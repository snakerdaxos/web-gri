"""Verificador de WebSocket contra la URL base (a través de nginx o directo).

Corre con el entorno del backend (httpx + httpx-ws YA están en el dev group):

    cd backend && uv run python ../deploy/verify_ws.py --base http://localhost:8080

Flujo REAL (no un handshake rechazado): registra un usuario único, loguea,
conecta ``/ws/cliente?token={access}`` (auth JWT por query param — patrón de
app/api/ws.py) y mantiene la conexión viva 2s sin error → imprime ``WS-OK``.
Cualquier fallo (registro, login, handshake, cierre inesperado) → exit 1.

Usado por deploy/verify_local.ps1 para validar el proxy WS de nginx
(proxy_http_version 1.1 + headers Upgrade — si nginx está mal configurado el
handshake muere aquí).
"""

import argparse
import asyncio
import sys
from uuid import uuid4

import httpx
from httpx_ws import aconnect_ws

PASSWORD = "VerifyWs!2026"  # >= 8 chars (UserCreate password min_length=8)


async def main(base_url: str) -> int:
    ws_base = base_url.replace("https://", "wss://").replace("http://", "ws://")
    async with httpx.AsyncClient(base_url=base_url, timeout=15) as client:
        email = f"verify-ws-{uuid4().hex[:8]}@gri.dev"
        r = await client.post(
            "/auth/register",
            json={"nombre": "Verify WS", "email": email, "password": PASSWORD},
        )
        r.raise_for_status()  # API viva y aceptando registros (a través de nginx)
        r = await client.post(
            "/auth/login", json={"email": email, "password": PASSWORD}
        )
        r.raise_for_status()
        access_token = r.json()["access_token"]

    # JWT real + room user:{id} — el servidor cierra con 4401 si el token
    # fuera inválido; aconnect_ws lanza y el script sale non-zero.
    async with aconnect_ws(f"{ws_base}/ws/cliente?token={access_token}") as ws:
        await asyncio.sleep(2)  # 2s vivos: handshake + upgrade completos
        assert ws.response.status_code == 101, "handshake no fue 101 Switching Protocols"

    print("WS-OK")
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Verifica el WebSocket de GRI con un JWT real contra --base."
    )
    parser.add_argument(
        "--base",
        default="http://localhost:8080",
        help="URL base a verificar (nginx :8080 o API directa :8000)",
    )
    args = parser.parse_args()
    try:
        sys.exit(asyncio.run(main(args.base)))
    except Exception as exc:  # noqa: BLE001 — verificador: reportar y fallar
        print(f"WS-FAIL: {type(exc).__name__}: {exc}")
        sys.exit(1)
