alter table public.planned_workouts
drop constraint if exists planned_workouts_source_check;

alter table public.planned_workouts
add constraint planned_workouts_source_check
check (
    source in (
        'generated',
        'user_moved',
        'user_deleted',
        'user_added',
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
        'window_refreshed',
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
        'sync_healthkit_and_reconcile',
        'refresh_plan_window',
        'record_plan_edit',
        'recommend_workout_replacements',
        'recommend_workout_additions',
        'interpret_workout_description',
        'replace_workout',
        'add_workout',
        'apply_replan_proposal',
        'check_in_to_workout',
        'scheduled_refresh_due_windows'
    )
);
