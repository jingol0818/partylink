-- ============================================================
-- PartyLink MVP: 테이블 생성
-- Supabase SQL Editor에서 그대로 실행하세요.
-- ============================================================

-- 1) rooms 테이블: 파티 방 정보
create table if not exists public.rooms (
  id          uuid        primary key default gen_random_uuid(),
  code        text        unique not null,
  game_key    text        not null,
  mode        text        not null,
  goal        text        not null,
  max_members int         not null default 5,
  slots       jsonb       not null,
  require_mic boolean     not null default false,
  status      text        not null default 'open',
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null
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
  last_seen_at timestamptz not null default now()
);

-- 3) 인덱스
create index if not exists idx_rooms_code
  on public.rooms(code);

create index if not exists idx_members_room
  on public.members(room_id);

create index if not exists idx_members_room_state
  on public.members(room_id, state);

create index if not exists idx_members_room_state_role
  on public.members(room_id, state, role);
