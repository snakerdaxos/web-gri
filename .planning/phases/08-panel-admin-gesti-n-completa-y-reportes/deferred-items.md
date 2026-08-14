# Deferred Items — Phase 08

## [Fuera de alcance — Wave 2] 72 mesas fantasma GRI-TEST-* acumuladas en restaurante 1 (dev DB)

- **Detectado:** 08-02 Task 1 verification (invariante post-suite).
- **Fuente:** `backend/tests/test_domain_constraints.py` — `test_qr_formato_demo` (línea ~141: `db_session.add(Mesa(...)); flush()` SIN cleanup, `numero = hash(uuid4) % 9000 + 1000`) y fixtures `GRI-TEST-*` del mismo archivo (~línea 83). Una mesa leak por test por run; 72 acumuladas a la fecha (todas con created_at anterior a 08-02).
- **Impacto:** las mesas fantasma aparecen en `GET /staff/mesas` del demo (rid=1) y renderizarían en el mapa del panel cuando llegue 08-03/08-05. Solo BD de dev — producción no corre pytest.
- **No arreglado aquí:** pre-existente, archivo no tocado por esta wave (SCOPE BOUNDARY). 
- **Sugerencia:** (a) cleanup try/finally en esa suite, o (b) purge one-off `DELETE FROM mesa WHERE codigo_qr LIKE 'GRI-TEST-%' OR (codigo_qr LIKE 'GRI-MESA-%' AND codigo_qr NOT REGEXP '^GRI-MESA-[0-9]{3}$')` + assert de invariante en conftest.
- **Verificación propia:** 08-02 NO aporta residuo (`codigo_qr LIKE 'GRI-MESA-R%'` = 0 filas tras 2 runs completos).
