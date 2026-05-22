alter table public.planning_ai_generations
drop constraint if exists planning_ai_generations_task_check;

alter table public.planning_ai_generations
add constraint planning_ai_generations_task_check
check (
    task in (
        'bootstrap_after_onboarding',
        'accept_strategy_and_create_initial_plan',
        'sync_healthkit_and_reconcile',
        'refresh_plan_window',
        'generate_weekly_plan_targets',
        'record_plan_edit',
        'record_weekly_plan_constraint',
        'recommend_workout_replacements',
        'recommend_workout_additions',
        'interpret_workout_description',
        'replace_workout',
        'add_workout',
        'create_repair_proposal_for_recent_edit',
        'apply_replan_proposal',
        'check_in_to_workout',
        'scheduled_refresh_due_windows'
    )
);

create index if not exists planning_targets_weekly_plan_idx
    on public.planning_targets (weekly_plan_id, target_scope, created_at);
