# Roadmap: GRI â€” GestiÃ³n y Reservas de Restaurantes

## Overview

GRI se construye de abajo hacia arriba siguiendo sus dependencias tÃ©cnicas: primero la infraestructura (Docker + MySQL + API con configuraciÃ³n por entorno), luego la autenticaciÃ³n multi-rol con aislamiento multi-tenant â€”que debe existir antes de cualquier endpoint de negocioâ€”, y el modelo de dominio con el restaurante demo sembrado. Sobre esa base se construyen las dos aplicaciones: el panel web admin (primero solo lectura, para validar la capa de datos y la identidad visual del mockup; despuÃ©s gestiÃ³n completa) y la app mÃ³vil cliente (primero descubrimiento y reservas, luego el pedido por QR que constituye el core value). El tiempo real (WebSockets) convierte lo funcional en vivo, y el ciclo cierra con pagos en lÃ­nea, calificaciones y el despliegue a producciÃ³n en Ubuntu Server. Cada fase entrega una capacidad verificable de punta a punta.

Nota: la Fase de cliente del research original (una sola fase "Cliente MÃ³vil REST" con ~18 requisitos) se dividiÃ³ aquÃ­ en dos journeys verticales independientes y verificables: Descubrimiento/Reservas (Fase 5) y Pedido por QR (Fase 6, el core value).

## Phases

**Phase Numbering:**
- Fases enteras (1, 2, 3): trabajo planificado del milestone
- Fases decimales (2.1, 2.2): inserciones urgentes (marcadas con INSERTED)

- [x] **Phase 1: FundaciÃ³n e Infraestructura** - Docker + MySQL + API corriendo con configuraciÃ³n por entorno
- [x] **Phase 2: AutenticaciÃ³n, Roles y Multi-tenant** - JWT multi-rol con aislamiento por restaurante; el super-admin crea restaurantes y staff (completed 2026-08-13)
- [x] **Phase 3: Modelo de Dominio y Seed Demo** - Todas las tablas de negocio, state machines y restaurante demo sembrado
- [x] **Phase 4: Panel Admin â€” Login, Dashboard y Mapa (Solo Lectura)** - El staff inicia sesiÃ³n y ve estadÃ­sticas y mapa de mesas con los colores del mockup
- [x] **Phase 5: App Cliente â€” Descubrimiento y Reservas** - El cliente descubre restaurantes y completa el ciclo de reserva de principio a fin
- [ ] **Phase 6: App Cliente â€” Pedido por QR (REST) y Vista Cocina** - El core value end-to-end: escanear, pedir, seguir el estado y pedir la cuenta (sin tiempo real aÃºn)
- [ ] **Phase 7: Tiempo Real â€” WebSockets** - Pedidos y mesas en vivo en cocina, mesero, cliente y panel sin refrescar
- [ ] **Phase 8: Panel Admin â€” GestiÃ³n Completa y Reportes** - CRUD de mesas/menÃº/clientes, reportes de ventas y gestiÃ³n de plataforma
- [ ] **Phase 9: Pagos, Calificaciones y Deploy** - Pago en lÃ­nea idempotente, calificaciÃ³n post-pago y despliegue a Ubuntu Server

## Phase Details

### Phase 1: FundaciÃ³n e Infraestructura
**Goal**: La plataforma corre: MySQL y la API en Docker, conectados por configuraciÃ³n de entorno, con datos persistentes
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: INFR-01, INFR-02
**Success Criteria** (what must be TRUE):
  1. `docker compose up` levanta MySQL y la API; el healthcheck de la API responde OK con la conexiÃ³n a BD verificada
  2. Los datos de MySQL sobreviven al reinicio del contenedor (volumen persistente) y la BD usa charset utf8mb4 con timezone America/Bogota (acentos y emojis se guardan y se leen bien)
  3. La conexiÃ³n a la BD se configura por variables de entorno: cambiar el `.env` cambia la conexiÃ³n sin tocar cÃ³digo
**Plans**: 1 plan
- [x] 01-01-PLAN.md â€” Walking Skeleton: stack Docker (MySQL 8.4 + FastAPI) con /health verificando SELECT 1, charset/TZ/persistencia y conexiÃ³n por .env

### Phase 2: AutenticaciÃ³n, Roles y Multi-tenant
**Goal**: Usuarios autenticados con sesiÃ³n persistente, 5 roles distinguibles y aislamiento estricto por restaurante; el super-admin administra la plataforma vÃ­a API
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, PLAT-02, PLAT-03
**Success Criteria** (what must be TRUE):
  1. Un usuario puede registrarse como cliente (nombre, email, contraseÃ±a) e iniciar sesiÃ³n recibiendo access + refresh token; el refresh le da una nueva sesiÃ³n sin volver a loguearse
  2. El sistema distingue los 5 roles (super_admin, admin_restaurante, mesero, cocina, cliente) y cada rol solo accede a los endpoints que le corresponden
  3. Un usuario staff del restaurante A que solicita recursos del restaurante B recibe 404 (aislamiento multi-tenant verificado con tests de acceso cruzado)
  4. El super-admin puede crear restaurantes con sus datos bÃ¡sicos y usuarios staff (admin, mesero, cocina) asignados a un restaurante vÃ­a la API
**Plans**: 2 plans
- [ ] 02-01-PLAN.md â€” Vertical Slice FundaciÃ³n: Models + Alembic + Bootstrap super-admin + register/login/refresh/me (AUTH-01, AUTH-02)
- [ ] 02-02-PLAN.md â€” Vertical Slice Roles + Tenant + Platform Admin: require_roles + TenantScope + /admin/restaurantes + /admin/restaurantes/{id}/staff (AUTH-03, AUTH-04, PLAT-02, PLAT-03)

### Phase 3: Modelo de Dominio y Seed Demo
**Goal**: Toda la base de datos de negocio existe con state machines explÃ­citas (mesa y pedido) y el restaurante demo sembrado al inicializar
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PLAT-04, MESA-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. Al desplegar/inicializar la plataforma en limpio, las migraciones (Alembic) y el seed se ejecutan automÃ¡ticamente como parte del proceso
  2. El sistema siembra un restaurante demo con menÃº, mesas y datos de ejemplo cuando DEMO_MODE estÃ¡ activo; con DEMO_MODE=false no siembra nada
  3. Cada mesa tiene un cÃ³digo QR Ãºnico en formato GRI-MESA-XXX y el sistema impide que dos mesas compartan cÃ³digo (constraint en BD)
**Notas**: Las tablas de dominio (mesa, categoria, producto, pedido, pedido_item, reserva, pago, calificacion) se crean aquÃ­ con FKs e Ã­ndices compuestos por restaurante. Las transiciones de MESA_TRANSITIONS y PEDIDO_TRANSITIONS se implementan con el schema (research ligero/SPEC recomendado antes de planear).
**Plans**: 2 plans
- [x] 03-01-PLAN.md â€” Vertical Slice Models + State Machines + MigraciÃ³n 0002 + tests DB-direct (MESA-02, mitad INFR-03 migraciones) â€” âœ… 53/53 tests, 9 tablas, 5 state machines
- [x] 03-02-PLAN.md â€” Vertical Slice Seed Demo + Lifespan Wiring + verify_seed.sh (PLAT-04, mitad INFR-03 seed)

### Phase 4: Panel Admin â€” Login, Dashboard y Mapa (Solo Lectura)
**Goal**: El staff (admin restaurante y super-admin) inicia sesiÃ³n en el panel web y ve dashboard con estadÃ­sticas y mapa de mesas con la identidad visual del mockup
**Mode:** mvp
**Depends on**: Phase 2, Phase 3
**Requirements**: PLAT-01, ADMN-01, ADMN-02
**Success Criteria** (what must be TRUE):
  1. Admin restaurante y super-admin pueden iniciar sesiÃ³n en el panel web (Flutter Web) con sus credenciales y la sesiÃ³n persiste
  2. El dashboard muestra estadÃ­sticas del restaurante con datos reales: mesas disponibles/ocupadas, reservas del dÃ­a y pedidos activos
  3. El mapa de mesas muestra cada mesa con su estado codificado por color (verde/rojo/amarillo/azul del mockup) y refleja cambios de la BD al refrescar (polling corto â€” deuda temporal; el tiempo real llega en Phase 7)
**Plans**: 2 plans
- [x] 04-01-PLAN.md - Vertical Slice Backend: CORSMiddleware + GET /staff/mesas + GET /staff/stats (tenant-scoped) + tests aislamiento + tests CORS (ADMN-01, ADMN-02)
- [x] 04-02-PLAN.md - Vertical Slice Panel Admin Flutter Web: scaffold + auth (login/persistencia/refresh interceptor/go_router guard) + dashboard (4 stat cards + mapa coloreado + sidebar) + polling 10s + widget tests (PLAT-01, ADMN-01, ADMN-02) Ã¢ DONE 2026-08-14

### Phase 5: App Cliente â€” Descubrimiento y Reservas
**Goal**: Un cliente puede descubrir restaurantes y completar el ciclo completo de reserva (buscar â†’ reservar â†’ consultar â†’ cancelar â†’ sentarse)
**Mode:** mvp
**Depends on**: Phase 3, Phase 4
**Requirements**: AUTH-05, REST-01, REST-02, RESV-01, RESV-02, RESV-03, RESV-04, RESV-05, MESA-04
**Success Criteria** (what must be TRUE):
  1. El cliente puede registrarse e iniciar sesiÃ³n desde la app mÃ³vil y ver/editar su perfil
  2. El cliente ve la lista de restaurantes activos (nombre, tipo de cocina, calificaciÃ³n â€” muestra "â€”" hasta Phase 9) y el detalle de un restaurante con su menÃº por categorÃ­as (productos con precio y descripciÃ³n)
  3. El cliente puede reservar mesa indicando fecha, hora y nÃºmero de personas; el sistema rechaza reservas que exceden capacidad o solapan horarios, incluso bajo peticiones concurrentes (sin sobre-reservas)
  4. El cliente puede consultar sus reservas (prÃ³ximas y pasadas, con estado) y cancelar una reserva futura
  5. El admin ve las reservas del dÃ­a en el panel y puede marcar la mesa como ocupada al llegar el cliente; los estados de mesa (disponible/reservada/ocupada/limpieza) solo cambian por transiciones vÃ¡lidas y las invÃ¡lidas son rechazadas
**Notas**: La protecciÃ³n anti concurrencia vive en la BD (UNIQUE mesa/fecha/slot + SELECT ... FOR UPDATE) segÃºn PITFALLS del research. Decisiones cerradas: auto-confirm (reservas nacen confirmadas, sin aprobaciÃ³n manual), slots horarios de 60min (:00), asignaciÃ³n de mesa automÃ¡tica (server elige), cancelaciÃ³n reverte mesa solo si estaba reservada. Web-first dev en Chrome :5174 (sin Android SDK).
**Plans**: 3 plans
- [x] 05-01-PLAN.md â€” Vertical Slice Backend Core: migraciÃ³n 0003 (UNIQUE slot) + /public/* (descubrimiento) + /cliente/* (perfil PATCH + reservas create/list/cancel con FOR UPDATE) + HARD GATE test_reserva_concurrency.py (AUTH-05, REST-01, REST-02, RESV-01, RESV-02, RESV-03, RESV-04) Ã¢ DONE 2026-08-14 (suite 95/95)
- [x] 05-02-PLAN.md â€” Vertical Slice Backend Staff: EXTENDER /staff/reservas + POST /staff/mesas/{id}/estado (MESA_TRANSITIONS vÃ­a validar_transicion) + tests tenant isolation (RESV-05, MESA-04) Ã¢ DONE 2026-08-14 (suite 105/105)
- [ ] 05-03-PLAN.md â€” Vertical Slice Flutter app_cliente: scaffold + copia lib/core de panel_admin + 4 tabs StatefulShellRoute.indexedStack + features auth/restaurantes/reservas/perfil + widget tests (AUTH-05, REST-01, REST-02, RESV-01, RESV-03 UI)

### Phase 6: App Cliente â€” Pedido por QR (REST) y Vista Cocina
**Goal**: El core value funciona de punta a punta sin tiempo real: sentarse, escanear el QR, pedir del menÃº, seguir el estado del pedido y pedir la cuenta
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-03, PEDI-04, PEDI-05, PEDI-06, PAGO-01, ADMN-05
**Success Criteria** (what must be TRUE):
  1. El cliente escanea el QR de la mesa con la cÃ¡mara del telÃ©fono, queda vinculado a la mesa (sesiÃ³n de mesa) y ve el menÃº
  2. El cliente arma un pedido con productos del menÃº y lo envÃ­a a cocina; el pedido aparece en la cola del restaurante y mesero/admin ven los pedidos activos con su detalle (mesa, productos, total)
  3. El pedido avanza por su mÃ¡quina de estados (enviado â†’ aceptado â†’ en_preparaciÃ³n â†’ servido, con rechazado como terminal); cocina avanza el pedido desde su vista de cola y las transiciones invÃ¡lidas son rechazadas (409)
  4. El cliente consulta el estado de su pedido desde la app (via REST/polling â€” en vivo a partir de Phase 7)
  5. El cliente puede solicitar la cuenta desde la app y el mesero/panel recibe el aviso
**Notas**: La vista de cocina de esta fase es la cola funcional (refresh/polling manual); el upgrade visual (tiempos, colores) es refinamiento sin requisito asociado. La sesiÃ³n de mesa se vincula al usuario autenticado (anti-spoofing, PITFALL P6).
**Plans**: 3 plans
- [x] 06-01-PLAN.md — Vertical Slice Backend: migración 0004 (pedido.sesion_id + cuenta solicitada + UNIQUE sesión activa por usuario) + /cliente/sesiones|pedidos|cuenta + /staff/pedidos (cola + matriz rol×transición + anti-zombi limpieza) + 4 suites tests con HARD GATE concurrencia (MESA-05, MESA-06, PEDI-01..06, PAGO-01 backend)
- [ ] 06-02-PLAN.md — Vertical Slice App Cliente: sesion_qr (mobile_scanner + input manual primera clase) + pedidos (carrito, envío, estado polling 10s, cuenta) + banner "Estás en la Mesa X" + widget tests (MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-04, PAGO-01 UI)
- [x] 06-03-PLAN.md — Vertical Slice Panel Cocina: cola de pedidos con cards (mesa/items/total/badge cuenta), botones según matriz rol×estado, polling 10s, sidebar "Pedidos" activo (ADMN-05, PEDI-05, PEDI-06, PAGO-01 UI) — DONE 2026-08-14 (panel suite 17/17, analyze 0, build web OK)

### Phase 7: Tiempo Real â€” WebSockets
**Goal**: Pedidos y estados de mesa llegan en vivo a cocina, mesero, cliente y panel sin refrescar, con recuperaciÃ³n ante desconexiones
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: RT-01, RT-02, RT-03
**Success Criteria** (what must be TRUE):
  1. Un cambio de estado de pedido llega en vivo a cocina, mesero/admin y al cliente sin refrescar la pantalla
  2. El mapa de mesas del panel se actualiza en vivo cuando cambia el estado de una mesa (completa el polling de Phase 4)
  3. Tras una desconexiÃ³n (p.ej. wifi perdido), la app se reconecta y re-sincroniza el estado al reconectar (sin eventos duplicados ni pantallas desactualizadas)
**Notas**: Research de fase obligatorio antes de planear (patrÃ³n de reconexiÃ³n Flutter, replay con sequence numbers, heartbeat). La abstracciÃ³n `Broadcaster` entra aquÃ­ desde el dÃ­a 1 (in-memory v1, Redis-ready).
**Plans**: 3 plans
- [x] 07-01-PLAN.md — Vertical Slice Backend: Broadcaster (rooms + seq, Redis-ready) + /ws/staff + /ws/cliente (auth JWT manual 4401, sin Depends(get_session)) + 6 emisiones post-commit en services + suite test_ws.py contra stack vivo con httpx-ws (RT-01/02/03 backend)
- [ ] 07-02-PLAN.md — Vertical Slice Panel Admin: WsClient (backoff+jitter, token fresco, 4401→refresh, dedup seq, resync) + kick-to-refetch en mesas/stats/pedidosStaff + safety net 60s + widget tests (RT-01/02/03 panel) — depende de 07-01
- [ ] 07-03-PLAN.md — Vertical Slice App Cliente: WsClient (copia) + pedidos de la sesion en vivo + manejo sesion.cerrada (anti-zombi) + tests dedup/reconexion/4401 (RT-01/03 cliente) — depende de 07-01, paralelo con 07-02

### Phase 8: Panel Admin â€” GestiÃ³n Completa y Reportes
**Goal**: El restaurante opera completamente desde el panel: gestiÃ³n de mesas con QR, menÃº, clientes, reportes y gestiÃ³n de plataforma del super-admin
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: PLAT-05, MENU-01, MENU-02, MESA-01, MESA-03, ADMN-03, ADMN-04, REPO-01, REPO-02
**Success Criteria** (what must be TRUE):
  1. El admin puede crear y editar mesas (nÃºmero, capacidad) y ver/imprimir el QR de cada mesa; el mapa refleja las mesas nuevas
  2. El admin puede crear, editar y desactivar categorÃ­as y productos del menÃº (con precio, descripciÃ³n, imagen y toggle agotado)
  3. El admin puede cambiar el estado de una mesa desde el mapa (marcar en limpieza, liberar) y gestionar clientes (lista e historial)
  4. El admin puede ver reportes de ventas por dÃ­a/rango (total, nÃºmero de pedidos) y los platos mÃ¡s vendidos
  5. El super-admin puede ver la lista de restaurantes y desactivarlos desde el panel
**Plans**: TBD

### Phase 9: Pagos, Calificaciones y Deploy
**Goal**: El ciclo financiero cierra: pago en lÃ­nea idempotente que libera la mesa, calificaciÃ³n post-pago visible en discover, y despliegue a producciÃ³n en Ubuntu Server
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: PAGO-02, PAGO-03, PAGO-04, CALI-01, CALI-02
**Success Criteria** (what must be TRUE):
  1. El cliente puede pagar en lÃ­nea el total de su consumo desde la app (pasarela definida en el research de la fase â€” Wompi preferida)
  2. Los pagos son idempotentes: reintentos o webhooks duplicados no generan doble cobro ni estados corruptos
  3. Al confirmarse el pago, la mesa pasa a limpieza y la sesiÃ³n de mesa se cierra
  4. Tras un pedido pagado, el cliente puede calificar su experiencia (estrellas + comentario) y el promedio del restaurante es visible en la lista y detalle de restaurantes
**Notas**: Research de fase MANDATORIO antes de planear (Wompi/PayU/Mercado Pago: webhooks, firma HMAC, sandbox, comisiones 2026). El deploy a Ubuntu Server (nginx + TLS + WS upgrade + DEMO_MODE=false) es la verificaciÃ³n final de INFR-01/02/03 en producciÃ³n.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 â†’ 2 â†’ 3 â†’ 4 â†’ 5 â†’ 6 â†’ 7 â†’ 8 â†’ 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. FundaciÃ³n e Infraestructura | 1/1 | Complete | 2026-08-13 |
| 2. AutenticaciÃ³n, Roles y Multi-tenant | 2/2 | Complete   | 2026-08-13 |
| 3. Modelo de Dominio y Seed Demo | 2/2 | Complete | 2026-08-13 |
| 4. Panel Admin â€” Login, Dashboard y Mapa (Solo Lectura) | 2/2 | Complete | 2026-08-14 |
| 5. App Cliente â€” Descubrimiento y Reservas | 3/3 | Complete | 2026-08-14 |
| 6. App Cliente â€” Pedido por QR (REST) y Vista Cocina | 3/3 | Complete | 2026-08-14 |
| 7. Tiempo Real â€” WebSockets | 1/3 | In progress | - |
| 8. Panel Admin â€” GestiÃ³n Completa y Reportes | 0/? | Not started | - |
| 9. Pagos, Calificaciones y Deploy | 0/? | Not started | - |

---
*Coverage: 50/50 requisitos v1 mapeados (PLAT 5, AUTH 5, REST 2, MENU 2, MESA 6, RESV 5, PEDI 6, RT 3, PAGO 4, CALI 2, ADMN 5, REPO 2, INFR 3). Nota: REQUIREMENTS.md decÃ­a "47 total" por error aritmÃ©tico; el conteo real de IDs es 50.*
*Created: 2026-08-13*


