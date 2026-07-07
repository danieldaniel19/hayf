create table if not exists public.ai_graph_runs (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    graph_name text not null check (
        graph_name in (
            'training_architecture',
            'fitness_strategy',
            'two_week_plan'
        )
    ),
    graph_version text not null default 'v1',
    triggering_task text not null,
    source_blueprint_revision_id uuid references public.athlete_blueprint_revisions(id) on delete set null,
    source_user_goal_id uuid references public.user_goals(id) on delete set null,
    source_fitness_strategy_id uuid references public.fitness_strategies(id) on delete set null,
    source_training_architecture_id uuid,
    orchestration_service_run_id text,
    status text not null default 'running' check (
        status in (
            'queued',
            'running',
            'succeeded',
            'failed',
            'cancelled'
        )
    ),
    input_json jsonb not null default '{}'::jsonb,
    output_json jsonb,
    model_json jsonb not null default '{}'::jsonb,
    error_summary text,
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists ai_graph_runs_user_created_idx
    on public.ai_graph_runs (user_id, created_at desc);

create index if not exists ai_graph_runs_user_status_idx
    on public.ai_graph_runs (user_id, graph_name, status, created_at desc);

create table if not exists public.training_architectures (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    user_goal_id uuid not null references public.user_goals(id) on delete cascade,
    source_blueprint_revision_id uuid not null references public.athlete_blueprint_revisions(id) on delete restrict,
    ai_graph_run_id uuid not null references public.ai_graph_runs(id) on delete restrict,
    version integer not null check (version > 0),
    status text not null default 'prepared' check (
        status in (
            'prepared',
            'active',
            'superseded',
            'failed'
        )
    ),
    input_packet_json jsonb not null default '{}'::jsonb,
    architecture_json jsonb not null default '{}'::jsonb,
    conflict_assessment_json jsonb not null default '{}'::jsonb,
    validation_json jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_goal_id, version)
);

create unique index if not exists training_architectures_one_active_per_goal_idx
    on public.training_architectures (user_goal_id)
    where status = 'active';

create index if not exists training_architectures_user_status_idx
    on public.training_architectures (user_id, status, created_at desc);

alter table public.ai_graph_runs
add constraint ai_graph_runs_source_training_architecture_fk
foreign key (source_training_architecture_id)
references public.training_architectures(id)
on delete set null
deferrable initially deferred;

create table if not exists public.ai_graph_node_outputs (
    id uuid primary key default extensions.gen_random_uuid(),
    graph_run_id uuid not null references public.ai_graph_runs(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    node_name text not null,
    subgraph_name text,
    sequence_order integer not null default 1 check (sequence_order > 0),
    input_summary_json jsonb not null default '{}'::jsonb,
    structured_output_json jsonb not null default '{}'::jsonb,
    validation_json jsonb not null default '{}'::jsonb,
    status text not null check (
        status in (
            'succeeded',
            'failed',
            'skipped'
        )
    ),
    retry_count integer not null default 0 check (retry_count >= 0),
    error_message text,
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists ai_graph_node_outputs_run_order_idx
    on public.ai_graph_node_outputs (graph_run_id, sequence_order, created_at);

create table if not exists public.ai_tool_calls (
    id uuid primary key default extensions.gen_random_uuid(),
    graph_run_id uuid not null references public.ai_graph_runs(id) on delete cascade,
    graph_node_output_id uuid references public.ai_graph_node_outputs(id) on delete set null,
    user_id uuid references auth.users(id) on delete cascade,
    tool_name text not null,
    tool_version text not null default 'v1',
    input_json jsonb not null default '{}'::jsonb,
    output_json jsonb,
    status text not null check (
        status in (
            'succeeded',
            'failed',
            'skipped'
        )
    ),
    error_message text,
    latency_ms integer,
    started_at timestamptz not null default now(),
    finished_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists ai_tool_calls_run_created_idx
    on public.ai_tool_calls (graph_run_id, created_at);

alter table public.user_goals
drop constraint if exists user_goals_status_check;

alter table public.user_goals
add constraint user_goals_status_check
check (status in ('prepared', 'active', 'superseded', 'completed'));

alter table public.fitness_strategies
drop constraint if exists fitness_strategies_status_check;

alter table public.fitness_strategies
add constraint fitness_strategies_status_check
check (status in ('prepared', 'active', 'superseded', 'completed'));

alter table public.fitness_strategies
add column if not exists training_architecture_id uuid
references public.training_architectures(id) on delete set null;

create index if not exists fitness_strategies_training_architecture_idx
    on public.fitness_strategies (training_architecture_id);

alter table public.weekly_plans
add column if not exists training_architecture_id uuid
references public.training_architectures(id) on delete set null;

create index if not exists weekly_plans_training_architecture_idx
    on public.weekly_plans (training_architecture_id);

alter table public.fitness_metric_observations
add column if not exists user_goal_id uuid references public.user_goals(id) on delete set null,
add column if not exists fitness_strategy_id uuid references public.fitness_strategies(id) on delete set null;

create index if not exists fitness_metric_observations_goal_strategy_idx
    on public.fitness_metric_observations (user_id, user_goal_id, fitness_strategy_id, created_at desc);

alter table public.fitness_history_insights
add column if not exists user_goal_id uuid references public.user_goals(id) on delete set null,
add column if not exists fitness_strategy_id uuid references public.fitness_strategies(id) on delete set null;

create index if not exists fitness_history_insights_goal_strategy_idx
    on public.fitness_history_insights (user_id, user_goal_id, fitness_strategy_id, updated_at desc);

alter table public.planning_ai_generations
drop constraint if exists planning_ai_generations_task_check;

alter table public.planning_ai_generations
add constraint planning_ai_generations_task_check
check (
    task in (
        'bootstrap_after_onboarding',
        'accept_strategy_and_create_initial_plan',
        'prepare_initial_strategy_after_blueprint',
        'accept_prepared_strategy_and_create_initial_plan',
        'get_planning_graph_run_status',
        'sync_healthkit_and_reconcile',
        'refresh_plan_window',
        'refresh_workout_weather_forecasts',
        'generate_weekly_plan_targets',
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
        'workout_added',
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

drop trigger if exists set_ai_graph_runs_updated_at on public.ai_graph_runs;
create trigger set_ai_graph_runs_updated_at
before update on public.ai_graph_runs
for each row
execute function public.set_updated_at();

drop trigger if exists set_training_architectures_updated_at on public.training_architectures;
create trigger set_training_architectures_updated_at
before update on public.training_architectures
for each row
execute function public.set_updated_at();

alter table public.ai_graph_runs enable row level security;
alter table public.training_architectures enable row level security;
alter table public.ai_graph_node_outputs enable row level security;
alter table public.ai_tool_calls enable row level security;

create policy "Users can read their own AI graph runs"
    on public.ai_graph_runs
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own training architectures"
    on public.training_architectures
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own AI graph node outputs"
    on public.ai_graph_node_outputs
    for select
    to authenticated
    using (user_id = auth.uid());

create policy "Users can read their own AI tool calls"
    on public.ai_tool_calls
    for select
    to authenticated
    using (user_id = auth.uid());
