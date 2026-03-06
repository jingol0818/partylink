-- ============================================================
-- 매칭 RPC 함수
-- ============================================================

-- 1) join_matching_pool: 매칭 풀 진입
create or replace function public.join_matching_pool(
  p_session_id    text,
  p_nickname      text,
  p_avatar_shape  text,
  p_avatar_color  text
) returns uuid
language plpgsql as $$
declare
  v_pool_id uuid;
begin
  -- 기존 대기 중인 항목이 있으면 취소
  update public.matching_pool
  set status = 'cancelled'
  where session_id = p_session_id and status = 'waiting';

  -- 새 항목 삽입
  insert into public.matching_pool (session_id, nickname, avatar_shape, avatar_color)
  values (p_session_id, p_nickname, p_avatar_shape, p_avatar_color)
  returning id into v_pool_id;

  return v_pool_id;
end;
$$;

-- 2) try_match: 매칭 시도
create or replace function public.try_match(p_pool_id uuid)
returns jsonb
language plpgsql as $$
declare
  v_me              record;
  v_waiting_count   int;
  v_target_count    int;
  v_ai_count        int;
  v_game_id         uuid;
  v_code            text;
  v_topic           text;
  v_player_id       uuid;
  v_other_player_id uuid;
  v_rec             record;
  v_adjectives      text[] := array[
    '잠자는','배고픈','신나는','졸린','용감한',
    '수상한','조용한','웃긴','빠른','느긋한',
    '똑똑한','엉뚱한','귀여운','무서운','행복한',
    '심심한','바쁜','한가한','당당한','소심한'
  ];
  v_animals         text[] := array[
    '호랑이','펭귄','고양이','강아지','토끼',
    '여우','곰','판다','햄스터','부엉이',
    '사자','코끼리','돌고래','다람쥐','수달',
    '앵무새','미어캣','카멜레온','너구리','오리'
  ];
  v_shapes          text[] := array['circle','triangle','square','diamond','star'];
  v_colors          text[] := array['#FF4757','#3742FA','#2ED573','#FFA502','#8B5CF6','#FF6B9D','#00D2D3','#FF793F'];
  v_personas        text[] := array['minsu','sujin','jaehyuk','haeun','junho','yuna','donghyun','minji','seojun','chaewon'];
  v_ai_nickname     text;
  v_ai_shape        text;
  v_ai_color        text;
  v_persona_id      text;
  v_used_nicknames  text[] := '{}';
  v_used_shapes     text[] := '{}';
  i                 int;
begin
  -- 내 정보 조회
  select * into v_me from public.matching_pool
  where id = p_pool_id and status = 'waiting'
  for update skip locked;

  if v_me is null then
    return jsonb_build_object('status', 'not_waiting');
  end if;

  -- 이미 매칭됐는지 확인
  if v_me.status != 'waiting' then
    return jsonb_build_object('status', v_me.status,
      'game_id', v_me.matched_game_id, 'player_id', v_me.matched_player_id);
  end if;

  -- 대기 중인 다른 플레이어 수 (만료되지 않은)
  select count(*) into v_waiting_count
  from public.matching_pool
  where status = 'waiting'
    and id != p_pool_id
    and expires_at > now();

  -- 타임아웃 체크 (10초 경과)
  if v_me.created_at + interval '10 seconds' < now() then
    -- 타임아웃: 현재 모인 인원 + AI로 게임 생성
    if v_waiting_count = 0 then
      v_target_count := 1;
      v_ai_count := 2;  -- 혼자 → AI 2명 = 총 3인 (미션카드 활성화)
    elsif v_waiting_count = 1 then
      v_target_count := 2;
      v_ai_count := 1;
    else
      v_target_count := least(v_waiting_count + 1, 4);
      v_ai_count := 5 - v_target_count;
      if v_ai_count < 1 then v_ai_count := 1; end if;
    end if;
  else
    -- 타임아웃 전: 아직 대기
    return jsonb_build_object('status', 'waiting', 'waiting_count', v_waiting_count + 1);
  end if;

  -- 랜덤 주제 선택
  select topic_text into v_topic
  from public.chat_topics
  where is_active = true
  order by random() limit 1;

  if v_topic is null then
    v_topic := '자유 대화';
  end if;

  -- 고유 코드 생성
  v_code := upper(substr(md5(random()::text), 1, 6));

  -- 게임 생성
  insert into public.games (code, status, phase, player_count, ai_count, topic)
  values (v_code, 'waiting', 'waiting', v_target_count, v_ai_count, v_topic)
  returning id into v_game_id;

  -- 나를 플레이어로 삽입
  insert into public.game_players (game_id, session_id, is_ai, nickname, avatar_shape, avatar_color)
  values (v_game_id, v_me.session_id, false, v_me.nickname, v_me.avatar_shape, v_me.avatar_color)
  returning id into v_player_id;

  v_used_nicknames := array_append(v_used_nicknames, v_me.nickname);
  v_used_shapes := array_append(v_used_shapes, v_me.avatar_shape);

  -- 내 매칭 상태 업데이트
  update public.matching_pool
  set status = 'matched', matched_game_id = v_game_id, matched_player_id = v_player_id
  where id = p_pool_id;

  -- 다른 대기 플레이어들 추가
  if v_target_count > 1 then
    for v_rec in
      select * from public.matching_pool
      where status = 'waiting'
        and id != p_pool_id
        and expires_at > now()
      order by created_at
      limit v_target_count - 1
      for update skip locked
    loop
      insert into public.game_players (game_id, session_id, is_ai, nickname, avatar_shape, avatar_color)
      values (v_game_id, v_rec.session_id, false, v_rec.nickname, v_rec.avatar_shape, v_rec.avatar_color)
      returning id into v_other_player_id;

      update public.matching_pool
      set status = 'matched', matched_game_id = v_game_id, matched_player_id = v_other_player_id
      where id = v_rec.id;

      v_used_nicknames := array_append(v_used_nicknames, v_rec.nickname);
      v_used_shapes := array_append(v_used_shapes, v_rec.avatar_shape);
    end loop;
  end if;

  -- AI 플레이어 생성
  for i in 1..v_ai_count loop
    -- AI 닉네임 (중복 방지)
    loop
      v_ai_nickname := v_adjectives[1 + floor(random() * array_length(v_adjectives, 1))::int]
                    || v_animals[1 + floor(random() * array_length(v_animals, 1))::int];
      exit when not (v_ai_nickname = any(v_used_nicknames));
    end loop;
    v_used_nicknames := array_append(v_used_nicknames, v_ai_nickname);

    -- AI 아바타 (도형 중복 방지)
    loop
      v_ai_shape := v_shapes[1 + floor(random() * array_length(v_shapes, 1))::int];
      exit when not (v_ai_shape = any(v_used_shapes));
    end loop;
    v_used_shapes := array_append(v_used_shapes, v_ai_shape);

    v_ai_color := v_colors[1 + floor(random() * array_length(v_colors, 1))::int];
    v_persona_id := v_personas[1 + floor(random() * array_length(v_personas, 1))::int];

    insert into public.game_players (game_id, is_ai, persona_id, nickname, avatar_shape, avatar_color)
    values (v_game_id, true, v_persona_id, v_ai_nickname, v_ai_shape, v_ai_color);
  end loop;

  return jsonb_build_object(
    'status', 'matched',
    'game_id', v_game_id,
    'code', v_code,
    'player_id', v_player_id,
    'topic', v_topic
  );
end;
$$;

-- 3) cancel_match: 매칭 취소
create or replace function public.cancel_match(p_pool_id uuid)
returns void
language plpgsql as $$
begin
  update public.matching_pool
  set status = 'cancelled'
  where id = p_pool_id and status = 'waiting';
end;
$$;

select 'Matching RPC functions created successfully!' as result;
