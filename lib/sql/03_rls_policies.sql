-- ============================================================
-- PartyLink MVP: RLS 정책 (관대한 MVP용)
-- Supabase SQL Editor에서 01, 02 실행 후 실행하세요.
--
-- ⚠️ 이 정책은 "로그인 없는 MVP"를 위한 전체 허용 정책입니다.
--    공개 서비스로 전환 시 반드시 보안을 강화해야 합니다.
--
-- 강화 계획:
--   1단계) 방장/멤버 secret 토큰 추가
--   2단계) Supabase Auth 도입 + 사용자별 정책
-- ============================================================

-- 1) RLS 활성화
alter table public.rooms   enable row level security;
alter table public.members enable row level security;

-- 2) 기존 정책 정리 (없으면 무시됨)
drop policy if exists "rooms_select_all"   on public.rooms;
drop policy if exists "rooms_insert_all"   on public.rooms;
drop policy if exists "rooms_update_all"   on public.rooms;
drop policy if exists "rooms_delete_all"   on public.rooms;

drop policy if exists "members_select_all" on public.members;
drop policy if exists "members_insert_all" on public.members;
drop policy if exists "members_update_all" on public.members;
drop policy if exists "members_delete_all" on public.members;

-- 3) rooms 정책: 전체 허용
create policy "rooms_select_all"
  on public.rooms for select
  to public using (true);

create policy "rooms_insert_all"
  on public.rooms for insert
  to public with check (true);

create policy "rooms_update_all"
  on public.rooms for update
  to public using (true) with check (true);

create policy "rooms_delete_all"
  on public.rooms for delete
  to public using (true);

-- 4) members 정책: 전체 허용
create policy "members_select_all"
  on public.members for select
  to public using (true);

create policy "members_insert_all"
  on public.members for insert
  to public with check (true);

create policy "members_update_all"
  on public.members for update
  to public using (true) with check (true);

create policy "members_delete_all"
  on public.members for delete
  to public using (true);
