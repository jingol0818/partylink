-- ============================================================
-- 함정 카드 테이블
-- ============================================================

create table if not exists public.trap_cards (
  id          uuid primary key default gen_random_uuid(),
  category    text not null,    -- context | speed | memory | emotion | logic
  question    text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create index if not exists idx_trap_cards_category on public.trap_cards(category);

-- 게임 내 함정 카드 답변 기록
create table if not exists public.game_trap_answers (
  id            uuid primary key default gen_random_uuid(),
  game_id       uuid not null references public.games(id) on delete cascade,
  round         int not null default 1,
  card_id       uuid not null references public.trap_cards(id),
  asker_id      uuid not null references public.game_players(id),
  target_id     uuid not null references public.game_players(id),
  answer        text,
  answered_at   timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists idx_trap_answers_game on public.game_trap_answers(game_id);

-- RLS
alter table public.trap_cards enable row level security;
alter table public.game_trap_answers enable row level security;

create policy "trap_cards_select" on public.trap_cards
  for select to anon, authenticated using (true);

create policy "trap_answers_all" on public.game_trap_answers
  for all to anon, authenticated using (true) with check (true);

-- Realtime
alter publication supabase_realtime add table public.game_trap_answers;

select 'Trap card tables created successfully!' as result;
