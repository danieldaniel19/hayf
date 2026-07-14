create table if not exists public.planning_generation_leases (
    user_id uuid not null references auth.users(id) on delete cascade,
    lock_key text not null,
    expires_at timestamptz not null,
    created_at timestamptz not null default now(),
    primary key (user_id, lock_key)
);

alter table public.planning_generation_leases enable row level security;

create or replace function public.acquire_planning_generation_lease(
    p_user_id uuid,
    p_lock_key text,
    p_lease_seconds integer default 600
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
    acquired boolean;
begin
    insert into public.planning_generation_leases (user_id, lock_key, expires_at)
    values (p_user_id, p_lock_key, now() + make_interval(secs => greatest(30, p_lease_seconds)))
    on conflict (user_id, lock_key) do update
    set expires_at = excluded.expires_at,
        created_at = now()
    where public.planning_generation_leases.expires_at <= now()
    returning true into acquired;

    return coalesce(acquired, false);
end;
$$;

create or replace function public.release_planning_generation_lease(
    p_user_id uuid,
    p_lock_key text
)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.planning_generation_leases
    where user_id = p_user_id
      and lock_key = p_lock_key;
$$;

revoke all on function public.acquire_planning_generation_lease(uuid, text, integer) from public;
revoke all on function public.release_planning_generation_lease(uuid, text) from public;
grant execute on function public.acquire_planning_generation_lease(uuid, text, integer) to service_role;
grant execute on function public.release_planning_generation_lease(uuid, text) to service_role;
