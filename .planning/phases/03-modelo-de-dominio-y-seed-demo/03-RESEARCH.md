# Phase 3: Modelo de Dominio y Seed Demo - Research

**Researched:** 2026-08-13
**Domain:** SQLAlchemy 2.0 async domain models (9 tablas MySQL 8.4) + state machines explícitas (Enum + dict de transiciones) + seed demo idempotente gateado por DEMO_MODE + Alembic migration 0002
**Confidence:** HIGH (cero dependencias nuevas; todos los patrones ya implementados y verificados en el repo — Alembic async, models, lifespan bootstrap, conftest. El único punto MEDIUM es el detalle DDL del unique-parcial de `sesion_mesa`)

---

## Summary

Phase 3 construye la capa de datos de negocio completa sobre la que descansan TODAS las fases 4-9, sin crear un solo endpoint. Sobre la base de Phase 2 (Restaurante/Usuario + Alembic async + TenantScope), esta fase añade: (1) **9 tablas de dominio** — mesa, categoria, producto, pedido, pedido_item, reserva, sesion_mesa, pago, calificacion — todas tenant-scoped con `restaurant_id` FK + índices compuestos `(restaurant_id, ...)`; (2) **state machines explícitas** como módulo puro (`app/core/state_machines.py`): Enums de estado en los models + dicts `MESA_TRANSITIONS`/`PEDIDO_TRANSITIONS`/`RESERVA_TRANSITIONS`/`PAGO_TRANSITIONS` + función `validar_transicion()` que lanza `TransicionInvalidaError` (Phase 5/6 la traducen a 409); (3) **migración 0002** escrita a mano (precedente 0001) con todas las tablas, constraints con nombre explícito y orden FK-dependiente; y (4) **seed demo idempotente** (`app/services/seed_service.py`) gateado por `settings.DEMO_MODE` (ya existe en config desde Phase 1, inert), corrido en lifespan después de `ensure_super_admin`, con restaurante + staff + 8 mesas con QR `GRI-MESA-001..008` + 4 categorías + ~16 productos COP + 2 clientes demo.

Dos verificaciones de código de esta sesión cambian el alcance percibido: **el Dockerfile CMD ya ejecuta `alembic upgrade head` en cada boot** (Phase 2 lo implementó) — la mitad de INFR-03 ya está hecha, solo falta el seed en lifespan. Y **los tests existentes corren en host contra el stack Docker vía HTTP** — para testear constraints y seed sin endpoints hace falta un fixture `db_session` nuevo en conftest (conexión asyncmy directa a localhost:3306), que es el único Wave 0 de infraestructura de testing.

**Decisiones clave que esta research prescribe** (dentro de la discreción del researcher, con evidencia): `codigo_qr` **único GLOBAL** (el success criterion 3 de la fase es explícito: "impide que dos mesas compartan código — constraint en BD", y MESA-02 dice "código QR único"; el unique por-restaurante de ARCHITECTURE Pattern 4 queda subordinado al criterio de la fase) + `numero` único por restaurante como constraint separado. **Una sola migración 0002** con las 9 tablas (cohesión — deshacer/auditar es atómico). El unique de "una sesión activa por mesa" se implementa con la técnica MySQL estándar de **columna generada `activo_flag` + UNIQUE(mesa_id, activo_flag)** (MySQL no tiene partial indexes; las filas con NULL en cualquier columna del unique son ignoradas — cerradas→NULL, activas→1).

**Primary recommendation:** 7 archivos de models (mesa, menu, pedido, reserva, sesion_mesa, pago, calificacion) + `core/state_machines.py` puro + `services/seed_service.py` con get-or-create por natural key + migración 0002 a mano + 3 archivos de tests (unitarios de state machines sin infra, integración DB-directa para seed/constraints) + `scripts/verify_seed.sh` siguiendo el precedente de verify_auth.sh.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| **PLAT-04** | El sistema siembra un restaurante demo con menú, mesas y datos de ejemplo al inicializarse | `seed_service.seed_demo(session)` llamado desde lifespan tras `ensure_super_admin`, gateado por `settings.DEMO_MODE`. Idempotente por natural keys (nombre restaurante, email usuarios, codigo_qr mesas, nombre categorías/productos). Contenido: "Restaurante Demo GRI" + staff admin/mesero/cocina + 8 mesas GRI-MESA-001..008 + 4 categorías + ~16 productos COP + 2 clientes. |
| **MESA-02** | Cada mesa tiene un código QR único que la identifica (formato GRI-MESA-XXX o URL) | Columna `mesa.codigo_qr String(32) NOT NULL` con `UniqueConstraint` GLOBAL `uq_mesa_codigo_qr` (constraint en BD — success criterion 3). Seed genera `GRI-MESA-{n:03d}`. Helper `generar_codigo_qr()` para Phase 8 (max global + retry on IntegrityError). |
| **INFR-03** | Las migraciones (Alembic) y el seed demo se ejecutan como parte del despliegue | Mitad migraciones YA HECHA: Dockerfile CMD = `alembic upgrade head && uvicorn` (Phase 2, verificado en repo). Mitad seed: lifespan ejecuta `seed_if_demo_mode(session)` tras `ensure_super_admin` — automático en cada boot, idempotente. Verificación: `docker compose down -v && up` → demo data presente (verify_seed.sh). |
</phase_requirements>

<user_constraints>
## User Constraints

**No CONTEXT.md exists for this phase** (el directorio `03-*` estaba vacío). Las constraints vienen de decisiones project-level ya locked en ARCHITECTURE.md / PITFALLS.md / ROADMAP.md — esta research NO las re-abre.

### Locked Decisions (from ARCHITECTURE.md / PITFALLS.md / ROADMAP — immutable)
- **Multi-tenant: shared DB + `restaurant_id` en cada tabla de dominio + índices compuestos (restaurant_id, ...)** — sin schemas por tenant (ARCHITECTURE Pattern 1; ROADMAP notas de fase 3).
- **Mesa estados: disponible / reservada / ocupada / limpieza** con `MESA_TRANSITIONS` dict explícito (ARCHITECTURE Pattern 5).
- **Pedido estados: borrador→enviado→aceptado→en_preparacion→servido→pagado, con rechazado terminal** — `PEDIDO_TRANSITIONS` dict (ARCHITECTURE Pattern 5; PEDI-03).
- **QR estable por mesa (no efímero), formato GRI-MESA-XXX** (ARCHITECTURE Pattern 4; MESA-02). El token efímero/rotativo es v2 (OPER-04, Out of Scope).
- **Reserva estados: pendiente / confirmada / cancelada**; FK mesa + usuario (RESV-03).
- **Pago: idempotencia por referencia única + state machine propia (pendiente/aprobado/rechazado)** (ARCHITECTURE; PITFALLS P4).
- **Sesión de mesa (`sesion_mesa`) vincula usuario a mesa — anti-spoofing** (PITFALLS P6; MESA-06 Phase 6).
- **Tech stack: FastAPI + MySQL 8.4 + SQLAlchemy 2.0 async + asyncmy + Alembic** — decisiones del usuario (PROJECT.md constraints).
- **Estado de mesa almacenado y autoritario, mutado solo por la state machine** (PITFALLS P2: fuente única de verdad, nunca recalculado on-the-fly).
- **Snapshot de precio en pedido_item** (`precio_unitario` al momento del pedido — el precio del producto puede cambiar después).
- **`expire_on_commit=False`** ya seteado en `async_session_maker` (Phase 1) — no regresar.

### Claude's Discretion (researcher recomienda, con evidencia)
- **`codigo_qr` único GLOBAL (no por restaurante)** + `numero` único por restaurante. Evidencia: success criterion 3 de la fase + MESA-02 son explícitos ("impide que dos mesas compartan código — constraint en BD").
- **Enums de estado viven en los models** (precedente `RolUsuario` en models/usuario.py) y **las transiciones en `app/core/state_machines.py`** — módulo puro sin dependencias de DB/HTTP, unit-testeable en milisegundos.
- **9 tablas en UNA migración 0002** escrita a mano (precedente 0001: "written by hand so constraints match exactly").
- **`sesion_mesa` se crea AHORA** (no está en la lista de 8 del ROADMAP, pero sí en la data model locked de ARCHITECTURE y la necesita Phase 6; crearla después es una migración extra sin beneficio) — con unique de sesión activa via columna generada.
- **Seed como service (`app/services/seed_service.py`)** siguiendo el precedente bootstrap.py, NO como `seeds/` separado (ARCHITECTURE sugería `seeds/demo_restaurante.py`, pero el codebase ya estableció el patrón services/ + lifespan).
- **Unique slot de reserva DEFERIDO a Phase 5** (ver Open Questions #1): PITFALLS P1 pide constraint único con el schema, pero la semántica del slot (duración de turno, auto-confirm) es decisión del SPEC de Phase 5. Un constraint prematuro con semántica equivocada es peor que una migración trivial en Phase 5 (en dev no hay datos reales que backfill).
- **CHECK constraints en BD** para `estrellas 1-5`, `cantidad > 0`, `num_personas >= 1` — MySQL 8.0.16+ los enforce (8.4 incluido).
- **`updated_at` solo en tablas con state machine mutable** (pedido, pago) con `onupdate=func.now()`.

### Deferred Ideas (OUT OF SCOPE for Phase 3)
- **Endpoints de dominio** (mesas, menú, pedidos, reservas) → Phase 4-8. Aquí SOLO models + state machines + seed.
- **Unique slot de reservas + SELECT FOR UPDATE** → Phase 5 (con su SPEC).
- **Flujo completo de pago/pasarela** → Phase 9 (aquí solo la tabla + enum + referencia unique).
- **Token efímero en QR (rotación)** → v2 (OPER-04).
- **Job de reconciliación de sesiones zombis** → Phase 6+ (PITFALLS P2 red de seguridad).
- **posicion_x/posicion_y en mesa para el mapa visual** → omitido (YAGNI; MESA-01 solo crea numero+capacidad; Phase 4 puede auto-organizar el grid por numero). Ver Open Questions #2.
- **Redis Pub/Sub** → PLT2-02 v2.
</user_constraints>

---

## Standard Stack

**CERO dependencias nuevas.** Todo lo que esta fase necesita ya está instalado y funcionando (verificado en `backend/pyproject.toml` + `uv.lock`):

### Core (existing — reused)
| Library | Version (locked) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **SQLAlchemy[asyncio]** | ≥2.0.52 | ORM models `Mapped[T]`/`mapped_column` + `Numeric`, `Computed`, `CheckConstraint`, `UniqueConstraint`, `Enum` | Ya usado en Phase 2 (Restaurante/Usuario). API 2.0 typed. **Confidence: HIGH** (repo) |
| **Alembic** | ≥1.19.0 | Migración 0002 | Async env.py YA implementado y funcionando (Phase 2, `alembic/env.py` verificado). **Confidence: HIGH** (repo) |
| **asyncmy** | ≥0.2.14 | Driver async MySQL | Devuelve `decimal.Decimal` para columnas `Numeric` (exacto, no float). **Confidence: HIGH** |
| **pydantic-settings** | ≥2.0 | `settings.DEMO_MODE` ya definido (Phase 1, inert) | Solo hay que leerlo en lifespan. **Confidence: HIGH** (repo) |
| **pytest + pytest-asyncio** | ≥8.0 / ≥0.24 | Tests unitarios state machines + integración | `asyncio_mode = "auto"` ya configurado. **Confidence: HIGH** (repo) |

### Installation
```bash
# NADA. No hay `uv add` en esta fase.
# Los tests nuevos usan pytest/pytest-asyncio/asyncmy/httpx ya presentes en dev group + deps.
```

**Version verification:** no aplica (sin paquetes nuevos). Las versiones locked del repo son la fuente de verdad.

---

## Architecture Patterns

### Recommended Project Structure (Phase 3 additions)
```
backend/
├── app/
│   ├── main.py                    # MODIFY: lifespan llama seed_if_demo_mode tras ensure_super_admin
│   ├── core/
│   │   ├── config.py              # UNCHANGED (DEMO_MODE ya existe, línea 28)
│   │   └── state_machines.py      # NEW: dicts de transiciones + validar_transicion + TransicionInvalidaError
│   ├── models/
│   │   ├── __init__.py            # MODIFY: re-exportar todos los models nuevos
│   │   ├── mesa.py                # NEW: Mesa + EstadoMesa
│   │   ├── menu.py                # NEW: Categoria + Producto
│   │   ├── pedido.py              # NEW: Pedido + PedidoItem + EstadoPedido
│   │   ├── reserva.py             # NEW: Reserva + EstadoReserva
│   │   ├── sesion_mesa.py         # NEW: SesionMesa + EstadoSesion + activo_flag computed
│   │   ├── pago.py                # NEW: Pago + EstadoPago
│   │   └── calificacion.py        # NEW: Calificacion
│   └── services/
│       ├── bootstrap.py           # UNCHANGED (ensure_super_admin) — o refactor menor
│       └── seed_service.py        # NEW: seed_if_demo_mode + seed_demo (get-or-create por natural key)
├── alembic/
│   ├── env.py                     # MODIFY: importar los 7 modules nuevos de models
│   └── versions/
│       └── 0002_domain_tables.py  # NEW: las 9 tablas en orden FK-dependiente
├── tests/
│   ├── conftest.py                # MODIFY: fixture db_session (asyncmy directo a localhost:3306)
│   ├── test_state_machines.py     # NEW: unitarios puros (sin DB ni HTTP)
│   ├── test_seed.py               # NEW: PLAT-04 — contenido, idempotencia, gate DEMO_MODE
│   └── test_domain_constraints.py # NEW: MESA-02 — QR duplicado IntegrityError, CHECKs, unique sesion activa
└── scripts/
    └── verify_seed.sh             # NEW: aceptación manual (clean volume → seed presente → restart → idempotente)
```

**Rationale:** Los enums de estado viven junto a su model (precedente `RolUsuario`); las transiciones en `core/` porque son lógica de dominio pura compartida por models y futuros services. `seed_service.py` en services/ (precedente bootstrap.py) — reutilizable desde lifespan, CLI o tests. Un archivo de models por agregado (menu.py = categoria+producto; pedido.py = pedido+pedido_item) siguiendo la estructura sugerida de ARCHITECTURE.md.

### Pattern 1: Enums de estado + tablas (el schema completo)

Todos los PKs `BigInteger` autoincrement (precedente Phase 2). Todas las FKs `BigInteger` (el tipo debe matchear el PK referenciado). `DateTime(timezone=False)` + `server_default=func.now()` (naive wall-time; el servidor MySQL corre a -05:00 — decisión Phase 1). `mysql_charset="utf8mb4"` / `mysql_collate="utf8mb4_unicode_ci"` en cada tabla (precedente 0001).

```python
# app/models/mesa.py
import datetime as dt
import enum

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, Integer, SmallInteger, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EstadoMesa(str, enum.Enum):
    disponible = "disponible"
    reservada = "reservada"
    ocupada = "ocupada"
    limpieza = "limpieza"


class Mesa(Base):
    __tablename__ = "mesa"
    __table_args__ = (
        UniqueConstraint("restaurant_id", "numero", name="uq_mesa_restaurante_numero"),
        UniqueConstraint("codigo_qr", name="uq_mesa_codigo_qr"),  # GLOBAL (MESA-02 + SC3)
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    restaurant_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("restaurante.id"), nullable=False
    )
    numero: Mapped[int] = mapped_column(Integer, nullable=False)          # etiqueta humana
    capacidad: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    codigo_qr: Mapped[str] = mapped_column(String(32), nullable=False)    # "GRI-MESA-001"
    estado: Mapped[EstadoMesa] = mapped_column(
        Enum(EstadoMesa, name="estado_mesa"),
        nullable=False,
        server_default="disponible",
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime(timezone=False), server_default=func.now(), nullable=False
    )
```

**Schema completo por tabla** (columnas → tipo → notas):

| Tabla | Columna | Tipo | Null | Default | Notas |
|-------|---------|------|------|---------|-------|
| **mesa** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK restaurante.id | no | — | |
| | numero | Integer | no | — | único por restaurante (uq compuesto) |
| | capacidad | SmallInteger | no | — | |
| | codigo_qr | String(32) | no | — | **UNIQUE GLOBAL** `uq_mesa_codigo_qr` |
| | estado | Enum estado_mesa | no | 'disponible' | |
| | created_at | DateTime | no | now() | |
| **categoria** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | nombre | String(100) | no | — | UNIQUE(restaurant_id, nombre) |
| | orden | Integer | no | 0 | orden de aparición en el menú |
| | created_at | DateTime | no | now() | |
| **producto** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | categoria_id | BigInteger FK categoria.id | no | — | |
| | nombre | String(150) | no | — | |
| | descripcion | String(500) | sí | — | |
| | precio | **Numeric(10,2)** | no | — | COP exacto, Decimal en Python |
| | imagen_url | String(500) | sí | — | v1: StaticFiles local |
| | disponible | Boolean | no | true | toggle agotado (MENU-02) |
| | created_at | DateTime | no | now() | |
| **pedido** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | mesa_id | BigInteger FK mesa.id | no | — | |
| | usuario_id | BigInteger FK usuario.id | no | — | cliente que pide |
| | estado | Enum estado_pedido | no | 'borrador' | |
| | total | Numeric(10,2) | no | 0 | |
| | notas | String(500) | sí | — | |
| | created_at | DateTime | no | now() | |
| | updated_at | DateTime | no | now() on update now() | muta con cada transición |
| **pedido_item** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | denormalizado (locked arch: "todas con restaurant_id") — simplifica REPO-02 |
| | pedido_id | BigInteger FK pedido.id | no | — | |
| | producto_id | BigInteger FK producto.id | no | — | |
| | cantidad | Integer | no | — | CHECK cantidad > 0 |
| | precio_unitario | Numeric(10,2) | no | — | **snapshot** al momento del pedido |
| | subtotal | Numeric(10,2) | no | — | cantidad × precio_unitario |
| | created_at | DateTime | no | now() | |
| **reserva** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | usuario_id | BigInteger FK | no | — | |
| | mesa_id | BigInteger FK | no | — | |
| | fecha | Date | no | — | |
| | hora_inicio | Time | no | — | |
| | num_personas | SmallInteger | no | — | CHECK >= 1 |
| | estado | Enum estado_reserva | no | 'pendiente' | |
| | created_at | DateTime | no | now() | |
| **sesion_mesa** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | mesa_id | BigInteger FK | no | — | |
| | usuario_id | BigInteger FK | no | — | anti-spoofing: sesión vinculada a usuario |
| | estado | Enum estado_sesion | no | 'activa' | activa/cerrada/expirada |
| | abierta_en | DateTime | no | now() | |
| | cerrada_en | DateTime | sí | — | NULL = abierta |
| | activo_flag | Integer **Computed** | (generated) | — | `CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END` |
| | | | | | UNIQUE(mesa_id, activo_flag) — una sesión activa por mesa |
| **pago** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | pedido_id | BigInteger FK | no | — | |
| | monto | Numeric(10,2) | no | — | |
| | referencia | String(100) | no | — | **UNIQUE** `uq_pago_referencia` — idempotencia (P4) |
| | estado | Enum estado_pago | no | 'pendiente' | |
| | pasarela | String(50) | sí | — | "wompi"/"payu"/... (Phase 9) |
| | created_at / updated_at | DateTime | no | now() | |
| **calificacion** | id | BigInteger PK AI | no | — | |
| | restaurant_id | BigInteger FK | no | — | |
| | usuario_id | BigInteger FK | no | — | |
| | pedido_id | BigInteger FK | no | — | UNIQUE `uq_calificacion_pedido` — una por pedido |
| | estrellas | SmallInteger | no | — | **CHECK 1-5** (MySQL 8.0.16+ enforce) |
| | comentario | String(1000) | sí | — | |
| | created_at | DateTime | no | now() | |

### Pattern 2: Índices compuestos (diseñados para las queries de Phase 4-6)

| Índice | Tabla | Columnas | Sirve a |
|--------|-------|----------|---------|
| `uq_mesa_restaurante_numero` (UNIQUE) | mesa | (restaurant_id, numero) | mapa de mesas + FK lookups (el unique sirve de índice, restaurant_id es prefijo) |
| `uq_mesa_codigo_qr` (UNIQUE) | mesa | (codigo_qr) | lookup por QR escaneado (Phase 6) + integrity |
| `ix_categoria_restaurante_orden` | categoria | (restaurant_id, orden) | menú ordenado (REST-02 Phase 5) |
| `ix_producto_restaurante_categoria` | producto | (restaurant_id, categoria_id) | menú por categorías (REST-02) |
| `ix_pedido_restaurante_estado` | pedido | (restaurant_id, estado) | cola de cocina "activos del restaurante" (PEDI-02/ADMN-05) |
| `ix_pedido_mesa` | pedido | (mesa_id) | pedidos de la mesa / cuenta (PAGO-01) |
| `ix_pedido_usuario` | pedido | (usuario_id) | "mis pedidos" del cliente (PEDI-04) |
| `ix_pedido_item_restaurante_producto` | pedido_item | (restaurant_id, producto_id) | platos más vendidos (REPO-02 Phase 8) |
| `ix_reserva_mesa_fecha` | reserva | (mesa_id, fecha) | disponibilidad/solapamiento (RESV-02 Phase 5) |
| `ix_reserva_restaurante_fecha_estado` | reserva | (restaurant_id, fecha, estado) | reservas del día (ADMN-01/RESV-05) |
| `ix_reserva_usuario` | reserva | (usuario_id) | "mis reservas" (RESV-03) |
| `ix_sesion_mesa_usuario` | sesion_mesa | (usuario_id) | sesión activa del cliente (MESA-06) |
| `uq_sesion_mesa_activa` (UNIQUE) | sesion_mesa | (mesa_id, activo_flag) | anti-doble-sesión (P6) |
| `uq_pago_referencia` (UNIQUE) | pago | (referencia) | idempotencia (P4/PAGO-03) |
| `ix_pago_pedido` | pago | (pedido_id) | pago del pedido |
| `ix_calificacion_restaurante` | calificacion | (restaurant_id) | promedio (CALI-02 Phase 9) |
| `uq_calificacion_pedido` (UNIQUE) | calificacion | (pedido_id) | una calificación por pedido (CALI-01) |

**Regla:** FKs siempre con índice (MySQL no crea índices en FKs automáticamente — InnoDB sí lo hace automáticamente para FKs, pero los comuestos arriba ya cubren la mayoría; los FKs que queden fuera de un índice compuesto llevan índice propio explícito).

### Pattern 3: State machines como módulo puro

**What:** Enums en los models (precedente RolUsuario) + transiciones en `core/state_machines.py`. El módulo NO importa nada de DB/FastAPI — solo los enums — así los tests unitarios corren en milisegundos sin stack.

```python
# app/core/state_machines.py
"""State machines explícitas de dominio (ARCHITECTURE.md Pattern 5).

Módulo PURO: no importa ORM ni FastAPI — solo los enums de estado. Phase 5/6
importan validar_transicion() en sus services y traducen TransicionInvalidaError
a 409 Conflict en el router (el dominio no decide códigos HTTP).
"""

from app.models.mesa import EstadoMesa
from app.models.pedido import EstadoPedido
from app.models.reserva import EstadoReserva
from app.models.sesion_mesa import EstadoSesion
from app.models.pago import EstadoPago


class TransicionInvalidaError(Exception):
    """Transición de estado no permitida por la máquina de estados del dominio."""

    def __init__(self, maquina: str, actual: str, nueva: str):
        self.maquina = maquina
        self.actual = actual
        self.nueva = nueva
        super().__init__(f"[{maquina}] transición {actual!r} → {nueva!r} no permitida")


# ARCHITECTURE.md Pattern 5 — estados con set vacío = terminales
MESA_TRANSITIONS: dict[EstadoMesa, set[EstadoMesa]] = {
    EstadoMesa.disponible: {EstadoMesa.reservada, EstadoMesa.ocupada},
    EstadoMesa.reservada: {EstadoMesa.ocupada, EstadoMesa.disponible},  # expira/cancela
    EstadoMesa.ocupada: {EstadoMesa.limpieza},
    EstadoMesa.limpieza: {EstadoMesa.disponible},
}

PEDIDO_TRANSITIONS: dict[EstadoPedido, set[EstadoPedido]] = {
    EstadoPedido.borrador: {EstadoPedido.enviado},
    EstadoPedido.enviado: {EstadoPedido.aceptado, EstadoPedido.rechazado},
    EstadoPedido.aceptado: {EstadoPedido.en_preparacion},
    EstadoPedido.en_preparacion: {EstadoPedido.servido},
    EstadoPedido.servido: {EstadoPedido.pagado},
    EstadoPedido.rechazado: set(),   # terminal
    EstadoPedido.pagado: set(),      # terminal
}

RESERVA_TRANSITIONS: dict[EstadoReserva, set[EstadoReserva]] = {
    EstadoReserva.pendiente: {EstadoReserva.confirmada, EstadoReserva.cancelada},
    EstadoReserva.confirmada: {EstadoReserva.cancelada},
    EstadoReserva.cancelada: set(),  # terminal
}

PAGO_TRANSITIONS: dict[EstadoPago, set[EstadoPago]] = {
    EstadoPago.pendiente: {EstadoPago.aprobado, EstadoPago.rechazado},
    EstadoPago.aprobado: set(),
    EstadoPago.rechazado: set(),
}

SESION_TRANSITIONS: dict[EstadoSesion, set[EstadoSesion]] = {
    EstadoSesion.activa: {EstadoSesion.cerrada, EstadoSesion.expirada},
    EstadoSesion.cerrada: set(),
    EstadoSesion.expirada: set(),
}

_ALL = {
    "mesa": MESA_TRANSITIONS,
    "pedido": PEDIDO_TRANSITIONS,
    "reserva": RESERVA_TRANSITIONS,
    "pago": PAGO_TRANSITIONS,
    "sesion_mesa": SESION_TRANSITIONS,
}


def validar_transicion(maquina: str, actual: str, nueva: str) -> None:
    """Raise TransicionInvalidaError si actual→nueva no está declarada."""
    transitions = _ALL[maquina]
    permitidas = transitions.get(actual, set())
    if nueva not in permitidas:
        raise TransicionInvalidaError(maquina, actual, nueva)


def puede_transicionar(maquina: str, actual: str, nueva: str) -> bool:
    transitions = _ALL[maquina]
    return nueva in transitions.get(actual, set())
```

**Cómo lo consumen fases futuras sin endpoints ahora:** Phase 5 (mesa/reserva) y Phase 6 (pedido/sesión) hacen:
```python
# Phase 6 example (NO implementar ahora):
try:
    validar_transicion("pedido", pedido.estado, nuevo_estado)
except TransicionInvalidaError as e:
    raise HTTPException(status.HTTP_409_CONFLICT, str(e))
pedido.estado = nuevo_estado
```
La decisión de dominio (qué transiciones existen) queda en `core/`; la traducción HTTP en el router. El dominio nunca importa FastAPI.

### Pattern 4: Seed demo idempotente gateado

**What:** `seed_service.py` con dos funciones: `seed_if_demo_mode(session)` (el gate — llamado por lifespan) y `seed_demo(session)` (el contenido). Idempotencia por **natural-key get-or-create**: nunca INSERT ciego.

```python
# app/services/seed_service.py (esqueleto — el menú completo es data literal)
"""Seed del restaurante demo (PLAT-04).

Corre en lifespan DESPUÉS de ensure_super_admin y solo cuando DEMO_MODE=true.
Idempotente por natural keys: buscar-antes-de-crear en cada entidad. Correr
dos veces (o reiniciar el contenedor N veces) deja la BD en el mismo estado.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_password
from app.models.usuario import RolUsuario, Usuario
from app.models.restaurante import Restaurante
# ... resto de models

DEMO_RESTAURANTE_NOMBRE = "Restaurante Demo GRI"
DEMO_PASSWORD = "Demo!1234"  # demo-only; DEMO_MODE=false en prod lo excluye (PITFALLS Security)


async def seed_if_demo_mode(session: AsyncSession) -> dict | None:
    """Gate de lifespan: no-op cuando DEMO_MODE=false (SC2)."""
    if not settings.DEMO_MODE:
        return None
    return await seed_demo(session)


async def _get_or_create_usuario(session, *, email, nombre, role, restaurant_id) -> Usuario:
    stmt = select(Usuario).where(Usuario.email == email)
    user = (await session.execute(stmt)).scalar_one_or_none()
    if user is None:
        user = Usuario(
            nombre=nombre, email=email,
            password_hash=hash_password(DEMO_PASSWORD),
            role=role, restaurant_id=restaurant_id,
        )
        session.add(user)
        await session.flush()  # asigna id sin commit — permite FKs dentro de la tx
    return user


async def seed_demo(session: AsyncSession) -> dict:
    """Siembra restaurante + staff + mesas + menú + clientes. Retorna resumen."""
    # 1. Restaurante (natural key: nombre exacto)
    restaurante = ...  # select por nombre; crear si falta
    # 2. Staff: admin@demo.gri.dev / mesero@demo.gri.dev / cocina@demo.gri.dev
    # 3. 8 mesas: numeros 1-8, capacidades [2,2,4,4,4,6,6,8], QR GRI-MESA-001..008
    #    (natural key: codigo_qr — respeta el unique global)
    # 4. 4 categorías: Entradas, Platos Fuertes, Bebidas, Postres (orden 1-4)
    # 5. ~16 productos COP (natural key: categoria + nombre)
    # 6. 2 clientes demo: carlos@demo.gri.dev, maria@demo.gri.dev
    await session.commit()
    return {...resumen con counts para logs...}
```

**Contenido del seed (prescrito):**

| Entidad | Datos |
|---------|-------|
| Restaurante | "Restaurante Demo GRI", tipo_cocina "Colombiana", descripcion "Restaurante de demostración de la plataforma GRI", direccion "Cra. 7 #63-44, Bogotá" |
| Staff (3) | admin@demo.gri.dev (admin_restaurante), mesero@demo.gri.dev (mesero), cocina@demo.gri.dev (cocina) — password Demo!1234 |
| Mesas (8) | numeros 1-8; capacidades 2,2,4,4,4,6,6,8; QR `GRI-MESA-001` … `GRI-MESA-008`; estado disponible |
| Categorías (4) | Entradas(1), Platos Fuertes(2), Bebidas(3), Postres(4) |
| Productos (~16) | 4 entradas (patacón con hogao $12.000, empanadas x3 $9.500, arepa rellena $11.000, sopita del día $14.000), 5 fuertes (bandeja paisa $32.000, ajiaco santafereño $28.000, lechona tolimense $30.000, trout moqueta $34.000, sancocho $26.000), 4 bebidas (limonada de coco $9.000, jugo natural $8.000, gaseosa $5.500, cerveza artesanal $12.000), 3 postres (tres leches $9.500, flan de coco $8.500, café con leche $4.500) |
| Clientes (2) | carlos@demo.gri.dev, maria@demo.gri.dev (password Demo!1234) |

Nota emails: `.dev` es gTLD real (a diferencia de `.local` que email-validator rechaza — lección de Phase 2 en 02-02-SUMMARY).

**Wiring en lifespan (main.py):**
```python
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    async with async_session_maker() as session:
        await ensure_super_admin(session)
        await seed_if_demo_mode(session)   # NEW — gate interno DEMO_MODE
    yield
    await engine.dispose()
```

**Orden de boot en deploy limpio (INFR-03 end-to-end):**
```
docker compose up
  → CMD: alembic upgrade head          (migraciones — YA EXISTE, Phase 2)
  → uvicorn arranca
  → lifespan: ensure_super_admin       (Phase 2)
  → lifespan: seed_if_demo_mode        (NEW — DEMO_MODE=true → siembra; false → no-op)
```

### Pattern 5: `sesion_mesa` — unique de sesión activa en MySQL (sin partial indexes)

**What:** PITFALLS P6 pide "UNIQUE (mesa_id) WHERE estado='activa' o lógica equivalente" — pero MySQL **no tiene partial indexes** (sintaxis Postgres). El equivalente MySQL estándar: columna generada + UNIQUE multi-columna, explotando que **MySQL ignora filas con NULL en cualquier columna de un índice unique** (múltiples (5, NULL) conviven; solo un (5, 1)).

```python
# app/models/sesion_mesa.py (fragmento)
from sqlalchemy import Computed, Integer, UniqueConstraint

class SesionMesa(Base):
    __tablename__ = "sesion_mesa"
    __table_args__ = (
        UniqueConstraint("mesa_id", "activo_flag", name="uq_sesion_mesa_activa"),
    )

    # ... id, restaurant_id, mesa_id, usuario_id, estado, abierta_en, cerrada_en ...

    # 1 mientras la sesión está abierta; NULL cuando cerrada_en se setea.
    # Las filas NULL quedan FUERA del unique → solo UNA sesión activa por mesa.
    activo_flag: Mapped[int | None] = mapped_column(
        Integer,
        Computed("CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END"),
        nullable=True,
    )
```

En la migración: `sa.Column("activo_flag", sa.Integer(), sa.Computed("CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END"), nullable=True)` seguido del `sa.UniqueConstraint("mesa_id", "activo_flag", name="uq_sesion_mesa_activa")`. MySQL 8.4 soporta índices unique sobre columnas generadas virtuales (desde 5.7.8). **El test `test_domain_constraints.py::test_una_sesion_activa_por_mesa` verifica empíricamente el comportamiento en el MySQL 8.4 real del stack** — si el DDL no enforce, el test falla y se detecta en el acto. Fallback documentado si algo no cuadra: drop del constraint y enforcement en service layer con `SELECT ... FOR UPDATE` en Phase 6 (perdiendo la defensa de BD pero no el funcionamiento).

### Pattern 6: Migración 0002 — una sola, a mano, orden FK-dependiente

**What:** Las 9 tablas en `0002_domain_tables.py`. Precedente 0001: escrita a mano con nombres de constraint explícitos (determinístico, auditable, sin sorpresas de autogenerate).

**Orden upgrade** (cada tabla solo referencia tablas ya existentes):
```
mesa → categoria → producto (→categoria)
→ pedido (→mesa, usuario) → pedido_item (→pedido, producto)
→ reserva (→usuario, mesa) → sesion_mesa (→mesa, usuario)
→ pago (→pedido) → calificacion (→restaurante, usuario, pedido)
```
**Downgrade:** orden exactamente inverso (calificacion primero … mesa última).

**Por qué una sola migración (pregunta 6 del scope):** cohesión — el modelo de dominio es una unidad conceptual; up/down atómico; una sola revisión; en dev no hay datos que migrar incrementalmente. Migraciones futuras (Phase 5 slot unique, Phase 8 columnas nuevas) serán incrementalmente pequeñas.

**Anti-patterns to Avoid**
- **`create_all()` para "verificar" los models** — regreso al anti-pattern que Phase 2 enterró. Solo Alembic. Si quieres ver el schema localmente: `alembic upgrade head` contra dev.
- **`Float` para dinero** — `Numeric(10,2)` + `Decimal` siempre (Pitfall 1 abajo).
- **Estado como string libre** — siempre Enums (Anti-Pattern 5 de ARCHITECTURE: `"preparandose"` typo = bug silencioso).
- **Seed con INSERT ciego / `delete_all` + re-insert** — rompe idempotencia y referencias. Natural-key get-or-create.
- **Strings literales para estados en el seed o tests** — usar los Enums (`EstadoMesa.disponible`), nunca `"disponible"` suelto.
- **`codigo_qr` unique por restaurante** — viola MESA-02/SC3. Es GLOBAL.
- **Cascade deletes entre tablas de dominio** — FKs con RESTRICT (default). El borrado de tenant data no está en scope v1 y un CASCADE accidental destruye datos.
- **Olvidar importar los models nuevos en `alembic/env.py`** — autogenerate/DDL vería metadata incompleto. La línea `from app.models import ...` debe incluir los 7 módulos nuevos (o importar `app.models` que ya re-exporta todo).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dinero (precios, totales) | `Float`/`float` columnas o aritmética | `Numeric(10,2)` + `decimal.Decimal` | Float pierde centavos (0.1+0.2≠0.3). MySQL DECIMAL es exacto; asyncmy devuelve Decimal. `total = sum(subtotals)` en Decimal o SQL SUM — ambos exactos |
| Máquina de estados | Librería `transitions`/`python-statemachine` | dict[Enum, set[Enum]] + `validar_transicion()` | El dict de 10 líneas es la totalidad de la necesidad; una librería añade conceptos (hierarchies, callbacks) que nadie pidió. ARCHITECTURE prescribe el dict |
| Snapshot de precio | Recalcular desde producto al leer | Columna `precio_unitario` en pedido_item | El precio del producto cambia; el histórico del pedido no debe mutar. Locked decision |
| Unicidad de QR | Check en service layer únicamente | `UniqueConstraint` en BD (+ chequeo service para UX) | La carrera "dos creates simultáneos" solo la pierde la BD... o la gana, si no hay constraint. SC3 exige constraint en BD explícitamente |
| "Una sesión activa por mesa" | Solo check en service (race condition) | Columna generada + UNIQUE (Pattern 5) | PITFALLS P6: la defensa vive en la BD |
| Idempotencia del seed | Tabla de tracking / flags en BD | Natural-key get-or-create | Sin infra extra; el estado de "ya sembrado" ES la existencia de las filas |
| Timestamps created/updated | Setear en Python | `server_default=func.now()` / `onupdate=func.now()` | Consistencia de reloj (un solo reloj: MySQL), funciona desde cualquier cliente |
| Constraints de rango | Validación solo en Pydantic (que no existe aún esta fase) | `CheckConstraint` en BD | estrellas 1-5 y cantidad>0 son invariantes del dominio — la BD es la última línea |

**Key insight:** Esta fase es casi enteramente "declarar el dominio correctamente". El riesgo no es dificultad sino omisión — el índice compuesto que falta, el constraint que se defería "para después", el Enum que deriva a string. Todo lo que esta fase declara en BD es defensa permanente para fases 4-9.

---

## Common Pitfalls

### Pitfall 1: Float para dinero
**What goes wrong:** `precio: float` o `Numeric` sin escala → `25.000,00` COP se redondea mal; totales no cuadran con la sumatoria de items; reportes de ventas (Phase 8) acumulan drift de centavos.
**Why it happens:** `Float` es el default mental; algunos ORMs/tutorials lo usan.
**How to avoid:** `Numeric(10, 2, decimal_return_scale=2)` en TODA columna monetaria (precio, precio_unitario, subtotal, total, monto). Python: `Decimal` end-to-end. Nunca `float()` intermedio.
**Warning signs:** `float` en un model; `round(total, 2)` en service code; tests comparando precios con `==` sobre floats.
**Confidence:** HIGH (semántica DECIMAL/Decimal estable 15+ años).

### Pitfall 2: `codigo_qr` unique por restaurante en vez de global
**What goes wrong:** Se copia el `UniqueConstraint("restaurant_id", "codigo")` del Pattern 4 de ARCHITECTURE.md → dos restaurantes pueden tener `GRI-MESA-001` → el QR escaneado es ambiguo (¿de qué restaurante es esta mesa?) → MESA-02/SC3 violados.
**Why it happens:** El snippet de research general usaba unique compuesto; el success criterion de ESTA fase es más específico.
**How to avoid:** UNIQUE global sobre `codigo_qr` + UNIQUE compuesto `(restaurant_id, numero)` para el número humano. Al crear mesas nuevas (Phase 8), el sufijo debe ser global-único: helper `generar_codigo_qr(session)` = `SELECT MAX` sobre el sufijo + reintentos ante IntegrityError.
**Warning signs:** test de QR duplicado que usa dos restaurantes distintos y espera fallo — si espera éxito, está mal.
**Confidence:** HIGH (requisito explícito).

### Pitfall 3: Seed no idempotente → duplicados en cada restart
**What goes wrong:** El seed hace INSERTs ciegos; `docker compose restart` re-ejecuta lifespan → restaurante demo duplicado, staff duplicado (o IntegrityError que rompe el boot), violando SC1 ("se ejecutan automáticamente como parte del proceso" — implica sin romperse).
**Why it happens:** Se prueba una vez y funciona; el restart es el caso que importa.
**How to avoid:** Natural-key get-or-create en CADA entidad (email, codigo_qr, nombre). Test que llama `seed_demo` DOS veces y compara counts.
**Warning signs:** `session.add` sin select previo en el seed; boot que falla con IntegrityError tras restart.
**Confidence:** HIGH.

### Pitfall 4: DEMO_MODE sin gate real (o gate que siembra igual)
**What goes wrong:** El seed corre incondicional (demo en prod — PITFALLS Security: "Contraseñas de seed/demo en prod") o el gate existe pero no se testea → regresión silenciosa.
**Why it happens:** El flag existe desde Phase 1 y nadie lo leyó; el gate es una línea fácil de olvidar.
**How to avoid:** `seed_if_demo_mode()` gatea dentro (no confiar solo en el caller); `DEMO_MODE: false` default YA está en config/compose/.env.example (verificado). Test: monkeypatch `settings.DEMO_MODE=False` → wrapper no crea filas nuevas.
**Warning signs:** grep del seed en lifespan sin referencia a DEMO_MODE.
**Confidence:** HIGH.

### Pitfall 5: Enums Python/MySQL desincronizados
**What goes wrong:** Alguien añade un estado en el Enum Python sin migración (o viceversa) → INSERT falla con "Data truncated for column" o estados huérfanos.
**Why it happens:** MySQL ENUM nativo requiere ALTER TABLE para cambiar valores.
**How to avoid:** Los Enums viven SOLO en `app/models/*.py` (una fuente); la migración referencia los mismos literales. En esta fase los 5 Enums se crean junto a sus tablas. Regla para fases futuras: cambiar un Enum = migración + enum juntos en el mismo commit.
**Warning signs:** strings literales de estado fuera de los Enums; dos definiciones del mismo Enum.
**Confidence:** HIGH.

### Pitfall 6: `expire_on_commit` / flush dentro del seed (MissingGreenlet o FKs sin id)
**What goes wrong:** (a) commit intermedio + acceso a atributo → MissingGreenlet (ya prevenido — `expire_on_commit=False` desde Phase 1); (b) crear staff ANTES de hacer flush del restaurante → `restaurant_id` NULL en memoria al construir el usuario.
**Why it happens:** Encadenar FKs dentro de una transacción sin flush intermedio.
**How to avoid:** `await session.flush()` después de crear cada entidad padre (asigna ids sin commit); UN solo `commit()` al final del seed (atomicidad — o se siembra todo o nada).
**Warning signs:** `MissingGreenlet` en tests del seed; restaurante creado pero staff sin restaurant_id.
**Confidence:** HIGH (patrón SQLAlchemy async documentado + ya aplicado en Phase 2).

### Pitfall 7: MySQL unique con NULL — comportamiento contra-intuitivo
**What goes wrong:** Se asume que UNIQUE(a, b) rechaza duplicados con NULL — MySQL permite N filas con NULL en cualquier parte del índice unique. Si alguien "confía" en que UNIQUE(cerrada_en) evita doble cierre... no lo hace.
**Why it happens:** Semántica SQL estándar (NULL ≠ NULL), no bug de MySQL.
**How to avoid:** Es exactamente lo que EXPLOTAMOS en Pattern 5 (activo_flag NULL = fuera del unique). Documentarlo en el model. Para uniqueness con NULLs usar columnas generadas que materialicen el estado.
**Confidence:** HIGH (semántica SQL fundamental).

### Pitfall 8: Tests de constraints vía HTTP-only
**What goes wrong:** Se intenta testear el QR duplicado o la idempotencia del seed vía la API — pero NO HAY endpoints de dominio hasta Phase 4-6 → tests imposibles o se crean endpoints solo para testear (scope creep).
**Why it happens:** El conftest existente solo ofrece `async_client` (HTTP).
**How to avoid:** Fixture `db_session` nuevo (asyncmy directo a localhost:3306, credenciales de .env — mismo patrón de lectura manual que `super_admin_token`). Los tests de dominio de esta fase son DB-directos + los state machines son unitarios puros.
**Warning signs:** propuestas de "endpoint temporal para el seed" — NO.
**Confidence:** HIGH.

---

## Code Examples

### Fixture db_session para conftest.py (Wave 0 — el único gap de infra de tests)
```python
# tests/conftest.py (addition)
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Sesión asyncmy DIRECTA a la BD del stack Docker (localhost:3306).

    Para tests de dominio sin endpoints: constraints, seed, enums.
    Requiere el stack corriendo (igual que async_client) + .env con credenciales.
    """
    # Reusar el parser manual de .env del fixture super_admin_token (refactor menor:
    # extraer helper _read_env() compartido).
    user, password = ..., ...
    url = f"mysql+asyncmy://{user}:{password}@localhost:3306/gri?charset=utf8mb4"
    engine = create_async_engine(url, pool_pre_ping=True)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()
```

### Test de constraint QR duplicado (MESA-02 hard gate)
```python
# tests/test_domain_constraints.py
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models.mesa import EstadoMesa, Mesa
from app.models.restaurante import Restaurante


async def _demo_restaurante(session) -> Restaurante:
    r = (await session.execute(select(Restaurante).limit(1))).scalar_one_or_none()
    if r is None:
        r = Restaurante(nombre=f"constraint-test-{uuid4().hex[:6]}")
        session.add(r)
        await session.flush()
    return r


async def test_qr_duplicado_rechazado(db_session):
    """MESA-02/SC3: dos mesas NO pueden compartir codigo_qr (aunque sea
    de restaurantes distintos — el unique es GLOBAL)."""
    r = await _demo_restaurante(db_session)
    db_session.add(Mesa(restaurant_id=r.id, numero=101, capacidad=4,
                        codigo_qr="GRI-MESA-999"))
    await db_session.flush()
    db_session.add(Mesa(restaurant_id=r.id, numero=102, capacidad=2,
                        codigo_qr="GRI-MESA-999"))  # mismo QR
    with pytest.raises(IntegrityError):
        await db_session.flush()
    await db_session.rollback()


async def test_una_sesion_activa_por_mesa(db_session):
    """PITFALLS P6: el unique (mesa_id, activo_flag) rechaza la 2a sesión activa."""
    # crear mesa + usuario, insertar sesion activa, insertar 2a sesion activa
    # → pytest.raises(IntegrityError); luego setear cerrada_en en la 1a
    # → la nueva sesión activa ES aceptable (verifica también la semántica NULL)
```

### Test unitario de state machine (sin infra — corre en ms)
```python
# tests/test_state_machines.py
import pytest

from app.core.state_machines import (
    MESA_TRANSITIONS, PEDIDO_TRANSITIONS, TransicionInvalidaError, validar_transicion,
)
from app.models.mesa import EstadoMesa
from app.models.pedido import EstadoPedido


def test_mesas_transiciones_validas():
    validar_transicion("mesa", EstadoMesa.disponible, EstadoMesa.ocupada)
    validar_transicion("mesa", EstadoMesa.ocupada, EstadoMesa.limpieza)
    validar_transicion("mesa", EstadoMesa.limpieza, EstadoMesa.disponible)


def test_mesa_salto_invalido_rechazado():
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("mesa", EstadoMesa.limpieza, EstadoMesa.ocupada)
    with pytest.raises(TransicionInvalidaError):
        validar_transicion("mesa", EstadoMesa.disponible, EstadoMesa.limpieza)


def test_pedido_rechazado_y_pagado_son_terminales():
    for terminal in (EstadoPedido.rechazado, EstadoPedido.pagado):
        for nuevo in EstadoPedido:
            if nuevo == terminal:
                continue
            with pytest.raises(TransicionInvalidaError):
                validar_transicion("pedido", terminal, nuevo)


def test_cobertura_declarada():
    """Todo estado declarado en el Enum tiene entrada en el dict (o explota aquí,
    no en runtime de Phase 6)."""
    assert set(MESA_TRANSITIONS) == set(EstadoMesa)
    # ... idem PEDIDO_TRANSITIONS vs EstadoPedido, etc.
```

### Test de idempotencia del seed (PLAT-04)
```python
# tests/test_seed.py
from sqlalchemy import func, select

from app.services.seed_service import seed_demo, seed_if_demo_mode


async def test_seed_crea_demo(db_session):
    resumen = await seed_demo(db_session)
    assert resumen["mesas"] == 8
    assert resumen["productos"] >= 15
    # restaurante existe, mesas con QR GRI-MESA-00X...


async def test_seed_idempotente(db_session):
    """Correr 2 veces = mismo estado (restart-safe)."""
    await seed_demo(db_session)
    n1 = (await db_session.execute(select(func.count()).select_from(Mesa))).scalar()
    await seed_demo(db_session)  # segunda pasada no duplica
    n2 = (await db_session.execute(select(func.count()).select_from(Mesa))).scalar()
    assert n1 == n2


async def test_demo_mode_false_no_siembra(db_session, monkeypatch):
    """SC2: con DEMO_MODE=false el gate no crea filas nuevas."""
    from app.core.config import settings
    monkeypatch.setattr(settings, "DEMO_MODE", False)
    before = (await db_session.execute(select(func.count()).select_from(Restaurante))).scalar()
    result = await seed_if_demo_mode(db_session)
    assert result is None
    after = (await db_session.execute(select(func.count()).select_from(Restaurante))).scalar()
    assert after == before  # nada NUEVO (aunque exista demo de otros tests)
```

### Migración 0002 (fragmento representativo — el patrón para las 9 tablas)
```python
# alembic/versions/0002_domain_tables.py
"""domain tables: mesa, categoria, producto, pedido, pedido_item, reserva,
sesion_mesa, pago, calificacion (Phase 3).

Revision ID: 0002
Revises: 0001
"""

revision: str = "0002"
down_revision: str = "0001"


def upgrade() -> None:
    op.create_table(
        "mesa",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("restaurant_id", sa.BigInteger(), nullable=False),
        sa.Column("numero", sa.Integer(), nullable=False),
        sa.Column("capacidad", sa.SmallInteger(), nullable=False),
        sa.Column("codigo_qr", sa.String(length=32), nullable=False),
        sa.Column("estado", sa.Enum("disponible", "reservada", "ocupada", "limpieza",
                                    name="estado_mesa"),
                  server_default="disponible", nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["restaurant_id"], ["restaurante.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("restaurant_id", "numero", name="uq_mesa_restaurante_numero"),
        sa.UniqueConstraint("codigo_qr", name="uq_mesa_codigo_qr"),
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_unicode_ci",
    )
    # ... categoria, producto, pedido (+ix_pedido_restaurante_estado, ix_pedido_mesa,
    #     ix_pedido_usuario), pedido_item (+ CHECK cantidad>0,
    #     ix_pedido_item_restaurante_producto), reserva (+ CHECK num_personas>=1,
    #     ix_reserva_*), sesion_mesa (+ activo_flag Computed + unique), pago
    #     (+ uq_pago_referencia), calificacion (+ CHECK estrellas 1-5,
    #     uq_calificacion_pedido, ix_calificacion_restaurante) ...


def downgrade() -> None:
    # Orden INVERSO de FKs
    op.drop_table("calificacion")
    op.drop_table("pago")
    op.drop_table("sesion_mesa")
    op.drop_table("reserva")
    op.drop_table("pedido_item")
    op.drop_table("pedido")
    op.drop_table("producto")
    op.drop_table("categoria")
    op.drop_table("mesa")
```
(Nota: como en 0001, no hace falta drop_index explícito — drop_table arrastra los índices.)

### verify_seed.sh (esqueleto — aceptación manual INFR-03/PLAT-04)
```bash
#!/bin/sh
# scripts/verify_seed.sh — corre DENTRO del contenedor api (docker exec -w /app gri-api sh scripts/verify_seed.sh)
# Precondición: DEMO_MODE=true en .env y stack up. MySQL client via docker exec gri-mysql.
echo "== 1. Restaurante demo existe =="
docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri \
  -e "SELECT id, nombre FROM restaurante WHERE nombre='Restaurante Demo GRI';"
echo "== 2. 8 mesas con QR GRI-MESA-00X únicas =="
docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri \
  -e "SELECT codigo_qr, numero, estado FROM mesa ORDER BY numero;"
echo "== 3. Restart del api (lifespan re-corre el seed) =="
docker restart gri-api && sleep 8
echo "== 4. Counts idénticos tras restart =="
docker exec gri-mysql mysql -ugri_app -p"$MYSQL_APP_PASSWORD" gri \
  -e "SELECT (SELECT COUNT(*) FROM mesa) mesas, (SELECT COUNT(*) FROM producto) productos, (SELECT COUNT(*) FROM usuario WHERE email LIKE '%@demo.gri.dev') demo_users;"
# (comparar manualmente con el count pre-restart / o capturar y diff dentro del script)
echo "ALL CHECKS PASSED"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Partial unique indexes (`UNIQUE ... WHERE`) | No existen en MySQL — columna generada + unique multi-columna | MySQL 8.0.13 (functional parts), 5.7 (generated cols) | Pattern 5 para sesion_mesa |
| CHECK constraints ignorados | Enforced desde MySQL 8.0.16 | 8.0.16 (2019) | estrellas 1-5, cantidad>0, num_personas>=1 son defensa real en 8.4 |
| `create_all()` para schema | Alembic desde el primer model | Phase 2 de ESTE repo | Ya resuelto — no regresar |
| Seed script manual post-deploy | Seed en lifespan gateado por env | patrón bootstrap Phase 2 | INFR-03 se cierra solo |

**Deprecated/outdated (para esta fase):** nada nuevo — la fase no añade tecnología.

---

## Open Questions

1. **Unique slot de reserva — ¿ahora o Phase 5?**
   - What we know: PITFALLS P1 pide el constraint único diseñado con el schema. La semántica del "slot" (¿turnos fijos de 90 min? ¿hora exacta?) es decisión del SPEC de Phase 5 (auto-confirm vs manual).
   - What's unclear: la forma del constraint sin la semántica.
   - Recommendation: **INDEX (mesa_id, fecha) ahora; unique de slot en Phase 5** con su migración (trivial en dev). Un constraint equivocado hoy es más caro que una migración pequeña mañana.

2. **posicion_x/posicion_y en mesa (para el mapa visual de Phase 4)**
   - What we know: ARCHITECTURE Pattern 4 las incluía; ningún requisito las pide; MESA-01 (Phase 8) solo edita numero+capacidad.
   - Recommendation: omitir (YAGNI). Phase 4 puede organizar el grid por numero. Si el mockup exige posiciones libres, migración aditiva en Phase 4 (columnas nullable — barato).

3. **`sesion_mesa` en 0002 o defer a Phase 6**
   - What we know: no está en la lista de 8 tablas de las notas del ROADMAP, pero la data model de ARCHITECTURE la incluye y Phase 6 la necesita (MESA-06).
   - Recommendation: **incluir en 0002** (9 tablas). Coste: una tabla más en la misma migración. Beneficio: el modelo de datos completo existe de una vez y el planner de Phase 6 no espera migraciones.

4. **Contenido exacto del menú demo**
   - What we know: el researcher prescribe un menú colombiano de ~16 productos con precios COP realistas (ver Pattern 4).
   - Recommendation: usarlo como viene; si el usuario quiere platos específicos, es un edit de data literals (sin cambio estructural).

5. **Pydantic v2 serializa Decimal como string en JSON** — relevante para los schemas de Phase 4/5 (el cliente Flutter recibe `"32000.00"` string, no número).
   - What we know: comportamiento default de Pydantic v2 (sería deseable para dinero — sin pérdida de precisión).
   - Recommendation: confirmar empíricamente al crear el primer schema de dominio (Phase 4). No afecta esta fase.

---

## Validation Architecture

> `workflow.nyquist_validation: true` en `.planning/config.json` — sección incluida.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest ≥8.0 + pytest-asyncio ≥0.24 (`asyncio_mode = "auto"`) |
| Config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` |
| Quick run command | `uv run pytest tests/test_state_machines.py -x` (unitarios puros — sin stack, milisegundos) |
| Full suite command | `uv run pytest` (requiere `docker compose up -d` + `.env`; patrón establecido Phase 2) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAT-04 | Seed crea restaurante demo + menú + mesas + usuarios cuando DEMO_MODE=true | integration (DB-direct) | `uv run pytest tests/test_seed.py -x` | ❌ Wave 0 |
| PLAT-04 | Seed idempotente (2a ejecución = mismo estado) | integration (DB-direct) | `uv run pytest tests/test_seed.py::test_seed_idempotente -x` | ❌ Wave 0 |
| PLAT-04 | DEMO_MODE=false no siembra nada nuevo | integration (DB-direct, monkeypatch) | `uv run pytest tests/test_seed.py::test_demo_mode_false_no_siembra -x` | ❌ Wave 0 |
| MESA-02 | Dos mesas no pueden compartir codigo_qr (global) | integration (DB-direct, IntegrityError) | `uv run pytest tests/test_domain_constraints.py -k qr -x` | ❌ Wave 0 |
| MESA-02 | Mesas demo tienen QR formato GRI-MESA-\d{3} | integration (DB-direct) | `uv run pytest tests/test_seed.py -k formato -x` | ❌ Wave 0 |
| INFR-03 | Migraciones + seed automáticos en boot limpio | scripted (manual acceptance) | `docker compose down -v && docker compose up -d --build && sh scripts/verify_seed.sh` (dentro del contenedor: `docker exec -w /app gri-api sh scripts/verify_seed.sh`) | ❌ Wave 0 (script) |
| (impl) | State machines: transiciones válidas pasan, inválidas y terminales rechazadas | unit (puro) | `uv run pytest tests/test_state_machines.py -x` | ❌ Wave 0 |
| (impl) | Una sesión activa por mesa (unique generado) | integration (DB-direct) | `uv run pytest tests/test_domain_constraints.py -k sesion -x` | ❌ Wave 0 |
| (impl) | CHECKs: estrellas 1-5, cantidad>0 | integration (DB-direct) | `uv run pytest tests/test_domain_constraints.py -k check -x` | ❌ Wave 0 |

Nota: los endpoints de dominio NO existen hasta Phase 4-6 — por eso no hay tests HTTP de dominio en esta fase. La suite existente (34 tests de Phase 1-2) debe seguir verde (regression gate).

### Sampling Rate
- **Per task commit:** `uv run pytest tests/test_state_machines.py -x` (models/SM tasks) o `uv run pytest tests/test_seed.py tests/test_domain_constraints.py -x` (seed/constraint tasks)
- **Per wave merge:** `uv run pytest` (suite completa — incluye los 34 de Phase 1-2 como regression)
- **Phase gate:** suite completa verde + `verify_seed.sh` ALL CHECKS PASSED antes de `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/conftest.py` — fixture `db_session` (asyncmy → localhost:3306) + refactor menor del parser .env a helper compartido
- [ ] `backend/tests/test_state_machines.py` — unitarios state machines (REQ: impl/PEDI-03 futuro, MESA-04 futuro)
- [ ] `backend/tests/test_seed.py` — PLAT-04 (contenido, idempotencia, gate)
- [ ] `backend/tests/test_domain_constraints.py` — MESA-02 + CHECKs + unique sesión
- [ ] `backend/scripts/verify_seed.sh` — INFR-03 aceptación manual
- Framework install: ninguna (pytest/pytest-asyncio/httpx ya presentes)

---

## Sources

### Primary (HIGH confidence — verified in repo this session)
- `backend/alembic/env.py` + `backend/alembic/versions/0001_initial.py` — patrón Alembic async YA funcionando; precedente migración a mano con nombres explícitos; nota drop_table-vs-drop_index
- `backend/Dockerfile` línea 44 — `CMD ["sh", "-c", "alembic upgrade head && uvicorn ..."]` — INFR-03 migraciones YA automática
- `backend/app/core/config.py` línea 28 — `DEMO_MODE: bool = False` ya definido (inert)
- `backend/app/main.py` — lifespan con `ensure_super_admin` — el punto de inserción del seed
- `backend/app/services/bootstrap.py` — patrón idempotente startup (select-before-insert)
- `backend/app/models/{base,usuario,restaurante}.py` + `deps/auth.py` — Base compartido, patrón Enum + nullable FK, TenantScope que Phase 4-6 consumirá
- `backend/tests/conftest.py` — patrón HTTP + lectura manual de .env (base para db_session fixture)
- `docker-compose.yml` — DEMO_MODE pasado al api; MySQL 8.4 utf8mb4 -05:00; puerto 3306 publicado (dev) — DB-direct tests posibles
- `.planning/research/ARCHITECTURE.md` — Patterns 1/4/5 (multi-tenant, QR estable, state machines), data model, anti-patterns
- `.planning/research/PITFALLS.md` — P1 (slot reservas), P2 (estado almacenado autoritativo), P4 (referencia idempotente), P6 (sesion_mesa + unique activa), "Looks Done But Isn't" seed check
- `.planning/phases/02-.../02-RESEARCH.md` + `02-02-SUMMARY.md` — decisiones locked Phase 2, patrón TenantScope a repetir, lección .local vs .dev

### Secondary (MEDIUM-HIGH confidence — training data estable, verificación empírica recomendada)
- MySQL CHECK constraint enforcement desde 8.0.16 (release notes MySQL) — **los tests de constraint de esta fase lo verifican empíricamente contra el 8.4 real**
- MySQL unique index ignora filas con NULL en cualquier columna (semántica SQL estándar) — base del Pattern 5; **verificado empíricamente por test**
- SQLAlchemy `Computed` para columnas generadas + render Alembic — API estable desde 1.3/1.4
- `Numeric(10,2)` ↔ MySQL `DECIMAL(10,2)` ↔ Python `Decimal` vía asyncmy — mapeo documentado SQLAlchemy, estable 15+ años
- Pydantic v2 serializa `Decimal` como string en JSON — confirmar en Phase 4 (Open Question #5)

### Tertiary (LOW confidence — none critical)
- Ninguna claim crítica depende de fuente no verificada. Los dos puntos MEDIUM-HIGH anteriores tienen verificación empírica integrada en los tests de la propia fase (si el comportamiento difiere, el test falla — no pasa desapercibido).

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — cero dependencias nuevas; todo ya instalado y verificado en repo
- Architecture (schema + state machines + seed): HIGH — patrones locked en research previo + precedentes de código leídos esta sesión
- Constraints MySQL (CHECK, NULL-unique, Computed): MEDIUM-HIGH — semántica estable; verificación empírica embebida en tests de la fase
- Seed content: MEDIUM — prescrito por el researcher; ajustable sin impacto estructural

**Research date:** 2026-08-13
**Valid until:** 2026-09-13 (estable — sin dependencias nuevas ni fuentes externas volátiles)
