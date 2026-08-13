#!/usr/bin/env bash
# verify_infra.sh — Phase 1 manual acceptance script.
# Proves the 3 ROADMAP Success Criteria (INFR-01 + INFR-02) end-to-end against
# a running `docker compose up -d` stack.
#
# Run from repo root:  sh backend/scripts/verify_infra.sh
# (Git Bash / WSL on Windows; any POSIX sh on Linux/macOS.)
set -euo pipefail

# Resolve repo root relative to this script so it can be invoked from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Prefer an explicit env var; fall back to the value in .env (dev secrets).
if [ -z "${MYSQL_APP_PASSWORD:-}" ]; then
  if [ -f .env ]; then
    # shellcheck disable=SC1091
    MYSQL_APP_PASSWORD="$(grep -E '^MYSQL_APP_PASSWORD=' .env | head -n1 | cut -d= -f2-)"
    export MYSQL_APP_PASSWORD
  fi
fi

if [ -z "${MYSQL_APP_PASSWORD:-}" ]; then
  echo "FATAL: MYSQL_APP_PASSWORD is not set and .env has no MYSQL_APP_PASSWORD." >&2
  echo "       Export it or run from a repo that has a .env file." >&2
  exit 2
fi

API_URL="${API_URL:-http://localhost:8000}"
MYSQL_USER="${MYSQL_USER:-gri_app}"
MYSQL_DB="${MYSQL_DB:-gri}"

echo "============================================================"
echo "  GRI Phase 1 — verify_infra.sh"
echo "  API: $API_URL   MySQL user: $MYSQL_USER   DB: $MYSQL_DB"
echo "============================================================"

echo ""
echo "[CHECK 1/4] GET /health -> 200 with database: connected"
HEALTH_BODY="$(curl -fsS "$API_URL/health")"
echo "  body: $HEALTH_BODY"
if ! echo "$HEALTH_BODY" | grep -q '"database":"connected"'; then
  echo "  FAIL: /health did not report database: connected" >&2
  exit 1
fi
echo "  OK"
echo ""

echo "[CHECK 2/4] MySQL charset=utf8mb4, collation=utf8mb4_unicode_ci, tz=-05:00, 4-byte round-trip"
# Heredoc runs several statements in one mysql session. -sN silences tabular headers.
SQL_OUTPUT="$(docker exec -i gri-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_APP_PASSWORD" "$MYSQL_DB" -sN 2>/dev/null <<'SQL'
SELECT CONCAT('charset=', @@character_set_database,
              ' collation=', @@collation_database,
              ' tz=', @@global.time_zone);
CREATE TABLE IF NOT EXISTS infra_probe (v VARCHAR(50) CHARACTER SET utf8mb4) ENGINE=InnoDB;
TRUNCATE TABLE infra_probe;
INSERT INTO infra_probe (v) VALUES ('Açaí 🍜 café Bogotá');
SELECT CONCAT('roundtrip=', v) FROM infra_probe;
SQL
)"
echo "$SQL_OUTPUT"
if ! echo "$SQL_OUTPUT" | grep -q 'charset=utf8mb4'; then
  echo "  FAIL: charset is not utf8mb4" >&2; exit 1
fi
if ! echo "$SQL_OUTPUT" | grep -q 'collation=utf8mb4_unicode_ci'; then
  echo "  FAIL: collation is not utf8mb4_unicode_ci" >&2; exit 1
fi
if ! echo "$SQL_OUTPUT" | grep -q 'tz=-05:00'; then
  echo "  FAIL: global time_zone is not -05:00" >&2; exit 1
fi
if ! echo "$SQL_OUTPUT" | grep -q 'roundtrip=Açaí 🍜 café Bogotá'; then
  echo "  FAIL: accented+emoji string did not round-trip intact" >&2; exit 1
fi
echo "  OK"
echo ""

echo "[CHECK 3/4] Data survives 'docker compose restart mysql'"
echo "  restarting mysql..."
docker compose restart mysql >/dev/null
echo "  waiting for mysql to become healthy again..."
# Poll docker compose ps for the healthy state (matches the compose healthcheck).
for i in $(seq 1 30); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' gri-mysql 2>/dev/null || echo none)"
  if [ "$STATUS" = "healthy" ]; then
    echo "  mysql healthy after ~$((i*2))s"
    break
  fi
  sleep 2
done
if [ "$STATUS" != "healthy" ]; then
  echo "  FAIL: mysql did not return to healthy within 60s" >&2; exit 1
fi
PERSISTED="$(docker exec gri-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_APP_PASSWORD" "$MYSQL_DB" -sN \
  -e "SELECT v FROM infra_probe;" 2>/dev/null)"
echo "  row after restart: $PERSISTED"
if [ "$PERSISTED" != "Açaí 🍜 café Bogotá" ]; then
  echo "  FAIL: persisted row does not match what we inserted" >&2; exit 1
fi
echo "  OK"
echo ""

echo "[CHECK 4/4] env-driven connection (INFR-02) — DOCUMENTED manual test"
cat <<'DOC'
  To prove that changing .env / docker-compose.yml changes the connection
  with zero code edits (INFR-02):

    A) Wrong DB_NAME -> /health returns 503.
       Edit docker-compose.yml, api.environment:
           DB_NAME: gri_does_not_exist
       Then:
           docker compose up -d api
           curl -s http://localhost:8000/health
       Expect: HTTP 503 {"status":"error","database":"unreachable",
                          "detail":"... 1049 Unknown database ..."}
       Revert DB_NAME to 'gri' and `docker compose up -d api` to recover.

    B) Wrong DB_PASSWORD -> /health returns 503.
       Edit .env: MYSQL_APP_PASSWORD=wrong-secret
       Then: docker compose up -d api && curl -s http://localhost:8000/health
       Expect: HTTP 503 with "... 1045 Access denied ..."
       Revert .env to recover.

  (These are not run automatically because they mutate compose state and
   require a re-up. The Wave 0 test test_health_returns_connected proves the
   positive path; this documents the negative path.)
DOC
echo "  OK (documented)"
echo ""

echo "============================================================"
echo "  ALL CHECKS PASSED"
echo "============================================================"
