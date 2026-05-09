alter table public.planning_ai_generations
drop constraint if exists planning_ai_generations_task_check;

alter table public.planning_ai_generations
add constraint planning_ai_generations_task_check
check (
    task in (
        'bootstrap_after_onboarding',
        'sync_healthkit_and_reconcile',
        'refresh_plan_window',
        'record_plan_edit',
        'recommend_workout_replacements',
        'replace_workout',
        'apply_replan_proposal',
        'check_in_to_workout',
        'scheduled_refresh_due_windows'
    )
);
