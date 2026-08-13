#!/usr/bin/env sh
# Manual acceptance for the whole of Phase 2 (Plans 02-01 + 02-02).
# Runs curl happy + sad paths against the live API at http://localhost:8000.
# Requires: curl, jq, sh, and SUPER_ADMIN_EMAIL/SUPER_ADMIN_PASSWORD in the env
# (the api container gets them from docker-compose env). Run after
# `docker compose up -d --build`.
#
# Sections:
#   CHECKS 1-6   AUTH FLOW       (AUTH-01/02 — Plan 02-01)
#   CHECKS 7-12  ADMIN PLATFORM  (PLAT-02/03 — Plan 02-02 Task 1)
#   CHECKS 13-15 ROLE ENFORCEMENT (AUTH-03 — Plan 02-02 Task 2)
#   CHECKS 16-19 MULTI-TENANT     (AUTH-04 — Plan 02-02 Task 2, hard gate 17)
set -euo pipefail

BASE="${BASE_URL:-http://localhost:8000}"
EMAIL="verify-$(date +%s)-$$@x.com"
PASS="S3cret0!"
STAFF_PASS="S3cret0!1"
UNIQ="$(date +%s)-$$"

fail() {
    echo "CHECK $1 FAILED — $2" >&2
    exit 1
}

# --- helper: HTTP status code of a request ------------------------------------
code() {
    # $1 = method, $2 = path, $3 = token ("" = none), $4 = JSON body ("" = none)
    if [ -n "$3" ] && [ -n "$4" ]; then
        curl -s -o /dev/null -w "%{http_code}" -X "$1" "$BASE$2" \
            -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4"
    elif [ -n "$3" ]; then
        curl -s -o /dev/null -w "%{http_code}" -X "$1" "$BASE$2" \
            -H "Authorization: Bearer $3"
    elif [ -n "$4" ]; then
        curl -s -o /dev/null -w "%{http_code}" -X "$1" "$BASE$2" \
            -H 'Content-Type: application/json' -d "$4"
    else
        curl -s -o /dev/null -w "%{http_code}" -X "$1" "$BASE$2"
    fi
}

echo "[CHECK 1/19] Register cliente -> 201, role=cliente, restaurant_id=null, no password_hash"
REG=$(code POST /auth/register "" "{\"nombre\":\"Verify\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$REG" = "201" ] || fail 1 "expected 201 got $REG"

BODY=$(curl -s -X POST "$BASE/auth/register" \
    -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Verify2\",\"email\":\"$EMAIL-x\",\"password\":\"$PASS\"}")
echo "$BODY" | jq -e '.role == "cliente"' >/dev/null || fail 1 "role != cliente"
echo "$BODY" | jq -e '.restaurant_id == null' >/dev/null || fail 1 "restaurant_id != null"
echo "$BODY" | jq -e 'has("password_hash") | not' >/dev/null || fail 1 "password_hash leaked"

echo "[CHECK 2/19] Register duplicate email -> 409"
DUP=$(code POST /auth/register "" "{\"nombre\":\"Dup\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$DUP" = "409" ] || fail 2 "expected 409 got $DUP"

echo "[CHECK 3/19] Login -> 200, access + refresh present"
TOKENS=$(curl -s -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
LOGIN_CODE=$(code POST /auth/login "" "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$LOGIN_CODE" = "200" ] || fail 3 "expected 200 got $LOGIN_CODE"
ACCESS=$(echo "$TOKENS" | jq -r '.access_token')
REFRESH=$(echo "$TOKENS" | jq -r '.refresh_token')
[ "$ACCESS" != "null" ] && [ -n "$ACCESS" ] || fail 3 "no access_token"
[ "$REFRESH" != "null" ] && [ -n "$REFRESH" ] || fail 3 "no refresh_token"

echo "[CHECK 4/19] Refresh -> 200 with NEW tokens (rotation)"
NEW=$(curl -s -X POST "$BASE/auth/refresh" \
    -H 'Content-Type: application/json' \
    -d "{\"refresh_token\":\"$REFRESH\"}")
REFRESH_CODE=$(code POST /auth/refresh "" "{\"refresh_token\":\"$REFRESH\"}")
[ "$REFRESH_CODE" = "200" ] || fail 4 "expected 200 got $REFRESH_CODE"
NEW_ACCESS=$(echo "$NEW" | jq -r '.access_token')
[ "$NEW_ACCESS" != "$ACCESS" ] || fail 4 "access token not rotated"

echo "[CHECK 5/19] /auth/me with access -> 200, correct email"
ME_CODE=$(code GET /auth/me "$ACCESS" "")
[ "$ME_CODE" = "200" ] || fail 5 "expected 200 got $ME_CODE"
ME=$(curl -s "$BASE/auth/me" -H "Authorization: Bearer $ACCESS")
echo "$ME" | jq -e ".email == \"$EMAIL\"" >/dev/null || fail 5 "email mismatch"

echo "[CHECK 6/19] /auth/me with NO token -> 401"
NOAUTH=$(code GET /auth/me "" "")
[ "$NOAUTH" = "401" ] || fail 6 "expected 401 got $NOAUTH"

# ===== ADMIN PLATFORM (PLAT-02, PLAT-03) ======================================

SA_EMAIL="${SUPER_ADMIN_EMAIL:?SUPER_ADMIN_EMAIL not set in env}"
SA_PASS="${SUPER_ADMIN_PASSWORD:?SUPER_ADMIN_PASSWORD not set in env}"

echo "[CHECK 7/19] Login super_admin (from env) -> 200 with tokens"
SA_LOGIN=$(curl -s -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$SA_EMAIL\",\"password\":\"$SA_PASS\"}")
SA_LOGIN_CODE=$(code POST /auth/login "" "{\"email\":\"$SA_EMAIL\",\"password\":\"$SA_PASS\"}")
[ "$SA_LOGIN_CODE" = "200" ] || fail 7 "expected 200 got $SA_LOGIN_CODE"
SA_ACCESS=$(echo "$SA_LOGIN" | jq -r '.access_token')
[ "$SA_ACCESS" != "null" ] && [ -n "$SA_ACCESS" ] || fail 7 "no super_admin access_token"

echo "[CHECK 8/19] POST /admin/restaurantes -> 201 with .id and .activo==true"
REST_BODY=$(curl -s -X POST "$BASE/admin/restaurantes" \
    -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Verify Rest $UNIQ\",\"descripcion\":\"verify\",\"tipo_cocina\":\"Fusion\",\"direccion\":\"Calle Verify $UNIQ\"}")
REST_CODE=$(code POST /admin/restaurantes "$SA_ACCESS" "{\"nombre\":\"Verify Rest Code $UNIQ\"}")
[ "$REST_CODE" = "201" ] || fail 8 "expected 201 got $REST_CODE"
REST_ID=$(echo "$REST_BODY" | jq -r '.id')
[ "$REST_ID" != "null" ] && [ -n "$REST_ID" ] || fail 8 "no .id in response"
echo "$REST_BODY" | jq -e '.activo == true' >/dev/null || fail 8 ".activo != true"

echo "[CHECK 9/19] GET /admin/restaurantes -> 200 lista >= 1 (todos activos)"
LIST_CODE=$(code GET /admin/restaurantes "$SA_ACCESS" "")
[ "$LIST_CODE" = "200" ] || fail 9 "expected 200 got $LIST_CODE"
LIST=$(curl -s "$BASE/admin/restaurantes" -H "Authorization: Bearer $SA_ACCESS")
COUNT=$(echo "$LIST" | jq 'length')
[ "$COUNT" -ge 1 ] || fail 9 "list has $COUNT rows (expected >= 1)"
echo "$LIST" | jq -e 'all(.activo == true)' >/dev/null || fail 9 "list contains inactive rows"

echo "[CHECK 10/19] POST staff role=mesero -> 201 .role==mesero .restaurant_id==id"
STAFF_EMAIL="verify-staff-$UNIQ@gri.dev"
STAFF_BODY=$(curl -s -X POST "$BASE/admin/restaurantes/$REST_ID/staff" \
    -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Verify Mesero\",\"email\":\"$STAFF_EMAIL\",\"password\":\"$STAFF_PASS\",\"role\":\"mesero\"}")
STAFF_CODE=$(code POST "/admin/restaurantes/$REST_ID/staff" "$SA_ACCESS" "{\"nombre\":\"Otro\",\"email\":\"verify-staff2-$UNIQ@gri.dev\",\"password\":\"$STAFF_PASS\",\"role\":\"mesero\"}")
[ "$STAFF_CODE" = "201" ] || fail 10 "expected 201 got $STAFF_CODE"
echo "$STAFF_BODY" | jq -e '.role == "mesero"' >/dev/null || fail 10 ".role != mesero"
echo "$STAFF_BODY" | jq -e ".restaurant_id == $REST_ID" >/dev/null || fail 10 ".restaurant_id != $REST_ID"

echo "[CHECK 11/19] POST staff role=cliente -> 422 (staff-only enum)"
INVALID_ROLE=$(code POST "/admin/restaurantes/$REST_ID/staff" "$SA_ACCESS" "{\"nombre\":\"No Cliente\",\"email\":\"verify-cli-$UNIQ@gri.dev\",\"password\":\"$STAFF_PASS\",\"role\":\"cliente\"}")
[ "$INVALID_ROLE" = "422" ] || fail 11 "expected 422 got $INVALID_ROLE"

echo "[CHECK 12/19] POST staff a restaurante inexistente (999999) -> 404"
MISSING=$(code POST "/admin/restaurantes/999999/staff" "$SA_ACCESS" "{\"nombre\":\"Fantasma\",\"email\":\"verify-ghost-$UNIQ@gri.dev\",\"password\":\"$STAFF_PASS\",\"role\":\"mesero\"}")
[ "$MISSING" = "404" ] || fail 12 "expected 404 got $MISSING"

# ===== ROLE ENFORCEMENT (AUTH-03) =============================================

echo "[CHECK 13/19] Registrar + login cliente -> token cliente"
CLI_EMAIL="verify-cli2-$UNIQ@x.com"
CLI_REG=$(code POST /auth/register "" "{\"nombre\":\"Cli\",\"email\":\"$CLI_EMAIL\",\"password\":\"$PASS\"}")
[ "$CLI_REG" = "201" ] || fail 13 "expected 201 got $CLI_REG"
CLI_TOKENS=$(curl -s -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$CLI_EMAIL\",\"password\":\"$PASS\"}")
CLI_ACCESS=$(echo "$CLI_TOKENS" | jq -r '.access_token')
[ "$CLI_ACCESS" != "null" ] && [ -n "$CLI_ACCESS" ] || fail 13 "cliente login failed"

echo "[CHECK 14/19] POST /admin/restaurantes con token cliente -> 403"
CLI_FORBIDDEN=$(code POST /admin/restaurantes "$CLI_ACCESS" "{\"nombre\":\"Rest de Cliente\"}")
[ "$CLI_FORBIDDEN" = "403" ] || fail 14 "expected 403 got $CLI_FORBIDDEN"

echo "[CHECK 15/19] POST /admin/restaurantes sin token -> 401"
NO_TOKEN=$(code POST /admin/restaurantes "" "{\"nombre\":\"Anon\"}")
[ "$NO_TOKEN" = "401" ] || fail 15 "expected 401 got $NO_TOKEN"

# ===== MULTI-TENANT ISOLATION (AUTH-04) =======================================

echo "[CHECK 16/19] Crear restaurantes A + B, mesero para A, login mesero"
REST_A=$(curl -s -X POST "$BASE/admin/restaurantes" \
    -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"TenantA-$UNIQ\",\"tipo_cocina\":\"Fusion\"}")
REST_B=$(curl -s -X POST "$BASE/admin/restaurantes" \
    -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"TenantB-$UNIQ\",\"tipo_cocina\":\"Parrilla\"}")
ID_A=$(echo "$REST_A" | jq -r '.id')
ID_B=$(echo "$REST_B" | jq -r '.id')
[ "$ID_A" != "null" ] && [ -n "$ID_A" ] || fail 16 "restaurante A not created"
[ "$ID_B" != "null" ] && [ -n "$ID_B" ] || fail 16 "restaurante B not created"
MESERO_EMAIL="verify-juan-$UNIQ@gri.dev"
MESERO=$(curl -s -X POST "$BASE/admin/restaurantes/$ID_A/staff" \
    -H "Authorization: Bearer $SA_ACCESS" -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Juan\",\"email\":\"$MESERO_EMAIL\",\"password\":\"$STAFF_PASS\",\"role\":\"mesero\"}")
echo "$MESERO" | jq -e ".restaurant_id == $ID_A" >/dev/null || fail 16 "mesero not bound to A"
MESERO_TOKENS=$(curl -s -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$MESERO_EMAIL\",\"password\":\"$STAFF_PASS\"}")
MESERO_ACCESS=$(echo "$MESERO_TOKENS" | jq -r '.access_token')
[ "$MESERO_ACCESS" != "null" ] && [ -n "$MESERO_ACCESS" ] || fail 16 "mesero login failed"

echo "[CHECK 17/19] Mesero A GET /admin/restaurantes/{B} -> 404 (NO 200, NO 403)"
CROSS=$(code GET "/admin/restaurantes/$ID_B" "$MESERO_ACCESS" "")
[ "$CROSS" = "404" ] || fail 17 "expected 404 got $CROSS (cross-tenant must be 404)"

echo "[CHECK 18/19] Mesero A GET /admin/restaurantes/{A} -> 200 (su propio tenant)"
OWN=$(code GET "/admin/restaurantes/$ID_A" "$MESERO_ACCESS" "")
[ "$OWN" = "200" ] || fail 18 "expected 200 got $OWN"

echo "[CHECK 19/19] Super_admin GET /admin/restaurantes/{B} -> 200 (sin filtro tenant)"
SA_ANY=$(code GET "/admin/restaurantes/$ID_B" "$SA_ACCESS" "")
[ "$SA_ANY" = "200" ] || fail 19 "expected 200 got $SA_ANY"

echo "ALL CHECKS PASSED"
