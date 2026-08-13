# Project Research Summary

**Project:** GRI — Gestión y Reservas de Restaurantes
**Domain:** Multi-tenant SaaS para restaurantes (reservas + QR ordering + pagos dine-in, sin delivery)
**Researched:** 2026-08-13
**Confidence:** HIGH (overall) — MEDIUM acotado a la integración con pasarela colombiana

## Executive Summary

GRI es una plataforma multi-restaurante que combina **tres productos típicamente separados** —reservas estilo OpenTable, QR ordering estilo Mr Yum/Bbot, y dashboard operativo— en un solo SaaS con super-admin. El stack ya está decidido por el usuario (Flutter móvil + Flutter Web + FastAPI + MySQL sobre Docker/Ubuntu), y la investigación prescribe las mejores librerías dentro de cada capa con versiones verificadas a Aug 2026. La arquitectura recomendada es un **monolito modular FastAPI** (no microservicios) con multi-tenant vía shared DB + `restaurant_id`, tiempo real vía WebSockets con rooms por restaurante, y JWT único multi-rol con claims `role` + `restaurant_id`. Para la escala de GRI v1 (decenas a centenas de restaurantes, 1 instancia de API), esto es lo correcto; partir en microservicios sería over-engineering.

La complejidad real del proyecto no está en la tecnología (patrones bien establecidos y documentados), sino en **tres riesgos de dominio**: (1) concurrencia en reservas y stock que solo se resuelve con constraints de BD + bloqueos pesimistas, no con lógica de aplicación; (2) aislamiento multi-tenant que requiere disciplina arquitectónica —el `TenantScope` debe filtrar toda query staff automáticamente, o ocurrirán leaks cross-restaurante; y (3) WebSockets que rompen silenciosamente al escalar workers o al reconectar clientes —el tutorial de FastAPI es solo para 1 proceso. La integración con pasarela colombiana (Wompi preferida sobre PayU/Mercado Pago) suma riesgo porque los docs oficiales no fueron accesibles (HTTP 403 anti-bot) y queda pendiente verificación en su fase.

La mitigación transversal es **diseñar los mecanismos de seguridad desde el día 1, no como optimización posterior**: constraint único `(mesa_id, slot)` en reservas, `restaurant_id` en cada tabla de negocio con dependency FastAPI que inyecta el filtro, máquina de estados explícita para mesa y pedido, verificación HMAC de webhooks con idempotencia por `evento.id`, y abstracción `Broadcaster` lista para Redis Pub/Sub aunque la implementación v1 sea in-memory. Migrar cualquiera de estos después de tener datos en producción es caro o imposible.

## Key Findings

### Recommended Stack

El stack base es decisión del usuario; la investigación prescribe librerías específicas con versiones verificadas contra PyPI y pub.dev a Agosto 2026. Confidence HIGH en capas Python/Flutter; MEDIUM en pasarelas de pago (training data, docs inaccesibles).

**Backend (FastAPI):**
- **Python 3.12 + FastAPI 0.141.1 + uvicorn[standard] 0.52.2** — runtime async nativo con WebSocket, OpenAPI automático, DI.
- **SQLAlchemy 2.0.52 (async) + asyncmy 0.2.14 + Alembic 1.19.1** — asyncmy sobre aiomysql (5x más rápido en resultsets grandes, drop-in API, wheels multiplataforma).
- **PyJWT 2.13.0** sobre `python-jose` (más activo: 4 releases 2026 vs 0).
- **bcrypt o argon2-cffi + pydantic-settings + httpx + ruff/black + pytest-asyncio**.
- **MySQL 8.4 LTS** (soporte hasta Abr 2032) en Docker con charset `utf8mb4` obligatorio.

**Frontend (Flutter 3.35+ / Dart 3.9+):**
- **flutter_riverpod 3.4.2** sobre Bloc/Provider (mejor DX, Flutter Favorite, AsyncValue nativo).
- **dio 5.11.0** (interceptors para refresh JWT), **go_router 17.5.0** (oficial, deep linking para QR), **web_socket_channel 3.0.3** (oficial Dart team), **mobile_scanner 7.4.0** (de facto, ML Kit nativo).
- **freezed + json_serializable + build_runner** para DTOs inmutables; **flutter_secure_storage** para JWT (NO `shared_preferences`).

**Infraestructura:** Docker Compose v2 + Ubuntu Server 24.04 LTS + Nginx (reverse proxy/TLS) + Redis 7.4 (Pub/Sub para WS multi-worker, opcional en v1 de 1 instancia).

**Pagos Colombia (MEDIUM confidence — decidir en su fase):**
- **Wompi** recomendado como default (PSE + tarjetas + NEQUI + Botón Bancolombia + Efecty, COP nativo, webhooks confiables, ~2.9% + $900).
- **Mercado Pago** como segunda opción (Checkout Pro redirect → PCI-DSS trivial, API excelente).
- **PayU** solo si se necesita multi-país LATAM desde día 1.

Ver STACK.md para tabla completa de alternativas, "What NOT to Use" y comandos de instalación.

### Expected Features

El scope v1 está decidido en PROJECT.md y validado contra mockups (`documentos/index.html`, `indexcliente.html`). Las features se agrupan en tres categorías con dependencias claras.

**Table stakes (lanzar con esto — todos P1):**
- Auth multirol (5 roles: super-admin GRI, admin restaurante, mesero, cocina, cliente) + JWT con refresh.
- Multi-restaurante con super-admin + **restaurante demo sembrado** con mesas/menú/clientes ficticios.
- Gestión de mesas (CRUD) con 4 estados (disponible/ocupada/reservada/limpieza) sincronizados por WebSocket.
- Mapa visual de mesas en tiempo real (panel admin, colores del mockup).
- Reservas: crear, consultar, cancelar + disponibilidad por fecha/hora/personas.
- Gestión de menú con categorías, ítems, modifiers y disponibilidad on/off (86).
- Escanear QR de mesa → sesión vinculada a usuario autenticado → armar carrito con modifiers → enviar a cocina.
- Estado de pedido en tiempo real (WebSocket push) con máquina de estados explícita.
- Vista cocina KDS ligero (lista con tiempo transcurrido + botón "listo").
- Pedir cuenta → aviso a mesero → pago en línea → calificación post-experiencia.
- Dashboard admin con estadísticas + reportes básicos (ventas, top items, ocupación).
- Gestión de clientes (lista + historial de reservas/pedidos).

**Differentiators estructurales (ya en v1):** QR ordering + reservas en una sola app (Mr Yum + OpenTable combinados), multi-restaurante SaaS-ready desde día 1, mapa visual de mesas en tiempo real vs. planillas de competencia local.

**Defer (v1.x o v2):** Propina desde app (v1.x si gateway lo soporta limpio), waitlist con WhatsApp (v1.x), CRM enriquecido (v1.x), split bill (v1.x), push notifications FCM/APNs (v2), multi-idioma (v2), multi-sede (v2), lealtad/puntos (v2).

**Anti-features (NO construir — previene scope creep):** POS tradicional con caja/impresora fiscal (GRI es capa digital sobre el POS existente), autoregistro de restaurantes, delivery/domicilios, multi-idioma en v1, reservas con depósito/garantía (complejo legalmente en LatAm), AI chatbot, app nativa separada por plataforma, KDS con routing por estación.

Ver FEATURES.md para matriz de competidores, dependencias detalladas, state machines (Pedido/Mesa/Reserva) y matriz de priorización.

### Architecture Approach

**Monolito modular FastAPI** con separación horizontal por capas (routers delgados → services con lógica → repos con queries) y vertical por bounded contexts (auth, restaurante, pedido, pago, realtime). Multi-tenant vía **shared DB + `restaurant_id`** en cada tabla de negocio (FK + índice compuesto) con `TenantScope` dependency que inyecta el filtro automáticamente — es operacionalmente simple y permite joins cross-tenant para reportes del super-admin.

**Major components:**
1. **App Cliente (Flutter móvil)** — UX del comensal: discover, reservar, escanear QR, armar pedido, seguir en vivo, pagar, calificar. Con dio + web_socket_channel + flutter_secure_storage.
2. **Panel Admin (Flutter Web)** — UX operativa: dashboard, mapa de mesas, CRUD completo, vista cocina, reportes. Roles derivan vistas; go_router con ShellRoute para sidebar.
3. **API FastAPI (núcleo único)** — Toda la lógica de negocio. Routers: `/auth`, `/public`, `/cliente`, `/staff`, `/admin-gri`, `/ws`. Services: AuthService, TenantScope, PedidoService, MesaService, PagoService, RealtimeHub.
4. **MySQL 8.4 LTS (Docker)** — Fuente de verdad transaccional, 1 schema shared con tenant_id en cada tabla.
5. **RealtimeHub (ConnectionManager)** — Rooms por restaurante, broadcast desde services tras commit DB.
6. **Pasarela de pago colombiana** — REST crear intención + webhook asíncrono con HMAC de firma.

**Patrones arquitectónicos clave:**
- **TenantScope dependency** inyecta `restaurant_id` en toda query staff (previene leak cross-tenant).
- **JWT único multi-rol** con claims `{sub, role, restaurant_id}` (nullable para cliente y super-admin).
- **WebSocket con rooms por restaurante** — `/ws?token=JWT`, room = `restaurant:{id}` o `user:{sub}`.
- **QR estable por mesa** (`GRI-MESA-001`) — suficiente porque JWT es el boundary de auth; abre sesión efímera vinculada a usuario al escanear.
- **State machines explícitas** para Mesa (6 transiciones) y Pedido (7 estados, 2 terminales) — transiciones inválidas → 409 Conflict.
- **Abstracción `Broadcaster`** lista para Redis Pub/Sub aunque v1 use in-memory (prevenir reescritura al escalar workers).

Ver ARCHITECTURE.md para diagrama completo, estructura de carpetas backend/frontend, flujo de datos end-to-end, matriz rol×endpoint, y consideraciones de escalado por tramos (0-10 / 10-100 / 100+ restaurantes).

### Critical Pitfalls

Los 6 pitfalls críticos (reescritura, pérdida de dinero o datos corruptos) con su prevención:

1. **Race condition en reservas** (doble reserva de la misma mesa/hora bajo concurrencia) → defensa principal en BD: `UNIQUE (mesa_id, fecha, turno_slot)` + `SELECT ... FOR UPDATE` + query de exclusión de rangos + `Idempotency-Key` header.
2. **Estado de mesa ambiguo** (drift entre almacenado y calculado) → `mesa.estado` como **estado almacenado autoritativo** mutado solo por eventos de la state machine + job de reconciliación periódico para sesiones zombis.
3. **WebSockets in-memory no sobrevive multi-worker ni reconexiones** → **abstracción `Broadcaster` desde el día 1** (aunque v1 use in-memory), re-sync HTTP al reconectar (WS = notificación, no fuente de estado), sequence numbers para replay, heartbeat ping/pong para detectar zombis, handlers idempotentes.
4. **Pagos sin idempotencia ni verificación de webhook** (doble cobro o fraude) → `Idempotency-Key` por intento, verificación HMAC de firma (rechazar 401 si no cuadra), tabla `webhook_eventos` con `evento.id` único, máquina de estados `pendiente→aprobado→conciliado`, job de reconciliación que consulta API de pasarela para `pendiente`.
5. **Escalada de privilegios cross-tenant** (admin del restaurante A accede a datos del B) → `restaurant_id` en cada tabla de negocio + `TenantScope` que filtra queries automáticamente + validación de propiedad en cada mutación + tests automatizados de acceso cruzado por endpoint.
6. **QR de mesa sin vinculación a sesión** (spoofing, mesa incorrecta, reuso malicioso) → QR abre **sesión efímera vinculada a usuario autenticado**, auth obligatoria antes de sesión, validación de mesa disponible, `UNIQUE (mesa_id) WHERE estado='activa'`, cierre al pagar + timeout de N horas.

Otros riesgos: MySQL Docker sin volumen persistente (pérdida crítica de BD), charset `utf8` (3-byte) en vez de `utf8mb4` (corrupción de emojis/acentos), timezone inconsistente entre contenedor y app, Flutter Web sin CORS configurado, WS detrás de nginx sin `proxy_read_timeout` alto. Ver PITFALLS.md para "Looks Done But Isn't" checklist y estrategias de recuperación.

## Implications for Roadmap

Las 4 investigaciones convergen en un orden de fases dictado por dependencias técnicas (FEATURES.md), agrupamiento por bounded contexts (ARCHITECTURE.md), y prevención de pitfalls desde el momento correcto (PITFALLS.md). **8 fases sugeridas:**

### Phase 1: Foundation & Infraestructura
**Rationale:** Todo bloquea sin esto. Docker Compose con MySQL + API skeleton + Alembic + healthcheck + env config. Sin infra no corre nada.
**Delivers:** Repos inicial con backend ejecutable, MySQL con volumen persistente + charset `utf8mb4` + TZ America/Bogota, primera migración vacía, `pydantic-settings` con `.env`, `Dockerfile` y `docker-compose.yml` funcionales.
**Addresses:** Ninguna feature aún; habilita todas.
**Avoids:** PITFALL MySQL Docker sin volumen (crítico — pérdida de BD), charset incorrecto, timezone inconsistente. Estas decisiones deben tomarse ANTES de tener datos.

### Phase 2: Auth + Multi-tenant Core
**Rationale:** Sin auth multirol y aislamiento tenant, ningún endpoint staff es seguro. La dependency `TenantScope` debe existir antes de cualquier endpoint de negocio — retrofitear multi-tenant es reescribir todas las queries.
**Delivers:** Models `usuario`, `restaurant`, `usuario_restaurante`; `/auth/login` + `/auth/refresh`; JWT multi-rol con claims `{role, restaurant_id}`; `TenantScope` dependency; guards `require_role(...)`; tests de acceso cruzado (token de restaurante A → recursos de B = 404).
**Addresses features:** Auth multirol (5 roles), Multi-restaurante con super-admin (parcial — creación de restaurantes).
**Avoids:** PITFALL escalada de privilegios cross-tenant (P5), JWT sin refresh + expiración corta.

### Phase 3: Domain Model + Seed Demo + State Machines
**Rationale:** Con auth listo, se siembran todas las tablas de dominio + el restaurante demo con datos ficticios. Las state machines de Mesa y Pedido se modelan AQUÍ (con el schema), no después — migrar state machines con datos en producción es doloroso.
**Delivers:** Migración crea `mesa`, `categoria`, `producto`, `pedido`, `pedido_item`, `reserva`, `pago`, `calificacion`; constraints únicos `(restaurant_id, codigo)` en mesa, FKs + índices compuestos en todas las tenant tables; `PEDIDO_TRANSITIONS` y `MESA_TRANSITIONS` en código; seed idempotente del restaurante demo con flag `DEMO_MODE`.
**Addresses features:** Restaurante demo sembrado, base para gestión de mesas/menú/reservas/pedidos.
**Avoids:** PITFALL estado de mesa ambiguo (P2) — state machine documentada desde el schema. PITFALL seed demo vs prod — `DEMO_MODE=false` no siembra.

### Phase 4: Panel Admin Read-only + Mapa de Mesas
**Rationale:** Con datos sembrados, se construye el panel admin en **solo lectura** primero (dashboard + mapa de mesas). Esto valida tempranamente que la capa de datos + auth staff + identidad visual del mockup funcionan end-to-end antes de construir features complejas.
**Delivers:** Flutter Web admin con login staff, dashboard con cards de estadísticas (mesas disponibles/ocupadas, reservas hoy, pedidos activos), mapa visual de mesas con 4 colores del mockup (`#20b26b`/`#e74c3c`/`#f5b82e`/`#3478f6`), navegación con go_router y ShellRoute. **Sincronización vía polling HTTP corto** (WS viene en Fase 6) — explícitamente documentado como deuda temporal.
**Addresses features:** Dashboard con estadísticas, Mapa de mesas (parcial — sin sync tiempo real todavía).
**Avoids:** PITFALL polling HTTP (deuda temporal aceptada y marcada para Fase 6).

### Phase 5: Cliente Móvil — Discover + Reservas + QR Ordering (REST)
**Rationale:** La cadena de pedidos por QR es la dependencia más larga del proyecto (7 eslabones según FEATURES.md). Se construye completa con REST (sin WS todavía) — cocina hace refresh manual o poll corto. Funcional aunque no óptimo; el tiempo real llega en Fase 6.
**Delivers:** Flutter móvil cliente con: login cliente, lista y detalle de restaurantes, menú por categoría con modifiers y fotos, wizard de reserva (restaurante → fecha → hora → personas → mesa disponible → confirmar) con `UNIQUE (mesa_id, fecha, turno_slot)` + `FOR UPDATE`, escanear QR con `mobile_scanner` → sesión efímera vinculada a usuario, armar carrito, enviar pedido (POST `/cliente/pedidos`), ver estado vía GET (sin WS), pedir cuenta (aviso a mesero), gestión de reservas y clientes en panel admin (CRUD completo).
**Addresses features:** Buscar restaurantes, ver menú, reservar mesa, consultar reserva, escanear QR, armar pedido, enviar a cocina, ver estado (parcial — REST), pedir cuenta, gestión de reservas y clientes, gestión de mesas y menú (CRUD admin).
**Avoids:** PITFALL race condition en reservas (P1) — constraint + `FOR UPDATE` diseñados con el schema. PITFALL QR spoofing (P6) — sesión efímera vinculada a usuario + cierre al pagar. PITFALL menú sin disponibilidad atómica — decremento atómico de stock.

### Phase 6: Tiempo Real — WebSockets + Abstracción Redis-ready
**Rationale:** Convierte lo funcional (REST + polling) en lo que el usuario pidió explícitamente. Esta fase requiere research previo (reconnect patterns en Flutter, event replay, heartbeat). La abstracción `Broadcaster` debe entrar AQUÍ desde el día 1, aunque la implementación v1 sea in-memory — migrar después es reescribir el ConnectionManager.
**Delivers:** Endpoint `/ws?token=JWT` con rooms por restaurante, `ConnectionManager` con interfaz `Broadcaster` (implementación in-memory + stub Redis Pub/Sub), tipos de evento (`pedido:nuevo`, `pedido:estado`, `mesa:estado`, `cuenta:solicitada`, `pago:confirmado`), re-sync HTTP al reconectar (WS = notificación, GET `/estado` = fuente), heartbeat ping/pong cada 25-30s, handlers idempotentes por `evento.id`. Cocina y cliente actualizan en vivo; mapa de mesas del panel admin se sincroniza solo.
**Addresses features:** Estado de pedido en tiempo real, sync del mapa de mesas (completa Fase 4).
**Avoids:** PITFALL WebSockets in-memory (P3) — abstracción diseñada desde el inicio, re-sync on connect, heartbeat, idempotencia. PITFALL polling HTTP — eliminado.

### Phase 7: Panel Admin Full CRUD + Vista Cocina (KDS ligero)
**Rationale:** Con WS funcionando, el panel admin se completa: CRUD de mesas/menú/reservas/clientes con feedback en tiempo real, vista cocina KDS ligero (lista con tiempo transcurrido y color coding verde/amarillo/rojo), reportes básicos, configuración del restaurante.
**Delivers:** Flutter Web admin completo: gestión de mesas con QR generado (`qr_flutter`), gestión de menú con modifiers y toggle disponibilidad (86), gestión de reservas (confirmar/cancelar/no-show), gestión de clientes con historial, vista cocina con cola de pedidos en vivo, reportes básicos (ventas día/semana, top items, ocupación), configuración (horarios, reglas de reserva). Charts con `fl_chart`, tablas con `data_table_2`.
**Addresses features:** Vista cocina KDS ligero, gestión completa de mesas/menú/reservas/clientes, reportes básicos, configuración.
**Avoids:** PITFALL broadcast WS a todas las conexiones — rooms por restaurante filtran naturalmente.

### Phase 8: Pagos en Línea + Calificaciones + Deploy/Hardening
**Rationale:** El pago es la feature de mayor riesgo técnico (gateway externo, sandboxes distintos a prod, webhooks con firma HMAC). Se aísla al final con research previo obligatorio sobre Wompi/PayU. Cierra el ciclo financiero + calificación + deploy final a Ubuntu Server.
**Delivers:** Integración con pasarela colombiana (Wompi preferida, verificar en research de fase), `/cliente/pagos` crea intención de pago, webhook `/webhooks/pago` verifica firma HMAC + idempotencia por `evento.id` + máquina de estados `pendiente→aprobado→conciliado`, job de reconciliación, calificación post-pago vinculada a `pedido_id`, mesa a `limpieza` al confirmar pago, deploy a Ubuntu Server con nginx (TLS + WS upgrade + rate limit), CORS con orígenes específicos, hardening final (logs estructurados, backups automáticos, `DEMO_MODE=false` en prod).
**Addresses features:** Pago en línea, calificación post-experiencia, liberación de mesa al pagar, deploy producción.
**Avoids:** PITFALL pagos sin idempotencia/firma (P4) — todos los mecanismos diseñados antes de integrar la pasarela. PITFALL QR zombi — cierre de sesión al pagar. PITFALL deploy sin CORS/cache-busting.

### Phase Ordering Rationale

- **Dependencias técnicas primero:** Foundation → Auth → Domain Model es lineal e innegociable. Cada fase necesita lo anterior (FEATURES.md dependency graph).
- **Validación visual temprana:** Panel Admin read-only (Fase 4) se construye antes que la app cliente para confirmar identidad visual del mockup y end-to-end del staff path con datos sembrados.
- **REST antes que WS:** El QR ordering se construye primero con REST + polling explícito (Fase 5), luego se añade tiempo real (Fase 6). Esto desacopla la lógica de negocio del mecanismo de notificación y permite iterar la cadena de pedidos sin lidiar con WS.
- **Pagos al final:** Es la feature de mayor riesgo (gateway externo, sandbox ≠ prod, fraud surface). Se aísla con research previo y no bloquea validar el resto del producto.
- **Agrupamiento por bounded contexts:** Cada fase entrega un contexto coherente (auth, mesa+reserva, pedido+qr, realtime, pago) que mapea a los `services/` de la arquitectura.

### Research Flags

**Necesitan `/gsd-research-phase` antes de planear:**
- **Fase 6 (Tiempo Real):** Patrón de reconexión en Flutter con `web_socket_channel`, event replay con sequence numbers, mejor patrón para heartbeat bidireccional, cuándo activar Redis Pub/Sub real vs in-memory. La doc oficial de FastAPI cubre el patrón base pero los detalles de Flutter reconnect + sync no.
- **Fase 8 (Pagos):** **MANDATORIO.** Comparativa Wompi vs PayU vs Mercado Pago con docs vivos (los 3 fueron inaccesibles en research inicial — HTTP 403), requisitos KYC del restaurante, formato exacto de webhooks y firmas HMAC, sandbox vs producción, soporte para propina split, comisiones actuales 2026. Sin esta investigación la fase no se puede planear con confianza.
- **Fase 3 (State Machines):** Light research. Las state machines de Mesa y Pedido están bien definidas en FEATURES.md, pero las transiciones exactas, manejo de `recall` (pedido devuelto a cocina), y diseño de índices para queries de disponibilidad benefit de un SPEC claro antes de implementar.

**Patrones estándar (skip research-phase, plan directo):**
- **Fase 1 (Foundation):** Docker Compose + FastAPI skeleton + Alembic — patrones universalmente documentados.
- **Fase 2 (Auth):** JWT/FastAPI auth con refresh token — documentado oficialmente en `fastapi.tiangolo.com/tutorial/security/oauth2-jwt/`.
- **Fase 4 (Panel Admin read-only):** Flutter Web consumiendo REST + go_router — patrón estándar Flutter.
- **Fase 5 (Cliente + QR Ordering REST):** Patrones de QR ordering bien documentados; `mobile_scanner` y `dio` son estándares.
- **Fase 7 (Panel Admin CRUD):** CRUD estándar con SQLAlchemy 2.0; solo choose UI components.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Versiones verificadas directamente contra PyPI y pub.dev (Agosto 2026). Excepción: pasarela colombiana MEDIUM (docs inaccesibles). |
| Features | **HIGH** | Scope validado contra PROJECT.md + mockups del usuario. Estado del arte de QR ordering y reservas bien documentado. |
| Architecture | **HIGH** | Patrones multi-tenant SaaS, FastAPI WebSockets y state machines verificados contra docs oficiales. |
| Pitfalls | **HIGH** | Concurrencia, multi-tenant, MySQL Docker y state machines son verdades fundamentales de ingeniería. Excepción: detalles específicos de webhooks Wompi/PayU son MEDIUM (firma, eventos). |

**Overall confidence:** **HIGH** — el proyecto se puede planear y ejecutar con confianza. La única zona de incertidumbre significativa es la integración con pasarela colombiana, que tiene su propia fase con research dedicado.

### Gaps to Address

- **Webhooks de Wompi/PayU/Mercado Pago:** Estructura exacta del evento, formato de firma HMAC, eventos disponibles. **Resolver en research de Fase 8** (docs fueron 403 anti-bot en research inicial).
- **Wompi widget in-site vs redirect-only para Colombia:** ¿Existe `Checkout.js` para CO o solo redirect? **Resolver en research de Fase 8.**
- **Comisiones actuales 2026:** Cambian anualmente. **Verificar en sitio oficial antes de comprometerse en Fase 8.**
- **Reserva auto-confirm vs aprobación manual:** Pregunta de diseño abierta (FEATURES.md). Auto-confirm es más simple y recomendado para v1; confirmar con el usuario en SPEC de Fase 5.
- **Abstracción `Broadcaster` vs Redis Pub/Sub real:** Para v1 con 1 worker, in-memory basta. **Decidir en SPEC de Fase 6** si se implementa la abstracción desde el inicio (recomendado) o se defiere.
- **Política de cancelación de reservas:** ¿Ventana de tiempo? ¿Penalización blanda? **Decidir en SPEC de Fase 5.**
- **Alérgenos como flags vs texto libre:** Si se quiere filtrar por alérgeno después, deben ser flags desde el inicio (FEATURES.md dependency note). **Decidir en SPEC de Fase 7** (gestión de menú).

## Sources

### Primary (HIGH confidence — docs oficiales verificados)

- **pypi.org** — Versiones verificadas Agosto 2026: `fastapi 0.141.1` (Jul 29 2026), `uvicorn 0.52.2`, `asyncmy 0.2.14` (Aug 12 2026), `PyJWT 2.13.0`, `alembic 1.19.1`, `aiomysql 0.3.2` (marcado `3-Alpha`), `python-jose 3.5.0` (sin releases 2026).
- **pub.dev** — Versiones verificadas Agosto 2026: `flutter_riverpod 3.4.2`, `flutter_bloc 9.1.1`, `dio 5.11.0`, `go_router 17.5.0`, `mobile_scanner 7.4.0`, `web_socket_channel 3.0.3`.
- **docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html** — SQLAlchemy 2.0.52, AsyncSession API confirmada.
- **fastapi.tiangolo.com/advanced/websockets/** — Patrón `ConnectionManager` con `active_connections`, nota explícita sobre limitación a 1 proceso y recomendación de `encode/broadcaster` (Redis/Postgres) para multi-proceso.
- **fastapi.tiangolo.com/tutorial/security/oauth2-jwt/** — Patrón estándar JWT con refresh.
- **fastapi.tiangolo.com/tutorial/bigger-applications/** — Estructura por APIRouter.
- **github.com/encode/broadcaster** — Referenciado por FastAPI para WS multi-proceso.
- **docs.flutter.dev/deployment/web** y **docs.flutter.dev/platform-integration/web/faq** — Builds Wasm con COEP/COOP, `kIsWeb` para evitar `dart:io`, cache-busting post-deploy.
- **documentos/index.html, documentos/indexcliente.html** (mockups del usuario) — Definición concreta de UI, sidebar admin, navegación cliente, endpoints anticipados, paleta cromática, formato QR `GRI-MESA-001`.
- **.planning/PROJECT.md** — Fuente de verdad del scope v1 y decisiones.

### Secondary (MEDIUM confidence)

- **Eat App — Features page** (`restaurant.eatapp.co/features`) — Referencia de plataforma de reservas + table management: lista de features observadas.
- **Conocimiento de dominio consolidado** — State machines de KDS (Toast/Square/Lightspeed/Aloha), QR ordering (Mr Yum/Bbot/Sunday/Slice/GloriaFood), flujos de reserva (OpenTable/Resy/Sevenrooms/TheFork). Corroborado por múltiples vendors.
- **Patrones SaaS multi-tenant** — Shared-DB + tenant_id como patrón dominante (AWS SaaS Factory, Microsoft SaaS patterns), estándar de industria 10+ años.
- **MySQL 8.4 LTS** — Ciclo de soporte hasta Abr 2032 según Oracle LTS policy.
- **OWASP Password Storage Cheat Sheet** — Recomendaciones bcrypt vs argon2.
- **Wompi/PayU/Mercado Pago en Colombia** — Capacidades y comisiones basadas en training data 2024-2025. **Las APIs y políticas cambian anualmente — verificar antes de decidir en Fase 8.**

### Tertiary (LOW confidence — validar en su fase)

- **Estructura exacta de webhooks de Wompi** — Headers `X-Event-Signature`, payload del evento, campos disponibles. **Requiere research en Fase 8** (docs oficiales inaccesibles, HTTP 403 anti-bot).
- **Wompi widget `Checkout.js` para Colombia** — Si soporta pago in-site (sin redirect) o solo redirect. **No confirmado para CO.**
- **Comisiones y métodos de pago actuales 2026** — Verificar en sitio oficial antes de comprometerse.
- **Brave Search API** — No configurada en este entorno; no se pudo usar para corroboración cruzada.

---
*Research completed: 2026-08-13*
*Ready for roadmap: yes*
