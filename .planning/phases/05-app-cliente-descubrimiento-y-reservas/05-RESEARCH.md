# Phase 5: App Cliente — Descubrimiento y Reservas - Research

**Researched:** 2026-08-13
**Domain:** FastAPI (public + cliente-scoped endpoints, concurrent reserva creation) + Flutter Web/Mobile app (cliente discovery + reservation flow)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT / this session's decisions)

### Locked Decisions
- **Auto-confirm** — reservas are created directly in `estado = confirmada` (no `pendiente`/approval step). The admin never has to approve. The `pendiente` state still exists in `RESERVA_TRANSITIONS` but is unused in v1. *(User decision this session.)*
- **Anti-concurrencia lives in the DB**: `UNIQUE (mesa_id, fecha, hora_inicio)` + `SELECT ... FOR UPDATE` on the mesa row inside the create-reserva transaction. The race is lost by the DB (IntegrityError → 409), not by app logic. *(From ROADMAP Phase 5 notes + PITFALLS P1.)*
- **App Flutter móvil** lives in `app_cliente/` — same foundation as `panel_admin/` (riverpod 3.4.2 codegen, go_router 17.5.0, dio 5.11.0 QueuedInterceptor, flutter_secure_storage 11.0.0, freezed + json_serializable, flutter_dotenv, intl). **Copy the proven `panel_admin/lib/core/` (`api_client.dart`, `auth_storage.dart`, `theme.dart`, `token_provider.dart`) as the starting point** — it's the identical auth stack, only the screens differ. *(User decision.)*
- **DESARROLLO LOCAL SIN Android SDK** — the machine has no Android SDK. Dev is **web-first** (`flutter run -d chrome`). The scaffold declares `--platforms=android,ios,web` so the mobile build target exists for later, but every iteration runs in Chrome. Widget tests (not integration tests) are the validation surface. *(User decision this session.)*
- **Backend prefixes**: `/public/*` (no auth, restaurant discovery + menu) + `/cliente/*` (auth cliente, reservas + perfil) + **staff extensions on the existing `/staff` router** (`GET /staff/reservas?fecha=`, `POST /staff/mesas/{id}/estado`). No new top-level routers. *(From additional_context.)*
- **MESA-04 simplification v1**: when a reserva is confirmed, the mesa goes `disponible → reservada`. This is a deliberate v1 simplification (a reservada mesa is not yet `ocupada` — that transition happens on arrival, RESV-05). *(From additional_context.)*
- **Perfil PATCH v1**: only `nombre` is editable. `email` is the login key (never editable — changing it breaks the unique login identity). `password` change is **optional**: included only if provided, validated with the same min 8/max 64 rule as `UserCreate`. *(From additional_context.)*

### Claude's Discretion
- **Mesa assignment strategy** for a reserva: automatic (server picks the first mesa with `capacidad >= num_personas` that is free at the requested slot) vs client-chosen. → **Recommendation: AUTOMATIC** (see Concurrency Design §3).
- **Slot granularity** (how to discretize reservation times so `UNIQUE` is sufficient): hourly fixed slots with a 60-minute effective turn for v1, vs free-time with range exclusion. → **Recommendation: HOURLY SLOTS, 60-min turn** for v1 (see Concurrency Design §1).
- **What happens to the reserva when the cliente arrives** (RESV-05 + MESA-04): the admin's "mark mesa as ocupada" action keeps the reserva as-is (the reserva already served its purpose). → **Recommendation: leave the reserva `confirmada`; do NOT add a `completada` state this phase** (the FEATURES.md state machine lists `completada`/`no_show` but v1 doesn't need them — defer to v1.x when no-show tracking is requested). Documented in State Machine Application §2.
- **UI structure of the reserva wizard**: 1 screen with stepped form vs multi-screen flow. → **Recommendation: single Stepper screen** (restaurante → fecha → hora → personas), matching the mockup's `reservar()` hint.

### Deferred Ideas (OUT OF SCOPE)
- **No-show tracking / `no_show` state** — defer to v1.x (requires a cron to expire past-due reservas; no business value in v1 with 1 demo restaurant).
- **Reserva with deposit/garantía** (FEATURES.md Anti-Feature) — out of scope.
- **Cliente-side rebooking/modification** — only create + cancel in v1.
- **Time-zone aware reservations across regions** — Colombia has one TZ (America/Bogota, no DST); the existing `TZ=America/Bogota` in docker-compose already covers this.
- **Waitlist** — v1.x.
- **Push notification of reserva confirmation** — out of scope v1 (NOTF-01 is v2).
- **Calificación display** — REST-01 says rating shows "—" until Phase 9 (CALI-02). The DTO carries a `calificacion: float | None` field; Phase 5 always returns `None` and the UI renders `"–"`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-05 | Cliente puede ver y editar su perfil | New `GET /auth/me` ALREADY EXISTS (Phase 2) for "ver"; new `PATCH /cliente/perfil` (§Endpoint Contract) for "editar" — nombre required, password optional, email immutable. Cliente UI: `features/perfil/perfil_screen.dart` reuses the existing `tokenProvider`. |
| REST-01 | Cliente ve lista de restaurantes activos con nombre, tipo de cocina y calificación | New `GET /public/restaurantes` (no auth) returns `RestauranteRead` + `calificacion: float \| None`. The list query reuses `admin_service.list_restaurantes` (filter `activo=True`) but lives under `/public/*`. Phase 5 always sends `calificacion=None`. Flutter: `features/restaurantes/restaurantes_list_screen.dart` renders the mockup's `.restaurant` card. |
| REST-02 | Cliente ve detalle de restaurante con menú (categorías y productos con precio y descripción) | New `GET /public/restaurantes/{id}` returns restaurante + nested `categorias[] → productos[]`. One query per table (3 total) — no N+1. Flutter: `features/restaurantes/restaurante_detalle_screen.dart` renders categorías as expandable sections. |
| RESV-01 | Cliente reserva mesa indicando fecha, hora y número de personas | New `POST /cliente/reservas`. Body: `{restaurante_id, fecha, hora_inicio, num_personas}`. The server auto-assigns the mesa (Concurrency Design §3). 201 on success. Flutter: `features/reservas/reserva_wizard_screen.dart` (Stepper). |
| RESV-02 | Sistema valida disponibilidad real sin sobre-reservas por concurrencia | **THE critical requirement.** Migration 0003 adds `UNIQUE (mesa_id, fecha, hora_inicio)`; the service does `SELECT … FOR UPDATE` on candidate mesas + `IntegrityError → 409`. Concurrent test mandatory (§Validation Architecture). |
| RESV-03 | Cliente consulta sus reservas (próximas y pasadas) con estado | New `GET /cliente/reservas` returns `[{reserva, restaurante_nombre, mesa_numero, …}]` ordered by `fecha, hora_inicio`. Split client-side into próximas (`fecha >= today`) / pasadas (`fecha < today`). Flutter: `features/reservas/mis_reservas_screen.dart`. |
| RESV-04 | Cliente cancela una reserva futura | New `POST /cliente/reservas/{id}/cancelar`. Validates ownership (`reserva.usuario_id == current_user.id`), validates future (`fecha >= today`), applies `RESERVA_TRANSITIONS` (`confirmada → cancelada`), and **reverts the mesa** to `disponible` if it was `reservada` for this reserva (§State Machine Application). |
| RESV-05 | Admin ve reservas del día + marca mesa ocupada al llegar cliente | Extend `/staff`: new `GET /staff/reservas?fecha=YYYY-MM-DD` (tenant-scoped, existing pattern) + new `POST /staff/mesas/{id}/estado` body `{estado: "ocupada"}`. The latter applies `MESA_TRANSITIONS` (409 on invalid). |
| MESA-04 | Mesa tiene 4 estados con transiciones válidas controladas | `MESA_TRANSITIONS` ALREADY EXISTS (Phase 3). Phase 5 adds the HTTP surface that exercises it: `POST /staff/mesas/{id}/estado` (RESV-05) + the reserva create/cancel side-effects on the mesa state. 409 on invalid transitions. |
</phase_requirements>

## Summary

Phase 5 is the **first client-facing app** and the **first write path on the domain layer** (Phase 4 was read-only). It has three independent workstreams that converge on one user journey (discover → reserve → arrive):

1. **Backend (FastAPI):** zero new Python dependencies — everything reuses the Phase 1–4 stack. The work is (a) **Migration 0003** adding the `UNIQUE (mesa_id, fecha, hora_inicio)` constraint that was deliberately deferred from `models/reserva.py` Phase 3 (see its docstring), (b) a new `/public` router (2 endpoints, no auth), (c) a new `/cliente` router (4 endpoints, `require_roles(cliente)`), and (d) two extensions to the existing `/staff` router (RESV-05). The critical new logic is `reserva_service.crear_reserva()` — a transactional `SELECT … FOR UPDATE` + insert + mesa-state-mutation that loses the race to the DB IntegrityError (PITFALLS P1).
2. **Frontend (Flutter Web first):** a new `app_cliente/` Flutter project, **cloned foundation from `panel_admin/lib/core/`** (api_client, auth_storage, token_provider, theme — identical auth stack), feature-first structure (`features/{auth, restaurantes, reservas, perfil}`). 4-tab bottom navigation matching the `indexcliente.html` mockup verbatim. Login/register → discover list → detalle menú → reserva wizard → mis reservas → perfil.
3. **Concurrency test (the make-or-break):** a pytest test that fires N concurrent `POST /cliente/reservas` for the same mesa/fecha/hora and asserts exactly one succeeds (201) and the rest get 409. Without this, RESV-02 is unverifiable and Phase 5 cannot ship (PITFALLS P1 warning sign #1).

The dominant **technical** risk is the concurrency design — a naive "check then insert" loses the race. The dominant **environmental** risk is the same as Phase 4: Flutter SDK must remain at `C:\src\flutter\bin` (not on global PATH), so every `flutter` command needs `$env:Path += ";C:\src\flutter\bin"`. Chrome is installed; `flutter run -d chrome` works. The app is scaffolded with `--platforms=android,ios,web` but **only web is exercised** during Phase 5 per the locked decision.

**Primary recommendation:** Add Migration 0003 with the slot UNIQUE constraint + a `FOR UPDATE`-gated service; ship `/public`, `/cliente`, and `/staff` extensions mirroring the proven `admin_service.get_restaurante_for_staff` tenant-filter pattern; scaffold `app_cliente/` by copying `panel_admin/lib/core/` and adding 4 feature folders. Pin the cliente web port (`--web-port=5174`) so its CORS origin is deterministic and distinct from the panel's `:5173`.

## Standard Stack

### Backend — additions (zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **SQLAlchemy 2.0 async** (existing) | 2.0.52 | `select(...).with_for_update()` for the reserva transaction | The async `with_for_update()` method is the SQLAlchemy 2.0 async API for `SELECT ... FOR UPDATE`. Works with asyncmy. **Confidence: HIGH** (SQLAlchemy 2.0 official docs — verified in Phase 3 research). |
| **Pydantic v2** (existing) | 2.x | Schema validation + Decimal → str serialization for COP prices | `Producto.precio` is `Numeric(10,2)` → `Decimal`. Pydantic v2 serializes Decimal → JSON string by default. The Dart client parses with `double.parse()`. Document this contract in the schema. **Confidence: HIGH**. |
| **asyncmy** (existing) | 0.2.14 | Row-level locking support | asyncmy fully supports `FOR UPDATE` (it's a server-side feature; the driver just sends the SQL). **Confidence: HIGH**. |

**No new `uv add` needed.** The new code is: (a) `alembic/versions/0003_reserva_unique_slot.py` migration, (b) `app/api/public.py` + `app/api/cliente.py` + extensions to `app/api/staff.py`, (c) `app/services/reserva_service.py` + extensions to `app/services/staff_service.py`, (d) `app/schemas/{reserva,menu,perfil}.py`.

### Frontend — new `app_cliente/` Flutter app

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **flutter_riverpod** | ^3.4.2 | State + DI | Identical to `panel_admin/`. **Confidence: HIGH** (verified Aug 2026, Phase 4). |
| **riverpod_annotation + riverpod_generator + riverpod_lint** (dev) + **custom_lint** (dev) | ^3.x / ^3.x / ^3.x | Codegen + lint | Identical to `panel_admin/`. **Confidence: HIGH**. |
| **dio** | ^5.11.0 | HTTP + QueuedInterceptor (Bearer + refresh-on-401 with Completer) | **Copy `panel_admin/lib/core/api_client.dart` verbatim** — it's the same auth flow against the same `/auth/*` endpoints. **Confidence: HIGH**. |
| **go_router** | ^17.5.0 | Routing + redirect guard + **StatefulShellRoute** (bottom nav with 4 tabs) | Use `StatefulShellRoute.indexedStack` (NOT the plain `ShellRoute` from panel) — bottom nav with sibling branches needs indexed stack so each tab preserves its scroll/state. **Confidence: HIGH** (go_router 17 official). |
| **flutter_secure_storage** | ^11.0.0 | Persist JWT | Identical to `panel_admin/`. **Confidence: HIGH** (Phase 4 verified). |
| **freezed + freezed_annotation + json_serializable + json_annotation + build_runner** (dev) | latest | Immutable DTOs (Restaurante, Producto, Reserva, Mesa) | Identical to `panel_admin/`. **Confidence: HIGH**. |
| **flutter_dotenv** | ^5.2.1 | `API_BASE_URL` + `APP_POLL_SECONDS` | Identical. **Confidence: HIGH**. |
| **intl** | ^0.19.0 | COP currency formatting (`NumberFormat.currency(locale: 'es_CO', symbol: '\$')` → `$ 32.000`) | Critical for menú prices — the mockup shows COP values without decimals. **Confidence: HIGH**. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **Auto mesa assignment** (server picks) | **Client-chosen mesa** from a list of available ones | Client-chosen requires a `GET /public/disponibilidad?restaurante_id=&fecha=&hora=&personas=` endpoint returning candidate mesas, plus UI for the cliente to pick. Auto is simpler (one POST, server decides) and matches the mockup (which has no mesa picker in the wizard). **Default: AUTO**; revisit client-chosen in v1.x if restaurants complain about which mesa they got. |
| **Hourly slots (60-min turn)** | **Range exclusion (90-min turn, free time)** | Range exclusion requires a `hora_inicio < ? + interval '90' minute AND hora_inicio + interval '90' minute > ?` overlap query inside `FOR UPDATE` — correct but harder to test and the UNIQUE alone won't catch all overlaps. Hourly slots make UNIQUE sufficient. **Default: HOURLY SLOTS** (see Concurrency Design §1). |
| **`StatefulShellRoute.indexedStack`** (bottom nav) | **Plain `ShellRoute`** (panel-style) | Panel uses `ShellRoute` because it has ONE active branch (sidebar). Cliente has 4 SIBLING tabs — switching between them must preserve each tab's state (scroll position, loaded data). `StatefulShellRoute.indexedStack` is the official go_router answer. **Default: StatefulShellRoute.indexedStack.** |
| **Single reserva wizard screen (Stepper)** | **Multi-screen flow** (5 pushed routes) | Multi-screen is more "app-like" but adds back-navigation complexity. The mockup's `reservar()` is one entry point. A single `Stepper` widget (Material) handles state cleanly. **Default: single Stepper.** |
| **Copy `panel_admin/lib/core/`** | **Re-implement auth stack** | The auth stack (api_client, auth_storage, token_provider) is **identical** for both apps — same `/auth/login`, `/auth/refresh`, `/auth/me`, same QueuedInterceptor + Completer pattern, same flutter_secure_storage. Copying is the DRY choice; re-implementing would diverge over time. **Default: COPY**, then diverge only when a cliente-specific need appears (none foreseen this phase). |

**Installation (app_cliente/):**

```powershell
cd C:\Users\valle\Documents\cel
$env:Path += ";C:\src\flutter\bin"   # SDK NOT on global PATH (Phase 4 lesson)
flutter create --org com.gri --project-name gri_cliente --platforms=android,ios,web app_cliente

cd app_cliente
flutter pub add `
  flutter_riverpod:^3.4.2 riverpod_annotation:^3.0.0 `
  dio:^5.11.0 go_router:^17.5.0 `
  flutter_secure_storage:^11.0.0 `
  freezed_annotation json_annotation flutter_dotenv:^5.2.1 intl:^0.19.0

flutter pub add --dev `
  build_runner riverpod_generator:^3.0.0 freezed json_serializable riverpod_lint:^3.0.0 custom_lint

# Copy the proven foundation from the panel (identical auth stack)
Copy-Item -Path ..\panel_admin\lib\core -Destination lib\core -Recurse
# Then edit lib/core/env.dart to change POLL default + add RESERVA_TURN_MIN if desired

dart run build_runner build
```

**Version verification (already done in Phase 4 — Aug 2026):**

| Package | Verified | Published |
|---------|----------|-----------|
| flutter_riverpod 3.4.2 | pub.dev | ~Jul 28 2026 |
| go_router 17.5.0 | pub.dev | ~Aug 10 2026 |
| flutter_secure_storage 11.0.0 | pub.dev | ~Aug 6 2026 |
| dio 5.11.0 | STACK.md (verified Aug 2026) | Aug 2026 |
| intl 0.19.0 | pub.dev | stable |

## Architecture Patterns

### Recommended Project Structure (app_cliente/)

Feature-first, mirroring `panel_admin/` for the `core/` layer and adding 4 feature folders for the 4 bottom-nav tabs:

```
app_cliente/
├── lib/
│   ├── main.dart                         # ProviderScope + dotenv.load + GriClienteApp
│   ├── app.dart                          # GoRouter (redirect + StatefulShellRoute.indexedStack, 4 branches)
│   ├── core/                             # COPIED from panel_admin/lib/core/ (identical auth stack)
│   │   ├── api_client.dart               # Dio + AuthInterceptor (QueuedInterceptor + Completer refresh)
│   │   ├── auth_storage.dart             # flutter_secure_storage wrapper
│   │   ├── token_provider.dart           # AuthState @Riverpod(keepAlive: true)
│   │   ├── env.dart                      # API_BASE_URL + (optional) poll seconds
│   │   └── theme.dart                    # GriColors — palette DIFFERS from panel (mockup has #f7f7f7 bg vs panel #f5f6f8; copy structure, swap constants)
│   ├── models/
│   │   ├── user.dart                     # freezed (copied from panel)
│   │   ├── token_pair.dart               # freezed (copied)
│   │   ├── restaurante.dart              # freezed + calificacion: double?
│   │   ├── producto.dart                 # freezed + precio: double (parsed from server's Decimal string)
│   │   ├── categoria.dart                # freezed + productos: List<Producto>
│   │   ├── restaurante_detalle.dart      # freezed: restaurante + categorias[]
│   │   ├── reserva.dart                  # freezed + EstadoReserva enum
│   │   └── reserva_create.dart           # freezed: restaurante_id, fecha, hora_inicio, num_personas
│   └── features/
│       ├── auth/
│       │   ├── login_screen.dart         # + link to register
│       │   ├── register_screen.dart      # AUTH-01 UI (backend exists from Phase 2)
│       │   └── auth_controller.dart      # AsyncNotifier for login + register
│       ├── restaurantes/                 # tab "Restaurantes" + home "Inicio"
│       │   ├── home_screen.dart          # welcome + 1st restaurante card + "Mis reservas" shortcut (matches mockup)
│       │   ├── restaurantes_list_screen.dart
│       │   ├── restaurante_detalle_screen.dart   # GET /public/restaurantes/{id} — menú por categoría
│       │   ├── restaurantes_provider.dart        # FutureProvider<List<Restaurante>>
│       │   └── restaurante_detalle_provider.dart # FutureProvider.family<RestauranteDetalle, int>
│       ├── reservas/                     # tab "Reservas"
│       │   ├── mis_reservas_screen.dart  # split próximas / pasadas (RESV-03)
│       │   ├── reserva_wizard_screen.dart# Stepper: restaurante→fecha→hora→personas→confirmar (RESV-01)
│       │   ├── reservas_provider.dart    # FutureProvider<List<Reserva>>
│       │   └── reserva_controller.dart   # AsyncNotifier for crear / cancelar
│       └── perfil/                       # tab "Perfil"
│           ├── perfil_screen.dart        # GET /auth/me + PATCH /cliente/perfil (AUTH-05)
│           └── perfil_controller.dart
├── assets/
│   └── .env                              # API_BASE_URL=http://localhost:8000 (gitignored)
├── test/
│   ├── auth/login_register_test.dart
│   ├── restaurantes/list_test.dart
│   ├── reservas/wizard_form_test.dart
│   ├── reservas/mis_reservas_render_test.dart
│   └── perfil/perfil_edit_test.dart
└── pubspec.yaml
```

### Pattern 1: StatefulShellRoute.indexedStack for the 4-tab bottom nav

**What:** A `StatefulShellRoute.indexedStack` with 4 branches (Inicio, Restaurantes, Reservas, Perfil), each branch preserving its own navigator state. The bottom nav switches branches via `navigationShell.goBranch(index)`.

**When to use:** Always for this app — it's the official go_router 17 answer to "bottom nav with state preservation per tab".

**Example:**
```dart
// app.dart — Source: go_router 17 StatefulShellRoute.indexedStack official doc
final goRouter = GoRouter(
  refreshListenable: authListenable,
  redirect: (context, state) {
    final loggedIn = ref.read(authStateProvider).value != null;
    final onAuth = state.matchedLocation.startsWith('/login') ||
                   state.matchedLocation.startsWith('/register');
    if (!loggedIn && !onAuth) return '/login';
    if (loggedIn && onAuth) return '/inicio';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/inicio', builder: (_, _) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/restaurantes', builder: (_, _) => const RestaurantesListScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/reservas', builder: (_, _) => const MisReservasScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/perfil', builder: (_, _) => const PerfilScreen())]),
      ],
    ),
  ],
);
```

The `AppShell` renders the mockup's bottom nav (fixed, max-width 480px like the `.app` container) + the `navigationShell` child above it.

### Pattern 2: Cliente auth dependency (distinct from staff's `get_tenant_scope`)

**What:** `/cliente/*` endpoints use `get_current_user` + `require_roles(RolUsuario.cliente)`. They MUST NOT use `get_tenant_scope` (which explicitly 403s clientes — see `deps/auth.py` line 122). The cliente has no `restaurant_id` in their token; their "tenant" is derived from the resource they're operating on (the reserva's `restaurant_id`).

**When to use:** Every `/cliente/*` endpoint.

**Example:**
```python
# app/api/cliente.py
from app.deps.auth import CurrentUser, get_current_user, require_roles
from app.models.usuario import RolUsuario

@router.post("/reservas", response_model=ReservaRead, status_code=201)
async def crear_reserva(
    body: ReservaCreate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    return await reserva_service.crear_reserva(session, user.id, body)
```

Ownership check happens inside the service for cancel: `if reserva.usuario_id != user.id: raise 404` (existence hiding — never 403, same convention as AUTH-04 cross-tenant).

### Pattern 3: Concurrent-safe reserva creation (THE critical pattern)

**What:** A single transactional service method that (a) `FOR UPDATE`-locks candidate mesas, (b) filters by capacity and free-slot, (c) inserts the reserva, (d) mutates the chosen mesa's state — all inside one `async with session.begin()` block. The DB UNIQUE is the last-line defense: if two transactions race past the `SELECT`, exactly one INSERT succeeds and the other raises `IntegrityError` → 409.

**When to use:** Every `POST /cliente/reservas`.

**Example:**
```python
# app/services/reserva_service.py — conceptual shape
# Source: SQLAlchemy 2.0 async with_for_update + PITFALLS P1
from sqlalchemy.exc import IntegrityError

async def crear_reserva(session, usuario_id, body):
    # 1. Validate restaurante exists & active (404 if not — public-facing, hide existence).
    restaurante = await session.get(Restaurante, body.restaurante_id)
    if restaurante is None or not restaurante.activo:
        raise HTTPException(404, "Restaurante no encontrado")

    # 2. Validate future date + slot granularity (Concurrency Design §1).
    _validate_slot(body.fecha, body.hora_inicio)  # raises 400 on past / non-:00 minute

    # 3. FOR UPDATE candidate mesas — locks rows until commit.
    stmt = (
        select(Mesa)
        .where(
            Mesa.restaurant_id == body.restaurante_id,
            Mesa.capacidad >= body.num_personas,
        )
        .order_by(Mesa.numero)
        .with_for_update()  # SELECT ... FOR UPDATE — serializes per-mesa
    )
    candidate_mesas = (await session.execute(stmt)).scalars().all()
    if not candidate_mesas:
        raise HTTPException(409, "No hay mesas con capacidad suficiente")

    # 4. Find first candidate with NO active reserva on this slot.
    chosen = None
    for mesa in candidate_mesas:
        existing = await session.execute(
            select(Reserva).where(
                Reserva.mesa_id == mesa.id,
                Reserva.fecha == body.fecha,
                Reserva.hora_inicio == body.hora_inicio,
                Reserva.estado != EstadoReserva.cancelada,
            )
        )
        if existing.scalar_one_or_none() is None:
            chosen = mesa
            break
    if chosen is None:
        raise HTTPException(409, "No hay mesas disponibles en ese horario")

    # 5. Mutate mesa state (MESA-04: disponible → reservada; idempotent if already reservada).
    validar_transicion("mesa", chosen.estado, EstadoMesa.reservada)  # raises -> 409
    chosen.estado = EstadoMesa.reservada

    # 6. Insert reserva (estado=confirmada — auto-confirm locked decision).
    reserva = Reserva(
        restaurant_id=body.restaurante_id,
        usuario_id=usuario_id,
        mesa_id=chosen.id,
        fecha=body.fecha,
        hora_inicio=body.hora_inicio,
        num_personas=body.num_personas,
        estado=EstadoReserva.confirmada,
    )
    session.add(reserva)

    # 7. Commit — UNIQUE(mesa_id, fecha, hora_inicio) catches any race that slipped through.
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, "La mesa acaba de ser reservada — intenta otro horario")
    await session.refresh(reserva)
    return reserva
```

**Critical details:**
- `with_for_update()` on asyncmy/MySQL uses `SELECT ... FOR UPDATE` — row-level lock until COMMIT/ROLLBACK. Two concurrent transactions selecting the same mesa serialize.
- The `IntegrityError` handler is **defense-in-depth**, not the primary defense. The `FOR UPDATE` + existence check is the primary path. The UNIQUE catches the rare race where two txns picked different candidate mesas but one of them was already reserved between the SELECT and the INSERT in a previous (aborted) tx — belt and suspenders.
- `validar_transicion("mesa", ...)` raises `TransicionInvalidaError` — the router catches that exception type and maps to 409 (same as Phase 3 unit-test pattern).

### Pattern 4: Polling-free cliente reads (FutureProvider, not Stream)

**What:** Unlike `panel_admin` (which polls `/staff/mesas` every 10s), `app_cliente` reads are **imperative fetches** triggered by navigation and pull-to-refresh. No polling. The restaurante list and mis-reservas only change when the user acts — `FutureProvider` (not Stream) is the right primitive.

**When to use:** All cliente reads. Polling returns only if Phase 7 adds live reserva-status updates (deferred).

**Why:** Polling the discovery list burns mobile data for content that changes ~never (the restaurante doesn't change while the cliente browses). The panel polls because staff leave the dashboard open all day; clientes open the app, look, decide, close.

### Anti-Patterns to Avoid

- **Check-then-insert WITHOUT `FOR UPDATE` or UNIQUE:** the textbook race condition (PITFALLS P1). The "it works in my manual test" trap.
- **Using `get_tenant_scope` for `/cliente/*` endpoints:** `deps/auth.py` explicitly 403s clientes there — every `/cliente/*` endpoint would 403. Use `get_current_user` + `require_roles(RolUsuario.cliente)` instead.
- **Mutating the mesa state OUTSIDE the reserva transaction:** if the mesa is marked `reservada` but the reserva INSERT fails, the mesa is stuck. Do both in one `session.begin()` block.
- **Reverting mesa to `disponible` on cancel WITHOUT checking it's `reservada`:** if the mesa was already promoted to `ocupada` (cliente arrived, RESV-05), cancelling the reserva must NOT downgrade the mesa. Only revert `reservada → disponible`, never `ocupada → disponible` (that's an invalid transition anyway — `MESA_TRANSITIONS` only allows `ocupada → limpieza`).
- **Returning `Decimal` directly in JSON:** Pydantic v2 serializes Decimal → JSON string (e.g., `"32000.00"`). The Dart client must `double.parse(serverString)`. Document this in the schema OR coerce to float server-side via `field_serializer`. **Recommendation: coerce server-side** (`precio: float` in the schema with a serializer) so the Dart side gets a clean `double`.
- **Hardcoding the cliente web port:** pin `--web-port=5174` (distinct from panel's 5173) and add `http://localhost:5174` to `CORS_ORIGINS` in `.env`. Otherwise the port floats and CORS breaks.
- **`Padding` of 0 / losing the 480px mobile frame in web:** the mockup is mobile (`max-width: 480px`). Wrap the body in a `Center` + `ConstrainedBox(maxWidth: 480)` so the web preview looks like a phone, not a stretched desktop layout.

## Concurrency Design (the make-or-break)

This is the single most important design decision of Phase 5. PITFALLS P1 (race condition in reservas) is the explicit trap. The design MUST make double-booking impossible under concurrent requests.

### §1. Slot granularity — why hourly slots (60-min turn) for v1

**The problem:** A "reserva" occupies a mesa for a duration (the "turn"). If turn = 90 min and the cliente reserves 19:00, the mesa is busy 19:00–20:30. A second cliente reserving 20:00 for the same mesa **overlaps** (20:00 is within 19:00–20:30), but a simple `UNIQUE (mesa_id, fecha, hora_inicio)` does NOT catch it — the `hora_inicio` values (19:00 vs 20:00) are different.

**Two honest options:**

| Option | How UNIQUE catches overlap | Complexity | When to upgrade |
|--------|----------------------------|------------|-----------------|
| **A. Hourly slots, 60-min turn (RECOMMENDED v1)** | Cliente picks from a fixed dropdown of `:00`-minute times (12:00, 13:00, …, 21:00). Turn = exactly 60 min. Two reservas on the same mesa/fecha can ONLY be at different `:00` hours → no overlap possible. `UNIQUE (mesa_id, fecha, hora_inicio)` is exact and sufficient. | LOW — one UNIQUE index, no range query. App validation rejects `:30` (or any non-`:00`) minutes. | When a restaurant wants 90-min turns → upgrade to Option B (range exclusion). |
| **B. Range exclusion, free time, 90-min turn** | Cliente picks any time. Service runs `SELECT 1 FROM reserva WHERE mesa_id=? AND fecha=? AND estado!=cancelada AND hora_inicio < ? + INTERVAL 90 MINUTE AND hora_inicio + INTERVAL 90 MINUTE > ?` inside `FOR UPDATE`. UNIQUE alone is NOT sufficient. | MEDIUM — range query + FOR UPDATE + still keep UNIQUE as exact-collision defense. | When business needs flexible times / variable turns. |

**v1 recommendation: Option A.** It's the simplest design where the DB constraint alone proves no-overlap. The mockup shows "7:00 PM" (a `:00` time), so hourly slots match the existing UX. The fixed dropdown also improves the wizard UX (no free-text time picker, no invalid times). Document the 60-min turn as a v1 limitation in the Open Questions; the migration to Option B is additive (drop nothing, add a range query).

### §2. Why UNIQUE + FOR UPDATE together (belt and suspenders)

- **`FOR UPDATE`** serializes concurrent transactions that select the same mesa row. While tx1 holds the lock, tx2's `SELECT … FOR UPDATE` blocks until tx1 commits/rolls back. Then tx2 re-reads and sees tx1's reserva → the existence check rejects it.
- **`UNIQUE (mesa_id, fecha, hora_inicio)`** is the last-line defense. If somehow (e.g., two txns picked DIFFERENT candidate mesas but one was already reserved between their SELECT and INSERT in a third aborted tx), the INSERT raises `IntegrityError` → 409.

Both layers are needed: `FOR UPDATE` prevents the race from reaching the INSERT in the common case; UNIQUE makes the INSERT safe even if it does.

### §3. Mesa assignment — why automatic (server picks) for v1

**The flow:** Cliente POSTs `{restaurante_id, fecha, hora_inicio, num_personas}`. The server:
1. `SELECT mesas WHERE restaurant_id=? AND capacidad >= num_personas ORDER BY numero FOR UPDATE`
2. Iterates candidates, picks the FIRST with no active reserva on that slot
3. Inserts the reserva against that mesa
4. Returns the chosen mesa in the response

**Why auto:**
- Matches the mockup (the wizard has no mesa picker — just fecha/hora/personas).
- Simpler API: ONE endpoint (`POST /cliente/reservas`) does availability + assignment + creation atomically. No separate `GET /disponibilidad` + client round-trip + race window.
- Fairness: `ORDER BY numero` means mesa #1 fills before mesa #2 — predictable for the restaurante.
- Avoids the "cliente picks mesa 5, hits confirm, server says 'just taken'" UX loop.

**Optional v1.x upgrade:** `GET /public/disponibilidad?restaurante_id=&fecha=&hora_inicio=&personas=` returning `[{mesa_id, numero, capacidad}]` for a client-chosen flow. Phase 5 ships auto only.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Concurrent-safe reserva | "Check then insert" with a `threading.Lock` or app-level mutex | DB `FOR UPDATE` + `UNIQUE` constraint + `IntegrityError` handler | App-level locks don't work across uvicorn workers (the GIL is per-process). The DB is the only shared serialization point. PITFALLS P1. |
| Mesa state transitions | `if estado == 'disponible': estado = 'reservada'` inline | `validar_transicion("mesa", actual, nueva)` from `app.core.state_machines` (Phase 3) | The transition table is already authoritative. Inline checks diverge from it. |
| Cliente auth gate | Re-implement a "is this a cliente?" check | `require_roles(RolUsuario.cliente)` (Phase 2 dependency) | Already proven; one missed branch = privilege escalation. |
| Decimal COP formatting in Dart | `'$' + precio.toStringAsFixed(0)` | `NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(precio)` | intl handles thousands separators (`$ 32.000` not `$ 32000`), locale variants, and is the same package panel uses. |
| 4-tab bottom nav state | `IndexedStack(index: _index, children: [...])` manual | `StatefulShellRoute.indexedStack` (go_router 17) | Official solution; handles deep links, back nav, and state preservation per tab. |
| JWT auth stack | Re-write `api_client.dart` / `auth_storage.dart` / `token_provider.dart` | **Copy from `panel_admin/lib/core/`** | Identical auth flow (login/refresh/me). Phase 4 already debugged the QueuedInterceptor + Completer pattern. Copying prevents drift. |
| Tenant filter for `/staff/reservas` | Inline `if user.restaurant_id != ...` | Existing `get_tenant_scope` dep | Already proven in Phase 4 staff endpoints. |

**Key insight:** Phase 5 introduces ONE genuinely novel problem on the backend (concurrent reserva creation) and ONE on the frontend (4-tab bottom nav). Everything else reuses proven patterns. Resist inventing abstractions.

## Common Pitfalls

### Pitfall 1: Race condition in reserva creation (THE pitfall — PITFALLS P1)
**What goes wrong:** Two concurrent `POST /cliente/reservas` for the same mesa/fecha/hora both pass the "is this mesa free?" check and both INSERT. Double-booked mesa.
**Why it happens:** Check-then-insert is not atomic without DB-level locking.
**How to avoid:** Migration 0003 `UNIQUE (mesa_id, fecha, hora_inicio)` + `with_for_update()` in the service + `IntegrityError → 409` handler (Pattern 3).
**Warning signs:** Tests pass in series but you have no concurrent test; no `IntegrityError` handler in the service; "works in manual testing" but double-bookings reported in peak hours.
**Verification:** `test_reserva_concurrency.py` fires N=10 concurrent identical POSTs and asserts exactly one 201 + nine 409. Mandatory for phase gate.

### Pitfall 2: Using `get_tenant_scope` for `/cliente/*` endpoints
**What goes wrong:** Every `/cliente/reservas` call returns 403.
**Why it happens:** `deps/auth.py` `get_tenant_scope` explicitly rejects clientes with 403 (line 122) — because a cliente's "tenant" is derived from the resource, not the token, and a NULL filter would match every tenant.
**How to avoid:** `/cliente/*` endpoints use `get_current_user` + `require_roles(RolUsuario.cliente)` — NOT `get_tenant_scope`. The ownership check (`reserva.usuario_id == user.id`) lives in the service.
**Warning signs:** All cliente endpoints 403 in tests; staff endpoints work.

### Pitfall 3: Decimal COP serialization mismatch (Pydantic v2 ↔ Dart)
**What goes wrong:** Server sends `"32000.00"` (string); Dart expects `double`; `json_serializable` generates `double get precio` and chokes on the string.
**Why it happens:** Pydantic v2 serializes `Decimal` → JSON string by default (JSON spec has no Decimal type). asyncmy returns `Decimal` from `Numeric(10,2)`.
**How to avoid:** In `app/schemas/menu.py`, declare `precio: float` with a `@field_serializer` that coerces `Decimal → float`, OR declare `precio: float` directly with `model_config = ConfigDict(from_attributes=True)` and let Pydantic coerce. The Dart `producto.dart` freezed model declares `precio: double`. **Test:** a backend test asserts `response.json()["precio"] == 32000.0` (float, not string).
**Warning signs:** Dart `type 'String' is not a subtype of type 'double'` at menú render.

### Pitfall 4: Mesa state drift on cancel (reverting an already-ocupada mesa)
**What goes wrong:** Cliente cancels a reserva; the service blindly sets `mesa.estado = disponible`; but the mesa was already promoted to `ocupada` (cliente arrived, admin marked it via RESV-05). Now a mesa with a seated cliente shows as `disponible`.
**Why it happens:** Cancel logic that doesn't check the mesa's current state.
**How to avoid:** On cancel, ONLY revert if `mesa.estado == reservada` (apply `validar_transicion("mesa", reservada, disponible)`). If the mesa is `ocupada` or `limpieza`, leave it alone — the reserva is still cancelled, but the mesa is not reverted. Document this as the v1 invariant.
**Warning signs:** Cancel test passes on a fresh `reservada` mesa but you have no test for cancelling a reserva whose mesa is `ocupada`.

### Pitfall 5: CORS — the app_cliente port is NOT in `CORS_ORIGINS`
**What goes wrong:** The cliente web app (`http://localhost:5174`) gets CORS preflight errors; every API call fails in Chrome.
**Why it happens:** Phase 4 set `CORS_ORIGINS=http://localhost:5173` (the panel). The cliente app uses a different port.
**How to avoid:** Update `.env`: `CORS_ORIGINS=http://localhost:5173,http://localhost:5174`. Run the cliente with `flutter run -d chrome --web-port=5174` (pinned).
**Warning signs:** `CORS policy: No 'Access-Control-Allow-Origin' header` in browser console.

### Pitfall 6: `fecha` vs `hora_inicio` timezone confusion
**What goes wrong:** "Today" computed in Python differs from "today" in MySQL → reservas_hoy count or "is this past?" check diverges.
**Why it happens:** MySQL `time_zone` is America/Bogota (compose sets it). Python `datetime.date.today()` uses the container TZ (also America/Bogota via `TZ`). They agree ONLY because compose sets both. If someone runs the API outside Docker without `TZ`, "today" shifts.
**How to avoid:** Compute "today" DB-side with `func.curdate()` for the "próximas vs pasadas" split (same as Phase 4 `reservas_hoy` pattern). For the "past date" validation in `crear_reserva`, compare `body.fecha < date.today()` — but document the TZ assumption. Both server-TZ and DB-TZ are America/Bogota (no DST); safe in Colombia.
**Warning signs:** Reservas created "today" appear in "pasadas" or vice versa.

### Pitfall 7: Flutter SDK not on PATH (same as Phase 4)
**What goes wrong:** `flutter create` / `flutter pub get` / `flutter run` fail with "command not found".
**Why it happens:** Flutter is at `C:\src\flutter\bin` but not on the global PATH.
**How to avoid:** Every `flutter`/`dart` command in every task needs `$env:Path += ";C:\src\flutter\bin"` first. Chrome IS installed, so `flutter run -d chrome` works once the SDK is on PATH.
**Warning signs:** "flutter : The term 'flutter' is not recognized".

### Pitfall 8: `StatefulShellRoute.indexedStack` vs `ShellRoute` (bottom nav vs sidebar)
**What goes wrong:** Bottom nav tabs lose state on switch (list scroll resets, fetched data re-loads).
**Why it happens:** Using a plain `ShellRoute` (like the panel's sidebar) — it doesn't preserve per-branch navigator state.
**How to avoid:** Use `StatefulShellRoute.indexedStack` (go_router 17 official). Each branch keeps its own navigator stack.
**Warning signs:** Switching from "Restaurantes" to "Reservas" and back resets the restaurantes scroll position.

## Endpoint Contract (to implement in Phase 5)

All endpoints reuse existing deps. `/public/*` = no auth. `/cliente/*` = `require_roles(RolUsuario.cliente)`. `/staff/reservas` and `/staff/mesas/{id}/estado` extend the existing `/staff` router (`get_tenant_scope`).

### `/public` router (new — no auth)

```python
# app/api/public.py — prefix /public, tag public
# GET /public/restaurantes → list[RestaurantePublico]  (REST-01)
# GET /public/restaurantes/{id} → RestauranteDetalle   (REST-02)
```

**`GET /public/restaurantes`** — REST-01
```python
# 200
[
  {"id": 1, "nombre": "Restaurante Demo GRI", "tipo_cocina": "Colombiana",
   "descripcion": "...", "direccion": "...", "calificacion": null}
]
# Filters: activo=True ONLY. Phase 5 always returns calificacion=null (Phase 9 fills it).
# Ordered by id. No pagination needed (1 restaurante demo, ~handful max).
```

**`GET /public/restaurantes/{id}`** — REST-02
```python
# 200
{
  "id": 1, "nombre": "...", "tipo_cocina": "...", "descripcion": "...", "direccion": "...",
  "calificacion": null,
  "categorias": [
    {"id": 1, "nombre": "Entradas", "orden": 1, "productos": [
      {"id": 1, "nombre": "Patacón con Hogao", "descripcion": "...", "precio": 12000.0,
       "imagen_url": null, "disponible": true}
    ]},
    ...
  ]
}
# 404 if id unknown or activo=False (existence hiding — even public endpoints don't reveal inactive).
# precio coerced Decimal → float (Pitfall 3).
# 3 queries total (restaurante, categorias ordered by 'orden', productos ordered by categoria+nombre) — no N+1.
```

### `/cliente` router (new — `require_roles(RolUsuario.cliente)`)

```python
# app/api/cliente.py — prefix /cliente, tag cliente
# GET    /cliente/perfil               → UserRead (AUTH-05 ver)  — alias; /auth/me already exists, but /cliente/perfil keeps the namespace clean
# PATCH  /cliente/perfil               → UserRead (AUTH-05 editar)
# GET    /cliente/reservas             → list[ReservaRead] (RESV-03)
# POST   /cliente/reservas             → ReservaRead, 201 (RESV-01, RESV-02)
# POST   /cliente/reservas/{id}/cancelar → ReservaRead (RESV-04)
```

**`PATCH /cliente/perfil`** — AUTH-05 editar
```python
# Body (all optional EXCEPT nombre is required; email immutable; password optional):
{ "nombre": "Carlos Nuevo", "password": "NuevoS3cret0!" }   # or just { "nombre": "..." }
# 200 → UserRead (updated)
# 422 if password provided but < 8 or > 64 chars (same rule as UserCreate)
# email is IGNORED if present (or 422 — pick one; recommendation: 422 to surface the immutability)
```

**`POST /cliente/reservas`** — RESV-01 + RESV-02
```python
# Body
{ "restaurante_id": 1, "fecha": "2026-08-20", "hora_inicio": "19:00:00", "num_personas": 4 }
# 201 → ReservaRead with the chosen mesa
# 404 restaurante desconocido/inactivo
# 400 fecha en pasado / hora no es :00 (slot validation) / num_personas < 1
# 409 no hay mesas con capacidad / no hay mesas libres en ese slot / IntegrityError (race lost)
```

**`GET /cliente/reservas`** — RESV-03
```python
# 200 → list[ReservaRead] ordered by fecha DESC, hora_inicio DESC
[
  {"id": 1, "restaurante_nombre": "Restaurante Demo GRI", "restaurante_id": 1,
   "mesa_numero": 4, "fecha": "2026-08-20", "hora_inicio": "19:00:00",
   "num_personas": 4, "estado": "confirmada", "created_at": "..."}
]
# Split client-side: próximas (fecha >= today) / pasadas (fecha < today). Server returns all; client partitions.
# Ownership: WHERE usuario_id = current_user.id — never returns another cliente's reservas.
```

**`POST /cliente/reservas/{id}/cancelar`** — RESV-04
```python
# No body
# 200 → ReservaRead with estado=cancelada
# 404 if id unknown OR reserva.usuario_id != current_user.id (existence hiding)
# 409 if reserva.estado == cancelada (already cancelled) — invalid transition
# 400 if reserva.fecha < today (can't cancel past reserva)
# Side-effect: if mesa.estado == reservada, revert to disponible (Pitfall 4)
```

### `/staff` extensions (RESV-05)

```python
# Extend app/api/staff.py (existing router)
# GET  /staff/reservas?fecha=YYYY-MM-DD → list[ReservaRead] (tenant-scoped)
# POST /staff/mesas/{id}/estado         → MesaRead (body {estado: "ocupada" | "limpieza" | "disponible" | "reservada"})
```

**`GET /staff/reservas`** — RESV-05 (ver)
```python
# ?fecha=YYYY-MM-DD (optional — defaults to today, DB-side func.curdate())
# ?restaurante_id= (required for super_admin; ignored for staff — same rule as /staff/mesas)
# 200 → list[ReservaRead] where fecha = ? AND restaurant_id = scope.restaurant_id
# Joins restaurante (nombre) + mesa (numero) for display.
```

**`POST /staff/mesas/{id}/estado`** — RESV-05 (marcar ocupada) + MESA-04
```python
# Body { "estado": "ocupada" }
# 200 → MesaRead (updated)
# 404 mesa unknown OR other tenant (existence hiding)
# 409 invalid transition (e.g., limpieza → ocupada) — TransicionInvalidaError mapped to 409
# Use case RESV-05: cliente arrives, admin marks mesa ocupada (reservada → ocupada is valid in MESA_TRANSITIONS).
```

### Pydantic schemas to add

```python
# app/schemas/menu.py
class ProductoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    descripcion: str | None
    precio: float   # Decimal coerced — Pitfall 3
    imagen_url: str | None
    disponible: bool

class CategoriaConProductos(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    orden: int
    productos: list[ProductoRead]

class RestaurantePublico(BaseModel):
    id: int
    nombre: str
    tipo_cocina: str | None
    descripcion: str | None
    direccion: str | None
    calificacion: float | None = None   # always None in Phase 5

class RestauranteDetalle(RestaurantePublico):
    categorias: list[CategoriaConProductos]

# app/schemas/reserva.py
class ReservaCreate(BaseModel):
    restaurante_id: int
    fecha: dt.date
    hora_inicio: dt.time
    num_personas: int = Field(ge=1, le=20)   # DB CHECK is >=1; cap at 20 for sanity

class ReservaRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    restaurante_id: int
    restaurante_nombre: str   # joined for display
    mesa_id: int
    mesa_numero: int          # joined for display
    fecha: dt.date
    hora_inicio: dt.time
    num_personas: int
    estado: EstadoReserva
    created_at: dt.datetime

# app/schemas/perfil.py
class PerfilUpdate(BaseModel):
    nombre: str = Field(min_length=1, max_length=150)
    password: str | None = Field(default=None, min_length=8, max_length=64)
    # email DELIBERATELY absent — immutable (login key)

# app/schemas/mesa.py (extend existing)
class MesaEstadoUpdate(BaseModel):
    estado: EstadoMesa
```

### Alembic migration 0003

```python
# alembic/versions/0003_reserva_unique_slot.py
"""Add UNIQUE (mesa_id, fecha, hora_inicio) on reserva — anti-concurrency defense (PITFALLS P1)."""

def upgrade():
    op.create_unique_constraint(
        "uq_reserva_mesa_fecha_hora",
        "reserva",
        ["mesa_id", "fecha", "hora_inicio"],
    )

def downgrade():
    op.drop_constraint("uq_reserva_mesa_fecha_hora", "reserva", type_="unique")
```

**Note:** This UNIQUE only catches EXACT (mesa, fecha, hora) collisions. Combined with hourly slots (Concurrency Design §1), it's sufficient. If a future migration moves to range exclusion, this constraint stays as the exact-collision defense.

**Migration safety check:** before applying, the migration should verify no existing duplicate `(mesa_id, fecha, hora_inicio)` rows exist (the seed creates 0 reservas, so it's safe on a fresh DB). Add a pre-check query in the migration if the table might have data.

## State Machine Application

### §1. RESERVA_TRANSITIONS (already exists in `state_machines.py`)

```
pendiente → {confirmada, cancelada}
confirmada → {cancelada}
cancelada → {} (terminal)
```

**Phase 5 usage:**
- `crear_reserva` creates directly in `confirmada` (auto-confirm locked decision). The `pendiente` state is **unused in Phase 5** but kept in the machine for v1.x (manual approval if a restaurant requests it).
- `cancelar` applies `confirmada → cancelada`. Validates the transition with `validar_transicion("reserva", confirmada, cancelada)`.
- **`completada` / `no_show` are NOT in the machine** (deferring to v1.x — the FEATURES.md state machine mentions them, but Phase 5 doesn't need them; the admin's "mark mesa ocupada" action does NOT transition the reserva). Documented as an Open Question.

### §2. MESA_TRANSITIONS + side-effects on reserva create/cancel

```
disponible → {reservada, ocupada}
reservada → {ocupada, disponible}
ocupada → {limpieza}
limpieza → {disponible}
```

**Phase 5 usage:**

| Event | Mesa transition | Side-effect on reserva |
|-------|-----------------|------------------------|
| `POST /cliente/reservas` succeeds | `disponible → reservada` (the chosen mesa) | New reserva created in `confirmada` |
| `POST /cliente/reservas/{id}/cancelar` | IF mesa was `reservada`: `reservada → disponible`. IF mesa was `ocupada`/`limpieza`: NO change (Pitfall 4). | Reserva `confirmada → cancelada` |
| `POST /staff/mesas/{id}/estado` body `ocupada` (cliente arrives, RESV-05) | `reservada → ocupada` (or `disponible → ocupada` for walk-in) | **No reserva transition** — the reserva stays `confirmada`. It served its purpose (got the cliente to the mesa). |

**Critical invariant:** the mesa state machine is the single source of truth for mesa state (PITFALLS P2). The reserva `estado` is independent — a cancelled reserva does NOT mean the mesa is cancelled; the mesa's transition is decided by its CURRENT state at cancel time.

### §3. Transactional boundary

The mesa mutation + reserva insert (on create) and the mesa mutation + reserva update (on cancel) MUST be in the same DB transaction. If the mesa update commits but the reserva insert rolls back, the mesa is stuck `reservada` with no reserva. Use `async with session.begin():` (or the existing commit/rollback pattern) to keep them atomic.

## Code Examples

### Concurrent-safe reserva service (full, with all validations)

See Pattern 3 above — that IS the canonical implementation. The router wraps it:

```python
# app/api/cliente.py
from app.core.state_machines import TransicionInvalidaError

@router.post("/reservas", response_model=ReservaRead, status_code=201)
async def crear_reserva(
    body: ReservaCreate,
    user: CurrentUser = Depends(require_roles(RolUsuario.cliente)),
    session: AsyncSession = Depends(get_session),
):
    try:
        return await reserva_service.crear_reserva(session, user.id, body)
    except TransicionInvalidaError:
        raise HTTPException(409, "Conflicto de estado de mesa")
```

### Concurrency test (the make-or-break test)

```python
# backend/tests/test_reserva_concurrency.py
import asyncio
import pytest

@pytest.mark.asyncio
async def test_concurrent_reservas_same_slot_only_one_wins(async_client):
    """PITFALLS P1 verification: 10 concurrent POSTs for the same mesa/slot →
    exactly ONE 201, NINE 409. No double-booking."""
    # Register + login a cliente
    cliente = await register_cliente(async_client)
    access, _ = await login(async_client, cliente["email"], cliente["_password"])
    headers = auth_header(access)

    # Fire 10 identical reserva requests for the same future date/slot.
    payload = {
        "restaurante_id": 1,           # demo restaurante
        "fecha": "2099-12-31",         # far future to avoid 'past' rejection
        "hora_inicio": "19:00:00",     # :00 slot
        "num_personas": 2,
    }
    tasks = [async_client.post("/cliente/reservas", json=payload, headers=headers)
             for _ in range(10)]
    responses = await asyncio.gather(*tasks)

    status_codes = [r.status_code for r in responses]
    assert status_codes.count(201) == 1, f"Expected 1 success, got {status_codes.count(201)}: {status_codes}"
    assert status_codes.count(409) == 9, f"Expected 9 conflicts, got {status_codes.count(409)}: {status_codes}"
```

**Why `asyncio.gather`:** httpx AsyncClient + asyncio fires truly concurrent requests (the GIL doesn't serialize I/O). The API (uvicorn) handles them on the event loop; the DB serializes via `FOR UPDATE`. This test catches the race that serial tests miss.

### Flutter reserva wizard (Stepper)

```dart
// features/reservas/reserva_wizard_screen.dart — conceptual shape
class ReservaWizardScreen extends ConsumerStatefulWidget {
  final int restauranteId;       // passed from detalle screen
  final String restauranteNombre;
  // ...
}

class _ReservaWizardState extends ConsumerState<ReservaWizardScreen> {
  int _currentStep = 0;
  DateTime? _fecha;
  TimeOfDay? _hora;              // restricted to :00 via a custom picker
  int _personas = 2;

  @override
  Widget build(BuildContext context) {
    final createAsync = ref.watch(reservaControllerProvider);
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: _onContinue,
      onStepCancel: _onBack,
      steps: [
        Step(title: Text('Fecha'), content: DatePickerDialog(...)),
        Step(title: Text('Hora'), content: _HoraSlotPicker()),  // dropdown of :00 hours
        Step(title: Text('Personas'), content: _PersonasSelector(value: _personas)),
        Step(title: Text('Confirmar'), content: _Resumen(...)),
      ],
    );
  }
}
```

### Flutter COP formatting

```dart
// core/format.dart
import 'package:intl/intl.dart';

String formatCOP(double precio) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(precio);
// formatCOP(32000.0) → "$ 32.000"  (matches mockup style)
```

### Backend Decimal → float coercion (Pitfall 3 fix)

```python
# app/schemas/menu.py
from pydantic import BaseModel, ConfigDict, field_serializer
from decimal import Decimal

class ProductoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    descripcion: str | None
    precio: float
    imagen_url: str | None
    disponible: bool

    @field_serializer("precio")
    def _coerce_decimal(self, v: float | Decimal) -> float:
        # asyncmy returns Decimal from Numeric(10,2); coerce to float for JSON.
        return float(v)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| App-level mutex / `threading.Lock` for reserva concurrency | DB `FOR UPDATE` + `UNIQUE` constraint | always | The only correct serialization point in a multi-worker uvicorn setup. App locks don't work across processes. |
| Manual mesa-state inline checks | `validar_transicion()` from `state_machines.py` | Phase 3 | Single source of truth; transition table is data, not code. |
| `Provider` (Flutter) | Riverpod 3.x | Phase 4 (panel) | Same as panel — DO NOT use Provider. |
| `ShellRoute` (sidebar) | `StatefulShellRoute.indexedStack` (bottom nav) | Phase 5 (cliente) | New for this app — preserves per-tab state. |
| Decimal → JSON string (Pydantic v2 default) | Decimal → float via `field_serializer` | Phase 5 | Dart client gets clean doubles; matches `precio: double` freezed model. |
| Pydantic v1 `.dict()` | Pydantic v2 `.model_dump()` | always | Existing codebase already on v2. |

**Deprecated/outdated to avoid:**
- `Provider` package (Flutter).
- `threading.Lock` / any app-level lock for reserva concurrency.
- Inline mesa-state checks (use `validar_transicion`).
- `Navigator.push` for auth gating (use go_router redirect).
- `python requests` in async paths (use existing asyncmy/SQLAlchemy).

## Open Questions

1. **Reserva turn length (60 vs 90 min)**
   - What we know: v1 ships hourly slots (60-min effective turn) so UNIQUE alone prevents overlap.
   - What's unclear: do real restaurantes need 90-min turns for dinner? (Most Colombian restaurants allow ~90 min for dinner, ~60 for lunch.)
   - Recommendation: ship 60-min for v1, document the limitation. The migration to range exclusion (Concurrency Design §1 Option B) is additive — no data migration needed, just a service-layer query change.

2. **Reserva `completada` / `no_show` states**
   - What we know: `RESERVA_TRANSITIONS` has `pendiente/confirmada/cancelada` only. FEATURES.md mentions `completada`/`no_show` but they're not in the machine.
   - What's unclear: should Phase 5 add them? (RESV-05 says "marcar mesa ocupada al llegar cliente" — but doesn't say the reserva transitions.)
   - Recommendation: **do NOT add `completada`/`no_show` in Phase 5.** The admin's action affects the MESA (reservada → ocupada), not the reserva. The reserva stays `confirmada` forever (or `cancelada` if cancelled). Defer `no_show` (needs a cron to mark past-due reservas) to v1.x.

3. **Cliente-side reserva modification (rebook)**
   - What we know: RESV-04 is cancel-only. No rebook in v1.
   - Recommendation: confirm cancel-only. A cliente who wants a different time cancels + re-creates. Simpler state machine.

4. **Should `/public/*` have rate limiting?**
   - What we know: public endpoints (no auth) are open to the world.
   - What's unclear: do we need rate limiting to prevent scraping / abuse?
   - Recommendation: defer to Phase 9 (deploy hardening). For local dev with 1 demo restaurante, no rate limiting. nginx will handle it in prod.

5. **Should the cliente wizard validate slot availability BEFORE submit?**
   - What we know: the simplest flow is submit-then-409. A friendlier flow pre-checks availability.
   - Recommendation: ship submit-then-409 for v1 (the 409 message guides the user to try another slot). Pre-check would require a `GET /public/disponibilidad` endpoint (deferred, see Concurrency Design §3).

## Validation Architecture

*nyquist_validation: true in .planning/config.json → section included.*

### Test Framework

| Property | Value |
|----------|-------|
| Backend framework | pytest 8.x + pytest-asyncio (`asyncio_mode="auto"`) — `backend/pyproject.toml` |
| Backend config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` (testpaths=["tests"]) |
| Backend quick run | `cd backend && uv run pytest tests/test_reserva.py -v` |
| Backend full suite | `cd backend && uv run pytest tests/ -v` (existing baseline: 70 tests from Phase 4, <20s) |
| Frontend framework | `flutter test` (built-in widget tests) — **NOT yet present** (app_cliente/ doesn't exist) |
| Frontend config file | none — `app_cliente/test/` (Wave 0) |
| Frontend quick run | `cd app_cliente && flutter test` |
| Shared backend fixtures | `backend/tests/conftest.py` (`async_client`, `register_cliente`, `login`, `auth_header`, `super_admin_token`, `db_session`) |

**Backend test precondition:** Docker stack running (`docker compose up -d`) — tests hit `http://localhost:8000` (see `conftest.API_BASE`) and `db_session` connects directly to MySQL on `:3306`. Established Phase 2–4 convention.

**Demo data available for tests:** `carlos@demo.gri.dev` / `Demo!1234` and `maria@demo.gri.dev` / `Demo!1234` (2 clientes seeded); restaurante id=1 ("Restaurante Demo GRI"); 8 mesas (capacidades [2,2,4,4,4,6,6,8]); 4 categorias; 16 productos; `admin@demo.gri.dev` / `Demo!1234` (admin_restaurante, restaurant_id=1). Tests can register fresh clientes via `register_cliente` helper for isolation.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-05 | `PATCH /cliente/perfil` actualiza nombre | integration (backend) | `cd backend && uv run pytest tests/test_cliente_perfil.py::test_update_nombre -v` | ❌ Wave 0 |
| AUTH-05 | `PATCH /cliente/perfil` con password nueva → login con nueva | integration (backend) | `cd backend && uv run pytest tests/test_cliente_perfil.py::test_update_password -v` | ❌ Wave 0 |
| AUTH-05 | `PATCH /cliente/perfil` ignora/rechaza email (immutable) | integration (backend) | `cd backend && uv run pytest tests/test_cliente_perfil.py::test_email_immutable -v` | ❌ Wave 0 |
| AUTH-05 | login + ver perfil UI (Flutter) | widget (Flutter) | `cd app_cliente && flutter test test/perfil/perfil_edit_test.dart` | ❌ Wave 0 |
| REST-01 | `GET /public/restaurantes` sin auth lista restaurantes activos | integration (backend) | `cd backend && uv run pytest tests/test_public_read.py::test_list_public_restaurantes -v` | ❌ Wave 0 |
| REST-01 | `GET /public/restaurantes` NO incluye inactivos | integration (backend) | `cd backend && uv run pytest tests/test_public_read.py::test_excludes_inactive -v` | ❌ Wave 0 |
| REST-01 | lista restaurantes UI (Flutter) | widget (Flutter) | `cd app_cliente && flutter test test/restaurantes/list_test.dart` | ❌ Wave 0 |
| REST-02 | `GET /public/restaurantes/{id}` con menú + categorías + productos | integration (backend) | `cd backend && uv run pytest tests/test_public_read.py::test_detalle_con_menu -v` | ❌ Wave 0 |
| REST-02 | `GET /public/restaurantes/{id}` inactivo → 404 | integration (backend) | `cd backend && uv run pytest tests/test_public_read.py::test_detalle_inactivo_404 -v` | ❌ Wave 0 |
| REST-02 | precio COP serializado como float (no string) — Pitfall 3 | integration (backend) | `cd backend && uv run pytest tests/test_public_read.py::test_precio_is_float -v` | ❌ Wave 0 |
| RESV-01 | `POST /cliente/reservas` crea reserva confirmada | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_crear_reserva_ok -v` | ❌ Wave 0 |
| RESV-01 | reserva en pasado → 400 | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_past_date_400 -v` | ❌ Wave 0 |
| RESV-01 | num_personas > capacidad max → 409 | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_capacity_exceeded -v` | ❌ Wave 0 |
| RESV-01 | wizard UI (Stepper) valida y envía (Flutter) | widget (Flutter) | `cd app_cliente && flutter test test/reservas/wizard_form_test.dart` | ❌ Wave 0 |
| **RESV-02** | **CONCURRENCIA: 10 POSTs simultáneos mismo slot → 1×201 + 9×409** | **integration (backend, CONCURRENTE)** | `cd backend && uv run pytest tests/test_reserva_concurrency.py -v` | ❌ Wave 0 |
| RESV-02 | reservar mesa ya reservada en mismo slot → 409 | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_slot_taken_409 -v` | ❌ Wave 0 |
| RESV-03 | `GET /cliente/reservas` lista propias, no ajenas | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_list_propias_only -v` | ❌ Wave 0 |
| RESV-03 | reservas ordenadas + split próximas/pasadas client-side | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_list_ordered -v` | ❌ Wave 0 |
| RESV-03 | mis_reservas UI render (Flutter) | widget (Flutter) | `cd app_cliente && flutter test test/reservas/mis_reservas_render_test.dart` | ❌ Wave 0 |
| RESV-04 | `POST /cliente/reservas/{id}/cancelar` confirma → cancelada | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_cancel_ok -v` | ❌ Wave 0 |
| RESV-04 | cancelar reserva ajena → 404 (existence hiding) | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_cancel_ajena_404 -v` | ❌ Wave 0 |
| RESV-04 | cancelar reserva pasada → 400 | integration (backend) | `cd backend && uv run pytest tests/test_reserva.py::test_cancel_past_400 -v` | ❌ Wave 0 |
| RESV-04 | cancelar reverte mesa reservada → disponible (Pitfall 4) | integration (backend, db_session) | `cd backend && uv run pytest tests/test_reserva.py::test_cancel_reverts_mesa -v` | ❌ Wave 0 |
| RESV-04 | cancelar NO reverte mesa ocupada (Pitfall 4) | integration (backend, db_session) | `cd backend && uv run pytest tests/test_reserva.py::test_cancel_keeps_ocupada -v` | ❌ Wave 0 |
| RESV-05 | `GET /staff/reservas?fecha=` tenant-scoped | integration (backend) | `cd backend && uv run pytest tests/test_staff_reservas.py::test_list_by_fecha -v` | ❌ Wave 0 |
| RESV-05 | `GET /staff/reservas` cross-tenant → 404/vacío (existence hiding) | integration (backend) | `cd backend && uv run pytest tests/test_staff_reservas.py::test_cross_tenant -v` | ❌ Wave 0 |
| RESV-05 | `POST /staff/mesas/{id}/estado` reservada → ocupada | integration (backend) | `cd backend && uv run pytest tests/test_mesa_estado.py::test_reservada_to_ocupada -v` | ❌ Wave 0 |
| MESA-04 | transición inválida (limpieza → ocupada) → 409 | integration (backend) | `cd backend && uv run pytest tests/test_mesa_estado.py::test_invalid_transition_409 -v` | ❌ Wave 0 |
| MESA-04 | `POST /staff/mesas/{id}/estado` cross-tenant → 404 | integration (backend) | `cd backend && uv run pytest tests/test_mesa_estado.py::test_cross_tenant_404 -v` | ❌ Wave 0 |

**Manual-only justification:** none — every requirement has an automated test. The concurrency test (`test_reserva_concurrency.py`) is the explicit PITFALLS P1 verification that serial tests cannot replace.

### Sampling Rate

- **Per task commit:** the specific test file(s) the task touched — e.g., `cd backend && uv run pytest tests/test_reserva.py -v` for reserva service tasks; `cd app_cliente && flutter test test/reservas/` for reserva UI tasks.
- **Per wave merge:** `cd backend && uv run pytest tests/ -v` (full regression — must stay green; baseline 70 from Phase 4) + `cd app_cliente && flutter test` (full widget suite).
- **Phase gate:** full backend suite green (including the concurrent test) + `flutter test` green + manual UAT (register cliente → discover → reserve → mis-reservas → admin marks ocupada → cliente cancels).

### Wave 0 Gaps

- [ ] **Flutter SDK on PATH** — `$env:Path += ";C:\src\flutter\bin"` before any frontend task. BLOCKER (same as Phase 4).
- [ ] **CORS_ORIGINS update** — `.env` add `http://localhost:5174` (cliente web port). Update `app/core/config.py` default or `.env` only.
- [ ] **Migration 0003** — `backend/alembic/versions/0003_reserva_unique_slot.py` (UNIQUE constraint on reserva).
- [ ] `backend/app/api/public.py` + `backend/app/api/cliente.py` — new routers.
- [ ] `backend/app/api/staff.py` — extend with `GET /staff/reservas` + `POST /staff/mesas/{id}/estado`.
- [ ] `backend/app/services/reserva_service.py` — new (crear + cancelar + list).
- [ ] `backend/app/services/staff_service.py` — extend with reservas del día + mesa estado mutation.
- [ ] `backend/app/services/public_service.py` — new (list + detalle restaurante).
- [ ] `backend/app/services/cliente_service.py` — new (perfil update).
- [ ] `backend/app/schemas/menu.py` + `reserva.py` + `perfil.py` — new (extend `mesa.py` with `MesaEstadoUpdate`).
- [ ] `backend/app/main.py` — `app.include_router(public.router)` + `app.include_router(cliente.router)`.
- [ ] `backend/tests/test_public_read.py` + `test_cliente_perfil.py` + `test_reserva.py` + `test_reserva_concurrency.py` + `test_staff_reservas.py` + `test_mesa_estado.py` — new test files.
- [ ] `app_cliente/` Flutter project scaffolded (`flutter create --platforms=android,ios,web`) + deps installed + `build_runner` codegen.
- [ ] `app_cliente/lib/core/*` — **copy from `panel_admin/lib/core/`** (api_client, auth_storage, token_provider, env; adapt theme.dart constants to mockup's #f7f7f7 bg).
- [ ] `app_cliente/test/*` — widget tests per the map above.

*(Existing test infrastructure (`conftest.py`, `async_client`, `register_cliente`, `login`, `auth_header`, `db_session`) covers all backend Phase 5 tests — no new fixtures needed beyond reusing them. The `register_cliente` helper is the seed for isolated cliente accounts per test.)*

## Sources

### Primary (HIGH confidence)
- **Existing backend code** (read this session):
  - `backend/app/models/reserva.py` — DEFERRED UNIQUE constraint (docstring lines 4-7); `hora_inicio: Time`, `num_personas: SmallInteger` with CHECK `>= 1`; indexes `ix_reserva_mesa_fecha` + `ix_reserva_restaurante_fecha_estado` already present. ✓
  - `backend/app/core/state_machines.py` — `MESA_TRANSITIONS`, `RESERVA_TRANSITIONS` exact definitions; `validar_transicion()` + `TransicionInvalidaError`. ✓
  - `backend/app/deps/auth.py` — `get_tenant_scope` rejects cliente with 403 (line 122); `require_roles(*roles)` factory; `CurrentUser` shape. ✓
  - `backend/app/services/{auth,admin,staff,seed}_service.py` — existing patterns (register_cliente, list_restaurantes, get_restaurante_for_staff, seed_demo content). ✓
  - `backend/app/api/{auth,admin,staff}.py` — existing router shapes; `auth_service.register_cliente` ALREADY EXISTS (AUTH-01 backend done in Phase 2). ✓
  - `backend/app/models/{mesa,usuario,restaurante,menu,sesion_mesa}.py` — exact fields; `EstadoMesa`, `RolUsuario.cliente`, `Producto.precio: Decimal`. ✓
  - `backend/app/core/{config,security}.py` — `CORS_ORIGINS` env-driven (line 48); JWT token shape; bcrypt direct (no passlib). ✓
  - `backend/tests/conftest.py` — `async_client`, `register_cliente`, `login`, `auth_header`, `super_admin_token`, `db_session` fixtures; `API_BASE=http://localhost:8000`. ✓
- **Phase 4 research + summary** (`04-RESEARCH.md`, `04-02-SUMMARY.md`): proven Flutter stack (riverpod 3.4.2, go_router 17.5.0, dio 5.11.0 QueuedInterceptor + Completer, flutter_secure_storage 11.0.0); Riverpod 3.x API gotchas (`AsyncValue.value` nullable, `StateProvider` deprecated → `NotifierProvider`, `(_, _)` wildcards); theme palette; copy-able `lib/core/`. ✓
- **Alembic versions present**: `0001_initial.py`, `0002_domain_tables.py` → Phase 5's is **0003**. ✓
- **PITFALLS P1** (race condition reservas) — `research/PITFALLS.md` lines 14-41: constraint UNIQUE + FOR UPDATE + IntegrityError → 409; explicit "Phase to address: Fase de Reservas". ✓
- **FEATURES.md Reserva state machine** (lines 232-243): `pendiente → confirmada → {completada, no_show, cancelada}`; open design question on auto-confirm (RESOLVED this session: auto-confirm). ✓
- **documentos/indexcliente.html** — exact cliente mockup: 4-tab bottom nav (Inicio/Restaurantes/Reservas/Perfil), welcome section, restaurant card with rating, "Reservar" CTA, "Mis reservas" shortcut, "Próxima reserva" card with status chip; palette (`--primary: #ff4c05`, `--background: #f7f7f7`, `--green: #20b26b`); `.app` max-width 480px; QR button (Phase 6, not 5). ✓
- **STACK.md** (project root CLAUDE.md): locked versions for FastAPI 0.141.1, SQLAlchemy 2.0.52, asyncmy 0.2.14, PyJWT 2.13.0, flutter_riverpod 3.4.2, dio 5.11.0, go_router 17.5.0, flutter_secure_storage 11.0.0. ✓

### Secondary (MEDIUM confidence)
- **SQLAlchemy 2.0 async `with_for_update()`** — standard SQLAlchemy 2.0 Core API; maps to `SELECT ... FOR UPDATE` on MySQL/asyncmy. Well-established, stable since SQLAlchemy 1.4. Not re-verified against docs this session but low-volatility.
- **asyncmy FOR UPDATE support** — asyncmy is a thin asyncio wrapper over MySQL protocol; FOR UPDATE is server-side. Implicit HIGH.
- **Pydantic v2 Decimal → str default serialization** — well-documented Pydantic v2 behavior; `field_serializer` is the documented escape hatch.
- **go_router 17 `StatefulShellRoute.indexedStack`** — referenced in go_router docs; not fetched line-by-line this session but the API is stable across 16.x→17.x.

### Tertiary (LOW confidence)
- **COP currency formatting in Dart `intl`** — `NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)` is the documented pattern; the exact thousands-separator output (`.` vs `,`) should be visually verified in the wizard test. Low risk.
- **Asyncio.gather concurrency test reliability** — fires truly concurrent httpx requests, but the exact interleaving depends on the event loop. The assertion "exactly 1×201 + N-1×409" should hold deterministically because the DB serializes; if flaky, increase N to 20.

## Metadata

**Confidence breakdown:**
- Backend endpoints + concurrency design: **HIGH** — `FOR UPDATE` + UNIQUE + IntegrityError is the textbook PITFALLS P1 answer; existing `get_tenant_scope` / `require_roles` / `validar_transicion` patterns are proven in Phases 2–4.
- Flutter cliente stack & structure: **HIGH** — copies the proven Phase 4 `lib/core/`; `StatefulShellRoute.indexedStack` is the official go_router 17 answer for bottom nav.
- Concurrency test design: **HIGH** — `asyncio.gather` + httpx AsyncClient is the standard pattern; assertion is deterministic because the DB serializes.
- Decimal COP serialization: **HIGH** on the Pydantic v2 default behavior (str); **MEDIUM** on the exact `field_serializer` output (should be verified by `test_precio_is_float`).
- Mesa state side-effects on cancel: **HIGH** on the invariant (only revert reservada); **MEDIUM** on the exact transactional boundary (one `session.begin()` covers it, but the test `test_cancel_keeps_ocupada` is the proof).
- Slot granularity choice (hourly / 60-min turn): **MEDIUM** — it's a deliberate v1 simplification; the upgrade to range exclusion is documented but not implemented.

**Research date:** 2026-08-13
**Valid until:** 2026-09-12 (30 days — stable stack; the only fast-moving item is the concurrency design, which is a one-shot decision this phase, not a versioning concern)
