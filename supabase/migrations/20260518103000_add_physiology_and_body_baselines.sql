alter table public.profiles
    add column if not exists physiology_reference text;

alter table public.profiles
    drop constraint if exists profiles_physiology_reference_check;

alter table public.profiles
    add constraint profiles_physiology_reference_check
    check (physiology_reference in ('male', 'female'));

comment on column public.profiles.physiology_reference is
    'Nullable for legacy rows until the user next reviews account setup; required by the app for new or edited profiles.';

create table if not exists public.body_measurements (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    measured_at timestamptz not null,
    source text not null check (source in ('onboarding_self_report', 'healthkit')),
    height_centimeters numeric,
    body_mass_kilograms numeric,
    body_fat_band text,
    body_fat_estimate_midpoint numeric,
    confidence text not null check (confidence in ('estimated_band', 'measured')),
    created_at timestamptz not null default now()
);

create index if not exists body_measurements_user_measured_at_idx
    on public.body_measurements (user_id, measured_at desc);

alter table public.body_measurements enable row level security;

drop policy if exists "Users can read their own body measurements"
    on public.body_measurements;
create policy "Users can read their own body measurements"
    on public.body_measurements
    for select
    to authenticated
    using (user_id = auth.uid());

drop policy if exists "Users can insert their own body measurements"
    on public.body_measurements;
create policy "Users can insert their own body measurements"
    on public.body_measurements
    for insert
    to authenticated
    with check (user_id = auth.uid());
