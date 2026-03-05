-- ============================================================
-- 누가 AI야? RPC 함수
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- 1) create_1v1_game: 1:1 게임 생성 (인간 1 + AI 1)
create or replace function public.create_1v1_game(
  p_session_id    text,
  p_nickname      text,
  p_avatar_shape  text,
  p_avatar_color  text
) returns jsonb
language plpgsql as $$
declare
  v_game_id     uuid;
  v_code        text;
  v_player_id   uuid;
  v_ai_id       uuid;
  v_topic       text;
  v_ai_nickname text;
  v_ai_shape    text;
  v_ai_color    text;
  v_persona_id  text;
  v_adjectives  text[] := array[
    '잠자는','배고픈','신나는','졸린','용감한',
    '수상한','조용한','웃긴','빠른','느긋한',
    '똑똑한','엉뚱한','귀여운','무서운','행복한',
    '심심한','바쁜','한가한','당당한','소심한'
  ];
  v_animals     text[] := array[
    '호랑이','펭귄','고양이','강아지','토끼',
    '여우','곰','판다','햄스터','부엉이',
    '사자','코끼리','돌고래','다람쥐','수달',
    '앵무새','미어캣','카멜레온','너구리','오리'
  ];
  v_shapes      text[] := array['circle','triangle','square','diamond','star'];
  v_colors      text[] := array['#FF4757','#3742FA','#2ED573','#FFA502','#8B5CF6','#FF6B9D','#00D2D3','#FF793F'];
  v_personas    text[] := array['minsu','sujin','jaehyuk','haeun','junho','yuna','donghyun','minji','seojun','chaewon'];
begin
  -- 고유 6자리 코드 생성
  v_code := upper(substr(md5(random()::text), 1, 6));

  -- 랜덤 주제 선택
  select topic_text into v_topic
  from public.chat_topics
  where is_active = true
  order by random() limit 1;

  if v_topic is null then
    v_topic := '자유 대화';
  end if;

  -- 게임 생성
  insert into public.games (code, status, phase, player_count, ai_count, topic)
  values (v_code, 'waiting', 'waiting', 1, 1, v_topic)
  returning id into v_game_id;

  -- 인간 플레이어 삽입
  insert into public.game_players (game_id, session_id, is_ai, nickname, avatar_shape, avatar_color)
  values (v_game_id, p_session_id, false, p_nickname, p_avatar_shape, p_avatar_color)
  returning id into v_player_id;

  -- AI 닉네임 생성 (접두사 + 공백 + 동물)
  v_ai_nickname := v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::int]
                || ' '
                || v_animals[1 + floor(random() * array_length(v_animals, 1))::int];

  -- AI 닉네임이 인간과 같으면 재생성
  while v_ai_nickname = p_nickname loop
    v_ai_nickname := v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::int]
                  || ' '
                  || v_animals[1 + floor(random() * array_length(v_animals, 1))::int];
  end loop;

  -- AI 아바타 (인간과 다른 도형)
  v_ai_shape := v_shapes[1 + floor(random() * array_length(v_shapes, 1))::int];
  v_ai_color := v_colors[1 + floor(random() * array_length(v_colors, 1))::int];
  while v_ai_shape = p_avatar_shape loop
    v_ai_shape := v_shapes[1 + floor(random() * array_length(v_shapes, 1))::int];
  end loop;

  -- 랜덤 페르소나
  v_persona_id := v_personas[1 + floor(random() * array_length(v_personas, 1))::int];

  -- AI 플레이어 삽입
  insert into public.game_players (game_id, is_ai, persona_id, nickname, avatar_shape, avatar_color)
  values (v_game_id, true, v_persona_id, v_ai_nickname, v_ai_shape, v_ai_color)
  returning id into v_ai_id;

  return jsonb_build_object(
    'game_id', v_game_id,
    'code', v_code,
    'player_id', v_player_id,
    'topic', v_topic
  );
end;
$$;

-- 2) advance_phase: 게임 페이즈 전환 (동적 타이머)
create or replace function public.advance_phase(
  p_game_id    uuid,
  p_next_phase text
) returns void
language plpgsql as $$
declare
  v_player_count int;
  v_chat_seconds int;
  v_vote_seconds int;
begin
  -- 인원 기반 동적 타이머
  select player_count into v_player_count from public.games where id = p_game_id;
  v_player_count := coalesce(v_player_count, 1);

  v_chat_seconds := case
    when v_player_count <= 2 then 90
    when v_player_count = 3  then 120
    when v_player_count = 4  then 150
    else 180
  end;
  v_vote_seconds := case
    when v_player_count <= 2 then 15
    when v_player_count = 3  then 20
    when v_player_count = 4  then 25
    else 30
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

-- 3) cast_vote: 투표
create or replace function public.cast_vote(
  p_player_id uuid,
  p_target_id uuid
) returns boolean
language plpgsql as $$
begin
  -- 자신에게 투표 방지
  if p_player_id = p_target_id then
    return false;
  end if;

  update public.game_players
  set voted_for = p_target_id
  where id = p_player_id and voted_for is null;

  return found;
end;
$$;

-- 4) ai_auto_vote: AI 자동 투표 (인간 중 랜덤 지목)
create or replace function public.ai_auto_vote(p_game_id uuid)
returns void
language plpgsql as $$
declare
  v_ai record;
  v_target_id uuid;
begin
  for v_ai in
    select id from public.game_players
    where game_id = p_game_id and is_ai = true and voted_for is null
  loop
    -- AI가 아닌 플레이어 중 랜덤 선택
    select id into v_target_id
    from public.game_players
    where game_id = p_game_id and id != v_ai.id
    order by random() limit 1;

    if v_target_id is not null then
      update public.game_players
      set voted_for = v_target_id
      where id = v_ai.id;
    end if;
  end loop;
end;
$$;

-- 5) calculate_score: 점수 계산
create or replace function public.calculate_score(p_game_id uuid)
returns void
language plpgsql as $$
declare
  v_player record;
  v_target_is_ai boolean;
  v_score int;
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

select 'Game RPC functions created successfully!' as result;
