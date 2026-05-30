alter table public.planned_workouts
add column if not exists generation_key text;

with ranked_generated_slots as (
    select
        id,
        row_number() over (
            partition by user_id, weekly_plan_id, scheduled_date, sequence_order
            order by
                case status when 'current' then 0 else 1 end,
                created_at asc,
                id asc
        ) as slot_rank
    from public.planned_workouts
    where weekly_plan_id is not null
      and source in ('generated', 'replanned')
      and status in ('planned', 'current')
)
update public.planned_workouts workout
set status = 'superseded',
    generation_key = null
from ranked_generated_slots ranked
where workout.id = ranked.id
  and ranked.slot_rank > 1;

update public.planned_workouts
set generation_key = scheduled_date::text || ':' || sequence_order::text
where weekly_plan_id is not null
  and source in ('generated', 'replanned')
  and status in ('planned', 'current')
  and generation_key is null;

with ranked_generation_keys as (
    select
        id,
        row_number() over (
            partition by user_id, weekly_plan_id, generation_key
            order by
                case status when 'current' then 0 else 1 end,
                created_at asc,
                id asc
        ) as key_rank
    from public.planned_workouts
    where weekly_plan_id is not null
      and generation_key is not null
      and source in ('generated', 'replanned')
      and status in ('planned', 'current')
)
update public.planned_workouts workout
set status = 'superseded',
    generation_key = null
from ranked_generation_keys ranked
where workout.id = ranked.id
  and ranked.key_rank > 1;

create unique index if not exists planned_workouts_generation_key_unique_idx
    on public.planned_workouts (user_id, weekly_plan_id, generation_key);
