-- Daily counts for the photo-to-cartoon feature, so costs stay predictable.
-- Only counts are stored: never photos.
create table if not exists public.cartoon_usage (
  day date not null default current_date,
  device text not null,
  count int not null default 0,
  primary key (day, device)
);
alter table public.cartoon_usage enable row level security;  -- no policies: server only

-- Adds one use for this device today; returns today's count for the device and overall.
create or replace function public.bump_cartoon_usage(p_device text)
returns table(device_count int, total int)
language plpgsql security definer set search_path = public as $$
begin
  insert into cartoon_usage(day, device, count) values (current_date, p_device, 1)
  on conflict (day, device) do update set count = cartoon_usage.count + 1;
  return query
    select (select c.count from cartoon_usage c where c.day = current_date and c.device = p_device),
           (select coalesce(sum(c.count), 0)::int from cartoon_usage c where c.day = current_date);
end $$;
revoke all on function public.bump_cartoon_usage(text) from public, anon, authenticated;
