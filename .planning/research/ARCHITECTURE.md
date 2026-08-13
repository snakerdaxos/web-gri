# Architecture Research

**Domain:** Multi-tenant restaurant management & reservation platform (SaaS)
**Researched:** 2026-08-13
**Confidence:** HIGH — dominio maduro, patrones bien establecidos y verificados contra docs oficiales de FastAPI; MEDIUM en integración de pasarela colombiana (se decide en su fase)

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         CLIENTES (Frontends Flutter)                      │
├──────────────────────────────────────────────────────────────────────────┤
│   App Cliente (móvil Android/iOS)         Panel Admin (Web)               │
│   - Login cliente (JWT)                   - Login staff (JWT + tenant)    │
│   - Buscar/restaurante, menú              - Dashboard, mapa de mesas      │
│   - Reservar, escanear QR                 - Gestión CRUD (mesas/menú/...) │
│   - Armar pedido, seguir en vivo          - Pedidos en vivo (WS)          │
│   - Pagar en línea, calificar             - Reportes, configuración       │
└──────────────┬───────────────────────────────────────┬───────────────────┘
               │ HTTP REST (JSON)                       │ HTTP REST (JSON)
               │ WebSocket (JSON frames)                │ WebSocket (JSON frames)
               │ Bearer JWT                             │ Bearer JWT
               ▼                                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                     API FastAPI (Python) — núcleo único                   │
├──────────────────────────────────────────────────────────────────────────┤
│  Capa de presentación (routers)                                          │
│   ├─ /auth/*         (login, refresh, registro demo)                     │
│   ├─ /public/*       (restaurantes, menú público — sin tenant en path)   │
│   ├─ /cliente/*      (reservas, pedidos, pagos, calificaciones)          │
│   ├─ /staff/*        (gestión restaurante — mesero/cocina/admin)         │
│   ├─ /admin-gri/*    (super-admin GRI: crear restaurantes)               │
│   └─ /ws             (WebSocket con rooms por restaurante)               │
│                                                                           │
│  Capa de dominio (servicios / casos de uso)                              │
│   ├─ AuthService          (emisión JWT, validación, claims rol+tenant)   │
│   ├─ TenantScope          (dependencia: inyecta restaurant_id al ctx)     │
│   ├─ PedidoService        (máquina de estados del pedido)                │
│   ├─ MesaService          (máquina de estados de mesa + reservas)         │
│   ├─ PagoService          (integración pasarela colombiana)              │
│   └─ RealtimeHub          (ConnectionManager + broadcast por room)        │
│                                                                           │
│  Capa de persistencia (SQLAlchemy + Alembic)                             │
│   ├─ Models (todas las tablas tenant-scoped con FK restaurant_id)        │
│   ├─ Repositories (queries SIEMPRE filtradas por tenant)                 │
│   └─ Migrations (Alembic upgrade head)                                   │
└──────────────┬───────────────────────────────────────┬───────────────────┘
               │                                        │
               ▼                                        ▼
┌──────────────────────────────┐         ┌────────────────────────────────┐
│   MySQL 8.x (Docker)         │         │   Pasarela de pago (REST/hooks)│
│   - 1 base de datos shared   │         │   - Wompi / PayU / ePayco (CO) │
│   - tenant_id en cada tabla  │         │   - Webhooks de confirmación   │
│   - FK + índices compuestos  │         │   - En su fase se decide cuál  │
└──────────────────────────────┘         └────────────────────────────────┘
```

**Nota clave:** es un **monolito modular** (un solo servicio FastAPI). No hay microservicios. La separación horizontal es por *capas* (routers → servicios → repos); la separación vertical es por *bounded contexts* (auth, restaurante, pedido, pago, realtime). Para la escala de GRI (decenas a centenas de restaurantes) esto es lo correcto; partir en microservicios sería over-engineering.

### Component Responsibilities

| Componente | Responsabilidad | Implementación típica |
|------------|-----------------|------------------------|
| **App Cliente (Flutter móvil)** | UX del comensal: descubrir, reservar, pedir, pagar, calificar | Flutter + Dio (HTTP) + `web_socket_channel` (WS) + almacenamiento seguro del JWT (flutter_secure_storage) |
| **Panel Admin (Flutter Web)** | UX operativa del restaurante y super-admin | Flutter Web + Dio + `web_socket_channel`; roles derivan vistas |
| **API FastAPI** | Toda la lógica de negocio + auth + realtime + integraciones | FastAPI + Uvicorn + SQLAlchemy 2.0 + Alembic + Pydantic v2 |
| **AuthService** | Emisión/validación de JWT con claims `role` + `restaurant_id` | `python-jose` o `PyJWT`; `passlib[bcrypt]` para hashing |
| **TenantScope dependency** | Garantizar que toda query se filtre por `restaurant_id` del token (excepto super-admin/cliente) | Dependencia FastAPI inyectada en cada router staff |
| **PedidoService** | Máquina de estados del pedido + validaciones de transición | Service class con `state_machine` dict; transacciones DB atómicas |
| **MesaService** | Estados de mesa + conflictos de reserva (no overlap horario) | Service + constraint check antes de INSERT |
| **PagoService** | Crear intención de pago, validar webhook, reconciliar | Adapter pattern: `PagoGateway` abstracto + implementación concreta |
| **RealtimeHub** | Multiplexar conexiones WebSocket en rooms por restaurante | `ConnectionManager` in-memory: `dict[room_name -> set[WebSocket]]` |
| **MySQL** | Fuente de verdad transaccional | 1 schema shared, todas las tablas tenant-scoped con FK + índice |
| **Pasarela de pago** | Cobrar al cliente (tarjeta/PSE/Nequi) | REST + webhooks; idempotencia por referencia de pedido |

---

## Recommended Project Structure

### Backend FastAPI

```
backend/
├── app/
│   ├── main.py                    # FastAPI() + routers + CORS + lifespan
│   ├── core/
│   │   ├── config.py              # Settings (pydantic-settings) — DB URL, JWT secret, etc.
│   │   ├── database.py            # engine, SessionLocal, Base
│   │   ├── security.py            # hash, verify, create_jwt, decode_jwt
│   │   └── tenant.py              # TenantScope dependency (inyecta restaurant_id)
│   ├── deps/
│   │   ├── auth.py                # get_current_user, require_role(...)
│   │   └── db.py                  # get_db session
│   ├── models/                    # SQLAlchemy ORM (1 archivo por agregado)
│   │   ├── user.py
│   │   ├── restaurant.py
│   │   ├── mesa.py
│   │   ├── menu.py                # categoria + producto
│   │   ├── reserva.py
│   │   ├── pedido.py              # pedido + pedido_item
│   │   ├── pago.py
│   │   └── calificacion.py
│   ├── schemas/                   # Pydantic v2 (request/response DTOs)
│   │   └── (espejo de models)
│   ├── services/                  # Lógica de negocio (casos de uso)
│   │   ├── auth_service.py
│   │   ├── mesa_service.py        # state machine de mesa
│   │   ├── pedido_service.py      # state machine de pedido
│   │   ├── reserva_service.py     # validación de overlap
│   │   ├── pago_service.py        # adapter a pasarela
│   │   └── realtime.py            # ConnectionManager (rooms)
│   ├── routers/                   # Capa HTTP (thin)
│   │   ├── auth.py
│   │   ├── public.py              # lista restaurantes, menú público
│   │   ├── cliente.py             # reservas, pedidos, pagos, calif.
│   │   ├── staff.py               # gestión restaurante (mesero/cocina/admin)
│   │   ├── admin_gri.py           # super-admin
│   │   └── ws.py                  # WebSocket endpoint
│   └── events.py                  # tipos de mensajes WS (enum)
├── alembic/                       # Migraciones versionadas
│   ├── env.py
│   └── versions/
├── seeds/
│   └── demo_restaurante.py        # Inserta restaurante + menú + mesas demo
├── tests/
├── Dockerfile
├── requirements.txt (o pyproject.toml)
└── alembic.ini
```

### Frontend (monorepo Flutter, 2 apps)

```
frontend/
├── cliente_app/                   # App móvil
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/                  # api_client, ws_client, auth_storage
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── discover/          # lista restaurantes
│   │   │   ├── menu/
│   │   │   ├── reserva/
│   │   │   ├── pedido/            # carrito + armar pedido
│   │   │   ├── pago/
│   │   │   └── qr_scan/           # escanear QR de mesa
│   │   └── shared/                # widgets, theme, router (go_router)
│   └── pubspec.yaml
└── admin_panel/                   # App web
    ├── lib/
    │   ├── main.dart
    │   ├── core/                  # api_client, ws_client, role_guard
    │   ├── features/
    │   │   ├── auth/
    │   │   ├── dashboard/         # estadísticas
    │   │   ├── mapa_mesas/        # grid de mesas con estados
    │   │   ├── pedidos/           # cola de cocina en vivo
    │   │   ├── reservas/
    │   │   ├── menu_admin/
    │   │   ├── clientes/
    │   │   ├── reportes/
    │   │   ├── configuracion/
    │   │   └── gri_admin/         # solo super-admin: crear restaurantes
    │   └── shared/
    └── pubspec.yaml
```

### Infraestructura

```
infra/
├── docker-compose.yml             # mysql + api + migrate + seed
├── docker-compose.prod.yml        # override: servidor Ubuntu, sin puertos DB expuestos
├── mysql/
│   ├── conf.d/my.cnf              # charset utf8mb4, timezone
│   └── init/                      # (opcional) scripts de init
└── nginx/                         # (prod) TLS + reverse proxy + WS upgrade
```

### Structure Rationale

- **`routers/` delgado, `services/` con la lógica:** los routers solo parsean request, llaman al servicio y arman response. Esto permite testear servicios sin HTTP y reutilizarlos desde WebSockets.
- **`models/` separado de `schemas/`:** los ORM models representan la BD; los Pydantic schemas son el contrato HTTP. Mezclarlos acopla migraciones a la API.
- **`core/tenant.py` como dependencia global para staff:** evita el error #1 de multi-tenant (olvidar el `WHERE restaurant_id = ?`). Un solo punto de verdad.
- **`services/realtime.py` aislado:** el `ConnectionManager` es independiente de HTTP/WS; cualquier servicio puede emitir un evento sin saber quién escucha.
- **2 apps Flutter en monorepo:** comparten `core/` (api_client, ws_client) vía path dependency o package local, pero tienen árboles de features distintos. Evita duplicar DTOs y lógica de red.
- **`seeds/` como script idempotente:** cada ejecución deja la BD en estado conocido (upsert del demo). Crítico para desarrollo y para smoke-tests post-deploy.

---

## Architectural Patterns

### Pattern 1: Multi-tenant con **shared DB + `restaurant_id`** (recomendado)

**What:** Una sola base de datos MySQL. Toda tabla con datos de tenant lleva una FK `restaurant_id`. El aislamiento es lógico (a nivel de fila), no físico.

**When to use:** GRI — muchos tenants pequeños (restaurantes), datos modestos por tenant, necesidad de migraciones y backups simples, super-admin que ve todo.

**Trade-offs:**
- ✅ Migraciones una sola vez (Alembic sobre 1 schema).
- ✅ Backups, monitoreo, conexión: una sola pieza.
- ✅ Joins cross-tenant triviales para reportes GRI (super-admin).
- ✅ Operacionalmente simple en Docker Compose.
- ❌ Riesgo de leak cross-tenant si una query olvida el `WHERE restaurant_id = ?` → **mitigado por `TenantScope` dependency**.
- ❌ No hay aislamiento de performance entre tenants ruidosos y silenciosos (aceptable para la escala de GRI).

**Veredicto:** **RECOMENDADO.** Las alternativas (schema/database por tenant) en MySQL implican administrar N bases de datos, N conjuntos de migraciones, y backup/restore por tenant — costos operacionales altos sin beneficio para GRI v1.

**Implementación del scope:**

```python
# app/core/tenant.py
from fastapi import Depends, HTTPException, status
from app.deps.auth import CurrentUser

class TenantContext:
    """Inyecta el restaurant_id aplicable según el rol del usuario."""
    def __init__(self, restaurant_id: int | None, is_super_admin: bool):
        self.restaurant_id = restaurant_id
        self.is_super_admin = is_super_admin

def get_tenant_ctx(user: CurrentUser) -> TenantContext:
    # super-admin: sin filtro (ve todos)
    if user.role == "super_admin":
        return TenantContext(None, True)
    # staff: amarrado al restaurante del token
    if user.restaurant_id is None:
        raise HTTPException(403, "Staff sin restaurante asignado")
    return TenantContext(user.restaurant_id, False)
    # cliente: restaurant_id NO viene del token; se toma del contexto
    # del recurso (ej. la mesa escaneada). Se maneja en el router.
```

```python
# app/services/mesa_service.py
def listar_mesas(db: Session, ctx: TenantContext) -> list[Mesa]:
    q = db.query(Mesa)
    if not ctx.is_super_admin:
        q = q.filter(Mesa.restaurant_id == ctx.restaurant_id)
    return q.all()
```

**Anti-pattern que esto previene:** "staff del restaurante A ve las mesas del restaurante B porque alguien hizo `db.query(Mesa).all()` sin filtro."

---

### Pattern 2: **JWT único, multi-rol, claims `role` + `restaurant_id`**

**What:** Un solo emisor de JWT (un endpoint `/auth/login`), un solo secreto. El token lleva `role` (uno de 5 valores) y `restaurant_id` (nullable para cliente y super-admin).

**When to use:** Siempre — es la única auth del sistema.

**Trade-offs:**
- ✅ Un solo flujo de login, una sola validación.
- ✅ Los claims viajan sin round-trip a DB.
- ❌ No hay revocación instantánea sin denylist (aceptable para v1; mitigar con TTL corto + refresh token).

**Estructura del payload:**

```json
{
  "sub": "42",                          // user_id
  "email": "mesero@elcarbon.com",
  "role": "mesero",                     // super_admin | admin_restaurante | mesero | cocina | cliente
  "restaurant_id": 7,                   // null para cliente y super_admin
  "exp": 1735689600,
  "iat": 1735603200
}
```

**Reglas de autorización (matriz rol × endpoint):**

| Recurso | super_admin | admin_restaurante | mesero | cocina | cliente |
|---------|:-----------:|:-----------------:|:------:|:------:|:-------:|
| Crear restaurante (GRI) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gestionar su restaurante (CRUD mesas/menú) | ✅ (todos) | ✅ (solo el suyo) | ❌ | ❌ | ❌ |
| Ver cola de pedidos (cocina) | ✅ | ✅ | lectura | ✅ | ❌ |
| Atender mesas / marcar limpieza | ✅ | ✅ | ✅ | ❌ | ❌ |
| Reservar / pedir / pagar | ❌ | ❌ | ❌ | ❌ | ✅ |
| Leer menú público | ✅ | ✅ | ✅ | ✅ | ✅ |

**Implementación del guard:**

```python
# app/deps/auth.py
def require_role(*roles: str):
    def _dep(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(403, f"Role {user.role} no autorizado")
        return user
    return _dep

# Uso en router:
@router.post("/mesas", dependencies=[Depends(require_role("admin_restaurante", "super_admin"))])
def crear_mesa(...): ...
```

**Nota sobre cliente:** el cliente NO tiene `restaurant_id` en el token porque puede ir a cualquier restaurante. El tenant se deriva del recurso que toca (la mesa que escaneó, la reserva que hace). Esto evita reemitir token cada vez que entra a otro local.

---

### Pattern 3: **WebSocket con rooms por restaurante** (`ConnectionManager` in-memory)

**What:** Un endpoint único `/ws?token=JWT`. Al conectar, el servidor decodifica el JWT, identifica `restaurant_id`, y une el socket a un "room" denominado `restaurant:{id}`. Los eventos se publican al room y todos los sockets conectados lo reciben.

**When to use:** Para tiempo real dentro de un restaurante (cocina ve pedidos, dashboard ve estados de mesa, cliente ve su pedido).

**Trade-offs:**
- ✅ Patrón nativo de FastAPI (verificado en docs oficiales — `ConnectionManager` con `active_connections`).
- ✅ Sin dependencias externas en v1.
- ✅ Filtrado natural por tenant: un cliente del restaurante A nunca recibe eventos del B porque está en otro room.
- ❌ Solo funciona con **1 worker de Uvicorn**. Para escalar horizontalmente (>1 worker, >1 contenedor) se necesita un broker **Redis Pub/Sub** (ver Scaling). Para GRI v1 con Docker Compose y un solo contenedor API, esto es perfecto.

**Implementación:**

```python
# app/services/realtime.py
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.rooms: dict[str, set[WebSocket]] = {}   # "restaurant:7" -> {ws, ws, ...}

    async def connect(self, ws: WebSocket, room: str):
        await ws.accept()
        self.rooms.setdefault(room, set()).add(ws)

    def disconnect(self, ws: WebSocket, room: str):
        self.rooms.get(room, set()).discard(ws)

    async def broadcast(self, room: str, message: dict):
        dead = []
        for ws in self.rooms.get(room, set()):
            try:
                await ws.send_json(message)
            except RuntimeError:
                dead.append(ws)
        for ws in dead:
            self.rooms[room].discard(ws)

manager = ConnectionManager()
```

```python
# app/routers/ws.py
@router.websocket("/ws")
async def ws_endpoint(websocket: WebSocket, token: str = Query(...)):
    try:
        payload = decode_jwt(token)
    except Exception:
        await websocket.close(code=1008)  # policy violation
        return

    room = f"restaurant:{payload['restaurant_id']}" if payload.get("restaurant_id") else f"user:{payload['sub']}"
    await manager.connect(websocket, room)
    try:
        while True:
            await websocket.receive_text()  # cliente puede enviar pings
    except WebSocketDisconnect:
        manager.disconnect(websocket, room)
```

**Tipos de evento (enum compartido frontend/backend):**

```python
# app/events.py
class EventType:
    PEDIDO_NUEVO      = "pedido:nuevo"        # cocina
    PEDIDO_ESTADO     = "pedido:estado"       # cliente + dashboard
    MESA_ESTADO       = "mesa:estado"         # dashboard
    CUENTA_SOLICITADA = "cuenta:solicitada"   # mesero
    PAGO_CONFIRMADO   = "pago:confirmado"     # cliente + cocina + dashboard
```

**Mensaje típico (broadcast al room del restaurante):**

```json
{"type": "pedido:estado", "pedido_id": 1023, "estado": "en_preparacion", "ts": "2026-08-13T19:42:00"}
```

---

### Pattern 4: **QR estable por mesa** (recomendado para v1)

**What:** Cada mesa tiene un `codigo` persistente (ej. `GRI-MESA-001` o un hash corto `M_a8f3k2`). El QR codifica una URL `https://gri.com/m/{codigo}` (o deep link Flutter `gri://mesa/{codigo}`). El código **no rota**.

**When to use:** Siempre en v1.

**Trade-offs vs token efímero (rotativo):**

| Criterio | QR estable ✅ | Token efímero ❌ |
|----------|:--------------:|:------------------:|
| Reimpresión | Una vez, lamina y listo | Periódica (operativo pesado) |
| Seguridad | QR no es el boundary (lo es el JWT) | Teóricamente más seguro |
| Implementación | Trivial | Compleja (rotación, invalidación) |
| Screenshot fraude | Posible pero inútil sin login | Mitigado |

**Por qué el QR estable es suficiente:** la auth es **obligatoria**. El QR solo identifica la mesa; para pedir, el cliente debe loguearse. El risk boundary es el JWT, no el QR. Un atacante con screenshot del QR igual necesita una cuenta cliente válida para hacer algo.

**Token efímero para v2 (defer):** sesión corta (ej. 2h) amarrada a `mesa_id + cliente_id`, emitida al "sentarse". Útil para invalidez post-pago y anti-replay. No necesario para v1.

**Implementación:**

```python
# models/mesa.py
class Mesa(Base):
    __tablename__ = "mesa"
    id            = Column(Integer, primary_key=True)
    restaurant_id = Column(Integer, ForeignKey("restaurant.id"), nullable=False, index=True)
    codigo        = Column(String(32), nullable=False)  # "GRI-MESA-001" o hash
    capacidad     = Column(Integer, nullable=False)
    posicion_x    = Column(Integer, default=0)          # para mapa visual
    posicion_y    = Column(Integer, default=0)
    estado        = Column(Enum("disponible","reservada","ocupada","limpieza"), default="disponible")
    __table_args__ = (UniqueConstraint("restaurant_id", "codigo", name="uq_mesa_rest_codigo"),)
```

El endpoint público `GET /m/{codigo}` devuelve `{mesa_id, restaurant_id, restaurant_nombre}` — el cliente luego decide reservar/pedir con su JWT.

---

### Pattern 5: **State machines explícitas** (mesa y pedido)

**What:** Estados y transiciones permitidas modelados como código, no como strings sueltos. Cualquier transición ilegal levanta error.

**Mesa state machine:**

```
                  reserva creada
        ┌──────────────────────────────┐
        ▼                              
   ┌──────────┐  cliente escanea QR   ┌──────────┐
   │disponible├──────────────────────►│ ocupada  │
   └──────────┘                        └────┬─────┘
        ▲                                   │
        │ mesero confirma limpieza          │ cuenta pagada / mesa liberada
        │                                   ▼
   ┌──────────┐                        ┌──────────┐
   │ limpieza │◄───────────────────────│ (ciclo)  │
   └──────────┘                        └──────────┘
        ▲                                   
        │ reserva expira / cancela           
   ┌──────────┐                             
   │reservada │◄── disponible (reserva confirmada)
   └──────────┘   ─► ocupada (cliente llega)
```

Transiciones válidas: `disponible→reservada`, `disponible→ocupada`, `reservada→ocupada`, `reservada→disponible` (expira/cancela), `ocupada→limpieza`, `limpieza→disponible`. Cualquier otra → 409 Conflict.

**Pedido state machine:**

```
borrador ──enviar──► enviado ──cocina acepta──► aceptado ──inicia prep──► en_preparacion
                        │                                                     │
                        │ cocina rechaza                                      │ mesero entrega
                        ▼                                                     ▼
                    rechazado                                              servido
                                                                              │
                                                                              │ pago confirmado
                                                                              ▼
                                                                           pagado
```

Transiciones: `borrador→enviado`, `enviado→aceptado|rechazado`, `aceptado→en_preparacion`, `en_preparacion→servido`, `servido→pagado`. Estados terminales: `rechazado`, `pagado`.

**Implementación:**

```python
# services/pedido_service.py
PEDIDO_TRANSITIONS = {
    "borrador":       {"enviado"},
    "enviado":        {"aceptado", "rechazado"},
    "aceptado":       {"en_preparacion"},
    "en_preparacion": {"servido"},
    "servido":        {"pagado"},
    "rechazado":      set(),
    "pagado":         set(),
}

def transicionar(db: Session, pedido_id: int, nuevo_estado: str, ctx: TenantContext):
    pedido = get_pedido_or_404(db, pedido_id, ctx)
    if nuevo_estado not in PEDIDO_TRANSITIONS.get(pedido.estado, set()):
        raise HTTPException(409, f"Transición {pedido.estado}→{nuevo_estado} no permitida")
    pedido.estado = nuevo_estado
    db.commit()
    # Emitir evento WS a cocina + cliente
    asyncio.create_task(manager.broadcast(
        f"restaurant:{ctx.restaurant_id}",
        {"type": "pedido:estado", "pedido_id": pedido_id, "estado": nuevo_estado}
    ))
    return pedido
```

**Beneficio:** imposible dejar la BD en estado inconsistente por un bug simple; los tests de transición son triviales.

---

## Data Flow

### Request Flow — Cliente arma un pedido (caso más completo)

```
[Cliente en la mesa]
    │ 1. Escanea QR (código "GRI-MESA-001")
    ▼
[App Flutter] ──GET /m/GRI-MESA-001──► [API] ─► [MesaService] ─► [MySQL]
    │ 2. App recibe {mesa_id, restaurant_id}                  ◄── devuelve mesa+restaurante
    │ 3. Cliente se loguea (si no lo estaba) → obtiene JWT
    │ 4. GET /cliente/menu?restaurant_id=7 → ve productos
    │ 5. Arma carrito (borrador en app)
    │ 6. POST /cliente/pedidos  {mesa_id, items:[...]}
    ▼
[API /cliente/pedidos]
    ├─ [AuthService] valida JWT, extrae user_id (cliente)
    ├─ [TenantScope] NO aplica (cliente cross-tenant); restaurant_id viene del body/mesa
    ├─ [PedidoService.crear()]
    │     ├─ valida mesa pertenece a restaurant_id y está ocupada
    │     ├─ valida productos existen y están disponibles
    │     ├─ calcula total; crea pedido (estado="enviado") + pedido_items
    │     ├─ [MySQL] INSERT en transacción
    │     └─ [RealtimeHub] broadcast "pedido:nuevo" → room restaurant:7
    ▼
[WebSocket cocina (admin panel) recibe "pedido:nuevo"]
    │ 7. Cocina cambia estado: PATCH /staff/pedidos/1023/estado {estado:"aceptado"}
    ▼
[PedidoService.transicionar] → MySQL UPDATE → WS broadcast "pedido:estado"
    ▼
[App cliente recibe "pedido:estado" via WS] → UI actualiza
    │ ... cocina prepara, mesero sirve, estados avanzan ...
    │ 8. Cliente toca "Pagar" → POST /cliente/pagos {pedido_id, metodo}
    ▼
[PagoService] → crea intención en pasarela → devuelve URL/redirect
    │ 9. Pasarela confirma (webhook) → POST /webhooks/pago
    ▼
[PagoService.confirmar()] → pedido.estado="pagado" → WS "pago:confirmado"
    │ 10. Mesa pasa a "limpieza" → WS "mesa:estado"
    ▼
[Dashboard admin actualiza mapa de mesas automáticamente]
```

### State Management — Frontend

```
[JWT] ──persist──► flutter_secure_storage (móvil) / sessionStorage (web)
    │
[ApiService (Dio)]
    ├─ Authorization: Bearer <jwt> en cada request
    └─ 401 → intenta refresh → si falla, logout
    │
[WsService (web_socket_channel)]
    ├─ Conecta con ?token=<jwt>
    ├─ Reconnect con backoff
    └─ Stream de eventos → Riverpod/Bloc providers
    │
[State (Riverpod recomendado)]
    ├─ authProvider (user, role, restaurant_id)
    ├─ pedidoEnVivoProvider (escucha WS "pedido:estado")
    ├─ mapaMesasProvider (escucha WS "mesa:estado")  [admin panel]
    └─ colaCocinaProvider (escucha WS "pedido:nuevo"|"pedido:estado")  [admin panel]
```

### Key Data Flows

1. **Flujo de auth:** login → JWT firmado → cliente/staff lo guarda → cada request/WS lo presenta → middleware valida → inyecta `CurrentUser` → `TenantScope` derivado.
2. **Flujo de tenant-scoping:** router staff recibe `TenantContext` vía `Depends(get_tenant_ctx)` → lo pasa al servicio → servicio añade `.filter(restaurant_id == ctx.restaurant_id)` a TODA query. Cliente omite este flow (restaurant_id viene del recurso).
3. **Flujo de evento WS:** mutación DB exitosa → servicio llama `manager.broadcast(room, event)` → todos los sockets del room reciben → frontend actualiza providers. **Una sola fuente de emisión** (el servicio), nunca el router directo.
4. **Flujo de pago:** pedido en estado `servido` → cliente initicia pago → API crea intención en pasarela → pasarela webhook → API confirma → pedido `pagado` + mesa `limpieza` → WS broadcast.
5. **Flujo de super-admin GRI:** super-admin no tiene `restaurant_id` → todas las queries son sin filtro → `POST /admin-gri/restaurantes` crea nuevo tenant → seed opcional.

---

## Scaling Considerations

| Escala | Ajuste arquitectónico |
|--------|-----------------------|
| **0–10 restaurantes, 1–100 concurrentes** | **Monolito FastAPI + 1 worker + `ConnectionManager` in-memory + 1 contenedor MySQL.** Docker Compose en Ubuntu Server. Es lo que v1 necesita. Sin Redis, sin cache, sin replicas. |
| **10–100 restaurantes, 100–1k concurrentes** | Añadir: cache Redis (menús públicos, sesiones), Nginx/Caddy con TLS y WS upgrade, `--workers 2-4` con Redis Pub/Sub para sincronizar WebSockets entre workers, índices compuestos en `(restaurant_id, estado, fecha)` en pedidos/reservas. |
| **100+ restaurantes, 1k+ concurrentes** | Separar lectura/escritura (read replicas MySQL), sharding por `restaurant_id` si un tenant es gigante, mover realtime a servicio dedicado (Socket.IO cluster o nativo con Redis Streams), CDN para imágenes de menú, colas (Celery/RQ) para webhooks de pago y reportes pesados. |

### Scaling Priorities

1. **Primer bottleneck (en v1 real, no ahora):** conexiones WebSocket en un solo proceso Uvicorn. Cada conexión viva consume memoria y bloquea un slot del event loop. Síntoma: latencia en broadcast cuando hay >500 sockets activos. **Fix cuando llegue el momento:** Redis Pub/Sub + `--workers N` (cada worker mantiene sus sockets, Redis distribuye los mensajes entre workers).

2. **Segundo bottleneck:** queries de mapa de mesas y cola de cocina polled con frecuencia por dashboards abiertos. **Fix:** ya mitigado con WebSockets (push en lugar de poll). Si persiste, cache L1 en memoria del panel por 1–2s.

3. **Lo que NO escalar en v1:** DB (MySQL maneja decenas de miles de pedidos sin sudar), API (FastAPI/uvicorn sirve miles de RPS por contenedor), pasarela (la escala es problema del proveedor).

**Filosofía:** no escalar anticipadamente. La arquitectura monolítica modular permite extraer servicios luego sin reescribir — los `services/` son boundaries naturales.

---

## Anti-Patterns

### Anti-Pattern 1: Olvidar `WHERE restaurant_id = ?` (leak cross-tenant)

**What people do:** `db.query(Mesa).all()` directamente en un router staff.
**Why it's wrong:** devuelve las mesas de TODOS los restaurantes. El mesero del restaurante A ve la operación del B.
**Do this instead:** toda query en servicios staff pasa por `TenantContext` que añade el filtro. Tests de integración con 2 restaurantes que verifiquen aislamiento.

### Anti-Pattern 2: Schema por tenant en MySQL

**What people do:** crear una database por restaurante (`gri_restaurante_7`, `gri_restaurante_8`...).
**Why it's wrong:** MySQL no tiene schemas lógicos separados de databases (como sí Postgres). Terminas administrando N bases, N migraciones, N connection pools. Operacionalmente carísimo sin beneficio real a esta escala.
**Do this instead:** shared DB + `restaurant_id`. Si en el futuro un tenant es gigante, *entonces* extrae su database (hybrid approach) — caso excepcional.

### Anti-Pattern 3: Polling HTTP para "tiempo real"

**What people do:** el panel admin hace `setInterval(() => fetch("/staff/mesas"), 2000)`.
**Why it's wrong:** carga innecesaria en servidor, latencia de hasta 2s, batería móvil muerta.
**Do this instead:** WebSocket con push. El servidor emite cuando hay cambio; el cliente solo escucha.

### Anti-Pattern 4: Lógica de negocio en routers

**What people do:** el router hace el INSERT, valida el estado, llama al WS, todo inline.
**Why it's wrong:** no se puede testear sin levantar HTTP, no se puede reutilizar desde WS o CLI (seeds, migraciones de datos), duplicación.
**Do this instead:** router delgado → servicio. El servicio es el único que toca DB y emite eventos WS.

### Anti-Pattern 5: Estado de pedido como string libre

**What people do:** `pedido.estado = "preparandose"` (typo) o `"preparando"` vs `"en_preparacion"` inconsistente.
**Why it's wrong:** bugs silenciosos, queries que no matchean, dashboards que no actualizan.
**Do this instead:** `Enum` en MySQL + `PEDIDO_TRANSITIONS` dict en Python. Solo transiciones declaradas son válidas; cualquier otra es 409.

### Anti-Pattern 6: Auth del cliente sin JWT (confiar solo en QR)

**What people do:** "el cliente escaneó el QR, entonces es legítimo, déjalo pedir".
**Why it's wrong:** el QR es reutilizable y compartible; sin auth no hay forma de asociar pedido a persona, ni evitar abuso, ni cobrar.
**Do this instead:** auth obligatoria (decisión del proyecto). QR solo identifica la mesa; JWT identifica a la persona.

### Anti-Pattern 7: Múltiples secrets JWT por rol

**What people do:** un secreto distinto para cliente, otro para staff.
**Why it's wrong:** complejidad innecesaria, bugs de validación, no aporta seguridad real.
**Do this instead:** un solo secreto, claims `role` + `restaurant_id`. La autorización se hace por el `role` del claim, no por qué secreto firmó.

---

## Integration Points

### External Services

| Servicio | Patrón de integración | Notas / gotchas |
|----------|----------------------|-----------------|
| **Pasarela de pago (Wompi / PayU / ePayco)** | REST crear intención → redirect/iframe cliente → **webhook** asíncrono al backend para confirmar | Webhooks pueden duplicarse → **idempotencia** por `referencia` (= pedido_id). Validar firma del webhook. Nunca confiar solo en el redirect del cliente (front-channel); siempre confirmar via webhook. La pasarela concreta se elige en su fase. |
| **Almacenamiento de imágenes de menú** | Subir a volumen Docker local (v1) o S3-compatible (v2); URL pública guardada en `producto.imagen_url` | En v1, `StaticFiles` de FastAPI sirve las imágenes desde `/media`. Migración a S3/MinIO es trivial (solo cambia la URL). |
| **SMTP (opcional, recuperación de password)** | SMTP relay o servicio transaccional (Resend, SendGrid) | Out of scope para v1 si no se incluye recovery; si se incluye, el flujo estándar de token de un solo uso (TTL 15 min). |

### Internal Boundaries

| Boundary | Comunicación | Notas |
|----------|-------------|-------|
| **App Cliente ↔ API** | REST + WebSocket | JWT Bearer. WS para estados en vivo, REST para todo lo demás. |
| **Panel Admin ↔ API** | REST + WebSocket | Mismo protocolo; las vistas cambian por rol. |
| **API ↔ MySQL** | TCP (SQLAlchemy + PyMySQL o asyncmy) | Pool de conexiones; charset `utf8mb4` obligatorio (emojis, acentos). |
| **API ↔ Pasarela pago** | HTTPS REST + Webhook entrante | El webhook entrante debe validar IP/firma. |
| **Servicio ↔ RealtimeHub** | Llamada directa (in-process) | El servicio emite evento → hub broadcast. En v1 es función local; si se extrae el hub a otro proceso, cambiar a Redis Pub/Sub sin tocar servicios. |

---

## Modelos de Datos — Visión consolidada

> Detalle completo de tablas y columnas se decide en la fase de planificación. Aquí el panorama para que el roadmap sepa dependencias.

```
restaurant (1) ──< mesa (N)
restaurant (1) ──< categoria (1) ──< producto (N)
restaurant (1) ──< reserva (N) >── mesa (1)
restaurant (1) ──< pedido (N) >── mesa (1)
pedido (1) ──< pedido_item (N) >── producto (1)
pedido (1) ──< pago (N o 1)
pedido (1) ──< calificacion (0..1) >── usuario (1)

usuario (global) ──< usuario_restaurante (N) >── restaurant (1)   # staff roles
usuario (1) ──< reserva (N)        # como cliente
usuario (1) ──< pedido (N)         # como cliente
usuario (1) ──< calificacion (N)   # como cliente
```

**Tablas y su tenant-scoping:**

| Tabla | Tenant-scoped (`restaurant_id`)? | Nota |
|-------|:--------------------------------:|------|
| `usuario` | ❌ (global) | Un usuario puede ser cliente en cualquier restaurante |
| `usuario_restaurante` | ✅ (la FK es el restaurant) | Define staff (mesero/cocina/admin) |
| `restaurant` | — (es el tenant raíz) | Solo super-admin crea |
| `mesa`, `categoria`, `producto`, `reserva`, `pedido`, `pedido_item`, `pago`, `calificacion` | ✅ | Todas con FK + índice compuesto `(restaurant_id, ...)` |

---

## Suggested Build Order (implicaciones para roadmap)

El orden below refleja **dependencias técnicas** — cada fase necesita lo anterior.

1. **Foundation / infraestructura** — Docker Compose (mysql + api skeleton + Alembic + healthcheck). Sin esto no corre nada.
   - *Bloquea:* todo lo demás.

2. **Auth + núcleo multi-tenant** — modelos usuario/restaurant/usuario_restaurante, JWT, `TenantScope`, middleware de roles.
   - *Bloquea:* cualquier endpoint staff.
   - *Evita pitfall:* leak cross-tenant (#1).

3. **Modelo de dominio + seed demo** — migración crea mesa/categoria/producto/reserva/pedido/pago/calificacion; seed inserta restaurante demo con menú y mesas.
   - *Permite:* ver datos end-to-end sin UI.
   - *Desbloquea:* todas las features.

4. **Panel Admin: solo lectura + mapa de mesas** — dashboard y mapa consumiendo datos sembrados. Validación visual temprana de la identidad (colores del mockup).
   - *Permite:* confirmar que la capa de datos + auth staff funciona.

5. **App Cliente: discover + menú (read-only)** — lista restaurantes, ver menú. Login cliente. Sin reservas ni pedidos aún.
   - *Permite:* validar Flutter móvil + JWT cliente + API pública.

6. **Reservas + QR de mesa** — cliente reserva mesa; escanea QR; mesero/admin gestiona reservas en panel.
   - *Depende de:* modelos mesa+reserva (fase 3).

7. **Pedidos (REST, sin WS todavía)** — cliente arma carrito, envía pedido; cocina cambia estados via REST. State machine del pedido.
   - *Depende de:* mesa ocupada (fase 6).
   - *Sin WS:* cocina hace refresh manual o poll corto. Funcional pero no óptimo.

8. **WebSockets — tiempo real** — `ConnectionManager`, rooms por restaurante, eventos. Cocina ve pedidos al instante; cliente sigue su pedido; dashboard actualiza solo.
   - *Convierte:* lo funcional en lo que el usuario pidió explícitamente.
   - *Evita pitfall:* polling (#3).

9. **Panel Admin: escritura completa** — CRUD mesas, gestión menú (productos/categorias), gestión reservas, clientes, reportes básicos, configuración.
   - *Depende de:* todo el modelo + auth + (idealmente) WS para feedback.

10. **Pago en línea + cuenta** — integración pasarela colombiana (elegir en su fase), webhook, flujo cuenta→pago, mesa a limpieza al confirmar.
    - *Depende de:* pedido en estado `servido`.
    - *Investigación adicional:* pasarela concreta (Wompi vs PayU vs ePayco) — su propia fase.

11. **Calificaciones + reportes + polish** — cliente califica post-pago; reportes de ventas; ajustes de UX; hardening (rate-limit, logs, backups).
    - *Cierre del milestone.*

**Phases que probablemente necesiten más research:**
- **Fase 8 (WebSockets):** validar patrón de reconexión en Flutter (`web_socket_channel` vs alternativas), manejo de eventos perdidos offline.
- **Fase 10 (Pago):** comparativa Wompi vs PayU vs ePayco, requisitos de KYC, webhooks en Colombia.
- **Fase 3 (Modelo):** decisiones finas de índices para queries de mapa de mesas y cola de cocina.

**Phases con patrón estándar (poco research):**
- Foundation, Auth, Pedidos REST, Panel CRUD — son patrones FastAPI/SQLAlchemy bien documentados.

---

## Sources

- **FastAPI WebSockets (oficial)** — https://fastapi.tiangolo.com/advanced/websockets/ — patrón `ConnectionManager` con `active_connections` y nota explícita sobre limitación a 1 proceso (recomienda Redis/PostgreSQL broadcaster para escalar). **HIGH confidence.**
- **FastAPI Security: OAuth2 with JWT (oficial)** — https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/ — patrón estándar de emisión y validación JWT con `python-jose`/`passlib`. **HIGH confidence.**
- **FastAPI Bigger Applications (oficial)** — https://fastapi.tiangolo.com/tutorial/bigger-applications/ — estructura por routers/APIRouter que justifica `routers/` separados. **HIGH confidence.**
- **encode/broadcaster** — https://github.com/encode/broadcaster — referenced por FastAPI para multi-proceso WS vía Redis/Postgres Pub/Sub. **HIGH confidence** (autoridad del mismo ecosistema).
- **Multi-tenant SaaS patterns (conocimiento de dominio consolidado)** — shared-DB + tenant_id como patrón dominante para SaaS multi-tenant small-data; ampliamente documentado en literatura de arquitectura (AWS SaaS Factory, Microsoft SaaS patterns). **HIGH confidence** (patrón estándar de la industria desde hace 10+ años).
- **State machine pattern** — patrón universal de dominio; verificado contra prácticas estándar en servicios de pedidos (Shopify, Square, pedidos-y-commerce OSS). **HIGH confidence.**
- **Pasarelas colombianas** — Wompi (Bancolombia), PayU, ePayco son las tres opciones estándar en Colombia para pagos online; la elección concreta se difiere a su fase. WebFetch a `docs.wompi.co` devolvió 403 (anti-bot) — no afecta el patrón arquitectónico (REST + webhook + idempotencia es común a las tres). **MEDIUM confidence** en detalles específicos; **HIGH** en el patrón de integración.

---

*Architecture research for: Multi-tenant restaurant management & reservation platform (GRI)*
*Researched: 2026-08-13*
