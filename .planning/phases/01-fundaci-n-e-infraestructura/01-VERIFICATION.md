---
phase: 01-fundaci-n-e-infraestructura
verified: 2026-08-13T12:45:00Z
status: passed
score: 3/3 must-haves verified
re_verification: No — initial verification
warnings:
  - severity: warning
    id: W01-transient-503
    title: "503 intermitente en /health tras idle (asyncmy/uvloop termination)"
    impact: "No bloquea Phase 1; siguiente request vuelve a 200 con conexión fresh. Revisitar en Phase 7 (WebSockets) donde conexiones long-lived importan."
  - severity: info
    id: I01-uv-not-on-path
    title: "uv no está en PATH global del host"
    impact: "Para reproducir los tests Wave 0 hay que invocar uv por ruta completa o añadir `%APPDATA%\\Python\\Python314\\Scripts` al PATH. No afecta al stack Docker."
---

# Phase 1: Fundación e Infraestructura — Verification Report

**Phase Goal:** La plataforma corre: MySQL y la API en Docker, conectados por configuración de entorno, con datos persistentes
**Verified:** 2026-08-13T12:45:00Z
**Status:** ✅ **PASSED**
**Re-verification:** No — initial verification (goal-backward, evidence-first)

> Verificación goal-backward. NO se confió en el SUMMARY. Cada must-have se probó con comandos reales contra el stack corriendo y contra el código fuente.

---

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | `docker compose up` levanta MySQL y la API; `/health` responde 200 con `database: connected` | ✅ VERIFIED | `docker compose ps`: `gri-mysql Up (healthy)`, `gri-api Up`. `/health`: **8/8 intentos estables = 200 `{"status":"ok","database":"connected"}`** tras breve 503 transient (ver W01). |
| 2   | Datos MySQL sobreviven reinicio (volumen persistente); charset utf8mb4 + tz America/Bogota; acentos/emojis OK | ✅ VERIFIED | `docker compose restart mysql` → fila `infra_probe` persiste. `SELECT @@character_set_database, @@collation_database, @@global.time_zone` = `utf8mb4 / utf8mb4_unicode_ci / -05:00`. `NOW()` = `2026-08-13 12:37:35` (hora Bogotá). `test_db_charset_tz_and_unicode` PASSED — Python round-trip de `'Açaí 🍜 café Bogotá'` intacto vía asyncmy. |
| 3   | Conexión a BD 100% por variables de entorno (cambiar `.env`/compose cambia conexión sin tocar código) | ✅ VERIFIED | Override `DB_NAME=gri_inexistente` vía `docker-compose.override.verif.yml` → **5/5 `/health` = 503** (determinista). Restaurado a `DB_NAME=gri` → `/health` = 200 connected. `config.py` lee `DB_*` de env y compone `database_url`; compose.yml inyecta `DB_HOST=mysql`, etc. |

**Score:** 3/3 truths verified

---

### Required Artifacts (3 niveles: existe / sustantivo / wired)

| Artifact | Existe | Sustantivo | Wired | Status |
| -------- | :----: | :--------: | :---: | ------ |
| `docker-compose.yml` | ✅ | ✅ contiene `mysql:8.4`, `gri_mysql_data`, `--default-time-zone=-05:00`, `condition: service_healthy`, `$$MYSQL_ROOT_PASSWORD` | ✅ el stack lo usa para levantar mysql+api | ✅ VERIFIED |
| `backend/Dockerfile` | ✅ | ✅ `ghcr.io/astral-sh/uv:0.12`, `UV_COMPILE_BYTECODE`, `uv sync --locked`, `USER appuser`, CMD solo `uvicorn app.main:app` (sin `alembic`) | ✅ `build: ./backend` en compose | ✅ VERIFIED |
| `backend/app/core/config.py` | ✅ | ✅ `Settings(BaseSettings)` con `DB_HOST/PORT/USER/PASSWORD/NAME` + `DEMO_MODE` + `database_url` property (`mysql+asyncmy://...?charset=utf8mb4`) | ✅ importado por `db.py` y `main.py` | ✅ VERIFIED |
| `backend/app/core/db.py` | ✅ | ✅ `create_async_engine` (`pool_pre_ping=True`, `pool_size=10`, `max_overflow=20`, `pool_recycle=3600`), `async_session_maker` con **`expire_on_commit=False`**, `get_session` async generator | ✅ `health.py` usa `Depends(get_session)` | ✅ VERIFIED |
| `backend/app/api/health.py` | ✅ | ✅ `router` con `GET /health` que ejecuta `text("SELECT 1")` → 200 connected \| 503 unreachable (no raise) | ✅ incluido en `main.py` vía `app.include_router(health.router)` | ✅ VERIFIED |
| `backend/app/main.py` | ✅ | ✅ `app = FastAPI(...)` con `lifespan` async context manager (`await engine.dispose()` al shutdown, NO `@app.on_event`) + `GET /` | ✅ runtime respondió `{"app":"GRI API","environment":"development"}` | ✅ VERIFIED |
| `backend/tests/conftest.py` | ✅ | ✅ fixture `async_client` (httpx.AsyncClient base_url `http://localhost:8000`) | ✅ consumido por `test_health.py` | ✅ VERIFIED |
| `backend/tests/test_health.py` | ✅ | ✅ asserts `status_code == 200` + `json()["database"] == "connected"` (INFR-02 smoke) | ✅ PASSED en runtime | ✅ VERIFIED |
| `backend/tests/test_db_config.py` | ✅ | ✅ asserts `@@character_set_database='utf8mb4'`, `@@global.time_zone='-05:00'`, round-trip emoji (INFR-01) | ✅ PASSED en runtime | ✅ VERIFIED |
| `backend/scripts/verify_infra.sh` | ✅ | ✅ existe | ✅ script de aceptación manual | ✅ VERIFIED |
| `.env.example` | ✅ | ✅ template con `MYSQL_ROOT_PASSWORD`, `MYSQL_APP_PASSWORD`, `DEMO_MODE` + nota sobre DB_* en compose | ✅ commiteado | ✅ VERIFIED |
| `.gitignore` | ✅ | ✅ excluye `.env`, `backend/.venv/`, caches | ✅ | ✅ VERIFIED |
| `.planning/phases/01-fundaci-n-e-infraestructura/SKELETON.md` | ✅ | ✅ existe | ✅ contrato arquitectónico | ✅ VERIFIED |
| `backend/uv.lock` | ✅ | ✅ lockfile reproducible commiteado | ✅ usado por Dockerfile `uv sync --locked` | ✅ VERIFIED |

---

### Key Link Verification

| From | To | Via | Status | Evidence |
| ---- | -- | --- | ------ | -------- |
| compose `api` | compose `mysql` | `depends_on.mysql.condition: service_healthy` | ✅ WIRED | `docker-compose.yml:47`. Logs muestran API no arranca hasta MySQL healthy. |
| compose `api.environment.DB_HOST=mysql` | `config.py Settings.DB_HOST` | env var → BaseSettings | ✅ WIRED | `docker-compose.yml:49` inyecta `DB_HOST: mysql`. Container API lo recibe. |
| `config.py database_url` | `db.py create_async_engine` | URL `mysql+asyncmy://...?charset=utf8mb4` | ✅ WIRED | `config.py:34` construye la URL; `db.py:19` la pasa a `create_async_engine(settings.database_url, ...)`. |
| `health.py health()` | `db.py get_session` | `Depends(get_session)` → `session.execute(text("SELECT 1"))` | ✅ WIRED | `health.py:22-25` usa `Depends(get_session)` y ejecuta `SELECT 1`. Runtime: 200 connected. |
| `main.py app` | `health.router` | `app.include_router(health.router)` | ✅ WIRED | `main.py:30`. `/health` responde. |
| Dockerfile CMD | runtime uvicorn | `CMD ["uvicorn", "app.main:app", ...]` | ✅ WIRED | `docker compose ps` muestra `uvicorn app.main:ap…` corriendo en gri-api. |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| **INFR-01** | 01-01-PLAN | MySQL en Docker con datos persistentes, charset utf8mb4, tz America/Bogota, acentos/emojis OK | ✅ SATISFIED | Volumen `gri_mysql_data` persiste tras `docker compose restart mysql`. `@@character_set_database=utf8mb4`, `@@collation_database=utf8mb4_unicode_ci`, `@@global.time_zone=-05:00`. Round-trip `'Açaí 🍜 café Bogotá'` OK (test PASSED). |
| **INFR-02** | 01-01-PLAN | Conexión a BD por variables de entorno (cambiar `.env` cambia conexión sin tocar código) | ✅ SATISFIED | `config.py` es `BaseSettings` parts-based. Env-swap test: `DB_NAME=gri_inexistente` → `/health` 503 determinista. Restaurado a `gri` → 200 connected. `/health` ejecuta SELECT 1 real. |

**Orphaned requirements check:** ROADMAP lista `INFR-01, INFR-02` para Phase 1. El PLAN los reclama en `requirements: [INFR-01, INFR-02]`. **No hay orphaned requirements.** (INFR-03 está mapeado a Phase 3, correctamente.)

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (ninguno en código) | — | — | — | — |

**Verificación anti-regresión (cosas que NO deben aparecer):**

| Anti-pattern | Status | Nota |
| ------------ | ------ | ---- |
| `--default-authentication-plugin` en compose `command:` | ✅ AUSENTE | Solo aparece en **comentario** (línea 30: "DO NOT pass..."). Compose command solo tiene `--character-set-server`, `--collation-server`, `--default-time-zone`. |
| `@app.on_event` en main.py | ✅ AUSENTE | Solo aparece en **docstring** (línea 3: "NOT the deprecated @app.on_event"). main.py usa `lifespan` context manager. |
| `expire_on_commit=True` en async_sessionmaker | ✅ AUSENTE | db.py explícitamente setea **`expire_on_commit=False`** (anti-MissingGreenlet). |
| `build-essential`/`default-libmysqlclient-dev` en Dockerfile | ✅ AUSENTE | Dockerfile usa wheels cp312 de asyncmy/greenlet/cryptography; no instala toolchain C. |
| `alembic upgrade head` en CMD del Dockerfile | ✅ AUSENTE | CMD es solo `uvicorn app.main:app`. Alembic diferido a Phase 3 (no hay migraciones). |
| `.venv/` copiado al image | ✅ AUSENTE | `.dockerignore` excluye `.venv/`, `__pycache__/`, `.env`, `tests/`. |
| `mysql:8.4-lts` tag (no existe en Docker Hub) | ✅ AUSENTE | Se usa `mysql:8.4` (rolling LTS branch tag, verificado). |
| Hardcoded credentials en código | ✅ AUSENTE | `config.py` solo lee de env. `.env` está en `.gitignore`. `.env.example` usa placeholders `replace-me-*`. |

---

### Manual Verification Required

**No requerida para aprobar la fase.** Tres truths verificadas con comandos reales; tests automáticos en verde.

(Opcional, si se quiere un check visual extra: correr `sh backend/scripts/verify_infra.sh` en WSL/git-bash para ver los 4 checks etiquetados `[CHECK N/4]` terminar en `ALL CHECKS PASSED`. No se ejecutó en esta verificación por no ser necesario — los 4 chequeos que hace el script ya fueron cubiertos individualmente: curl /health (Truth 1), charset/TZ/unicode (Truth 2), persistencia tras restart (Truth 2), env-swap (Truth 3).)

---

### Warnings (no bloqueantes)

#### W01 — 503 intermitente en `/health` tras idle (asyncmy/uvloop termination)

**Síntoma:** En runtime, se observó 1 de N requests a `/health` devolver 503 (con la excepción `RuntimeError: unable to perform operation on <TCPTransport closed=True ...>; the handler is closed` durante `pool._close_connection` → `asyncmy.do_terminate`).

**Mecanismo:** `pool_pre_ping=True` detecta conexiones stale (MySQL cerró la conexión por `wait_timeout`, o reset TCP). Al intentar **terminate** esa conexión para descartarla del pool, asyncmy/uvloop choca contra un transporte ya cerrado y lanza RuntimeError. Ese error **se propaga al endpoint** en lugar de limitarse al cleanup interno, resultando en 503.

**Recuperación:** El siguiente request crea una conexión fresh y retorna 200. Verificado: 8/8 requests estables tras el transient.

**Severidad:** WARNING (no BLOCKER) — la plataforma cumple su goal: levanta, conecta, persiste. El usuario final vería un retry exitoso.

**Acción recomendada:** No bloquea Phase 1. **Revisitar en Phase 7** (WebSockets) donde las conexiones long-lived son críticas. Posibles fixes a explorar: bump asyncmy versión, `pool_recycle` < MySQL `wait_timeout`, o un wrapper que absorba el RuntimeError en el termination path. Guardar como deuda técnica.

#### I01 — `uv` no está en PATH global del host

**Síntoma:** `uv run pytest tests/` falla desde PowerShell con `uv not recognized`. uv está instalado solo en `%APPDATA%\Python\Python314\Scripts\uv.exe` (Python 3.14, instalado vía `pip install --user uv` durante esta verificación).

**Impacto:** No afecta al stack Docker (que usa la imagen `ghcr.io/astral-sh/uv:0.12` self-contained). Para reproducir los tests Wave 0 desde host, hay que invocar uv por ruta completa o añadir el dir al PATH. uv creó un `.venv` con Python 3.12.13 automáticamente (respeta `requires-python=">=3.12"`).

**Acción recomendada:** Documentar en onboarding o instalar uv globalmente. No es deuda del Phase 1.

---

### Gaps Summary

**Sin gaps.** Las 3 truths del goal están verificadas con evidencia runtime directa:

- ✅ Stack levanta y `/health` responde 200 connected (Truth 1)
- ✅ Persistencia, charset, timezone, round-trip unicode verificados por tests y queries directas (Truth 2)
- ✅ Env-driven: cambiar `DB_NAME` por override produce 503 determinista; restaurar produce 200 (Truth 3)

**Tests:** 2/2 PASSED (`test_health_returns_connected`, `test_db_charset_tz_and_unicode`).

**Artefactos:** los 14 declarados en el PLAN existen, son sustantivos y están wired.

**Anti-patrones:** ninguno presente en código (los únicos 2 matches de grep son comentarios/docs explicando qué evitar).

**Warning W01** (transient 503 en asyncmy termination) es el único hallazgo notable; no bloquea la aceptación de Phase 1 pero queda registrado como deuda para Phase 7. La meta de la fase ("la plataforma corre, conectada, persistente, por .env") está cumplida.

---

_Verified: 2026-08-13T12:45:00Z_
_Verifier: Claude (gsd-verifier) — goal-backward, evidence-first_
_Method: comandos reales contra el stack corriendo + inspección de código + tests reproducidos (uv instalado on-demand)_
