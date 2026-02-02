-- ============================================================
-- PartyLink v2 마이그레이션: 신규 컬럼 추가
-- 기존 테이블에 새 컬럼을 추가합니다.
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

-- 1) rooms 테이블에 신규 컬럼 추가
ALTER TABLE public.rooms
  ADD COLUMN IF NOT EXISTS room_name text,
  ADD COLUMN IF NOT EXISTS team_count int NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS members_per_team int NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS custom_slot_names jsonb,
  ADD COLUMN IF NOT EXISTS host_session_id text;

-- mode 컬럼을 nullable로 변경 (종합게임은 모드 없음)
ALTER TABLE public.rooms
  ALTER COLUMN mode DROP NOT NULL;

-- 2) members 테이블에 신규 컬럼 추가
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS invite_id text,
  ADD COLUMN IF NOT EXISTS session_id text;

-- 3) 신규 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_rooms_room_name
  ON public.rooms(room_name);

CREATE INDEX IF NOT EXISTS idx_members_session
  ON public.members(session_id);

-- 4) 기존 데이터 마이그레이션 (기본값 설정)
-- 기존 방들의 team_count, members_per_team을 슬롯 수에 맞게 설정
UPDATE public.rooms
SET team_count = 1,
    members_per_team = max_members
WHERE team_count IS NULL OR members_per_team IS NULL;

-- 완료 메시지
SELECT 'Migration v2 completed successfully!' as result;
