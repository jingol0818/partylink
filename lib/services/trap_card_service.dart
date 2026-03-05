import '../supabase_client.dart';
import '../models/trap_card.dart';

class TrapCardService {
  /// 랜덤 함정 카드 뽑기
  Future<TrapAnswer?> drawCard({
    required String gameId,
    required int round,
    required String askerId,
    required String targetId,
  }) async {
    final result = await supa().rpc('draw_trap_card', params: {
      'p_game_id': gameId,
      'p_round': round,
      'p_asker_id': askerId,
      'p_target_id': targetId,
    });

    if (result == null || result['error'] != null) return null;

    return TrapAnswer(
      id: result['answer_id'] as String,
      gameId: gameId,
      round: round,
      cardId: result['card_id'] as String,
      askerId: result['asker_id'] as String,
      targetId: result['target_id'] as String,
      createdAt: DateTime.now(),
      category: result['category'] as String?,
      question: result['question'] as String?,
    );
  }

  /// 함정 카드 답변 제출
  Future<void> submitAnswer({
    required String answerId,
    required String answer,
  }) async {
    await supa().rpc('answer_trap_card', params: {
      'p_answer_id': answerId,
      'p_answer': answer,
    });
  }

  /// 현재 라운드 활성 함정 카드 조회
  Future<TrapAnswer?> getActiveCard(String gameId, int round) async {
    final result = await supa()
        .from('game_trap_answers')
        .select('*, trap_cards(category, question)')
        .eq('game_id', gameId)
        .eq('round', round)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (result == null) return null;

    final card = result['trap_cards'] as Map<String, dynamic>?;
    return TrapAnswer(
      id: result['id'] as String,
      gameId: result['game_id'] as String,
      round: result['round'] as int,
      cardId: result['card_id'] as String,
      askerId: result['asker_id'] as String,
      targetId: result['target_id'] as String,
      answer: result['answer'] as String?,
      answeredAt: result['answered_at'] != null
          ? DateTime.parse(result['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(result['created_at'] as String),
      category: card?['category'] as String?,
      question: card?['question'] as String?,
    );
  }
}
