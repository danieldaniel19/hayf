# HAYF Training Orchestrator

This service is the LangGraph runtime for post-blueprint planning. Supabase remains the product backend and source of truth; this package owns long-running graph execution and typed planner artifacts.

## Graphs

- `training_architecture`: hidden coaching-structure artifact for an athlete, goal, and modality mix.
- `fitness_strategy`: user-facing strategy reveal derived from a validated Training Architecture.
- `two_week_plan`: committed week plus draft week plan generation.

## Local Development

```bash
npm install
npm run check
npm test
npm audit
npm run dev
```

`langgraph.json` exposes three graph entries:

- `training_architecture`: `src/graphs/training-architecture.ts:trainingArchitectureGraph`
- `fitness_strategy`: `src/graphs/fitness-strategy.ts:fitnessStrategyGraph`
- `two_week_plan`: `src/graphs/two-week-plan.ts:twoWeekPlanGraph`

The Supabase Edge Function calls this service through `TRAINING_ORCHESTRATOR_URL` when configured, or uses the local deterministic bridge while the service is being rolled out. Keep Supabase as the persistence boundary: graph responses should return artifacts and trace nodes, while the Edge Function persists canonical rows and validates ownership.

## Contracts

The graph input is a bounded planning packet. Do not send raw HealthKit samples, workout ledgers, or device-origin records to this service. Tests in `test/graphs.test.ts` cover this packet rule plus representative planning fixtures.
