# Phase 7: Tiempo Real — WebSockets - Research

**Researched:** 2026-08-14
**Domain:** WebSockets FastAPI (broadcast por rooms) + cliente Flutter con reconexión/re-sync + testing WS
**Confidence:** HIGH (patrones verificados contra docs vivas de FastAPI/pub.dev/PyPI + código fuente local de uvicorn 0.52.3 y de los 3 frontends existentes)

## Summary

La fase convierte el polling REST existente (3 StreamProviders con `Timer.periodic(10s)` en panel_admin y app_cliente) en push por WebSocket, manteniendo los GET como re-sync. El backend ya corre **1 solo worker uvicorn** (CMD del Dockerfile: `uvicorn app.main:app` sin `--workers`), así que un `InMemoryBroadcaster` con rooms es correcto para v1 — exactamente lo que la doc oficial de FastAPI recomienda para single-process, con el límite documentado para el día en que se escale (Redis Pub/Sub, ya previsto como PLT2-02).

Las tres piezas nuevas: (1) `app/core/broadcaster.py` con la abstracción `Broadcaster` (interfaz publish/connect/disconnect idéntica a la que tendría un `RedisBroadcaster`) + `InMemoryBroadcaster` (dict room→set[WebSocket], contador `seq` por room); (2) `app/api/ws.py` con `/ws/staff?token=` (room `restaurant:{id}`) y `/ws/cliente?token=` (room `user:{id}`) — auth JWT manual con close code **4401**; (3) emisiones **post-commit** en los services existentes (`pedido_service`, `sesion_service`, `staff_service`). Flutter: `web_socket_channel 3.0.3` (`WebSocketChannel.connect` es cross-platform IO+Web — sin imports condicionales) + `WsClient` propio con backoff exponencial + jitter, y el patrón **"WS como señal de invalidate → GET refresh"**: el evento no muta estado local, dispara el GET existente. Reconexión → GET de re-sync → seguir deltas, dedup por `seq`.

Hallazgos críticos que moldean el plan: **(a)** `Depends(get_session)` en un endpoint WS sostiene el checkout del pool durante TODA la vida de la conexión → agota el pool (auth WS debe usar `async_session_maker()` manual y cerrar en el acto); **(b)** el access token expira en 15 min (`ACCESS_TTL_MIN=15`) — el WsClient debe leer el token FRESCO del AuthStorage en cada intento de conexión y, ante close 4401, refrescar y reconectar (flujo ejercitado constantemente en producción); **(c)** el heartbeat ya existe protocol-level: uvicorn 0.52.3 manda ping cada 20s con timeout 20s por defecto (verificado en `backend/.venv/.../uvicorn/config.py`) — NO implementar ping/pong a nivel app; **(d)** los tests backend corren contra el stack Docker vivo (filosofía del proyecto) y httpx no soporta WS → **httpx-ws 0.9.0** (PyPI, Mar 2026) con `aconnect_ws`; **(e)** el contenedor api no tiene volume mount → todo cambio requiere `docker compose up -d --build api` antes de pytest.

**Primary recommendation:** Broadcaster in-memory en `core/broadcaster.py` + 2 endpoints WS con JWT query param (4401) + emisión post-commit en services; en Flutter, WsClient con backoff+jitter+resync y providers que reemplazan el Timer por kick-to-refetch, conservando polling 60s como safety net.

## User Constraints

No existe CONTEXT.md para esta fase. Las decisiones que gobiernan el trabajo vienen del ROADMAP (nota de la fase), ARCHITECTURE.md del proyecto y el brief del orquestador:

### Locked Decisions (upstream — el planner DEBE honrarlas)

- **Broadcaster desde el día 1, in-memory v1, Redis-ready** (ROADMAP nota + PLT2-02 defer): interfaz publish/subscribe; NO implementar Redis ahora. v1 corre 1 worker (verificado en Dockerfile CMD) — documentar el límite multi-worker en el código.
- **Rooms**: `restaurant:{id}` para staff; `user:{id}` para cliente (aislamiento natural cross-tenant + privacidad del cliente: si el cliente entrara al room del restaurante vería pedidos de otros comensales).
- **Patrón re-sync HTTP + WS deltas** (requisito): el WS es *notificación*, no fuente de estado. Al (re)conectar: GET del estado actual → deltas por WS. Sequence numbers para dedup/orden client-side.
- **FastAPI WebSocket nativo** (`@app.websocket`) — sin Socket.IO, sin SSE, sin deps runtime nuevas.
- **Stack Flutter locked**: riverpod 3.x + codegen, dio, freezed 4.0.0-dev.3 (pin ya validado). Flutter SDK en `C:\src\flutter\bin` (no en PATH).
- **Eventos de negocio** emitidos por los SERVICES (post-commit), nunca por los routers (convención ARCHITECTURE.md: "una sola fuente de emisión").

### Claude's Discretion (investigado y resuelto en este research)

- Ubicación del broadcaster: `core/broadcaster.py` (resuelto — ver Architecture Patterns).
- Heartbeat: protocol-level de uvicorn (resuelto — no app-level ping/pong).
- Estrategia de aplicación de eventos en Flutter: kick-to-refetch (resuelto — ver Pattern 6).
- Polling safety net: mantener a 60s (resuelto).
- Tests backend: httpx-ws contra stack vivo (resuelto — ver Validation Architecture).

### Deferred (OUT OF SCOPE)

- Redis Pub/Sub multi-instancia (PLT2-02, v2).
- Replay persistente de eventos server-side (log/ring buffer en BD) — el re-sync HTTP cubre el gap en v1; el campo `seq` queda adelante-compatible.
- Push notifications FCM/APNs (v2, Out of Scope REQUIREMENTS.md).
- nginx WS upgrade headers (F9 deploy — documentado aquí para que F9 lo consuma).

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RT-01 | Cambios de estado de pedidos llegan a cocina, mesero y cliente sin refrescar (WebSockets) | Eventos `pedido.creado`/`pedido.estado` publicados a room `restaurant:{id}` (staff) + `user:{usuario_id}` (cliente dueño) desde `pedido_service.crear_pedido`/`transicionar` post-commit; providers `pedidosStaff` (panel) y `pedidosSession` (app) reemplazan Timer por escucha WS → GET refresh |
| RT-02 | Cambios de estado de mesas se reflejan en el mapa del panel sin refrescar | Evento `mesa.estado` publicado desde `sesion_service.abrir_sesion` y `staff_service.set_mesa_estado` → `mesasProvider` (+`statsProvider`) escuchan → GET `/staff/mesas` refresh |
| RT-03 | La app se recupera de desconexiones (reconexión + re-sincronización al reconectar) | WsClient con backoff exponencial 1→30s ×2 + jitter; al reconectar: re-sync GET (providers existentes) + reset de `lastSeq`; dedup por `seq <= lastSeq`; token fresco por intento + refresh ante 4401; safety net polling 60s |

</phase_requirements>

## Standard Stack

### Core (NUEVAS deps de esta fase)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **web_socket_channel** (Flutter, ambas apps) | ^3.0.3 | Cliente WS cross-platform | Oficial Dart team (verified publisher `tools.dart.dev`, 1.6k likes, 9.13M downloads/sem). `WebSocketChannel.connect(uri)` selecciona la implementación IO (móvil/desktop) o Web automáticamente — **sin imports condicionales**. `await channel.ready` para conectar o fallar. Verificado en pub.dev (Aug 2026). **HIGH** |
| **httpx-ws** (backend, dev-only) | >=0.9.0 | Cliente WS para tests pytest contra el stack vivo | De François Voron (ecosistema httpx). `aconnect_ws(url)` async context manager + `receive_json()`/`send_json()`. Funciona sobre `httpx.AsyncClient` real (network) — encaja con la filosofía de tests del proyecto (stack Docker vivo). Release Mar 28 2026. Verificado en PyPI + docs. **HIGH** |

### Ya instaladas (sin cambios)

| Library | Version | Role en esta fase |
|---------|---------|-------------------|
| FastAPI | >=0.141.0 | `@app.websocket` nativo, `WebSocketDisconnect`, `WebSocketException`, Depends soportado en WS |
| uvicorn[standard] | 0.52.3 (venv local) | Sirve WS sin config extra. **Heartbeat protocol-level por defecto**: `ws_ping_interval=20.0`, `ws_ping_timeout=20.0` (verificado en código fuente local) |
| PyJWT | >=2.13.0 | `decode_token()` existente reutilizado para auth WS (HS256, `type=="access"`) |
| pytest + pytest-asyncio | 8.x / >=0.24 | `asyncio_mode = "auto"` ya configurado |

**Instalación:**
```bash
# backend (dev group)
cd backend && uv add --group dev "httpx-ws>=0.9.0"
# ambas apps Flutter
cd app_cliente && flutter pub add web_socket_channel:^3.0.3
cd panel_admin  && flutter pub add web_socket_channel:^3.0.3
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| web_socket_channel | socket_io_client | NO — Socket.IO es un protocolo propietario sobre WS (necesita server python-socketio); overkill total para broadcast unidireccional server→client |
| WsClient propio (reconexión) | web_socket_channel + paquete de reconexión | No hay paquete de reconexión estándar/mantenido en pub.dev; el loop de backoff son ~40 líneas y el control del flujo 4401→refresh→retry necesita acceso al AuthStorage del proyecto igualmente |
| httpx-ws (tests) | starlette TestClient in-process | TestClient requeriría importar la app en el host y cambia la filosofía de tests del proyecto (todo contra el stack Docker vivo); httpx-ws mantiene el patrón |
| httpx-ws (tests) | `websockets` lib directa | Funciona, pero httpx-ws ya está integrada con httpx (mismo client/URL base) y tiene helpers JSON |
| Broadcaster propio | encode/broadcaster | encode/broadcaster es la referencia oficial de FastAPI para multi-proceso (Redis/PG) — en v2, cuando exista Redis, evaluarlo; para v1 in-memory una interfaz propia de 3 métodos es más simple y sin deps |

## Architecture Patterns

### Estructura resultante

```
backend/app/
├── core/
│   └── broadcaster.py        # NUEVO — Broadcaster protocol + InMemoryBroadcaster + singleton
├── api/
│   └── ws.py                 # NUEVO — /ws/staff + /ws/cliente (router websocket)
├── main.py                   # + include_router(ws.router)
└── services/                 # emisiones post-commit (sin nuevos archivos)
    ├── pedido_service.py     #   pedido.creado / pedido.estado
    ├── sesion_service.py     #   mesa.estado (abrir) / sesion.abierta / sesion.cuenta
    └── staff_service.py      #   mesa.estado (transición) / sesion.cerrada (anti-zombi)

app_cliente/lib/core/ws_client.dart     # NUEVO — copia (patrón core/ del proyecto)
panel_admin/lib/core/ws_client.dart     # NUEVO — copia idéntica
# providers existentes: reemplazo de Timer.periodic por escucha WS (sin renombrar)
```

### Pattern 1: Broadcaster con rooms + seq (in-memory, Redis-ready)

**What:** Un objeto singleton con tres operaciones — `connect(ws, room)`, `disconnect(ws, room)`, `publish(room, event)`. Rooms `restaurant:{id}` (staff) y `user:{id}` (cliente). Cada `publish` incrementa un contador `seq` **por room** y lo adjunta al evento. La interfaz no expone nada específico de memoria: un futuro `RedisBroadcaster` sobrescribe `publish` (PUBLISH al canal) y corre un listener que entrega a sus sockets locales reutilizando la parte local — por eso Redis-ready sin Redis.

**When to use:** siempre en esta fase. El límite documentado: **solo correcto con 1 worker** (doc oficial FastAPI: "it will only work while the process is running, and will only work with a single process"). El Dockerfile corre 1 worker — añadir comentario en `broadcaster.py` y en `docker-compose.yml` (advertencia: si alguien añade `--workers N`, el broadcast se rompe silenciosamente → PITFALLS P3).

```python
# app/core/broadcaster.py — fuente: patrón oficial FastAPI ConnectionManager
# (https://fastapi.tiangolo.com/advanced/websockets/) adaptado a rooms + seq.
import asyncio
from typing import Any, Protocol

from fastapi import WebSocket


class Broadcaster(Protocol):
    """Interfaz publish/subscribe por rooms — Redis-ready (PLT2-02).

    InMemoryBroadcaster SOLO es correcto con 1 worker uvicorn (default del
    Dockerfile). Multi-worker requiere RedisBroadcaster que reimplemente
    publish() via Redis Pub/Sub y entregue a los sockets locales.
    """

    async def connect(self, ws: WebSocket, room: str) -> None: ...
    async def disconnect(self, ws: WebSocket, room: str) -> None: ...
    async def publish(self, room: str, event: dict[str, Any]) -> None: ...


class InMemoryBroadcaster:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}
        self._seq: dict[str, int] = {}          # por room; reset al reiniciar (OK: re-sync HTTP cubre)
        self._lock = asyncio.Lock()              # defensivo; single event loop no la exige

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
        # iterar COPIA: un discard durante el loop no puede romper la iteración
        for ws in list(self._rooms.get(room, ())):
            try:
                await ws.send_json(event)
            except Exception:                    # socket muerto NO rompe el publish
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws, room)


broadcaster = InMemoryBroadcaster()   # singleton importado por services y api/ws.py
```

### Pattern 2: Endpoints WS con JWT query param (4401) — y SIN Depends(get_session)

**What:** `/ws/staff?token=<access>` y `/ws/cliente?token=<access>`. El browser no permite headers custom en el handshake WS → token por query param (la doc oficial de FastAPI usa exactamente `?token=` en su ejemplo de WS con dependencias). Auth manual: `decode_token` → `type=="access"` → usuario existe y activo → rol esperado. Fallo → `WebSocketException(code=4401)` ANTES del accept (el cliente ve close code 4401; rango 4000-4999 es app-defined por RFC 6455). Éxito → join al room + receive loop hasta `WebSocketDisconnect`.

**CRÍTICO — no usar `Depends(get_session)` en endpoints WS:** una dependencia con `yield` se cierra cuando termina el "request" — en WS eso es **al cerrar la conexión**. La `AsyncSession` (y su conexión del pool) quedaría checked-out durante toda la vida del socket → decenas de staff conectados agotan el pool y se cae toda la API. El auth del WS abre su propia sesión corta con `async_session_maker()` y la cierra en el acto (1 SELECT por PK, barato, solo al conectar).

```python
# app/api/ws.py (esqueleto prescriptivo)
import jwt
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, WebSocketException

from app.core.broadcaster import broadcaster
from app.core.db import async_session_maker
from app.core.security import decode_token
from app.models.usuario import RolUsuario, Usuario

router = APIRouter()

_WS_CLOSE_UNAUTHENTICATED = 4401  # app-defined (RFC 6455 §7.4.1: 4000-4999)


async def _ws_user(token: str) -> Usuario:
    """Auth del handshake. SIN Depends(get_session): esa sesión viviría tanto
    como la conexión WS y agotaría el pool. Sesión corta y al cierre."""
    try:
        payload = decode_token(token)
    except jwt.PyJWTError:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    if payload.get("type") != "access":
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    async with async_session_maker() as session:          # abre → 1 get por PK → cierra
        user = await session.get(Usuario, int(payload["sub"]))
    if user is None or not user.activo:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    return user


@router.websocket("/ws/staff")
async def ws_staff(
    websocket: WebSocket,
    token: str = Query(...),
    restaurante_id: int | None = Query(default=None),
):
    user = await _ws_user(token)
    if user.role == RolUsuario.cliente:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)

    # super_admin SIN restaurant_id en el token → param requerido (mirror
    # _resolve_rid de staff.py: hint validado, 404-if-unknown → aquí 4400).
    # Para staff el param se IGNORA: el tenant sale del token.
    rid = user.restaurant_id if user.role != RolUsuario.super_admin else restaurante_id
    if rid is None:
        raise WebSocketException(code=4400)  # bad request app-defined

    room = f"restaurant:{rid}"
    await broadcaster.connect(websocket, room)
    try:
        while True:
            await websocket.receive_text()   # descarta pings app-level si llegan; mantiene viva la conn
    except WebSocketDisconnect:
        await broadcaster.disconnect(websocket, room)


@router.websocket("/ws/cliente")
async def ws_cliente(websocket: WebSocket, token: str = Query(...)):
    user = await _ws_user(token)
    if user.role != RolUsuario.cliente:
        raise WebSocketException(code=_WS_CLOSE_UNAUTHENTICATED)
    room = f"user:{user.id}"
    await broadcaster.connect(websocket, room)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await broadcaster.disconnect(websocket, room)
```

**Nota super_admin:** el panel ya resuelve el restaurante activo (`currentRestauranteIdProvider`) y manda `?restaurante_id=` en los GET — el WS replica ese patrón. Validación de existencia del restaurante: opcional en v1 (un rid inexistente simplemente no recibe eventos); si se valida, 4404.

### Pattern 3: Emisión post-commit en services (una sola fuente)

**What:** cada service emite DESPUÉS del `await session.commit()` exitoso — nunca dentro de la transacción (PITFALLS Performance Trap: broadcast dentro de la tx = locks + latencia; y un rollback dejaría eventos fantasma emitidos). `await broadcaster.publish(...)` directo (no `asyncio.create_task`): ordenado, testeable, y los errores de sockets muertos ya los absorbe el broadcaster.

**Mapa exacto de emisiones sobre el código existente:**

| Service (función) | Evento(s) | Rooms | Dispara en el cliente |
|---|---|---|---|
| `pedido_service.crear_pedido` (post-commit) | `pedido.creado` | `restaurant:{rid}` + `user:{usuario_id}` | Cola cocina aparece; dueño ve su pedido |
| `pedido_service.transicionar` (post-commit) | `pedido.estado` | `restaurant:{rid}` + `user:{usuario_id}` | Cocina/mesero re-ordenan cola; dueño ve estado |
| `sesion_service.abrir_sesion` (post-commit, solo `created=True`) | `mesa.estado` + `sesion.abierta` | `restaurant:{rid}` / `user:{usuario_id}` | Mapa del panel pinta ocupada |
| `sesion_service.solicitar_cuenta` (solo si cambió) | `sesion.cuenta` | `restaurant:{rid}` + `user:{usuario_id}` | Badge cuenta en cola; ACK al dueño |
| `staff_service.set_mesa_estado` (post-commit) | `mesa.estado` | `restaurant:{rid}` | Mapa del panel |
| `staff_service.set_mesa_estado` (si anti-zombi cerró sesión) | `sesion.cerrada` | `user:{usuario_id de la sesión}` | App del cliente re-sincroniza (su sesión murió) |

**Shape del evento (contrato compartido):**
```json
{
  "type": "pedido.estado",          // pedido.creado | pedido.estado | mesa.estado |
                                    // sesion.abierta | sesion.cuenta | sesion.cerrada
  "restaurante_id": 1,              // null en eventos de user room
  "seq": 42,                        // monotónico POR ROOM; reset al reiniciar server (OK)
  "ts": "2026-08-14T19:42:00-05:00",
  "data": { "pedido_id": 1023, "estado": "en_preparacion", "mesa_id": 4 }
}
```
`data` lleva ids + estado mínimo (no el objeto completo): la estrategia client-side es kick-to-refetch (Pattern 6), así que el payload no necesita joins display. El `type` versiona el contrato — añadir campos es backward-compatible.

**Cómo obtener `usuario_id` en `set_mesa_estado` para `sesion.cerrada`:** el anti-zombi ya hace `UPDATE` de la sesión activa en la misma tx — capturar el `usuario_id` de esa sesión ANTES del commit (lección MissingGreenlet: capturar valores en variables planas antes de cualquier expire) y emitir post-commit solo si había sesión.

### Pattern 4: Secuencia / dedup / re-sync (RT-03)

**What:** el `seq` es **por room**, monotónico dentro de la vida del proceso. Cliente:

1. Mantiene `lastSeq` (int?) del último evento aplicado de SU room.
2. Evento con `seq <= lastSeq` → **ignorar** (dedup — cubre duplicados y re-entregas).
3. Al **(re)conectar**: GET de re-sync primero (estado autoritativo, sobrescribe) → `lastSeq = null` (reset) → deltas desde ahí. Un evento llegando con cualquier seq tras el reset simplemente se aplica (el snapshot ya es más nuevo o igual; los handlers son idempotentes por diseño "último estado gana").
4. Reset del server (seq vuelve a 1 tras reinicio): como el reconnect siempre resetea `lastSeq`, la comparación nunca ve "seq retrocedió" — sin lógica extra.

El replay server-side (re-enviar eventos perdidos) NO existe en v1: la ventana de pérdida la cierra el GET de re-sync. `seq` queda en el contrato para el replay de v2 sin romper clientes.

### Pattern 5: Heartbeat = protocol-level (ya activo)

**What:** uvicorn con `websockets` (viene en `uvicorn[standard]`) manda **ping de protocolo cada 20s y corta si no hay pong en 20s** — defaults verificados en el código fuente local de uvicorn 0.52.3 (`ws_ping_interval: float | None = 20.0`). Los clientes responden pong automáticamente: `dart:io` WebSocket en móvil y el browser en web lo hacen a nivel de protocolo sin código de app.

- NO implementar ping/pong JSON a nivel app (el receive loop del server simplemente descarta texto entrante).
- Detección client-side de server muerto: `onDone`/`onError` del canal (TCP close / error) → reconexión. No se necesita `pingInterval` client-side.
- nginx en F9: requiere `proxy_read_timeout` > 20s (p.ej. 3600s) + headers Upgrade — documentado en Open Questions para F9.

### Pattern 6: Flutter — WsClient + kick-to-refetch en los providers

**What (WsClient):** clase en `core/ws_client.dart` (copia idéntica en ambas apps — patrón `core/` del proyecto), expuesta como provider. Responsabilidades: conectar con **token fresco leído del AuthStorage en cada intento** (el access expira en 15 min — nunca cachearlo en el constructor), exponer `Stream<WsEvent>` broadcast, reconectar con **backoff exponencial 1,2,4,8,16,30s cap** ×2 + jitter (0-500ms), y señalar `onResync` cuando una conexión se restablece.

```dart
// core/ws_client.dart — esqueleto prescriptivo
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'env.dart';

class WsEvent {
  final String type;
  final int? seq;
  final Map<String, dynamic> data;
  /* fromJson: type/seq/ts/data */
}

/// WS como SEÑAL: los eventos no mutan estado — disparan GET refresh.
/// Reconexión: backoff 1→30s x2 + jitter; 4401 → refresca token y reintenta.
class WsClient {
  WsClient(this._storage, this._api);

  final AuthStorage _storage;
  final ApiClient _api;                 // reutiliza el refresh del AuthInterceptor

  final _events = StreamController<WsEvent>.broadcast();
  Stream<WsEvent> get events => _events.stream;
  final _resync = StreamController<void>.broadcast();
  Stream<void> get resync => _resync.stream;   // se dispara al RESTABLECER conexión

  WebSocketChannel? _channel;
  int _failures = 0;
  int? _lastSeq;

  /// ws(s):// derivado de http(s):// del Env — misma infra dev/prod.
  Uri _wsUri(String path) => Uri.parse(
        Env.apiBaseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://')
            + path);

  Future<void> connect(String path) async {
    final token = await _storage.readAccess();   // FRESCO en cada intento (15 min TTL)
    if (token == null) return;
    final channel = WebSocketChannel.connect(_wsUri(path).replace(
        queryParameters: {'token': token}));
    try {
      await channel.ready;                       // conecta o lanza
    } catch (_) {
      _scheduleReconnect(path);
      return;
    }
    _channel = channel;
    _lastSeq = null;                             // reset: el re-sync GET reordena
    if (_failures > 0) _resync.add(null);        // reconexión → re-sync
    _failures = 0;
    channel.stream.listen(
      (msg) {
        final ev = WsEvent.fromJson(msg as String);
        if (_lastSeq != null && ev.seq != null && ev.seq! <= _lastSeq!) return; // dedup
        _lastSeq = ev.seq;
        _events.add(ev);
      },
      onDone: () => _scheduleReconnect(path),    // server cerró / red cayó
      onError: (_) => _scheduleReconnect(path),
    );
  }

  Future<void> _scheduleReconnect(String path) async {
    _failures++;
    if (_failures > 1) {
      // 4401 = token expirado → refresh (mecanismo existente del ApiClient) y retry YA
      // (el close code llega en channel.closeCode una vez done)
    }
    final backoff = min(30000, 1000 * pow(2, _failures - 1)).toInt();
    final jitter = Random().nextInt(500);
    await Future.delayed(Duration(milliseconds: backoff + jitter));
    await connect(path);
  }

  void dispose() { _channel?.sink.close(); _events.close(); _resync.close(); }
}
```

*(El planner refinará el manejo exacto del `closeCode == 4401` → refresh + reintento inmediato — `WebSocketChannel.closeCode` está disponible tras `onDone`; ver pub.dev docs.)*

**What (providers):** los 3 StreamProviders existentes (`mesas`, `pedidosStaff`, `pedidosSession`) mantienen su GET inicial y consumers intactos; el `Timer.periodic` se reemplaza por:

```dart
// patrón para pedidosStaffProvider (espejo en mesasProvider / pedidosSession)
yield await client.getPedidosActivos(restauranteId: queryRid);  // snapshot inicial

final controller = StreamController<List<PedidoStaff>>();
Future<void> refresh() async {
  try { controller.add(await client.getPedidosActivos(restauranteId: queryRid)); }
  catch (e) { controller.addError(e); }
}

// 1) eventos WS relevantes → kick-to-refetch (NO mutar estado local)
final sub1 = ref.watch(wsEventsProvider).where((e) =>
    e.type == 'pedido.creado' || e.type == 'pedido.estado' ||
    e.type == 'sesion.cuenta' || e.type == 'mesa.estado').listen((_) => refresh());
// 2) reconexión restablecida → re-sync total
final sub2 = ref.watch(wsResyncProvider).listen((_) => refresh());
// 3) safety net: polling lento 60s (cubre bugs de WS; barato)
Timer? timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());

ref.onDispose(() { sub1.cancel(); sub2.cancel(); timer?.cancel(); controller.close(); });
yield* controller.stream;
```

**Por qué kick-to-refetch y no aplicar el delta localmente:** una sola fuente de verdad de construcción de estado (el server ya construye la cola con joins display y orden FIFO `FIELD()`); cero lógica de merge/orden client-side; cero drift (PITFALLS P2); el criterio "sin refrescar la pantalla" se cumple (el GET es automático e invisible). Costo: 1 GET por evento por screen — trivial a escala GRI (y MENOS tráfico que el polling de 10s actual). El contrato (type/seq) permite evolucionar a aplicación directa de deltas sin romper clientes.

**Conexión WS por app (ciclo de vida):**
- `panel_admin`: conectar al autenticarse (watch de `authStateProvider`) a `/ws/staff` (+ `?restaurante_id=` si super_admin cambia el dropdown → reconectar al cambiar `currentRestauranteIdProvider`). `autoDispose` de los providers solo cancela SUSCRIPCIONES al stream broadcast; el WsClient vive mientras haya sesión.
- `app_cliente`: conectar al iniciar sesión a `/ws/cliente`. `pedidosSession` además escucha `sesion.cerrada` → refresh (la sesión murió por anti-zombi/pago → el GET devuelve 404 → estado vacío correcto).

### Anti-Patterns to Avoid

- **`Depends(get_session)` en endpoint WS** — mantiene el checkout del pool vivo toda la conexión → pool agotado → API caída. Usar `async_session_maker()` manual corto.
- **Broadcast dentro de la transacción** (antes del commit) — locks + eventos fantasma en rollback. Siempre post-commit.
- **Token cacheado al construir el WsClient** — expira a los 15 min y TODA reconexión posterior falla con 4401 en loop. Leer del storage en cada intento.
- **Room de restaurante para el cliente** — el comensal vería pedidos de otras mesas (privacy). Staff→room restaurante; cliente→room usuario (con publicación dual desde los services).
- **Mutación local del estado desde el evento** — duplica la lógica de orden/merge del server y crea drift. Kick-to-refetch.
- **`asyncio.create_task(publish(...))` fire-and-forget** — errores silenciosos y orden no garantizado entre múltiples publicaciones de un mismo flujo. `await` directo post-commit.
- **Iterar `self._rooms[room]` sin copia** en `publish` — el discard de sockets muertos durante la iteración rompe el loop. Iterar `list(...)`.
- **Eliminar los GET existentes** — son el re-sync de RT-03 y el fallback del safety net. Solo se retira el Timer de 10s (→ 60s).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cliente WS multiplataforma (IO + Web) | WebSocketConditional con imports `dart:io`/`dart:html` | `WebSocketChannel.connect()` | El constructor ya selecciona la implementación por plataforma (verificado pub.dev README) |
| Heartbeat/zombie detection | Ping/pong JSON app-level + timeouts custom | Defaults de uvicorn (`ws_ping_interval=20`) + `onDone` del canal | Protocol-level es invisible para la app y ya está activo |
| Reconexión con backoff | ...bueno, sí se hand-rolla — pero son ~40 líneas | Loop `_scheduleReconnect` del WsClient | No existe lib estándar mantenida; el flujo 4401→refresh necesita el ApiClient del proyecto |
| Orden/dedup de eventos | UUIDs por evento + tabla de vistos client-side | `seq` por room + `lastSeq` + reset on reconnect | TCP ya garantiza orden por conexión; el reset-on-reconnect elimina los casos borde |
| Envío a N sockets concurrentes | `asyncio.gather` masivo con cancelación compleja | loop secuencial `await send_json` con dead-socket cleanup | Payloads pequeños (bytes) y decenas de sockets — el secuencial es suficiente y simple |
| Multi-proceso WS (futuro) | Custom broker sobre MySQL | `encode/broadcaster` o `redis[hiredis]` Pub/Sub en PLT2-02 | Referencia oficial FastAPI; solo cuando exista >1 worker |

**Key insight:** en tiempo real, la complejidad real NO está en el broadcast (50 líneas) sino en la RECUPERACIÓN (reconexión, re-sync, dedup, token expirado). Ese es el foco de testing de la fase.

## Common Pitfalls

### Pitfall 1: Pool de BD agotado por dependencias con yield en WS
**What goes wrong:** `Depends(get_session)` en el handler WS → la sesión se cierra al terminar la conexión → N staff conectados = N conexiones del pool permanentemente tomadas → el API entero muere con timeouts.
**Why:** el ciclo de vida de una dependencia con yield en WebSockets es la CONEXIÓN, no el request HTTP.
**How to avoid:** auth WS con `async with async_session_maker()` corto (Pattern 2). Ningún endpoint WS declara `Depends(get_session)`.
**Warning signs:** el primer síntoma en dev sería tests WS que pasan pero `/health` se pone lento con varias conexiones abiertas.

### Pitfall 2: Reconexión con token expirado (4401 loop)
**What goes wrong:** access TTL = 15 min. Tras 15 min de sesión + una caída de red, el cliente reconecta con el token viejo → 4401 → si el WsClient no distingue el código, reintenta con el MISMO token para siempre (loop inútil) o se rinde cuando la sesión era perfectamente recuperable.
**How to avoid:** token fresco del AuthStorage en CADA intento; ante `closeCode == 4401` → refresh (reutilizar el mecanismo del ApiClient/`_refreshOnce`) → reintento inmediato sin backoff agresivo. Si el refresh falla → sesión expirada → logout (el `onSessionExpired` ya existe).
**Warning signs:** test manual — abrir app, esperar >15 min (o bajar `ACCESS_TTL_MIN` en dev), cortar la red 5s → debe reconectar sola.

### Pitfall 3: Broadcast dentro de la transacción
**What:** eventos emitidos antes del commit: si la tx hace rollback, los clientes vieron un estado que nunca existió; y `send_json` dentro de la tx alarga los locks.
**How to avoid:** emisión estrictamente post-commit en el service (después del último `await session.commit()` exitoso). Test: la transición inválida (409) NO emite nada (ver test de cross-tenant/con 409).

### Pitfall 4: Sockets muertos rompen el broadcast
**What:** `send_json` a un socket cerrado lanza; si el publish no lo atrapa, un solo cliente muerto rompe el evento para todos los demás.
**How to avoid:** try/except por socket + lista `dead` + disconnect (ya en el Pattern 1). Iterar sobre copia.

### Pitfall 5: "Funciona en dev, rompe con 2 workers"
**What:** el broadcaster in-memory es invisible-incorrecto con >1 worker: cocina conectada al worker B nunca ve pedidos publicados en el worker A (PITFALLS P3 — fallo silencioso, no reproducible en dev 1-worker).
**How to avoid:** comentario explícito en `broadcaster.py` y `docker-compose.yml` ("NO añadir --workers sin RedisBroadcaster/PLT2-02"). El CMD actual (1 worker) es el correcto para v1.

### Pitfall 6: App a background (móvil/web) → estado stale al volver
**What:** al volver de background la conexión puede estar muerta sin `onDone` inmediato (half-open) — el usuario ve estado viejo hasta el primer evento.
**How to avoid:** el safety net de 60s acota la ventana; el `resync` stream del WsClient dispara refresh al restablecer. (WidgetsBindingObserver app-resume → refresh HTTP es un upgrade opcional; el safety net ya cubre el criterio RT-03.)

### Pitfall 7: W01 (deuda Phase 1) — 503 intermitente asyncmy tras idle
**¿El WS lo agrava?** NO. Las conexiones WS no sostienen sesiones de BD (auth de 1 query al conectar; los eventos nacen de requests HTTP normales). Además kick-to-refetch REDUCE tráfico vs polling 10s (1 evento → ~3 GETs de screens activas vs 3 screens × 1 GET/10s continuo). El mecanismo de W01 (terminate de conexión stale del pool en `pool_pre_ping`) es independiente del WS.
**Acción recomendada en esta fase (barata, señalada por 01-VERIFICATION):** añadir `pool_recycle=3600` al engine en `app/core/db.py` (previene conexiones más viejas que 1h; el error de W01 venía del terminate de conexiones stale). 1 línea + test de regresión existente (`/health` suite). Si reaparece, deferir a F9.

### Pitfall 8: Flutter Web — secure context y derivación de URL
**What:** `ws://` no-WSS desde un origen HTTPS es bloqueado por el browser; y `Env.apiBaseUrl` es `http://...` → derivar SIEMPRE `ws://` de `http://` y `wss://` de `https://` (nunca hardcodear `ws://localhost`).
**How to avoid:** helper `_wsUri` del Pattern 6. En dev (Chrome :5173/:5174 → localhost:8000) `ws://` funciona; en F9 (HTTPS+nginx) la misma derivación produce `wss://`.

## Code Examples

Además de los patrones 1, 2 y 6 arriba (prescriptivos), el ejemplo canónico de testing backend:

```python
# tests/test_ws_realtime.py — fuente: httpx-ws docs quickstart
# (https://frankie567.github.io/httpx-ws/usage/quickstart/), adaptado.
import asyncio

import pytest
from httpx_ws import aconnect_ws

pytestmark = pytest.mark.anyio


async def test_staff_recibe_pedido_creado(async_client, db_session):
    token = await login_staff_demo(async_client, "cocina@demo.gri.dev")
    # setup: usuario cliente con sesión activa (helpers conftest existentes)
    ...
    async with aconnect_ws(
        f"http://localhost:8000/ws/staff?token={token}"
    ) as ws, asyncio.timeout(2):
        resp = await async_client.post("/cliente/pedidos", json={...},
                                       headers=auth_header(client_token))
        assert resp.status_code == 201
        event = await ws.receive_json()
        assert event["type"] == "pedido.creado"
        assert isinstance(event["seq"], int)
        assert event["data"]["pedido_id"] == resp.json()["id"]


async def test_token_invalido_close_4401(async_client):
    with pytest.raises(Exception) as exc:  # WebSocketDisconnect con code 4401
        async with aconnect_ws(
            "http://localhost:8000/ws/staff?token=basura"
        ) as ws:
            await ws.receive_json()
    assert getattr(exc.value, "code", None) == 4401
```

*Nota pytest-asyncio:* el proyecto usa `asyncio_mode = "auto"` (sin marker `anyio`); los tests WS siguen el mismo estilo async que los 141 existentes. `asyncio.timeout` (3.11+) reemplaza `wait_for`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Polling REST 10s (Timer.periodic) | WS push + re-sync HTTP on reconnect | Esta fase | Latencia 10s → <1s; ~6x menos requests en reposo |
| `dart:html`/`dart:io` imports condicionales para WS | `WebSocketChannel.connect` cross-platform | web_socket_channel 3.x | Sin código condicional; `channel.ready` para await de conexión |
| TestClient in-process para WS | httpx-ws sobre el stack vivo | httpx-ws 0.7+ (ASGI transport también disponible) | Tests WS en la misma filosofía integración-real del proyecto |
| ConnectionManager plano (tutorial) | Broadcaster con rooms + seq (interfaz Redis-ready) | — | Base para PLT2-02 sin reescritura |

**Deprecated/outdated a evitar:** paquetes `web_socket` viejos standalone (usar `web_socket_channel`); `qr_code_scanner`-style abandonware no aplica aquí; `socket_io` (protocolo propietario innecesario).

## Open Questions

1. **Nginx WS upgrade (F9, NO esta fase)** — F9 necesita: `proxy_http_version 1.1`, `proxy_set_header Upgrade/Connection "upgrade"`, `proxy_read_timeout 3600s` (> ping interval 20s). Documentado aquí; el plan de F9 lo consume.
   - Recommendation: no tocar infra en v7.
2. **¿Cerrar conexiones WS server-side cuando el token expira?** (kick tras 15 min forzando re-auth)
   - What we know: el server no re-valida el token post-handshake; la conexión viva sobrevive a la expiración.
   - Recommendation: NO en v1 (el reconnect natural + 4401→refresh ya cubre; un kicker agrega un timer por socket). Defer.
3. **`statsProvider` del panel en vivo** — escucha `mesa.estado`/`pedido.*` para refrescar las 4 stat cards, o queda con polling 60s?
   - Recommendation: conectarlo a los mismos eventos (1 línea más, mismo patrón) — el dashboard "en vivo" es parte del efecto wow de la fase. El planner decide granularidad.
4. **`receive_text` vs `receive` en el loop del server** — el server ignora el contenido entrante; si un futuro necesita client→server (acks), revisitar. `receive_text()` es el estándar del tutorial oficial.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Backend | pytest 8.x + pytest-asyncio (`asyncio_mode=auto`) **contra el stack Docker vivo** (`localhost:8000`) + **httpx-ws 0.9.0** (NUEVA dev dep) |
| Config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` |
| Quick run (backend) | `docker compose up -d --build api` primero (contenedor sin volume mount) → `uv run pytest tests/test_ws_realtime.py -x` (workdir `backend/`; uv por ruta completa si no está en PATH — gotcha I01) |
| Full suite (backend) | `uv run pytest` (141 + nuevos; stack vivo requerido) |
| Flutter (por app) | `$env:Path += ";C:\src\flutter\bin"; flutter test` en `panel_admin/` y `app_cliente/` (+ `dart run build_runner build` si hay codegen nuevo) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RT-01 | Staff conectado a `/ws/staff` recibe `pedido.creado` <2s tras POST /cliente/pedidos | integration (WS vivo) | `uv run pytest tests/test_ws_realtime.py::test_staff_recibe_pedido_creado -x` | ❌ Wave 0 |
| RT-01 | Cliente conectado a `/ws/cliente` recibe `pedido.estado` tras transición staff | integration | `uv run pytest tests/test_ws_realtime.py::test_cliente_recibe_pedido_estado -x` | ❌ Wave 0 |
| RT-01 | Panel cocina actualiza cola sin interacción (evento WS → provider refetch → UI) | widget test | `flutter test test/pedidos_ws_test.dart` (panel_admin) | ❌ Wave 0 |
| RT-02 | `mesa.estado` llega al staff al abrir sesión (QR) y al transicionar mesa | integration | `uv run pytest tests/test_ws_realtime.py::test_mesa_estado_eventos -x` | ❌ Wave 0 |
| RT-02 | Mapa del panel refresca al llegar evento (fake WsClient → provider → widget) | widget test | `flutter test test/mesas_ws_test.dart` (panel_admin) | ❌ Wave 0 |
| RT-03 | Token inválido/expirado → close 4401 (no join al room) | integration | `uv run pytest tests/test_ws_realtime.py::test_token_invalido_close_4401 -x` | ❌ Wave 0 |
| RT-03 | Cross-tenant: staff del restaurante A NO recibe eventos del B (room aislada) | integration | `uv run pytest tests/test_ws_realtime.py::test_cross_tenant_aislamiento -x` | ❌ Wave 0 |
| RT-03 | Dedup: segundo evento con mismo/menor seq ignorado; reconexión → resync GET llamado | unit (Dart) | `flutter test test/ws_client_test.dart` (app_cliente) | ❌ Wave 0 |
| RT-03 | `sesion.cerrada` (anti-zombi) llega al user room | integration | `uv run pytest tests/test_ws_realtime.py::test_sesion_cerrada_user_room -x` | ❌ Wave 0 |
| — | `seq` monotónico por room en emisiones consecutivas | integration | `uv run pytest tests/test_ws_realtime.py::test_seq_monotonico -x` | ❌ Wave 0 |

**Manual-only (justificación):** caída real de red/wifi y re-conexión del browser móvil — los widget tests con fake WsClient cubren la lógica; el flujo físico se verifica en UAT de fase (mismo criterio de las fases 4-6).

### Sampling Rate
- **Per task commit:** quick run de la suite nueva WS (`tests/test_ws_realtime.py`) + suite del área tocada (`-k pedido` / `-k sesion` según el service emitido).
- **Per wave merge:** full suite backend (141 + nuevos) + `flutter test` de ambas apps + `flutter analyze` (0 issues) — sin regresiones.
- **Phase gate:** full suites verdes ×2 runs consecutivos + smoke manual end-to-end (cocina ve pedido en vivo, mapa cambia, app cliente sobrevive reinicio del server API) antes de `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `backend/tests/test_ws_realtime.py` — suite WS completa (RT-01/02/03 backend side); helpers conftest reutilizables (`login_staff_demo`, `abrir_sesion`, usuarios dedicados por fixture — gotcha UNIQUE 0004)
- [ ] `httpx-ws>=0.9.0` en `[dependency-groups] dev` + `docker compose up -d --build api` (el contenedor no tiene volume mount — todo cambio de código requiere rebuild)
- [ ] `panel_admin/test/{mesas_ws_test.dart, pedidos_ws_test.dart}` + fake `wsEventsProvider` (StreamController broadcast en ProviderScope inline — gotcha: riverpod 3.4.2 no exporta `Override`)
- [ ] `app_cliente/test/ws_client_test.dart` — dedup seq + resync-on-reconnect (fake channel)
- [ ] WsClient compartido en ambas apps (`core/ws_client.dart`) + `web_socket_channel: ^3.0.3` en ambos pubspec

## Sources

### Primary (HIGH confidence)
- **FastAPI WebSockets docs (oficial, vivas)** — https://fastapi.tiangolo.com/advanced/websockets/ — patrón ConnectionManager + WebSocketDisconnect; nota oficial single-process + referencia a encode/broadcaster; `WebSocketException` con close codes; ejemplo canónico `?token=` query param. Fetch Aug 14 2026.
- **pub.dev/packages/web_socket_channel** — v3.0.3, verified publisher `tools.dart.dev`, 9.13M downloads/sem; `WebSocketChannel.connect` cross-platform (IO/Html automático), `channel.ready`, `closeCode/closeReason`, `status.dart`. Fetch Aug 14 2026.
- **PyPI httpx-ws** — v0.9.0 (Mar 28 2026), Python ≥3.10, `aconnect_ws`/`receive_json` (quickstart docs verificadas en frankie567.github.io/httpx-ws). Fetch Aug 14 2026.
- **uvicorn 0.52.3 código fuente local** (`backend/.venv/Lib/site-packages/uvicorn/config.py`) — `ws_ping_interval=20.0`, `ws_ping_timeout=20.0` defaults. Verificado directamente.
- **Código del proyecto** — Dockerfile CMD (1 worker), `deps/auth.py` (decode + type check), `core/security.py`, `pedido_service.py`, `sesion_service.py`, `staff.py`, `conftest.py`, los 3 providers con polling, ambos pubspec, STATE.md (gotchas: rebuild contenedor, freezed pin, flutter PATH).

### Secondary (MEDIUM confidence)
- **Comportamiento de dependencias con yield en WS** (checkout del pool durante la conexión) — comportamiento documentado del ciclo de vida ASGI/Starlette + múltiples issues de FastAPI sobre exit-stack en websockets. Prescrito el workaround (sesión manual corta) que es correcto independientemente del matiz exacto.
- **Browser auto-pong a protocol pings** — comportamiento estándar de la plataforma web (WebSocket API no expone ping/pong; el browser responde pong). Training data consolidado + consistente con los defaults de uvicorn.

### Tertiary (LOW confidence)
- Ninguno load-bearing. La política de close codes exacta que `websockets` (server) produce al rechazar antes de accept (`WebSocketException` pre-accept → handshake HTTP 403 vs close frame 4401) puede variar por versión — el test `test_token_invalido_close_4401` valida el comportamiento real en Wave 0; si el código observado difiere, ajustar contrato (4401 como objetivo, tolerar handshake HTTP rechazado) sin cambiar el diseño.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versiones verificadas en registry vivo hoy; uvicorn verificado en fuente local.
- Architecture: HIGH — broadcaster/rooms/emisión post-commit siguen el patrón oficial FastAPI + convenciones ya probadas del proyecto (services delgados en routers, existence hiding, conftest).
- Flutter WsClient: HIGH en API (pub.dev docs), MEDIUM en detalle del manejo `closeCode` 4401 entre IO y Web (diferencia de plataforma a validar en Wave 0 — el diseño lo aisla en `_scheduleReconnect`).
- Pitfalls: HIGH — pool-yield y token-expiry derivan de hechos verificados del código propio (TTL=15, get_session con yield); W01 analizado contra su VERIFICATION real.

**Research date:** 2026-08-14
**Valid until:** 2026-09-14 (stack estable; web_socket_channel publicado hace 16 meses sin cambios breaking)
