-- ============================================================
-- 누가 AI야? RLS 정책 + 보안 VIEW
-- is_ai 필드를 result phase 전까지 숨기는 것이 핵심
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- 1) RLS 활성화
alter table public.games enable row level security;
alter table public.game_players enable row level security;
alter table public.game_chat_messages enable row level security;
alter table public.chat_topics enable row level security;

-- 2) games 정책 (MVP: 전체 허용)
create policy "games_select" on public.games for select to anon, authenticated using (true);
create policy "games_insert" on public.games for insert to anon, authenticated with check (true);
create policy "games_update" on public.games for update to anon, authenticated using (true) with check (true);

-- 3) game_players 정책 (MVP: 전체 허용, is_ai 보호는 VIEW로)
create policy "game_players_select" on public.game_players for select to anon, authenticated using (true);
create policy "game_players_insert" on public.game_players for insert to anon, authenticated with check (true);
create policy "game_players_update" on public.game_players for update to anon, authenticated using (true) with check (true);

-- 4) game_chat_messages 정책
create policy "game_chat_select" on public.game_chat_messages for select to anon, authenticated using (true);
create policy "game_chat_insert" on public.game_chat_messages for insert to anon, authenticated with check (true);

-- 5) chat_topics 정책 (읽기 전용)
create policy "topics_select" on public.chat_topics for select to anon, authenticated using (true);

-- ============================================================
-- 보안 VIEW: is_ai & sender_type 마스킹
-- 클라이언트는 이 VIEW를 통해 데이터를 조회합니다.
-- ============================================================

-- 6) game_players_safe: is_ai를 result phase에서만 공개
create or replace view public.game_players_safe as
select
  gp.id,
  gp.game_id,
  gp.session_id,
  case when g.phase = 'result' then gp.is_ai else null end as is_ai,
  gp.persona_id,
  gp.nickname,
  gp.avatar_shape,
  gp.avatar_color,
  gp.voted_for,
  gp.score,
  gp.is_connected,
  gp.created_at
from public.game_players gp
join public.games g on g.id = gp.game_id;

-- 7) game_chat_messages_safe: sender_type을 result phase에서만 공개
create or replace view public.game_chat_messages_safe as
select
  cm.id,
  cm.game_id,
  cm.sender_id,
  case
    when g.phase = 'result' then cm.sender_type
    when cm.sender_type = 'gm' then 'gm'
    else 'player'
  end as sender_type,
  cm.nickname,
  cm.content,
  cm.round,
  cm.created_at
from public.game_chat_messages cm
join public.games g on g.id = cm.game_id;

select 'RLS policies and secure views created successfully!' as result;
