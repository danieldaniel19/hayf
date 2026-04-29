create extension if not exists pgcrypto with schema extensions;

create table if not exists public.onboarding_profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    intent text not null check (intent in ('stayConsistent', 'concreteGoal', 'findGoal')),
    selected_answers jsonb not null default '{}'::jsonb,
    generated_summary jsonb not null default '{}'::jsonb,
    first_rhythm jsonb not null default '{}'::jsonb,
    health_permission_state text not null default 'not_requested',
    completed_at timestamptz not null default now(),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.onboarding_ai_generations (
    id uuid primary key default extensions.gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    task text not null check (
        task in (
            'generate_summary',
            'generate_first_rhythm',
            'generate_goal_candidates',
            'generate_blended_candidate'
        )
    ),
    model text not null,
    compact_request jsonb not null default '{}'::jsonb,
    structured_response jsonb,
    status text not null check (status in ('success', 'failure')),
    latency_ms integer,
    error_message text,
    created_at timestamptz not null default now()
);

create index if not exists onboarding_profiles_completed_at_idx
    on public.onboarding_profiles (completed_at desc);

create index if not exists onboarding_ai_generations_user_created_at_idx
    on public.onboarding_ai_generations (user_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists set_onboarding_profiles_updated_at on public.onboarding_profiles;
create trigger set_onboarding_profiles_updated_at
before update on public.onboarding_profiles
for each row
execute function public.set_updated_at();

alter table public.onboarding_profiles enable row level security;
alter table public.onboarding_ai_generations enable row level security;

drop policy if exists "Users can read their own onboarding profile"
    on public.onboarding_profiles;
create policy "Users can read their own onboarding profile"
    on public.onboarding_profiles
    for select
    to authenticated
    using (id = auth.uid());

drop policy if exists "Users can insert their own onboarding profile"
    on public.onboarding_profiles;
create policy "Users can insert their own onboarding profile"
    on public.onboarding_profiles
    for insert
    to authenticated
    with check (id = auth.uid());

drop policy if exists "Users can update their own onboarding profile"
    on public.onboarding_profiles;
create policy "Users can update their own onboarding profile"
    on public.onboarding_profiles
    for update
    to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());

drop policy if exists "Users can delete their own onboarding profile"
    on public.onboarding_profiles;
create policy "Users can delete their own onboarding profile"
    on public.onboarding_profiles
    for delete
    to authenticated
    using (id = auth.uid());
