alter table public.replan_proposals
add column if not exists metadata_json jsonb not null default '{}'::jsonb;

alter table public.plan_events
drop constraint if exists plan_events_event_type_check;

alter table public.plan_events
add constraint plan_events_event_type_check
check (
    event_type in (
        'bootstrapped',
        'strategy_accepted',
        'window_refreshed',
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
        'create_repair_proposal_for_pending_edits',
        'apply_replan_proposal',
        'check_in_to_workout',
        'scheduled_refresh_due_windows'
    )
);
