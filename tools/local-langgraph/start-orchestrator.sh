#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/supabase/.env.local-langgraph"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE. Run tools/local-langgraph/setup-local-langgraph.sh first." >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "OPENAI_API_KEY is missing in $ENV_FILE." >&2
  exit 1
fi

export PORT="${PORT:-8787}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-5-mini}"
export TRAINING_ORCHESTRATOR_API_KEY="${TRAINING_ORCHESTRATOR_API_KEY:-local-langgraph-dev}"

cd "$ROOT_DIR/services/training-orchestrator"
npm run serve
