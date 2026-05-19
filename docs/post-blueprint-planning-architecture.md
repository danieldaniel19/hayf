# Post-Blueprint Planning Architecture

Status: target architecture for the refactor that begins after Athlete Blueprint acceptance.

## Why This Exists

The first planning engine shipped before the Athlete Blueprint existed. It treats one `active_fitness_blocks` row as the user's goal, strategy container, and active planning state at the same time.

That was enough to prove the loop, but it is too compressed for the product now taking shape:

- the Athlete Blueprint is no longer just an onboarding payoff; it should evolve as the athlete changes
- the user can have only one active goal at a time
- the strategy can change while the goal stays the same
- time-bound goals should have phases; consistency goals should not
- targets should exist at every level where HAYF can make them meaningful
- the product needs a visible two-week horizon without pretending that both weeks are equally committed

This document defines the target model. The older model remains the current implementation until the runtime refactor reaches it.

## Canonical Model

```text
Athlete Profile
  -> Athlete Blueprint Revisions

Active User Goal
  -> Fitness Strategies
      -> optional Strategy Phases
      -> Weekly Plans
          -> Workouts

Targets can attach to:
  goal, strategy, phase, week, or session
```

Guidance flows downward:

```text
Athlete Blueprint + Goal -> Strategy -> Weekly Plan -> Workouts
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

### Fitness Strategy

- A fitness strategy is the current overall approach for achieving the active goal.
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

After the user accepts the first Athlete Blueprint:

1. Persist or mark accepted the current blueprint revision.
2. Persist the single active user goal.
3. Build a compact planning packet from:
   - current blueprint revision
   - hidden planning inputs
   - normalized goal
   - bounded planning-grade evidence summaries
   - user constraints and preferences
4. Generate the initial fitness strategy.
5. Generate required strategy phases when the goal requires them.
6. Generate targets wherever meaningful:
   - goal
   - strategy
   - phase
   - week
   - session
7. Show the user-facing Fitness Strategy reveal defined in `docs/fitness-strategy-spec.md`.
8. After the user accepts the strategy, generate:
   - current week as `committed`
   - next week as `draft`
9. Generate workouts for those visible weeks.
10. Persist events and AI generation traces.

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
- deterministic requirements
```

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

- strategy rationale
- phase descriptions
- weekly emphasis
- workout prescriptions
- polished coach-facing language

The AI may propose structured artifacts. Deterministic code owns validation and storage.

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
