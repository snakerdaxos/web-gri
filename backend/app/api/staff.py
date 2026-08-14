"""Staff router — operational reads + mesa state writes for the panel admin
(ADMN-01 + ADMN-02 + RESV-05 + MESA-04).

Separated from /admin (platform ops) per the research convention: /staff holds
the endpoints the panel dashboard consumes (mesas, stats, reservas del día,
mesa state transitions; pedidos follow in Phase 6).

Role matrix, enforced via get_tenant_scope (no require_roles needed — the
scope dep already rejects cliente with 403):

| Endpoint                    | Allowed roles               | Denied ->                              |
|-----------------------------|-----------------------------|----------------------------------------|
| GET  /staff/mesas           | staff (any) + super_admin*  | 401 (no token) / 403 (cliente)         |
| GET  /staff/stats           | staff (any) + super_admin*  | 401 / 403 (same)                       |
| GET  /staff/reservas        | staff (any) + super_admin*  | 401 / 403 / 400 / 404 (same rules)     |
| POST /staff/mesas/{id}/estado | staff (any) + super_admin* | 401 / 403 / 404 / 409                  |
|                             |                             | 400 (super_admin sin ?restaurante_id=) |
|                             |                             | 404 (restaurante/mesa inexistente/ajena)|
|                             |                             | 409 (transición MESA_TRANSITIONS inválida)|
| POST /staff/mesas           | admin_rest. + super_admin*  | 403 (mesero/cocina) / 409 (numero dup) |
| PATCH /staff/mesas/{id}     | admin_rest. + super_admin*  | 403 / 404 / 409 / 422 (body vacío)    |

* super_admin MUST pass ?restaurante_id= (a hint, validated 404-if-unknown);
  for staff the param is IGNORED — the tenant always comes from the token
  (T-04-02, mirrored from admin_service.get_restaurante_for_staff).

Existence hiding cross-tenant (AUTH-04 style): una mesa de OTRO tenant es
indistinguible de una mesa inexistente → 404 (nunca 403, nunca 200).
"""

import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_session
from app.core.state_machines import TransicionInvalidaError
from app.deps.auth import (
    CurrentUser,
    TenantScope,
    get_current_user,
    get_tenant_scope,
    require_roles,
)
from app.models.usuario import RolUsuario
from app.schemas.cliente import ClienteResumen
from app.schemas.dashboard import DashboardStats
from app.schemas.menu import (
    CategoriaCreate,
    CategoriaStaff,
    CategoriaUpdate,
    ProductoCreate,
    ProductoStaff,
    ProductoUpdate,
)
from app.schemas.mesa import (
    MesaCreate,
    MesaEstadoUpdate,
    MesaRead,
    MesaUpdate,
)
from app.schemas.pedido import PedidoEstadoUpdate, PedidoStaffRead
from app.schemas.reserva import ReservaRead
from app.services import pedido_service, staff_service

router = APIRouter(prefix="/staff", tags=["staff"])

# Writes de menú/mesas (Phase 8): solo admin_restaurante/super_admin — los
# reads de menú/clientes/reportes quedan abiertos a todo el staff (un mesero
# ver el menú o los reportes es correcto; la configuración es del admin).
_staff_write_roles = Depends(
    require_roles(RolUsuario.admin_restaurante, RolUsuario.super_admin)
)


@router.get("/mesas", response_model=list[MesaRead])
async def list_mesas(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """Mesa map for the caller's tenant (ADMN-02), ordered by numero."""
    mesas = await staff_service.list_mesas(session, scope, restaurante_id)
    return [MesaRead.model_validate(m) for m in mesas]


@router.get("/stats", response_model=DashboardStats)
async def get_stats(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """Dashboard counts for the caller's tenant (ADMN-01)."""
    return await staff_service.get_stats(session, scope, restaurante_id)


@router.get("/reservas", response_model=list[ReservaRead])
async def list_reservas(
    fecha: dt.date | None = Query(
        default=None, description="Default: hoy (computado DB-side)."
    ),
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """RESV-05 (ver): reservas del día del caller's tenant, con joins display
    (restaurante_nombre, mesa_numero). Incluye canceladas (el campo estado
    discrimina). Orden por hora_inicio."""
    return await staff_service.list_reservas_by_fecha(
        session, scope, restaurante_id, fecha
    )


@router.post("/mesas/{mesa_id}/estado", response_model=MesaRead)
async def set_mesa_estado(
    mesa_id: int,
    body: MesaEstadoUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """RESV-05 (marcar) + MESA-04: transicionar el estado de una mesa.

    Caso de uso principal: el cliente llega y el admin marca la mesa
    ocupada (reservada→ocupada, o disponible→ocupada para walk-ins). El
    ciclo sigue con ocupada→limpieza→disponible.

    - 200 MesaRead actualizada (transición válida en MESA_TRANSITIONS).
    - 404 mesa inexistente O de otro tenant (existence hiding).
    - 409 transición inválida (ej. limpieza→ocupada) — el dominio
      (``TransicionInvalidaError``) no decide códigos HTTP; el router mapea.
    """
    try:
        mesa = await staff_service.set_mesa_estado(
            session, scope, mesa_id, body, restaurante_id
        )
    except TransicionInvalidaError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Transición de estado no permitida: {exc}",
        ) from exc
    return MesaRead.model_validate(mesa)


# --- Phase 8 (MESA-01): mesas CRUD con QR determinista --------------------------


@router.post("/mesas", response_model=MesaRead, status_code=status.HTTP_201_CREATED)
async def create_mesa(
    body: MesaCreate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MESA-01 (crear): mesa del tenant con codigo_qr autogenerado
    determinista ``GRI-MESA-R{rid}-{numero:03d}`` (jamás input del cliente)
    y estado ``disponible``.

    - 201 MesaRead (QR incluido — el panel lo imprime con qr_flutter).
    - 409 numero duplicado en el tenant (uq_mesa_restaurante_numero).
    - 400 super_admin sin ?restaurante_id= / 404 restaurante inexistente.
    - 403 mesero/cocina/cliente (solo admin_restaurante/super_admin).
    """
    return await staff_service.create_mesa(session, scope, body, restaurante_id)


@router.patch("/mesas/{mesa_id}", response_model=MesaRead)
async def update_mesa(
    mesa_id: int,
    body: MesaUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MESA-01 (editar): numero/capacidad (parcial). Si ``numero`` cambia, el
    codigo_qr se REGENERA al nuevo número — el QR impreso anterior queda
    obsoleto (el form del panel lo advierte antes de aplicar).

    - 200 MesaRead actualizada (QR regenerado si tocó numero).
    - 404 mesa inexistente O de otro tenant (existence hiding).
    - 409 numero duplicado / 422 body vacío / 403 mesero/cocina.
    """
    return await staff_service.update_mesa(
        session, scope, mesa_id, body, restaurante_id
    )


# --- PEDI-06 + PEDI-03/05: cola de pedidos + transiciones (Phase 6) ----------


@router.get("/pedidos", response_model=list[PedidoStaffRead])
async def list_pedidos_cola(
    activos: bool = Query(
        default=True,
        description="Solo ?activos=true está soportado en v1 (la cola "
        "excluye terminales pagado/rechazado).",
    ),
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """PEDI-06: cola de pedidos activos del tenant (FIFO por etapa de
    preparación: FIELD(estado,'enviado','aceptado','en_preparacion',
    'servido'), created_at ASC) con items, total, notas, usuario_nombre y el
    badge solicita_cuenta (PAGO-01).

    - 400 super_admin sin ?restaurante_id= (patrón list_mesas).
    - 403 cliente (get_tenant_scope).
    - Cross-tenant: ausente de la lista (existence hiding).
    """
    if not activos:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Solo ?activos=true está soportado en v1",
        )
    return await pedido_service.cola_activos(session, scope, restaurante_id)


@router.post("/pedidos/{pedido_id}/estado", response_model=PedidoStaffRead)
async def set_pedido_estado(
    pedido_id: int,
    body: PedidoEstadoUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    user: CurrentUser = Depends(get_current_user),
):
    """PEDI-03/05: avanzar el estado de un pedido (matriz rol×transición).

    - 200 PedidoStaffRead (transición válida + rol autorizado).
    - 404 pedido inexistente O de otro tenant (existence hiding).
    - 409 transición inválida (PEDIDO_TRANSITIONS) — evaluada ANTES que la
      matriz de roles (un rol no autorizado con salto inválido recibe 409).
    - 403 rol no autorizado para ESA transición (mesero solo puede servido).
    """
    try:
        return await pedido_service.transicionar(
            session, scope, user, pedido_id, body.estado, restaurante_id
        )
    except TransicionInvalidaError as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            f"Transición de estado no permitida: {exc}",
        ) from exc


# --- Phase 8 (MENU-01/02): menú CRUD + staff read ------------------------------


@router.get("/menu", response_model=list[CategoriaStaff])
async def get_menu(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """MENU-01/02 (ver): menú completo del tenant para el panel — INCLUYE
    inactivos y agotados con sus flags (el staff ve TODO; /public filtra).

    Read abierto a todo el staff (mesero/cocina incluidos).

    - 400 super_admin sin ?restaurante_id=; 404 restaurante desconocido.
    - 403 cliente (get_tenant_scope).
    """
    return await staff_service.get_menu_staff(session, scope, restaurante_id)


@router.post(
    "/categorias", response_model=CategoriaStaff, status_code=status.HTTP_201_CREATED
)
async def create_categoria(
    body: CategoriaCreate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MENU-01 (crear): categoría del tenant.

    - 201 CategoriaStaff (id/nombre/orden/activo=true, productos=[]).
    - 400 super_admin sin ?restaurante_id= / 404 restaurante inactivo.
    - 403 mesero/cocina/cliente (solo admin_restaurante/super_admin).
    - 409 nombre duplicado en el tenant (uq_categoria_restaurante_nombre).
    """
    return await staff_service.create_categoria(
        session, scope, body, restaurante_id
    )


@router.patch("/categorias/{categoria_id}", response_model=CategoriaStaff)
async def update_categoria(
    categoria_id: int,
    body: CategoriaUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MENU-01 (editar): nombre/orden/activo (parcial — PATCH). ``activo=false``
    es el soft-delete: desaparece de /public, la fila y su historia viven.

    - 200 CategoriaStaff actualizada.
    - 404 categoría inexistente O de otro tenant (existence hiding).
    - 409 nombre duplicado / 403 mesero/cocina / 400 super_admin sin param.
    """
    return await staff_service.update_categoria(
        session, scope, categoria_id, body, restaurante_id
    )


@router.post(
    "/productos", response_model=ProductoStaff, status_code=status.HTTP_201_CREATED
)
async def create_producto(
    body: ProductoCreate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MENU-02 (crear): producto bajo una categoría DEL tenant.

    - 201 ProductoStaff (precio float en la respuesta).
    - 422 precio<=0 (gt=0 server-side) / campos fuera de rango.
    - 404 categoría inexistente O de otro tenant (existence hiding).
    - 403 mesero/cocina / 400 super_admin sin param.
    """
    return await staff_service.create_producto(
        session, scope, body, restaurante_id
    )


@router.patch("/productos/{producto_id}", response_model=ProductoStaff)
async def update_producto(
    producto_id: int,
    body: ProductoUpdate,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
    _: CurrentUser = _staff_write_roles,
):
    """MENU-02 (editar): nombre/descripción/precio/imagen_url/disponible/activo
    (parcial). Semántica de los toggles: ``disponible=false`` = agotado
    (SIGUE en /public con su flag); ``activo=false`` = soft-delete
    (DESAPARECE de /public).

    - 200 ProductoStaff actualizada (precio float).
    - 404 producto inexistente O de otro tenant / 422 precio<=0.
    - 403 mesero/cocina / 400 super_admin sin param.
    """
    return await staff_service.update_producto(
        session, scope, producto_id, body, restaurante_id
    )


# --- Phase 8 (ADMN-03): clientes del restaurante --------------------------------


@router.get("/clientes", response_model=list[ClienteResumen])
async def list_clientes(
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff (el "
        "tenant sale del token).",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """ADMN-03 (lista): clientes del tenant = usuarios CON pedidos ahí
    (JOIN pedido→usuario; quien solo reservó NO aparece — decisión v1).
    num_pedidos + total_gastado (JSON number) + ultimo_pedido_at, orden por
    total_gastado DESC. count/SUM sobre TODOS los estados.

    Read abierto a todo el staff. 400 super_admin sin ?restaurante_id= /
    404 restaurante desconocido / 403 cliente.
    """
    return await staff_service.list_clientes(session, scope, restaurante_id)


@router.get(
    "/clientes/{usuario_id}/historial", response_model=list[PedidoStaffRead]
)
async def get_cliente_historial(
    usuario_id: int,
    restaurante_id: int | None = Query(
        default=None,
        description="Requerido para super_admin; IGNORADO para staff.",
    ),
    session: AsyncSession = Depends(get_session),
    scope: TenantScope = Depends(get_tenant_scope),
):
    """ADMN-03 (historial): pedidos del usuario EN el tenant (todos los
    estados, newest first) reusando el schema F6 — items con nombre,
    mesa_numero, usuario_nombre.

    - 404 si el usuario no tiene pedidos en el tenant (existence hiding
      RELACIONAL — no revela que el usuario_id existe globalmente).
    - 400 super_admin sin ?restaurante_id= / 403 cliente.
    """
    return await staff_service.get_cliente_historial(
        session, scope, usuario_id, restaurante_id
    )
