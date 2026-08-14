# Phase 6: App Cliente — Pedido por QR (REST) y Vista Cocina - Research

**Researched:** 2026-08-14
**Domain:** Sesión de mesa por QR + pedidos REST (state machine) + cola cocina (polling) — FastAPI/SQLAlchemy async + Flutter (mobile_scanner web)
**Confidence:** HIGH (contratos derivados de código existente verificado línea a línea; mobile_scanner verificado en pub.dev oficial)

## Summary

El core value de GRI se construye sobre piezas que YA existen: `sesion_mesa` (con UNIQUE de una sesión activa por mesa vía columna computada `activo_flag`), `pedido`/`pedido_item` (con snapshot de `precio_unitario` y CHECK cantidad>0), `PEDIDO_TRANSITIONS`/`MESA_TRANSITIONS`/`SESION_TRANSITIONS` en `state_machines.py`, y `validar_transicion()` que Phase 5 ya mapea a 409 en routers. El backend de esta fase es casi puro ensamblaje bajo los patrones probados de `reserva_service` (FOR UPDATE + IntegrityError→409) y `staff.py` (get_tenant_scope + existence hiding 404).

**Un gap real de schema:** `pedido` NO tiene `sesion_id` — la relación pedido↔sesión solo se puede inferir por (mesa, usuario, timestamps), lo cual es frágil. **Migración 0004** agrega `pedido.sesion_id` + las columnas de cuenta solicitada en `sesion_mesa` (`solicita_cuenta`, `solicitada_en`) + UNIQUE de una sesión activa por usuario. Es la única migración de la fase.

En Flutter: `mobile_scanner 7.4.0` soporta web (verificado pub.dev: backend Auto = BarcodeDetector nativo → fallback zxing-wasm), funciona en dev web-first `localhost:5174` (secure context). PERNO: cámara web depende de CDN (zxing-wasm ~2MB de jsDelivr) y de permiso del browser → **el input manual del código `GRI-MESA-XXX` es ciudadano de primera clase** (única vía además testeable en widget tests). La vista cocina del panel reemplaza el placeholder del sidebar ('📋', 'Pedidos') y clona el patrón de polling 10s de `mesas_provider` (deuda conocida → WS en Phase 7).

**Primary recommendation:** 3 planes — (1) backend: migración 0004 + services sesión/pedido + endpoints `/cliente/sesiones|pedidos|cuenta` y `/staff/pedidos` con matriz rol×transición, (2) app_cliente: escáner+fallback manual → menú/carrito → estado pedido → pedir cuenta, (3) panel_admin: cola cocina con avance de estados.

## Decisiones cerradas (del brief de fase — tratar como locked)

| Decisión | Valor |
|----------|-------|
| Mesa compartida | **NO en v1**: una sesión activa por mesa (UNIQUE ya existe) Y una sesión activa por usuario (nuevo UNIQUE en 0004) |
| Sesión ↔ reserva | Independientes: la sesión nace del QR scan; la reserva solo garantiza la mesa. Reservada→ocupada al abrir sesión es transición válida |
| Mesa → ocupada | **Al abrir sesión** (no al primer pedido) — fiel al core value; disponible→ocupada y reservada→ocupada ambas válidas |
| Estado inicial pedido | POST crea directo en `enviado` (carrito es client-side; `borrador` queda sin uso server-side, igual que `pendiente` en reservas) |
| Total | Server-side SIEMPRE: precio actual del producto al POST, snapshot en `pedido_item`; nunca confiar precios del cliente |
| Cerrar sesión | **No hay endpoint de cierre cliente en v1** — cierre al pagar (F9). Defensa anti-zombi: al pasar mesa a `limpieza` vía staff, se cierra la sesión activa de esa mesa |
| Aviso de cuenta | PAGO-01 = flag en sesión (no cierra nada); staff lo ve como badge en la cola de pedidos |
| Real-time | NO en esta fase: cliente y cocina usan polling REST (10s); WS es Phase 7 |

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MESA-05 | Cliente escanea QR con cámara | mobile_scanner 7.4.0 (web OK en localhost:5174) + input manual fallback; formato `GRI-MESA-XXX` globalmente único en BD |
| MESA-06 | QR válido → vinculado (sesión mesa) + ve menú | POST /cliente/sesiones {codigo_qr} → SesionRead; menú vía GET /public/restaurantes/{id} existente (no se re-implementa) |
| PEDI-01 | Agregar productos a un pedido | Carrito client-side (Riverpod Notifier) sobre el menú de /public; validación server: sesión propia activa + producto disponible |
| PEDI-02 | Enviar a cocina; aparece en cola | POST /cliente/pedidos crea en `enviado`; GET /staff/pedidos?activos=true lo lista tenant-scoped |
| PEDI-03 | State machine con 409 en inválidas | PEDIDO_TRANSITIONS ya existe; validar_transicion → TransicionInvalidaError → 409 (patrón Phase 5 en router) |
| PEDI-04 | Cliente consulta estado (REST/polling) | GET /cliente/pedidos/actual (pedidos de la sesión activa) + Timer.periodic 10s en provider |
| PEDI-05 | Cocina avanza estados | POST /staff/pedidos/{id}/estado con matriz rol×transición (cocina/admin: todas; mesero: solo servido) |
| PEDI-06 | Mesero/admin ven pedidos activos con detalle | GET /staff/pedidos?activos=true incluye mesa_numero, items con nombre, total, notas (joins display) |
| PAGO-01 | Solicitar cuenta avisa mesero/panel | POST /cliente/sesiones/actual/cuenta (idempotente) → flag visible en cola staff (badge por mesa) |
| ADMN-05 | Vista cocina: cola con avance | feature `cocina/` en panel_admin: cards por estado + botones según matriz + polling 10s (patrón mesas_provider) |

</phase_requirements>

## Migración 0004 (única de la fase)

Tabla `sesion_mesa`:
- `solicita_cuenta BOOLEAN NOT NULL SERVER DEFAULT FALSE`
- `solicitada_en DATETIME NULL`
- `UNIQUE (usuario_id, activo_flag)` name `uq_sesion_mesa_usuario_activa` — misma técnica de columna computada NULL-able que el UNIQUE existente por mesa (verificado: 0002 + tests 53/53): una sesión activa por usuario

Tabla `pedido`:
- `sesion_id BIGINT NULL FK → sesion_mesa.id` + `Index("ix_pedido_sesion", "sesion_id")` — nullable para no romper filas previas (en la práctica vacía); el service SIEMPRE lo escribe

## Contrato de API (exacto)

### Cliente — `require_roles(RolUsuario.cliente)` (NUNCA get_tenant_scope, que 403-ea clientes — lección 05-01)

| Endpoint | Body | Éxito | Errores |
|----------|------|-------|---------|
| `POST /cliente/sesiones` | `{"codigo_qr": "GRI-MESA-001"}` | 201 SesionRead | 404 QR no existe / restaurante inactivo · 409 mesa ocupada por sesión ajena / mesa limpieza / usuario ya tiene sesión activa en otra mesa · 200 (idempotente) si re-escaneo de MI sesión activa |
| `GET /cliente/sesiones/actual` | — | 200 SesionRead / 404 sin sesión activa | — |
| `POST /cliente/pedidos` | `{"sesion_id": 1, "items": [{"producto_id": 3, "cantidad": 2}], "notas": "…"}` (items min_length=1, cantidad gt=0 → 422 Pydantic) | 201 PedidoRead (estado=`enviado`) | 404 sesión inexistente/ajena (existence hiding) · 409 sesión no activa / producto agotado · 404 producto de otro restaurante |
| `GET /cliente/pedidos/actual` | — | 200 list[PedidoRead] — TODOS los pedidos de mi sesión activa (cualquier estado, newest first); 404 sin sesión | — |
| `POST /cliente/sesiones/actual/cuenta` | — | 200 SesionRead (solicita_cuenta=true) — **idempotente** (doble tap seguro) | 404 sin sesión activa |

`SesionRead`: `id, restaurante_id, restaurante_nombre, mesa_id, mesa_numero, abierta_en, solicita_cuenta, solicitada_en`. El menú NO va embebido — la app reusa `GET /public/restaurantes/{id}`.

`PedidoRead` (cliente): `id, sesion_id, mesa_numero, estado, total(float), notas, created_at, items: [{producto_id, nombre, cantidad, precio_unitario(float), subtotal(float)}]`. **Decimal→float vía `@field_serializer`** (patrón schemas/menu.py — lección 05-01).

Semántica de `abrir_sesion` (defense-in-depth, patrón reserva_service):
1. Mesa por `codigo_qr` (unique global) con `SELECT … FOR UPDATE` + restaurante activo
2. Si mesa `disponible` → transicionar a `ocupada` (validar_transicion); si `reservada` → `ocupada`; si `limpieza` → 409
3. Si ya existe sesión activa de la mesa: mismo usuario → devolverla (200 idempotente); otro usuario → 409
4. Si el usuario ya tiene sesión activa en OTRA mesa → 409 "Ya tienes una sesión activa en la Mesa X"
5. INSERT SesionMesa(estado=activa) → `IntegrityError` (UNIQUE mesa o usuario) → rollback → 409 (la BD gana la carrera)

Semántica de `crear_pedido`:
1. Sesión por id: `usuario_id == user.id` y `estado == activa` (404 ajena/inexistente, 409 inactiva)
2. Productos: todos del restaurante de la sesión, `disponible == True`; nombre/precio leídos server-side
3. `precio_unitario = producto.precio` (snapshot), `subtotal = precio * cantidad`, `total = Σ subtotal` — server-side SIEMPRE
4. INSERT Pedido(estado=`enviado`, sesion_id, mesa_id=sesion.mesa_id, restaurant_id, usuario_id) + items en UNA tx

### Staff — `get_tenant_scope` + `?restaurante_id=` para super_admin (espejo de staff.py existente)

| Endpoint | Body | Semántica |
|----------|------|-----------|
| `GET /staff/pedidos?activos=true` | — | Pedidos no terminales (estado NOT IN rechazado, pagado) del tenant, ORDER BY FIELD(estado,'enviado','aceptado','en_preparacion','servido'), created_at ASC (FIFO). Super_admin sin `?restaurante_id=` → 400 (patrón list_mesas). Cliente → 403 |
| `POST /staff/pedidos/{id}/estado` | `{"estado": "aceptado"}` | 200 PedidoStaffRead · 404 pedido de otro tenant/inexistente (existence hiding) · 409 transición inválida (validar_transicion) · 403 rol no autorizado para ESA transición (matriz) |

`PedidoStaffRead` = PedidoRead + `usuario_nombre` + `solicita_cuenta, solicitada_en` (JOIN sesion_mesa via pedido.sesion_id → el badge "pio la cuenta" vive en cada card de la cola).

**Matriz rol×transición (orden de checks: 1º validez de transición → 409; 2º matriz → 403):**

| Transición | cocina | mesero | admin_restaurante | super_admin |
|------------|:------:|:------:|:----------------:|:-----------:|
| enviado→aceptado | ✅ | ❌ | ✅ | ✅ |
| enviado→rechazado | ✅ | ❌ | ✅ | ✅ |
| aceptado→en_preparacion | ✅ | ❌ | ✅ | ✅ |
| en_preparacion→servido | ✅ | ✅ | ✅ | ✅ |

Justificación: PEDI-05 da a cocina aceptar/preparar/servir; "servido" = entrega física en mesa → mesero también; admin todo. Mesero NO acepta ni rechaza (decisión de cocina).

### Extensión a endpoint existente (anti-zombi)

`POST /staff/mesas/{id}/estado` a `limpieza`: además de la transición de mesa, cerrar la sesión activa de esa mesa (estado=cerrada, cerrada_en=now) si existe. Sin esto, una sesión abierta bloquea la mesa para siempre hasta F9.

## Standard Stack (delta de esta fase)

| Tech | Versión | Propósito | Status |
|------|---------|-----------|--------|
| mobile_scanner | 7.4.0 | Escanear QR (MESA-05) | NUEVO en app_cliente — web ✔ verificado pub.dev |
| Resto (riverpod 3.4.2, go_router 17.5.0, dio, freezed 4.0.0-dev.3, pytest) | existing | — | YA instalados en ambos apps |

**Flutter web — mobile_scanner 7.4.0 (verificado pub.dev, HIGH):**
- Web ✔. Backend Auto (default): `BarcodeDetector` nativo (Chrome/Edge 83+, Safari 17+, NO Firefox) → fallback `zxing-wasm` (~2MB WASM desde CDN jsDelivr en primer uso). Desde 5.0.0 NO hay que tocar index.html
- Cámara web = getUserMedia → **secure context obligatorio**: `localhost:5174` OK; IP LAN → bloqueado → fallback manual imprescindible
- En web NO funcionan: `scanWindow`, `analyzeImage`, `returnImage`, `autoZoom` — no depender de ellos
- Uso: `MobileScanner(controller: ..., formats: [BarcodeFormat.qrCode], onDetect: ...)`; `DetectionSpeed.noDuplicates` + `controller.stop()` tras el primer hit (evita doble POST — además el endpoint es idempotente); dispose correcto del controller; `MobileScannerException` (permiso denegado) → mostrar input manual
- Android ya scaffoldeado (minSdk 21 default ≥ requerido; ML Kit bundled +3-10MB — irrelevante para dev web)

## Architecture Patterns

### Backend (sigue la estructura Phase 3/5 exacta)
```
backend/app/
├── api/cliente.py        # + sesiones, pedidos, cuenta (require_roles(cliente))
├── api/staff.py          # + GET /staff/pedidos, POST /staff/pedidos/{id}/estado (get_tenant_scope)
├── services/sesion_service.py   # abrir/listar/solicitar_cuenta (FOR UPDATE + IntegrityError 409)
├── services/pedido_service.py   # crear (total server-side) + cola staff + transicionar (matriz)
├── schemas/sesion.py, schemas/pedido.py
└── alembic/versions/0004_sesion_pedido_cuenta.py
```

### app_cliente (nuevas features)
```
lib/features/
├── sesion_qr/   # scan_screen (MobileScanner + TextField fallback), sesion_provider
└── pedidos/     # menu_mesa_screen (reusa cards de restaurante_detalle), carrito_controller,
                 # pedidos_provider (polling 10s), pedido_estado_screen, cuenta CTA
lib/models/      # sesion_mesa.dart, pedido.dart, pedido_item.dart (freezed — MANTENER pin 4.0.0-dev.3)
```
Home: botón 📷 placeholder → navega a scan; si `sesionProvider` tiene sesión activa → banner "Estás en la Mesa X" con acceso a menú/mis pedidos/cuenta. El botón es reemplazo directo del SnackBar "Próximamente".

### panel_admin (nueva feature)
```
lib/features/cocina/   # cocina_screen (cards por estado), pedidos_staff_provider (polling 10s),
                       # widgets/pedido_card.dart (botones según rol × matriz, badge "🍽️ pidió la cuenta")
```
Sidebar: item existente `('📋', 'Pedidos')` pasa de `_showProximamente` a ruta `/cocina`. Polling: clonar `mesas_provider.dart` (Timer.periodic Env.pollSeconds + ref.onDispose cancel + queryRid para super_admin). Mesero logueado en panel: ve cola, solo botón "Marcar servido".

## Don't Hand-Roll

| Problema | No construir | Usar | Why |
|----------|--------------|------|-----|
| Escaneo QR | Cámara propia + decode | mobile_scanner 7.4.0 | ML Kit/Vision nativos + web ZXing; permisos, formatos, lifecycle resueltos |
| Total del pedido | Cálculo confiado en el cliente | server-side desde producto.precio | anti-tampering; snapshot en pedido_item ya diseñado |
| Validación de transiciones | if/else de estados | `validar_transicion("pedido", …)` | ya existe, testeado, TransicionInvalidaError→409 patrón Phase 5 |
| Carrera de sesión concurrente | check-then-insert sin lock | FOR UPDATE + UNIQUE(mesa_id, activo_flag) + IntegrityError→409 | la BD gana la carrera (patrón reserva_service verificado) |
| Money en JSON | float en Python | Decimal ORM + @field_serializer→float | lección 05-01 (Pydantic Decimal→string rompe Dart) |

## Common Pitfalls

### 1. Sesiones zombis bloquean mesas para siempre
**Qué:** no hay cierre de sesión en v1 hasta F9; un usuario que se va sin pagar deja la mesa ocupada + UNIQUE activa.
**Mitigación (ya en contrato):** mesa→limpieza (staff) cierra la sesión activa. Documentar que `expirada` (SESION_TRANSITIONS) queda sin job automático en v1 — F9/ops.
**Señal:** tests que reusan la misma mesa fallan con 409 — usar mesas distintas del seed (8 disponibles) o cerrar por DB en fixture.

### 2. REPEATABLE READ en tests (lección 05-01, DEVAforación #1 documentada)
Tras un commit del API, la tx abierta del test ve snapshot viejo. **Fix:** rollback + get fresco en el test, NUNCA `session.refresh(obj)` para verificar efectos de OTRO commit.

### 3. `get_tenant_scope` rechaza cliente con 403 (lección 05-01)
Todo endpoint `/cliente/*` usa `require_roles(RolUsuario.cliente)`; el tenant se deriva del recurso (sesión.usuario_id), jamás del token.

### 4. Doble disparo del escáner / doble tap en "Enviar pedido"
onDetect puede disparar varias veces; POST /cliente/sesiones es idempotente (200) y el scanner hace `stop()` tras el primer hit. Para pedidos: deshabilitar botón mientras vuela el request (el doble POST crea 2 pedidos — no es idempotente, aceptable v1; UI lo previene).

### 5. Widget tests no pueden instanciar MobileScanner
La cámara no existe en el test env. **Todos los flows de test van por el input manual** (`TextField` con código `GRI-MESA-001`) — por eso el fallback es requisito, no decoración.

### 6. freezed + campos List (lección 05-03)
Los modelos nuevos (Pedido con `items: List<PedidoItem>`) necesitan el pin `freezed: 4.0.0-dev.3` ya presente en app_cliente/pubspec.yaml. NO "actualizar" freezed a 3.x estable — genera constructores inválidos con List.

### 7. Producto agotado mostrado tarde (UX pitfall del research)
El menú ya trae `disponible` (GET /public). Marcar ítem agotado en la UI desde el inicio; el 409 del POST es la red de seguridad, no el UX primario.

### 8. Polling sin cleanup
Timer.periodic en providers debe cancelarse en `ref.onDispose` (patrón mesas_provider) — sino timers zombis entre navegación.

### 9. Cámara web en entornos sin secure context / sin CDN
Dev por `localhost` OK; si se accede por IP o sin internet (zxing-wasm CDN), la cámara falla → el catch de `MobileScannerException` SIEMPRE ofrece el input manual.

## Code Examples

### Abrir sesión (service — patrón reserva_service)
```python
# services/sesion_service.py (esqueleto prescriptivo)
async def abrir_sesion(session: AsyncSession, usuario_id: int, codigo_qr: str) -> SesionRead:
    mesa = (await session.execute(
        select(Mesa).where(Mesa.codigo_qr == codigo_qr).with_for_update()
    )).scalar_one_or_none()
    if mesa is None:
        raise HTTPException(404, "Mesa no encontrada")
    restaurante = await session.get(Restaurante, mesa.restaurant_id)
    if restaurante is None or not restaurante.activo:
        raise HTTPException(404, "Restaurante no disponible")
    # sesión activa existente de la mesa → idempotente propio / 409 ajeno
    activa = (await session.execute(
        select(SesionMesa).where(SesionMesa.mesa_id == mesa.id, SesionMesa.cerrada_en.is_(None))
    )).scalar_one_or_none()
    if activa is not None:
        if activa.usuario_id == usuario_id:
            return _to_read(activa, restaurante, mesa)   # 200 idempotente
        raise HTTPException(409, "Mesa ocupada")
    # una sesión activa por USUARIO
    mia = (await session.execute(
        select(SesionMesa).where(SesionMesa.usuario_id == usuario_id, SesionMesa.cerrada_en.is_(None))
    )).scalar_one_or_none()
    if mia is not None:
        raise HTTPException(409, "Ya tienes una sesión activa")
    # mesa disponible/reservada → ocupada (limpieza → 409 por validar_transicion)
    validar_transicion("mesa", mesa.estado, EstadoMesa.ocupada)  # raises → 409 en router
    mesa.estado = EstadoMesa.ocupada
    sesion = SesionMesa(restaurant_id=mesa.restaurant_id, mesa_id=mesa.id, usuario_id=usuario_id)
    session.add(sesion)
    try:
        await session.commit()
    except IntegrityError:  # UNIQUE(mesa_id|usuario_id, activo_flag) — la BD gana la carrera
        await session.rollback()
        raise HTTPException(409, "La mesa acaba de ser ocupada")
    ...
```

### Transición con matriz de roles (staff)
```python
TRANSITION_ROLES: dict[EstadoPedido, set[RolUsuario]] = {
    EstadoPedido.aceptado: {RolUsuario.cocina, RolUsuario.admin_restaurante, RolUsuario.super_admin},
    EstadoPedido.rechazado: {RolUsuario.cocina, RolUsuario.admin_restaurante, RolUsuario.super_admin},
    EstadoPedido.en_preparacion: {RolUsuario.cocina, RolUsuario.admin_restaurante, RolUsuario.super_admin},
    EstadoPedido.servido: {RolUsuario.cocina, RolUsuario.mesero, RolUsuario.admin_restaurante, RolUsuario.super_admin},
}
# router: 1º validar_transicion → 409; 2º user.role in TRANSITION_ROLES[nuevo] → 403
```

### Scanner con fallback (app_cliente)
```dart
// features/sesion_qr/scan_screen.dart — forma prescriptiva
MobileScanner(
  controller: controller,
  formats: const [BarcodeFormat.qrCode],
  onDetect: (capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _navigating) return;
    _navigating = true;
    await controller.stop();                    // no re-disparar
    await ref.read(sesionControllerProvider.notifier).abrir(raw);  // 200/409 idempotente
  },
  errorBuilder: (context, error) => _ManualInput(),  // permiso/CDI fallo → fallback SIEMPRE visible
)
// + botón permanente "Escribir código" → TextField GRI-MESA-001 (única vía en tests)
```

## State of the Art / Notas de versión

- `pedido_item.pedido_item` no existe como archivo: PedidoItem vive en `models/pedido.py` (no crear archivo nuevo)
- `ix_pedido_restaurante_estado` YA existe → la cola `WHERE restaurant_id AND estado IN (...)` está indexada sin trabajo extra
- `borrador` (pedido) y `pendiente` (reserva) existen en los enums pero quedan sin uso server-side en v1 — decisión consistente con Phase 5
- Alembic: siguiente revisión = `0004` (0001–0003 tomadas)
- Seed demo para UAT: restaurante id=1, mesas GRI-MESA-001..008, cocina@demo.gri.dev / mesero@demo.gri.dev / admin@demo.gri.dev (Demo!1234), carlos@demo.gri.dev (cliente)

## Open Questions

1. **¿Motivo del rechazo?** PEDI-03 no lo exige; `notas` existe en pedido. v1: sin campo. Impacto: cliente ve "Rechazado" a secas.
2. **¿Múltiples pedidos simultáneos por sesión?** Permitido (comer → postre después). La UI lista todos; sin límite v1. Confirmar en UAT que el flujo es claro.
3. **¿Cuenta solicitada visible si NO hay pedidos activos?** Edge (pedir cuenta sin pedir comida): la cola no la mostraría. Aceptado en v1 (no hay nada que cobrar); F9 puede agregar GET /staff/sesiones/activas si importa.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Backend | pytest + pytest-asyncio (httpx AsyncClient contra stack Docker `localhost:8000`) — `docker compose up -d` requerido |
| Flutter app | flutter_test (widget tests) — `cd app_cliente && flutter test` |
| Panel | flutter_test — `cd panel_admin && flutter test` |
| Config | backend: conftest.py existente (fixtures async_client/register_cliente/login/auth_header/db_session) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MESA-05/06 | QR válido abre sesión + mesa→ocupada; QR inválido 404; idempotencia propio/409 ajeno; 409 usuario con sesión previa; limpieza 409; concurrencia 2 sesiones misma mesa → 1x201+1x409 | integration | `cd backend && python -m pytest tests/test_sesion_mesa.py -x -q` | ❌ Wave 0 |
| PEDI-01/02 | POST pedido: 201 estado=enviado, total server-side, snapshot precio, items correctos; sin sesión 404/409; sesión ajena 404; agotado 409; producto cross-restaurante 404; cantidad 0 → 422 | integration | `cd backend && python -m pytest tests/test_cliente_pedidos.py -x -q` | ❌ Wave 0 |
| PEDI-03/05 | Transiciones válidas 200 secuencia enviada→…→servido; inválidas 409 (saltos, terminales); matriz roles (mesero 403 en aceptar, 200 en servido; cocina todo) | integration | `cd backend && python -m pytest tests/test_staff_pedidos.py -x -q` | ❌ Wave 0 |
| PEDI-06 | Cola staff: tenant-scoped (staff A no ve pedidos B; super_admin sin param 400; cliente 403); incluye mesa+items+total+notas+solicita_cuenta | integration | `cd backend && python -m pytest tests/test_staff_pedidos.py -x -q` (misma suite) | ❌ Wave 0 |
| PAGO-01 | POST cuenta marca flag+solicitada_en; idempotente 200; sin sesión 404; visible en cola staff | integration | `cd backend && python -m pytest tests/test_cuenta.py -x -q` | ❌ Wave 0 |
| MESA-05 (UI) | Input manual GRI-MESA-001 → sesión abierta → banner "Mesa X" (fake provider) | widget | `cd app_cliente && flutter test test/sesion_qr/scan_test.dart` | ❌ Wave 0 |
| PEDI-01/02 (UI) | Carrito: agregar/quitar, total COP, enviar → estado enviado | widget | `cd app_cliente && flutter test test/pedidos/carrito_test.dart` | ❌ Wave 0 |
| PEDI-04 (UI) | Render chips de estado (enviado/aceptado/en_preparacion/servido/rechazado) | widget | `cd app_cliente && flutter test test/pedidos/estado_test.dart` | ❌ Wave 0 |
| PAGO-01 (UI) | Botón cuenta → confirmación + flag | widget | `cd app_cliente && flutter test test/pedidos/cuenta_test.dart` | ❌ Wave 0 |
| ADMN-05 | Cola cocina render (cards mesa/items/total/badge cuenta); botón avanza estado; mesero solo "Servido" | widget | `cd panel_admin && flutter test test/cocina/cola_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** suite nueva del módulo tocado (backend `-x -q` del archivo; flutter del feature)
- **Per wave merge:** `cd backend && python -m pytest tests/ -q` (105/105 actuales deben seguir verdes) + `flutter test` en ambos apps + `flutter analyze` (0 issues)
- **Phase gate:** las tres suites completas verdes antes de `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/test_sesion_mesa.py` — MESA-05/06 (+ test de concurrencia estilo test_reserva_concurrency)
- [ ] `backend/tests/test_cliente_pedidos.py` — PEDI-01/02
- [ ] `backend/tests/test_staff_pedidos.py` — PEDI-03/05/06 (+ aislamiento tenant)
- [ ] `backend/tests/test_cuenta.py` — PAGO-01
- [ ] `app_cliente/test/sesion_qr/`, `app_cliente/test/pedidos/` — MESA-05 UI, PEDI UI
- [ ] `panel_admin/test/cocina/` — ADMN-05
- [ ] Helpers conftest nuevos: `abrir_sesion(client, token, qr)` + login staff demo (cocina/mesero) reusando seed

## Sources

### Primary (HIGH confidence)
- Código local verificado (línea a línea): `state_machines.py` (PEDIDO/SESION/MESA_TRANSITIONS + validar_transicion), `models/{pedido,sesion_mesa,mesa,menu,usuario}.py`, `api/{cliente,staff}.py`, `deps/auth.py` (require_roles/get_tenant_scope), `services/reserva_service.py` (FOR UPDATE + IntegrityError), `tests/conftest.py`, `seed_service.py` (GRI-MESA-001..008, staff demo), `panel_admin/mesas_provider.dart` (polling), `app_shell.dart` (item '📋 Pedidos')
- pub.dev/packages/mobile_scanner (7.4.0, official) — web ✔, backends Auto/BarcodeDetector/zxing-wasm, secure context, limitaciones web (scanWindow ❌), auto-load script desde 5.0.0

### Secondary (MEDIUM)
- PITFALLS.md P2/P6 (estado autoritativo, sesión anti-spoofing) y "Looks Done But Isn't" (una sesión activa por usuario) — research previo del proyecto
- Lecciones 05-01/05-03 SUMMARY (get_tenant_scope 403 cliente, Decimal→float, REPEATABLE READ, freezed pin) — documentadas de ejecución real

## Metadata

**Confidence breakdown:**
- Contrato API / migración: HIGH — derivado de models y patrones existentes verificados directamente
- mobile_scanner web: HIGH — pub.dev oficial leído hoy (límites web documentados arriba)
- Matriz roles y decisiones de producto (ocupada-al-abrir, sin cierre v1): MEDIUM — recomendaciones prescriptivas basadas en requirements; el planner puede ajustar con el usuario

**Research date:** 2026-08-14
**Valid until:** 2026-09-14 (estable — dominio propio + mobile_scanner verificado hoy)
