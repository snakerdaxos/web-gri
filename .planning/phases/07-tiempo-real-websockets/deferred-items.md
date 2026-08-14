# Deferred items — fuera de scope del plan (encontrados durante ejecución)

- **[2026-08-14] 07-01:** `ruff B904` pre-existente en
  `backend/app/services/sesion_service.py` (raise HTTPException dentro del
  `except IntegrityError` del Phase 6, mapeo 409 carrera de sesiones). Existe
  en HEAD antes de los cambios de 07-01. Fix de 1 palabra (`from None`) pero
  fuera del scope (Rule: no arreglar lint pre-existente de código no tocado).
- **[2026-08-14] 07-01:** los tests host con `db_session` requieren
  `$env:DB_PASSWORD = <MYSQL_APP_PASSWORD del .env raíz>` antes de
  `uv run pytest` (documentado en 01-01-SUMMARY; comportamiento conocido del
  proyecto, no un bug de 07-01).
