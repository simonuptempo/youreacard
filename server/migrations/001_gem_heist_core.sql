-- You're a Card / Gem Heist: database setup.
-- Paste all of this into Supabase > youreacard project > SQL Editor > New query, then click Run.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Player' check (char_length(display_name) between 1 and 24),
  avatar jsonb not null default '{}'::jsonb,
  is_guest boolean not null default false,
  beaten jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  game_type text not null default 'gem_heist',
  status text not null default 'active' check (status in ('active', 'finished', 'abandoned')),
  seat0 uuid references auth.users(id) on delete set null,
  seat1 uuid references auth.users(id) on delete set null,
  state jsonb not null,
  current_seat int not null default 0,
  winner int not null default -1,
  move_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index games_seat0_idx on public.games (seat0);
create index games_seat1_idx on public.games (seat1);

create table public.game_moves (
  game_id uuid not null references public.games(id) on delete cascade,
  seq int not null,
  seat int not null,
  move jsonb not null,
  view0 jsonb not null,
  view1 jsonb not null,
  created_at timestamptz not null default now(),
  primary key (game_id, seq)
);

create table public.invites (
  code text primary key,
  host uuid not null references auth.users(id) on delete cascade,
  guest uuid references auth.users(id) on delete cascade,
  guest_name text,
  status text not null default 'open' check (status in ('open', 'pending', 'accepted', 'declined', 'expired')),
  game_id uuid references public.games(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);
create index invites_host_idx on public.invites (host);
create index invites_guest_idx on public.invites (guest);
create index invites_game_idx on public.invites (game_id);

create table public.match_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.games enable row level security;
alter table public.game_moves enable row level security;
alter table public.invites enable row level security;
alter table public.match_queue enable row level security;

create policy "read own profile" on public.profiles for select to authenticated using ((select auth.uid()) = id);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, is_guest)
  values (new.id,
          left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), nullif(new.raw_user_meta_data->>'given_name', ''), 'Player'), 24),
          coalesce(new.is_anonymous, false))
  on conflict (id) do nothing;
  return new;
end $$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.take_match(me uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare other uuid;
begin
  select user_id into other from public.match_queue
   where user_id <> me order by joined_at limit 1 for update skip locked;
  if other is null then
    insert into public.match_queue (user_id) values (me) on conflict (user_id) do nothing;
    return null;
  end if;
  delete from public.match_queue where user_id in (me, other);
  return other;
end $$;
revoke execute on function public.take_match(uuid) from public, anon, authenticated;
