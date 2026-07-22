# Local LangGraph Simulator Proof

This runbook proves the real LangGraph planning flow locally without hosting the orchestrator.

Current status: this path has been implemented on `codex/local-langgraph-proof` and has successfully run simulator onboarding -> strategy reveal -> accept strategy -> two visible weeks against local Supabase and the local orchestrator.

Target runtime:

```text
iOS Simulator
 -> local Supabase API/Auth/DB/Edge Functions
   -> local training-orchestrator LangGraph service
     -> OpenAI
```

Hosted Supabase is not changed by this flow.

## One-Time Setup

1. Start Docker Desktop.

2. Start local Supabase from the repo root:

   ```bash
   npx supabase start
   ```

3. Create local env, update the `HAYF Local LangGraph` Xcode scheme with the local anon key, and create the local dev auth user:

   ```bash
   tools/local-langgraph/setup-local-langgraph.sh
   ```

   The script creates `supabase/.env.local-langgraph`, which is ignored by git. If `supabase/.env.local` has `OPENAI_API_KEY`, the script copies it into the local file.

4. If needed, manually edit `supabase/.env.local-langgraph` and set:

   ```text
   OPENAI_API_KEY=<server-side dev key>
   OPENAI_MODEL=gpt-5-mini
   ATHLETE_PROFILE_ENGINE_URL=http://host.docker.internal:54321/functions/v1/athlete-profile-engine
   ATHLETE_PROFILE_ENGINE_API_KEY=local-athlete-profile-engine-dev
   ATHLETE_PROFILE_ENGINE_TIMEOUT_MS=10000
   TRAINING_ORCHESTRATOR_URL=http://host.docker.internal:8787
   TRAINING_ORCHESTRATOR_API_KEY=local-langgraph-dev
   TRAINING_ORCHESTRATOR_REQUIRED=true
   ```

## Run The Proof

Use three terminal windows.

### Terminal 1: Orchestrator

```bash
tools/local-langgraph/start-orchestrator.sh
```

Verify:

```bash
curl http://127.0.0.1:8787/health
```

Expected provider later in graph runs: `hayf-training-orchestrator`.

Expected health response:

```json
{
  "ok": true,
  "service": "@hayf/training-orchestrator",
  "version": "training-architect-consultants-v1"
}
```

### Terminal 2: Edge Functions

```bash
tools/local-langgraph/serve-functions.sh
```

This serves local `onboarding-ai` and `planning-ai` with `TRAINING_ORCHESTRATOR_REQUIRED=true`, so plan generation fails instead of silently using the local deterministic bridge if the orchestrator is unreachable.

### Xcode

Before opening Xcode, verify the exact Athlete Blueprint scoring path:

```bash
tools/local-langgraph/verify-athlete-profile.sh
```

Do not run onboarding unless this prints `Forte Dev radar preflight passed`.

1. Select the shared scheme `Forte Dev` or `HAYF Local LangGraph`.
2. Run on an iOS simulator.
3. The app auto-signs into the local Supabase user in Debug builds only.
4. Complete onboarding.
5. Generate/reveal strategy.
6. Accept strategy.
7. Confirm the Plan tab shows current week plus next week.

## Proof Queries

After accepting the strategy:

```bash
tools/local-langgraph/query-proof.sh
```

Check:

- `ai_graph_runs` prepare run provider is `hayf-training-orchestrator`.
- No prepare run provider is `edge-local-contract-bridge`.
- Node outputs include Training Architecture and Fitness Strategy stages.
- Tool calls include:
  - `consult_cycling_specialist`, `consult_running_specialist`, and/or `consult_strength_specialist` for selected modalities
  - `synthesize_training_architecture`
  - `author_training_architecture_reasoning`
  - `generate_fitness_strategy_targets`
  - `generate_fitness_strategy`
  - `compile_two_week_plan`
- `weekly_plans`, `planned_workouts`, and `planning_targets` exist.

Useful direct audit query for modality leaks:

```bash
npx supabase db query --local "
select
  id,
  created_at,
  input_json #> '{goal_context,selected_modality_order}' as input_modalities,
  output_json #> '{trainingArchitecture,priority_order}' as architecture_modalities,
  output_json #>> '{fitnessStrategy,operatingRhythm,summary}' as strategy_rhythm_summary
from ai_graph_runs
where graph_name = 'training_architecture'
order by created_at desc
limit 5;
"
```

If a modality appears in `strategy_rhythm_summary` but not in `input_modalities` or `architecture_modalities`, the bug is in Fitness Strategy copy generation, not in the initial packet or two-week planner.

## Local Auth

The local Xcode scheme sets:

```text
HAYF_LOCAL_LANGGRAPH=true
HAYF_LOCAL_AUTH_EMAIL=local-langgraph@hayf.dev
HAYF_LOCAL_AUTH_PASSWORD=local-langgraph-password
```

`AuthViewModel` only uses this auto-login path in `DEBUG` builds when `HAYF_LOCAL_LANGGRAPH=true`. Production Google auth remains unchanged.

## Notes

- The local orchestrator uses real OpenAI calls.
- The simulator app never receives an OpenAI key.
- The local Supabase database is isolated from hosted Supabase.
- Physical iPhone testing can be added later by binding services to the Mac LAN IP; this runbook targets simulator only.

## Known Caveats And Next Work

- The latest observed modality issue was a Fitness Strategy copy leak: a strategy summary mentioned strength even though the selected modalities and validated Training Architecture were cycling/running only. The two-week planner stayed constrained correctly.
- Add a post-`generate_fitness_strategy` validation gate that rejects or regenerates strategy text when it mentions modalities outside `trainingArchitecture.priority_order`.
- Build a dev-only AI Run Inspector later. It should read `ai_graph_runs`, `ai_graph_node_outputs`, and `ai_tool_calls` and show an n8n-like timeline with node inputs, node outputs, model/tool calls, status, latency, and final artifacts.
- Keep workout normalization and target UI polish separate from this local LangGraph proof.
