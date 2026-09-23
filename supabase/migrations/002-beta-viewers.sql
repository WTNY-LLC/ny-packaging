-- Who sees pages still in progress (tabs marked data-beta) without adding ?beta to the address.
-- Set per person in ny_members.beta; the page asks can_see_beta() after sign-in.
alter table public.ny_members add column if not exists beta boolean not null default false;

create or replace function public.can_see_beta() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select m.beta from auth.users u join public.ny_members m on m.email = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  ), false)
$$;
grant execute on function public.can_see_beta() to authenticated;
