-- War and Piece: online games, on the shared "youreacard" Supabase project.
-- Its own tables (wp_*), so Gem Heist's games, invites and matchmaking are untouched.
-- Accounts and profiles (public.profiles) are shared with Gem Heist.

create table public.wp_games (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'active' check (status in ('active', 'finished', 'abandoned')),
  seat0 uuid references auth.users(id) on delete set null,
  seat1 uuid references auth.users(id) on delete set null,
  state jsonb not null,
  current_seat int not null default 2,   -- 2: either player can move (War, or both arranging)
  winner int not null default -1,
  move_count int not null default 0,
  via text not null default 'invite' check (via in ('invite', 'match')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index wp_games_seat0_idx on public.wp_games (seat0);
create index wp_games_seat1_idx on public.wp_games (seat1);

create table public.wp_moves (
  game_id uuid not null references public.wp_games(id) on delete cascade,
  seq int not null,
  seat int not null,
  move jsonb not null,
  created_at timestamptz not null default now(),
  primary key (game_id, seq)
);

create table public.wp_invites (
  code text primary key,
  host uuid not null references auth.users(id) on delete cascade,
  guest uuid references auth.users(id) on delete cascade,
  guest_name text,
  status text not null default 'open' check (status in ('open', 'pending', 'accepted', 'declined', 'expired')),
  game_id uuid references public.wp_games(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);
create index wp_invites_host_idx on public.wp_invites (host);
create index wp_invites_guest_idx on public.wp_invites (guest);
create index wp_invites_game_idx on public.wp_invites (game_id);

create table public.wp_match_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now()
);

-- Server only: the war-and-piece function uses the service role; no client policies.
alter table public.wp_games enable row level security;
alter table public.wp_moves enable row level security;
alter table public.wp_invites enable row level security;
alter table public.wp_match_queue enable row level security;

create or replace function public.take_wp_match(me uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare other uuid;
begin
  select user_id into other from public.wp_match_queue
   where user_id <> me order by joined_at limit 1 for update skip locked;
  if other is null then
    insert into public.wp_match_queue (user_id) values (me) on conflict (user_id) do nothing;
    return null;
  end if;
  delete from public.wp_match_queue where user_id in (me, other);
  return other;
end $$;
revoke execute on function public.take_wp_match(uuid) from public, anon, authenticated;
