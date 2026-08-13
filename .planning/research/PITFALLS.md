# Pitfalls Research

**Domain:** Plataforma multi-restaurante — reservas, pedidos por QR, tiempo real (WebSockets), multi-tenant, pagos Colombia
**Stack:** Flutter móvil (cliente) + Flutter Web (admin) + FastAPI + MySQL en Docker/Ubuntu Server + WebSockets + Wompi/PayU
**Researched:** 2026-08-13
**Confidence:** HIGH en concurrencia/multi-tenant/MySQL/WS patterns · MEDIUM en detalles específicos de Wompi (docs oficiales inaccesibles, 403)

---

## Critical Pitfalls

Errores que causan reescrituras, pérdida de dinero o datos corruptos. No negociables.

### Pitfall 1: Race condition en reservas — dos clientes reservan la misma mesa a la misma hora

**What goes wrong:**
Dos clientes (o el mismo cliente con doble tap) ejecutan `POST /reservas` para la misma mesa/horario casi simultáneamente. La lógica "leer disponibilidad → insertar reserva" no es atómica; ambas lecturas ven la mesa libre y ambos inserts pasan. Resultado: **doble reserva de la misma mesa**. El restaurante descubre el conflicto cuando llegan los dos clientes.

**Why it happens:**
El patrón natural en FastAPI/SQLAlchemy es:
```python
if not existe_reserva(mesa_id, hora):   # SELECT
    crear_reserva(mesa_id, hora)          # INSERT
```
Bajo concurrencia, dos requests pasan el `SELECT` antes de que cualquiera haga el `INSERT`. Sin bloqueo a nivel de fila o constraint único, la BD no rechaza nada. Esto se agrava con múltiples workers Uvicorn (cada request en paralelo real, no solo por GIL).

**How to avoid:**
1. **Constraint único en la BD** (defensa principal, no la app): `UNIQUE (mesa_id, fecha_hora)` o, mejor, un constraint sobre un *slot* (`UNIQUE (mesa_id, fecha, turno_slot)`). Capturar `IntegrityError` y devolver 409 Conflict.
2. **Bloqueo pesimista por fila**: `SELECT ... FOR UPDATE` sobre la mesa dentro de una transacción, o `WITH LOCK` al validar disponibilidad. Garantiza serialización por mesa.
3. **Validación de solapamiento por rango**: la mesa no es "libre a las 20:00" sino "libre en la ventana [20:00, 20:00+duración]". El constraint único simple no cubre solapamientos parciales — usar query de exclusión de rangos (`tsrange`/overlap) dentro de la transacción bloqueada.
4. **Idempotencia en el endpoint**: el cliente mía un `Idempotency-Key` (header); el backend de/deduplica inserts idénticos en ventana de ~30s. Protege contra doble tap del usuario.

**Warning signs:**
- Tests de reserva pasan siempre en serie — nunca se prueba concurrencia real.
- No hay `IntegrityError` handler ni constraint único en el schema de reservas.
- "Funciona en mis pruebas manuales" pero el cliente reporta mesas duplicadas en horas pico.
- El ORM hace el `SELECT` y el `INSERT` en sesiones/transacciones distintas.

**Phase to address:**
**Fase de Reservas** (probablemente Fase 2 o 3). El constraint único y el `FOR UPDATE` deben diseñarse *con el schema*, no añadirse después. Si el schema de reservas se crea sin el constraint, migrarlo después requiere backfill + validación de duplicados existentes (doloroso).

---

### Pitfall 2: Estado de mesa derivado vs. almacenado — fuente única de verdad ambigua

**What goes wrong:**
El estado de la mesa (`disponible | ocupada | reservada | limpieza`) se calcula a partir de múltiples fuentes: reservas activas, pedidos abiertos, sesión QR activa. Si el estado se *calcula en runtime* cada vez, dos clientes pueden ver estados distintos según cuándo consulten. Si se *almacena* pero también se *calcula*, hay **drift**: el campo `estado` dice "disponible" pero existe un pedido abierto, o dice "ocupada" pero la sesión QR expiró hace una hora.

**Why it happens:**
Es tentador guardar `mesa.estado` como columna (rápido de leer, fácil para el mapa de mesas del admin) pero olvidar que ese campo debe actualizarse en *todos* los eventos que lo afectan (nueva reserva, cliente escanea QR, pedido cerrado, mesero marca limpieza, reserva expira). Alguien añade un nuevo flujo (ej. "cliente abandona") y no actualiza el estado → inconsistencia permanente.

**How to avoid:**
1. **Decidir y documentar la fuente de verdad**: recomiendo `mesa.estado` como **estado almacenado y autoritativo**, mutado exclusivamente por eventos (state machine explícito), NO recalculado on-the-fly.
2. **Modelar una máquina de estados** con transiciones válidas (`disponible→reservada→ocupada→limpieza→disponible`). Rechazar transiciones inválidas en la BD (trigger) o en la app (con test). Ej: no se puede pasar de `limpieza` directo a `ocupada`.
3. **Cron/backups de reconciliación**: job periódico que detecta mesas `ocupada` sin sesión QR activa > N minutos y las marca `limpieza` (o alerta al admin). No es la fuente de verdad, es una red de seguridad.
4. **Transiciones atómicas**: cada cambio de estado en su propia transacción, broadcast por WS *después* del commit (no antes).

**Warning signs:**
- El mapa de mesas del admin muestra estados distintos a los que ve el cliente.
- Mesas quedan "ocupada" para siempre tras un crash o timeout de sesión QR.
- Dos endpoints distintos calculan el estado con lógica duplicada y divergen.
- No existe un diagrama de transiciones de estados de mesa.

**Phase to address:**
**Fase de Gestión de Mesas** (junto con el panel admin, Fase 2). La máquina de estados debe definirse al modelar las mesas. Cambiar el modelo de estado cuando ya hay pedidos/reservas en producción requiere migración de datos y es fuente de bugs sutiles.

---

### Pitfall 3: WebSockets in-memory — no sobrevive a múltiples workers ni reconexiones con sync

**What goes wrong:**
Se implementa el `ConnectionManager` del tutorial de FastAPI (lista `active_connections` en memoria). Funciona en dev con 1 worker. En producción con `--workers 4`, un pedido creado en el worker A se broadcastea solo a los clientes conectados al worker A — **cocina (conectada al worker B) nunca ve el pedido**. Además, al reconectar un cliente tras caída de red, el backend no le reenvía el estado que perdió; el cliente muestra estado obsoleto.

**Why it happens:**
El patrón del tutorial es explícitamente "single process" en la doc oficial de FastAPI. Es la solución más copiada porque es simple. Nadie prueba con múltiples workers hasta deploy. El segundo problema (reconexión sin sync) ocurre porque los devs asumen que WebSocket = tiempo real confiable, pero las conexiones WS *caen* (wifi, app a background, proxy timeout) y los mensajes enviados durante la desconexión **se pierden**.

**How to avoid:**
1. **PubSub externo desde el día 1**: Redis Pub/Sub (o PostgreSQL LISTEN/NOTIFY) como bus entre workers. Cada worker publica en el canal `restaurante:{id}` y todos los workers suscritos broadcastean a sus conexiones locales. La doc oficial sugiere `encode/broadcaster`. NO postergar esto — migrar de in-memory a Redis después es reescribir el ConnectionManager.
2. **Reconexión con re-sync de estado**: al conectar (y reconectar), el cliente siempre debe hacer un `GET /estado` HTTP inicial para obtener el snapshot actual, *luego* suscribirse por WS para deltas. El WS es *notificación*, no *fuente de estado*.
3. **Sequence numbers / versión**: cada evento WS lleva un `seq` o `version`. El cliente, al reconectar, reporta su último `seq` visto y el backend le envía los eventos perdidos (replay desde la BD/log). Sin esto, hay ventana de pérdida garantizada.
4. **Heartbeat/ping-pong**: detectar conexiones zombis (cliente cerró pero el server no sabe). Sin esto, `active_connections` se llena de sockets muertos y el broadcast falla silenciosamente o tarda.
5. **Diseñar para "al menos una vez" + idempotencia**: el mismo evento puede llegar duplicado tras reconexión; los handlers de cliente deben ser idempotentes (usar `evento.id`).

**Warning signs:**
- "A veces cocina no recibe el pedido" — no reproducible en dev con 1 worker.
- El cliente muestra "preparando..." cuando el pedido ya fue entregado, tras volver de background.
- El contador de conexiones activas crece sin límite (sockets zombis).
- Broadcast lanza excepciones silenciosas a conexiones cerradas.

**Phase to address:**
**Fase de Tiempo Real** (Fase 4). Redis Pub/Sub debe entrar en esa fase, NO como "optimización posterior". El modelo re-sync-on-connect debe definirse desde el primer día de WS. Si se lanza con in-memory, el primer deploy multi-worker rompe silenciosamente.

---

### Pitfall 4: Pagos sin idempotencia ni verificación de webhook — doble cobro o fraude

**What goes wrong:**
(1) El cliente paga; la app no recibe respuesta por timeout de red y **reintenta** → se generan **dos transacciones**, doble cobro. (2) El webhook de la pasarela confirma el pago pero el backend no verifica la firma → un atacante envía un webhook falso "APROBADO" y obtiene comida gratis marcando pedidos como pagados. (3) La pasarela reenvía el webhook (at-least-once) y el backend procesa el pedido dos veces. (4) El pedido se marca pagado sin conciliar contra el estado real de la transacción en la pasarela.

**Why it happens:**
Las pasarelas (Wompi/PayU en Colombia) usan **entrega at-least-once** de webhooks: el mismo evento puede llegar varias veces. Sin idempotencia (`evento.id` deduplicado) y sin verificación de firma (HMAC con llave de integridad), el sistema es vulnerable y/o duplica. Los devs suelen confiar en la respuesta HTTP del checkout y omitir el webhook, o implementar el webhook sin validar firma "para probar rápido".

**How to avoid:**
1. **Idempotency-Key en la creación de transacción**: el cliente genera un UUID por intento de pago; el backend lo guarda con `UNIQUE`. Reintentos con misma key → misma transacción, no se duplica.
2. **Verificación de firma del webhook (obligatorio)**: Wompi usa llaves de integridad y una `signature`/checksum calculado sobre propiedades del evento + secreto. Recalcular en el backend y rechazar (`401`) si no coincide. Nunca confiar en el body sin verificar.
3. **Idempotencia por `evento.id`**: tabla `webhook_eventos (id PK, procesado_at)`. Antes de procesar, verificar si el evento ya fue procesado; si sí, devolver 200 sin reprocesar.
4. **Estado del pago como máquina de estados**: `pendiente → aprobado → conciliado` (o `rechazado`). Solo `conciliado` (tras webhook verificado) libera el pedido. Nunca marcar pagado por la respuesta del checkout del cliente.
5. **Reconciliación periódica**: job que consulta el estado real de transacciones `pendiente` vía API de la pasarela (no solo webhook) por si el webhook se perdió. El webhook es el camino rápido, la consulta API es la red de seguridad.
6. **Webhook debe responder 200 rápido**: no hacer lógica pesada sincrónica que haga timeout y provoque reintentos. Encolar o procesar async tras verificar firma.

**Warning signs:**
- El webhook handler no verifica firma ni tiene tabla de eventos procesados.
- El pedido se marca pagado en la respuesta del endpoint `/pagar`, no en el webhook.
- No hay plan de reconciliación: si falla el webhook, el pedido queda "pendiente" para siempre.
- En pruebas, reenviar el mismo webhook crea dos pedidos.

**Phase to address:**
**Fase de Pagos** (Fase 5). El modelo de datos de transacciones (con `idempotency_key` único, `evento_id` deduplicado, máquina de estados) debe diseñarse ANTES de integrar la pasarela. La verificación de firma y la tabla de eventos procesados son requisitos de aceptación de la fase, no nice-to-have.

---

### Pitfall 5: Escalada de privilegios entre restaurantes (multi-tenant sin aislamiento en queries)

**What goes wrong:**
El admin del Restaurante A, manipulando IDs en una petición (`GET /api/mesas/{otro_restaurante_id}` o `PUT /pedidos/{id}`), accede o modifica datos del Restaurante B. O un mesero asume rol de admin. El super-admin GRI puede operar todo, pero los roles por restaurante no están aislados: el middleware de auth verifica "es admin" pero no "es admin **de este restaurante**".

**Why it happens:**
La auth por rol (`is_admin: true`) es estándar y fácil; la **autorización por tenant** (este admin pertenece a este restaurante y solo a este) se olvida. Las queries del ORM no filtran automáticamente por `restaurante_id`; el dev debe acordarse en cada query. Un endpoint olvidado (`/pedidos/{id}` sin check de que el pedido pertenece al restaurante del usuario) abre filtrado/escritura cruzada.

**How to avoid:**
1. **`restaurante_id` en cada tabla de negocio** (mesas, menu, pedidos, reservas, clientes) con FK + índice. Sin excepciones.
2. **Filtro de tenant a nivel de query layer, no por endpoint**: implementar un `current_restaurante_id` derivado del JWT/sesión e inyectarlo en todos los queries automáticamente (dependency de FastAPI que filtra el query). El principio: que sea más difícil hacer una query SIN filtro que con él.
3. **Validación de propiedad en cada mutación**: antes de `UPDATE pedidos SET ...`, verificar `pedido.restaurante_id == current_user.restaurante_id`. Helper reutilizable.
4. **Tests de penetración de tenant automatizados**: por cada endpoint, un test que use credenciales del Restaurante A intentando acceder a recursos del Restaurante B → debe dar 404/403. Sin esto, el olvido en un endpoint se descubre en producción.
5. **Roles en JWT con scope de restaurante**: el token lleva `{"role": "admin_restaurante", "restaurante_id": 42}`. El super-admin GRI no tiene `restaurante_id` (es global). Validar en cada endpoint.
6. **IDs internos opacos vs. secuenciales**: evitar exponer `/pedidos/1, /pedidos/2...` que invita a enumeration. Usar UUID o validar propiedad antes de devolver.

**Warning signs:**
- Existe `role` en el token pero no `restaurante_id`.
- Endpoints que reciben `{id}` y devuelven el recurso sin verificar pertenencia.
- No hay tests automatizados de acceso cruzado entre restaurantes.
- Un endpoint "funciona" devolviendo datos sin importar quién pide.

**Phase to address:**
**Fase de Autenticación / Foundation** (Fase 1). El aislamiento por tenant debe diseñarse con el modelo de datos desde el inicio (el `restaurante_id` en cada tabla) y la dependency de FastAPI que filtra queries debe existir antes de cualquier endpoint de negocio. Retrofitear multi-tenant a una app mono-tenant es reescribir todos los queries.

---

### Pitfall 6: QR de mesa sin vinculación a sesión/usuario — spoofing, reuso y mesa incorrecta

**What goes wrong:**
El QR contiene un ID secuencial (`GRI-MESA-001`) o una URL predecible. (1) Un cliente fotocopía/comparte el QR y hace pedidos a esa mesa desde fuera del local. (2) El cliente escanea el QR de la mesa 5 pero se sienta en la 6; sus pedidos llegan a la mesa equivocada. (3) El QR de la mesa sigue activo días después; un cliente escanea y la mesa aparece "disponible" cuando en realidad el restaurante cambió la numeración. (4) El mismo QR permite a varios clientes distintos abrir sesión simultánea y hacer pedidos contradictorios sobre la misma mesa.

**Why it happens:**
El QR se trata como un "link permanente a la mesa" en vez de como un **token de sesión efímera**. Sin vincular el escaneo a (a) un usuario autenticado, (b) una sesión activa, y (c) una validación de que la mesa sigue existiendo/disponible, el QR es un vector de abuso y de error operativo.

**How to avoid:**
1. **QR apunta a un endpoint que abre sesión, no a la mesa directamente**: `POST /qr/escanear/{token_mesa}` crea una `sesion_mesa` con estado (`activa`, `cerrada`, `expirada`), usuario, timestamp de inicio. El token del QR puede ser estable por mesa, pero la sesión es efímera.
2. **Auth obligatoria antes de abrir sesión**: el cliente debe estar logueado (PROJECT.md ya exige auth en todas las apps). Sin usuario, no hay sesión.
3. **Validación de mesa activa y disponible**: al escanear, verificar que la mesa existe, pertenece al restaurante correcto y está en estado que permite abrir sesión (`disponible`/`reservada` para ese cliente). Si está `ocupada` por otra sesión, rechazar o avisar al mesero.
4. **Una sesión activa por mesa a la vez** (o política definida: ¿mesa compartida?): constraint `UNIQUE (mesa_id) WHERE estado = 'activa'` o lógica equivalente. Evita dos clientes compitiendo.
5. **Expiración/cierre de sesión**: el mesero cierra la sesión al cobrar; un timeout (ej. 3h) la cierra si se olvidó. Sin esto, sesiones zombis bloquean mesas.
6. **Token del QR no secuencial**: usar un token aleatorio (no `MESA-001` que se adivina). El ID visible puede ser 001, pero el QR codifica un token no enumerable.

**Warning signs:**
- El QR codifica solo el `mesa_id` numérico.
- Se puede hacer pedidos sin sesión activa asociada.
- No hay concepto de "cerrar sesión de mesa".
- Tras un día, hay 50 sesiones `activa` en la BD que nunca cerraron.
- Pedidos llegan a mesas donde el cliente ya se fue.

**Phase to address:**
**Fase de Cliente Móvil / Pedidos por QR** (Fase 3). El modelo de `sesion_mesa` debe diseñarse junto con el flujo de pedido, antes de implementar el escaneo. El cierre de sesión debe coordinarse con el pago (Fase 5): pagar = libera la mesa.

---

## Technical Debt Patterns

Atajos que parecen razonables pero generan problemas. Notar cuándo son aceptables en MVP.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `ConnectionManager` in-memory sin Redis | Menos infra en dev, tutorial copiado | Rompe con múltiples workers en prod; reescritura del manager | **Nunca** si se planea >1 worker. Aceptable en demo de 1 sola |
| Estado de mesa calculado on-the-fly en cada query | No hay que sincronizar columna | Lógica duplicada, drift, inconsistencias | MVP muy pequeño, pero documentar la deuda |
| Trust en la respuesta del checkout en vez del webhook | Integración de pago más rápida | Doble cobro, fraude, sin conciliación | **Nunca** en producción. Solo spike |
| `GET /recurso/{id}` sin validar tenant | Menos código por endpoint | Filtrado/escritura cruzada entre restaurantes | **Nunca**. La dependency de tenant debe existir desde Fase 1 |
| Seed de demo mezclado con datos reales | "Funciona para probar" | Restaurante demo aparece en reportes de prod, IDs colisionan | Solo si hay flag de entorno estricto `DEMO_MODE` |
| IDs secuenciales expuestos en API/UI | Simple, ordenado | Enumeration, adivinación de mesa/pedido | MVP, migrar a UUID/opaco antes de multi-tenant serio |
| WebSockets sin heartbeat | Menos código | Sockets zombis, broadcast falla silenciosamente | Demo corta; inaceptable en prod |
| JWT sin expiración corta + refresh | UX "siempre logueado" sin esfuerzo | Token robado = acceso perpetuo | Requerir refresh tokens desde el inicio |

## Integration Gotchas

Errores comunes al conectar servicios externos.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Wompi / PayU (webhook) | Procesar sin verificar `signature`/llave de integridad | Recalcular HMAC con secreto, rechazar si no coincide (MEDIUM confidence — docs oficiales inaccesibles 403, verificar en Fase de Pagos) |
| Wompi / PayU (webhook) | Asumir entrega única del evento | Tabla `webhook_eventos` con `evento.id` único; idempotencia |
| Wompi / PayU (transacción) | Reintentar pago creando nueva transacción | `Idempotency-Key` por intento lógico; mismo key = misma transacción |
| Wompi / PayU (conciliación) | Confiar solo en webhook | Job periódico consulta estado real vía API para `pendiente` |
| MySQL en Docker | No montar volumen para `/var/lib/mysql` | `docker run -v mysql_data:/var/lib/mysql` — sin volumen, `docker rm` borra TODA la BD |
| MySQL (charset) | Collation por defecto `latin1`/`utf8` (3-byte) | Forzar `utf8mb4` y `utf8mb4_unicode_ci`/`0900_ai_ci` en server, DB, tabla y columna. Emoji y acentos se corrompen con `utf8` |
| MySQL (timezone) | TZ del contenedor = UTC, app asume America/Bogota | Setear `TZ=America/Bogota` en el contenedor y `time_zone='+00:00'` o consistente en MySQL; NUNCA mezclar TIMESTAMP naive con aware |
| Flutter Web → FastAPI (CORS) | Olvidar `CORSMiddleware` o permitir `*` en prod | Orígenes específicos del admin web en prod; `allow_credentials=True` solo con orígenes explícitos |
| Flutter Web (render) | Asumir canvas kit = bueno para todo | Canvas kit indexa mal en SEO (no aplica a admin interno) y Wasm requiere headers COEP/COOP. Para admin interno, HTML/canvas está bien |
| WebSocket detrás de proxy/nginx | Proxy corta conexiones idle a los 60s | Configurar `proxy_read_timeout` alto + heartbeat ping/pong cada 25-30s |
| QR → API | QR con `mesa_id` predecible y permanente | Token opaco + sesión efímera vinculada a usuario |

## Performance Traps

Patrones que funcionan a pequeña escala pero fallan al crecer.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| N+1 en mapa de mesas (1 query por mesa para su estado) | Dashboard admin lento con muchas mesas | JOIN/aggregate en una query; o vista materializada | >20 mesas con estado calculado en runtime |
| Broadcast WS a TODAS las conexiones por cada evento | CPU/network se satura con cada pedido | Filtrar por `restaurante_id` (rooms); solo clientes del restaurante reciben | >50 conexiones concurrentes globales |
| Polling HTTP en vez de WS (por "simplicidad") | Cientos de requests/min, BD saturada | WebSockets/SSE para tiempo real desde el inicio | >10 clientes haciendo polling cada 2s |
| Sincronización completa de menú en cada apertura de app | Carga lenta, datos móviles consumidos | Caché con ETag/versionado en cliente; delta solo cambios | Menú >50 ítems o muchos clientes |
| WS envía payloads gigantes (objeto restaurante completo por delta) | Latencia visible, memory en móvil | Enviar solo el campo cambiado + `version` | Estados de mesa o pedidos con mucho detalle |
| Consultar la pasarela de pago sincrónicamente en cada request de estado | Endpoint de pago lento, timeouts | Caché corto del estado de transacción; webhook como fuente principal | Concurrencia alta en consulta de pedido |
| Transacciones de BD largas (incluyendo WS broadcast dentro) | Locks, lentitud, deadlocks | Broadcast DESPUÉS del commit, no dentro de la transacción | Cualquier carga; empeora con concurrencia |

## Security Mistakes

Problemas de seguridad específicos del dominio (más allá de OWASP base).

| Mistake | Risk | Prevention |
|---------|------|------------|
| Webhook de pago sin verificación de firma | Fraude: webhook falso marca pedidos como pagados | HMAC con llave de integridad; rechazar si no cuadra |
| Sin aislamiento de tenant en queries | Restaurante A lee/modifica datos de Restaurante B | `restaurante_id` en cada tabla + filtro automático en query layer + tests de acceso cruzado |
| QR de mesa como token permanente y predecible | Pedidos remotos maliciosos, mesa equivocada | Token opaco + sesión efímera vinculada a usuario autenticado |
| JWT de larga duración sin refresh | Token comprometido = acceso permanente | Access token corto (15 min) + refresh token rotativo |
| Rol verificado pero no scope de restaurante | Mesero se hace pasar por admin, o admin cruza restaurantes | Token con `{role, restaurante_id}`; validar ambos por endpoint |
| IDs secuenciales en endpoints públicos | Enumeration de mesas/pedidos/clientes | UUID o validación de pertenencia antes de responder |
| Logs/errores exponen datos de pago (número de tarjeta) | Incumplimiento normativo, fuga | Nunca loggear PAN/full card; tokenizar; enmascarar |
| Super-admin GRI con privilegios sin auditoría | Abuso o error sin rastro | Log de auditoría de acciones de super-admin (creación de restaurantes, etc.) |
| Contraseñas de seed/demo en prod | Acceso trivial a cuentas demo | Seed solo si `DEMO_MODE=true`; passwords aleatorios o deshabilitados en prod |
| WS sin auth en conexión | Cualquiera se conecta al canal y ve pedidos | Token en query/subprotocol al conectar; validar y rechazar WS si inválido |

## UX Pitfalls

Errores de experiencia comunes en este dominio.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Pedido enviado sin confirmación visible | Cliente duda si se envió, toca de nuevo (duplica) | Pantalla de "pedido en cocina" con estado en tiempo real + idempotencia por si toca dos veces |
| Estado del pedido no actualiza al volver de background | Cliente ve estado obsoleto tras reabrir app | Re-fetch HTTP del estado al resumir + WS para deltas |
| Mesa marcada equivocada al escanear QR de mesa vecina | Pedido llega a otra mesa, confusión | Confirmar "Estás en la Mesa 5 del Restaurante X" antes de abrir menú |
| Menú muestra ítem agotado solo al intentar pedir | Frustración tardía | Badge "agotado" en el ítem desde el inicio del menú |
| Pago "en proceso" sin feedback | Cliente no sabe si cobraron | Estados claros del pago (pendiente/aprobado/rechazado) con timestamp |
| Solicitar cuenta al mesero sin canal de confirmación | Cliente no sabe si el mesero vio el pedido | ACK visible ("mesero notificado") + estado |
| Reserva sin confirmación de superposición de horario | Cliente cree que reservó pero fue rechazado | Feedback inmediato de disponibilidad antes de confirmar |
| App lenta al abrir por WS pendiente | Experiencia de carga rota | No bloquear UI esperando WS; cargar con HTTP primero |
| Sin manejo de offline/conexión perdida | Pedido "desaparece" si cae la red en medio | Cola local de acciones + reintento con idempotencia |

## "Looks Done But Isn't" Checklist

Cosas que parecen completas pero faltan piezas críticas.

- [ ] **Reservas:** Parece done pero falta — constraint único o `FOR UPDATE`. Verificar: simular dos reservas simultáneas a la misma mesa/hora (script de concurrencia) → una debe fallar con 409.
- [ ] **Estado de mesa:** Parece done pero falta — máquina de estados con transiciones válidas y reconciliación de sesiones expiradas. Verificar: forzar una sesión zombi y comprobar que un job la cierra.
- [ ] **WebSockets:** Parece done pero falta — Redis Pub/Sub entre workers + re-sync on reconnect + heartbeat. Verificar: levantar 2 workers, crear pedido por uno, confirmar que el cliente conectado al otro lo recibe.
- [ ] **Pagos:** Parece done pero falta — verificación de firma del webhook + idempotencia de evento + reconciliación. Verificar: reenviar el mismo webhook dos veces → procesa una; mandar webhook con firma inválida → 401.
- [ ] **Multi-tenant:** Parece done pero falta — filtro de `restaurante_id` en cada query + tests de acceso cruzado. Verificar: con token del Restaurante A, intentar `GET /pedidos/{id_de_B}` → 404/403.
- [ ] **QR de mesa:** Parece done pero falta — sesión efímera vinculada a usuario + cierre de sesión. Verificar: sin sesión activa no se puede pedir; un mismo usuario no abre dos sesiones en mesas distintas.
- [ ] **Menú con disponibilidad:** Parece done pero falta — decremento atómico de stock al pedir y marca "agotado". Verificar: dos clientes piden el último ítem simultáneamente → uno queda sin stock y se marca agotado.
- [ ] **MySQL Docker:** Parece done pero falta — volumen persistente + charset `utf8mb4` + timezone consistente. Verificar: `docker compose down && up` conserva datos; `SHOW VARIABLES LIKE 'character_set%'` dice `utf8mb4`.
- [ ] **Seed demo:** Parece done pero falta — flag de entorno que lo aisle de prod. Verificar: en `DEMO_MODE=false` no se siembra el restaurante demo.
- [ ] **Auth:** Parece done pero falta — refresh token + expiración corta + scope de restaurante. Verificar: token expira y se refresca sin re-login; mesero no accede a endpoints de admin.
- [ ] **Flutter Web admin:** Parece done pero falta — CORS configurado + cache-busting post-deploy. Verificar: deploy nuevo y refrescar muestra la versión nueva (no cacheada).
- [ ] **Cocina tiempo real:** Parece done pero falta — cocina recibe pedidos tras reconexión. Verificar: matar y reabrir el navegador de cocina con un pedido en curso → ve el estado actual, no vacío.

## Recovery Strategies

Cuando el pitfall ocurre a pesar de la prevención, cómo recuperarse.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Doble reserva creada por race condition | LOW | Script que detecte reservas solapadas (mismo mesa/hora/slot) → reembolsar/anular una, contactar al cliente afectado, añadir el constraint único que faltaba |
| Estado de mesa en drift permanente | MEDIUM | Script de reconciliación: recalcular `estado` desde fuentes (sesiones, reservas, pedidos) para todas las mesas; definir la máquina de estados; añadir tests de transición |
| WS in-memory ya en prod sin Redis | MEDIUM | Migrar ConnectionManager a Redis Pub/Sub; no requiere cambio de schema, pero requiere re-desplegar todos los workers a la vez y reiniciar conexiones |
| Doble cobro por falta de idempotencia | HIGH | Identificar transacciones duplicadas (mismo `idempotency_key` o mismo cliente/monto en ventana corta) → reembolso manual vía la pasarela; implementar idempotency antes de reabrir pagos |
| Webhook falso procesado (sin firma) | HIGH | Auditar qué pedidos se marcaron pagados sin transacción real en la pasarela; revertir; implementar verificación de firma inmediatamente; rotar llaves |
| Filtrado de datos entre restaurantes detectado | HIGH | Auditar accesos, notificar a restaurantes afectados, parchear el endpoint vulnerable, añadir tests de tenant, considerar regulatorio si hay datos personales |
| Sesiones QR zombis bloqueando mesas | LOW | Script que cierre sesiones `activa` con `updated_at` > N horas; añadir timeout automático y cierre al pagar |
| BD MySQL perdida por `docker rm` sin volumen | **CRITICAL** | Si no hay backup, los datos se pierden. Restaurar del último backup; crear volumen persistente Y backups automáticos antes de volver a levantar |
| Datos corruptos por charset `utf8` | MEDIUM | Migrar DB/tablas a `utf8mb4`, reparar strings corruptos (no siempre recuperable); script de conversión + validación |
| Token JWT comprometido | MEDIUM | Rotar secreto de firma (invalida todos los tokens), forzar re-login a todos los usuarios, añadir refresh + expiración corta |

## Pitfall-to-Phase Mapping

Cómo las fases del roadmap deben abordar estos pitfalls. (Nombres temáticos — el orquestador debe mapear a las fases reales del ROADMAP.)

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Multi-tenant sin aislamiento (P5) | **Fase 1: Foundation / Auth** | Tests de acceso cruzado pasan; `restaurante_id` en cada tabla de negocio; dependency de filtro existe |
| Escalada de privilegios / roles (P5) | **Fase 1: Foundation / Auth** | Token con `{role, restaurante_id}`; mesero no accede a endpoints de admin; refresh funciona |
| MySQL Docker sin volumen/charset/TZ | **Fase 1: Foundation / Infra** | `docker compose down/up` preserva datos; `SHOW VARIABLES` confirma utf8mb4; TZ consistente |
| Seed demo vs prod (deuda) | **Fase 1: Foundation** | `DEMO_MODE=false` no siembra demo; seed aislado por entorno |
| Estado de mesa ambiguo (P2) | **Fase 2: Panel Admin / Mesas** | Máquina de estados documentada; transiciones inválidas rechazadas; job de reconciliación existe |
| Race condition en reservas (P1) | **Fase 2/3: Reservas** | Test de concurrencia (2 requests simultáneos) → uno recibe 409; constraint único en schema |
| QR spoofing / mesa incorrecta (P6) | **Fase 3: Cliente Móvil / QR** | Sin auth no hay sesión; una sesión activa por mesa; cierre al pagar |
| Menú sin disponibilidad atómica | **Fase 3: Cliente Móvil / Pedidos** | Stock decrementado atómico; ítem se marca agotado; test de concurrencia en último ítem |
| WS in-memory sin Redis (P3) | **Fase 4: Tiempo Real** | 2 workers, pedido por worker A llega a cliente en worker B; reconnect re-sincroniza estado |
| WS drift estado / reconexión (P3) | **Fase 4: Tiempo Real** | Cliente reconecta y obtiene snapshot correcto; heartbeat detecta zombis |
| Pagos sin idempotencia/firma/webhook (P4) | **Fase 5: Pagos** | Webhook reenviado procesa 1 vez; firma inválida → 401; job de reconciliación corre |
| CORS / cache-busting Flutter Web admin | **Fase 6: Deploy / Hardening** | CORS con orígenes específicos; deploy nuevo se ve sin cache; Wasm con COEP/COOP si aplica |

## Sources

- **FastAPI — WebSockets** (oficial): https://fastapi.tiangolo.com/advanced/websockets/ — Confirma que `ConnectionManager` in-memory "only works with a single process"; recomienda `encode/broadcaster` (Redis/Postgres) para multi-proceso. `WebSocketDisconnect` es la señal de desconexión. [HIGH confidence]
- **Flutter — Build and release a web app** (oficial): https://docs.flutter.dev/deployment/web — Confirma: builds Wasm requieren headers COEP/COOP; source maps exponen código si se hostean públicamente; cache-busting necesario post-deploy. [HIGH confidence]
- **Flutter — Web FAQ** (oficial): https://docs.flutter.dev/platform-integration/web/faq — Confirma: `dart:io`/`Platform.is*` lanza `UnsupportedError` en web (usar `kIsWeb`); isolates no soportados en web; Flutter web no apto para SEO; CORS controlado por el browser; conditional imports distintos para Wasm (`dart.library.js_interop`). [HIGH confidence]
- **Wompi Colombia — Webhooks / Llaves de integridad**: https://docs.wompi.co/docs/co/ — **NO accesible (HTTP 403, protección anti-bot)**. Claims sobre firma de integridad, entrega at-least-once e idempotencia son conocimiento de dominio bien establecido pero NO verificados contra docs vivos en esta sesión. [MEDIUM confidence — **verificar en Fase de Pagos**]
- **Concurrencia de reservas / multi-tenant / máquinas de estados / MySQL Docker**: conocimiento de ingeniería estándar y bien documentado (constraints únicos, `SELECT FOR UPDATE`, utf8mb4, volúmenes Docker). [HIGH confidence — verdades fundamentales de BD/concurrencia, no claims de vendor]
- **MySQL character sets**: documentación oficial MySQL cubre utf8mb4 vs utf8 (3-byte) y problemas con emoji/4-byte chars. [HIGH confidence]
- **Docker volumes & data persistence**: documentación oficial Docker — sin volumen montado, `docker rm` destruye datos del contenedor. [HIGH confidence]

---
*Pitfalls research for: plataforma multi-restaurante GRI (reservas + QR ordering + tiempo real + multi-tenant + pagos Colombia)*
*Researched: 2026-08-13*
