create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;

create table if not exists public.active_fitness_blocks (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    kind text not null check (
        kind in (
            'specific_goal',
            'goal_discovery_chosen',
            'consistency',
            're_entry',
            'maintenance'
        )
    ),
    title text not null,
    goal_text text,
    status text not null default 'active' check (status in ('active', 'archived', 'completed')),
    start_date date not null,
    target_date date,
    review_cadence_days integer not null default 28,
    timezone text not null default 'UTC',
    source_onboarding_profile_id uuid references public.onboarding_profiles(id) on delete set null,
    context_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists active_fitness_blocks_one_active_per_user_idx
    on public.active_fitness_blocks (user_id)
    where status = 'active';

create index if not exists active_fitness_blocks_user_status_idx
    on public.active_fitness_blocks (user_id, status);

create table if not exists public.fitness_block_phases (
    id uuid primary key default extensions.gen_random_uuid(),
    active_block_id uuid not null references public.active_fitness_blocks(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    start_date date,
    end_date date,
    objective text not null default '',
    focus_json jsonb not null default '[]'::jsonb,
    risk_json jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists fitness_block_phases_block_idx
    on public.fitness_block_phases (active_block_id);

create table if not exists public.weekly_rhythms (
    id uuid primary key default extensions.gen_random_uuid(),
    active_block_id uuid not null references public.active_fitness_blocks(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    week_start_date date not null,
    week_end_date date not null,
    objective text not null default '',
    priority_order_json jsonb not null default '[]'::jsonb,
    hard_easy_distribution_json jsonb not null default '{}'::jsonb,
    bad_day_floor text,
    swap_rules_json jsonb not null default '[]'::jsonb,
    status text not null default 'active' check (status in ('active', 'superseded', 'archived')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists weekly_rhythms_block_week_idx
    on public.weekly_rhythms (active_block_id, week_start_date);

create table if not exists public.planned_workouts (
    id uuid primary key default extensions.gen_random_uuid(),
    active_block_id uuid not null references public.active_fitness_blocks(id) on delete cascade,
    weekly_rhythm_id uuid references public.weekly_rhythms(id) on delete set null,
    user_id uuid not null references auth.users(id) on delete cascade,
    scheduled_date date not null,
    sequence_order integer not null default 1,
    activity_type text not null,
    title text not null,
    duration_minutes integer not null check (duration_minutes > 0),
    intensity_label text not null default 'Moderate',
    purpose text not null default '',
    status text not null default 'planned' check (
        status in (
            'planned',
            'current',
            'checked_in',
            'adjusted',
            'done',
            'missed',
            'deleted',
            'superseded'
        )
    ),
    source text not null default 'generated' check (
        source in (
            'generated',
            'user_moved',
            'user_deleted',
            'healthkit_detected',
            'checkin_adjusted',
            'replanned'
        )
    ),
    prescription_json jsonb not null default '{}'::jsonb,
    fueling_summary text,
    original_workout_id uuid references public.planned_workouts(id) on delete set null,
    version integer not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists planned_workouts_block_date_idx
    on public.planned_workouts (active_block_id, scheduled_date, sequence_order);

create index if not exists planned_workouts_user_status_idx
    on public.planned_workouts (user_id, status);

create table if not exists public.health_feature_snapshots (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    generated_at timestamptz not null,
    snapshot_json jsonb not null default '{}'::jsonb,
    source_timezone text not null default 'UTC',
    created_at timestamptz not null default now()
);

create index if not exists health_feature_snapshots_user_generated_idx
    on public.health_feature_snapshots (user_id, generated_at desc);

create table if not exists public.actual_workouts (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    healthkit_uuid text not null,
    start_date timestamptz not null,
    activity_type text not null,
    duration_minutes integer not null check (duration_minutes > 0),
    distance_kilometers numeric,
    energy_kilocalories numeric,
    load_value numeric,
    matched_planned_workout_id uuid references public.planned_workouts(id) on delete set null,
    match_confidence numeric,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, healthkit_uuid)
);

create index if not exists actual_workouts_user_start_idx
    on public.actual_workouts (user_id, start_date desc);

create table if not exists public.plan_events (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete set null,
    planned_workout_id uuid references public.planned_workouts(id) on delete set null,
    event_type text not null check (
        event_type in (
            'bootstrapped',
            'window_refreshed',
            'workout_moved',
            'workout_deleted',
            'actual_synced',
            'actual_matched',
            'extra_workout_detected',
            'checkin_recorded',
            'proposal_created',
            'proposal_accepted',
            'proposal_rejected'
        )
    ),
    payload_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists plan_events_user_created_idx
    on public.plan_events (user_id, created_at desc);

create table if not exists public.replan_proposals (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete cascade,
    trigger_event_id uuid references public.plan_events(id) on delete set null,
    reason text not null,
    proposed_mutations_json jsonb not null default '[]'::jsonb,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'expired')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists replan_proposals_user_status_idx
    on public.replan_proposals (user_id, status, created_at desc);

create table if not exists public.planning_ai_generations (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    task text not null check (
        task in (
            'bootstrap_after_onboarding',
            'sync_healthkit_and_reconcile',
            'refresh_plan_window',
            'record_plan_edit',
            'apply_replan_proposal',
            'check_in_to_workout',
            'scheduled_refresh_due_windows'
        )
    ),
    model text not null,
    compact_request jsonb not null default '{}'::jsonb,
    structured_response jsonb,
    status text not null check (status in ('success', 'failure')),
    latency_ms integer,
    error_message text,
    created_at timestamptz not null default now()
);

create index if not exists planning_ai_generations_user_created_idx
    on public.planning_ai_generations (user_id, created_at desc);

drop trigger if exists set_active_fitness_blocks_updated_at on public.active_fitness_blocks;
create trigger set_active_fitness_blocks_updated_at
before update on public.active_fitness_blocks
for each row
execute function public.set_updated_at();

drop trigger if exists set_weekly_rhythms_updated_at on public.weekly_rhythms;
create trigger set_weekly_rhythms_updated_at
before update on public.weekly_rhythms
for each row
execute function public.set_updated_at();

drop trigger if exists set_planned_workouts_updated_at on public.planned_workouts;
create trigger set_planned_workouts_updated_at
before update on public.planned_workouts
for each row
execute function public.set_updated_at();

drop trigger if exists set_actual_workouts_updated_at on public.actual_workouts;
create trigger set_actual_workouts_updated_at
before update on public.actual_workouts
for each row
execute function public.set_updated_at();

drop trigger if exists set_replan_proposals_updated_at on public.replan_proposals;
create trigger set_replan_proposals_updated_at
before update on public.replan_proposals
for each row
execute function public.set_updated_at();

alter table public.active_fitness_blocks enable row level security;
alter table public.fitness_block_phases enable row level security;
alter table public.weekly_rhythms enable row level security;
alter table public.planned_workouts enable row level security;
alter table public.health_feature_snapshots enable row level security;
alter table public.actual_workouts enable row level security;
alter table public.plan_events enable row level security;
alter table public.replan_proposals enable row level security;
alter table public.planning_ai_generations enable row level security;

create policy "Users can read their own active fitness blocks"
    on public.active_fitness_blocks
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness block phases"
    on public.fitness_block_phases
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own weekly rhythms"
    on public.weekly_rhythms
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own planned workouts"
    on public.planned_workouts
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own health feature snapshots"
    on public.health_feature_snapshots
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own actual workouts"
    on public.actual_workouts
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own plan events"
    on public.plan_events
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own replan proposals"
    on public.replan_proposals
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own planning AI generations"
    on public.planning_ai_generations
    for select
    to authenticated
    using (user_id = auth.uid());

create or replace function public.invoke_planning_ai_due_windows()
returns void
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
    project_url text := nullif(current_setting('app.supabase_project_url', true), '');
    service_role_key text := nullif(current_setting('app.supabase_service_role_key', true), '');
begin
    if project_url is null or service_role_key is null then
        raise notice 'Skipping planning-ai cron invocation because app.supabase_project_url or app.supabase_service_role_key is not configured.';
        return;
    end if;

    perform net.http_post(
        url := project_url || '/functions/v1/planning-ai',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_role_key
        ),
        body := jsonb_build_object('task', 'scheduled_refresh_due_windows'),
        timeout_milliseconds := 15000
    );
end;
$$;

do $$
begin
    begin
        perform cron.unschedule('planning-ai-refresh-due-windows');
    exception
        when others then null;
    end;

    perform cron.schedule(
        'planning-ai-refresh-due-windows',
        '0 * * * *',
        'select public.invoke_planning_ai_due_windows();'
    );
end $$;
