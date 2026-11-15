create table public.auth_relay (
  lid text primary key check (char_length(lid) between 16 and 64),
  code text not null,
  created_at timestamptz not null default now()
);
alter table public.auth_relay enable row level security;
