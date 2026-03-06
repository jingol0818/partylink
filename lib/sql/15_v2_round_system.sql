-- ============================================================
-- v2.0 라운드 시스템 SQL 마이그레이션
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- 1) advance_phase 업데이트: 라운드 기반 타이머
-- R1: 채팅 90초, 투표 20초 (중간투표)
-- R2: 채팅 60초, 미션 15초 (투표 없음)
-- R3: 채팅 45초, 투표 30초 (최종투표)
create or replace function public.advance_phase(
  p_game_id    uuid,
  p_next_phase text
) returns void
language plpgsql as $$
declare
  v_game record;
  v_chat_seconds int;
  v_vote_seconds int;
begin
  -- 게임 정보 조회 (라운드 포함)
  select * into v_game from public.games where id = p_game_id;

  -- 라운드 기반 채팅 시간
  v_chat_seconds := case
    when v_game.round = 1 then 90   -- R1: 탐색
    when v_game.round = 2 then 60   -- R2: 반론
    when v_game.round >= 3 then 45  -- R3: 최종 심판
    else 90
  end;

  -- 라운드 기반 투표 시간
  v_vote_seconds := case
    when v_game.round = 1 then 20   -- 중간투표
    when v_game.round >= 3 then 30  -- 최종투표
    else 20
  end;

  update public.games
  set
    phase = p_next_phase,
    status = case
      when p_next_phase = 'chatting' then 'active'
      when p_next_phase = 'result' then 'finished'
      else status
    end,
    phase_ends_at = case
      when p_next_phase = 'chatting'      then now() + (v_chat_seconds || ' seconds')::interval
      when p_next_phase = 'voting'        then now() + (v_vote_seconds || ' seconds')::interval
      when p_next_phase = 'trap_question' then now() + interval '15 seconds'
      when p_next_phase = 'result'        then null
      else null
    end,
    finished_at = case when p_next_phase = 'result' then now() else null end
  where id = p_game_id;
end;
$$;

-- 2) advance_to_next_round: 라운드 전환 + 투표 리셋
create or replace function public.advance_to_next_round(p_game_id uuid)
returns void
language plpgsql as $$
begin
  -- 라운드 증가
  update public.games
  set round = round + 1
  where id = p_game_id;

  -- 모든 플레이어의 투표 리셋 (중간투표 후 다음 라운드를 위해)
  update public.game_players
  set voted_for = null
  where game_id = p_game_id;
end;
$$;

-- 3) try_match 업데이트: 솔로 매칭 시 AI 2명 (총 3인)
-- (이미 실행됨 - 확인용)
-- v_ai_count := 2 for solo

select 'v2.0 Round System SQL applied successfully!' as result;
