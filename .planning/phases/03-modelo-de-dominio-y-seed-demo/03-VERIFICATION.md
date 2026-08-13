---
phase: 03-modelo-de-dominio-y-seed-demo
verified: 2026-08-13T00:00:00Z
status: passed
score: 3/3 must-haves verified
re_verification: false
requirements:
  - id: PLAT-04
    status: satisfied
    evidence: "Restaurante Demo GRI sembrado (1 fila) + 8 mesas + 4 categorías + 16 productos COP + 5 usuarios demo (3 staff + 2 clientes); verify_seed.sh sección 1-5 ALL CHECKS PASSED"
  - id: MESA-02
    status: satisfied
    evidence: "UniqueConstraint codigo_qr GLOBAL en BD (SHOW INDEX uq_mesa_codigo_qr=True); migration 0002 línea 68; test_qr_duplicado_rechazado PASSED (IntegrityError)"
  - id: INFR-03
    status: satisfied
    evidence: "docker compose down -v && up -d → alembic 0001→0002 automáticos + lifespan seed_if_demo_mode → plataforma lista; verify_seed.sh ALL CHECKS PASSED con idempotencia 16==16"
human_verification: []
---

# Phase 3: Modelo de Dominio y Seed Demo — Verification Report

**Phase Goal:** Toda la base de datos de negocio existe con state machines explícitas (mesa y pedido) y el restaurante demo sembrado al inicializar
**Verified:** 2026-08-13
**Status:** ✅ PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Must-Haves)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | Migraciones y seed se ejecutan automáticamente al desplegar en limpio (`docker compose down -v && up -d` → plataforma lista) | ✅ VERIFIED | Clean deploy ejecutado: `down -v && up -d` → logs muestran `Running upgrade -> 0001` y `Running upgrade 0001 -> 0002` automáticos + `Application startup complete`; 12 tablas creadas (11 dominio + alembic_version); datos demo presentes (mesas_demo=8, usuarios_demo=5, productos_demo=16); `verify_seed.sh` → ALL CHECKS PASSED con idempotencia 16==16 |
| 2   | Restaurante demo sembrado con DEMO_MODE=true; DEMO_MODE=false no siembra nada | ✅ VERIFIED | DEMO_MODE=true + clean deploy → 8 mesas, 5 usuarios, 16 productos sembrados. DEMO_MODE=false + clean deploy → mesas_demo=0, usuarios_demo=0, productos_demo=0 (cero filas). Gate dentro del service (`seed_service.py:100 if not settings.DEMO_MODE: return None`). Migraciones sí corren en ambos casos (schema presente). Tests test_demo_mode_false_no_siembra + test_demo_mode_true_siembra PASSED |
| 3   | QR único GRI-MESA-XXX con constraint en BD (dos mesas no pueden compartir código) | ✅ VERIFIED | `SHOW INDEX FROM mesa WHERE Key_name='uq_mesa_codigo_qr'` → existe. Constraint GLOBAL en migration 0002 línea 68 y model mesa.py línea 48 (no compuesto con restaurant_id). test_qr_duplicado_rechazado PASSED (IntegrityError en flush). 8 mesas sembradas GRI-MESA-001..008 |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `backend/app/core/state_machines.py` | 5 SM (MESA/PEDIDO/RESERVA/PAGO/SESION) + validar_transicion + TransicionInvalidaError; módulo PURO | ✅ VERIFIED | 102 líneas; 5 dicts de transiciones + validar_transicion + puede_transicionar + TransicionInvalidaError. Grep: 0 imports de sqlalchemy/fastapi. Estados terminales como `set()` vacíos |
| `backend/app/models/mesa.py` | Mesa + EstadoMesa + codigo_qr UNIQUE GLOBAL | ✅ VERIFIED | UniqueConstraint("codigo_qr", name="uq_mesa_codigo_qr") línea 48 (no compuesto con restaurant_id) |
| `backend/app/models/sesion_mesa.py` | SesionMesa + EstadoSesion + activo_flag Computed + UNIQUE(mesa_id, activo_flag) | ✅ VERIFIED | activo_flag Computed("CASE WHEN cerrada_en IS NULL THEN 1 ELSE NULL END") líneas 71-74; UniqueConstraint("mesa_id", "activo_flag", name="uq_sesion_mesa_activa") línea 43 |
| `backend/app/models/pedido.py` | Pedido + PedidoItem + EstadoPedido + CHECK cantidad>0 + snapshot precio Numeric(10,2) | ✅ VERIFIED | (presente, migración declara ck_pedido_item_cantidad_positiva + Numeric(10,2)) |
| `backend/app/models/menu.py` | Categoria + Producto | ✅ VERIFIED | (presente, uq_categoria_restaurante_nombre en BD) |
| `backend/app/models/{reserva,pago,calificacion}.py` | 3 tablas + enums + CHECKs/uniques | ✅ VERIFIED | CHECKs (estrellas 1-5, num_personas>=1) + uq_pago_referencia + uq_calificacion_pedido en BD |
| `backend/app/models/__init__.py` | re-export de los 9 models + 5 enums | ✅ VERIFIED | 47 líneas, __all__ con todos los nombres nuevos |
| `backend/alembic/versions/0002_domain_tables.py` | 9 tablas FK-dependientes, constraints con nombres | ✅ VERIFIED | revision="0002", down_revision="0001" literales; 9 tablas en orden FK; 6 nombres críticos presentes; upgrade/downgrade limpio (alembic_version=0002) |
| `backend/app/services/seed_service.py` | seed_if_demo_mode gate + seed_demo get-or-create natural-key | ✅ VERIFIED | 340 líneas; gate línea 100; helpers _get_or_create_* por natural key; UN solo commit real (línea 330); Decimal exacto para precios |
| `backend/app/main.py` | lifespan llama seed_if_demo_mode tras ensure_super_admin | ✅ VERIFIED | Import línea 16; `await seed_if_demo_mode(session)` línea 26 tras `ensure_super_admin` |
| `backend/tests/test_state_machines.py` | unitarios puros SM (sin DB) | ✅ VERIFIED | 11 tests PASSED en 0.04s (sin stack); 0 imports sqlalchemy/fastapi |
| `backend/tests/test_domain_constraints.py` | DB-direct: QR dup, sesión activa, CHECKs, uniques | ✅ VERIFIED | 8 tests PASSED; captura (IntegrityError, OperationalError) para CHECKs (MySQL 8.4 mapea error 3819) |
| `backend/tests/test_seed.py` | contenido + idempotencia + gate DEMO_MODE | ✅ VERIFIED | 6 tests PASSED; scope por natural keys para evitar contaminación cross-test |
| `backend/scripts/verify_seed.sh` + `verify_seed.py` | aceptación INFR-03 end-to-end | ✅ VERIFIED | ALL CHECKS PASSED; 8 secciones; idempotencia before/after comparada |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `main.py::lifespan` | `seed_service.py::seed_if_demo_mode` | import + await tras ensure_super_admin | ✅ WIRED | main.py:16 import + main.py:26 `await seed_if_demo_mode(session)` |
| `seed_service.py::seed_if_demo_mode` | `config.py::settings.DEMO_MODE` | gate `if not settings.DEMO_MODE: return None` | ✅ WIRED | seed_service.py:100; verificado empíricamente (DEMO_MODE=false → 0 filas) |
| `seed_service.py::seed_demo` | tablas de dominio | imports Mesa/Categoria/Producto/Usuario/Restaurante + session.add() get-or-create | ✅ WIRED | seed_service.py:40-43 imports; helpers _get_or_create_* |
| `Dockerfile CMD` | `seed_service.py` | `alembic upgrade head → uvicorn → lifespan → seed_if_demo_mode` | ✅ WIRED | Logs clean deploy confirman orden; CMD `sh -c 'alembic upgr...'` (docker compose ps) |
| `alembic/env.py` | los 9 models | imports explícitos para metadata completo | ✅ WIRED | Base.metadata genera las 9 tablas en migración 0002 |
| `state_machines.py` | 5 Enums de estado | import solo Enums (no ORM/HTTP) | ✅ WIRED | líneas 13-17 importan solo Estado*; módulo puro confirmado |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| PLAT-04 | 03-02 | Restaurante demo con menú, mesas y datos de ejemplo | ✅ SATISFIED | 1 restaurante + 8 mesas + 4 categorías + 16 productos COP + 5 usuarios sembrados al boot; verify_seed.sh secciones 1-5 |
| MESA-02 | 03-01 | QR único por mesa | ✅ SATISFIED | uq_mesa_codigo_qr GLOBAL en BD + migration + test_qr_duplicado_rechazado PASSED |
| INFR-03 | 03-01 + 03-02 | Migraciones y seed ejecutados automáticamente en deploy | ✅ SATISFIED | Clean deploy `down -v && up -d` → migraciones automáticas (logs) + seed automático (lifespan) + idempotencia (16==16); DEMO_MODE=false no siembra |

### Constraints Verification (en BD, defensa permanente)

Verificado directamente via `information_schema` tras clean deploy:

| Constraint | Tipo | Tabla | Propósito | Presente |
| ---------- | ---- | ----- | --------- | -------- |
| uq_mesa_codigo_qr | UNIQUE | mesa | QR global único (MESA-02/SC3) | ✅ |
| uq_mesa_restaurante_numero | UNIQUE | mesa | número único por tenant | ✅ |
| uq_categoria_restaurante_nombre | UNIQUE | categoria | nombre único por tenant | ✅ |
| uq_sesion_mesa_activa | UNIQUE | sesion_mesa | una sesión activa por mesa (Computed activo_flag) | ✅ |
| uq_pago_referencia | UNIQUE | pago | idempotencia de pagos | ✅ |
| uq_calificacion_pedido | UNIQUE | calificacion | una calificación por pedido | ✅ |
| ck_pedido_item_cantidad_positiva | CHECK | pedido_item | cantidad > 0 | ✅ |
| ck_reserva_num_personas_positiva | CHECK | reserva | num_personas >= 1 | ✅ |
| ck_calificacion_estrellas_rango | CHECK | calificacion | estrellas BETWEEN 1 AND 5 | ✅ |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (ninguno) | - | - | - | Sin TODO/FIXME/XXX/HACK/PLACEHOLDER/NotImplemented en app/; sin stubs; state_machines.py es módulo puro; seed_service tiene un solo commit (atomicidad) |

### Human Verification Required

Ninguno. Todos los must-haves son verificables empíricamente via comandos (clean deploy, tests, inspección de BD) y fueron ejecutados durante esta verificación.

### Evidence — Comandos ejecutados y resultados

**1. Stack status:**
```
NAME        IMAGE       COMMAND                  STATUS
gri-api     cel-api     "sh -c 'alembic upgr…"   Up (healthy)
gri-mysql   mysql:8.4   "docker-entrypoint.s…"   Up (healthy)
```

**2. Suite completa de tests:**
```
docker compose exec api uv run pytest tests/ -v
============================= 59 passed in 11.08s ==============================
```
(34 regression Phase 1-2 + 11 state machines + 8 domain constraints + 6 seed = 59)

**3. Tests de dominio específicos:**
```
docker compose exec api uv run pytest tests/test_state_machines.py tests/test_domain_constraints.py tests/test_seed.py -v
============================= 25 passed in 0.88s ==============================
```

**4. verify_seed.sh (clean deploy, DEMO_MODE=true):**
```
docker compose exec -w /app api sh scripts/verify_seed.sh
== 1. Restaurante demo existe ==      restaurante demo filas: 1
== 2. 8 mesas con QR GRI-MESA-00X ==  mesas demo filas: 8
== 3. 4 categorias ==                 categorias demo filas: 4
== 4. 16 productos COP (>=15) ==      productos demo filas: 16
== 5. 3 staff + 2 clientes demo ==    usuarios demo filas: 5
== 6. Captura counts PRE-restart ==   mesas=8 productos=16 demo_users=5
== 7. Re-corre el seed ==             seed re-corrido sin errores
== 8. Counts POST-restart ==          mesas=8 productos=16 demo_users=5
ALL CHECKS PASSED
```

**5. SC1 — Clean deploy (down -v && up -d):**
```
gri-api  | INFO [alembic.runtime.migration] Running upgrade -> 0001
gri-api  | INFO [alembic.runtime.migration] Running upgrade 0001 -> 0002
gri-api  | INFO: Application startup complete.
# Resultado: 12 tablas + todos los constraints + datos demo (8/5/16) presentes automáticamente
```

**6. SC2 — DEMO_MODE=false (clean deploy):**
```
mesas_demo=0  usuarios_demo=0  productos_demo_scoped=0
# Pero 12 tablas + todos los constraints presentes (migraciones sí corren)
# Gate dentro del service: seed_service.py:100 `if not settings.DEMO_MODE: return None`
```

**7. SC3 — Constraint QR en BD:**
```
SHOW INDEX FROM mesa WHERE Key_name='uq_mesa_codigo_qr' → existe (GLOBAL)
test_qr_duplicado_rechazado → PASSED (IntegrityError en flush)
```

### Issues / Observaciones

**Info (no blocker):** `scripts/verify_seed.py` secciones 6 y 8 cuentan productos del restaurante demo SIN scope por categorías demo (a diferencia de la sección 4 que sí filtra con `c.nombre IN ('Entradas','Platos Fuertes','Bebidas','Postres')`). Tras ejecutar `pytest` contra el stack, esto captura contaminación de `test_domain_constraints.py` (que crea productos `prod-XXXXXX` adjuntados al primer restaurante, que es el demo) — el count absoluto aparece como 52 en vez de 16. Esto **NO afecta la verificación de idempotencia** (before==after siempre se cumple) ni refleja un bug del seed: en un clean deploy el count es 16 correctamente. Es un detalle cosmético de scoping que podría alinearse con la sección 4 para consistencia, pero no impacta ninguna Success Criterion ni requirement.

### Gaps Summary

Sin gaps. Los 3 must-haves están verificados empíricamente:

1. **Deploy limpio automático** — `docker compose down -v && up -d` deja la plataforma lista: migraciones 0001→0002 corren solas (CMD Dockerfile), seed corre en lifespan, datos demo presentes sin intervención humana. INFR-03 completo.

2. **Gate DEMO_MODE real** — verificado en ambas direcciones con clean deploy: `DEMO_MODE=true` siembra (8/5/16), `DEMO_MODE=false` no siembra NADA (0/0/0). El gate vive dentro del service (defense-in-depth), no solo en el caller del lifespan. PLAT-04 + SC2 completos.

3. **QR único global** — constraint `uq_mesa_codigo_qr` en BD (no compuesto con restaurant_id), respaldado por migration + model + test de IntegrityError. MESA-02 + SC3 completos.

Adicionalmente: 5 state machines explícitas como módulo puro (0 dependencias ORM/HTTP, testeables en ms); 9 tablas de dominio con todos los FKs, índices compuestos y constraints de defensa permanente; sesion_mesa con `activo_flag` Computed + UNIQUE para garantizar una sola sesión activa por mesa; snapshot de precio Numeric(10,2) Decimal exacto.

**Phase 3 lista. El goal está logrado.** Las fases 4-9 pueden construir sobre esta base de datos de negocio con state machines y constraints en BD.

---

_Verified: 2026-08-13_
_Verifier: Claude (gsd-verifier)_
