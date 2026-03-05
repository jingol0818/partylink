-- ============================================================
-- 누가 AI야? 대화 주제 시드 데이터
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================

insert into public.chat_topics (category, topic_text, is_active) values
-- 일상 (daily)
('daily', '오늘 뭐 했어?', true),
('daily', '아침에 일어나서 제일 먼저 하는 거?', true),
('daily', '요즘 자주 듣는 노래 있어?', true),
('daily', '주말에 보통 뭐 해?', true),
('daily', '어젯밤에 뭐 했어?', true),
('daily', '요즘 빠진 취미 있어?', true),

-- 취향 (taste)
('taste', '좋아하는 음식이 뭐야?', true),
('taste', '영화 vs 드라마 뭐가 좋아?', true),
('taste', '강아지 vs 고양이?', true),
('taste', '여름이 좋아 겨울이 좋아?', true),
('taste', '최근에 본 유튜브 영상 추천해줘', true),
('taste', '제일 좋아하는 간식이 뭐야?', true),

-- 선택 (choice)
('choice', '로또 당첨되면 제일 먼저 뭐 할 거야?', true),
('choice', '시간 여행 가능하면 과거 vs 미래?', true),
('choice', '무인도에 하나만 가져간다면?', true),
('choice', '갑자기 1억 생기면 뭐 할 거야?', true),
('choice', '초능력 하나 고른다면?', true),
('choice', '하루만 투명인간 된다면 뭐 할래?', true),

-- 상황 (situation)
('situation', '카페에서 주문 실수 당하면 어떻게 해?', true),
('situation', '길에서 아는 사람 마주치면 먼저 인사해?', true),
('situation', '친구가 약속에 1시간 늦으면?', true),
('situation', '처음 보는 사람이랑 엘리베이터에 둘이 타면 뭐 해?', true),
('situation', '배달 음식이 잘못 왔을 때 어떻게 해?', true),
('situation', '밤에 갑자기 배고프면 어떻게 해?', true),

-- 경험 (experience)
('experience', '가장 기억에 남는 여행지는?', true),
('experience', '인생에서 가장 창피했던 순간은?', true),
('experience', '제일 맛있게 먹었던 음식은?', true),
('experience', '최근에 가장 웃겼던 일은?', true),
('experience', '가장 오래 해본 취미는 뭐야?', true),
('experience', '학교 다닐 때 제일 좋아했던 과목은?', true);

select count(*) || ' topics seeded!' as result from public.chat_topics;
