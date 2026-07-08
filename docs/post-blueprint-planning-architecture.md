# Post-Blueprint Planning Architecture

Status: target architecture and current handoff for the LangGraph planning refactor after Athlete Blueprint acceptance.

As of the local simulator proof on `codex/local-langgraph-proof`, the core path exists locally:

```text
iOS Simulator
  -> local Supabase API/Auth/DB/Edge Functions
    -> local training-orchestrator service
      -> OpenAI
```

The implemented proof can run onboarding, reveal a prepared Fitness Strategy, accept that strategy, and persist current-week plus next-week plans. The production hosted Supabase path remains unchanged until an orchestrator hosting target is selected.

## Why This Exists

The first planning engine shipped before the Athlete Blueprint existed. It treats one `active_fitness_blocks` row as the user's goal, strategy container, and active planning state at the same time.

That was enough to prove the loop, but it is too compressed for the product now taking shape:

- the Athlete Blueprint is no longer just an onboarding payoff; it should evolve as the athlete changes
- the user can have only one active goal at a time
- the strategy can change while the goal stays the same
- time-bound goals should have phases; consistency goals should not
- targets should exist at every level where HAYF can make them meaningful
- the product needs a visible two-week horizon without pretending that both weeks are equally committed

This document defines the target model, current implementation state, and refactor branch strategy. The older hosted production model remains the stable implementation until the LangGraph refactor proves it is better end to end.

## Refactor Branch Strategy

This is a clear fork in the road, not an incremental polish pass.

Keep `main` as the stable working app. Build the LangGraph planning architecture on a dedicated long-lived branch, for example:

```text
codex/langgraph-planning-architecture
```

All experimental planning-architecture work should merge into that branch first, not directly into `main`.

Recommended branch policy:

- `main` stays shippable and reflects the current app that works.
- `codex/langgraph-planning-architecture` is the integration branch for the new AI planning architecture.
- Smaller implementation branches may fork from that integration branch and merge back into it.
- Merge the integration branch to `main` only after the full post-onboarding flow is demonstrably better than the current implementation.

Implementation slices and current state:

1. document and schema contracts: implemented for the local proof
2. durable artifacts for `training_architectures` and graph traces: implemented
3. LangGraph service spike: implemented in `services/training-orchestrator`
4. Supabase Edge Function bridge to the orchestration service: implemented with fail-fast local env support
5. Training Architecture graph: implemented
6. Specialist Consultant subgraphs and tool hooks: implemented as model-backed bounded consultant calls for selected modalities
7. Fitness Strategy generation from Training Architecture: implemented as model-backed target generation plus strategy copy
8. two-week Plan generation from Training Architecture: implemented as model-backed planner compiler
9. real onboarding-case evaluation and rollback decision: in progress through simulator proof

## Canonical Model

```text
Athlete Profile
  -> Athlete Blueprint Revisions

Active User Goal
  -> Training Architecture
      -> Fitness Strategies
      -> optional Strategy Phases
      -> Weekly Plans
          -> Workouts

Targets can attach to:
  goal, strategy, phase, week, or session
```

Guidance flows downward:

```text
Athlete Blueprint + Goal -> Training Architecture -> Strategy -> Weekly Plan -> Workouts
```

Evaluation flows upward:

```text
Actual sessions + feedback -> Weekly Plan -> Strategy -> Goal
```

## Core Product Rules

### Athlete Blueprint

- The Athlete Blueprint is an evolving report, not a one-time static snapshot.
- The first post-onboarding blueprint is revision 1 of the same structure HAYF should use later when the athlete changes.
- Every revision keeps the user-facing sections:
  1. `coach_read`
  2. `athlete_archetype`
  3. `current_training_state`
  4. `history_findings`
  5. `goal_fit`
- Revisions are immutable so HAYF can explain how its understanding changed over time.
- `athlete_profiles.current_blueprint_revision_id` points at the currently surfaced report.
- Hidden planning inputs such as strengths, constraints, coaching priorities, and risk flags belong with the revision but are not separate frontend sections.

### User Goal

- A user can have exactly one active goal at a time.
- `consistency` is a real goal.
- Restarting onboarding creates a new active goal and supersedes the previous active goal instead of deleting history.
- Creating a new active goal immediately requires a new active strategy.

### Training Architecture

- The Training Architecture is the central AI reasoning artifact for post-onboarding planning.
- It is not frontend copy and it is not the two-week workout plan.
- It answers how HAYF should structure training for this athlete, this goal, and this modality mix before the user-facing Fitness Strategy or any workouts are generated.
- It should receive the Athlete Blueprint, normalized goal, selected modality order, constraints, access, avoidances, body-composition intent, compact planning-grade HealthKit summaries, and known injury or recovery limitations.
- It should not be a thin parameter collector for the Fitness Strategy prompt. This is where the deepest coaching reasoning belongs.
- It owns priority resolution across modalities, weekly training budget, phase logic, minimum effective dose rules, interference rules, and tradeoff handling.
- It should explicitly decide each selected modality's role: primary driver, secondary support, maintenance exposure, optional filler, or currently inappropriate.
- It should flag impossible or strongly conflicting goals instead of pretending they can all be maximized at once. For example, "become a bodybuilder and a Tour de France competitor" should produce a conflict assessment and force a prioritization or compromise.
- It should be durable and inspectable enough for later plan explanations, replans, and strategy changes to reference the same coaching rationale.

### Training Architect And Specialist Consultant Model

The Training Architecture should be generated by a LangGraph orchestrated AI flow, not by one generic prompt pretending all modalities are equivalent.

The Training Architect is the top-level graph owner. It:

- interprets the whole goal, including explicit text such as weight loss, athletic look, climbing performance, or strength appearance
- resolves priority order and tradeoffs across the selected modalities
- sets weekly training budget and recovery constraints
- decides which Specialist Consultants should be invoked
- integrates specialist consultations into one coherent structure
- produces the final conflict assessment and planning rules

Specialist Consultants are bounded worker agents or subgraphs. They reason inside the Training Architect's frame:

- a cycling coach can choose the cycling development path, for example VO2max, climbing-specific work, threshold, base, interval templates, and long-ride role
- a strength coach can choose the gym regime that complements the goal, for example hypertrophy, maximal strength, strength maintenance, movement quality, or fatigue-managed lower-body work
- a running coach can decide whether running should support aerobic volume, weight loss, durability, or simply stay as a low-dose retained modality
- future modality specialists should plug into the same contract without requiring deterministic workout templates for every new modality

Specialists should not independently create full plans in isolation. The Training Architect sets the frame first, specialists propose within that frame, and the Training Architect resolves conflicts before the Strategy or Plan sees the output.

Current implementation note: selected cycling, strength, and running specialists are real model-backed calls grounded in static knowledge packs. Unsupported modalities use a conservative generic specialist. The graph records tool calls such as `consult_cycling_specialist`, `consult_running_specialist`, `consult_strength_specialist`, and `synthesize_training_architecture`.

Specialist agents may later call their own tools, such as:

- modality-specific workout or interval libraries
- past adherence summaries for that modality
- success metrics for the selected timeline
- recent load and recovery summaries
- equipment and access lookups
- interference and fatigue rules

These tools should be exposed through bounded graph nodes with typed inputs and outputs. The specialist can have room to reason, but the durable artifact contract still belongs to HAYF, not to the framework.

The two-week planner is a Planner Compiler. It chooses dates, sessions, durations, and workout prescriptions from the validated Training Architecture, accepted Fitness Strategy, user constraints, actuals summary, and approved archetypes. It may exercise scheduling judgment, but it cannot introduce off-menu modalities or reopen goal priority, modality roles, or tradeoff decisions.

Observed local-proof behavior: the two-week planner respected the validated Training Architecture modalities. A strategy summary copy leak mentioned strength when only cycling/running were selected; the initial planning packet and final Training Architecture were correct. This should be fixed with a Fitness Strategy validation gate that rejects or regenerates copy containing modalities outside `trainingArchitecture.priority_order`.

Knowledge access is intentionally layered:

- universal training doctrine stays shared and evidence-first
- HAYF planning policy is separate from physiology
- the Training Architect gets core doctrine, HAYF policy, goal packs, and modality summary refs
- Specialist Consultants get their own full modality pack plus the shared doctrine digest
- the Planner Compiler gets approved archetypes and constraints, not the full knowledge base

For a goal like "drop 3 kg and increase cycling VO2max so I can climb better while keeping an athletic look with well defined muscles" with modalities `Cycling`, `Strength`, `Running`, the architecture should be able to conclude something like:

- cycling is the primary performance driver
- strength is a protected secondary goal because the user explicitly values visible muscularity
- running is retained as light aerobic support or optional calorie expenditure, not allowed to cannibalize cycling quality or strength recovery
- weight loss should use a modest deficit and fatigue management so power and muscle retention do not collapse
- lower-body strength and hard cycling should be spaced to avoid interference

### Fitness Strategy

- A fitness strategy is the current overall approach for achieving the active goal.
- It is downstream of the Training Architecture.
- It explains the chosen coaching structure to the user, but it should not re-decide modality priority, tradeoffs, or weekly training budget on its own.
- A goal can have many historical strategies over time, but only one active strategy at a time.
- The coach may replace a strategy mid-goal when evaluation shows that the current approach is no longer right, for example poor compliance or meaningful body-composition drift.
- Strategies should record which blueprint revision informed them.

### Strategy Phases

- Phases are product-conditioned, not user-selected.
- Consistency goals do not have phases.
- Time-bound concrete goals do have phases.
- A goal-discovery flow that resolves into a time-bound concrete goal also has phases.

### Targets

- Targets are fundamental product infrastructure, not a garnish.
- HAYF should create targets whenever a meaningful target can be defined.
- Targets may exist at goal, strategy, phase, week, or session scope.
- HAYF should omit a target only when a target would be misleading, fake, or not currently measurable.

### Two-Week Horizon

- The visible planning horizon stays two weeks.
- The commitment horizon is one week.
- Week 1 is `committed`.
- Week 2 is `draft`.
- Draft weeks are visible and editable so users can add known constraints such as trips, hikes, unavailable days, or future commitments.
- When a draft week rolls forward into the committed slot, passive planning must preserve user-authored inputs and plan around them.

## Artifact Responsibilities

### `athlete_profiles`

Durable athlete container. One row per user.

Owns:

- current blueprint pointer
- profile lifecycle metadata

### `athlete_blueprint_revisions`

Immutable athlete-report revisions.

Owns:

- visible blueprint sections
- hidden coach-side planning inputs
- approved evidence packet snapshot
- reason/source for generation

### `user_goals`

Durable active goal state.

Owns:

- normalized goal
- goal kind
- timeframe
- one-active-goal invariant
- link back to onboarding and the blueprint revision that informed the goal

### `training_architectures`

Future durable coaching-structure artifact. Until a dedicated table exists, the current implementation may store this under `fitness_strategies.context_json.trainingArchitecture` or equivalent generation trace metadata.

Owns:

- orchestrator read of the goal, athlete, and constraints
- modality roles and priority order
- Training Architect frame and specialist consultations
- approved and rejected workout archetypes
- weekly budget, recovery envelope, and minimum effective dose rules
- phase logic and progression rules
- interference rules across modalities
- conflict assessment, conflict decisions, and required tradeoffs
- source knowledge references for final roles, archetypes, and tradeoffs
- source blueprint revision and goal revision

### `ai_graph_runs`

Durable trace for a graph execution. This may live in a dedicated table or in equivalent trace infrastructure if the orchestration service provides it.

Owns:

- graph name and version
- triggering task and user
- source artifact ids
- status, started/finished timestamps, error summary
- model/provider metadata where relevant
- link to final produced artifact

### `ai_graph_node_outputs`

Durable node-level trace for debugging and evaluation.

Owns:

- graph run id
- node or subgraph name
- input summary
- structured output
- validation result
- retry/error metadata

### `ai_tool_calls`

Durable trace of tool use by graph nodes or specialist agents.

Owns:

- graph run id and node id
- tool name and version
- bounded input payload
- bounded output payload
- timing, status, and error metadata

### `fitness_strategies`

Replace the current durable meaning of `active_fitness_blocks`.

Owns:

- the current approach to the active goal
- review cadence
- rationale
- change reason and version history
- phase requirement

### `fitness_strategy_phases`

Replace the current durable meaning of `fitness_block_phases`.

Owns:

- ordered strategy segments
- phase objectives
- phase-level targets

### `weekly_plans`

Replace the current canonical meaning of `weekly_rhythms`.

Owns:

- one week of strategy implementation
- `draft` versus `committed` status
- week objective
- week-level constraints and targets

`weekly rhythm` may remain useful as product copy or a property inside a weekly plan, but it should no longer be the top-level weekly artifact.

### `planned_workouts`

Remain the session-level execution records.

Owns:

- scheduled workout facts
- workout prescriptions
- session-level targets

### `planning_targets`

Replace the role currently spread across `fitness_goal_targets`.

Owns:

- scoped targets for goal, strategy, phase, week, or session
- target metadata and evaluation rules

### `planning_target_evaluations`

Replace the role currently held by `fitness_goal_evaluations`.

Owns:

- append-only target evaluations
- upward evaluation history

### `plan_events` and `replan_proposals`

Remain sidecar audit and repair artifacts, not hierarchy nodes.

## Immediate Post-Acceptance Flow

The future replacement for `bootstrap_after_onboarding` should be something like `create_initial_strategy_after_blueprint`.

The iOS app should not know whether LangGraph is involved. It should call one authenticated backend task and receive product artifacts or a retryable failure.

After the user accepts the first Athlete Blueprint:

1. Persist or mark accepted the current blueprint revision.
2. Persist the single active user goal.
3. Build a compact planning packet from:
   - current blueprint revision
   - hidden planning inputs
   - normalized goal
   - bounded planning-grade evidence summaries
   - user constraints and preferences
4. Generate the Training Architecture:
   - Training Architect frame
   - selected modality roles
   - Specialist Consultant recommendations
   - approved and rejected workout archetypes
   - weekly budget and recovery envelope
   - phase and progression rules
   - conflict assessment
5. Generate the initial Fitness Strategy from the Training Architecture.
6. Generate required strategy phases when the goal requires them.
7. Generate targets wherever meaningful:
   - goal
   - strategy
   - phase
   - week
   - session
8. Show the user-facing Fitness Strategy reveal defined in `docs/fitness-strategy-spec.md`.
9. After the user accepts the strategy, generate an AI-authored two-week plan from the Training Architecture:
   - current week as `committed`
   - next week as `draft`
10. Generate workouts for those visible weeks.
11. Persist events and AI generation traces.

## Compact Planning Packet

Planning should not receive the giant raw `healthSnapshot` object.

The future packet should contain only bounded structured summaries:

```text
athlete_context
- blueprint_revision_id
- coach_read summary
- athlete archetype
- current training state
- approved history findings
- goal fit
- hidden strengths / constraints / coaching priorities / risk flags

goal_context
- normalized goal
- goal kind
- timeframe
- success definition
- selected modality order
- explicit body-composition or appearance intent

planning_constraints
- feasible modalities
- frequency
- session length
- injuries / limitations
- equipment / access
- bad-day floor
- timezone / start date

approved_evidence_summary
- recent training load
- consistency
- modality mix
- only planning-grade body / recovery context
- confidence and caveats

generation_policy
- visible horizon
- committed horizon
- allowed claims
- AI-first plan generation requirements
```

## LangGraph Runtime Shape

Use LangGraph for the Training Architecture layer from the beginning of this refactor.

The graph should be split into durable product-artifact boundaries rather than one giant run:

```text
Onboarding Intake output
  -> Athlete Blueprint
  -> Training Architecture Graph
      -> Validate Packet
      -> Load Knowledge Manifest
      -> Training Architect Frame
      -> Specialist Consultant Subgraphs
      -> Training Architect Synthesis
      -> Conflict / Feasibility Assessment
      -> Deterministic Validation
  -> Fitness Strategy
  -> Two-Week Plan Graph
  -> Persistence
```

This is similar to an n8n workflow in shape, but with a stricter product boundary: each major stage produces a durable artifact that can be inspected, versioned, retried, and consumed by later stages.

Do not model the whole app as one endless agent run. Use separate graph runs connected by durable artifacts:

```text
Onboarding output = durable intake artifact
Blueprint output = durable athlete read
Training Architecture output = durable coaching structure
Strategy output = durable user-facing explanation
Plan output = durable scheduled execution
```

### Agent Boundaries

Onboarding can become an intake graph later, but it should not be the planning brain.

- Onboarding Intake Agent: asks and normalizes.
- Blueprint Agent: reads the athlete from approved evidence.
- Training Architecture Graph: decides the coaching structure.
- Strategy Agent: explains the chosen structure to the user.
- Plan Graph: schedules concrete sessions.

These agents may share durable artifacts and evidence summaries, but they should not collapse into one unbounded planner.

## Developer Observability

The implementation already persists the raw ingredients for an n8n-like inspector:

- `ai_graph_runs`: one row per graph execution with input packet, final output artifact, provider/model metadata, status, and source artifact ids
- `ai_graph_node_outputs`: ordered node outputs with validation status and structured output
- `ai_tool_calls`: model/tool calls, bounded inputs/outputs, status, latency, and errors

The missing piece is a dev UI. Recommended next step is a local web dashboard, not an iOS screen:

```text
Run list
  -> run timeline
      -> graph node
      -> model/tool call
      -> validation result
      -> persisted artifact
```

The first version should highlight modality consistency:

- selected modalities from `ai_graph_runs.input_json.goal_context.selected_modality_order`
- final architecture modalities from `output_json.trainingArchitecture.priority_order`
- modalities mentioned in Fitness Strategy user-facing text
- modalities scheduled in `planned_workouts`

Warnings should call out cases such as "strategy copy mentions strength, but the architecture only allows cycling and running."

### Deployment Boundary

Do not run the full long-running LangGraph planning system inside Supabase Edge Functions.

Use Supabase Edge Functions for:

- authentication and authorization
- request validation
- user ownership checks
- lightweight orchestration entrypoints
- writing and reading canonical Supabase artifacts

Use a dedicated AI orchestration service for:

- LangGraph execution
- long-running graph state
- checkpointing / persistence
- specialist agent tool calls
- graph-level traces
- retries and resumability
- optional streaming or human-in-the-loop later

Recommended shape:

```text
iOS app
  -> Supabase Edge Function
      -> auth, validation, ownership checks
      -> start or call LangGraph orchestration service
          -> Training Architecture graph
          -> specialist agents and tools
          -> graph traces / checkpoints
      -> write canonical artifacts back to Supabase
```

Reasoning:

- Supabase Edge Functions are best kept short-lived and idempotent.
- LangGraph is designed for stateful, long-running, tool-using graph workflows.
- Supabase should remain the product backend and database.
- LangGraph should be the AI orchestration runtime, not the source of truth for product state.

### Framework Guardrails

LangGraph is the orchestration runtime, not the product model.

- Product artifacts remain `Athlete Blueprint`, `User Goal`, `Training Architecture`, `Fitness Strategy`, `Weekly Plan`, and `Workout`.
- Specialist Consultants can be tool-using agents, but only inside bounded subgraphs with typed outputs.
- Deterministic validation and persistence stay outside the agents.
- Graph traces are for debugging, auditability, and evaluation; the app renders canonical product artifacts.
- If a graph fails, the product should surface a retryable failure rather than silently replacing the result with deterministic workout templates.

## Deterministic Versus AI-Authored

Deterministic:

- evidence extraction
- blueprint packet assembly
- normalized goal
- default 12-week timeframe when needed
- phase requirement
- planning packet assembly
- target math and evaluation
- persistence, validation, and status transitions

AI-authored:

- Training Architecture and Specialist Consultant reasoning
- strategy rationale
- phase descriptions
- weekly emphasis
- workout prescriptions
- polished coach-facing language

The AI may propose structured artifacts. Deterministic code owns validation and storage, but it should not silently replace failed AI planning with generic workout templates. If AI generation fails, the product should surface a retryable failure rather than pretending a fallback plan is the real HAYF plan.

## Transitional Mapping From The Current Engine

| Current implementation | Target architecture |
| --- | --- |
| `active_fitness_blocks` | `fitness_strategies` |
| `fitness_block_phases` | `fitness_strategy_phases` |
| `weekly_rhythms` | `weekly_plans` |
| `fitness_goal_targets` | `planning_targets` |
| `fitness_goal_evaluations` | `planning_target_evaluations` |
| `planned_workouts` | keep |
| `plan_events` | keep |
| `replan_proposals` | keep |

During the migration period, both models may coexist. New code should be deliberate about whether it is reading the current engine or the target architecture.
