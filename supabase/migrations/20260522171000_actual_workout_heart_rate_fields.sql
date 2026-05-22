alter table public.actual_workouts
    add column if not exists average_heart_rate_bpm numeric,
    add column if not exists max_heart_rate_bpm numeric,
    add column if not exists heart_rate_samples_json jsonb not null default '[]'::jsonb;
