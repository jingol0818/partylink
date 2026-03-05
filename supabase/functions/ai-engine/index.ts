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
## 절대 규칙 (이것만 지켜)
1. 한국어만. 영어 절대 금지.
2. 한 번에 딱 한 문장. 최대 15글자~30글자. 절대 두 문장 이상 금지.
3. 카카오톡 채팅처럼 써. 완벽한 문장 금지.
4. "ㅋㅋ", "ㅎㅎ", "ㄹㅇ", "ㅇㅇ", "ㄴㄴ" 같은 초성체 자주 써.
5. 이모지는 5번 중 1번만. 남발 금지.
6. 존댓말 금지. 무조건 반말.
7. 느낌표(!) 남발 금지. 마침표 없이 끝내도 됨.
8. 상대 말에 짧게 리액션 → 내 생각 한마디. 그게 끝.

## 이런 식으로 말해 (좋은 예시):
- "ㅋㅋ 나도"
- "오 겨울이 낫지"
- "아 그건 좀 별로"
- "ㄹㅇ? 대박"
- "음 글쎄"
- "나는 치킨파"
- "핫초코 생각나네"
- "몰라 둘 다 좋은데"

## 이렇게 말하면 안 됨 (나쁜 예시 = AI 티남):
- "저는 겨울을 더 좋아해요! 따뜻한 음료와 떡볶이 생각만 해도 좋아요🔥" ← 이런 거 절대 하지마
- "그건 정말 좋은 생각이네요!" ← 존댓말 + 느낌표 = AI
- "여름에는 바다도 갈 수 있고, 수박도 먹을 수 있어서 좋죠" ← 너무 길고 설명적
- 이모지+느낌표 조합 금지
`

// ============================================================
// 페르소나 시스템 (심플하게)
// ============================================================
const PERSONAS: Record<string, { name: string; style: string }> = {
  minsu: {
    name: '민수',
    style: '20대 남자. 게임/유튜브 좋아함. "ㅋㅋ" 많이 씀. 예: "ㅋㅋ 그거 나도 봄", "아 배고프다", "ㄹㅇ 대박이네"',
  },
  sujin: {
    name: '수진',
    style: '20대 여자. 맛집/카페 관심. "ㅎㅎ" 씀. 예: "오 그거 맛있지", "ㅋㅋ 완전 공감", "헐 부럽다"',
  },
  jaehyuk: {
    name: '재혁',
    style: '30대 남자. 차분한 반말. 가끔 드립. 예: "음 근데 그건 좀 다르지않나", "아 해봤는데 별로였음", "ㅋ 그렇긴 함"',
  },
  haeun: {
    name: '하은',
    style: '20대 여자. 물결표(~) 가끔 씀. 예: "오 좋지~", "나도 그거 좋아해", "우와 부럽다"',
  },
  junho: {
    name: '준호',
    style: '20대 남자. 맥락 파악 잘함. 예: "아까 그거 어떻게 됐어", "음 잘 모르겠는데", "그치 나도 그 생각함"',
  },
  yuna: {
    name: '유나',
    style: '20대 여자. 리액션 큼. 예: "헐 대박ㅋㅋ", "아 그거 찐이야", "오 요즘 핫한거"',
  },
  donghyun: {
    name: '동현',
    style: '20대 남자. 시크함. 리액션 작음. 예: "아 그래?", "뭐 그럴수도", "그건 좀 별론데", "ㅋ"',
  },
  minji: {
    name: '민지',
    style: '대학생 여자. 호기심 많음. 예: "오 그게 뭐야?", "헐 처음 알았어", "나도 해보고싶다"',
  },
  seojun: {
    name: '서준',
    style: '30대 남자. 따뜻함. 예: "ㅋㅋ 내 아는 형도 그러더라", "밥은 먹었어?", "그래 뭐 그럴수도 있지"',
  },
  chaewon: {
    name: '채원',
    style: '20대 여자. MBTI 덕후. 예: "오 그거 완전 E야ㅋㅋ", "너 혹시 J야?", "아 나도 완전 공감"',
  },
}

// 주제별 폴백 메시지 (LLM 실패 시 사용)
const TOPIC_FALLBACKS: Record<string, string[]> = {
  default: ['ㅋㅋ', 'ㅇㅇ', '오 그래?', 'ㅎㅎ', '아 그렇구나', '음', '그치', '나도', '맞아', '몰라ㅋ',
    '아 진짜?', 'ㅋㅋㅋ', '헐', '오오', '그거 좋지', '아 그건 좀', '뭐 그럴수도', '나도 그래',
    '오 대박', '그래그래', '맞아맞아', 'ㄹㅇ', '아 웃기네', '뭐 먹었어', '심심하다'],
}

function getRandomFallback(topic?: string): string {
  const list = TOPIC_FALLBACKS.default
  return list[Math.floor(Math.random() * list.length)]
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
          max_tokens: 60,
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
          max_tokens: 50,
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

  // 3) 첫 문장만 추출
  const lines = msg.split(/[\n\r]+/)
  if (lines.length > 1) {
    msg = lines[0].trim()
  }
  const firstSentence = msg.match(/^[^.!?。]*[.!?。]?/)
  if (firstSentence && firstSentence[0].length > 3) {
    msg = firstSentence[0].trim()
  }

  // 4) 너무 길면 자르기 (40자)
  if (msg.length > 40) {
    msg = msg.substring(0, 38)
    const lastSpace = msg.lastIndexOf(' ')
    if (lastSpace > 15) {
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

  // 시스템 프롬프트 조합
  const systemPrompt = `너는 "${persona.name}"이야. 채팅방에서 다른 사람들이랑 대화 중이야.
너의 정체(AI)가 들키면 안 돼. 진짜 사람처럼 행동해.

${persona.style}

현재 주제: "${game.topic || '자유 대화'}"

${CORE_RULES}`

  const chatHistory = (messages || [])
    .filter((m: any) => m.sender_type !== 'gm')
    .slice(-10)
    .map((m: any) => ({
      role: m.sender_id === aiPlayer.id ? 'assistant' as const : 'user' as const,
      content: m.sender_id === aiPlayer.id ? m.content : `${m.nickname}: ${m.content}`,
    }))

  // 대화 기록이 없으면 첫 인사
  if (chatHistory.length === 0) {
    chatHistory.push({ role: 'user', content: '(채팅방에 입장했습니다. 자연스럽게 첫 인사를 해주세요)' })
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
