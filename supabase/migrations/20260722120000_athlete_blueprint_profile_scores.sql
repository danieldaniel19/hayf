alter table public.athlete_blueprint_revisions
add column if not exists profile_scores_json jsonb not null default '{}'::jsonb;

alter table public.athlete_blueprint_revisions
add column if not exists profile_score_version text;
