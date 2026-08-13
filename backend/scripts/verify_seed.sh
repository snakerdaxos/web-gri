#!/bin/sh
# Manual acceptance for Phase 3 Plan 02 (INFR-03 + PLAT-04 + SC2).
#
# Verifica end-to-end que:
#   1. El boot del API siembra restaurante + 8 mesas + 4 cats + 16 productos + 5 usuarios demo.
#   2. Re-correr el seed (lo que el lifespan hace en cada restart) deja los mismos counts.
#
# Precondiciones:
#   - Stack up con migración 0002 aplicada (docker compose up -d --build).
#   - DEMO_MODE=true en .env (si no, el seed no corre y este script falla).
#
# Cómo correrlo (dentro del contenedor api — evita quoting PowerShell):
#   docker exec -w /app gri-api sh scripts/verify_seed.sh
#
# Nota: el api container no tiene cliente mysql pero SÍ tiene Python + SQLAlchemy
# + asyncmy. Todos los queries van via Python contra la misma BD del stack. El
# "restart" se simula re-invocando seed_if_demo_mode vía Python, que es
# exactamente lo que el lifespan ejecuta en cada docker restart. Para una
# verificación adicional con `docker restart gri-api` real, ver el comentario
# al final de este script.
#
# El script delega TODA la lógica de queries + comparación a verify_seed.py
# (Python puro) para evitar artefactos de quoting de sh heredando SQL.
# PYTHONPATH=/app garantiza que `from app.* import` resuelva (WORKDIR=/app
# solo afecta sh, no el sys.path de Python al correr un script).
#
# Las 8 secciones numeradas (== N. title ==) y la lógica before/after viven en
# verify_seed.py — juntas, verify_seed.sh + verify_seed.py componen la suite de
# aceptación INFR-03. La última línea ejecutable de este .sh es el marker
# canónico de éxito (igual que verify_auth.sh).
set -eu

PYTHONPATH=/app python scripts/verify_seed.py

echo "ALL CHECKS PASSED"
