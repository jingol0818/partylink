-- ============================================================
-- PartyLink MVP: 테이블 생성
-- Supabase SQL Editor에서 그대로 실행하세요.
-- ============================================================

-- 1) rooms 테이블: 파티 방 정보
create table if not exists public.rooms (
  id                uuid        primary key default gen_random_uuid(),
  code              text        unique not null,
  game_key          text        not null,
  mode              text,  -- nullable로 변경 (종합게임은 모드 없음)
  goal              text        not null,
  max_members       int         not null default 5,
  slots             jsonb       not null,
  require_mic       boolean     not null default false,
  status            text        not null default 'open',
  created_at        timestamptz not null default now(),
  expires_at        timestamptz not null,

  -- 신규 필드
  room_name         text,  -- 방 이름 (최대 20자)
  team_count        int         not null default 1,  -- 팀 수
  members_per_team  int         not null default 5,  -- 팀당 인원
  custom_slot_names jsonb,  -- 커스텀 슬롯명 배열
  host_session_id   text  -- 방장 세션 ID
);

-- 2) members 테이블: 파티 멤버 정보
create table if not exists public.members (
  id           uuid        primary key default gen_random_uuid(),
  room_id      uuid        not null references public.rooms(id) on delete cascade,
  display_name text        not null,
  tag          text,
  role         text,
  state        text        not null default 'watching',
  ready        boolean     not null default false,
  joined_at    timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),

  -- 신규 필드
  invite_id    text,  -- 게임ID/배틀태그 등 초대 방법
  session_id   text   -- 세션 ID (방장 확인용)
);

-- 3) 인덱스
create index if not exists idx_rooms_code
  on public.rooms(code);

create index if not exists idx_rooms_room_name
  on public.rooms(room_name);

create index if not exists idx_members_room
  on public.members(room_id);

create index if not exists idx_members_room_state
  on public.members(room_id, state);

create index if not exists idx_members_room_state_role
  on public.members(room_id, state, role);

create index if not exists idx_members_session
  on public.members(session_id);
