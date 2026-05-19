create table if not exists public.athlete_profiles (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null unique references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.athlete_blueprint_revisions (
    id uuid primary key default extensions.gen_random_uuid(),
    athlete_profile_id uuid not null references public.athlete_profiles(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    revision_number integer not null check (revision_number > 0),
    generation_reason text not null check (
        generation_reason in (
            'initial_post_onboarding',
            'scheduled_reassessment',
            'material_evidence_change',
            'manual_refresh'
        )
    ),
    coach_read text not null,
    athlete_archetype_json jsonb not null default '{}'::jsonb,
    current_training_state_json jsonb not null default '{}'::jsonb,
    history_findings_json jsonb not null default '[]'::jsonb,
    goal_fit_json jsonb not null default '{}'::jsonb,
    planning_inputs_json jsonb not null default '{}'::jsonb,
    evidence_packet_json jsonb not null default '{}'::jsonb,
    evidence_packet_version text not null default 'v1',
    generated_at timestamptz not null default now(),
    accepted_at timestamptz,
    created_at timestamptz not null default now(),
    unique (athlete_profile_id, revision_number)
);

alter table public.athlete_profiles
add column if not exists current_blueprint_revision_id uuid
references public.athlete_blueprint_revisions(id) on delete set null;

create index if not exists athlete_blueprint_revisions_user_generated_idx
    on public.athlete_blueprint_revisions (user_id, generated_at desc);

create table if not exists public.user_goals (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    source_onboarding_profile_id uuid references public.onboarding_profiles(id) on delete set null,
    source_blueprint_revision_id uuid references public.athlete_blueprint_revisions(id) on delete set null,
    goal_kind text not null check (
        goal_kind in (
            'consistency',
            'specific_goal',
            'goal_discovery_chosen'
        )
    ),
    title text not null,
    normalized_goal_json jsonb not null default '{}'::jsonb,
    timeframe_weeks integer,
    status text not null default 'active' check (status in ('active', 'superseded', 'completed')),
    start_date date not null,
    target_date date,
    requires_phases boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists user_goals_one_active_per_user_idx
    on public.user_goals (user_id)
    where status = 'active';

create index if not exists user_goals_user_status_idx
    on public.user_goals (user_id, status, created_at desc);

create table if not exists public.fitness_strategies (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    user_goal_id uuid not null references public.user_goals(id) on delete cascade,
    source_blueprint_revision_id uuid references public.athlete_blueprint_revisions(id) on delete set null,
    version integer not null check (version > 0),
    change_reason text not null check (
        change_reason in (
            'initial',
            'coach_adjustment',
            'goal_restart',
            'manual_review'
        )
    ),
    status text not null default 'active' check (status in ('active', 'superseded', 'completed')),
    title text not null,
    summary text not null default '',
    rationale text not null default '',
    review_cadence_days integer not null default 28,
    start_date date not null,
    target_date date,
    requires_phases boolean not null default false,
    context_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_goal_id, version)
);

create unique index if not exists fitness_strategies_one_active_per_goal_idx
    on public.fitness_strategies (user_goal_id)
    where status = 'active';

create unique index if not exists fitness_strategies_one_active_per_user_idx
    on public.fitness_strategies (user_id)
    where status = 'active';

create index if not exists fitness_strategies_user_status_idx
    on public.fitness_strategies (user_id, status, created_at desc);

create table if not exists public.fitness_strategy_phases (
    id uuid primary key default extensions.gen_random_uuid(),
    fitness_strategy_id uuid not null references public.fitness_strategies(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    sequence_order integer not null check (sequence_order > 0),
    name text not null,
    start_date date,
    end_date date,
    objective text not null default '',
    focus_json jsonb not null default '[]'::jsonb,
    risk_json jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default now(),
    unique (fitness_strategy_id, sequence_order)
);

create index if not exists fitness_strategy_phases_strategy_idx
    on public.fitness_strategy_phases (fitness_strategy_id, sequence_order);

create table if not exists public.weekly_plans (
    id uuid primary key default extensions.gen_random_uuid(),
    fitness_strategy_id uuid not null references public.fitness_strategies(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    week_start_date date not null,
    week_end_date date not null,
    status text not null check (status in ('draft', 'committed', 'superseded', 'archived')),
    objective text not null default '',
    rhythm_json jsonb not null default '{}'::jsonb,
    constraints_json jsonb not null default '{}'::jsonb,
    generated_at timestamptz not null default now(),
    promoted_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (fitness_strategy_id, week_start_date)
);

create index if not exists weekly_plans_strategy_week_idx
    on public.weekly_plans (fitness_strategy_id, week_start_date);

create index if not exists weekly_plans_user_status_idx
    on public.weekly_plans (user_id, status, week_start_date desc);

alter table public.planned_workouts
add column if not exists weekly_plan_id uuid
references public.weekly_plans(id) on delete set null;

create table if not exists public.planning_targets (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    user_goal_id uuid references public.user_goals(id) on delete cascade,
    fitness_strategy_id uuid references public.fitness_strategies(id) on delete cascade,
    fitness_strategy_phase_id uuid references public.fitness_strategy_phases(id) on delete cascade,
    weekly_plan_id uuid references public.weekly_plans(id) on delete cascade,
    planned_workout_id uuid references public.planned_workouts(id) on delete cascade,
    target_scope text not null check (target_scope in ('goal', 'strategy', 'phase', 'week', 'session')),
    target_kind text not null check (target_kind in ('primary', 'supporting')),
    title text not null,
    description text,
    metric_key text,
    metric_category text,
    direction text not null default 'maintain' check (direction in ('increase', 'decrease', 'maintain', 'complete', 'review')),
    baseline_value numeric,
    target_value numeric,
    unit text,
    start_date date not null,
    target_date date,
    evaluation_rule_json jsonb not null default '{}'::jsonb,
    source text not null default 'planning_engine' check (source in ('planning_engine', 'user', 'coach')),
    status text not null default 'needs_review' check (status in ('on_track', 'lagging', 'achieved', 'needs_review')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (
        num_nonnulls(
            user_goal_id,
            fitness_strategy_id,
            fitness_strategy_phase_id,
            weekly_plan_id,
            planned_workout_id
        ) = 1
    ),
    check (
        (target_scope = 'goal' and user_goal_id is not null) or
        (target_scope = 'strategy' and fitness_strategy_id is not null) or
        (target_scope = 'phase' and fitness_strategy_phase_id is not null) or
        (target_scope = 'week' and weekly_plan_id is not null) or
        (target_scope = 'session' and planned_workout_id is not null)
    )
);

create index if not exists planning_targets_user_scope_idx
    on public.planning_targets (user_id, target_scope, status, updated_at desc);

create table if not exists public.planning_target_evaluations (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    planning_target_id uuid not null references public.planning_targets(id) on delete cascade,
    status text not null check (status in ('on_track', 'lagging', 'achieved', 'needs_review')),
    current_value numeric,
    target_value numeric,
    unit text,
    progress_ratio numeric,
    evaluated_at timestamptz not null default now(),
    evidence_json jsonb not null default '{}'::jsonb,
    message text not null default '',
    confidence text not null default 'medium' check (confidence in ('low', 'medium', 'high'))
);

create index if not exists planning_target_evaluations_target_time_idx
    on public.planning_target_evaluations (planning_target_id, evaluated_at desc);

create index if not exists planning_target_evaluations_user_time_idx
    on public.planning_target_evaluations (user_id, evaluated_at desc);

alter table public.plan_events
add column if not exists user_goal_id uuid references public.user_goals(id) on delete set null,
add column if not exists fitness_strategy_id uuid references public.fitness_strategies(id) on delete set null,
add column if not exists weekly_plan_id uuid references public.weekly_plans(id) on delete set null;

alter table public.replan_proposals
add column if not exists user_goal_id uuid references public.user_goals(id) on delete set null,
add column if not exists fitness_strategy_id uuid references public.fitness_strategies(id) on delete set null,
add column if not exists weekly_plan_id uuid references public.weekly_plans(id) on delete set null;

drop trigger if exists set_athlete_profiles_updated_at on public.athlete_profiles;
create trigger set_athlete_profiles_updated_at
before update on public.athlete_profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_user_goals_updated_at on public.user_goals;
create trigger set_user_goals_updated_at
before update on public.user_goals
for each row
execute function public.set_updated_at();

drop trigger if exists set_fitness_strategies_updated_at on public.fitness_strategies;
create trigger set_fitness_strategies_updated_at
before update on public.fitness_strategies
for each row
execute function public.set_updated_at();

drop trigger if exists set_weekly_plans_updated_at on public.weekly_plans;
create trigger set_weekly_plans_updated_at
before update on public.weekly_plans
for each row
execute function public.set_updated_at();

drop trigger if exists set_planning_targets_updated_at on public.planning_targets;
create trigger set_planning_targets_updated_at
before update on public.planning_targets
for each row
execute function public.set_updated_at();

alter table public.athlete_profiles enable row level security;
alter table public.athlete_blueprint_revisions enable row level security;
alter table public.user_goals enable row level security;
alter table public.fitness_strategies enable row level security;
alter table public.fitness_strategy_phases enable row level security;
alter table public.weekly_plans enable row level security;
alter table public.planning_targets enable row level security;
alter table public.planning_target_evaluations enable row level security;

create policy "Users can read their own athlete profiles"
    on public.athlete_profiles
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own athlete blueprint revisions"
    on public.athlete_blueprint_revisions
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own user goals"
    on public.user_goals
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness strategies"
    on public.fitness_strategies
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness strategy phases"
    on public.fitness_strategy_phases
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own weekly plans"
    on public.weekly_plans
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own planning targets"
    on public.planning_targets
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own planning target evaluations"
    on public.planning_target_evaluations
    for select
    to authenticated
    using (user_id = auth.uid());
