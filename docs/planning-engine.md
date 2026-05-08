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
- upserts actual workout summaries by `(user_id, healthkit_uuid)`
- matches actuals to planned workouts by date, modality compatibility, and duration proximity
- marks matched planned workouts `done`
- inserts unmatched actual workouts as `planned_workouts.source = healthkit_detected` and `status = done`
- creates one batched `replan_proposal` if any unexpected actuals were detected

The first sync can be slower because it imports many recent workouts and writes events. Later syncs should be much lighter because HealthKit UUID upsert makes it idempotent.

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

Plan drag/drop and delete must call `PlanningAIProvider.recordPlanEdit`, not directly mutate planning rows.

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
