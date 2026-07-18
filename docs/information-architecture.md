# HAYF Information Architecture

Last updated: 2026-05-18

This document is the working source of truth for where fitness planning, goals, profile context, and account controls live in the app. Its main job is to prevent naming drift and duplicated surfaces as the product grows.

The current implementation still uses the first planning-engine model. The target post-blueprint model is defined in `docs/post-blueprint-planning-architecture.md`; use that document when designing the next refactor slice.

## Canonical Terms

- **Athlete Blueprint** is the user-facing evolving report of the athlete. The first post-onboarding blueprint is revision 1, not a static forever snapshot.
- **Current goal** is the single active user goal. Restarting onboarding supersedes the prior active goal and creates a new one.
- **Fitness strategy** is the current overall approach for achieving the active goal. A goal may have several historical strategies, but only one active strategy at a time.
- **Training targets** are HAYF-derived targets at the goal, strategy, phase, week, or session level.
- **This week's focus** is the week-level objective from the current `weekly_plan`. It belongs in Plan, not Profile.
- **What HAYF knows** is the user-facing summary of durable fitness evidence, powered by `fitness_history_insights`, `fitness_metric_observations`, and related evaluations.

## Screen Responsibilities

### Plan

Plan is the execution home.

It should answer: What am I doing now, what is HAYF optimizing for through the active strategy, and what is scheduled across the visible planning window?

Plan owns:

- active strategy status, phase, and progress
- training targets for the visible strategy/week/session context
- this week's focus / objective
- current week plus next week workout schedule
- direct workout planning actions, such as moving, deleting, replacing, or adding planned workouts
- repair proposals and plan refresh states

The post-onboarding Fitness Strategy reveal is not the Plan screen. Strategy explains the approach; Plan owns execution.

The Plan screen may scroll. The first glance should prioritize the active strategy, training targets, and current week context. The visible horizon remains two weeks: the current week is committed, the next week is draft. Both weeks should render all seven days, even when a day has no workout, so users can choose explicit move targets for planned workouts and enter known future constraints.

Today and future day rows may also add workouts. Open days should expose an add-workout entry point directly in the row, and occupied days should expose the same day-level add entry below that day's workout cards. Add and replace should share one coach sheet: HAYF can suggest plan-aware options, or the user can describe a workout in natural language and preview the interpreted workout before confirming. Any selected workout change opens a review step with Accept, Cancel, and a disabled Follow up with coach action before the plan is mutated.

Coach-generated planning proposals should consistently be framed as reviewable changes, not hidden mutations. The user should always understand the current workout/week, the proposed result, and the resulting week before accepting. Cancel returns to the prior decision point for direct workout changes; canceling a repair proposal keeps the user's accepted workout change and rejects only the repair.

Planned workouts in the past should be reconciled after HealthKit sync. If the latest sync window happened after the workout date and there is no matching actual workout evidence, the planned workout should become `missed`. When missed workouts materially change the visible plan, HAYF should refresh the rest of the two-week window instead of leaving stale recommendations in place.

Primary implementation references:

- `HAYFHealthKitPrototype/Planning/PlanScreenView.swift`
- `HAYFHealthKitPrototype/Planning/PlanDataStore.swift`
- `supabase/functions/planning-ai/index.ts`
- `docs/planning-engine.md`

### Profile

Profile is the user identity and durable fitness context home.

It should answer: Who am I in HAYF, what goal/context is HAYF carrying for me, and what does HAYF know about my evolving athlete profile?

Profile owns:

- name and basic account identity
- location, when available or user-provided
- one quiet settings entry point
- first-level sign out
- a fitness profile card for "What HAYF knows" / current Athlete Blueprint
- a calm place to revisit the durable goal/current focus after onboarding
- likely later access to the current Fitness Strategy, though the final entry point is not decided yet

Profile should not become a week-planning dashboard. It can reference the current goal and current Athlete Blueprint because users need a post-onboarding home for durable athlete context, but weekly execution and short-horizon targets still belong in Plan.

Profile should not include:

- a second settings entry in the top-right
- global workout feedback
- health data management as a top-level Profile item
- week focus cards or active block execution details that duplicate Plan

Primary implementation references:

- `HAYFHealthKitPrototype/Profile/ProfileScreenView.swift`
- `HAYFHealthKitPrototype/Profile/ProfileDataStore.swift`
- `Forte-designs/DESIGN.md` for the active Forte visual redesign
- `HAYF-designs/mocks/Profile/README.md` for the legacy HAYF Profile mock only

### Settings

Settings is the future home for account and app management.

Settings should own:

- account details and preferences
- health data connections and permissions education
- privacy and data controls
- notification and integration settings

Profile should link to Settings once. Health data should live inside Settings, not as a standalone Profile entry.

### Coach Chat

Coach chat is a future global affordance.

The top-right action across primary screens should be reserved for opening coach chat. It should not be used for settings. The future coach should pick up screen and user context, answer questions, and eventually propose bounded adjustments to plans or goals.

Until the chat exists, the affordance can be disabled or marked as coming later, but the slot should remain conceptually reserved.

### Workout Feedback

Workout feedback is a post-workout flow, not a global navigation item.

Feedback should be requested after completed workouts through workout detail / debrief flows. It should feed the shared evidence layer and future coaching logic without requiring users to hunt for a manual feedback area in Profile.

## Goal And Target Model

Onboarding can create a concrete goal such as losing 2 kg, reducing body fat from 15% to 12%, building consistency, preparing for an event, or discovering a better fitness direction.

The target post-blueprint model is:

1. **Athlete Blueprint** keeps the evolving athlete read that guides all downstream planning.
2. **User goal** carries the one active goal HAYF is serving.
3. **Training Architecture** is the hidden AI coaching-structure layer that resolves modality priorities, specialist coach recommendations, weekly budget, interference, and tradeoffs.
4. **Fitness strategy** carries the user-facing overall approach for that goal and may change while the goal remains active.
5. **Strategy phases** exist for time-bound concrete goals and are absent for consistency goals.
6. **Weekly plans** translate the active strategy into one week of execution, with the current week committed and the next week draft.
7. **Workouts** turn the weekly plan into concrete sessions.
8. **Targets** attach wherever meaningful: goal, strategy, phase, week, or session.
9. **Actual workouts and feedback** evaluate upward into the week, strategy, and goal.

This means goals appear in two places for different reasons:

- Profile lets the user revisit the durable goal and current athlete read.
- Plan shows how the active strategy is being operationalized right now.

Do not create parallel goal surfaces that let users edit the same concept in unrelated places. A goal review or adjustment can start from Profile or Plan, but the actual change should resolve through a single review flow, later likely with coach assistance.

## Data Sources

The current planning/profile evidence layer is source-agnostic.

Target core tables:

- `athlete_profiles`: one durable athlete container per user
- `athlete_blueprint_revisions`: immutable evolving athlete-report revisions
- `user_goals`: one active user goal per user
- `fitness_strategies`: one active strategy for the active goal, with historical strategies preserved
- `fitness_strategy_phases`: required for time-bound strategies and absent for consistency strategies
- `weekly_plans`: week-level implementation with `draft` and `committed` states
- `planned_workouts`: concrete scheduled workouts
- `health_feature_snapshots`: compact HealthKit-derived snapshots
- `actual_workouts`: imported HealthKit workout summaries
- `fitness_history_insights`: coach-readable "What HAYF knows" insights
- `fitness_metric_observations`: labelled metric evidence
- `planning_targets`: scoped targets for goal, strategy, phase, week, and session
- `planning_target_evaluations`: append-only target evaluations
- `workout_debrief_requests`: prompts for post-workout feedback
- `workout_feedback`: user feedback after workouts
- `plan_events`: audit trail for user and engine planning changes
- `replan_proposals`: reviewable repair proposals after meaningful planning changes
- `planning_ai_generations`: compact AI request/response traces and failures

HealthKit remains the source of truth for Apple health data. HAYF stores compact derived features and evidence, not raw HealthKit sample history. Workout history and body history follow the same rule: the raw archive stays on-device, while durable planning memory is represented through snapshots, labelled metric observations, and coach-readable history insights.

## Current Product State

Implemented or partially implemented in the current engine:

- Plan reads active block, phases, weekly rhythms, planned workouts, and training targets.
- Plan renders the visible two-week window.
- Plan renders all days in each visible week, including empty days.
- Plan supports add/replace workout flows with AI suggestions, manual natural-language workout interpretation, and review-before-apply confirmation.
- HealthKit sync stores feature snapshots, actual workouts, history insights, observations, targets, and evaluations.
- Past planned workouts without matching evidence after sync are marked missed.
- Missed workouts can force a visible-window refresh.
- Profile screen and Fitness Profile data plumbing have started.
- Profile is intended to show identity, settings entry, sign out, current goal context, and "What HAYF knows."

Known future work:

- goal review / adjustment flow
- settings screen
- global coach chat
- post-workout feedback UI
- richer Fitness Profile detail views
- user-facing explanations for training targets and target evaluations
- migrate from the current active-block hierarchy to the target post-blueprint architecture

## Design Guardrails

- Keep Plan action-oriented and strategy/week focused.
- Keep Profile holistic, calm, and durable.
- Keep exactly one active user goal.
- Allow strategy changes without replacing the goal.
- Do not put weekly focus in Profile.
- Do not put health data management or global workout feedback in Profile.
- Keep the top-right screen action reserved for coach chat.
- Prefer one clear entry point to each concept over multiple competing shortcuts.
