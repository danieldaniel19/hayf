create table if not exists public.daily_briefings (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    fitness_strategy_id uuid references public.fitness_strategies(id) on delete cascade,
    weekly_plan_id uuid references public.weekly_plans(id) on delete set null,
    local_date date not null,
    timezone text not null default 'UTC',
    input_fingerprint text not null,
    briefing_json jsonb not null default '{}'::jsonb,
    generation_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, local_date)
);

create index if not exists daily_briefings_user_date_idx
    on public.daily_briefings (user_id, local_date desc);

alter table public.daily_briefings enable row level security;

create policy "Users can read their own daily briefings"
    on public.daily_briefings
    for select
    to authenticated
    using (user_id = auth.uid());

drop trigger if exists set_daily_briefings_updated_at on public.daily_briefings;
create trigger set_daily_briefings_updated_at
before update on public.daily_briefings
for each row
execute function public.set_updated_at();

alter table public.workout_feedback
    add column if not exists updated_at timestamptz not null default now();

drop trigger if exists set_workout_feedback_updated_at on public.workout_feedback;
create trigger set_workout_feedback_updated_at
before update on public.workout_feedback
for each row
execute function public.set_updated_at();

with ranked as (
    select id,
           row_number() over (
               partition by user_id, planned_workout_id
               order by created_at desc, id desc
           ) as position
    from public.workout_feedback
    where planned_workout_id is not null
)
delete from public.workout_feedback feedback
using ranked
where feedback.id = ranked.id
  and ranked.position > 1;

with ranked as (
    select id,
           row_number() over (
               partition by user_id, actual_workout_id
               order by created_at desc, id desc
           ) as position
    from public.workout_feedback
    where actual_workout_id is not null
)
delete from public.workout_feedback feedback
using ranked
where feedback.id = ranked.id
  and ranked.position > 1;

with ranked as (
    select id,
           row_number() over (
               partition by user_id, planned_workout_id
               order by created_at desc, id desc
           ) as position
    from public.workout_debrief_requests
    where planned_workout_id is not null
)
delete from public.workout_debrief_requests debrief
using ranked
where debrief.id = ranked.id
  and ranked.position > 1;

create unique index if not exists workout_feedback_user_planned_unique_idx
    on public.workout_feedback (user_id, planned_workout_id)
    where planned_workout_id is not null;

create unique index if not exists workout_feedback_user_actual_unique_idx
    on public.workout_feedback (user_id, actual_workout_id)
    where actual_workout_id is not null;

create unique index if not exists workout_debrief_user_planned_unique_idx
    on public.workout_debrief_requests (user_id, planned_workout_id)
    where planned_workout_id is not null;

alter table public.planned_workouts
drop constraint if exists planned_workouts_status_check;

alter table public.planned_workouts
add constraint planned_workouts_status_check
check (
    status in (
        'planned',
        'current',
        'checked_in',
        'adjusted',
        'done',
        'missed',
        'skipped',
        'deleted',
        'superseded'
    )
);

alter table public.planned_workouts
drop constraint if exists planned_workouts_source_check;

alter table public.planned_workouts
add constraint planned_workouts_source_check
check (
    source in (
        'generated',
        'user_moved',
        'user_deleted',
        'user_skipped',
        'user_added',
        'user_adjusted',
        'healthkit_detected',
        'checkin_adjusted',
        'replanned'
    )
);

alter table public.plan_events
drop constraint if exists plan_events_event_type_check;

alter table public.plan_events
add constraint plan_events_event_type_check
check (
    event_type in (
        'bootstrapped',
        'strategy_prepared',
        'training_architecture_prepared',
        'strategy_accepted',
        'window_refreshed',
        'weekly_targets_generated',
        'weekly_plan_promoted',
        'weekly_plan_constraint_recorded',
        'workout_moved',
        'workout_deleted',
        'workout_skipped',
        'workout_adjusted',
        'workout_added',
        'workout_completed_manually',
        'actual_synced',
        'actual_matched',
        'extra_workout_detected',
        'checkin_recorded',
        'proposal_created',
        'proposal_accepted',
        'proposal_rejected',
        'plan_review_completed',
        'goal_targets_created',
        'goal_progress_evaluated',
        'goal_status_changed',
        'goal_achieved',
        'goal_review_needed',
        'workout_debrief_requested',
        'workout_feedback_recorded'
    )
);

alter table public.planning_ai_generations
drop constraint if exists planning_ai_generations_task_check;

alter table public.planning_ai_generations
add constraint planning_ai_generations_task_check
check (
    task in (
        'bootstrap_after_onboarding',
        'accept_strategy_and_create_initial_plan',
        'prepare_initial_strategy_after_blueprint',
        'start_prepare_initial_strategy_after_blueprint',
        'start_accept_prepared_strategy_and_create_initial_plan',
        'accept_prepared_strategy_and_create_initial_plan',
        'get_planning_graph_run_status',
        'sync_healthkit_and_reconcile',
        'refresh_plan_window',
        'refresh_workout_weather_forecasts',
        'generate_weekly_plan_targets',
        'refresh_today_briefing',
        'recommend_today_workout_action',
        'skip_workout',
        'adjust_workout',
        'mark_workout_complete',
        'record_workout_feedback',
        'record_plan_edit',
        'record_weekly_plan_constraint',
        'recommend_workout_replacements',
        'recommend_workout_additions',
        'interpret_workout_description',
        'replace_workout',
        'add_workout',
        'create_repair_proposal_for_recent_edit',
        'create_repair_proposal_for_pending_edits',
        'apply_replan_proposal',
        'check_in_to_workout',
        'scheduled_refresh_due_windows'
    )
);
