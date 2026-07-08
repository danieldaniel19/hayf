# HAYF Training Orchestrator

This service is the LangGraph runtime for post-blueprint planning. Supabase remains the product backend and source of truth; this package owns long-running graph execution and typed planner artifacts.

Current proof status: the local simulator path has successfully exercised onboarding -> strategy reveal -> accept strategy -> two-week plan through this service and local Supabase.

## Graphs

- `training_architecture`: hidden coaching-structure artifact for an athlete, goal, and modality mix.
- `fitness_strategy`: user-facing strategy reveal derived from a validated Training Architecture.
- `two_week_plan`: committed week plus draft week plan generation.

## Training Architecture Model

The `training_architecture` graph uses a Training Architect plus bounded Specialist Consultants:

- `validate_packet`: reject incomplete packets and raw HealthKit records.
- `load_knowledge_manifest`: load static repo knowledge packs for doctrine, HAYF policy, goals, and modalities.
- `architect_frame`: interpret the case, choose priority hypotheses, budget range, recovery risks, and consultant briefs.
- `specialist_consultations`: run selected modality consultants in parallel. V1 has dedicated cycling, strength, and running packs, plus a conservative generic fallback for other modalities.
- `architect_synthesis`: filter consultant recommendations, decide final roles/tradeoffs, and approve workout archetypes for planning.
- `deterministic_validation`: enforce source refs, selected-modality roles, no dated specialist workouts, and planner-safe archetypes.

The Training Architect owns coherence. Specialists recommend modality roles, dose ranges, fatigue risks, and workout archetypes, but they do not create calendars. The planner compiler receives only the validated architecture, approved archetypes, strategy, constraints, actuals summary, and draft inputs.

Expected model/tool call trace for a cycling/running case:

```text
consult_cycling_specialist
consult_running_specialist
synthesize_training_architecture
author_training_architecture_reasoning
generate_fitness_strategy_targets
generate_fitness_strategy
```

For a cycling/strength/running case, expect `consult_strength_specialist` as well.

## Knowledge Packs

Static knowledge packs live under `src/knowledge/packs`:

- `core/training-doctrine.md`: shared physiology and planning doctrine.
- `policy/hayf-planning-policy.md`: product constraints and evidence boundaries.
- `goals/*.md`: goal lenses such as consistency, body composition, and performance.
- `modalities/*.md`: modality-specific consultant packs for cycling, strength, running, and generic fallback.

The Architect receives shared doctrine, HAYF policy, goal packs, and modality summary refs. Specialists receive the shared doctrine digest plus their own full modality pack. The planner does not receive the full knowledge base; it receives approved archetypes and constraints.

## Local Development

```bash
npm install
npm run check
npm test
npm run serve
npm audit
npm run dev
```

`langgraph.json` exposes three graph entries:

- `training_architecture`: `src/graphs/training-architecture.ts:trainingArchitectureGraph`
- `fitness_strategy`: `src/graphs/fitness-strategy.ts:fitnessStrategyGraph`
- `two_week_plan`: `src/graphs/two-week-plan.ts:twoWeekPlanGraph`

The Supabase Edge Function calls this service through `TRAINING_ORCHESTRATOR_URL` when configured, or uses the local deterministic bridge while the service is being rolled out. Keep Supabase as the persistence boundary: graph responses should return artifacts and trace nodes, while the Edge Function persists canonical rows and validates ownership.

## HTTP Adapter

`src/server.ts` exposes the Edge-facing HTTP contract:

- `GET /health`
- `POST /planning/prepare-initial-strategy` with `{ "planningPacket": ... }`
- `POST /planning/two-week-plan` with `{ "context": ... }`

Run locally:

```bash
PORT=8787 npm run serve
```

Build and run compiled output:

```bash
npm run build
PORT=8787 npm start
```

If `TRAINING_ORCHESTRATOR_API_KEY` is set on the service, callers must send `Authorization: Bearer <key>`. The Supabase Edge Function already forwards `TRAINING_ORCHESTRATOR_API_KEY` when configured. To route simulator onboarding through this service, deploy it to a URL reachable by Supabase Edge and set these Supabase secrets:

```text
TRAINING_ORCHESTRATOR_URL=https://your-orchestrator-host
TRAINING_ORCHESTRATOR_API_KEY=optional-shared-secret
```

## Contracts

The graph input is a bounded planning packet. Do not send raw HealthKit samples, workout ledgers, or device-origin records to this service. Tests in `test/graphs.test.ts` cover this packet rule plus representative planning fixtures.

## Known Follow-Ups

- Add a Fitness Strategy validation gate that fails or regenerates copy if it mentions modalities not present in the validated Training Architecture.
- Build a local AI Run Inspector over Supabase trace tables for n8n-like debugging.
- Keep permanent orchestrator hosting separate from the local simulator proof. Fly-related files are scaffolding only and are not required for local proof.
