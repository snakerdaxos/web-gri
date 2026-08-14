# Deferred Items — Phase 08

## [Fuera de alcance — Wave 2] 72 mesas fantasma GRI-TEST-* acumuladas en restaurante 1 (dev DB)

- **Detectado:** 08-02 Task 1 verification (invariante post-suite).
- **Fuente:** `backend/tests/test_domain_constraints.py` — `test_qr_formato_demo` (línea ~141: `db_session.add(Mesa(...)); flush()` SIN cleanup, `numero = hash(uuid4) % 9000 + 1000`) y fixtures `GRI-TEST-*` del mismo archivo (~línea 83). Una mesa leak por test por run; 72 acumuladas a la fecha (todas con created_at anterior a 08-02).
- **Impacto:** las mesas fantasma aparecen en `GET /staff/mesas` del demo (rid=1) y renderizarían en el mapa del panel cuando llegue 08-03/08-05. Solo BD de dev — producción no corre pytest.
- **No arreglado aquí:** pre-existente, archivo no tocado por esta wave (SCOPE BOUNDARY). 
- **Sugerencia:** (a) cleanup try/finally en esa suite, o (b) purge one-off `DELETE FROM mesa WHERE codigo_qr LIKE 'GRI-TEST-%' OR (codigo_qr LIKE 'GRI-MESA-%' AND codigo_qr NOT REGEXP '^GRI-MESA-[0-9]{3}$')` + assert de invariante en conftest.
- **Verificación propia:** 08-02 NO aporta residuo (`codigo_qr LIKE 'GRI-MESA-R%'` = 0 filas tras 2 runs completos).

## [Fuera de alcance — Wave 5] Backend pytest 165/181: residuo de datos acumulado en BD demo + .env no visible desde backend/

- **Detectado:** 08-05 verification (sanity check — este plan NO toca backend; `git status backend/` limpio, cero cambios).
- **Causa 1 (conexión):** `Settings` lee `.env` relativo al CWD → correr `uv run pytest` desde `backend/` sin `backend/.env` ni `$env:DB_PASSWORD` produce `Access denied for user 'gri_app' (using password: NO)` (103 fallos). Workaround usado: `$env:DB_PASSWORD` = `MYSQL_APP_PASSWORD` del `.env` raíz.
- **Causa 2 (estado de datos):** con la conexión OK quedan 16 fallos por residuo ACUMULADO post-08-02 en el restaurante demo (rid=1): `test_seed_crea_demo assert 15 == 8` (7 mesas extra creadas por UAT manual de 08-03/08-04 contra el stack), `test_staff_menu/clientes/reportes/reservas/public_read` dependientes de datos limpios. Ningún archivo de código backend cambió — es drift del estado de la BD de dev.
- **No arreglado aquí:** pre-existente/ambiental, fuera de SCOPE BOUNDARY (08-05 es panel-only).
- **Sugerencia:** (a) purge de datos del demo (mesas > 8, pedidos/categorías de UAT) antes del sanity check de fase; (b) hacer que `Settings` resuelva el `.env` del project root (`parents[1]`) o exportar DB_* en la sesión; (c) suite-seed determinista (re-seed idempotente en fixture) para desacoplar tests del estado.
- **Nota:** los tests panel de 08-05 usan fakes (cero red) — este residuo no afecta la suite Flutter (61/61).
