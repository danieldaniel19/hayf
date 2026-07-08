#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/supabase/.env.local-langgraph"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Run tools/local-langgraph/setup-local-langgraph.sh first." >&2
  exit 1
fi

cd "$ROOT_DIR"
npx supabase functions serve --env-file "$ENV_FILE"
