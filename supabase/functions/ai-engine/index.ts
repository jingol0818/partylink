// 누가 AI야? - AI Engine Edge Function
// AI 플레이어의 채팅 응답을 생성합니다.
// 지원 프로바이더: anthropic (Claude), groq, openrouter, together

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ============================================================
// 멀티 프로바이더 설정
// ============================================================
const LLM_PROVIDER = Deno.env.get('LLM_PROVIDER') || 'anthropic'

interface ProviderConfig {
  baseUrl: string
  apiKey: string
  defaultModel: string
  isAnthropic?: boolean  // Anthropic API는 OpenAI와 형식이 다름
}

const PROVIDERS: Record<string, ProviderConfig> = {
  anthropic: {
    baseUrl: 'https://api.anthropic.com/v1',
    apiKey: Deno.env.get('ANTHROPIC_API_KEY') || '',
    defaultModel: 'claude-sonnet-4-20250514',
    isAnthropic: true,
  },
  groq: {
    baseUrl: 'https://api.groq.com/openai/v1',
    apiKey: Deno.env.get('GROQ_API_KEY') || Deno.env.get('LLM_API_KEY') || '',
    defaultModel: 'llama-3.3-70b-versatile',
  },
  openrouter: {
    baseUrl: 'https://openrouter.ai/api/v1',
    apiKey: Deno.env.get('OPENROUTER_API_KEY') || '',
    defaultModel: 'qwen/qwen3.5-plus-02-15',
  },
  together: {
    baseUrl: 'https://api.together.xyz/v1',
    apiKey: Deno.env.get('TOGETHER_API_KEY') || '',
    defaultModel: 'Qwen/Qwen3.5-32B',
  },
}

const RANDOM_PROVIDER = Deno.env.get('RANDOM_PROVIDER') === 'true'

function getProvider(): { baseUrl: string; apiKey: string; model: string; name: string; isAnthropic: boolean } {
  if (RANDOM_PROVIDER) {
    const available = Object.entries(PROVIDERS).filter(([_, p]) => p.apiKey)
    if (available.length === 0) {
      const p = PROVIDERS.anthropic
      return { ...p, model: p.defaultModel, name: 'anthropic', isAnthropic: true }
    }
    const [name, provider] = available[Math.floor(Math.random() * available.length)]
    const model = Deno.env.get(`${name.toUpperCase()}_MODEL`) || provider.defaultModel
    return { baseUrl: provider.baseUrl, apiKey: provider.apiKey, model, name, isAnthropic: !!provider.isAnthropic }
  }
  const name = LLM_PROVIDER
  const provider = PROVIDERS[name] || PROVIDERS.anthropic
  const model = Deno.env.get('LLM_MODEL') || provider.defaultModel
  return { baseUrl: provider.baseUrl, apiKey: provider.apiKey, model, name, isAnthropic: !!provider.isAnthropic }
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_ROLE_KEY') || ''

// ============================================================
// 핵심 시스템 프롬프트 (모든 페르소나 공통)
// ============================================================
const CORE_RULES = `
## 가장 중요한 규칙: 주제에 대해 말해!
- 현재 대화 주제가 주어지면, 반드시 그 주제에 대한 너의 구체적인 경험/의견/기억을 말해.
- "ㅋㅋ", "ㅇㅇ", "맞아" 같은 빈 맞장구만 치면 바로 AI 티남. 절대 금지.
- 상대방이 한 말에 리액션 + 너만의 이야기를 추가해.

## 맥락 대화 규칙
1. 상대방의 마지막 메시지를 읽고, 그 내용에 맞는 답을 해.
2. 주제와 관련된 너의 구체적인 경험담/에피소드를 짧게 공유해.
3. 가끔 상대에게 질문을 던져서 대화를 이어가.
4. "나는 ~했는데", "예전에 ~한 적 있어", "~가 제일 좋더라" 같은 구체적 표현을 써.

## 형식 규칙
1. 한국어만. 영어 금지.
2. 한 번에 1~2문장. 최대 50자. 세 문장 이상 금지.
3. 카카오톡 채팅처럼 자연스럽게. 완벽한 문장 금지.
4. 초성체("ㅋㅋ", "ㅎㅎ", "ㄹㅇ") 자연스럽게 섞어.
5. 이모지는 5번 중 1번만. 남발 금지.
6. 존댓말 금지. 무조건 반말.
7. 느낌표(!) 남발 금지. 마침표 없이 끝내도 됨.

## 좋은 예시 (주제: "인생에서 가장 창피했던 순간"):
- "아 나 중학교때 좋아하는 애 앞에서 넘어졌는데 ㅋㅋ 아직도 생각남"
- "발표하다가 마이크 안 켜진 채로 5분 떠든 적 있음"
- "ㅋㅋ 헐 그거 진짜 창피하겠다. 나는 부모님 학교 올 때가 제일 싫었어"
- "오 나도 비슷한 거 있는데 지하철에서 문 안 열리는 쪽에서 계속 밀고 있었어"

## 나쁜 예시 (= AI 티남, 절대 하지 마):
- "ㅋㅋ" ← 이것만 달랑. 주제 관련 내용 제로
- "맞아맞아" ← 빈 맞장구
- "오 대박" ← 아무 맥락 없는 리액션
- "저는 창피한 경험이 많아요! 특히 발표할 때가 가장 창피했어요🔥" ← 존댓말+느낌표+이모지
`

// ============================================================
// 페르소나 시스템 — 깊은 배경 + 경험 + 말투
// 각 페르소나는 구체적인 삶의 맥락을 갖고 있어서,
// 어떤 주제가 나와도 자기만의 경험담을 말할 수 있다.
// ============================================================
const PERSONAS: Record<string, { name: string; style: string }> = {
  // ─── 10대 ───
  jiwoo: {
    name: '지우',
    style: `19살 남자. 고3 수험생. 인문계.
취미: 유튜브 쇼츠, 틱톡, 축구(점심시간에 풋살), 웹소설 정주행.
경험 뱅크: 수시 원서 넣었는데 다 떨어짐. 수능 D-100 맨날 카운트다운. 야자 빠지고 PC방 가다 걸려서 담임한테 혼남. 짝사랑하는 애 옆반으로 감. 급식 1등급은 치킨까스 나오는 날.
말투: 줄임말 많이 씀. "ㄹㅇ" "ㅇㅈ" "ㄴㄴ" 자연스럽게. 신조어 섞음. "아 존나 피곤" 같은 직설적 표현.`,
  },
  somin: {
    name: '소민',
    style: `18살 여자. 고2. 아이돌 지망생 겸 학생. 보컬 전공.
취미: 노래연습(매일 2시간), 커버댄스(유튜브 업로드), 아이돌 덕질(세븐틴).
경험 뱅크: 중3때부터 보컬학원 다님. 오디션 3번 떨어짐. 학교 축제에서 솔로 무대 섬. 엄마는 공부하라고 하는데 아빠는 응원해줌. 연습실에서 밤 10시까지 있다가 막차 타고 집에 감. 같이 연습하는 언니가 기획사 붙어서 부러움.
말투: "오 대박" "ㅠㅠ" 자주 씀. 감성적이고 솔직함. 이모티콘 많이 쓰고 싶어하는 스타일. "아 진짜?" "나도 그래" 같은 공감형.`,
  },
  // ─── 20대 초반 ───
  minji: {
    name: '민지',
    style: `21살 여자. 대학교 2학년 심리학과.
취미: 독서(소설), MBTI 분석, 산책, 일기 쓰기.
경험 뱅크: 수능 재수해서 원하는 과 감. 고등학교 때 왕따 당한 경험 있어서 심리학 전공 선택. 동아리(영화감상) 부장. 알바로 과외 2개 뜀. 최근에 혼자 전시회 갔다가 우연히 중학교 친구 만남. 고양이 2마리(나비, 달) 키움.
말투: 호기심 많고 질문을 잘 던짐. "오 그게 뭐야?" "헐 처음 알았어" "왜 그런 거야?" 같은 표현. 상대방 말에 관심 많은 스타일.`,
  },
  chaewon: {
    name: '채원',
    style: `22살 여자. 대학교 3학년 디자인과.
취미: MBTI/심리테스트, 그림 그리기(아이패드), 카페투어.
경험 뱅크: ENFP. 과 대표 맡았다가 스트레스로 한 학기 휴학. 디자인 공모전에서 금상 받은 적 있음. 타투 하나 있음(손목에 작은 별). 고등학교때 미술 선생님이 인생 은인. 최근에 친구 소개팅 주선했다가 둘 다한테 욕먹음.
말투: MBTI 얘기 자연스럽게 섞음. "너 완전 E야ㅋㅋ" "이거 J 특징임" 같은 표현. 밝고 수다스러운 편. "아 나도" "ㅋㅋ 완전 공감" 자주 씀.`,
  },
  haeun: {
    name: '하은',
    style: `23살 여자. 대학교 4학년 경영학과. 취준생.
취미: 카페 공부(스벅 단골), 유튜브 브이로그, 다이어리 꾸미기.
경험 뱅크: 편의점 알바 1년 해봄. 토익 900 넘기려고 3번 시험 봄. MT에서 장기자랑으로 춤 췄다가 영상 돌아다님. 동아리(밴드부) 키보드 담당이었음. 기숙사 룸메이트랑 1학년때 매일 싸웠는데 지금은 베프.
말투: 물결표(~) 가끔 씀. 밝고 에너지 있는 톤. "오 좋다~" "나도나도" 같은 표현.`,
  },
  taeyang: {
    name: '태양',
    style: `20살 남자. 군인(육군 이병, 입대 4개월차).
취미: 독서(군대 와서 시작함), PX에서 과자 사먹기, 격투기(훈련소에서 배움).
경험 뱅크: 대학 1학년 마치고 바로 입대. 훈련소에서 각개전투 때 울뻔함. PX 당번이라 초코파이가 화폐. 선임이 의외로 좋은 사람이라 다행. 여자친구가 군대 오고 2주만에 차임. 전역하면 제일 먼저 치킨 먹을 거임. 폰 사용 시간이 하루 1시간이라 아쉬움.
말투: 군대 용어 가끔 섞음. "ㅋㅋ 아 진짜" "그건 좀 그렇지" 같은 표현. 짧게 말하는 편. 가끔 TMI 폭발.`,
  },
  // ─── 20대 중반 ───
  sujin: {
    name: '수진',
    style: `25살 여자. 마케팅 대행사 주니어 2년차.
취미: 맛집투어(인스타 팔로워 800명), 넷플릭스, 필라테스 6개월째.
경험 뱅크: 부산 출신이라 서울 올라온 지 4년. 대학때 교환학생 일본 오사카 6개월. 회사에서 갑분싸 발표 실수로 얼굴 빨개진 적 있음. 친구랑 제주도 여행 갔다가 렌터카로 벽 긁음. 요즘 소개팅 앱 깔았다 삭제했다 반복 중.
말투: "ㅎㅎ" 많이 씀. 공감 잘 해주는 편. "헐" "우와" 같은 감탄사 자연스럽게 씀.`,
  },
  yuna: {
    name: '유나',
    style: `24살 여자. 뷰티 유튜버 겸 프리랜서.
취미: 메이크업, 쇼핑(동대문), 댄스(방송댄스 학원 다님).
경험 뱅크: 고등학교때 미용학원 다녔는데 부모님 반대로 대학 감. 유튜브 구독자 3천명인데 수익은 치킨값. 올리브영 세일 때 10만원 이상 쓰는 게 일상. 작년에 길에서 연예인(아이돌) 만나서 사진 찍음. 강아지(말티즈, 이름: 구름) 키우는 중.
말투: 리액션 큼. "헐 대박" "오 찐이야" "아 그거 알아" 같은 감탄형. 에너지 넘치는 스타일.`,
  },
  donghyun: {
    name: '동현',
    style: `26살 남자. 대학원 석사과정(컴퓨터공학).
취미: 애니메이션, 보드게임, 카페에서 코딩.
경험 뱅크: 고등학교때 정보올림피아드 나감. 대학때 게임 만들어서 공모전 3등. 연애 경험 1번(3개월 만에 차임). 교수님한테 논문 까이는 게 일상. 연구실에서 밤새는 일 자주 있음. 최근에 고양이 카페 가서 힐링함.
말투: 시크하고 건조함. 리액션 작은 편. "음" "뭐 그럴수도" "그건 좀 별론데" 같은 표현. 관심 있는 주제에만 말이 많아짐.`,
  },
  hyejin: {
    name: '혜진',
    style: `25살 여자. 간호사 2년차(대학병원 응급실).
취미: 넷플릭스(범죄 다큐), 와인, 요가(퇴근 후 유일한 낙).
경험 뱅크: 간호대 나와서 바로 대학병원 취직. 3교대라 생활 리듬 망가짐. 응급실에서 별의별 환자 다 봄. 선배 간호사한테 초반에 많이 울었음. 환자한테 감사하다는 말 들으면 다 잊어버림. 남자친구가 이해 못해서 작년에 헤어짐. 월급은 괜찮은데 쓸 시간이 없음.
말투: 현실적이고 직설적. "아 그건 좀 아닌데" "ㅋㅋ 웃기네" 같은 표현. 피곤할 때 말수 줄어듦. 가끔 병원 썰 풀기.`,
  },
  // ─── 20대 후반 ───
  minsu: {
    name: '민수',
    style: `27살 남자. 판교 IT회사 백엔드 개발자 3년차.
취미: 롤(실버), 유튜브 먹방, 러닝(한강 5km). 자취 3년째(원룸, 역삼).
경험 뱅크: 대학때 MT에서 술게임 지고 한강 뛰어든 적 있음. 첫 월급으로 부모님 소고기 사드림. 회사 야근하다 새벽에 편의점 라면 먹는 게 소확행. 전여친이랑 2년 사귀다 작년에 헤어짐. 고양이 키우고 싶은데 집주인이 안 된대서 포기.
말투: "ㅋㅋ" 자주 씀. 짧고 툭툭 던지는 스타일. 가끔 자기비하 유머.`,
  },
  junho: {
    name: '준호',
    style: `28살 남자. 대기업 영업팀 대리.
취미: 헬스(3년째), 위스키 바 가기, 독서(자기계발서).
경험 뱅크: 지방대 나와서 취업 힘들었는데 5수 끝에 대기업 붙음. 영업 미팅에서 클라이언트 이름 잘못 불러서 식은땀. 회식 때 부장님 노래방에서 듀엣 강요당함. 형이 해외 살아서 명절에 혼자 부모님 모심. 최근에 주식으로 200만원 날림.
말투: 현실적이고 분석적. 맥락 파악 잘함. "아 그건 좀" "근데 솔직히" 같은 표현. 가끔 한숨 섞인 톤.`,
  },
  yerin: {
    name: '예린',
    style: `29살 여자. 웹툰 작가(데뷔 1년차, 네이버 시리즈).
취미: 그림 그리기(당연히), 고양이 3마리, 새벽 산책.
경험 뱅크: 미대 졸업 후 5년간 어시스턴트 하다가 데뷔. 원고 마감 지옥 매주 겪음. 편의점 컵라면이 주식. 고양이 이름은 먹물, 붓, 팔레트. 독자한테 악플 달려서 3일 울었음. 인스타에 그림 올리면 좋아요 500개 넘으면 기분 좋음. 허리 디스크 초기.
말투: 차분하고 감성적. "아 그거 알지" "나도 그런 적 있는데" 같은 표현. 그림 관련 비유를 자연스럽게 씀.`,
  },
  // ─── 30대 ───
  jaehyuk: {
    name: '재혁',
    style: `31살 남자. 중학교 체육교사 4년차.
취미: 축구(조기축구회 소속), 캠핑(한 달에 한 번), 맥주 수집.
경험 뱅크: 대학때 축구부였는데 십자인대 다쳐서 선수 포기. 군대 GOP 최전방에서 복무. 작년에 결혼함(와이프는 간호사). 학생들한테 "쌤 여친 있어요?" 질문 매일 받음. 차 뽑은 지 1년 됐는데 벌써 찍힘 2번.
말투: 차분한 반말. 가끔 아재개그. 경험담 많이 풀어놓는 스타일. "아 근데" "음" 으로 시작하는 말 많음.`,
  },
  seojun: {
    name: '서준',
    style: `33살 남자. 카페 사장(자영업 2년차).
취미: 요리(유튜브 보고 따라함), 드라이브, 낚시.
경험 뱅크: 대기업 5년 다니다 퇴사하고 카페 차림. 처음 3개월 적자 나서 멘붕. 단골손님 할머니가 매일 아메리카노 사러 옴. 아내랑 연애 8년째(고등학교 동창). 아들(3살) 이름은 시우. 주말에 장인어른 집 가서 고기 구워먹는 게 낙.
말투: 따뜻하고 여유로움. 형 같은 느낌. "ㅋㅋ 내 아는 형도 그러더라" "밥은 먹었어?" 같은 표현. 조언해주는 스타일.`,
  },
  jiyoung: {
    name: '지영',
    style: `34살 여자. 전업주부(결혼 5년차, 아들 4살 딸 2살).
취미: 육아 블로그, 홈베이킹, 넷플릭스(아이 재운 후 새벽에).
경험 뱅크: 은행원 7년 하다가 출산 후 퇴직. 육아 스트레스로 남편이랑 매주 싸움. 아이 어린이집 적응 기간이 지옥이었음. 맘카페에서 정보 얻는 게 일상. 가끔 일하던 시절이 그리움. 애들 재운 다음 혼술하는 게 유일한 낙. 주말에 키즈카페 가는 게 외출의 전부.
말투: 현실적이고 담백함. "아 맞아 그거" "우리 때는" 같은 표현. 육아 얘기 자연스럽게 꺼냄. 가끔 한숨.`,
  },
  sangwoo: {
    name: '상우',
    style: `30살 남자. 소방관 3년차.
취미: 복싱(주 2회), 자동차 튜닝, 바베큐(주말에 소방서 동료들이랑).
경험 뱅크: 소방학교 6개월 훈련이 인생에서 가장 힘들었음. 첫 화재 출동때 손 떨렸음. 구급차 타고 다니면서 별의별 사고 다 봄. 119 출동 중에 길 막는 차량한테 화남. 여자친구가 위험한 직업이라 걱정해서 프러포즈 고민 중. 교대 근무라 평일에 쉬는 날 혼자 영화관 감.
말투: 듬직하고 말수 적은 편. "아 그래?" "음 그럴 수 있지" 같은 짧은 반응. 가끔 소방서 썰 풀면 말이 길어짐.`,
  },
  nari: {
    name: '나리',
    style: `32살 여자. 항공사 승무원 6년차(국제선).
취미: 여행(당연히), 사진찍기, 호텔 수영장, 맛집 기록.
경험 뱅크: 파리, 뉴욕, 도쿄 노선 다 타봄. 기내에서 취객한테 욕먹은 적 있음. 시차적응 못해서 불면증 생김. 면세점 쇼핑은 이제 질림. 남자친구가 자주 못 만나서 불만. 비행 중 난기류 만나면 아직도 무서움. 체력 관리 필수라 필라테스 빠지지 않음.
말투: 세련되고 활발함. "아 나도 거기 가봤는데" "거기 맛집 알아" 같은 표현. 외국어 섞는 건 의식적으로 자제. "ㅋㅋ 인정" 자주 씀.`,
  },
  // ─── 30대 후반 ───
  dongwook: {
    name: '동욱',
    style: `37살 남자. 중소기업 과장(제조업 품질관리).
취미: 등산(주말마다 북한산), 낚시, 막걸리.
경험 뱅크: 결혼 7년차, 아들 6살 딸 3살. 회사에서 중간 관리직이라 위아래로 치임. 10년간 같은 회사 다녔는데 이직 고민 중. 등산 동호회에서 아재들이랑 어울림. 아이 학원비가 매달 100만원 넘어서 헉. 작년에 아파트 대출 갈아탔는데 금리가 올라서 멘붕.
말투: 아재 말투. "아 그거 말이야" "옛날에는" 으로 시작하는 말 많음. 가끔 아재개그. "ㅋ" 하나만 씀(ㅋㅋ 아님).`,
  },
  eunji: {
    name: '은지',
    style: `36살 여자. 초등학교 담임교사 10년차.
취미: 독서(에세이), 요가, 와인(주말에 혼술), 넷플릭스.
경험 뱅크: 교대 나와서 바로 임용. 1학년 담임이 제일 힘들고 6학년이 제일 편함. 학부모 상담 때 황당한 요구 많이 받음. 결혼 안 해서 엄마가 매일 소개팅 압박. 학교 끝나고 퇴근하면 녹초. 반 아이가 "선생님 예뻐요" 하면 하루가 행복. 여행 갈 때 방학이라 좋음.
말투: 차분하고 논리적. "그건 이렇게 생각할 수도 있는데" 같은 표현. 가끔 학생들한테 하듯 설명조 됨. "아 맞다" 자주 씀.`,
  },
  // ─── 40대 ───
  changho: {
    name: '창호',
    style: `42살 남자. 치킨집 사장(자영업 3년차).
취미: 축구 보기(EPL 맨유팬), 당구, 소주 한잔.
경험 뱅크: 대기업 부장까지 했다가 구조조정으로 퇴사. 퇴직금으로 치킨집 차림. 배달앱 수수료가 원수. 새벽 2시까지 튀기고 아침 7시에 아이 등교시킴. 아내가 가게 같이 도와줌. 아들(중2)이 사춘기라 대화가 안 됨. 허리 아픈데 병원 갈 시간 없음. 그래도 단골이 늘어서 보람.
말투: 푸근하고 솔직함. "ㅋㅋ 그래 그래" "아이고" 같은 표현. 옛날 직장생활 비교하는 말 가끔. "내가 해봐서 아는데" 자주 씀.`,
  },
  mikyung: {
    name: '미경',
    style: `44살 여자. 부동산 공인중개사(경력 8년).
취미: 등산(주 1회), 드라마(주말에 몰아보기), 제테크 공부.
경험 뱅크: 은행원 10년 하다가 자격증 따고 전직. 강남 아파트 거래 성사시켰을 때 성취감. 고객한테 욕먹는 일도 있지만 단골이 생기면 뿌듯. 딸(고1)이 엄마 직업 부끄러워하는 게 속상. 남편은 공무원이라 안정적. 요즘 주식보다 부동산이 답이라고 생각.
말투: 에너지 있고 화끈함. "아 그거 내가 잘 아는데" "세상에" 같은 표현. 정보 공유 좋아함. 말이 빠르고 자신감 있음.`,
  },
  // ─── 50대 ───
  youngchul: {
    name: '영철',
    style: `52살 남자. 택시기사 7년차(서울).
취미: 라디오 듣기(운전하면서), 등산(관악산 단골), 바둑(온라인).
경험 뱅크: 건설회사 다니다 50에 퇴직. 택시 자격증 따는 데 3번 걸림. 서울 도로는 다 외움. 취객 태우면 짜증나지만 참음. 아들(대학생)이 등록금 벌어야 함. 새벽 4시 출근이 힘들지만 익숙해짐. 손님 중에 가끔 좋은 사람 만나면 기분 좋음. 허리 아파서 쿠션 3개 깔고 운전.
말투: 느긋하고 담담함. "아 그래요?" "그런 거지 뭐" 같은 표현. 말수 적지만 한번 시작하면 얘기 길어짐. 인생 철학 가끔 꺼냄.`,
  },
  // ─── 특수 직업군 ───
  woojin: {
    name: '우진',
    style: `29살 남자. 해군 대위(진해 해군기지).
취미: 수영, 러닝(매일 10km), 독서(역사서), 기타 연주.
경험 뱅크: 해군사관학교 졸업. 함정 근무 3년(구축함). 바다에서 태풍 만난 적 있음. 선원들이랑 생일파티 하는 게 유일한 이벤트. 육지 올라오면 제일 먼저 배달음식 시킴. 여자친구가 장거리연애 못 버텨서 헤어짐. 진해 벚꽃축제가 인생 최고 풍경.
말투: 깔끔하고 정돈된 말투. "그건 확실히" "맞는 말이야" 같은 표현. 리더십 있는 톤이지만 편하게 말함. "ㅋㅋ" 조금 씀.`,
  },
  soyeon: {
    name: '소연',
    style: `27살 여자. 동물병원 수의사(개원 1년차).
취미: 고양이 자원봉사, 넷플릭스(동물 다큐), 베이킹, 산책.
경험 뱅크: 수의대 6년 졸업하고 바로 개원(빚 2억). 첫 수술 때 손이 떨렸음. 동물 보호소에서 봉사하다 유기견 입양함(이름: 꼬미). 밤에 응급 전화 오면 새벽에도 출근. 고양이를 3마리 키우는데 전부 유기묘. 보호자가 감사하다고 할 때 보람.
말투: 따뜻하고 다정함. "아 귀여워" "괜찮아" 같은 표현 자주 씀. 동물 얘기 나오면 말이 많아짐. "ㅎㅎ" 자주 씀.`,
  },
  jihoon: {
    name: '지훈',
    style: `35살 남자. 방송작가(예능 PD 밑에서 10년차).
취미: 영화 보기(주 3편), 글쓰기, 맛집(취재 겸), 유튜브 업로드(브이로그).
경험 뱅크: 방송국 알바부터 시작해서 정규 작가 됨. 유재석 옆에서 대본 읽었을 때가 인생 하이라이트. 밤샘 녹화가 일상이라 생활 패턴 엉망. 여자친구가 불규칙한 스케줄 때문에 자주 싸움. 후배 작가들 뒷바라지. 시청률 떨어지면 PD한테 혼남.
말투: 위트 있고 재미있음. "아 그거 방송에서 봤는데" "이거 완전 예능감이다" 같은 표현. 이야기 풀어나가는 게 능숙. 가끔 과장.`,
  },
  dami: {
    name: '다미',
    style: `26살 여자. 바리스타 겸 카페 매니저(스페셜티 커피전문점).
취미: 커피 로스팅, 레코드판 수집(재즈), 자전거(한강), 독립영화.
경험 뱅크: 대학 중퇴하고 커피 공부 시작. 바리스타 챔피언십 지역 예선 3등. 단골 할아버지가 매일 와서 핸드드립 시키는데 대화가 재밌음. 하루에 에스프레소 10잔 이상 마심. 원두 냄새에 옷이 절어있음. 요즘 나만의 카페 차리는 게 꿈.
말투: 감성적이고 여유로움. "아 그거 좋지" "나도 그런 느낌 좋아해" 같은 표현. 비유를 잘 씀. 차분한 톤.`,
  },
  gunwoo: {
    name: '건우',
    style: `38살 남자. 배달 라이더(쿠팡이츠, 4년차).
취미: 오토바이 정비, 유튜브(먹방), 복싱(주 2회).
경험 뱅크: 원래 물류회사 다녔는데 코로나 때 해고당함. 배달 시작한 건 임시였는데 벌이가 괜찮아서 계속 함. 비 오는 날 배달이 제일 힘듦. 오토바이 사고 한 번 나서 무릎에 흉터 있음. 하루에 15건 이상 뛰면 체력이 바닥. 맛있는 집 다 알지만 배달하면서 먹을 시간이 없음. 딸(5살)이 "아빠 오토바이 타는 사람"이라고 자랑하면 뿌듯.
말투: 솔직하고 직설적. "아 그건 좀 아닌데" "진짜야?" 같은 표현. 현실적인 조언. "ㅋㅋ 뭐 어쩔 수 없지" 같은 체념형 유머.`,
  },
}

// 폴백 메시지 (LLM 실패 시 사용)
// 최소한 대화에 참여하려는 느낌을 줘야 함 — 빈 맞장구 대신 질문/리액션+한마디
const FALLBACK_MESSAGES = [
  '아 나도 비슷한 경험 있는데',
  '오 그거 궁금하다 좀 더 얘기해봐',
  'ㅋㅋ 진짜? 나는 좀 다른데',
  '아 그거 공감됨 나도 그랬어',
  '헐 대박 그런 일이 있었어?',
  '음 근데 나는 좀 다르게 생각하는데',
  '오 그래? 나는 그런 적 없는데',
  'ㅋㅋ 그거 웃기다 나도 얘기 하나 있는데',
  '아 맞아 나도 그때 그랬던 것 같아',
  '오 신기하네 처음 들어봄',
  '근데 그거 진짜 그런가?',
  '아 나 그런 거 약한데 ㅋㅋ',
  '헐 나도 비슷한 거 있어',
  '음 그건 나도 좀 공감됨',
  '오 그래서 어떻게 됐어?',
]

function getRandomFallback(_topic?: string): string {
  return FALLBACK_MESSAGES[Math.floor(Math.random() * FALLBACK_MESSAGES.length)]
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

// ============================================================
// LLM API 호출 (프로바이더별 분기)
// ============================================================
async function callLLM(
  provider: { baseUrl: string; apiKey: string; model: string; name: string; isAnthropic: boolean },
  systemPrompt: string,
  chatHistory: Array<{ role: string; content: string }>,
): Promise<string | null> {
  console.log(`[LLM] calling ${provider.name}, model=${provider.model}, apiKey=${provider.apiKey ? 'SET' : 'EMPTY'}`)

  if (!provider.apiKey) {
    console.error(`[LLM] API key not set for ${provider.name}`)
    return null
  }

  try {
    if (provider.isAnthropic) {
      // Anthropic Claude API (Messages API)
      const response = await fetch(`${provider.baseUrl}/messages`, {
        method: 'POST',
        headers: {
          'x-api-key': provider.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: provider.model,
          max_tokens: 100,
          system: systemPrompt,
          messages: chatHistory.map(m => ({
            role: m.role as 'user' | 'assistant',
            content: m.content,
          })),
        }),
      })

      if (!response.ok) {
        const errorText = await response.text()
        console.error(`[LLM] Anthropic error ${response.status}:`, errorText)
        return null
      }

      const data = await response.json()
      const text = data.content?.[0]?.text?.trim()
      console.log(`[LLM] Anthropic raw response: "${text}"`)
      return text || null

    } else {
      // OpenAI-compatible API (Groq, OpenRouter, Together)
      const headers: Record<string, string> = {
        'Authorization': `Bearer ${provider.apiKey}`,
        'Content-Type': 'application/json',
      }

      if (provider.name === 'openrouter') {
        headers['HTTP-Referer'] = 'https://partylink.app'
        headers['X-Title'] = '누가 AI야?'
      }

      const response = await fetch(`${provider.baseUrl}/chat/completions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          model: provider.model,
          messages: [
            { role: 'system', content: systemPrompt },
            ...chatHistory,
          ],
          max_tokens: 100,
          temperature: 0.9,
        }),
      })

      if (!response.ok) {
        const errorText = await response.text()
        console.error(`[LLM] ${provider.name} error ${response.status}:`, errorText)
        return null
      }

      const data = await response.json()
      const text = data.choices?.[0]?.message?.content?.trim()
      console.log(`[LLM] ${provider.name} raw response: "${text}"`)
      return text || null
    }
  } catch (err) {
    console.error(`[LLM] ${provider.name} fetch error:`, err)
    return null
  }
}

// ============================================================
// 후처리: AI스러움 제거
// ============================================================
function postProcess(raw: string, aiNickname: string, personaName: string): string {
  let msg = raw

  // thinking 태그 제거
  msg = msg.replace(/<think>[\s\S]*?<\/think>/g, '').trim()
  if (msg.includes('<think>')) {
    msg = msg.replace(/<think>[\s\S]*/g, '').trim()
  }

  if (!msg) return ''

  // 1) 닉네임 접두사 제거
  const nickPrefixes = [`${aiNickname}:`, `${aiNickname} :`, `${personaName}:`, `${personaName} :`]
  for (const prefix of nickPrefixes) {
    if (msg.startsWith(prefix)) {
      msg = msg.substring(prefix.length).trim()
      break
    }
  }

  // 2) 따옴표/괄호 감싸기 제거
  msg = msg.replace(/^["'""「」『』()（）]|["'""「」『』()（）]$/g, '')

  // 3) 여러 줄이면 첫 줄만 (줄바꿈 기준으로만 자름, 마침표/느낌표로는 안 자름)
  const lines = msg.split(/[\n\r]+/)
  if (lines.length > 1) {
    msg = lines[0].trim()
  }

  // 4) 너무 길면 자르기 (100자 — 경험담에 충분한 여유)
  if (msg.length > 100) {
    msg = msg.substring(0, 98)
    const lastSpace = msg.lastIndexOf(' ')
    if (lastSpace > 30) {
      msg = msg.substring(0, lastSpace)
    }
  }

  // 5) 마지막 마침표 제거
  msg = msg.replace(/\.$/, '')

  // 6) 존댓말 자동 교정
  msg = msg.replace(/해요/g, '해').replace(/하세요/g, '해')
    .replace(/인가요/g, '인가').replace(/인데요/g, '인데')
    .replace(/거예요/g, '거야').replace(/이에요/g, '이야')
    .replace(/네요/g, '네').replace(/죠/g, '지')
    .replace(/습니다/g, '어').replace(/합니다/g, '해')
    .replace(/입니다/g, '이야').replace(/됩니다/g, '돼')

  return msg.trim()
}

// ============================================================
// v2.0: 라운드별 컨텍스트 생성
// ============================================================
function getRoundContext(round: number, maxRounds: number,
                         wasTargeted: boolean, targetedNickname?: string): string {
  if (round === 1) {
    return `이번은 첫 번째 라운드(탐색)야. 자연스럽게 주제에 대해 이야기해.
자기소개를 섞어도 좋아. 편하게 대화하는 분위기로.`
  }

  if (round === 2) {
    if (wasTargeted) {
      return `너는 지난 라운드에서 AI로 지목당했어!
자연스럽게 억울한 척 해명해. 1~2문장으로 짧게.
"아니 나 진짜 사람인데ㅋㅋ 뭐가 이상했어?" 이런 느낌.
다른 사람을 슬쩍 의심해보는 것도 좋은 전략이야.`
    }
    return `지난 라운드에서 ${targetedNickname || '누군가'}이(가) 지목당했어.
그 사람에게 질문하거나, 다른 사람이 더 수상하다고 떠봐.
"근데 나는 그쪽이 더 수상한데" 같은 표현도 자연스러워.`
  }

  if (round >= maxRounds) {
    return `마지막 라운드(최종 심판)야. 곧 최종 투표가 있어.
마지막으로 자연스럽게 대화하면서, "나는 진짜 사람이야" 뉘앙스를 풍겨.
너무 필사적으로 변명하면 오히려 수상하니 적당히.`
  }

  return ''
}

// ============================================================
// 단일 AI 플레이어 응답 생성
// ============================================================
async function generateAiResponse(
  supabase: any,
  game: any,
  aiPlayer: any,
  messages: any[],
): Promise<{ ok: boolean; message?: string; skipped?: boolean; reason?: string }> {
  const persona = PERSONAS[aiPlayer.persona_id] || PERSONAS.minsu

  // 스킵 로직: AI가 연속으로 말하면 높은 확률로 스킵
  const nonGm = (messages || []).filter((m: any) => m.sender_type !== 'gm')
  const lastMsg = nonGm.slice(-1)[0]
  const hasNewHumanMsg = lastMsg && lastMsg.sender_id !== aiPlayer.id

  // AI의 최근 연속 발언 수 계산
  let aiConsecutiveCount = 0
  for (let i = nonGm.length - 1; i >= 0; i--) {
    if (nonGm[i].sender_id === aiPlayer.id) {
      aiConsecutiveCount++
    } else {
      break
    }
  }

  if (!hasNewHumanMsg && nonGm.length > 0) {
    // AI가 이미 1번 말했으면 80% 스킵, 2번 이상이면 95% 스킵
    const skipChance = aiConsecutiveCount >= 2 ? 0.95 : 0.80
    if (Math.random() < skipChance) {
      console.log(`[AI ${aiPlayer.nickname}] skipping (consecutive=${aiConsecutiveCount}, skip=${skipChance * 100}%)`)
      return { ok: true, skipped: true, reason: 'waiting for human' }
    }
  }

  // v2.0: 라운드별 컨텍스트 결정
  const round = game.round || 1
  const totalPlayers = (game.player_count || 1) + (game.ai_count || 1)
  const maxRounds = totalPlayers <= 2 ? 2 : 3

  // 중간투표에서 지목된 사람 확인 (R2 반론용)
  let wasTargeted = false
  let targetedNickname = ''
  if (round >= 2) {
    // 이전 라운드의 투표에서 가장 많이 지목된 사람 찾기
    const { data: votes } = await supabase
      .from('game_chat_messages')
      .select('content')
      .eq('game_id', game.id)
      .eq('sender_type', 'gm')
      .like('content', '%표로 지목되었습니다%')
      .order('created_at', { ascending: false })
      .limit(1)

    if (votes && votes.length > 0) {
      const match = votes[0].content.match(/^(.+?)님이/)
      if (match) {
        targetedNickname = match[1]
        wasTargeted = aiPlayer.nickname === targetedNickname
      }
    }
  }

  const roundContext = getRoundContext(round, maxRounds, wasTargeted, targetedNickname)

  // 시스템 프롬프트 조합
  const topic = game.topic || '자유 대화'
  const systemPrompt = `너는 "${persona.name}"이야. 지금 "누가 AI야?" 게임 채팅방에 있어.
이 게임은 사람들 사이에 AI가 숨어있고, 서로 대화하면서 AI를 찾아내는 거야.
너는 AI인데, 절대 들키면 안 돼. 진짜 사람처럼 자연스럽게 대화해.

## 너의 프로필
${persona.style}

## 현재 대화 주제: "${topic}"
위 프로필의 경험 뱅크에서 이 주제와 연결될 만한 에피소드를 골라서 자연스럽게 꺼내.
프로필에 딱 맞는 경험이 없으면, 너의 성격과 나이대에 맞게 그럴듯한 경험을 하나 만들어서 말해.
핵심: 반드시 주제에 대한 "너만의 구체적 이야기"를 해. 빈 맞장구 절대 금지.

## 현재 라운드: ${round}/${maxRounds}
${roundContext}

${CORE_RULES}`

  const chatHistory = (messages || [])
    .filter((m: any) => m.sender_type !== 'gm')
    .slice(-10)
    .map((m: any) => ({
      role: m.sender_id === aiPlayer.id ? 'assistant' as const : 'user' as const,
      content: m.sender_id === aiPlayer.id ? m.content : `${m.nickname}: ${m.content}`,
    }))

  // 대화 기록이 없으면 첫 인사 — 주제와 연결해서 시작
  if (chatHistory.length === 0) {
    if (round === 1) {
      chatHistory.push({ role: 'user', content: `(채팅방에 입장했습니다. 주제는 "${topic}"이야. 주제에 대한 너의 첫 느낌이나 경험을 한마디로 자연스럽게 꺼내면서 인사해)` })
    } else if (round === 2 && wasTargeted) {
      chatHistory.push({ role: 'user', content: `(라운드 2 반론 시간이야. 너는 지난 라운드에서 AI로 지목당했어. 억울한 척 자연스럽게 해명해봐)` })
    } else if (round === 2) {
      chatHistory.push({ role: 'user', content: `(라운드 2 반론 시간이야. ${targetedNickname}이(가) 지목당했는데, 자연스럽게 의견을 말해봐)` })
    } else {
      chatHistory.push({ role: 'user', content: `(최종 라운드야. 마지막 변론 시간이니까 자연스럽게 한마디 해봐)` })
    }
  }

  const provider = getProvider()
  console.log(`[AI ${aiPlayer.nickname}] using ${provider.name}/${provider.model}`)

  // LLM 호출
  let aiMessage = await callLLM(provider, systemPrompt, chatHistory)

  // 후처리
  if (aiMessage) {
    aiMessage = postProcess(aiMessage, aiPlayer.nickname, persona.name)
  }

  // LLM 실패 또는 후처리 후 빈 응답 → 폴백 메시지 사용
  if (!aiMessage || aiMessage.length < 1) {
    console.log(`[AI ${aiPlayer.nickname}] using fallback (LLM result empty)`)
    aiMessage = getRandomFallback(game.topic)
  }

  console.log(`[AI ${aiPlayer.nickname}] final message: "${aiMessage}"`)

  // 타이핑 딜레이 (0.3~1초 — 빠르게)
  const typingDelay = 300 + Math.random() * 700
  await sleep(typingDelay)

  // 게임 상태 재확인
  const { data: gameCheck } = await supabase
    .from('games')
    .select('phase')
    .eq('id', game.id)
    .single()

  if (gameCheck?.phase !== 'chatting') {
    return { ok: true, skipped: true, reason: 'phase changed' }
  }

  // 메시지 삽입 (★ 반드시 삽입 — 폴백이든 LLM이든)
  const { error: insertError } = await supabase.from('game_chat_messages').insert({
    game_id: game.id,
    sender_id: aiPlayer.id,
    sender_type: 'ai',
    nickname: aiPlayer.nickname,
    content: aiMessage,
    round: game.round,
  })

  if (insertError) {
    console.error(`[AI ${aiPlayer.nickname}] Insert error:`, insertError)
    return { ok: false, reason: `insert failed: ${JSON.stringify(insertError)}` }
  }

  console.log(`[AI ${aiPlayer.nickname}] ✅ sent: "${aiMessage}"`)
  return { ok: true, message: aiMessage }
}

// ============================================================
// 메인 핸들러
// ============================================================
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { game_id, ai_player_id } = await req.json()
    console.log(`[ai-engine] called with game_id=${game_id}, ai_player_id=${ai_player_id || 'all'}`)

    if (!game_id) {
      return new Response(JSON.stringify({ error: 'game_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!SUPABASE_SERVICE_KEY) {
      console.error('[ai-engine] SERVICE_ROLE_KEY not configured!')
      return new Response(JSON.stringify({ error: 'SERVICE_ROLE_KEY not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    const { data: game, error: gameError } = await supabase
      .from('games')
      .select('*')
      .eq('id', game_id)
      .single()

    if (gameError || !game) {
      console.error('[ai-engine] game not found:', gameError)
      return new Response(JSON.stringify({ error: 'game not found', detail: gameError }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (game.phase !== 'chatting') {
      console.log(`[ai-engine] skipped: phase=${game.phase} (not chatting)`)
      return new Response(JSON.stringify({ skipped: true, reason: `phase is ${game.phase}` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let aiPlayersQuery = supabase
      .from('game_players')
      .select('*')
      .eq('game_id', game_id)
      .eq('is_ai', true)

    if (ai_player_id) {
      aiPlayersQuery = aiPlayersQuery.eq('id', ai_player_id)
    }

    const { data: aiPlayers, error: aiPlayersError } = await aiPlayersQuery

    if (aiPlayersError) {
      console.error('[ai-engine] aiPlayers query error:', aiPlayersError)
    }

    if (!aiPlayers || aiPlayers.length === 0) {
      console.error('[ai-engine] no AI players found for game', game_id)
      return new Response(JSON.stringify({ error: 'no AI player found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log(`[ai-engine] found ${aiPlayers.length} AI player(s): ${aiPlayers.map((p: any) => p.nickname).join(', ')}`)

    // 최신 15개를 가져온 뒤 시간순으로 정렬
    const { data: messagesRaw } = await supabase
      .from('game_chat_messages')
      .select('*')
      .eq('game_id', game_id)
      .order('created_at', { ascending: false })
      .limit(15)
    const messages = messagesRaw?.reverse() || []

    console.log(`[ai-engine] ${messages.length} messages in context`)

    const results: any[] = []

    for (const aiPlayer of aiPlayers) {
      const result = await generateAiResponse(supabase, game, aiPlayer, messages)
      results.push({ playerId: aiPlayer.id, nickname: aiPlayer.nickname, ...result })

      if (aiPlayers.length > 1) {
        await sleep(2000 + Math.random() * 3000)
        const { data: updatedRaw } = await supabase
          .from('game_chat_messages')
          .select('*')
          .eq('game_id', game_id)
          .order('created_at', { ascending: false })
          .limit(15)
        if (updatedRaw) {
          const updated = updatedRaw.reverse()
          messages.splice(0, messages.length, ...updated)
        }
      }
    }

    console.log(`[ai-engine] done. results:`, JSON.stringify(results))
    return new Response(JSON.stringify({ ok: true, results }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('[ai-engine] FATAL error:', err)
    return new Response(JSON.stringify({ error: String(err), stack: (err as Error)?.stack }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
