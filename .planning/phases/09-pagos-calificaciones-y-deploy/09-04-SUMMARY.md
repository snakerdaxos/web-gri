---
phase: 09-pagos-calificaciones-y-deploy
plan: 04
subsystem: infra
tags: [deploy, docker, nginx, tls, certbot, websocket, production, ubuntu]
requires:
  - "09-01: Settings SANDBOX_MODE/WOMPI_* + montaje condicional del router sandbox (404 real en prod)"
  - "backend/Dockerfile: CMD alembic upgrade head && uvicorn 1 worker (INFR-03 en boot)"
  - "docker-compose.yml dev: shape mysql+api a endurecer"
  - "panel_admin: flutter build web --release (estáticos del panel)"
provides:
  - "deploy/docker-compose.prod.yml: stack prod (mysql:8.4.11 pin, sin 3306 expuesto, api solo 127.0.0.1:8000, DEMO/SANDBOX locked false, project gri-prod)"
  - "deploy/nginx/gri.conf: reverse proxy TLS same-origin por paths (WS upgrade + http_version 1.1 + read_timeout 3600s, API -> 127.0.0.1:8000, panel SPA con cache 7d)"
  - ".env.production.example: template de secretos prod con política DEMO/SANDBOX=false + comandos de generación"
  - "deploy/README.md: guía reproducible Ubuntu 24.04 (12 secciones con comandos exactos)"
  - "deploy/verify_local.ps1 + verify_ws.py + local-verify.conf: smoke production-like automatizado y reproducible"
affects:
  - "deploy real post-fase (usuario, manual con README)"
  - "operación: updates/backups/rotación de secretos"
tech-stack:
  added:
    - "nginx:1.24 (apt Ubuntu 24.04 / contenedor de verificación) — proxy TLS + estáticos"
    - "certbot + python3-certbot-nginx (guía, host)"
    - "mysql:8.4.11 pin exacto prod (dev sigue en rolling 8.4)"
  patterns:
    - "Same-origin por paths: un dominio/un certificado, CERO CORS para el panel"
    - "nginx en el HOST (no Docker) — certbot --nginx gestiona cert+reload+renew sin reload-dance"
    - "Flags de seguridad locked en compose (DEMO_MODE/SANDBOX_MODE hardcodeados false — editar el .env jamás los re-activa)"
    - "Verificación local production-like: stack prod + nginx contenedor en la red del proyecto, teardown con restauración del stack dev en finally"
key-files:
  created:
    - deploy/docker-compose.prod.yml
    - deploy/nginx/gri.conf
    - deploy/nginx/local-verify.conf
    - deploy/README.md
    - deploy/verify_local.ps1
    - deploy/verify_ws.py
    - .env.production.example
  modified:
    - .gitignore
decisions:
  - "nginx en el HOST de Ubuntu con certbot nativo (no contenedor): evita el reload-dance de renewal cross-boundary (Pitfall 7)"
  - "DEMO_MODE/SANDBOX_MODE hardcodeados false en compose prod (defense-in-depth): el .env.production no puede re-activarlos"
  - "mysql:8.4.11 pin exacto (reproducibilidad) y SIN ports 3306; api publica SOLO 127.0.0.1:8000 — nginx del host es el único cliente"
  - "http2 como parámetro de listen (portable a nginx 1.24 del target) en vez de la directiva standalone `http2 on;` (requiere >= 1.25.1)"
  - "local-verify.conf proxya por NOMBRE de contenedor (gri-prod-api) dentro de la red docker del proyecto — gri.conf (host) usa 127.0.0.1:8000"
requirements-completed: [INFR-01, INFR-02, INFR-03]
metrics:
  duration: 25 min
  completed: 2026-08-15
---

# Phase 9 Plan 04: Artefactos de Deploy a Producción Summary

**Stack prod Docker endurecido (mysql:8.4.11 sin puertos, api solo 127.0.0.1:8000, migraciones en boot) + nginx host con TLS/certbot y proxy WS correcto, validado localmente 6/6 production-like (sandbox 404 real, WS con JWT a través del proxy, panel SPA) + guía Ubuntu reproducible**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-15T02:25Z (aprox. — el timestamp del primer comando fue inválido: `date -u` mal parseado por PS 5.1)
- **Completed:** 2026-08-15T02:50Z
- **Tasks:** 2/2
- **Files modified:** 8 (7 creados + .gitignore)

## Accomplishments

- **INFR-01/02 en configuración prod:** MySQL Docker persistente (volumen nombrado `gri_prod_mysql_data`) SIN exposición de 3306; API por configuración de entorno (`--env-file .env.production`) publicada solo en 127.0.0.1:8000 — nginx del host es el único cliente posible.
- **INFR-03 en prod:** mismo Dockerfile del dev (CMD `alembic upgrade head && uvicorn`, 1 worker SIN --workers) — migraciones automáticas en cada boot, verificadas en la corrida local (la API quedó healthy sobre BD recién migrada).
- **Verificación local production-like 6/6 PASO:** health directo y vía nginx, `/pagos/sandbox/*` = **404 real** (SANDBOX_MODE=false: el router no se monta), panel sirve index.html vía try_files SPA, **WebSocket con JWT real conecta a través del proxy nginx** (headers Upgrade + http_version 1.1 + read_timeout 3600s), stack dev restaurado al final.
- **Guía reproducible:** deploy/README.md (276 líneas, 12 secciones + apéndice) con cada comando exacto — Docker, secretos con generación `secrets.token_urlsafe`, nginx host, panel por rsync, certbot con auto-renew, verificación post-deploy, operación (update/logs/backup/rotación) y troubleshooting (WS 60s, sandbox 404 esperado, Wompi futuro).

## Task Commits

1. **Task 1: docker-compose.prod.yml + nginx/gri.conf + local-verify.conf + .env.production.example** — `cfc72eb` (feat)
2. **Task 2: README guía Ubuntu + verify_local.ps1 + verify_ws.py + verificación ejecutada** — `d3a6201` (feat)

## Files Created/Modified

- `deploy/docker-compose.prod.yml` — Stack prod: pin 8.4.11, sin 3306, 127.0.0.1:8000, flags locked, project gri-prod
- `deploy/nginx/gri.conf` — Proxy TLS producción: map Upgrade, :80 redirect, :443 con /ws/ + API regex + panel SPA
- `deploy/nginx/local-verify.conf` — Variante contenedor :8080 (proxya por nombre gri-prod-api) — solo verificación local
- `.env.production.example` — Template secretos con política y comandos de generación
- `deploy/README.md` — Guía Ubuntu 12 secciones paso a paso
- `deploy/verify_local.ps1` — Smoke prod-like automatizado con restauración del dev stack
- `deploy/verify_ws.py` — WS real (registro+login+JWT via httpx-ws) contra --base
- `.gitignore` — Cubre `.env.production*` con excepción del example

## Decisions Made

- Ver frontmatter `decisions` — 5 decisiones (nginx host+certbot, flags locked, pin/sin puertos, http2 portable, proxy por nombre en verificación local).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `http2 on;` no existe en nginx 1.24 (target real del deploy)**
- **Found during:** Task 1 (nginx -t del propio plan como variante sin ssl)
- **Issue:** El patrón §7 del research usaba la directiva standalone `http2 on;`, agregada en nginx **1.25.1** — Ubuntu 24.04 trae nginx **1.24** y el `nginx -t` fallaba con `unknown directive "http2"`: el servidor real no habría arrancado.
- **Fix:** `listen 443 ssl http2;` (parámetro de listen — válido en 1.24 y deprecated-pero-funcional en ≥1.25, portable para el target).
- **Files modified:** deploy/nginx/gri.conf
- **Verification:** nginx -t (nginx:1.24) OK en la variante sin ssl_certificate.
- **Committed in:** cfc72eb

**2. [Rule 3 - Blocking] `nginx -t` valida DNS del upstream de proxy_pass**
- **Found during:** Task 1 (verificación local-verify.conf)
- **Issue:** `nginx -t` resolve los hostnames de proxy_pass al chequear: `gri-prod-api` no existe con el stack caído → `[emerg] host not found in upstream` aunque la sintaxis sea correcta.
- **Fix:** Validación sintáctica con `--add-host gri-prod-api:127.0.0.1` (solo para el -t; en la corrida real el contenedor se conecta a `gri-prod_default` y resuelve de verdad). gri.conf usa IP 127.0.0.1 → no aplica.
- **Verification:** nginx -t OK para ambos archivos.
- **Committed in:** (sin cambio de archivo — método de validación documentado)

**3. [Rule 1 - Bug] verify_local.ps1: `$home` es variable automática de solo lectura en PowerShell**
- **Found during:** Task 2 (primera corrida de verify_local.ps1)
- **Issue:** `Invoke-WebRequest` asignado a `$home` → error terminante `SessionStateUnauthorizedAccessException` que saltaba los checks de panel y WS directamente al finally — con 4/0 PASO y **exit 0** (checks omitidos, no fallados): un falso verde peligroso.
- **Fix:** Renombrada a `$homeResp`; tras el fix la corrida completa dio 6/6 incluyendo panel y WS.
- **Files modified:** deploy/verify_local.ps1
- **Verification:** Segunda corrida: 6 PASO / 0 FAIL, exit 0.
- **Committed in:** d3a6201

**4. [Rule 1 - Bug] EAP=Stop + `2>&1` con comandos nativos en PS 5.1**
- **Found during:** Task 2 (primera corrida — murió en `docker compose down 2>&1`)
- **Issue:** Con `$ErrorActionPreference = "Stop"`, la primera línea de stderr de docker (progreso "Container gri-api Stopping") redirigida con `2>&1` se convierte en NativeCommandError terminante.
- **Fix:** EAP=Continue + checks explícitos de `$LASTEXITCODE` en cada paso crítico (docker up, nginx run, flutter build, verify_ws).
- **Files modified:** deploy/verify_local.ps1
- **Verification:** Corrida completa 6/6.
- **Committed in:** d3a6201

---

**Total deviations:** 4 auto-fixed (3 bugs + 1 blocking)
**Impact on plan:** Todas dentro del scope de los artefactos del plan (ninguna tocó backend/ ni panel_admin/ código). La 1 y la 3 eran falsos-verdes/server-no-arranca que la propia verificación del plan detectó — el sistema funcionó como estaba diseñado.

## Issues Encountered

- `panel_admin/build/web` no existía al empezar (no se había hecho build del panel): construido con `flutter build web --release` (3.47.0, 30.8s) como paso previo; el script mantiene el build-if-missing (PATH `C:\src\flutter\bin`) para reproducibilidad. El build NO se commitea (gitignored).
- La nota de secuencia del orquestador se cumplió: verify_local.ps1 baja/restaura el stack dev (ventana de ~4 min con el dev caído durante la verificación — coordinado con el agente paralelo de app_cliente).

## Verification Evidence

- `docker compose --env-file .env.production.temp -f deploy/docker-compose.prod.yml config -q` → **COMPOSE-OK** (sin warnings de vars faltantes).
- nginx -t (nginx:1.24): local-verify.conf **OK** (--add-host para DNS); gri.conf **OK** en variante sin ssl_certificate (lo anticipado por el plan — los certificados los crea certbot en el servidor).
- `powershell -File deploy\verify_local.ps1` → **6 PASO / 0 FAIL, exit 0**:
  1. health API directa :8000 (200 tras boot con migraciones)
  2. sandbox OFF en prod real (/pagos/sandbox/* = 404, no 403/500)
  3. health via nginx :8080 (proxy + regex location)
  4. panel sirve index.html via / (try_files SPA)
  5. WebSocket con JWT real a través de nginx (verify_ws.py → WS-OK, handshake 101)
  6. stack DEV restaurado arriba (health 200)
- Post-teardown: sin residuo (.env.production.local eliminado, contenedores gri-nginx-verify/gri-prod-* removidos, `docker compose ps` muestra gri-api + gri-mysql healthy).
- Anti-patrones verificados: 0 `3306:3306`, 0 `--workers` reales, `mysql:8.4.11` literal, .env.production gitignored y example NO ignorado (`git check-ignore`).

## User Setup Required

Sin archivo USER-SETUP.md (el plan no lo genera). El setup manual queda documentado en dos lugares:
- **Deploy real post-fase (manual):** deploy/README.md §1-§12 — DNS A, ufw 80/443, secretos con `secrets.token_urlsafe`, certbot `--nginx`.
- **Wompi (cuando el KYC esté aprobado):** deploy/README.md §12 — 4 keys en .env.production (SANDBOX_MODE queda false) + webhook `https://{dominio}/webhooks/pago` en el dashboard.

## Next Phase Readiness

- Fase FINAL del roadmap: INFR-01/02/03 verificados en configuración de producción + artefactos y guía listos para el servidor real.
- El deploy real (Ubuntu Server) es post-fase y manual (sin SSH desde esta máquina) — todo lo necesario está en deploy/README.md.

## Self-Check: PASSED

7/7 archivos verificados en disco · 2/2 commits de tarea verificados en git log · README 276 líneas (must_have ≥ 80) · patrón `proxy_pass http://127.0.0.1:8000` presente en gri.conf · `contains: 8.4.11` y `contains: proxy_http_version 1.1` verificados.
