alter table public.weekly_plans
add column if not exists context_json jsonb not null default '{}'::jsonb;

update public.weekly_plans
set context_json = jsonb_build_object(
    'schemaVersion', 1,
    'strategyExplanation', case
        when length(trim(objective)) > 0 then trim(objective)
        else 'This week supports the current strategy while keeping training repeatable.'
    end,
    'provenance', 'hayf_original',
    'adaptationExplanation', null,
    'updatedAt', coalesce(updated_at, now())
)
where context_json = '{}'::jsonb;
