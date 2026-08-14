---
phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina
verified: 2026-08-14T10:53:16Z
status: passed
score: 6/6 must-haves verified
re_verification: null
gaps: []
human_verification:
  - test: "Cámara QR en dispositivo físico Android/iOS"
    expected: "mobile_scanner (ML Kit / AVFoundation) escanea un QR real GRI-MESA-XXX y abre la sesión"
    why_human: "Widget tests usan Fake ApiClient y cero instancias de MobileScanner; web probada solo en localhost (secure context). El nativo requiere hardware."
  - test: "Flujo visual completo cliente+panel en dos ventanas"
    expected: "Cliente envía pedido → panel cocina lo ve (≤10s) → avanza estados → chips del cliente cambian → cliente pide cuenta → badge amarillo aparece en el card de cocina"
    why_human: "Look&feel (colores chips, banner gradiente, badge a distancia) y latencia percibida del polling 10s no son verificables por grep/widget tests."
  - test: "Errores UX: mesa ocupada (409) y código inválido en la app real"
    expected: "SnackBar rojo con el detail del backend ('La mesa está ocupada...') y validación regex pre-red del input manual"
    why_human: "Render del SnackBar en dispositivo real y tono del mensaje."
warnings:
  - "42 mesas GRI-TEST-* acumuladas en BD demo (residuo pre-existente de tests de fases 3-5, no de Phase 6). FK pedido.mesa_id impide borrado simple. Tests inmunes por diseño (test_public_read lo cubre). Cosmético: GET /staff/mesas devuelve 50 mesas — el mapa del panel muestra 50 tiles en el demo. Limpieza sugerida (script SQL con DELETE en orden FK) fuera del scope de esta fase."
---

# Phase 6: App Cliente — Pedido por QR (REST) y Vista Cocina — Verification Report

**Phase Goal:** El core value funciona de punta a punta sin tiempo real: sentarse, escanear el QR, pedir del menú, seguir el estado del pedido y pedir la cuenta
**Verified:** 2026-08-14T10:53:16Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Escanea QR (o input manual GRI-MESA-XXX) → sesión abierta → mesa ocupada → ve menú | ✓ VERIFIED | **Live**: POST /cliente/sesiones `{codigo_qr: GRI-MESA-005}` → **HTTP 201** (sesión 305, mesa 5, restaurante correcto). Frontend: `MobileScanner` solo tras tap (`if (_cameraOn)`), `TextFormField` SIEMPRE en el árbol (scan_screen.dart L150-209), regex `^GRI-MESA-\d{3}$` L42, anti doble-disparo (`DetectionSpeed.noDuplicates` + `_navigating` + `controller.stop()`). Menú: `menu_mesa_screen` reusa `restauranteDetalleProvider(sesion.restauranteId)` L87. Mesa→ocupada validado por suite (9/9 test_sesion_mesa). |
| 2 | Arma pedido (total server-side, snapshot precio) → enviado → cola staff con detalle | ✓ VERIFIED | **Live**: POST /cliente/pedidos items=[{3,1},{2,2}] → **HTTP 201**, `estado=enviado`, `total=30000.0` (=11000×1 + 9500×2, computado server-side), `precio_unitario` snapshot en cada item. `PedidoCreate` schema SIN campos de precio (solo producto_id/cantidad/sesion_id/notas — schemas/pedido.py L26-36). Cola staff: GET /staff/pedidos?activos=true contiene pedido 348 con items, total, `usuario_nombre="Carlos Cliente"`. Carrito Flutter: agregar/incrementar/decrementar→remover/limpiar + total/itemCount (carrito_controller.dart). |
| 3 | State machine: válidas 200, inválidas 409, matriz roles (mesero solo servido) | ✓ VERIFIED | **Live**: aceptado→servido → **HTTP 409** `"Transición de estado no permitida"`; camino válido aceptado→en_preparacion→servido → **200/200**. Matriz: `TRANSITION_ROLES` en pedido_service (cocina/admin/super_admin todo; mesero solo servido) — verificado por backend tests (409 antes de 403) y panel test (f) "mesero sin Aceptar/Rechazar, solo Marcar servido" en suite 17/17. `nextActions(rol)` espejo client-side en PedidoCard (pedido_card.dart L40). |
| 4 | Cliente consulta estado con polling 10s | ✓ VERIFIED | **Live**: GET /cliente/pedidos/actual → pedido 348 `estado=aceptado` (reflejó la transición hecha por cocina). `pedidosSessionProvider`: `Timer.periodic(Duration(seconds: Env.pollSeconds))` + `ref.onDispose` (pedidos_provider.dart L33,40); `Env.pollSeconds = 10` (env.dart L24). PedidoEstadoScreen: cards + chips coloreados 5 estados + botón cuenta. |
| 5 | Solicita cuenta → idempotente → badge visible en cola staff | ✓ VERIFIED | **Live**: POST /cliente/sesiones/actual/cuenta → **HTTP 200** con `solicita_cuenta=true, solicitada_en=...`; cola staff inmediatamente muestra `solicita_cuenta=true` en el pedido 348. Idempotencia server-side: test_cuenta.py en suite 141/141 (`solicitar_cuenta` no re-escribe solicitada_en). UI: badge "🍽️ pidió la cuenta" amarillo en PedidoCard L235-253; cliente ve "Cuenta solicitada ✓" (estado screen + banner home L206). |
| 6 | HARD GATE: 2 sesiones misma mesa concurrentes → 1×201 + 1×409 | ✓ VERIFIED | `pytest tests/test_sesion_mesa.py -k concurrencia` → **1 passed** (`test_concurrencia_misma_mesa`: 2 POST concurrentes misma mesa → exactamente 1×201 + 1×409 + 1 sesión activa en DB). Mecanismo: FOR UPDATE + UNIQUE(mesa_id\|usuario_id, activo_flag) migración 0004 + IntegrityError→409. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/alembic/versions/0004_sesion_pedido_cuenta.py` | Migración cuenta + UNIQUE + FK | ✓ VERIFIED | Aplicada (alembic head 0004, boot OK); constraint `uq_sesion_mesa_usuario_activa` probada en vivo por el HARD GATE |
| `backend/app/services/sesion_service.py` | abrir_sesion/actual/cuenta | ✓ VERIFIED | Live 201/200/404 post anti-zombi; 409 concurrencia |
| `backend/app/services/pedido_service.py` | crear/cola/transicionar | ✓ VERIFIED | Live total server-side + snapshot; 409 inválida; TRANSITION_ROLES |
| `backend/app/services/staff_service.py` | anti-zombi en set_mesa_estado | ✓ VERIFIED | **Live**: mesa 5→limpieza cerró sesión 305 → GET /cliente/sesiones/actual = 404 |
| `backend/app/api/cliente.py` + `staff.py` | 7 endpoints nuevos | ✓ VERIFIED | Todos invocados live con el contrato esperado |
| `app_cliente/lib/features/sesion_qr/*` | Scan lazy + manual first-class | ✓ VERIFIED | grep + lectura de código (L42 regex, L150 condicional, L191+ manual) |
| `app_cliente/lib/features/pedidos/*` (5 archivos) | Carrito, envío, estado, cuenta | ✓ VERIFIED | 34/34 widget tests; wiring ApiClient (abrirSesion L142, pedirCuenta L165, createPedido L191) |
| `panel_admin/lib/features/cocina/*` (4 archivos) | Cola + cards + badge + botones rol | ✓ VERIFIED | 17/17 tests; getPedidosActivos L90 / avanzarPedido L107 en ApiClient |
| `panel_admin/lib/features/shared/app_shell.dart` | Sidebar Pedidos activo | ✓ VERIFIED | Mapa `_routes` con `/cocina` L157, `activeIndex = _routes.indexOf(location)` L166, "Próximamente" eliminado |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| ScanScreen | POST /cliente/sesiones | ApiClient.abrirSesion → sesionController.abrir | ✓ WIRED | SnackBar éxito/409 detail + pushReplacement /mesa |
| MenuMesaScreen | POST /cliente/pedidos | ApiClient.createPedido (items sin precios) | ✓ WIRED | Live 201; body sin precio/sesion_id |
| PedidoEstadoScreen | GET /cliente/pedidos/actual | pedidosSessionProvider (Timer 10s) | ✓ WIRED | Live reflejó aceptado |
| PedidoEstadoScreen | POST /cliente/sesiones/actual/cuenta | ApiClient.pedirCuenta | ✓ WIRED | Live 200 + mirror local |
| CocinaScreen | GET /staff/pedidos?activos=true | pedidosStaffProvider (Timer 10s) | ✓ WIRED | Live: cola con badge |
| PedidoCard | POST /staff/pedidos/{id}/estado | ApiClient.avanzarPedido + invalidate | ✓ WIRED | Live 200/409 + test (e) |
| AppShell sidebar | /cocina | context.go('/cocina') + isActive por path | ✓ WIRED | Test suite panel |
| staff set_mesa_estado | UPDATE sesion_mesa (anti-zombi) | misma tx | ✓ WIRED | Live: /actual 404 tras limpieza |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MESA-05 | 06-01, 06-02 | Abrir sesión por QR vinculada al usuario | ✓ SATISFIED | Live 201 + anti-spoofing (sesión ajena 404) + suite |
| MESA-06 | 06-01, 06-02 | Mesa ocupada al abrir sesión; liberación anti-zombi | ✓ SATISFIED | Suite + live anti-zombi (limpieza cierra sesión) |
| PEDI-01 | 06-01, 06-02 | Armar pedido del menú | ✓ SATISFIED | Carrito + agotados disabled + live 201 |
| PEDI-02 | 06-01 | Total server-side + snapshot precio | ✓ SATISFIED | Live total 30000 exacto; schema sin precios; test snapshot |
| PEDI-03 | 06-01 | State machine con 409 en inválidas | ✓ SATISFIED | Live 409 + suite |
| PEDI-04 | 06-01, 06-02 | Cliente consulta estado (REST/polling) | ✓ SATISFIED | Live /pedidos/actual + Timer 10s |
| PEDI-05 | 06-01, 06-03 | Cola de pedidos staff con detalle | ✓ SATISFIED | Live cola + PedidoCard + sidebar activo |
| PEDI-06 | 06-01, 06-03 | Avance por matriz rol×transición | ✓ SATISFIED | Live 200 válidas + test mesero solo servido |
| PAGO-01 | 06-01, 06-02, 06-03 | Solicitar cuenta idempotente + aviso staff | ✓ SATISFIED | Live 200 + badge true en cola + test idempotencia |
| ADMN-05 | 06-03 | Vista cocina en panel | ✓ SATISFIED | CocinaScreen + 17/17 + build web OK |

Orphaned requirements: ninguno — los 10 IDs de Phase 6 en ROADMAP están cubiertos por los 3 planes.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | 0 patrones reales | — | Matches "TODO" eran la palabra española en comentarios ("TODOS los pedidos"); "placeholder" en app_shell.dart L13 documenta lo que REEMPLAZÓ (ya eliminado) |

### Test Suites (ejecutadas en esta verificación)

| Suite | Resultado | Comando |
|--------|-----------|---------|
| Backend (integración, Docker runtime) | **141 passed** in 42s | `docker compose exec api uv run pytest tests/ -q` |
| HARD GATE concurrencia | **1 passed** | `pytest tests/test_sesion_mesa.py -k concurrencia -v` |
| app_cliente (widget) | **34 passed** | `flutter test` |
| panel_admin (widget) | **17 passed** | `flutter test` |

### Runtime E2E Smoke (curl, localhost:8000 — evidencia en vivo)

1. carlos@demo.gri.dev login ✓ → POST /cliente/sesiones GRI-MESA-005 → **201**
2. POST /cliente/pedidos 2 items → **201** enviado, total=30000, snapshot precios ✓
3. cocina@demo.gri.dev → GET /staff/pedidos?activos=true → pedido presente con items+usuario ✓
4. POST estado aceptado → **200** ✓
5. POST /cliente/sesiones/actual/cuenta → **200**, solicita_cuenta=true ✓
6. GET cola → badge solicita_cuenta=true ✓
7. Transición inválida aceptado→servido → **409** ✓ · GET /cliente/pedidos/actual refleja aceptado ✓
8. Cleanup: en_preparacion→servido (200×2) → mesa limpieza (**sesión cerrada, /actual=404** — anti-zombi live) → mesa disponible ✓
9. BD restaurada: 0 pedidos activos, 0 sesiones activas, 8 mesas seed disponibles ✓

### Human Verification Required

### 1. Cámara QR en dispositivo físico
**Test:** Escanear un QR real GRI-MESA-XXX con la app en Android/iOS
**Expected:** Sesión abierta → menú; doble lectura imposible
**Why human:** Widget tests excluyen MobileScanner (Fakes); web solo probada en localhost secure context; nativo requiere hardware

### 2. Flujo visual completo cliente+panel (2 ventanas)
**Test:** app cliente (5174) + panel cocina (5173) con users demo; enviar pedido, avanzar estados, pedir cuenta
**Expected:** Chip cambia solo en ≤10s; badge amarillo visible a distancia; colores del mockup
**Why human:** Latencia percibida del polling y look&feel final no verificables por grep/widget tests

### 3. Errores UX en app real
**Test:** Intentar mesa ocupada (409) y código inválido
**Expected:** SnackBar con detail del backend; regex bloquea pre-red
**Why human:** Render real del SnackBar en dispositivo

### Gaps Summary

Sin gaps. Los 6 must-haves verificados con evidencia en vivo (runtime curl contra Docker) + suites completas (141+34+17). El goal del core value REST end-to-end está logrado: sentarse → escanear → pedir → seguir estado (polling) → pedir la cuenta, con la vista cocina operando la matriz rol×transición.

**Warning no bloqueante:** 42 mesas `GRI-TEST-*` acumuladas en la BD demo (residuo pre-existente de tests de fases 3-5, FK pedido.mesa_id impide borrado directo; tests inmunes por diseño). Cosmético para el demo (mapa del panel muestra 50 mesas). Sugerido: script de limpieza fuera de scope.

---

_Verified: 2026-08-14T10:53:16Z_
_Verifier: Claude (gsd-verifier)_
