# Roadmap: GRI — Gestión y Reservas de Restaurantes

## Overview

GRI se construye de abajo hacia arriba siguiendo sus dependencias técnicas: primero la infraestructura (Docker + MySQL + API con configuración por entorno), luego la autenticación multi-rol con aislamiento multi-tenant —que debe existir antes de cualquier endpoint de negocio—, y el modelo de dominio con el restaurante demo sembrado. Sobre esa base se construyen las dos aplicaciones: el panel web admin (primero solo lectura, para validar la capa de datos y la identidad visual del mockup; después gestión completa) y la app móvil cliente (primero descubrimiento y reservas, luego el pedido por QR que constituye el core value). El tiempo real (WebSockets) convierte lo funcional en vivo, y el ciclo cierra con pagos en línea, calificaciones y el despliegue a producción en Ubuntu Server. Cada fase entrega una capacidad verificable de punta a punta.

Nota: la Fase de cliente del research original (una sola fase "Cliente Móvil REST" con ~18 requisitos) se dividió aquí en dos journeys verticales independientes y verificables: Descubrimiento/Reservas (Fase 5) y Pedido por QR (Fase 6, el core value).

## Phases

**Phase Numbering:**
- Fases enteras (1, 2, 3): trabajo planificado del milestone
- Fases decimales (2.1, 2.2): inserciones urgentes (marcadas con INSERTED)

- [ ] **Phase 1: Fundación e Infraestructura** - Docker + MySQL + API corriendo con configuración por entorno
- [ ] **Phase 2: Autenticación, Roles y Multi-tenant** - JWT multi-rol con aislamiento por restaurante; el super-admin crea restaurantes y staff
- [ ] **Phase 3: Modelo de Dominio y Seed Demo** - Todas las tablas de negocio, state machines y restaurante demo sembrado
- [ ] **Phase 4: Panel Admin — Login, Dashboard y Mapa (Solo Lectura)** - El staff inicia sesión y ve estadísticas y mapa de mesas con los colores del mockup
- [ ] **Phase 5: App Cliente — Descubrimiento y Reservas** - El cliente descubre restaurantes y completa el ciclo de reserva de principio a fin
- [ ] **Phase 6: App Cliente — Pedido por QR (REST) y Vista Cocina** - El core value end-to-end: escanear, pedir, seguir el estado y pedir la cuenta (sin tiempo real aún)
- [ ] **Phase 7: Tiempo Real — WebSockets** - Pedidos y mesas en vivo en cocina, mesero, cliente y panel sin refrescar
- [ ] **Phase 8: Panel Admin — Gestión Completa y Reportes** - CRUD de mesas/menú/clientes, reportes de ventas y gestión de plataforma
- [ ] **Phase 9: Pagos, Calificaciones y Deploy** - Pago en línea idempotente, calificación post-pago y despliegue a Ubuntu Server

## Phase Details

### Phase 1: Fundación e Infraestructura
**Goal**: La plataforma corre: MySQL y la API en Docker, conectados por configuración de entorno, con datos persistentes
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: INFR-01, INFR-02
**Success Criteria** (what must be TRUE):
  1. `docker compose up` levanta MySQL y la API; el healthcheck de la API responde OK con la conexión a BD verificada
  2. Los datos de MySQL sobreviven al reinicio del contenedor (volumen persistente) y la BD usa charset utf8mb4 con timezone America/Bogota (acentos y emojis se guardan y se leen bien)
  3. La conexión a la BD se configura por variables de entorno: cambiar el `.env` cambia la conexión sin tocar código
**Plans**: 1 plan
- [ ] 01-01-PLAN.md — Walking Skeleton: stack Docker (MySQL 8.4 + FastAPI) con /health verificando SELECT 1, charset/TZ/persistencia y conexión por .env

### Phase 2: Autenticación, Roles y Multi-tenant
**Goal**: Usuarios autenticados con sesión persistente, 5 roles distinguibles y aislamiento estricto por restaurante; el super-admin administra la plataforma vía API
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, PLAT-02, PLAT-03
**Success Criteria** (what must be TRUE):
  1. Un usuario puede registrarse como cliente (nombre, email, contraseña) e iniciar sesión recibiendo access + refresh token; el refresh le da una nueva sesión sin volver a loguearse
  2. El sistema distingue los 5 roles (super_admin, admin_restaurante, mesero, cocina, cliente) y cada rol solo accede a los endpoints que le corresponden
  3. Un usuario staff del restaurante A que solicita recursos del restaurante B recibe 404 (aislamiento multi-tenant verificado con tests de acceso cruzado)
  4. El super-admin puede crear restaurantes con sus datos básicos y usuarios staff (admin, mesero, cocina) asignados a un restaurante vía la API
**Plans**: TBD

### Phase 3: Modelo de Dominio y Seed Demo
**Goal**: Toda la base de datos de negocio existe con state machines explícitas (mesa y pedido) y el restaurante demo sembrado al inicializar
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PLAT-04, MESA-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. Al desplegar/inicializar la plataforma en limpio, las migraciones (Alembic) y el seed se ejecutan automáticamente como parte del proceso
  2. El sistema siembra un restaurante demo con menú, mesas y datos de ejemplo cuando DEMO_MODE está activo; con DEMO_MODE=false no siembra nada
  3. Cada mesa tiene un código QR único en formato GRI-MESA-XXX y el sistema impide que dos mesas compartan código (constraint en BD)
**Notas**: Las tablas de dominio (mesa, categoria, producto, pedido, pedido_item, reserva, pago, calificacion) se crean aquí con FKs e índices compuestos por restaurante. Las transiciones de MESA_TRANSITIONS y PEDIDO_TRANSITIONS se implementan con el schema (research ligero/SPEC recomendado antes de planear).
**Plans**: TBD

### Phase 4: Panel Admin — Login, Dashboard y Mapa (Solo Lectura)
**Goal**: El staff (admin restaurante y super-admin) inicia sesión en el panel web y ve dashboard con estadísticas y mapa de mesas con la identidad visual del mockup
**Mode:** mvp
**Depends on**: Phase 2, Phase 3
**Requirements**: PLAT-01, ADMN-01, ADMN-02
**Success Criteria** (what must be TRUE):
  1. Admin restaurante y super-admin pueden iniciar sesión en el panel web (Flutter Web) con sus credenciales y la sesión persiste
  2. El dashboard muestra estadísticas del restaurante con datos reales: mesas disponibles/ocupadas, reservas del día y pedidos activos
  3. El mapa de mesas muestra cada mesa con su estado codificado por color (verde/rojo/amarillo/azul del mockup) y refleja cambios de la BD al refrescar (polling corto — deuda temporal; el tiempo real llega en Phase 7)
**Plans**: TBD

### Phase 5: App Cliente — Descubrimiento y Reservas
**Goal**: Un cliente puede descubrir restaurantes y completar el ciclo completo de reserva (buscar → reservar → consultar → cancelar → sentarse)
**Mode:** mvp
**Depends on**: Phase 3, Phase 4
**Requirements**: AUTH-05, REST-01, REST-02, RESV-01, RESV-02, RESV-03, RESV-04, RESV-05, MESA-04
**Success Criteria** (what must be TRUE):
  1. El cliente puede registrarse e iniciar sesión desde la app móvil y ver/editar su perfil
  2. El cliente ve la lista de restaurantes activos (nombre, tipo de cocina, calificación — muestra "—" hasta Phase 9) y el detalle de un restaurante con su menú por categorías (productos con precio y descripción)
  3. El cliente puede reservar mesa indicando fecha, hora y número de personas; el sistema rechaza reservas que exceden capacidad o solapan horarios, incluso bajo peticiones concurrentes (sin sobre-reservas)
  4. El cliente puede consultar sus reservas (próximas y pasadas, con estado) y cancelar una reserva futura
  5. El admin ve las reservas del día en el panel y puede marcar la mesa como ocupada al llegar el cliente; los estados de mesa (disponible/reservada/ocupada/limpieza) solo cambian por transiciones válidas y las inválidas son rechazadas
**Notas**: La protección anti concurrencia vive en la BD (UNIQUE mesa/fecha/slot + SELECT ... FOR UPDATE) según PITFALLS del research. Decisiones abiertas para el SPEC: auto-confirm vs aprobación manual, política de cancelación.
**Plans**: TBD

### Phase 6: App Cliente — Pedido por QR (REST) y Vista Cocina
**Goal**: El core value funciona de punta a punta sin tiempo real: sentarse, escanear el QR, pedir del menú, seguir el estado del pedido y pedir la cuenta
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-03, PEDI-04, PEDI-05, PEDI-06, PAGO-01, ADMN-05
**Success Criteria** (what must be TRUE):
  1. El cliente escanea el QR de la mesa con la cámara del teléfono, queda vinculado a la mesa (sesión de mesa) y ve el menú
  2. El cliente arma un pedido con productos del menú y lo envía a cocina; el pedido aparece en la cola del restaurante y mesero/admin ven los pedidos activos con su detalle (mesa, productos, total)
  3. El pedido avanza por su máquina de estados (enviado → aceptado → en_preparación → servido, con rechazado como terminal); cocina avanza el pedido desde su vista de cola y las transiciones inválidas son rechazadas (409)
  4. El cliente consulta el estado de su pedido desde la app (via REST/polling — en vivo a partir de Phase 7)
  5. El cliente puede solicitar la cuenta desde la app y el mesero/panel recibe el aviso
**Notas**: La vista de cocina de esta fase es la cola funcional (refresh/polling manual); el upgrade visual (tiempos, colores) es refinamiento sin requisito asociado. La sesión de mesa se vincula al usuario autenticado (anti-spoofing, PITFALL P6).
**Plans**: TBD

### Phase 7: Tiempo Real — WebSockets
**Goal**: Pedidos y estados de mesa llegan en vivo a cocina, mesero, cliente y panel sin refrescar, con recuperación ante desconexiones
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: RT-01, RT-02, RT-03
**Success Criteria** (what must be TRUE):
  1. Un cambio de estado de pedido llega en vivo a cocina, mesero/admin y al cliente sin refrescar la pantalla
  2. El mapa de mesas del panel se actualiza en vivo cuando cambia el estado de una mesa (completa el polling de Phase 4)
  3. Tras una desconexión (p.ej. wifi perdido), la app se reconecta y re-sincroniza el estado al reconectar (sin eventos duplicados ni pantallas desactualizadas)
**Notas**: Research de fase obligatorio antes de planear (patrón de reconexión Flutter, replay con sequence numbers, heartbeat). La abstracción `Broadcaster` entra aquí desde el día 1 (in-memory v1, Redis-ready).
**Plans**: TBD

### Phase 8: Panel Admin — Gestión Completa y Reportes
**Goal**: El restaurante opera completamente desde el panel: gestión de mesas con QR, menú, clientes, reportes y gestión de plataforma del super-admin
**Mode:** mvp
**Depends on**: Phase 4, Phase 6
**Requirements**: PLAT-05, MENU-01, MENU-02, MESA-01, MESA-03, ADMN-03, ADMN-04, REPO-01, REPO-02
**Success Criteria** (what must be TRUE):
  1. El admin puede crear y editar mesas (número, capacidad) y ver/imprimir el QR de cada mesa; el mapa refleja las mesas nuevas
  2. El admin puede crear, editar y desactivar categorías y productos del menú (con precio, descripción, imagen y toggle agotado)
  3. El admin puede cambiar el estado de una mesa desde el mapa (marcar en limpieza, liberar) y gestionar clientes (lista e historial)
  4. El admin puede ver reportes de ventas por día/rango (total, número de pedidos) y los platos más vendidos
  5. El super-admin puede ver la lista de restaurantes y desactivarlos desde el panel
**Plans**: TBD

### Phase 9: Pagos, Calificaciones y Deploy
**Goal**: El ciclo financiero cierra: pago en línea idempotente que libera la mesa, calificación post-pago visible en discover, y despliegue a producción en Ubuntu Server
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: PAGO-02, PAGO-03, PAGO-04, CALI-01, CALI-02
**Success Criteria** (what must be TRUE):
  1. El cliente puede pagar en línea el total de su consumo desde la app (pasarela definida en el research de la fase — Wompi preferida)
  2. Los pagos son idempotentes: reintentos o webhooks duplicados no generan doble cobro ni estados corruptos
  3. Al confirmarse el pago, la mesa pasa a limpieza y la sesión de mesa se cierra
  4. Tras un pedido pagado, el cliente puede calificar su experiencia (estrellas + comentario) y el promedio del restaurante es visible en la lista y detalle de restaurantes
**Notas**: Research de fase MANDATORIO antes de planear (Wompi/PayU/Mercado Pago: webhooks, firma HMAC, sandbox, comisiones 2026). El deploy a Ubuntu Server (nginx + TLS + WS upgrade + DEMO_MODE=false) es la verificación final de INFR-01/02/03 en producción.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Fundación e Infraestructura | 0/1 | Planned | - |
| 2. Autenticación, Roles y Multi-tenant | 0/? | Not started | - |
| 3. Modelo de Dominio y Seed Demo | 0/? | Not started | - |
| 4. Panel Admin — Login, Dashboard y Mapa (Solo Lectura) | 0/? | Not started | - |
| 5. App Cliente — Descubrimiento y Reservas | 0/? | Not started | - |
| 6. App Cliente — Pedido por QR (REST) y Vista Cocina | 0/? | Not started | - |
| 7. Tiempo Real — WebSockets | 0/? | Not started | - |
| 8. Panel Admin — Gestión Completa y Reportes | 0/? | Not started | - |
| 9. Pagos, Calificaciones y Deploy | 0/? | Not started | - |

---
*Coverage: 50/50 requisitos v1 mapeados (PLAT 5, AUTH 5, REST 2, MENU 2, MESA 6, RESV 5, PEDI 6, RT 3, PAGO 4, CALI 2, ADMN 5, REPO 2, INFR 3). Nota: REQUIREMENTS.md decía "47 total" por error aritmético; el conteo real de IDs es 50.*
*Created: 2026-08-13*
