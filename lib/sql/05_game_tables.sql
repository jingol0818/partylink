-- ============================================================
-- 누가 AI야? 게임 테이블
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- 1) games: 게임 세션
create table if not exists public.games (
  id             uuid        primary key default gen_random_uuid(),
  code           text        unique not null,
  status         text        not null default 'waiting',   -- waiting | active | finished
  phase          text        not null default 'waiting',   -- waiting | chatting | trap_question | voting | result
  round          int         not null default 1,
  player_count   int         not null default 1,
  ai_count       int         not null default 1,
  topic          text,
  phase_ends_at  timestamptz,
  created_at     timestamptz not null default now(),
  finished_at    timestamptz
);

-- 2) game_players: 게임 참가자 (인간 + AI)
create table if not exists public.game_players (
  id             uuid        primary key default gen_random_uuid(),
  game_id        uuid        not null references public.games(id) on delete cascade,
  session_id     text,                                     -- null for AI players
  is_ai          boolean     not null default false,
  persona_id     text,                                     -- AI persona identifier (minsu, sujin, etc.)
  nickname       text        not null,
  avatar_shape   text        not null,                     -- circle | triangle | square | diamond | star
  avatar_color   text        not null,                     -- hex color
  voted_for      uuid        references public.game_players(id),
  score          int         not null default 0,
  is_connected   boolean     not null default true,
  created_at     timestamptz not null default now()
);

-- 3) game_chat_messages: 게임 채팅 메시지
create table if not exists public.game_chat_messages (
  id             uuid        primary key default gen_random_uuid(),
  game_id        uuid        not null references public.games(id) on delete cascade,
  sender_id      uuid        references public.game_players(id),  -- null for GM
  sender_type    text        not null default 'player',    -- player | ai | gm
  nickname       text        not null,
  content        text        not null,
  round          int         not null default 1,
  created_at     timestamptz not null default now()
);

-- 4) chat_topics: 대화 주제
create table if not exists public.chat_topics (
  id             uuid        primary key default gen_random_uuid(),
  category       text        not null,                     -- daily | taste | choice | situation | experience
  topic_text     text        not null,
  is_active      boolean     not null default true
);

-- 5) 인덱스
create index if not exists idx_games_code on public.games(code);
create index if not exists idx_games_status on public.games(status);
create index if not exists idx_game_players_game on public.game_players(game_id);
create index if not exists idx_game_players_session on public.game_players(session_id);
create index if not exists idx_game_chat_game on public.game_chat_messages(game_id);
create index if not exists idx_game_chat_game_round on public.game_chat_messages(game_id, round);

-- Realtime 활성화
alter publication supabase_realtime add table public.games;
alter publication supabase_realtime add table public.game_players;
alter publication supabase_realtime add table public.game_chat_messages;

select 'Game tables created successfully!' as result;
