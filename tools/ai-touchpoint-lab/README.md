# AI Touchpoint Lab

Local browser tool for editing and testing HAYF AI touchpoint prompts and
parameters.

## Run

```sh
deno run \
  --allow-read=. \
  --allow-write=supabase/functions/_shared/ai-touchpoint-catalog.ts,tools/ai-touchpoint-lab/fixtures \
  --allow-run=git,/opt/homebrew/bin/deno \
  --allow-env=OPENAI_API_KEY,AI_TOUCHPOINT_LAB_PORT,OPENAI_MODEL \
  --allow-net=127.0.0.1,api.openai.com \
  tools/ai-touchpoint-lab/server.ts
```

Then open `http://127.0.0.1:8787`.

Use `AI_TOUCHPOINT_LAB_PORT=8788` to run on a different port. OpenAI test runs
require `OPENAI_API_KEY`.

The lab also loads local ignored env files automatically, in this order:

- `tools/ai-touchpoint-lab/.env.local`
- `supabase/.env.local`
- `supabase/functions/.env.local`
- `.env.local`
- `.env`

For example:

```sh
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-5-mini
```

## Persistence

The browser cannot write project files directly. Saves go through the local Deno
server, which only writes:

- `supabase/functions/_shared/ai-touchpoint-catalog.ts`
- JSON fixtures under `tools/ai-touchpoint-lab/fixtures/`

After saving a prompt change, the server runs `deno check` against the Supabase
functions and returns the current git diff.

## Mock fixtures

The lab ships with curated mock compact requests in `mock-fixtures.ts`. These
are based on the production Edge Function context builders and the trace shape
stored in `onboarding_ai_generations.compact_request` and
`planning_ai_generations.compact_request`.

Each mock uses:

- `task`: the production task name sent to the model
- `context`: the compact context object
- `candidates`: only when the production request includes candidate cards
