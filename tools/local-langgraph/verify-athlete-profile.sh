#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/supabase/.env.local-langgraph"
REQUEST_FIXTURE="$ROOT_DIR/supabase/functions/onboarding-ai/test-fixtures/rich-hybrid-request.json"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Run tools/local-langgraph/setup-local-langgraph.sh first." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for required in SUPABASE_URL SUPABASE_ANON_KEY HAYF_LOCAL_AUTH_EMAIL HAYF_LOCAL_AUTH_PASSWORD; do
  if [ -z "${!required:-}" ]; then
    echo "Missing $required in $ENV_FILE." >&2
    exit 1
  fi
done

auth_body="$(jq -nc \
  --arg email "$HAYF_LOCAL_AUTH_EMAIL" \
  --arg password "$HAYF_LOCAL_AUTH_PASSWORD" \
  '{email:$email,password:$password}')"
auth_response="$(curl -sS --max-time 20 \
  -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  --data "$auth_body")"
access_token="$(printf '%s' "$auth_response" | jq -er '.access_token')"

now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
request_body="$(jq -c --arg now "$now" \
  'walk(if type == "string" and . == "__NOW__" then $now else . end)' \
  "$REQUEST_FIXTURE")"
response="$(curl -sS --max-time 75 \
  -X POST "$SUPABASE_URL/functions/v1/onboarding-ai" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  --data "$request_body")"

printf '%s' "$response" | jq -e '
  .profileScoring.status == "success" and
  .output.profileScores.schemaVersion == "athlete-profile-scores.v1" and
  .output.profileScores.scoreVersion == "profile-radar-v1.2.0" and
  ([.output.profileScores.dimensions[].key] == [
    "consistency",
    "momentum",
    "strength",
    "training_base",
    "endurance"
  ])
' >/dev/null

printf '%s' "$response" | jq -r '
  "Forte Dev radar preflight passed: " +
  ([.output.profileScores.dimensions[] | "\(.key)=\(.score // "—")"] | join(", "))
'
