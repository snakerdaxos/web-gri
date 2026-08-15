---
phase: 09-pagos-calificaciones-y-deploy
verified: 2026-08-15T03:11:55Z
status: passed
score: 5/5 must-haves verified
human_verification:
  - test: "Pase visual del flujo de pago en la app (flutter run -d chrome --web-port 5174)"
    expected: "Login → escanear QR de mesa disponible → 2 productos → enviar → avanzar a servido en panel → 'Pedir la cuenta' → 'Pagar en línea 💳' → aprobar en sandbox → ✅ en ≤3s → calificar 5★ → '⭐ X.X (1)' en tab Restaurantes"
    why_human: "Experiencia visual/UX del checkout en navegador real + polling en vivo — no verificable programáticamente"
  - test: "Checkout REAL con Wompi (cuando el KYC del restaurante esté aprobado)"
    expected: "SANDBOX_MODE=false + 4 keys WOMPI_* en .env.production → flujo idéntico con dinero real; webhook https://{dominio}/webhooks/pago configurado en dashboard Wompi"
    why_human: "Requiere credenciales merchant reales (KYC pendiente — limitación v1 documentada en 09-VALIDATION y deploy/README §12)"
  - test: "Deploy real en Ubuntu Server 24.04 (DNS A → IP, ufw 80/443, certbot --nginx)"
    expected: "https://{dominio} sirve panel + API + WS con TLS; /pagos/sandbox/* → 404; migraciones corren en boot"
    why_human: "Requiere servidor real con SSH — post-fase manual según plan 09-04 (sin SSH desde esta máquina). Guía completa en deploy/README.md §1-§12"
---

# Phase 9: Pagos, Calificaciones y Deploy — Verification Report

**Phase Goal:** El ciclo financiero cierra: pago en línea idempotente que libera la mesa, calificación post-pago visible en discover, y despliegue a producción en Ubuntu Server
**Verified:** 2026-08-15T03:11:55Z
**Status:** PASSED
**Re-verification:** No — verificación inicial

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Cliente paga en línea el total (sandbox e2e: checkout → aprobar → aprobado) | ✓ VERIFIED | E2E curl 15/15 contra stack dev real: login carlos@demo.gri.dev → sesión GRI-MESA-004 → pedido 2× Arepa ($22.000) → cocina avanza a servido → cuenta → `POST /cliente/pagos/intencion` → **monto 22000.0 calculado server-side** (coincide con total del pedido — body jamás trae montos) + checkout_url → GET HTML contiene ref+monto → POST aprobar → **303** → `GET /cliente/pagos/{id}` → **aprobado + pedido_ids=[2532]**. UI wired: botón "Pagar en línea 💳" (`pedido_estado_screen.dart:185` → `context.push('/mesa/pago')`) → GoRoute `/mesa/pago` (`app.dart:63`) → PagoScreen con launcher inyectable + polling 2.5s. Flutter **51/51 tests + analyze 0 issues** |
| 2 | Idempotencia: webhook duplicado no doble-cobra (dedup txn:status + FOR UPDATE) | ✓ VERIFIED | **HARD GATES 3/3 PASSED**: `test_firma_integridad_vector_conocido`, `test_firma_invalida_401_cero_efectos`, `test_dedup_mismo_evento_dos_veces`. Código: `event_key=f"{txn_id}:{txn_status}"` UNIQUE (`pago_service.py:259`), `select(Pago).with_for_update()` serializa concurrentes (`:252`), firma PRIMERA timing-safe `hmac.compare_digest` → 401 antes de negocio (`webhooks.py:34-36`), `IntegrityError`/`TransicionInvalidaError` → **200 no-op, jamás 500** (`webhooks.py:41-46`). E2E paso 15: re-entrega (re-aprobar) → no-op sin 500 ni efectos dobles |
| 3 | Pago aprobado → pedidos pagados + sesión cerrada + mesa limpieza (misma tx + WS) | ✓ VERIFIED | E2E: `pedido_ids=[2532]` (servido→pagado), **mesa 4 → limpieza** (GET /staff/mesas), **sesión cerrada** (GET /cliente/sesiones/actual → 404). Código `aplicar_pago_aprobado` (`pago_service.py:323-368`): UNA transacción (pago aprobado + pedidos servido→pagado + sesión `cerrada`+`cerrada_en` + mesa `limpieza`) con `validar_transicion` por state machine + emisiones WS post-commit (`pedido.estado`×N → `sesion.cerrada` → `mesa.estado` → `pago.estado`, líneas 337-406). Cubierto además por tests e2e `test_pago_sandbox.py` con assert WS |
| 4 | Calificación post-pago (5★ + comentario) → promedio visible en /public | ✓ VERIFIED | E2E: `POST /cliente/calificaciones {pedido_id, 5★, comentario}` → **201**; `GET /public/restaurantes` → **calificacion=5.0, total_calificaciones=1**. Backend: `calificacion_service.py` (solo pedidos pagados propios: 404 ajeno existence-hiding, 409 ya calificado vía UNIQUE, 422 rango) + AVG+COUNT en `public_service` lista y detalle. UI: `CalificacionSheet` (5 IconButtons star + TextField) wired desde PagoScreen éxito (`pedidoIds.last`); `ratingLabel` "X.X (N)" | "—" en lista (`:145`) + detalle (`:103`) + home (`:98`); `totalCalificaciones @Default(0)` con JSON gen |
| 5 | Deploy artifacts: compose prod + nginx (WS upgrade) + guía Ubuntu + validación local production-like | ✓ VERIFIED | `docker compose --env-file .env.production.example -f deploy/docker-compose.prod.yml config -q` → **OK sin warnings**. Compose endurecido: `mysql:8.4.11` pin exacto, **SIN ports en mysql**, api solo `127.0.0.1:8000`, `DEMO_MODE/SANDBOX_MODE: "false"` + `ENVIRONMENT: production` **hardcodeados** (no interpolables del .env — defense-in-depth), sin `--workers` (broadcaster in-memory). `nginx/gri.conf`: `map $http_upgrade` + `proxy_http_version 1.1` + `Upgrade`/`Connection` headers + `proxy_read_timeout 3600s` (WS), TLS :443 con http2 portable a nginx 1.24, redirect :80, API regex → 127.0.0.1:8000, panel SPA `try_files` + cache 7d. `README.md` 207 líneas, 12 secciones + apéndice (Docker→secretos→nginx→certbot→verificación→operación→troubleshooting). Validación local production-like **6/6** ejecutada por 09-04 (sandbox 404 real en prod, WS con JWT a través del proxy nginx, panel SPA, migraciones en boot) — reportada en SUMMARY con evidencia |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `backend/alembic/versions/0006_pago_sesion_eventos.py` | ✓ VERIFIED | 100 líneas; `alembic current`=0006 confirmado por SUMMARY 09-01 |
| `backend/app/core/gateways/{base,wompi_gateway,sandbox_gateway,__init__}.py` | ✓ VERIFIED | 29/136/28/15 líneas; Protocol + factory `get_pago_gateway()` según SANDBOX_MODE |
| `backend/app/services/pago_service.py` | ✓ VERIFIED | 359 líneas; FOR UPDATE + event_key + aplicar_pago_aprobado atómico |
| `backend/app/api/webhooks.py` | ✓ VERIFIED | 41 líneas; firma-primera 401, IntegrityError→200, jamás 500 |
| `backend/app/api/pagos.py` | ✓ VERIFIED | 166 líneas; intención/estado + sandbox_router con `_sandbox_guard()` 404 por-request |
| `backend/app/services/calificacion_service.py` + `schemas/calificacion.py` | ✓ VERIFIED | 64/21 líneas |
| `backend/tests/test_{pagos,webhook_pago,pago_sandbox,calificaciones}.py` | ✓ VERIFIED | 291/345/155/166 líneas; suite completa **215/215 passed** (84s) |
| `app_cliente/lib/features/pagos/{pago_controller,pago_screen,calificacion_sheet}.dart` | ✓ VERIFIED | 166/398/162 líneas; wired: route + botón + launcher + polling |
| `app_cliente/lib/models/pago.dart` + ApiClient (3 métodos) | ✓ VERIFIED | crearIntencionPago/getPagoEstado/crearCalificacion (`api_client.dart:227,237,245`) |
| `deploy/docker-compose.prod.yml` | ✓ VERIFIED | 95 líneas; config -q OK |
| `deploy/nginx/gri.conf` + `local-verify.conf` | ✓ VERIFIED | 89/49 líneas; WS upgrade completo |
| `deploy/README.md` + `verify_local.ps1` + `verify_ws.py` + `.env.production.example` | ✓ VERIFIED | 207/125/54/54 líneas |

**Wiring (Level 3):** Todos los artefactos clave están conectados — verificado por greps: GoRoute `/mesa/pago` en `app.dart`, `context.push('/mesa/pago')` desde `_cuentaSection` (`pedido_estado_screen.dart:185`), `pagoLauncherProvider` usado en `pago_controller.dart:155`, `CalificacionSheet` instanciado en `pago_screen.dart:77`, `ratingLabel` renderizado en 3 screens, routers montados en `main.py` (pagos siempre + sandbox condicional `if settings.SANDBOX_MODE` con warning lifespan prod).

### Key Link Verification

| From | To | Via | Status |
|------|----|----|--------|
| PagoScreen | POST /cliente/pagos/intencion | `crearIntencionPago()` en `iniciar()` postFrameCallback | ✓ WIRED (e2e paso 7) |
| Sandbox aprobar | procesar_webhook REAL | `_sandbox_resolver` → `_construir_evento` firmado → MISMO pipeline | ✓ WIRED (e2e pasos 9-10: 303 → aprobado) |
| Webhook APPROVED | pedidos+sesion+mesa+WS | `aplicar_pago_aprobado` UNA tx + emits post-commit | ✓ WIRED (e2e pasos 10-12) |
| PagoScreen éxito | POST /cliente/calificaciones | `CalificacionSheet(pedidoId: pedidoIds.last)` → `crearCalificacion` | ✓ WIRED (e2e paso 13) |
| /public/restaurantes | AVG calificaciones | `public_service` LEFT JOIN + AVG + COUNT | ✓ WIRED (e2e paso 14) |
| main.py | sandbox_router | `if settings.SANDBOX_MODE` + guard por-request | ✓ WIRED (grep main.py:71-72) |
| nginx /ws/ | api 127.0.0.1:8000 | map Upgrade + http_version 1.1 + timeout 3600s | ✓ WIRED (verify_ws 6/6 en 09-04) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PAGO-02 | 09-01, 09-03 | Pagar en línea el total del consumo | ✓ SATISFIED | Sandbox e2e completo (backend+UI); Wompi real pendiente KYC (limitación v1 documentada — README §12) |
| PAGO-03 | 09-01 | Idempotencia: sin doble cobro ni estados corruptos | ✓ SATISFIED | HARD GATES dedup/firma 3/3 + FOR UPDATE + no-op terminal 200 + re-entrega e2e sin efectos |
| PAGO-04 | 09-01 | Pago confirmado → mesa limpieza + sesión cerrada | ✓ SATISFIED | E2e pasos 11-12 + misma transacción + WS post-commit (tests con assert WS) |
| CALI-01 | 09-02, 09-03 | Calificar (estrellas+comentario) tras pedido pagado | ✓ SATISFIED | E2e 201 con 5★+comentario; solo pedidos pagados propios (404/409/422); sheet UI testeada |
| CALI-02 | 09-02, 09-03 | Promedio visible en lista y detalle | ✓ SATISFIED | E2e /public → 5.0/1; ratingLabel en lista+detalle+home con "—" sin datos |

Sin requirements huérfanos: los 5 IDs de Fase 9 del ROADMAP están cubiertos por planes y verificados.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| deploy/nginx/gri.conf | 33,48,53 | "TODO-reemplazar: dominio REAL" | ℹ️ Info | Intencional — el dominio solo se conoce al desplegar (README §1/§7 lo documentan como paso manual) |
| deploy/docker-compose.prod.yml | 87-88 | "placeholders hasta KYC" (WOMPI_* keys) | ℹ️ Info | Intencional — sin credenciales Wompi reales el flujo queda inerte con SANDBOX_MODE=false; documentado README §12 |

Sin stubs, sin placeholders de código, sin handlers vacíos, sin returns estáticos. Los únicos matches del scan son la palabra española "TODO/TODOS" y los 2 casos intencionales arriba.

### Test Suites

| Suite | Resultado |
|-------|-----------|
| Backend (docker compose exec api) | **215/215 passed** (84s) |
| HARD GATES pagos (dedup or firma, -v) | **3/3 PASSED** |
| Flutter app_cliente | **51/51 passed** |
| flutter analyze | **0 issues** |
| Commits de fase en git log | **19/19 verificados** |
| E2e sandbox curl (15 pasos) | **E2E-OK** + residuo limpiado (0 calificaciones/pagos/pago_events, mesa disponible) |

### Human Verification Required

Los 3 items del frontmatter (pase visual del flujo de pago, checkout real Wompi post-KYC, deploy real Ubuntu). Ninguno bloquea la fase: el primero quedó como no-bloqueante por design del orchestrator (suite + e2e automatizado verde), y los dos últimos son explícitamente post-fase en el plan 09-04 y están procedimentalizados en deploy/README.md.

### Gaps Summary

Sin gaps. Los 5 must-haves pasaron con evidencia de código + tests + e2e en vivo contra el stack real. El estado de la BD quedó prístino tras la limpieza post-e2e (verificado con SELECT: 0/0/0, mesa disponible).

---

_Verified: 2026-08-15T03:11:55Z_
_Verifier: Claude (gsd-verifier)_
