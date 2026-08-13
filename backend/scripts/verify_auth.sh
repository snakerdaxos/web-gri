#!/usr/bin/env sh
# Manual acceptance for AUTH-01 + AUTH-02 (Phase 2 Plan 01).
# Runs curl happy + sad paths against the live API at http://localhost:8000.
# Requires: curl, jq, sh. Run after `docker compose up -d --build`.
#
# Plan 02-02 extends this script with the role/tenant/admin sections and
# renames the final banner to the overall "ALL CHECKS PASSED".
set -euo pipefail

BASE="${BASE_URL:-http://localhost:8000}"
EMAIL="verify-$(date +%s)-$$@x.com"
PASS="S3cret0!"

fail() {
    echo "AUTH FLOW: CHECK $1 FAILED — $2" >&2
    exit 1
}

echo "[CHECK 1/6] Register cliente -> 201, role=cliente, restaurant_id=null, no password_hash"
REG=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/register" \
    -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Verify\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$REG" = "201" ] || fail 1 "expected 201 got $REG"

BODY=$(curl -s -X POST "$BASE/auth/register" \
    -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Verify2\",\"email\":\"$EMAIL-x\",\"password\":\"$PASS\"}")
echo "$BODY" | jq -e '.role == "cliente"' >/dev/null || fail 1 "role != cliente"
echo "$BODY" | jq -e '.restaurant_id == null' >/dev/null || fail 1 "restaurant_id != null"
echo "$BODY" | jq -e 'has("password_hash") | not' >/dev/null || fail 1 "password_hash leaked"

echo "[CHECK 2/6] Register duplicate email -> 409"
DUP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/register" \
    -H 'Content-Type: application/json' \
    -d "{\"nombre\":\"Dup\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$DUP" = "409" ] || fail 2 "expected 409 got $DUP"

echo "[CHECK 3/6] Login -> 200, access + refresh present"
TOKENS=$(curl -s -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
LOGIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
[ "$LOGIN_CODE" = "200" ] || fail 3 "expected 200 got $LOGIN_CODE"
ACCESS=$(echo "$TOKENS" | jq -r '.access_token')
REFRESH=$(echo "$TOKENS" | jq -r '.refresh_token')
[ "$ACCESS" != "null" ] && [ -n "$ACCESS" ] || fail 3 "no access_token"
[ "$REFRESH" != "null" ] && [ -n "$REFRESH" ] || fail 3 "no refresh_token"

echo "[CHECK 4/6] Refresh -> 200 with NEW tokens (rotation)"
NEW=$(curl -s -X POST "$BASE/auth/refresh" \
    -H 'Content-Type: application/json' \
    -d "{\"refresh_token\":\"$REFRESH\"}")
REFRESH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/refresh" \
    -H 'Content-Type: application/json' \
    -d "{\"refresh_token\":\"$REFRESH\"}")
[ "$REFRESH_CODE" = "200" ] || fail 4 "expected 200 got $REFRESH_CODE"
NEW_ACCESS=$(echo "$NEW" | jq -r '.access_token')
[ "$NEW_ACCESS" != "$ACCESS" ] || fail 4 "access token not rotated"

echo "[CHECK 5/6] /auth/me with access -> 200, correct email"
ME_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/auth/me" \
    -H "Authorization: Bearer $ACCESS")
[ "$ME_CODE" = "200" ] || fail 5 "expected 200 got $ME_CODE"
ME=$(curl -s "$BASE/auth/me" -H "Authorization: Bearer $ACCESS")
echo "$ME" | jq -e ".email == \"$EMAIL\"" >/dev/null || fail 5 "email mismatch"

echo "[CHECK 6/6] /auth/me with NO token -> 401"
NOAUTH=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/auth/me")
[ "$NOAUTH" = "401" ] || fail 6 "expected 401 got $NOAUTH"

echo "AUTH FLOW: ALL CHECKS PASSED"
