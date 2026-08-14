"""Broadcaster — abstracción publish/subscribe por rooms (Phase 7, RT-01..03).

Fuente: patrón ConnectionManager oficial de FastAPI
(https://fastapi.tiangolo.com/advanced/websockets/) adaptado a rooms + seq.

Rooms:
- ``restaurant:{id}`` — staff del restaurante (aislamiento cross-tenant).
- ``user:{id}`` — cliente dueño (privacidad: un cliente jamás ve eventos de
  otros comensales).

ADVERTENCIA MULTI-WORKER (PITFALL P3): ``InMemoryBroadcaster`` SOLO es
correcto con 1 worker uvicorn (el CMD actual del Dockerfile — 1 proceso, 1
event loop). Si alguien añade ``--workers N``, cocina conectada al worker B
jamás vería pedidos publicados en el worker A (fallo SILENCIOSO, no
reproducible en dev). Multi-worker requiere un ``RedisBroadcaster`` que
reimplemente ``publish()`` vía Redis Pub/Sub (PLT2-02, v2) — NO añadir
--workers sin él. La advertencia se replica en docker-compose.yml.

``seq`` es monotónico POR ROOM y se resetea al reiniciar el server — aceptable
por diseño: el reconnect client-side hace GET de re-sync y resetea su
``lastSeq`` (Pattern 4 del research).
"""

import asyncio
from datetime import UTC, datetime
from typing import Any, Protocol

from fastapi import WebSocket


class Broadcaster(Protocol):
    """Interfaz publish/subscribe por rooms — Redis-ready (PLT2-02).

    Un futuro ``RedisBroadcaster`` sobrescribe ``publish`` (PUBLISH al canal)
    y corre un listener que entrega a sus sockets LOCALES reutilizando la
    parte in-memory — por eso la interfaz no expone nada específico de
    memoria. InMemoryBroadcaster SOLO es correcto con 1 worker uvicorn;
    multi-worker requiere Redis (ver advertencia del módulo).
    """

    async def connect(self, ws: WebSocket, room: str) -> None: ...

    async def disconnect(self, ws: WebSocket, room: str) -> None: ...

    async def publish(self, room: str, event: dict[str, Any]) -> None: ...


class InMemoryBroadcaster:
    """Implementación single-process: dict room→set[WebSocket] + seq por room."""

    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}
        self._seq: dict[str, int] = {}  # por room; reset al reiniciar (OK)
        self._lock = asyncio.Lock()  # defensivo; single event loop no la exige

    async def connect(self, ws: WebSocket, room: str) -> None:
        await ws.accept()
        async with self._lock:
            self._rooms.setdefault(room, set()).add(ws)

    async def disconnect(self, ws: WebSocket, room: str) -> None:
        async with self._lock:
            self._rooms.get(room, set()).discard(ws)

    async def publish(self, room: str, event: dict[str, Any]) -> None:
        async with self._lock:
            self._seq[room] = self._seq.get(room, 0) + 1
            event = {**event, "seq": self._seq[room]}
        dead: list[WebSocket] = []
        # Iterar COPIA: un discard durante el loop no puede romper la iteración
        # (PITFALL P4 — un socket muerto NUNCA rompe el publish a los demás).
        for ws in list(self._rooms.get(room, ())):
            try:
                await ws.send_json(event)
            except Exception:  # socket muerto → cleanup post-loop
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws, room)


# Singleton importado por services (emisión) y api/ws.py (join/leave).
broadcaster = InMemoryBroadcaster()


async def emit_event(
    type_: str,
    restaurante_id: int | None,
    usuario_id: int | None,
    data: dict,
) -> None:
    """Emite un evento de negocio a los rooms implicados (07-01 Task 2).

    Contrato (consumido por 07-02 panel y 07-03 app cliente):
    ``{"type": str, "restaurante_id": int|None, "seq": int, "ts": str, "data": dict}``

    - ``restaurante_id`` no-None → room ``restaurant:{id}`` (staff) con el
      restaurante_id en el payload.
    - ``usuario_id`` no-None → room ``user:{id}`` (cliente dueño) con
      ``restaurante_id: None`` (contrato: null en eventos del user room).

    ``seq`` lo adjunta ``broadcaster.publish`` POR ROOM (independiente en cada
    room al que llega el evento). Dos awaits directos y SECUENCIALES — NO
    ``asyncio.create_task`` (orden garantizado entre publicaciones de un mismo
    flujo; errores de sockets muertos los absorbe el broadcaster).

    Convención: invocar SOLO post-commit desde los services (una sola fuente
    de emisión — jamás routers, jamás dentro de la transacción).
    """
    ts = datetime.now(UTC).isoformat()
    if restaurante_id is not None:
        await broadcaster.publish(
            f"restaurant:{restaurante_id}",
            {"type": type_, "restaurante_id": restaurante_id, "ts": ts, "data": data},
        )
    if usuario_id is not None:
        await broadcaster.publish(
            f"user:{usuario_id}",
            {"type": type_, "restaurante_id": None, "ts": ts, "data": data},
        )
