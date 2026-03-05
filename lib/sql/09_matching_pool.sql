-- ============================================================
-- 매칭 풀 테이블
-- ============================================================

create table if not exists public.matching_pool (
  id              uuid primary key default gen_random_uuid(),
  session_id      text not null,
  nickname        text not null,
  avatar_shape    text not null,
  avatar_color    text not null,
  status          text not null default 'waiting',   -- waiting | matched | cancelled | expired
  matched_game_id uuid references public.games(id),
  matched_player_id uuid,
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default (now() + interval '30 seconds')
);

create index if not exists idx_matching_pool_status on public.matching_pool(status);
create index if not exists idx_matching_pool_session on public.matching_pool(session_id);

-- RLS
alter table public.matching_pool enable row level security;
create policy "matching_pool_all" on public.matching_pool
  for all to anon, authenticated using (true) with check (true);

-- Realtime
alter publication supabase_realtime add table public.matching_pool;

select 'Matching pool table created successfully!' as result;
