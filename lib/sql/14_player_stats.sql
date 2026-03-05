-- ============================================================
-- 플레이어 통계 + 리더보드
-- ============================================================

create table if not exists public.player_stats (
  id            uuid primary key default gen_random_uuid(),
  session_id    text unique not null,
  display_name  text not null,
  total_games   int not null default 0,
  total_wins    int not null default 0,
  total_score   int not null default 0,
  win_streak    int not null default 0,
  best_streak   int not null default 0,
  updated_at    timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists idx_player_stats_score on public.player_stats(total_score desc);
create index if not exists idx_player_stats_session on public.player_stats(session_id);

-- RLS
alter table public.player_stats enable row level security;
create policy "player_stats_select" on public.player_stats
  for select to anon, authenticated using (true);
create policy "player_stats_upsert" on public.player_stats
  for all to anon, authenticated using (true) with check (true);

-- update_player_stats: 게임 종료 후 통계 업데이트
create or replace function public.update_player_stats(
  p_session_id   text,
  p_display_name text,
  p_score        int,
  p_won          boolean
) returns void
language plpgsql as $$
begin
  insert into public.player_stats (session_id, display_name, total_games, total_wins, total_score, win_streak, best_streak)
  values (
    p_session_id, p_display_name, 1,
    case when p_won then 1 else 0 end,
    greatest(p_score, 0),
    case when p_won then 1 else 0 end,
    case when p_won then 1 else 0 end
  )
  on conflict (session_id) do update set
    display_name = p_display_name,
    total_games = player_stats.total_games + 1,
    total_wins = player_stats.total_wins + case when p_won then 1 else 0 end,
    total_score = player_stats.total_score + greatest(p_score, 0),
    win_streak = case when p_won then player_stats.win_streak + 1 else 0 end,
    best_streak = greatest(
      player_stats.best_streak,
      case when p_won then player_stats.win_streak + 1 else player_stats.best_streak end
    ),
    updated_at = now();
end;
$$;

-- get_leaderboard: 상위 50명
create or replace function public.get_leaderboard()
returns table(
  rank bigint,
  display_name text,
  total_games int,
  total_wins int,
  total_score int,
  best_streak int
)
language sql stable as $$
  select
    row_number() over (order by total_score desc) as rank,
    display_name,
    total_games,
    total_wins,
    total_score,
    best_streak
  from public.player_stats
  where total_games > 0
  order by total_score desc
  limit 50;
$$;

select 'Player stats tables and RPCs created successfully!' as result;
