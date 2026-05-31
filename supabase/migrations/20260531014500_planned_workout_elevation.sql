alter table public.planned_workouts
add column if not exists estimated_elevation_meters numeric;

comment on column public.planned_workouts.estimated_elevation_meters is
  'Approximate planned elevation gain for distance-bearing route workouts such as hikes and rides.';
