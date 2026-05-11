# HAYF Information Architecture

Last updated: 2026-05-11

This document is the working source of truth for where fitness planning, goals, profile context, and account controls live in the app. Its main job is to prevent naming drift and duplicated surfaces as the product grows.

## Canonical Terms

- **Active block** is the canonical name for the user's current durable training container. It maps to `active_fitness_blocks`.
- **Current goal** can be used as friendly Profile copy when referring to the user's active block goal, but it should not imply a separate data object.
- **Training targets** are HAYF-derived short-term targets or sub-goals, such as cycling kilometers per week, running kilometers per week, upper-body minutes, or consistency targets. They map to `fitness_goal_targets`.
- **This week's focus** is the week-level objective from `weekly_rhythms`. It belongs in Plan, not Profile.
- **What HAYF knows** is the user-facing summary of durable fitness evidence, powered by `fitness_history_insights`, `fitness_metric_observations`, and related evaluations.

Avoid using **active goal** as a product term when it means the active block. If the UI needs a softer label, use copy like "Current goal" while keeping the underlying concept clear.

## Screen Responsibilities

### Plan

Plan is the execution home.

It should answer: What am I doing now, what is HAYF optimizing for this block, and what is scheduled across the visible planning window?

Plan owns:

- active block status, phase, and progress
- training targets for the active block
- this week's focus / objective
- current week plus next week workout schedule
- direct workout planning actions, such as moving, deleting, replacing, or adding planned workouts
- repair proposals and plan refresh states

The Plan screen may scroll. The first glance should prioritize the active block, training targets, and current week context. The two-week schedule should always render all seven days of each week, even when a day has no workout, so users can choose explicit move targets for planned workouts.

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

It should answer: Who am I in HAYF, what goal/context is HAYF carrying for me, and what does HAYF know about my fitness history?

Profile owns:

- name and basic account identity
- location, when available or user-provided
- one quiet settings entry point
- first-level sign out
- a fitness profile card for "What HAYF knows"
- a calm place to revisit the durable goal/current focus after onboarding

Profile should not become a week-planning dashboard. It can reference the current goal because users need a post-onboarding home for goals like "drop 2 kg" or "body fat 15% to 12%", but weekly execution and training targets still belong in Plan.

Profile should not include:

- a second settings entry in the top-right
- global workout feedback
- health data management as a top-level Profile item
- week focus cards or active block execution details that duplicate Plan

Primary implementation references:

- `HAYFHealthKitPrototype/Profile/ProfileScreenView.swift`
- `HAYFHealthKitPrototype/Profile/ProfileDataStore.swift`
- `design/mocks/Profile/README.md`

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

Onboarding can create a concrete goal such as losing 2 kg, reducing body fat from 15% to 12%, building consistency, preparing for an event, or discovering a better fitness direction. After onboarding, that intent becomes the active block.

The post-onboarding model is:

1. **Active block** carries the durable goal, review cadence, timeline, and broad training direction.
2. **Weekly rhythm** translates that durable goal into the current week's focus and constraints.
3. **Training targets** translate the goal into measurable short-term signals HAYF watches.
4. **Planned workouts** turn the target/rhythm into specific scheduled sessions.
5. **Actual workouts and feedback** update HAYF's evidence, evaluations, and future plan choices.

This means goals appear in two places for different reasons:

- Profile lets the user revisit the durable goal and understand what HAYF believes about them.
- Plan shows how that goal is being operationalized right now.

Do not create parallel goal surfaces that let users edit the same concept in unrelated places. A goal review or adjustment can start from Profile or Plan, but the actual change should resolve through a single review flow, later likely with coach assistance.

## Data Sources

The current planning/profile evidence layer is source-agnostic.

Core tables:

- `active_fitness_blocks`: one active block per user
- `fitness_block_phases`: optional block phases
- `weekly_rhythms`: week-level objective and operating rhythm
- `planned_workouts`: concrete scheduled workouts
- `health_feature_snapshots`: compact HealthKit-derived snapshots
- `actual_workouts`: imported HealthKit workout summaries
- `fitness_history_insights`: coach-readable "What HAYF knows" insights
- `fitness_metric_observations`: labelled metric evidence
- `fitness_goal_targets`: primary goal target plus supporting training targets
- `fitness_goal_evaluations`: append-only target evaluations
- `workout_debrief_requests`: prompts for post-workout feedback
- `workout_feedback`: user feedback after workouts
- `plan_events`: audit trail for user and engine planning changes
- `replan_proposals`: reviewable repair proposals after meaningful planning changes
- `planning_ai_generations`: compact AI request/response traces and failures

HealthKit remains the source of truth for Apple health data. HAYF stores compact derived features and evidence, not raw HealthKit sample history.

## Current Product State

Implemented or partially implemented:

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

## Design Guardrails

- Keep Plan action-oriented and week/block focused.
- Keep Profile holistic, calm, and durable.
- Do not duplicate the active block as a separate "active goal" object.
- Do not put weekly focus in Profile.
- Do not put health data management or global workout feedback in Profile.
- Keep the top-right screen action reserved for coach chat.
- Prefer one clear entry point to each concept over multiple competing shortcuts.
