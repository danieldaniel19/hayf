create extension if not exists pgcrypto with schema extensions;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null,
    birthdate date not null,
    main_city text not null,
    profile_photo_path text,
    profile_photo_url text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

alter table public.profiles enable row level security;

drop policy if exists "Users can read their own profile"
    on public.profiles;
create policy "Users can read their own profile"
    on public.profiles
    for select
    to authenticated
    using (id = auth.uid());

drop policy if exists "Users can insert their own profile"
    on public.profiles;
create policy "Users can insert their own profile"
    on public.profiles
    for insert
    to authenticated
    with check (id = auth.uid());

drop policy if exists "Users can update their own profile"
    on public.profiles;
create policy "Users can update their own profile"
    on public.profiles
    for update
    to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());

insert into storage.buckets (id, name, public)
values ('profile-photos', 'profile-photos', false)
on conflict (id) do nothing;

drop policy if exists "Users can read their own profile photos"
    on storage.objects;
create policy "Users can read their own profile photos"
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users can upload their own profile photos"
    on storage.objects;
create policy "Users can upload their own profile photos"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users can update their own profile photos"
    on storage.objects;
create policy "Users can update their own profile photos"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    )
    with check (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

drop policy if exists "Users can delete their own profile photos"
    on storage.objects;
create policy "Users can delete their own profile photos"
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
