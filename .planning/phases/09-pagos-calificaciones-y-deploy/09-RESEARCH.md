# Phase 9: Pagos, Calificaciones y Deploy - Research

**Researched:** 2026-08-14
**Domain:** Pasarela de pagos Colombia (Wompi Web Checkout + webhooks HMAC) + calificaciones post-pago + deploy production-like (nginx/TLS/WS) en Ubuntu Server
**Confidence:** HIGH (arquitectura interna + deploy + idempotencia) · MEDIUM-HIGH (contrato Wompi, verificado desde SDK mantenido mar-2026 — docs oficiales siguen 403)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PAGO-02 | Cliente puede pagar en línea el total de su consumo (pasarela: Wompi preferida) | Flujo Wompi Web Checkout verificado (§Contrato Wompi): intención de pago → checkout URL → webhook. `PagoGateway` Protocol + `SandboxGateway` (sin credenciales) / `WompiGateway` (env vars). `POST /cliente/pagos/intencion` con monto server-side. |
| PAGO-03 | El pago es idempotente: reintentos o webhooks duplicados no generan doble cobro ni estados corruptos | Dedup por `(transaction_id, status)` en tabla `pago_event` (UNIQUE) + idempotencia natural por estado terminal (`PAGO_TRANSITIONS`: aprobado/rechazado son terminal → re-proceso = no-op 200) + referencia unique ya existente (`uq_pago_referencia`) + idempotencia de intención (1 pago pendiente por sesión). |
| PAGO-04 | Al confirmarse el pago, la mesa se libera (limpieza) y la sesión se cierra | Efectos en UNA transacción BD (§Efectos del pago aprobado): pedidos servido→pagado, sesión cerrada (`cerrada_en`, `estado=cerrada`), mesa ocupada→limpieza (transición ya válida en `MESA_TRANSITIONS`), WS post-commit (`sesion.cerrada` ya existe y la app cliente 07-03 ya lo maneja). |
| CALI-01 | Cliente puede calificar (estrellas + comentario) después de un pedido pagado | `POST /cliente/calificaciones` con validación `pedido.estado == pagado` + `pedido.usuario_id == user` (404 ajeno, 409 no pagado, 409 ya calificado vía `uq_calificacion_pedido`). Modelo `Calificacion` ya existe (CHECK 1-5 + UNIQUE). |
| CALI-02 | La calificación promedio del restaurante es visible en lista y detalle | `list_public_restaurantes` / detalle: LEFT JOIN + `AVG(estrellas)` + `COUNT(*)` agrupado; `RestaurantePublico.calificacion` ya existe (siempre None hoy) + campo nuevo `total_calificaciones: int`. |
| INFR (verificación final) | Deploy a Ubuntu Server (nginx + TLS + WS upgrade + DEMO_MODE=false) | Artefactos: `docker-compose.prod.yml`, `deploy/nginx.conf`, `.env.production.example`, `deploy/README.md` (guía paso a paso). Verificación local production-like con nginx en puerto local. Verificado: nginx.org WS proxying (Upgrade headers + `proxy_http_version 1.1;` requerido en nginx < 1.29.7 — Ubuntu 24.04 trae 1.24). |
</phase_requirements>

## Summary

La fase cierra el ciclo financiero con tres frentes independientes que convergen: (1) **pagos** — una pasarela ABSTRACTA (`PagoGateway` Protocol) con implementación Sandbox local que replica el flujo EXACTO de Wompi (verificado § abajo), de modo que al obtener credenciales reales solo cambien env vars; (2) **calificaciones** — modelo ya existe desde Phase 3, faltan endpoints + agregado público + UI; (3) **deploy** — artefactos production-like completos (compose prod + nginx + TLS + guía Ubuntu) porque NO hay SSH al servidor desde esta máquina.

**El hallazgo más importante del research:** el contrato de la API de Wompi quedó **verificado desde código fuente mantenible** (paquete Laravel `IGedeon/laravel-wompi`, marzo 2026, con tests) tras 3 intentos fallidos contra docs oficiales (403 anti-bot — consistente con research previo). Esto ELEVA la confianza del flujo sandbox de "training data" a MEDIUM-HIGH y valida la decisión pragmática v1: el sandbox puede replicar firma de integridad SHA256, verificación de webhook (`signature.properties` + `checksum` + `timestamp`), y estados de transacción EXACTOS. Detalle crítico descubierto: **el payload del webhook NO trae un `event.id`** — la idempotencia debe deduplicar por clave DERIVADA (`transaction.id + status`), no por un id de evento (design robusto que además funciona con re-entregas).

Segundo hallazgo estructural: **el pago es por SESIÓN, no por pedido**. La cuenta (PAGO-01) es de la sesión y puede abarcar N pedidos; `pago.pedido_id` (NOT NULL, único uso: test de constraint) no modela "el total de mi consumo". Migración 0006: `pago.sesion_id` NOT NULL + `pedido_id` nullable (retrocompatible con el test existente) + `transaction_id` unique nullable + tabla `pago_event` para dedup.

**Primary recommendation:** Implementar `PagoGateway` (Protocol) con `SandboxGateway` (URL checkout local + endpoint aprobar/rechazar que construye el evento FIRMADO y pasa por el MISMO pipeline de verificación del webhook) y `WompiGateway` (URL determinista de Web Checkout — no requiere llamada API para crear la intención). Política de pago simple: **todos los pedidos de la sesión deben estar `servido`** (usa `PEDIDO_TRANSITIONS` sin tocarlas: servido→pagado ya existe). Deploy: **nginx en el HOST de Ubuntu** (no en Docker) con certbot nativo, routing same-origin por paths de la API.

## Restricciones del Entorno (verificadas — el planner DEBE honored)

> No hay CONTEXT.md de discuss; estas restricciones vienen de la realidad del entorno confirmada por el orquestador.

1. **Sin credenciales de pasarela** (KYC pendiente): arquitectura gateway abstracta + `SANDBOX_MODE=true` por defecto. Credenciales reales = solo env vars (`WOMPI_PUBLIC_KEY`, `WOMPI_PRIVATE_KEY`, `WOMPI_EVENTS_SECRET`, `WOMPI_INTEGRITY_SECRET`, `SANDBOX_MODE=false`).
2. **Sin SSH al Ubuntu Server** desde esta máquina: el plan produce ARTEFACTOS + guía; el deploy real lo ejecuta el usuario. Verificación local production-like (nginx en puerto local con el stack prod).
3. **1 worker uvicorn OBLIGATORIO** — `InMemoryBroadcaster` (advertencia ya en docker-compose.yml y broadcaster.py). El deploy prod NO debe añadir `--workers` (rompe WS silenciosamente; Redis es PLT2-02/v2).
4. **Web-first dev en Chrome :5174** para app_cliente (locked Phase 5): el checkout sandbox en `localhost:8000` es alcanzable desde el navegador dev.
5. Wompi sigue siendo la pasarela preferida (STACK.md); la abstracción absorbe el cambio si el usuario termina eligiendo Mercado Pago/PayU.

## El Contrato Wompi (VERIFICADO desde fuente mantenida 2026)

> Fuente: `github.com/IGedeon/laravel-wompi` (paquete Laravel 12, creado mar-2026, con suite de tests) — código fuente completo leído: `IntegritySignatureService.php`, `WebhookSignatureService.php`, `WebhookController.php`, `WompiClient.php`, `Environment.php`, `TransactionStatus.php`, `redirect-form.blade.php`, `WebhookSignatureServiceTest.php`. Docs oficiales (docs.wompi.co) re-verificadas HOY: **siguen 403** (anti-bot) — igual que en el research de stack.

**Confidence: MEDIUM-HIGH** (fuente secundaria mantenida + consistente con training data + tests del paquete ejercitan las firmas). Todo lo que toque dinero real debe re-verificarse contra docs oficiales al obtener credenciales.

### Endpoints y URLs base

| Elemento | Valor | Uso |
|----------|-------|-----|
| Base sandbox | `https://sandbox.wompi.co/v1` | API (crear payment links, consultar transacciones) |
| Base production | `https://production.wompi.co/v1` | Ídem prod |
| Auth API | `Authorization: Bearer <key>` — **public key para GET**, **private key para POST** | Consulta transacciones (reconciliación) |
| Web Checkout (redirect) | `GET https://checkout.wompi.co/p/?public-key=...&currency=COP&amount-in-cents=...&reference=...&signature:integrity=...&redirect-url=...` | **URL DETERMINISTA — no requiere llamada API**. Es un form GET (verificado en `redirect-form.blade.php`) |
| Payment Links API | `POST /payment_links` → checkout URL `https://checkout.wompi.co/l/{id}` | Alternativa (no necesaria para v1 — redirect form basta) |
| Consulta transacción | `GET /transactions/{id}` (public key) | Reconciliación (red de seguridad del webhook) |

### Firma de integridad (crear la intención de pago)

```python
# VERIFICADO — IntegritySignatureService.php (mar-2026)
import hashlib

def firma_integridad(referencia: str, amount_in_cents: int, currency: str,
                     integrity_secret: str, expiration_time: str | None = None) -> str:
    payload = f"{referencia}{amount_in_cents}{currency}"
    if expiration_time is not None:
        payload += expiration_time
    payload += integrity_secret
    return hashlib.sha256(payload.encode()).hexdigest()
```

Concatenación PLANA de strings — sin separadores. `amount_in_cents` como entero sin formato (ej. `"GRI-PAGO-x"5000000"COP" + secret`).

### Webhook `transaction.updated` — estructura y verificación

Estructura del payload (verificada en los tests del paquete):

```json
{
  "event": "transaction.updated",
  "data": {
    "transaction": {
      "id": "txn-001",
      "status": "APPROVED",
      "amount_in_cents": 5000000,
      "currency": "COP",
      "reference": "GRI-PAGO-xxxx",
      "payment_method_type": "PSE",
      "status_message": "..."
    }
  },
  "sent_at": "2018-07-20T16:45:05.000Z",
  "timestamp": 1530291411,
  "signature": {
    "properties": ["transaction.id", "transaction.status", "transaction.amount_in_cents"],
    "checksum": "<sha256-hex>"
  }
}
```

Verificación (verificada — `WebhookSignatureService.php` + su test):

```python
# VERIFICADO — replica exacta del algoritmo del SDK
import hashlib, hmac

def _dig(data: dict, path: str):
    """Dot-path resolver: 'transaction.id' -> data['transaction']['id'] ('' si falta)."""
    for part in path.split("."):
        if not isinstance(data, dict):
            return ""
        data = data.get(part, "")
    return data

def verificar_firma_webhook(payload: dict, events_secret: str) -> bool:
    props = payload.get("signature", {}).get("properties") or []
    checksum = payload.get("signature", {}).get("checksum") or ""
    timestamp = payload.get("timestamp", "")
    if not props or not checksum:
        return False
    values = "".join(str(_dig(payload.get("data", {}), p)) for p in props)
    values += str(timestamp) + events_secret
    computed = hashlib.sha256(values.encode()).hexdigest()
    return hmac.compare_digest(computed, checksum)  # timing-safe
```

**⚠️ NO existe `event.id` en el payload** (verificado): la entrega es at-least-once y la re-entrega no trae id único de evento. El dedup debe usar una **clave derivada**: `transaction.id + transaction.status` (única por entrega lógica). Combinada con la idempotencia natural de la máquina de estados (estado terminal → no-op), cubre PAGO-03.

### Estados de transacción (verificados — `TransactionStatus.php`)

| Estado Wompi | ¿Final? | Mapeo a `EstadoPago` |
|--------------|---------|----------------------|
| `PENDING` | No | `pendiente` (no hacer nada) |
| `APPROVED` | Sí | `aprobado` → disparar efectos |
| `DECLINED` | Sí | `rechazado` |
| `VOIDED` | Sí | `rechazado` (anulada post-aprobación — v1: tratar como rechazado y LOGGEAR; caso raro) |
| `ERROR` | Sí | `rechazado` |

### Env vars (verificadas — coinciden 1:1 con lo propuesto)

```env
WOMPI_ENVIRONMENT=sandbox|production   # → SANDBOX_MODE en nuestro Settings (más simple)
WOMPI_PUBLIC_KEY=pub_test_xxx
WOMPI_PRIVATE_KEY=prv_test_xxx
WOMPI_EVENTS_SECRET=test_events_xxx    # firma del webhook
WOMPI_INTEGRITY_SECRET=test_integrity_xxx  # firma del checkout
```

### Qué queda ASUMIDO (LOW confidence — re-verificar con credenciales)

- Comisiones exactas 2026 (STACK.md: ~2.9% + $900 COP — training data).
- Si el checkout sandbox real (checkout.wompi.co) rechaza referencias con formato custom — irrelevante para v1 (nuestro sandbox es local).
- Comportamiento exacto de `redirect-url` de retorno (append de query params al volver) — la app hace polling de estado, no depende del retorno.
- Tope de `reference` length (nuestro `GRI-PAGO-{uuid8}` ~ 20 chars, seguro).

## Standard Stack

### Backend — CERO dependencias nuevas en runtime crítico

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **hashlib + hmac** | stdlib | SHA256 de firmas + `compare_digest` (timing-safe) | Stdlib — nada que instalar. **Confidence: HIGH** |
| **httpx** | ≥0.28 (YA está en dev-group del lock) | Cliente async para `GET /transactions/{id}` (reconciliación Wompi real) | Promover de dev → prod deps (coste cero, ya versionado en uv.lock). Solo lo usa `WompiGateway` (inerte en sandbox). **Confidence: HIGH** |
| **pydantic-settings** | ya en uso | Nuevas vars: `SANDBOX_MODE`, `WOMPI_*` en `Settings` | Patrón existente (config.py). **Confidence: HIGH** |

### Flutter (app_cliente) — UNA dependencia nueva

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **url_launcher** | ^6.3.2 | Abrir la checkout URL (browser externo en móvil / nueva pestaña en web) | Oficial flutter.dev, Flutter Favorite, 8.1k likes, 5.68M downloads/sem, web+móvil. **Verificado pub.dev HOY. Confidence: HIGH**. Nota web verificada: "launch must be triggered by a user action" — nuestro botón Pagar ES un user action |
| Rating de estrellas | — | **CUSTOM** (Row de 5 IconButtons con `Icons.star`/`star_border`) | Trivial (~40 líneas), cero deps. Ver "Don't Hand-Roll" para el límite |

**NO añadir:** `flutter_rating_bar` (dep innecesaria para 5 estrellas), `webview_flutter` (checkout Wompi es una página hosted — browser externo es el patrón de Web Checkout; WebView añade peso + manejo de permisos).

### Deploy — verificado

| Technology | Version | Purpose | Verified |
|------------|---------|---------|----------|
| **nginx (HOST Ubuntu)** | 1.24 (apt de Ubuntu 24.04) | Reverse proxy + TLS + estáticos del panel | **nginx < 1.29.7 REQUIERE `proxy_http_version 1.1;` explícito para WS** (verificado nginx.org/en/docs/http/websocket.html — el comment del snippet oficial dice "before version 1.29.7"). HIGH |
| **certbot + python3-certbot-nginx** | apt (Ubuntu 24.04) | TLS Let's Encrypt con auto-renew (systemd timer) | Integración nativa `certbot --nginx` — LA razón para nginx en host y no en Docker (evita el reload-dance certbot↔container). HIGH |
| **mysql (prod)** | `mysql:8.4.11` (PIN) | Reproducibilidad | Verificado Docker Hub: 8.4.11 pushed Jul 28 2026 (último patch 8.4 LTS). HIGH |
| **docker compose (prod)** | v2 integrado | Stack mysql + api | Mismo Dockerfile (alembic upgrade head en boot ya cubre INFR-03). HIGH |

## Architecture Patterns

### Patrón 1: Gateway abstracto + Sandbox que ejercita el pipeline REAL

```python
# app/services/gateway_pago.py (nuevo)
from typing import Protocol
from decimal import Decimal

class PagoGateway(Protocol):
    """Contrato de pasarela — v1: SandboxGateway | WompiGateway."""
    nombre: str  # "sandbox" | "wompi" (se persiste en pago.pasarela)

    async def crear_checkout(
        self, *, referencia: str, monto: Decimal, redirect_url: str | None = None
    ) -> str:
        """Devuelve la URL de checkout (relativa si es sandbox local)."""
        ...

    async def consultar_transaccion(self, transaction_id: str) -> dict | None:
        """Reconciliación (red de seguridad). None si no aplica/sandbox."""
        ...

# Selección: settings.SANDBOX_MODE → SandboxGateway | WompiGateway
```

- `SandboxGateway.crear_checkout` → `"/pagos/sandbox/checkout/{referencia}"` (relativa; la app antepone `Env.apiBaseUrl`). `consultar_transaccion` → None.
- `WompiGateway.crear_checkout` → URL determinista del Web Checkout (form GET verificado) con `signature:integrity` = SHA256 concat. `consultar_transaccion` → httpx GET (public key).
- **El sandbox NO es un mock del handler**: `POST /pagos/sandbox/{referencia}/aprobar|rechazar` construye el evento `transaction.updated` COMPLETO con firma válida (`WOMPI_EVENTS_SECRET`) y llama a `pago_service.procesar_webhook(payload)` — la MISMA función del endpoint público. El pipeline de verificación queda ejercitado end-to-end en dev/tests.

### Patrón 2: Flujo de pago de punta a punta

```
Cliente                    Backend                         Pasarela/Sandbox
  │ POST /cliente/pagos/intencion
  │  (sesión activa, sin body)  │
  │                             ├─ valida: sesión activa (404) + TODOS los pedidos
  │                             │  de la sesión en `servido` (409 si no) + ≥1 pedido (409)
  │                             ├─ monto = Σ pedido.total (estado=servido) SERVER-SIDE
  │                             ├─ reutiliza pago `pendiente` existente de la sesión
  │                             │  (idempotencia de intención) o crea:
  │                             │  pago(referencia="GRI-PAGO-{uuid8}", pasarela, sesion_id)
  │ ←─ {pago_id, referencia, monto, estado, checkout_url}
  │
  │ launchUrl(checkout_url) ────┼───────────────────────────→ página de pago
  │                             │
  │                             │ ←─ POST /webhooks/pago (evento FIRMADO)
  │                             ├─ verificar firma (401 si inválida) — SIEMPRE PRIMERO
  │                             ├─ dedup (transaction.id+status) → si visto: 200 no-op
  │                             ├─ localizar pago por referencia (log+200 si desconocida)
  │                             ├─ verificar amount_in_cents == pago.monto*100 (fraud)
  │                             └─ efectos (UNA tx BD — ver Patrón 3) + WS post-commit
  │
  │ GET /cliente/pagos/{id}/estado (polling 2-3s al volver) ─→ aprobado
  └─ UI success → prompt calificación → POST /cliente/calificaciones
```

**Reglas de oro (de PITFALLS P4 + verificación):**
1. **NUNCA confiar en el retorno del checkout** — el pago SOLO se marca por webhook verificado (redirect/polling es UX, no verdad).
2. **Firma primero, todo lo demás después** — payload sin firma válida = 401, sin parseo de negocio.
3. **Webhook responde 200 rápido** — sin lógica pesada; los efectos son una tx BD corta.

### Patrón 3: Efectos del pago aprobado — UNA transacción, WS post-commit

```python
# pago_service.aplicar_pago_aprobado — TODO en una AsyncSession (rollback si algo falla)
async with session.begin():
    # 1. pago: pendiente → aprobado (validar_transicion("pago", ...) — re-entrega = TransicionInvalida → no-op)
    # 2. pedidos de la sesión (estado=servido): servido → pagado  (PEDIDO_TRANSITIONS ya lo permite)
    # 3. sesión: estado=cerrada, cerrada_en=now()  (SESION_TRANSITIONS activa→cerrada)
    # 4. mesa: ocupada → limpieza  (MESA_TRANSITIONS ocupada→limpieza — ya válida)
# post-commit (fuera de la tx — patrón emit_event existente):
await emit_event("pago.estado", usuario_id=dueño, data={"pago_id", "estado": "aprobado"})
await emit_event("sesion.cerrada", usuario_id=dueño, ...)   # la app 07-03 YA maneja este evento
for pedido in pagados: await emit_event("pedido.estado", ...)  # staff room + user room
await emit_event("mesa.estado", restaurante_id=rid, data={"mesa_id", "estado": "limpieza"})
```

- La cola de cocina (`cola_activos` con `FIELD(estado, 'enviado','aceptado','en_preparacion','servido')`) excluye `pagado` automáticamente — el pedido desaparece de la cola al pagarse, sin cambios.
- Reportes 08-02 definieron venta = `servido|pagado` → el efecto es consistente con reportes existentes.
- **Política de estado previo (decidida, simple):** pagar exige TODOS los pedidos de la sesión en `servido`. Cero cambios a `PEDIDO_TRANSITIONS`; rechazados quedan excluidos del total; sesión sin pedidos → 409 "no hay nada que pagar".

### Patrón 4: Migración 0006 — pago por sesión + dedup de eventos

```
ALTER pago:
  + sesion_id BIGINT NOT NULL FK(sesion_mesa.id) INDEX  (la cuenta es de la SESIÓN)
  + transaction_id VARCHAR(100) NULL UNIQUE            (id externo de la transacción)
  + pedido_id → NULLABLE (retrocompatible; NO se escribe más)
CREATE pago_event (                                    (dedup at-least-once)
  id PK, event_key VARCHAR(150) UNIQUE NOT NULL,       -- f"{transaction_id}:{status}"
  pago_id BIGINT NULL FK(pago.id),
  payload JSON/TEXT, recibido_at DATETIME, procesado BOOLEAN DEFAULT 1
)
```

- `event_key` UNIQUE es la defensa de BD (IntegrityError → ya procesado → 200 no-op), igual que `uq_sesion_mesa_activa` ganó la carrera en Phase 6.
- `pago_event` también sirve de auditoría (qué eventos llegaron, cuándo).
- El test existente `test_pago_referencia_unique` sigue pasando (pasa `pedido_id` — ahora nullable, lo acepta; `sesion_id` requiere valor → el test se ACTUALIZA para pasar sesion_id del seed chain).

### Patrón 5: Endpoints nuevos (contrato)

| Endpoint | Auth | Comportamiento |
|----------|------|----------------|
| `POST /cliente/pagos/intencion` | cliente | Body vacío (usa la sesión activa). 201/200 (reutiliza pendiente) · 404 sin sesión · 409 pedidos no servidos / sesión sin pedidos · 409 pedido ya pagado (sessión cerrada). Devuelve `{pago_id, referencia, monto, estado, checkout_url}` |
| `GET /cliente/pagos/{pago_id}/estado` | cliente | Polling post-checkout. 404 ajeno/inexistente (existence hiding). Si `pendiente` y gateway=wompi y edad > 2 min → reconciliación lazy (consultar_transaccion + reprocesar) |
| `POST /webhooks/pago` | **PÚBLICO** | 401 firma inválida/ausente · 200 dedup/conocido/no-op · 200 efectos aplicados. Sin Depends de auth |
| `GET /pagos/sandbox/checkout/{referencia}` | **PÚBLICO, SOLO SANDBOX_MODE=true** | HTML mínimo (total, referencia, botones Aprobar/Rechazar). 404 si SANDBOX_MODE=false (router no montado) |
| `POST /pagos/sandbox/{referencia}/aprobar` | ídem | Construye evento firmado → `procesar_webhook` (MISMO pipeline) → redirect a la página con resultado |
| `POST /pagos/sandbox/{referencia}/rechazar` | ídem | Ídem con status DECLINED |
| `POST /cliente/calificaciones` | cliente | `{pedido_id, estrellas 1-5 (Pydantic ge/le + DB CHECK), comentario?}`. 201 · 404 pedido ajeno/inexistente · 409 pedido no pagado · 409 ya calificado (IntegrityError→409, patrón reserva) |

`/public/restaurantes` y `/public/restaurantes/{id}` (sin cambios de contrato salto campo nuevo): `calificacion: float | None` ahora poblado (round 1 decimal) + `total_calificaciones: int` (0 si None) — LEFT JOIN + GROUP BY o subquery correlacionada; con 1-2 restaurantes demo, cualquier forma es correcta (sin N+1: 1 query extra).

### Patrón 6: Flutter cliente — pago, retorno, calificación

```
lib/features/pago/
  pago_screen.dart        # total (de intencion), botón "Pagar" → launchUrl, polling estado
  pago_controller.dart    # intencion() → launchUrl(externalApplication) → poll cada 2.5s
  calificacion_sheet.dart # bottom sheet post-pago: 5 estrellas custom + comentario + enviar
lib/models/pago.dart      # freezed (PagoCreate no existe — solo Read + estado enum)
lib/models/calificacion.dart
```

- **launch:** `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)` — móvil: browser del sistema; web: nueva pestaña (verificado url_launcher). Fallback si `launchUrl` retorna false → SnackBar con la URL copiable.
- **retorno:** no hay deep-link en v1 — al volver a la app (App Lifecycle resumed / re-navegación), el polling de `GET /cliente/pagos/{id}/estado` (Timer 2.5s mientras la pantalla visible) revela `aprobado`/`rechazado`. El WS `pago.estado`/`sesion.cerrada` llega por el canal existente como vía rápida (la pantalla escucha ambos; polling es el safety net — mismo patrón pollSafetyNet de 07-03).
- **estrellas custom:** `Row(mainAxisSize: min, children: [for i in 1..5 IconButton(icon: i<=valor ? Icon(Icons.star) : Icon(Icons.star_border))])` — cero deps.
- **lista restaurantes:** `⭐ 4.8 (245)` cuando `total_calificaciones > 0`; `"—"` si 0 (columna existente — solo cambia el source del dato).
- **models regen:** `Restaurante` gana `total_calificaciones` (additive — regen freezed/json).

### Patrón 7: Deploy — routing same-origin por paths (nginx HOST)

**Decisión: nginx en el HOST de Ubuntu** (apt) con certbot nativo — no contenedor. Razones: `certbot --nginx` gestifica certificado + reload + auto-renew (systemd timer) sin coreografía docker exec; el stack Docker queda solo mysql+api (mismo Dockerfile/dev shape). El artefacto `deploy/nginx.conf` se copia a `/etc/nginx/sites-available/gri` + symlink.

```nginx
# deploy/nginx.conf — VERIFICADO contra nginx.org/en/docs/http/websocket.html
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {  # 80 → redirect 443 (certbot maneja el challenge antes del redirect)
    server_name gri.example.com;   # PLACEHOLDER — usuario reemplaza
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl;
    http2 on;
    server_name gri.example.com;

    ssl_certificate     /etc/letsencrypt/live/gri.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gri.example.com/privkey.pem;

    # --- API (routers FastAPI montados en RAÍZ — sin prefijo /api) ---
    location /ws/ {  # WebSocket — los 3 headers son OBLIGATORIOS
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;              # REQUERIDO en nginx < 1.29.7 (Ubuntu 24.04 = 1.24)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 3600s;            # default 60s mataría WS idle (ping uvicorn 20s igual lo resetea)
        proxy_set_header Host $host;
    }
    location ~ ^/(auth|public|cliente|staff|admin|health|docs|openapi\.json|redoc|webhooks|pagos) {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 5m;
    }
    # --- Panel admin (estáticos Flutter Web) + SPA fallback ---
    location / {
        root /var/www/gri-panel;   # panel_admin/build/web copiado acá
        try_files $uri $uri/ /index.html;   # SPA: cualquier ruta profunda → index
        location ~* \.(js|json|png|jpg|svg|wasm|otf|ttf)$ {
            root /var/www/gri-panel;
            expires 7d; add_header Cache-Control "public";
        }
    }
}
```

- **Same-origin = CERO CORS para el panel** (la decisión de routing más simple: un dominio, un certificado). `CORS_ORIGINS=https://gri.example.com` igual se setea (defensa + app cliente web dev).
- Colisión paths: el panel genera `/assets/`, `/main.dart.js`, `/manifest.json`… los prefixes de la API (`/auth`, `/public`…) no colisionan; nginx longest-prefix gana siempre.
- **Verificación local production-like** (sin Ubuntu): `docker compose -f docker-compose.prod.yml up` con nginx conf adaptado a puerto local 8080 (sin ssl) + build web del panel → smoke: health, panel carga, WS conecta, login.
- `docker-compose.prod.yml`: `mysql:8.4.11` SIN ports expuestos (solo interno), api sin `--workers`, `restart: unless-stopped`, `env_file: .env.production`, `DEMO_MODE=false`, volumen MySQL persistente.

### Anti-Patterns to Avoid

- **Marcar pagado en el redirect/retorno del checkout** — doble cobro/fraude garantizado (PITFALLS P4). Solo webhook verificado.
- **`--workers N` en prod** — broadcaster in-memory rompe silenciosamente (documentado en compose/broadcaster).
- **Dedup por `event.id`** — NO EXISTE en el payload Wompi (verificado). Usar clave derivada.
- **Pagar por `pedido_id` individual** — la cuenta es de la SESIÓN (N pedidos). `pago.sesion_id`.
- **Montos del cliente** — `monto` = Σ totals server-side; además verificar `amount_in_cents` del webhook contra `pago.monto * 100` (mismatch = alerta fraude, no aplicar).
- **nginx sin `proxy_http_version 1.1`** — WS muere en handshake detrás de Ubuntu nginx 1.24.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Comparación de firmas | `==` sobre strings | `hmac.compare_digest` | Timing-safe; comparación plana filtra timing attacks |
| Verificación de webhook | Parser custom "confiado" | El algoritmo `signature.properties`+`timestamp`+secret verificado (arriba) | Es el contrato real de Wompi — inventar otro = incompatibilidad al conectar prod |
| Widget de estrellas | — | Custom Row de IconButtons | ~40 líneas; una dep para esto es scope creep |
| Job de reconciliación periódico (v1) | Celery/APScheduler/timers | Reconciliación LAZY en `GET .../estado` (si pendiente > 2 min) | v1 sandbox entrega webhook local confiable; el poll del cliente dispara la consulta. Un scheduler es infra nueva sin requisito |
| TLS termination | Certificados manuales / self-signed scripts | certbot `--nginx` + systemd timer | Auto-renew resuelto por el paquete de Ubuntu |
| SPA fallback del panel | Hash routing / server logic | `try_files ... /index.html` | Estándar nginx para SPAs |

**Key insight:** TODO lo difícil de pagos (idempotencia, firmas, estados) ya tiene patrón probado en este codebase (constraints UNIQUE como defensa, `validar_transicion` 409, emisión post-commit) o algoritmo verificado arriba. La fase es ENSAMBLAR patrones existentes, no inventar.

## Common Pitfalls

### Pitfall 1: Webhook procesado sin firma (fraude)
**What:** POST falso `APPROVED` a `/webhooks/pago` → comida gratis.
**Avoid:** Firma PRIMERO (401), `hmac.compare_digest`, `WOMPI_EVENTS_SECRET` obligatorio (sin default vacío en prod — Settings valida). Test: firma inválida → 401 y CERO efectos.
**Warning signs:** handler que hace negocio antes de verificar; secret con default "".

### Pitfall 2: Doble procesamiento del webhook (at-least-once)
**What:** Wompi reenvía el evento → efectos duplicados (o errores 500 por transición inválida).
**Avoid:** (a) `pago_event.event_key` UNIQUE (IntegrityError → 200 no-op), (b) estado terminal: `aprobado` es terminal en `PAGO_TRANSITIONS` → segunda entrega levanta `TransicionInvalidaError` que el handler captura como no-op 200 (NO 500 — Wompi reintenta ante 5xx). Test: mismo evento 2× → exactamente 1 set de efectos.

### Pitfall 3: Sandbox expuesto en producción
**What:** `/pagos/sandbox/*` accesible en prod = cualquiera "aprueba" pagos.
**Avoid:** El router sandbox se monta condicionalmente (`if settings.SANDBOX_MODE`) → en prod las rutas NO EXISTEN (404 real). Test: con SANDBOX_MODE=false → 404.

### Pitfall 4: nginx mata el WebSocket a los 60s
**What:** Conexiones `/ws/*` se cortan tras 60s idle (default `proxy_read_timeout`); mapa/panel muestran estado stale hasta reconnect.
**Avoid:** Los 3 headers + `proxy_http_version 1.1` + `proxy_read_timeout 3600s` (verificado nginx.org: default 60s cierra si el backend no transmite; el ping protocolar de uvicorn cada 20s también resetea el timer). Verificación local: WS conectado tras >60s sigue recibiendo eventos.

### Pitfall 5: `amount_in_cents` mismatch no verificado
**What:** Webhook legítimo en firma pero con monto distinto (transacción de OTRO comercio/referencia colisionada) aplica efectos parciales.
**Avoid:** Verificar `transaction.amount_in_cents == int(pago.monto * 100)` y `transaction.reference == pago.referencia` ANTES de efectos; mismatch → log + 200 sin efectos (y alerta en `pago_event`). COP no tiene decimales en la práctica — `Decimal * 100` exacto.

### Pitfall 6: SESIÓN cerrada pero calificación imposible
**What:** Tras el pago, `GET /cliente/sesiones/actual` → 404 (sesión cerrada) — la app ya no sabe qué pedido calificar.
**Avoid:** La respuesta de `pago.estado` (y el WS `pago.estado`) incluye `pedido_ids: [...]` de los pedidos pagados → el sheet de calificación usa el último. El endpoint de calificación valida por `pedido_id` directo (no requiere sesión activa).

### Pitfall 7: Certbot + nginx-in-Docker reload dance
**What:** nginx en contenedor + certbot en host → cert en volumen docker, reload cross-boundary, renewals fallan silenciosas.
**Avoid:** nginx en HOST (decisión ya tomada, Patrón 7). `certbot --nginx -d gri.example.com` una vez; systemd timer renueva.

### Pitfall 8: Flutter web — launch bloqueado sin user gesture
**What:** `launchUrl` programático (sin tap) es bloqueado por algunos browsers.
**Avoid:** El launch SOLO ocurre en el onPressed del botón "Pagar" (user action — verificado readme url_launcher).

## Code Examples

### Settings nuevos (patrón config.py existente)

```python
# app/core/config.py — aditivo
SANDBOX_MODE: bool = True          # v1 sin credenciales; prod = false
WOMPI_PUBLIC_KEY: str = "pub_test_dev"
WOMPI_PRIVATE_KEY: str = "prv_test_dev"
WOMPI_EVENTS_SECRET: str = "dev-events-secret"      # firma webhook (sandbox local)
WOMPI_INTEGRITY_SECRET: str = "dev-integrity-secret" # firma checkout
# Validación en lifespan: si ENVIRONMENT=production y SANDBOX_MODE=true → LOG WARNING fuerte
```

### Handler del webhook (forma canónica)

```python
@router.post("/webhooks/pago")
async def webhook_pago(payload: dict, session: AsyncSession = Depends(get_session)):
    # 1. FIRMA PRIMERO — sin firma válida no hay negocio
    if not verificar_firma_webhook(payload, settings.WOMPI_EVENTS_SECRET):
        raise HTTPException(401, "Firma inválida")
    # 2. Dedup BD (event_key UNIQUE) → IntegrityError = ya procesado → 200
    try:
        resultado = await pago_service.procesar_webhook(session, payload)
        return {"status": "procesado", **resultado}
    except TransicionInvalidaError:
        return {"status": "ya-procesado"}   # re-entrega sobre estado terminal: 200, NUNCA 409/500
```

### Sandbox aprobar (ejercita el pipeline completo)

```python
async def aprobar_sandbox(session, referencia: str) -> Pago:
    pago = ...  # por referencia, debe estar pendiente
    event = {
        "event": "transaction.updated",
        "data": {"transaction": {"id": f"sandbox-{referencia}", "status": "APPROVED",
                                 "amount_in_cents": int(pago.monto * 100),
                                 "currency": "COP", "reference": referencia}},
        "sent_at": utc_now_iso(), "timestamp": int(time.time()),
        "signature": _firmar_evento_sandbox(...),  # properties+checksum con EVENTS_SECRET
    }
    return await pago_service.procesar_webhook(session, event)  # MISMO pipeline
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Wompi contrato = training data MEDIUM | Contrato verificado desde SDK mantenido mar-2026 (firmas, estados, URLs) | Este research | Sandbox replica el flujo EXACTO; confianza MEDIUM-HIGH |
| `pago.pedido_id` (Phase 3 shape) | `pago.sesion_id` (la cuenta es de la sesión) | Migración 0006 | Modela "total de mi consumo" (N pedidos) correctamente |
| Dedup webhook por `event.id` (asunción) | Sin `event.id` en payload (verificado) → clave derivada `txn_id:status` | Este research | Diseño de idempotencia correcto desde el día 1 |
| nginx WS snippet sin `proxy_http_version` | `proxy_http_version 1.1` obligatorio < 1.29.7 | nginx 1.29.7 (2026) | Ubuntu 24.04 (1.24) lo REQUIERE explícito |

## Open Questions

1. **Dominio real de producción**
   - What we know: placeholder `gri.example.com` en todos los artefactos.
   - Recommendation: el plan usa placeholders; el usuario reemplaza al ejecutar la guía (documentado en deploy/README.md).

2. **VOIDED post-aprobación (Wompi)**
   - What we know: VOIDED es final; puede llegar DESPUÉS de APPROVED (anulación).
   - Recommendation v1: tratar VOIDED como `rechazado` si el pago estaba pendiente; si ya estaba aprobado → log en `pago_event` SIN revertir efectos (reembolso es operación manual fuera de scope v1). Documentar en el handler.

3. **Comisiones y métodos exactos 2026**
   - LOW confidence (training data ~2.9% + $900). No bloquea nada técnico. Verificar al abrir cuenta real.

4. **`flutter_secure_storage` en Web requiere HTTPS** (nota 04-RESEARCH)
   - Resuelto por el propio deploy (TLS en prod). En dev localhost funciona (secure context de localhost). Sin acción.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Backend | pytest 8 + pytest-asyncio (asyncio_mode=auto), ya configurado en `backend/pyproject.toml`. Tests de integración contra stack Docker VIVO (`httpx` → localhost:8000) + `db_session` directo asyncmy |
| Backend quick run | `docker compose up -d ; cd backend ; uv run pytest tests/test_pagos.py -x` |
| Backend full suite | `cd backend ; uv run pytest` (181 tests actuales — suite entera < 2 min) |
| Flutter | `flutter test` (app_cliente ~41 tests de fases previas) |
| Panel | `flutter test` panel_admin (~61 tests) — SIN cambios esta fase (solo build web para deploy) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PAGO-02 | Intención crea pago pendiente con monto server-side + checkout_url | integration | `uv run pytest tests/test_pagos.py -x` | ❌ Wave 0 |
| PAGO-02 | 409 si pedidos no servidos / sin pedidos; 404 sin sesión; reutiliza pendiente (idempotencia intención) | integration | ídem | ❌ Wave 0 |
| PAGO-03 | Webhook firma inválida → 401 + CERO efectos | integration | `uv run pytest tests/test_webhook_pago.py -x` | ❌ Wave 0 |
| PAGO-03 | Mismo evento 2× → exactamente 1 set de efectos (dedup + terminal no-op 200) | integration | ídem | ❌ Wave 0 |
| PAGO-03 | amount_in_cents mismatch → sin efectos + log | integration | ídem | ❌ Wave 0 |
| PAGO-04 | Webhook APPROVED → pedidos pagado + sesión cerrada + mesa limpieza (misma tx) + WS emitidos | integration (+assert WS via estado BD) | ídem | ❌ Wave 0 |
| PAGO-02/03/04 | E2E sandbox: intencion → checkout page → aprobar → efectos completos | integration | `uv run pytest tests/test_pago_sandbox.py -x` | ❌ Wave 0 |
| PAGO-03 | SANDBOX_MODE=false → rutas sandbox 404 | integration | ídem | ❌ Wave 0 |
| CALI-01 | POST calificación happy path; 404 ajeno; 409 no pagado; 409 duplicada; 422 rango | integration | `uv run pytest tests/test_calificaciones.py -x` | ❌ Wave 0 |
| CALI-02 | /public/restaurantes devuelve AVG correcto + count; sin calificaciones → None/0 | integration | `uv run pytest tests/test_public_read.py -x` (extender) | ✅ (extender) |
| INFR | compose prod levanta local: health OK, panel sirve index.html, WS conecta tras >60s | smoke manual+script | `docker compose -f docker-compose.prod.yml up -d` + `deploy/verify_local.ps1` | ❌ Wave 0 |
| PAGO-02 UI | pago_screen: render total → aprobar (mock) → success; rechazado → error state | widget | `flutter test test/pago/` | ❌ Wave 0 |
| CALI-01 UI | calificacion_sheet: tap 4 estrellas → envía con pedido correcto | widget | `flutter test test/pago/calificacion_test.dart` | ❌ Wave 0 |
| CALI-02 UI | lista restaurantes muestra ⭐ 4.8 (245) con datos mock; "—" con 0 | widget | `flutter test test/restaurantes/` (extender) | ✅ (extender) |

### Sampling Rate
- **Per task commit:** suite del archivo nuevo (`uv run pytest tests/test_pagos.py -x` etc.) + `flutter test` del feature tocado
- **Per wave merge:** `uv run pytest` completo (backend) + `flutter test` (app_cliente)
- **Phase gate:** suite completa verde ×2 corridas consecutivas (patrón 06-01) + verificación local production-like del stack prod

### Wave 0 Gaps
- [ ] `backend/tests/test_pagos.py`, `test_webhook_pago.py`, `test_pago_sandbox.py`, `test_calificaciones.py` — nuevos
- [ ] `docker-compose.yml` dev: añadir `SANDBOX_MODE: true` + `WOMPI_EVENTS_SECRET` al env de api (los tests sandbox los necesitan)
- [ ] conftest: helper `abrir_sesion_con_pedido_servido(client, token, qr)` (fixture de cuenta lista para pagar)
- [ ] Cleanup pattern (lección 06-01): borrar pagos/pago_event/calificaciones creados por tests en orden FK inverso
- [ ] `deploy/verify_local.ps1` (o .sh) — smoke del stack prod local
- [ ] Flutter: `test/pago/` directorio + models regen (build_runner) tras añadir `total_calificaciones`

## Sources

### Primary (HIGH confidence)
- **Codebase GRI** (leído completo hoy): models pago/calificacion/sesion_mesa/pedido, `state_machines.py` (PAGO/SESION/MESA/PEDIDO_TRANSITIONS), `broadcaster.py`/`emit_event` (eventos existentes: mesa.estado, sesion.abierta/cuenta/cerrada, pedido.creado/estado), `config.py`, `docker-compose.yml`, `Dockerfile`, `public_service.py` (calificacion=None hoy), `api/ws.py`, `tests/conftest.py`, `test_domain_constraints.py` (uso actual de Pago/Calificacion), app_cliente `pubspec.yaml`/`env.dart`/`api_client.dart`
- **nginx.org/en/docs/http/websocket.html** — patrón oficial WS proxy: map `$http_upgrade`, `proxy_set_header Upgrade/Connection`, default 60s `proxy_read_timeout`, y `proxy_http_version 1.1` requerido antes de 1.29.7 (Ubuntu 24.04 = nginx 1.24)
- **pub.dev/packages/url_launcher** — 6.3.2, verified publisher flutter.dev, Flutter Favorite, 5.68M downloads/sem, plataformas web+móvil, limitación "user action" en web
- **hub.docker.com (API tags mysql)** — 8.4.11 pushed 2026-07-28 (pin prod); rama 8.4 LTS

### Secondary (MEDIUM-HIGH confidence — contrato Wompi)
- **github.com/IGedeon/laravel-wompi** (Laravel 12, mar-2026, con CI tests) — leídos: `IntegritySignatureService` (SHA256 concat ref+cents+currency+[exp]+secret), `WebhookSignatureService` + su test (properties dot-path + timestamp + events_secret + checksum, hash_equals; payload SIN event.id), `WebhookController` (data.transaction, respuesta 204), `WompiClient`/`Environment` (sandbox/production.wompi.co/v1, public=GET/private=POST), `TransactionStatus` (PENDING/APPROVED/DECLINED/VOIDED/ERROR), `redirect-form.blade.php` (form GET a checkout.wompi.co/p/ con signature:integrity), README (env vars WOMPI_*, payment links /l/{id})
- **docs.wompi.co** — re-verificado HOY: sigue HTTP 403 (anti-bot). Coherente con STACK.md/PITFALLS.md

### Tertiary (LOW confidence)
- Comisiones 2026 (~2.9% + $900 COP) — training data, verificar al abrir cuenta
- Comportamiento exacto del redirect-url de retorno de checkout.wompi.co — irrelevante para v1 (polling, no redirect-truth)

## Metadata

**Confidence breakdown:**
- Arquitectura interna (gateway/endpoints/migración/efectos/WS): **HIGH** — ensambla patrones ya probados en el codebase (UNIQUE-defense, validar_transicion, emit post-commit)
- Contrato Wompi: **MEDIUM-HIGH** — fuente secundaria mantenida mar-2026 con tests, consistente con training data; docs oficiales inaccesibles (403)
- Idempotencia/firmas: **HIGH** — algoritmos verificados + defensa de BD + no-op terminal
- Deploy nginx/TLS: **HIGH** — patrón oficial nginx.org verificado; certbot nativo Ubuntu estándar
- Comisiones/métodos 2026: **LOW** — no bloquea implementación

**Research date:** 2026-08-14
**Valid until:** 2026-09-14 (estable; re-verificar contrato Wompi al obtener credenciales reales)
