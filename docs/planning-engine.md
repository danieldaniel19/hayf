# HAYF Planning Engine

Implemented: 2026-05-08

## Purpose

The planning engine turns completed onboarding into the app's durable fitness planning source of truth:

1. one active fitness block
2. one or more weekly rhythms inside that block
3. planned workouts that Home and Plan can render
4. HealthKit-derived actual workouts that can reconcile against the plan
5. append-only events and user-approved repair proposals

This is the foundation for the Home workout card, the Plan screen, check-in flow, workout-detail screens, and later calendar/coach integrations.

For product/navigation ownership and current terminology, see `docs/information-architecture.md`. In short: `active_fitness_blocks` is the canonical active block concept; Plan is the execution home; Profile is the durable user and fitness context home.

## Product Rules Captured

- HAYF is not locked to a three-month plan.
- Consistency onboarding creates a rolling `consistency` block with a 28-day review cadence and no fake phases.
- Concrete-goal onboarding creates a `specific_goal` block with a required timeline.
- Goal-discovery onboarding creates a `goal_discovery_chosen` block.
- The first concrete plan window is current week plus next week.
- Raw HealthKit samples stay on device. Supabase receives compact derived snapshots and actual workout summaries.
- Direct user edits and HealthKit-detected workouts apply immediately.
- Extra HAYF repair changes are proposed for user approval, not auto-applied.
- Unexpected actual workouts are batched into one replan proposal per sync, while individual detected-workout events are still logged.

## Supabase Data Model

Migration: `supabase/migrations/20260508162000_planning_engine.sql`

Core tables:

- `active_fitness_blocks`: one active block per user.
- `fitness_block_phases`: optional phases for goal blocks.
- `weekly_rhythms`: operating plan for a week.
- `planned_workouts`: source for Home and Plan UI.
- `health_feature_snapshots`: compact derived HealthKit feature snapshots.
- `actual_workouts`: recent HealthKit-derived workout summaries.
- `fitness_metric_observations`: source-agnostic derived facts from HealthKit now, manual logs / feedback later.
- `fitness_history_insights`: coach-readable history patterns for goal suggestion and the future Fitness Profile.
- `fitness_goal_targets`: primary active-block goals and supporting sub-goals.
- `fitness_goal_evaluations`: append-only goal status evaluations.
- `workout_debrief_requests`: feedback prompts created after completed workouts are detected.
- `workout_feedback`: future post-workout feedback records.
- `plan_events`: append-only audit trail.
- `replan_proposals`: user-approved repair layer.
- `planning_ai_generations`: planning AI traces and failures.

RLS:

- Authenticated users can read their own planning rows.
- Edge functions write with the service role.

Scheduled refresh:

- The migration creates an hourly `pg_cron` job that calls `planning-ai.scheduled_refresh_due_windows`.
- The helper is safe to run without secrets configured; it no-ops until `app.supabase_project_url` and `app.supabase_service_role_key` are set in Postgres settings.
- First-product QA does not depend on cron because the app also performs catch-up refresh.

## Edge Function

Function: `supabase/functions/planning-ai/index.ts`

Public tasks:

- `bootstrap_after_onboarding`
- `sync_healthkit_and_reconcile`
- `refresh_plan_window`
- `record_plan_edit`
- `recommend_workout_replacements`
- `replace_workout`
- `recommend_workout_additions`
- `interpret_workout_description`
- `add_workout`
- `apply_replan_proposal`
- `check_in_to_workout`
- `scheduled_refresh_due_windows`

The function is authenticated for app tasks. The scheduled task requires service-role authorization.

### Bootstrap

`bootstrap_after_onboarding`:

- loads `profiles` and `onboarding_profiles`
- generates an active block from onboarding intent
- generates current week plus next week
- creates full workout prescriptions and one-line fueling summaries
- writes block, phases, weekly rhythms, planned workouts, event log, and AI trace
- falls back deterministically if OpenAI fails

Important QA fix:

- The onboarding row must be fetched as a single object, not an array. Otherwise fallback cannot read `onboarding.intent` and may default incorrectly.

### HealthKit Sync

`sync_healthkit_and_reconcile`:

- stores the latest derived feature snapshot
- stores reusable fitness history observations and insight candidates from the snapshot
- upserts actual workout summaries by `(user_id, healthkit_uuid)`
- matches actuals to planned workouts by date, modality compatibility, and duration proximity
- marks matched planned workouts `done`
- inserts unmatched actual workouts as `planned_workouts.source = healthkit_detected` and `status = done`
- creates `workout_debrief_requests` for matched or detected actual workouts so Today / Workout Detail can ask for feedback later
- creates initial active-block goal targets when needed and evaluates goal status after sync
- creates one batched `replan_proposal` if any unexpected actuals were detected

The first sync can be slower because it imports many recent workouts and writes events. Later syncs should be much lighter because HealthKit UUID upsert makes it idempotent.

### Workout Adaptation

Workout replacement and addition are first-class planning-engine tasks because they can change weekly load, session spacing, and active-block coverage.

Suggestion tasks:

- `recommend_workout_replacements` takes a planned workout ID and returns second-best candidates for that exact slot.
- `recommend_workout_additions` takes a scheduled date and returns candidates that fit the selected day and surrounding week.
- `interpret_workout_description` takes natural-language text and returns one structured candidate. It can be scoped to either an existing workout slot or a scheduled date.

Mutation tasks:

- `replace_workout` supersedes the original workout, inserts the accepted candidate as the new fact, emits `plan_events.event_type = workout_replaced`, and may return a repair proposal.
- `add_workout` inserts the accepted candidate at the selected date/order, writes `planned_workouts.source = user_added`, emits `plan_events.event_type = workout_added`, and may return a repair proposal.

The planning engine should never treat a user-accepted replacement or addition as the thing to undo. If recovery or balance needs repair, proposals should adapt surrounding sessions around the user's chosen workout.

### Fitness History And Goal Evidence

The app now builds a broader `fitnessHistory` profile inside `HealthFeatureSnapshot`.
This is not intended to become an analytics dashboard. It is a reusable evidence layer for:

- onboarding Flow C goal suggestions
- active-block goal and sub-goal tracking
- later Fitness Profile UI under Profile
- future coach chat answers about training history

Current history categories:

- training identity and modality mix
- consistency, active weeks, streaks, and gaps
- monthly/seasonal activity
- rolling volume/load windows
- generic distance-effort performance proxies
- strength continuity
- recovery and body trend context
- activity floor

HealthKit is the first source, but the database model is source-agnostic. Manual gym logs, HAYF workout debriefs, and future external sources should feed the same observation / insight / evaluation pipeline instead of creating parallel systems.

Product decisions:

- The AI should receive labelled evidence and compact insight summaries, not raw HealthKit samples.
- Calculations should stay broad and reusable. Running and cycling can have extra helpers, but the foundation should not need a rebuild for every new goal idea.
- Active blocks can have a primary goal and supporting sub-goals.
- Goal status language should be simple: on track, lagging, achieved, or needs review.
- When imported data proves a goal was achieved early, HAYF should create a review moment instead of silently continuing.
- Profile > Fitness Profile is the user-facing home for long-term highlights. Plan and Today should consume the same evidence but stay focused on action.
- Onboarding Flow C should run HealthKit consent and feature extraction before suggesting goals.

First Profile mock:

- `design/mocks/Profile/profile-fitness-profile-entry-and-sheet.png`
- Shows a Profile tab entry point plus a pull-up Fitness Profile detail card, matching the active block sheet pattern from Plan.

### Window Refresh

`refresh_plan_window`:

- ensures the visible two-week window exists
- uses the latest snapshots, events, and proposals as context
- avoids overwriting user-moved/user-deleted/done rows
- skips user-triggered refresh if the two-week window already exists
- records health-data freshness in `plan_events.payload_json`

### Edits And Proposals

`record_plan_edit`:

- move applies immediately and logs `workout_moved`
- delete marks the workout `deleted`, does not hard-delete, and logs `workout_deleted`
- cross-week moves and deletes can create pending repair proposals

`apply_replan_proposal`:

- `accepted` applies proposed mutations and logs `proposal_accepted`
- `rejected` leaves the direct edit/actual workout in place and logs `proposal_rejected`

### Check-In

`check_in_to_workout`:

- with no adjustment signal, marks the workout `checked_in`
- with a low-energy/text distress signal, creates an adjustment proposal for the current workout
- later-workout repairs remain proposals

## iOS Integration

Files:

- `HAYFHealthKitPrototype/Planning/PlanningAIProvider.swift`
- `HAYFHealthKitPrototype/Health/HealthSyncService.swift`
- `HAYFHealthKitPrototype/Health/HealthKitManager.swift`
- `HAYFHealthKitPrototype/Onboarding/OnboardingFlowView.swift`
- `HAYFHealthKitPrototype/Auth/AuthenticatedHomeView.swift`
- `HAYFHealthKitPrototype/Health/HealthDebugView.swift`

`PlanningAIProvider` mirrors the onboarding provider and calls the `planning-ai` tasks.

`HealthSyncService` builds the sync payload:

- `HealthFeatureSnapshot`
- recent `HealthActualWorkoutSummary` rows
- sync window dates

`OnboardingFlowView` now:

1. builds a HealthKit feature snapshot if connected
2. upserts `onboarding_profiles`
3. calls `bootstrap_after_onboarding`
4. only publishes onboarding completion after bootstrap returns

This avoids a race where authenticated Home appears and tries sync/refresh before an active block exists.

`AuthenticatedHomeView` currently performs a quiet app-open sync/refresh:

1. build HealthKit sync payload
2. call `sync_healthkit_and_reconcile`
3. call `refresh_plan_window`

When real Home/Plan screens exist, this should move into an app/session service rather than living directly in the tester home.

`HealthDebugView` has a QA button:

- `Sync Planning From HealthKit`

This directly tests the HealthKit-to-planning sync path without rerunning onboarding.

## UI Contracts

Home should read from `planned_workouts`:

- default to the next actionable workout: `current`, or the earliest future `planned/checked_in/adjusted`
- show `title`, `duration_minutes`, `intensity_label`, `purpose`, `fueling_summary`, and compact vitals
- tapping the workout card should enter the check-in/workout-detail flow

Plan should read:

- `active_fitness_blocks` for the current block context
- `weekly_rhythms` for weekly objectives
- `planned_workouts` for current week plus next week
- optional `fitness_block_phases` for goal-block roadmap display
- `plan_events` and `replan_proposals` for repair/proposal states

Plan edit actions must go through the planning engine, not directly mutate planning rows. Move and delete call `PlanningAIProvider.recordPlanEdit`; replacement calls the audited replacement endpoint and returns the same coach-review outcome shape.
Workout additions also go through the planning engine. The app first asks for suggested additions or asks the engine to interpret a natural-language workout description, then `add_workout` inserts the user-approved candidate with `planned_workouts.source = user_added` and emits `plan_events.event_type = workout_added`.

Audited Plan edit UX:

- Planned workout cards expose explicit swipe actions for replace, move, and delete.
- Today/future day rows expose a day-level add-workout action; open days show it as the row body, and occupied days show it below the day's cards.
- Plan does not use drag/drop for workout movement. Move enters a target-selection state, and whole day rows become tappable destinations.
- Submitted edits show a blocking coach-analysis overlay while HAYF audits the resulting week.
- The visible plan changes only after the backend returns and Plan reloads.
- If the edit is low risk, the user edit stands with no extra prompt.
- If the edit creates meaningful risk, the existing coach-review sheet opens with one consolidated replan proposal.
- Replacement keeps the user's chosen replacement as the new fact; any repair proposal must adapt around it, not revert it.
- Addition keeps the user's added workout as the new fact; any repair proposal must adapt surrounding sessions instead of removing the addition.
- Replacement and addition share one pull-up sheet. While suggestions load, the frontend rotates static prompt-derived coach copy explaining that HAYF is checking role, load, recovery spacing, active-block targets, and weekly impact. Manual natural-language entry is always available and previews the interpreted workout.
- Choosing either an AI suggestion or a manual preview opens a review step before mutation. The user can accept, cancel back to the choice sheet, or see the disabled Follow up with coach action reserved for future conversational planning.
- Replan proposals use the same decision language: accept the adjustment, cancel it, or see the disabled Follow up with coach action.

Check-in should call `PlanningAIProvider.checkInToWorkout`.

Proposal UI should call `PlanningAIProvider.applyReplanProposal`.

## QA Queries

Recent block:

```sql
select kind, title, status, start_date, target_date, review_cadence_days, timezone
from active_fitness_blocks
order by created_at desc
limit 5;
```

Expected for consistency:

- `kind = consistency`
- `target_date is null`
- `review_cadence_days = 28`

Visible workouts:

```sql
select scheduled_date, sequence_order, activity_type, title, duration_minutes, intensity_label, status, source, fueling_summary
from planned_workouts
where status != 'superseded'
order by scheduled_date, sequence_order;
```

AI traces:

```sql
select task, model, status, error_message, created_at
from planning_ai_generations
order by created_at desc
limit 20;
```

Events:

```sql
select event_type, payload_json, created_at
from plan_events
order by created_at desc
limit 40;
```

Actual workouts:

```sql
select healthkit_uuid, start_date, activity_type, duration_minutes, matched_planned_workout_id, match_confidence
from actual_workouts
order by start_date desc
limit 20;
```

## Deployment

Deploy function after backend changes:

```bash
supabase functions deploy planning-ai
```

Push migrations when schema changes:

```bash
supabase db push
```

Required function secret:

```bash
supabase secrets set OPENAI_API_KEY=...
```

Optional:

```bash
supabase secrets set OPENAI_MODEL=gpt-5-mini
```

## Known Follow-Ups

- Move app-open planning sync out of tester Home into a dedicated app/session coordinator.
- Build typed read models or Supabase views for Home and Plan.
- Add proper UI for pending replan proposals.
- Add tests around matching actual workouts to planned workouts.
- Decide how far back initial HealthKit actual sync should go for production.
- Add deployment notes for configuring `app.supabase_project_url` and `app.supabase_service_role_key` for cron.
- Build Profile > Fitness Profile UI using `historyInsights`, `goalTargets`, `goalEvaluations`, and `debriefRequests`.
- Build workout feedback capture from pending `workout_debrief_requests`.
- Move onboarding Flow C HealthKit consent before AI goal candidate generation.
