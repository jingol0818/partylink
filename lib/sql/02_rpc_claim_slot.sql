-- ============================================================
-- PartyLink MVP: 자리 점유 RPC (원자 처리)
-- Supabase SQL Editor에서 01_tables.sql 실행 후 실행하세요.
--
-- 5단계 검증:
--   1. 방 존재 확인 + 행 잠금 (FOR UPDATE)
--   2. 방 상태 확인 (open + 만료 안 됨)
--   3. 역할 중복 확인
--   4. 인원 초과 확인
--   5. 멤버 유효성 확인 (이 방 소속 + watching 상태)
-- ============================================================

create or replace function public.claim_slot(
  p_room_code text,
  p_member_id uuid,
  p_role      text
)
returns table(ok boolean, message text)
language plpgsql
as $$
declare
  v_room         public.rooms%rowtype;
  v_joined_count int;
  v_updated      int;
begin
  -- [검증 1] 방 조회 + 행 잠금 (동시 요청 시 순차 처리 보장)
  select * into v_room
  from public.rooms
  where code = p_room_code
  for update;

  if not found then
    return query select false, 'ROOM_NOT_FOUND';
    return;
  end if;

  -- [검증 2] 방 상태 확인 (열려있고 만료 안 됨)
  if v_room.status <> 'open' or v_room.expires_at < now() then
    return query select false, 'ROOM_CLOSED';
    return;
  end if;

  -- [검증 3] 역할 중복 확인 (이미 누가 그 역할을 차지했는지)
  if exists (
    select 1 from public.members
    where room_id = v_room.id
      and state   = 'joined'
      and role    = p_role
  ) then
    return query select false, 'ROLE_TAKEN';
    return;
  end if;

  -- [검증 4] 인원 초과 확인
  select count(*) into v_joined_count
  from public.members
  where room_id = v_room.id
    and state   = 'joined';

  if v_joined_count >= v_room.max_members then
    return query select false, 'ROOM_FULL';
    return;
  end if;

  -- [검증 5] 멤버 업데이트
  -- 조건: 이 방 소속(room_id 일치) + watching 상태만 허용
  -- → 다른 방 멤버로 침투 불가
  -- → 이미 joined인 멤버가 역할 변경 불가
  -- → ready를 false로 초기화
  update public.members
  set state        = 'joined',
      role         = p_role,
      ready        = false,
      joined_at    = now(),
      last_seen_at = now()
  where id      = p_member_id
    and room_id = v_room.id
    and state   = 'watching';

  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    return query select false, 'INVALID_MEMBER';
    return;
  end if;

  return query select true, 'OK';
end;
$$;
