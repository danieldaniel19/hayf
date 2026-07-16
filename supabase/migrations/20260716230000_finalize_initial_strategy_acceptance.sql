create or replace function public.finalize_initial_strategy_acceptance(
    p_user_id uuid,
    p_user_goal_id uuid,
    p_fitness_strategy_id uuid,
    p_training_architecture_id uuid,
    p_source_onboarding_profile_id uuid,
    p_program_start_date date,
    p_target_date date,
    p_accepted_at timestamptz,
    p_accepted_local_date date,
    p_plan_owner_start_date date,
    p_graph_run_id uuid,
    p_recovered_from_persisted_plan boolean default false,
    p_event_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_strategy_status text;
    v_visible_plan_count integer;
    v_committed_plan_count integer;
    v_workout_count integer;
    v_empty_plan_count integer;
    v_event_id uuid;
    v_current_workout_id uuid;
begin
    select status
    into v_strategy_status
    from public.fitness_strategies
    where id = p_fitness_strategy_id
      and user_id = p_user_id
    for update;

    if v_strategy_status is null then
        raise exception 'Prepared fitness strategy not found';
    end if;

    if v_strategy_status not in ('prepared', 'active') then
        raise exception 'Fitness strategy is not prepared for acceptance';
    end if;

    select
        count(*) filter (where status in ('committed', 'draft')),
        count(*) filter (where status = 'committed')
    into v_visible_plan_count, v_committed_plan_count
    from public.weekly_plans
    where user_id = p_user_id
      and fitness_strategy_id = p_fitness_strategy_id;

    select count(*)
    into v_workout_count
    from public.planned_workouts workout
    join public.weekly_plans plan on plan.id = workout.weekly_plan_id
    where workout.user_id = p_user_id
      and plan.user_id = p_user_id
      and plan.fitness_strategy_id = p_fitness_strategy_id
      and plan.status in ('committed', 'draft')
      and workout.status not in ('deleted', 'superseded');

    select count(*)
    into v_empty_plan_count
    from public.weekly_plans plan
    where plan.user_id = p_user_id
      and plan.fitness_strategy_id = p_fitness_strategy_id
      and plan.status in ('committed', 'draft')
      and not exists (
          select 1
          from public.planned_workouts workout
          where workout.user_id = p_user_id
            and workout.weekly_plan_id = plan.id
            and workout.status not in ('deleted', 'superseded')
      );

    if v_visible_plan_count < 2 or v_committed_plan_count < 1 or v_workout_count < 1 or v_empty_plan_count > 0 then
        raise exception 'Initial plan is incomplete and cannot be activated';
    end if;

    if v_strategy_status = 'prepared' then
        update public.training_architectures
        set status = 'superseded'
        where user_id = p_user_id
          and status = 'active'
          and (p_training_architecture_id is null or id <> p_training_architecture_id);

        update public.fitness_strategies
        set status = 'superseded'
        where user_id = p_user_id
          and status = 'active'
          and id <> p_fitness_strategy_id;

        update public.user_goals
        set status = 'superseded'
        where user_id = p_user_id
          and status = 'active'
          and id <> p_user_goal_id;

        update public.user_goals
        set status = 'active',
            source_onboarding_profile_id = coalesce(p_source_onboarding_profile_id, source_onboarding_profile_id),
            start_date = p_program_start_date,
            target_date = p_target_date
        where id = p_user_goal_id
          and user_id = p_user_id;

        if not found then
            raise exception 'Prepared user goal not found';
        end if;

        update public.fitness_strategies
        set status = 'active',
            start_date = p_program_start_date,
            target_date = p_target_date,
            context_json = coalesce(context_json, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
                'acceptedAt', p_accepted_at,
                'planOwnerStartDate', p_plan_owner_start_date,
                'programStartDate', p_program_start_date
            ))
        where id = p_fitness_strategy_id
          and user_id = p_user_id;

        if p_training_architecture_id is not null then
            update public.training_architectures
            set status = 'active'
            where id = p_training_architecture_id
              and user_id = p_user_id;

            if not found then
                raise exception 'Prepared Training Architecture not found';
            end if;
        end if;
    end if;

    update public.planned_workouts workout
    set status = 'planned'
    from public.weekly_plans plan
    where plan.id = workout.weekly_plan_id
      and workout.user_id = p_user_id
      and plan.user_id = p_user_id
      and plan.fitness_strategy_id = p_fitness_strategy_id
      and workout.status = 'current';

    select workout.id
    into v_current_workout_id
    from public.planned_workouts workout
    join public.weekly_plans plan on plan.id = workout.weekly_plan_id
    where workout.user_id = p_user_id
      and plan.user_id = p_user_id
      and plan.fitness_strategy_id = p_fitness_strategy_id
      and plan.status in ('committed', 'draft')
      and workout.scheduled_date >= p_accepted_local_date
      and workout.status in ('planned', 'checked_in', 'adjusted')
    order by workout.scheduled_date, workout.sequence_order
    limit 1;

    if v_current_workout_id is not null then
        update public.planned_workouts
        set status = 'current'
        where id = v_current_workout_id
          and status = 'planned';
    end if;

    select id
    into v_event_id
    from public.plan_events
    where user_id = p_user_id
      and fitness_strategy_id = p_fitness_strategy_id
      and event_type = 'strategy_accepted'
    order by created_at desc
    limit 1;

    if v_event_id is null then
        insert into public.plan_events (
            user_id,
            user_goal_id,
            fitness_strategy_id,
            event_type,
            payload_json
        )
        values (
            p_user_id,
            p_user_goal_id,
            p_fitness_strategy_id,
            'strategy_accepted',
            coalesce(p_event_payload, '{}'::jsonb) || jsonb_build_object(
                'activationCommitted', true,
                'recoveredFromPersistedPlan', p_recovered_from_persisted_plan
            )
        )
        returning id into v_event_id;
    end if;

    if p_graph_run_id is not null then
        update public.ai_graph_runs
        set status = 'succeeded',
            output_json = coalesce(output_json, '{}'::jsonb) || jsonb_build_object(
                'activationCommitted', true,
                'recoveredFromPersistedPlan', p_recovered_from_persisted_plan
            ),
            error_summary = null,
            finished_at = coalesce(finished_at, now()),
            updated_at = now()
        where id = p_graph_run_id
          and user_id = p_user_id
          and source_fitness_strategy_id = p_fitness_strategy_id;
    end if;

    return jsonb_build_object(
        'fitnessStrategyID', p_fitness_strategy_id,
        'eventID', v_event_id,
        'visiblePlanCount', v_visible_plan_count,
        'workoutCount', v_workout_count,
        'currentWorkoutID', v_current_workout_id,
        'recoveredFromPersistedPlan', p_recovered_from_persisted_plan
    );
end;
$$;

revoke all on function public.finalize_initial_strategy_acceptance(
    uuid, uuid, uuid, uuid, uuid, date, date, timestamptz, date, date, uuid, boolean, jsonb
) from public;
grant execute on function public.finalize_initial_strategy_acceptance(
    uuid, uuid, uuid, uuid, uuid, date, date, timestamptz, date, date, uuid, boolean, jsonb
) to service_role;
