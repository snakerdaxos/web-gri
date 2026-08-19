# Roadmap: GRI Ã¢â‚¬â€ GestiÃƒÂ³n y Reservas de Restaurantes

## Overview

GRI se construye de abajo hacia arriba siguiendo sus dependencias tÃƒÂ©cnicas: primero la infraestructura (Docker + MySQL + API con configuraciÃƒÂ³n por entorno), luego la autenticaciÃƒÂ³n multi-rol con aislamiento multi-tenant Ã¢â‚¬â€que debe existir antes de cualquier endpoint de negocioÃ¢â‚¬â€, y el modelo de dominio con el restaurante demo sembrado. Sobre esa base se construyen las dos aplicaciones: el panel web admin (primero solo lectura, para validar la capa de datos y la identidad visual del mockup; despuÃƒÂ©s gestiÃƒÂ³n completa) y la app mÃƒÂ³vil cliente (primero descubrimiento y reservas, luego el pedido por QR que constituye el core value). El tiempo real (WebSockets) convierte lo funcional en vivo, y el ciclo cierra con pagos en lÃƒÂ­nea, calificaciones y el despliegue a producciÃƒÂ³n en Ubuntu Server. Cada fase entrega una capacidad verificable de punta a punta.

Nota: la Fase de cliente del research original (una sola fase "Cliente MÃƒÂ³vil REST" con ~18 requisitos) se dividiÃƒÂ³ aquÃƒÂ­ en dos journeys verticales independientes y verificables: Descubrimiento/Reservas (Fase 5) y Pedido por QR (Fase 6, el core value).

## Phases

**Phase Numbering:**
- Fases enteras (1, 2, 3): trabajo planificado del milestone
- Fases decimales (2.1, 2.2): inserciones urgentes (marcadas con INSERTED)

- [x] **Phase 1: FundaciÃƒÂ³n e Infraestructura** - Docker + MySQL + API corriendo con configuraciÃƒÂ³n por entorno
- [x] **Phase 2: AutenticaciÃƒÂ³n, Roles y Multi-tenant** - JWT multi-rol con aislamiento por restaurante; el super-admin crea restaurantes y staff (completed 2026-08-13)
- [x] **Phase 3: Modelo de Dominio y Seed Demo** - Todas las tablas de negocio, state machines y restaurante demo sembrado
- [x] **Phase 4: Panel Admin Ã¢â‚¬â€ Login, Dashboard y Mapa (Solo Lectura)** - El staff inicia sesiÃƒÂ³n y ve estadÃƒÂ­sticas y mapa de mesas con los colores del mockup
- [x] **Phase 5: App Cliente Ã¢â‚¬â€ Descubrimiento y Reservas** - El cliente descubre restaurantes y completa el ciclo de reserva de principio a fin
- [ ] **Phase 6: App Cliente Ã¢â‚¬â€ Pedido por QR (REST) y Vista Cocina** - El core value end-to-end: escanear, pedir, seguir el estado y pedir la cuenta (sin tiempo real aÃƒÂºn)
- [ ] **Phase 7: Tiempo Real Ã¢â‚¬â€ WebSockets** - Pedidos y mesas en vivo en cocina, mesero, cliente y panel sin refrescar
- [x] **Phase 8: Panel Admin Ã¢â‚¬â€ GestiÃƒÂ³n Completa y Reportes** - CRUD de mesas/menÃƒÂº/clientes, reportes de ventas y gestiÃƒÂ³n de plataforma
- [x] **Phase 9: Pagos, Calificaciones y Deploy** - Pago en lÃƒÂ­nea idempotente, calificaciÃƒÂ³n post-pago y despliegue a Ubuntu Server
- [ ] **Phase 10: Migracion a Firebase (Opcion B)** - Ambas apps 100% Firebase; checkpoint humano de deploy pendiente
- [ ] **Phase 11: Correccion Critica y Profesionalizacion** - Arranque desde BD vacia, reglas/indices corregidos y sistema de diseno responsive

## Phase Details

### Phase 1: FundaciÃƒÂ³n e Infraestructura
**Goal**: La plataforma corre: MySQL y la API en Docker, conectados por configuraciÃƒÂ³n de entorno, con datos persistentes
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: INFR-01, INFR-02
**Success Criteria** (what must be TRUE):
  1. `docker compose up` levanta MySQL y la API; el healthcheck de la API responde OK con la conexiÃƒÂ³n a BD verificada
  2. Los datos de MySQL sobreviven al reinicio del contenedor (volumen persistente) y la BD usa charset utf8mb4 con timezone America/Bogota (acentos y emojis se guardan y se leen bien)
  3. La conexiÃƒÂ³n a la BD se configura por variables de entorno: cambiar el `.env` cambia la conexiÃƒÂ³n sin tocar cÃƒÂ³digo
**Plans**: 1 plan
- [x] 01-01-PLAN.md Ã¢â‚¬â€ Walking Skeleton: stack Docker (MySQL 8.4 + FastAPI) con /health verificando SELECT 1, charset/TZ/persistencia y conexiÃƒÂ³n por .env

### Phase 2: AutenticaciÃƒÂ³n, Roles y Multi-tenant
**Goal**: Usuarios autenticados con sesiÃƒÂ³n persistente, 5 roles distinguibles y aislamiento estricto por restaurante; el super-admin administra la plataforma vÃƒÂ­a API
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, PLAT-02, PLAT-03
**Success Criteria** (what must be TRUE):
  1. Un usuario puede registrarse como cliente (nombre, email, contraseÃƒÂ±a) e iniciar sesiÃƒÂ³n recibiendo access + refresh token; el refresh le da una nueva sesiÃƒÂ³n sin volver a loguearse
  2. El sistema distingue los 5 roles (super_admin, admin_restaurante, mesero, cocina, cliente) y cada rol solo accede a los endpoints que le corresponden
  3. Un usuario staff del restaurante A que solicita recursos del restaurante B recibe 404 (aislamiento multi-tenant verificado con tests de acceso cruzado)
  4. El super-admin puede crear restaurantes con sus datos bÃƒÂ¡sicos y usuarios staff (admin, mesero, cocina) asignados a un restaurante vÃƒÂ­a la API
**Plans**: 2 plans
- [ ] 02-01-PLAN.md Ã¢â‚¬â€ Vertical Slice FundaciÃƒÂ³n: Models + Alembic + Bootstrap super-admin + register/login/refresh/me (AUTH-01, AUTH-02)
- [ ] 02-02-PLAN.md Ã¢â‚¬â€ Vertical Slice Roles + Tenant + Platform Admin: require_roles + TenantScope + /admin/restaurantes + /admin/restaurantes/{id}/staff (AUTH-03, AUTH-04, PLAT-02, PLAT-03)

### Phase 3: Modelo de Dominio y Seed Demo
**Goal**: Toda la base de datos de negocio existe con state machines explÃƒÂ­citas (mesa y pedido) y el restaurante demo sembrado al inicializar
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PLAT-04, MESA-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. Al desplegar/inicializar la plataforma en limpio, las migraciones (Alembic) y el seed se ejecutan automÃƒÂ¡ticamente como parte del proceso
  2. El sistema siembra un restaurante demo con menÃƒÂº, mesas y datos de ejemplo cuando DEMO_MODE estÃƒÂ¡ activo; con DEMO_MODE=false no siembra nada
  3. Cada mesa tiene un cÃƒÂ³digo QR ÃƒÂºnico en formato GRI-MESA-XXX y el sistema impide que dos mesas compartan cÃƒÂ³digo (constraint en BD)
**Notas**: Las tablas de dominio (mesa, categoria, producto, pedido, pedido_item, reserva, pago, calificacion) se crean aquÃƒÂ­ con FKs e ÃƒÂ­ndices compuestos por restaurante. Las transiciones de MESA_TRANSITIONS y PEDIDO_TRANSITIONS se implementan con el schema (research ligero/SPEC recomendado antes de planear).
**Plans**: 2 plans
- [x] 03-01-PLAN.md Ã¢â‚¬â€ Vertical Slice Models + State Machines + MigraciÃƒÂ³n 0002 + tests DB-direct (MESA-02, mitad INFR-03 migraciones) Ã¢â‚¬â€ Ã¢Å“â€¦ 53/53 tests, 9 tablas, 5 state machines
- [x] 03-02-PLAN.md Ã¢â‚¬â€ Vertical Slice Seed Demo + Lifespan Wiring + verify_seed.sh (PLAT-04, mitad INFR-03 seed)

### Phase 4: Panel Admin Ã¢â‚¬â€ Login, Dashboard y Mapa (Solo Lectura)
**Goal**: El staff (admin restaurante y super-admin) inicia sesiÃƒÂ³n en el panel web y ve dashboard con estadÃƒÂ­sticas y mapa de mesas con la identidad visual del mockup
**Mode:** mvp
**Depends on**: Phase 2, Phase 3
**Requirements**: PLAT-01, ADMN-01, ADMN-02
**Success Criteria** (what must be TRUE):
  1. Admin restaurante y super-admin pueden iniciar sesiÃƒÂ³n en el panel web (Flutter Web) con sus credenciales y la sesiÃƒÂ³n persiste
  2. El dashboard muestra estadÃƒÂ­sticas del restaurante con datos reales: mesas disponibles/ocupadas, reservas del dÃƒÂ­a y pedidos activos
  3. El mapa de mesas muestra cada mesa con su estado codificado por color (verde/rojo/amarillo/azul del mockup) y refleja cambios de la BD al refrescar (polling corto Ã¢â‚¬â€ deuda temporal; el tiempo real llega en Phase 7)
**Plans**: 2 plans
- [x] 04-01-PLAN.md - Vertical Slice Backend: CORSMiddleware + GET /staff/mesas + GET /staff/stats (tenant-scoped) + tests aislamiento + tests CORS (ADMN-01, ADMN-02)
- [x] 04-02-PLAN.md - Vertical Slice Panel Admin Flutter Web: scaffold + auth (login/persistencia/refresh interceptor/go_router guard) + dashboard (4 stat cards + mapa coloreado + sidebar) + polling 10s + widget tests (PLAT-01, ADMN-01, ADMN-02) ÃƒÂ¢ DONE 2026-08-14

### Phase 5: App Cliente Ã¢â‚¬â€ Descubrimiento y Reservas
**Goal**: Un cliente puede descubrir restaurantes y completar el ciclo completo de reserva (buscar Ã¢â€ â€™ reservar Ã¢â€ â€™ consultar Ã¢â€ â€™ cancelar Ã¢â€ â€™ sentarse)
**Mode:** mvp
**Depends on**: Phase 3, Phase 4
**Requirements**: AUTH-05, REST-01, REST-02, RESV-01, RESV-02, RESV-03, RESV-04, RESV-05, MESA-04
**Success Criteria** (what must be TRUE):
  1. El cliente puede registrarse e iniciar sesiÃƒÂ³n desde la app mÃƒÂ³vil y ver/editar su perfil
  2. El cliente ve la lista de restaurantes activos (nombre, tipo de cocina, calificaciÃƒÂ³n Ã¢â‚¬â€ muestra "Ã¢â‚¬â€" hasta Phase 9) y el detalle de un restaurante con su menÃƒÂº por categorÃƒÂ­as (productos con precio y descripciÃƒÂ³n)
  3. El cliente puede reservar mesa indicando fecha, hora y nÃƒÂºmero de personas; el sistema rechaza reservas que exceden capacidad o solapan horarios, incluso bajo peticiones concurrentes (sin sobre-reservas)
  4. El cliente puede consultar sus reservas (prÃƒÂ³ximas y pasadas, con estado) y cancelar una reserva futura
  5. El admin ve las reservas del dÃƒÂ­a en el panel y puede marcar la mesa como ocupada al llegar el cliente; los estados de mesa (disponible/reservada/ocupada/limpieza) solo cambian por transiciones vÃƒÂ¡lidas y las invÃƒÂ¡lidas son rechazadas
**Notas**: La protecciÃƒÂ³n anti concurrencia vive en la BD (UNIQUE mesa/fecha/slot + SELECT ... FOR UPDATE) segÃƒÂºn PITFALLS del research. Decisiones cerradas: auto-confirm (reservas nacen confirmadas, sin aprobaciÃƒÂ³n manual), slots horarios de 60min (:00), asignaciÃƒÂ³n de mesa automÃƒÂ¡tica (server elige), cancelaciÃƒÂ³n reverte mesa solo si estaba reservada. Web-first dev en Chrome :5174 (sin Android SDK).
**Plans**: 3 plans
- [x] 05-01-PLAN.md Ã¢â‚¬â€ Vertical Slice Backend Core: migraciÃƒÂ³n 0003 (UNIQUE slot) + /public/* (descubrimiento) + /cliente/* (perfil PATCH + reservas create/list/cancel con FOR UPDATE) + HARD GATE test_reserva_concurrency.py (AUTH-05, REST-01, REST-02, RESV-01, RESV-02, RESV-03, RESV-04) ÃƒÂ¢ DONE 2026-08-14 (suite 95/95)
- [x] 05-02-PLAN.md Ã¢â‚¬â€ Vertical Slice Backend Staff: EXTENDER /staff/reservas + POST /staff/mesas/{id}/estado (MESA_TRANSITIONS vÃƒÂ­a validar_transicion) + tests tenant isolation (RESV-05, MESA-04) ÃƒÂ¢ DONE 2026-08-14 (suite 105/105)
- [ ] 05-03-PLAN.md Ã¢â‚¬â€ Vertical Slice Flutter app_cliente: scaffold + copia lib/core de panel_admin + 4 tabs StatefulShellRoute.indexedStack + features auth/restaurantes/reservas/perfil + widget tests (AUTH-05, REST-01, REST-02, RESV-01, RESV-03 UI)

### Phase 6: App Cliente Ã¢â‚¬â€ Pedido por QR (REST) y Vista Cocina
**Goal**: El core value funciona de punta a punta sin tiempo real: sentarse, escanear el QR, pedir del menÃƒÂº, seguir el estado del pedido y pedir la cuenta
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-03, PEDI-04, PEDI-05, PEDI-06, PAGO-01, ADMN-05
**Success Criteria** (what must be TRUE):
  1. El cliente escanea el QR de la mesa con la cÃƒÂ¡mara del telÃƒÂ©fono, queda vinculado a la mesa (sesiÃƒÂ³n de mesa) y ve el menÃƒÂº
  2. El cliente arma un pedido con productos del menÃƒÂº y lo envÃƒÂ­a a cocina; el pedido aparece en la cola del restaurante y mesero/admin ven los pedidos activos con su detalle (mesa, productos, total)
  3. El pedido avanza por su mÃƒÂ¡quina de estados (enviado Ã¢â€ â€™ aceptado Ã¢â€ â€™ en_preparaciÃƒÂ³n Ã¢â€ â€™ servido, con rechazado como terminal); cocina avanza el pedido desde su vista de cola y las transiciones invÃƒÂ¡lidas son rechazadas (409)
  4. El cliente consulta el estado de su pedido desde la app (via REST/polling Ã¢â‚¬â€ en vivo a partir de Phase 7)
  5. El cliente puede solicitar la cuenta desde la app y el mesero/panel recibe el aviso
**Notas**: La vista de cocina de esta fase es la cola funcional (refresh/polling manual); el upgrade visual (tiempos, colores) es refinamiento sin requisito asociado. La sesiÃƒÂ³n de mesa se vincula al usuario autenticado (anti-spoofing, PITFALL P6).
**Plans**: 3 plans
- [x] 06-01-PLAN.md â€” Vertical Slice Backend: migraciÃ³n 0004 (pedido.sesion_id + cuenta solicitada + UNIQUE sesiÃ³n activa por usuario) + /cliente/sesiones|pedidos|cuenta + /staff/pedidos (cola + matriz rolÃ—transiciÃ³n + anti-zombi limpieza) + 4 suites tests con HARD GATE concurrencia (MESA-05, MESA-06, PEDI-01..06, PAGO-01 backend)
- [ ] 06-02-PLAN.md â€” Vertical Slice App Cliente: sesion_qr (mobile_scanner + input manual primera clase) + pedidos (carrito, envÃ­o, estado polling 10s, cuenta) + banner "EstÃ¡s en la Mesa X" + widget tests (MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-04, PAGO-01 UI)
- [x] 06-03-PLAN.md â€” Vertical Slice Panel Cocina: cola de pedidos con cards (mesa/items/total/badge cuenta), botones segÃºn matriz rolÃ—estado, polling 10s, sidebar "Pedidos" activo (ADMN-05, PEDI-05, PEDI-06, PAGO-01 UI) â€” DONE 2026-08-14 (panel suite 17/17, analyze 0, build web OK)

### Phase 7: Tiempo Real Ã¢â‚¬â€ WebSockets
**Goal**: Pedidos y estados de mesa llegan en vivo a cocina, mesero, cliente y panel sin refrescar, con recuperaciÃƒÂ³n ante desconexiones
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: RT-01, RT-02, RT-03
**Success Criteria** (what must be TRUE):
  1. Un cambio de estado de pedido llega en vivo a cocina, mesero/admin y al cliente sin refrescar la pantalla
  2. El mapa de mesas del panel se actualiza en vivo cuando cambia el estado de una mesa (completa el polling de Phase 4)
  3. Tras una desconexiÃƒÂ³n (p.ej. wifi perdido), la app se reconecta y re-sincroniza el estado al reconectar (sin eventos duplicados ni pantallas desactualizadas)
**Notas**: Research de fase obligatorio antes de planear (patrÃƒÂ³n de reconexiÃƒÂ³n Flutter, replay con sequence numbers, heartbeat). La abstracciÃƒÂ³n `Broadcaster` entra aquÃƒÂ­ desde el dÃƒÂ­a 1 (in-memory v1, Redis-ready).
**Plans**: 3 plans
- [x] 07-01-PLAN.md â€” Vertical Slice Backend: Broadcaster (rooms + seq, Redis-ready) + /ws/staff + /ws/cliente (auth JWT manual 4401, sin Depends(get_session)) + 6 emisiones post-commit en services + suite test_ws.py contra stack vivo con httpx-ws (RT-01/02/03 backend)
- [x] 07-02-PLAN.md â€” Vertical Slice Panel Admin: WsClient (backoff+jitter, token fresco, 4401â†’refresh, dedup seq, resync) + kick-to-refetch en mesas/stats/pedidosStaff + safety net 60s + widget tests (RT-01/02/03 panel) â€” depende de 07-01
- [x] 07-03-PLAN.md â€” Vertical Slice App Cliente: WsClient (copia) + pedidos de la sesion en vivo + manejo sesion.cerrada (anti-zombi) + tests dedup/reconexion/4401 (RT-01/03 cliente) â€” depende de 07-01, paralelo con 07-02 â€” COMPLETO 2026-08-14 (suite 41, commits 80ea89b/cc7073e/030b69e)

### Phase 8: Panel Admin Ã¢â‚¬â€ GestiÃƒÂ³n Completa y Reportes
**Goal**: El restaurante opera completamente desde el panel: gestiÃƒÂ³n de mesas con QR, menÃƒÂº, clientes, reportes y gestiÃƒÂ³n de plataforma del super-admin
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: PLAT-05, MENU-01, MENU-02, MESA-01, MESA-03, ADMN-03, ADMN-04, REPO-01, REPO-02
**Success Criteria** (what must be TRUE):
  1. El admin puede crear y editar mesas (nÃƒÂºmero, capacidad) y ver/imprimir el QR de cada mesa; el mapa refleja las mesas nuevas
  2. El admin puede crear, editar y desactivar categorÃƒÂ­as y productos del menÃƒÂº (con precio, descripciÃƒÂ³n, imagen y toggle agotado)
  3. El admin puede cambiar el estado de una mesa desde el mapa (marcar en limpieza, liberar) y gestionar clientes (lista e historial)
  4. El admin puede ver reportes de ventas por dÃƒÂ­a/rango (total, nÃƒÂºmero de pedidos) y los platos mÃƒÂ¡s vendidos
  5. El super-admin puede ver la lista de restaurantes y desactivarlos desde el panel
**Plans**: 5 plans
- [x] 08-01-PLAN.md â€” Vertical Slice Backend: migraciÃ³n 0005 (activo en categoria/producto + filtro pÃºblico) + menÃº CRUD (/staff/menu, categorÃ­as, productos) + clientes e historial (MENU-01, MENU-02, ADMN-03)
- [x] 08-02-PLAN.md â€” Vertical Slice Backend: mesas CRUD con QR determinista GRI-MESA-R{rid}-{numero:03d} + reportes ventas/top-platos (venta=servido|pagado) + PLAT-05 PATCH activo + incluir_inactivos (MESA-01, REPO-01, REPO-02, PLAT-05) â€” depende de 08-01
- [x] 08-03-PLAN.md â€” Vertical Slice Panel: gestiÃ³n de mesas + QR dialog imprimible (qr_flutter/web) + mapa interactivo ADMN-04 con solo transiciones vÃ¡lidas + sidebar Mesas + TopBar dinÃ¡mico (MESA-01, MESA-03, ADMN-04) â€” depende de 08-02
- [x] 08-04-PLAN.md â€” Vertical Slice Panel: menÃº CRUD en ConfiguraciÃ³n (tabs) + clientes DataTable2 con historial (MENU-01, MENU-02, ADMN-03) â€” depende de 08-03
- [x] 08-05-PLAN.md â€” Vertical Slice Panel: reportes por rango + reservas del dÃ­a (marcar ocupada) + tab Restaurantes super-admin (PLAT-05) + sidebar 7/7 (REPO-01, REPO-02, PLAT-05) â€” depende de 08-04

### Phase 9: Pagos, Calificaciones y Deploy
**Goal**: El ciclo financiero cierra: pago en lÃƒÂ­nea idempotente que libera la mesa, calificaciÃƒÂ³n post-pago visible en discover, y despliegue a producciÃƒÂ³n en Ubuntu Server
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: PAGO-02, PAGO-03, PAGO-04, CALI-01, CALI-02
**Success Criteria** (what must be TRUE):
  1. El cliente puede pagar en lÃƒÂ­nea el total de su consumo desde la app (pasarela definida en el research de la fase Ã¢â‚¬â€ Wompi preferida)
  2. Los pagos son idempotentes: reintentos o webhooks duplicados no generan doble cobro ni estados corruptos
  3. Al confirmarse el pago, la mesa pasa a limpieza y la sesiÃƒÂ³n de mesa se cierra
  4. Tras un pedido pagado, el cliente puede calificar su experiencia (estrellas + comentario) y el promedio del restaurante es visible en la lista y detalle de restaurantes
**Notas**: Research de fase MANDATORIO antes de planear (Wompi/PayU/Mercado Pago: webhooks, firma HMAC, sandbox, comisiones 2026). El deploy a Ubuntu Server (nginx + TLS + WS upgrade + DEMO_MODE=false) es la verificaciÃƒÂ³n final de INFR-01/02/03 en producciÃƒÂ³n.
**Plans**: 4 plans
- [x] 09-01-PLAN.md — Vertical Slice Backend Pagos: migración 0006 (pago.sesion_id + transaction_id + pago_event dedup) + gateway abstracto (Sandbox/Wompi con firmas verificadas) + /cliente/pagos/intencion|estado + webhook público timing-safe + efectos atómicos (pedidos pagado, sesión cerrada, mesa limpieza) + sandbox checkout por el MISMO pipeline + e2e tests (PAGO-02, PAGO-03, PAGO-04)
- [x] 09-02-PLAN.md — Vertical Slice Backend Calificaciones: POST /cliente/calificaciones (solo pedidos pagados propios, 404/409/422) + promedio AVG/COUNT en /public lista y detalle (CALI-01, CALI-02) — depende de 09-01
- [x] 09-03-PLAN.md — Vertical Slice App Cliente: features/pagos (botón Pagar → url_launcher → polling → éxito) + calificacion_sheet (5 estrellas custom) + rating real en lista/detalle restaurantes + checkpoint e2e sandbox (PAGO-02 UI, CALI-01 UI, CALI-02 UI) — depende de 09-01 + 09-02
- [x] 09-04-PLAN.md — Vertical Slice Deploy: docker-compose.prod.yml (mysql:8.4.11 pin, sin puertos BD, 1 worker) + nginx HOST con WS upgrade/TLS/certbot + .env.production.example + README guía Ubuntu + verify_local.ps1 production-like (INFR-01/02/03 re-verificados) — depende de 09-01, paralelo con 09-03

## Progress

**Execution Order:**
Phases execute in numeric order: 1 Ã¢â€ â€™ 2 Ã¢â€ â€™ 3 Ã¢â€ â€™ 4 Ã¢â€ â€™ 5 Ã¢â€ â€™ 6 Ã¢â€ â€™ 7 Ã¢â€ â€™ 8 Ã¢â€ â€™ 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. FundaciÃƒÂ³n e Infraestructura | 1/1 | Complete | 2026-08-13 |
| 2. AutenticaciÃƒÂ³n, Roles y Multi-tenant | 2/2 | Complete   | 2026-08-13 |
| 3. Modelo de Dominio y Seed Demo | 2/2 | Complete | 2026-08-13 |
| 4. Panel Admin Ã¢â‚¬â€ Login, Dashboard y Mapa (Solo Lectura) | 2/2 | Complete | 2026-08-14 |
| 5. App Cliente Ã¢â‚¬â€ Descubrimiento y Reservas | 3/3 | Complete | 2026-08-14 |
| 6. App Cliente Ã¢â‚¬â€ Pedido por QR (REST) y Vista Cocina | 3/3 | Complete | 2026-08-14 |
| 7. Tiempo Real Ã¢â‚¬â€ WebSockets | 2/3 | In progress | - |
| 8. Panel Admin - Gestion Completa y Reportes | 0/5 | Planned | - |
| 9. Pagos, Calificaciones y Deploy | 0/4 | Planned | - |

### Phase 10: Migracion a Firebase (Opcion B) — apps Flutter (movil y panel web) directas a Firebase Auth + Firestore con security rules, backend FastAPI archivado como referencia

**Goal:** Las dos apps Flutter (app cliente y panel admin) funcionan 100% sobre Firebase Auth + Firestore con security rules por custom claims, realtime nativo (onSnapshot) y transacciones de concurrencia; el restaurante demo se siembra en Firestore (emuladores + proyecto real) y el backend FastAPI queda archivado como referencia
**Mode:** mvp
**Depends on**: Phase 9
**Requirements**: MIGRA-01, MIGRA-02, MIGRA-03, MIGRA-04, MIGRA-05, MIGRA-06
**Success Criteria** (what must be TRUE):
  1. La app cliente completa (auth, descubrimiento, reservas, sesión QR, pedidos, cuenta, calificación) opera 100% contra Firebase sin rastro de la capa HTTP propia (dio/ws/dotenv fuera del pubspec)
  2. El panel admin completo (login staff por claims, dashboard/mapa y cocina en vivo, mesas+QR, menú, clientes, reportes, reservas, super-admin) opera 100% contra Firebase
  3. firestore.rules + firestore.indexes.json desplegables al proyecto p-gri-b5b40: autorización 100% por custom claims {role, rid}, doc usuarios espejo jamás autoriza, transiciones validadas server-side
  4. El seed idempotente (restaurante demo + 6 usuarios + claims + 8 mesas QR + menú de 16 productos) corre contra emuladores sin credenciales y contra el proyecto real con serviceAccountKey (gitignored)
  5. Pedidos, mesas, reservas y aviso de cuenta se actualizan en vivo en cliente y panel sin refrescar (onSnapshot nativo — reemplaza WebSockets de Phase 7)
  6. Reservas y sesiones de mesa son seguras bajo concurrencia: doc IDs deterministas + runTransaction (sin doble reserva del slot ni doble sesión activa por mesa)
**Plans:** 7 plans
- [x] 10-01-PLAN.md — Infra Firebase raíz: firestore.rules + indexes + firebase.json + seed idempotente (Admin SDK, claims) + guía FIREBASE_SETUP (MIGRA-03, MIGRA-04)
- [x] 10-02-PLAN.md — app_cliente: deps + firebase_options (fallback manual) + bootstrap emuladores + state_machines port 1:1 + auth/perfil migrados (MIGRA-01)
- [x] 10-03-PLAN.md — app_cliente: models fromDoc + discover (lista/detalle/menú) + reservas tx anti sobre-reserva (MIGRA-01, MIGRA-06)
- [x] 10-04-PLAN.md — app_cliente: sesión QR tx + pedidos snapshot tx + cuenta + calificación agregada + realtime + purge legacy (MIGRA-01, MIGRA-05, MIGRA-06)
- [x] 10-05-PLAN.md — panel_admin: bootstrap + login por claims + dashboard/mapa/stats en vivo + cocina cola realtime + aviso cuenta (MIGRA-02, MIGRA-05) — depende de 10-04 (app primero)
- [x] 10-06-PLAN.md — panel_admin: mesas CRUD+QR determinista + menú CRUD + clientes + reservas staff + super-admin + reportes + purge legacy (MIGRA-02, MIGRA-05)
- [x] 10-07-PLAN.md — Smoke e2e en emuladores + deploy rules/indexes al proyecto real + checkpoint final (MIGRA-03, MIGRA-04, MIGRA-05, MIGRA-06)

### Phase 11: Corrección Crítica y Profesionalización — Bootstrap, Reglas/Índices y Sistema de Diseño

**Goal:** GRI arranca desde una base de datos vacía y se comporta como un producto profesional: un super_admin se crea a sí mismo desde el panel, da de alta restaurantes y equipo sin scripts, el cliente puede entrar con Google, el menú del cliente y el del panel cargan sin errores de rules ni de índices, y las dos apps son responsive, accesibles y con identidad GRI.
**Depends on:** Phase 10
**Requirements**: ENV-01, DOC-01, FIX-01, FIX-02, TEST-01, TEST-02, BOOT-01, BOOT-02, BOOT-03, BOOT-04, AUTH-G01, UX-01, UX-02, UX-03, UX-04, DS-01, DS-02, DS-03, E2E-01, E2E-02
**Success Criteria** (qué debe ser VERDAD):
  1. Desde un proyecto Firebase vacío, una persona autorizada crea el primer super_admin desde `/bootstrap`, da de alta un restaurante con slug válido y su equipo (admin/mesero/cocina) sin tocar la consola ni `serviceAccountKey.json`
  2. La función de bootstrap exige correo verificado **y** un secreto de despliegue, y una carrera de N llamadas paralelas deja exactamente un super_admin y un solo documento centinela
  3. Nadie puede asignar el rol `super_admin` por la callable de staff, un `admin_restaurante` nunca puede crear usuarios de otro `rid`, y la cuenta de un cliente no puede convertirse en staff sin su consentimiento — todo demostrado con tests unitarios exhaustivos y e2e con tokens reales
  4. Un cliente ve el menú de un restaurante que tiene productos agotados y categorías inactivas (bug de query vs rules cerrado), y el menú del panel carga sin `FAILED_PRECONDITION` (índice compuesto declarado y construido en el proyecto real)
  5. `firestore.rules` tiene suite automatizada en las 9 colecciones, existen tests de base vacía en ambas apps, y `npm run audit:indexes` falla tanto si una query nueva se queda sin índice como si pierde un filtro que la regla exige
  6. Un cliente puede registrarse e iniciar sesión con Google en la app móvil, quedando como cliente sin claims, y la colisión con una cuenta de contraseña se explica en vez de reventar
  7. Los 5 campos de contraseña permiten ver lo escrito, el registro pide confirmación, ninguna lista queda en blanco sin guía (incluido el dashboard con la plataforma vacía) y una URL inexistente muestra un 404 propio
  8. Ni el panel ni la app cliente conservan rastro de "A new Flutter project" ni del azul `#0175C2`; el ícono y el splash del móvil son GRI, y `npm run audit:branding` caza la regresión
  9. Todas las pantallas del panel (contadas del árbol real, no de una constante) adaptan al viewport, la app cliente ya no está encajada en 480px fijos, y los dos overflows conocidos están cerrados con test de regresión
  10. Las pantallas del camino crítico pasan `androidTapTargetGuideline` y `labeledTapTargetGuideline`, y el texto secundario cumple contraste AA **sin que ningún token de la paleta de marca cambie de valor**
  11. `npm run gates` deja en verde los 8 gates (2 suites Flutter, 2 analyze, rules, functions, audit de índices, audit de branding) sin bajar de los baselines 91 + 84
  12. El runbook `docs/SMOKE-E2E-v2.md` recorre el flujo completo desde base vacía, incluidas la verificación de que el QR de mesa es escaneable y el ingreso con Google
**Notas**: La identidad visual se CONSERVA (naranja `#FF4C05`, layout del mockup) — es trabajo de consistencia, no de rediseño. El plan Blaze solo hace falta para desplegar Cloud Functions, no para emularlas: toda la fase es desarrollable y testeable sin tocar la facturación, y el despliegue está partido en dos checkpoints (rules/índices sin Blaze en 11-16; funciones con Blaze en 11-20) para que la prueba real del bug del índice no quede rehén de una decisión de facturación.
**Plans:** 3/20 plans executed

Plans:
- [x] 11-01-PLAN.md — Ola 1: desbloqueo de entorno (Java, `.firebaserc`), scaffold de `functions/` con `.env.demo-gri`, arnés de tests de rules y CLAUDE.md corregido
- [x] 11-02-PLAN.md — Ola 1: fixture de base vacía + regresión de primer arranque, cliente de Cloud Functions en el panel y guía de arranque en el dashboard
- [x] 11-03-PLAN.md — Ola 2: bug del menú del cliente (query vs rules) + índice compuesto de `categorias` + audit de índices y de paridad rules↔query
- [ ] 11-04-PLAN.md — Ola 2: suite de `firestore.rules` del resto de colecciones, con los tres vectores de escalada conocidos
- [ ] 11-05-PLAN.md — Ola 2: panel — crear restaurante con slug (y seleccionarlo al vuelo), estado vacío guiado y confirmación al desactivar
- [ ] 11-06-PLAN.md — Ola 2: ver/ocultar contraseña en los 5 campos + confirmar contraseña en el registro
- [ ] 11-07-PLAN.md — Ola 3: Cloud Function de bootstrap del primer super_admin (guarda atómica, correo verificado + secreto) + pantalla `/bootstrap` con ruta exenta del guard
- [ ] 11-18-PLAN.md — Ola 3: branding GRI en LAS DOS apps (generador de assets, manifest, favicon, ícono, splash) + `audit:branding`
- [ ] 11-08-PLAN.md — Ola 4: callable `crearUsuarioStaff` con la matriz de roles, anti-secuestro y su combinatoria de escalada
- [ ] 11-09-PLAN.md — Ola 4: estados vacíos guiados y pantalla 404 propia en ambas apps
- [ ] 11-17-PLAN.md — Ola 4: login con Google en la app cliente (rama Web ya funcional; corrección del appId de Android al registro correcto + checkpoint de la huella SHA-1)
- [ ] 11-10-PLAN.md — Ola 5: panel — pantalla de equipo adaptativa por rol + regla de lectura acotada al `rid`
- [ ] 11-11-PLAN.md — Ola 5: tokens de diseño (espaciado, radios, breakpoints), escala tipográfica y colores semánticos
- [ ] 11-12-PLAN.md — Ola 6: migración 1:1 de hex crudos y estilos duplicados del PANEL + gate anti-regresión
- [ ] 11-19-PLAN.md — Ola 6: migración 1:1 de hex crudos y `TextStyle` de la APP CLIENTE + gate anti-regresión
- [ ] 11-13-PLAN.md — Ola 7: responsive real (shell del cliente, todas las pantallas del panel, grids fluidos, overflows)
- [ ] 11-14-PLAN.md — Ola 8: accesibilidad (etiquetas, tap targets de 48dp, contraste AA sin tocar la paleta) con gates `meetsGuideline`
- [ ] 11-15-PLAN.md — Ola 9: runbook `SMOKE-E2E-v2` desde base vacía + `npm run gates` como ejecutor único
- [ ] 11-16-PLAN.md — Ola 10: runbook de despliegue + CHECKPOINT HUMANO A (rules e índices, sin Blaze) con la prueba real del bug del índice
- [ ] 11-20-PLAN.md — Ola 11: CHECKPOINT HUMANO B (Blaze, deploy de Cloud Functions y smoke E2E completo)

---
*Coverage: 50/50 requisitos v1 mapeados (PLAT 5, AUTH 5, REST 2, MENU 2, MESA 6, RESV 5, PEDI 6, RT 3, PAGO 4, CALI 2, ADMN 5, REPO 2, INFR 3). Nota: REQUIREMENTS.md decÃƒÂ­a "47 total" por error aritmÃƒÂ©tico; el conteo real de IDs es 50.*
*Created: 2026-08-13*






