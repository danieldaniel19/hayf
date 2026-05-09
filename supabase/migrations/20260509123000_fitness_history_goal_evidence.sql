create table if not exists public.fitness_metric_observations (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete set null,
    source text not null check (source in ('healthkit', 'manual', 'hayf_feedback', 'future_external')),
    metric_key text not null,
    metric_label text not null,
    metric_category text not null,
    value numeric,
    unit text,
    observed_start timestamptz,
    observed_end timestamptz,
    dimensions_json jsonb not null default '{}'::jsonb,
    evidence_json jsonb not null default '{}'::jsonb,
    confidence text not null default 'medium' check (confidence in ('low', 'medium', 'high')),
    created_at timestamptz not null default now()
);

create index if not exists fitness_metric_observations_user_metric_idx
    on public.fitness_metric_observations (user_id, metric_key, observed_end desc);

create index if not exists fitness_metric_observations_user_category_idx
    on public.fitness_metric_observations (user_id, metric_category, created_at desc);

create table if not exists public.fitness_history_insights (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete set null,
    insight_key text not null,
    category text not null,
    title text not null,
    summary text not null,
    evidence_json jsonb not null default '{}'::jsonb,
    source text not null default 'healthkit' check (source in ('healthkit', 'manual', 'hayf_feedback', 'future_external', 'combined')),
    confidence text not null default 'medium' check (confidence in ('low', 'medium', 'high')),
    valid_from date,
    valid_until date,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, insight_key)
);

create index if not exists fitness_history_insights_user_category_idx
    on public.fitness_history_insights (user_id, category, updated_at desc);

create table if not exists public.fitness_goal_targets (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid not null references public.active_fitness_blocks(id) on delete cascade,
    parent_goal_target_id uuid references public.fitness_goal_targets(id) on delete cascade,
    target_kind text not null check (target_kind in ('primary', 'sub_goal')),
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
    updated_at timestamptz not null default now()
);

create index if not exists fitness_goal_targets_block_kind_idx
    on public.fitness_goal_targets (active_block_id, target_kind, created_at);

create index if not exists fitness_goal_targets_user_status_idx
    on public.fitness_goal_targets (user_id, status, updated_at desc);

create table if not exists public.fitness_goal_evaluations (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid not null references public.active_fitness_blocks(id) on delete cascade,
    goal_target_id uuid not null references public.fitness_goal_targets(id) on delete cascade,
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

create index if not exists fitness_goal_evaluations_goal_time_idx
    on public.fitness_goal_evaluations (goal_target_id, evaluated_at desc);

create index if not exists fitness_goal_evaluations_user_time_idx
    on public.fitness_goal_evaluations (user_id, evaluated_at desc);

create table if not exists public.workout_debrief_requests (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete cascade,
    planned_workout_id uuid references public.planned_workouts(id) on delete set null,
    actual_workout_id uuid references public.actual_workouts(id) on delete set null,
    status text not null default 'needed' check (status in ('needed', 'completed', 'dismissed', 'expired')),
    prompt_reason text not null default 'completed_workout_detected',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, actual_workout_id)
);

create index if not exists workout_debrief_requests_user_status_idx
    on public.workout_debrief_requests (user_id, status, created_at desc);

create table if not exists public.workout_feedback (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    active_block_id uuid references public.active_fitness_blocks(id) on delete set null,
    planned_workout_id uuid references public.planned_workouts(id) on delete set null,
    actual_workout_id uuid references public.actual_workouts(id) on delete set null,
    perceived_effort numeric,
    felt_rating numeric,
    pain_flag boolean not null default false,
    pain_notes text,
    difficulty_label text check (difficulty_label in ('too_easy', 'right', 'too_hard')),
    free_text text,
    feedback_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists workout_feedback_user_created_idx
    on public.workout_feedback (user_id, created_at desc);

drop trigger if exists set_fitness_history_insights_updated_at on public.fitness_history_insights;
create trigger set_fitness_history_insights_updated_at
before update on public.fitness_history_insights
for each row
execute function public.set_updated_at();

drop trigger if exists set_fitness_goal_targets_updated_at on public.fitness_goal_targets;
create trigger set_fitness_goal_targets_updated_at
before update on public.fitness_goal_targets
for each row
execute function public.set_updated_at();

drop trigger if exists set_workout_debrief_requests_updated_at on public.workout_debrief_requests;
create trigger set_workout_debrief_requests_updated_at
before update on public.workout_debrief_requests
for each row
execute function public.set_updated_at();

alter table public.fitness_metric_observations enable row level security;
alter table public.fitness_history_insights enable row level security;
alter table public.fitness_goal_targets enable row level security;
alter table public.fitness_goal_evaluations enable row level security;
alter table public.workout_debrief_requests enable row level security;
alter table public.workout_feedback enable row level security;

create policy "Users can read their own fitness metric observations"
    on public.fitness_metric_observations
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness history insights"
    on public.fitness_history_insights
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness goal targets"
    on public.fitness_goal_targets
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own fitness goal evaluations"
    on public.fitness_goal_evaluations
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own workout debrief requests"
    on public.workout_debrief_requests
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own workout feedback"
    on public.workout_feedback
    for select
    to authenticated
    using (user_id = auth.uid());

alter table public.plan_events
drop constraint if exists plan_events_event_type_check;

alter table public.plan_events
add constraint plan_events_event_type_check
check (
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
        'proposal_rejected',
        'goal_targets_created',
        'goal_progress_evaluated',
        'goal_status_changed',
        'goal_achieved',
        'goal_review_needed',
        'workout_debrief_requested',
        'workout_feedback_recorded'
    )
);
