-- ============================================================
-- 함정 카드 RPC + advance_phase 업데이트
-- ============================================================

-- 1) draw_trap_card: 랜덤 함정 카드 뽑기
create or replace function public.draw_trap_card(
  p_game_id   uuid,
  p_round     int,
  p_asker_id  uuid,
  p_target_id uuid
) returns jsonb
language plpgsql as $$
declare
  v_card    record;
  v_answer_id uuid;
begin
  -- 랜덤 카드 선택
  select id, category, question into v_card
  from public.trap_cards
  where is_active = true
  order by random()
  limit 1;

  if v_card is null then
    return jsonb_build_object('error', 'no cards available');
  end if;

  -- 답변 레코드 생성
  insert into public.game_trap_answers (game_id, round, card_id, asker_id, target_id)
  values (p_game_id, p_round, v_card.id, p_asker_id, p_target_id)
  returning id into v_answer_id;

  return jsonb_build_object(
    'answer_id', v_answer_id,
    'card_id', v_card.id,
    'category', v_card.category,
    'question', v_card.question,
    'asker_id', p_asker_id,
    'target_id', p_target_id
  );
end;
$$;

-- 2) answer_trap_card: 함정 카드 답변
create or replace function public.answer_trap_card(
  p_answer_id uuid,
  p_answer    text
) returns void
language plpgsql as $$
begin
  update public.game_trap_answers
  set answer = p_answer, answered_at = now()
  where id = p_answer_id;
end;
$$;

-- 3) advance_phase 업데이트: 동적 타이머 + trap_question 지원
create or replace function public.advance_phase(
  p_game_id    uuid,
  p_next_phase text
) returns void
language plpgsql as $$
declare
  v_player_count int;
begin
  -- 플레이어 수 조회
  select player_count into v_player_count
  from public.games where id = p_game_id;

  update public.games
  set
    phase = p_next_phase,
    status = case
      when p_next_phase = 'chatting' then 'active'
      when p_next_phase = 'result' then 'finished'
      else status
    end,
    phase_ends_at = case
      when p_next_phase = 'chatting' then now() + (
        case
          when v_player_count <= 2 then interval '90 seconds'
          when v_player_count = 3 then interval '120 seconds'
          when v_player_count = 4 then interval '150 seconds'
          else interval '180 seconds'
        end
      )
      when p_next_phase = 'trap_question' then now() + interval '15 seconds'
      when p_next_phase = 'voting' then now() + (
        case
          when v_player_count <= 2 then interval '15 seconds'
          when v_player_count = 3 then interval '20 seconds'
          when v_player_count = 4 then interval '25 seconds'
          else interval '30 seconds'
        end
      )
      when p_next_phase = 'result' then null
      else null
    end,
    finished_at = case when p_next_phase = 'result' then now() else null end
  where id = p_game_id;
end;
$$;

-- 4) advance_to_next_round: 다음 라운드 진행
create or replace function public.advance_to_next_round(p_game_id uuid)
returns void
language plpgsql as $$
begin
  -- 라운드 증가 + 투표 초기화
  update public.games
  set round = round + 1
  where id = p_game_id;

  update public.game_players
  set voted_for = null, score = 0
  where game_id = p_game_id;
end;
$$;

-- 5) calculate_score 업데이트: 함정 카드 보너스 지원
create or replace function public.calculate_score(p_game_id uuid)
returns void
language plpgsql as $$
declare
  v_player  record;
  v_target_is_ai boolean;
  v_score   int;
  v_has_trap_bonus boolean;
begin
  for v_player in
    select id, voted_for
    from public.game_players
    where game_id = p_game_id and is_ai = false
  loop
    v_score := 0;

    if v_player.voted_for is not null then
      select is_ai into v_target_is_ai
      from public.game_players
      where id = v_player.voted_for;

      if v_target_is_ai then
        v_score := 100;   -- AI 정확 지목

        -- 함정 카드 보너스: 이 플레이어가 카드를 사용해서 AI를 지목했으면 +30
        select exists(
          select 1 from public.game_trap_answers
          where game_id = p_game_id
            and asker_id = v_player.id
            and target_id = v_player.voted_for
            and answer is not null
        ) into v_has_trap_bonus;

        if v_has_trap_bonus then
          v_score := v_score + 30;
        end if;
      else
        v_score := -30;   -- 사람 오지목
      end if;
    else
      v_score := -10;     -- 미투표
    end if;

    update public.game_players
    set score = v_score
    where id = v_player.id;
  end loop;
end;
$$;

select 'Trap card RPCs + updated advance_phase created successfully!' as result;
