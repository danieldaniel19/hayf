alter table public.planned_workouts
add column if not exists estimated_distance_kilometers numeric,
add column if not exists planned_location_label text,
add column if not exists weather_forecast_json jsonb not null default '{}'::jsonb;

comment on column public.planned_workouts.estimated_distance_kilometers is
    'Approximate planned workout distance in kilometers for distance-based modalities.';

comment on column public.planned_workouts.planned_location_label is
    'Human-readable planned workout location. Defaults to the user home city until travel editing exists.';

comment on column public.planned_workouts.weather_forecast_json is
    'Compact forecast payload for the workout card. Mocked until a weather provider is integrated.';
