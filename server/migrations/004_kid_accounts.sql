-- Kid accounts (players under 13, from the app's age screen): guest-only, nickname from
-- a fixed list, friends by invite code only (no matchmaking with strangers).
alter table public.profiles add column if not exists kid boolean not null default false;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, is_guest, kid)
  values (new.id,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), nullif(new.raw_user_meta_data->>'given_name', ''), 'Player'), 24),
          coalesce(new.is_anonymous, false),
          coalesce(new.is_anonymous, false) and coalesce((new.raw_user_meta_data->>'kid')::boolean, false))
  on conflict (id) do nothing;
  return new;
end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
