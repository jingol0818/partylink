import '../supabase_client.dart';

/// GameMaster 시스템 메시지 서비스
///
/// 게임 진행 안내 메시지를 game_chat_messages에 삽입
class GmService {
  /// GM 메시지 삽입
  static Future<void> _insert(String gameId, String content, int round) async {
    await supa().from('game_chat_messages').insert({
      'game_id': gameId,
      'sender_type': 'gm',
      'nickname': 'GM',
      'content': content,
      'round': round,
    });
  }

  /// 게임 시작 안내 (동적 타이머)
  static Future<void> announceGameStart(
    String gameId, String topic, int round, {int playerCount = 2}
  ) async {
    final chatTime = switch (playerCount) { <= 2 => 90, 3 => 120, 4 => 150, _ => 180 };
    await _insert(gameId, '모두 모였네요! 게임을 시작합니다.', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '이 중에 AI가 숨어 있습니다. 대화를 통해 누가 AI인지 찾아보세요!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '주제: "$topic"', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '자유 대화 시간: $chatTime초', round);
  }

  /// 투표 시작 안내 (동적 타이머)
  static Future<void> announceVoting(
    String gameId, int round, {int playerCount = 2}
  ) async {
    final voteTime = switch (playerCount) { <= 2 => 15, 3 => 20, 4 => 25, _ => 30 };
    await _insert(gameId, '자유 대화 종료!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, 'AI라고 생각되는 사람을 지목하세요! ($voteTime초)', round);
  }

  /// 함정 카드 안내
  static Future<void> announceTrapQuestion(
    String gameId, String askerName, String targetName, int round,
  ) async {
    await _insert(gameId, '함정 카드 시간! 🃏', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '$askerName님이 $targetName님에게 질문합니다!', round);
  }

  /// 결과 공개 안내
  static Future<void> announceResult(String gameId, int round) async {
    await _insert(gameId, '투표가 마감되었습니다.', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '정체를 공개합니다...', round);
  }

  /// 다음 라운드 안내
  static Future<void> announceNextRound(String gameId, int round) async {
    await _insert(gameId, '🔄 라운드 $round 시작!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '다시 대화를 시작하세요!', round);
  }

  /// 침묵 유도 메시지
  static Future<void> nudgeSilence(String gameId, int round) async {
    await _insert(gameId, '조용하네요~ 서로 이야기해 보세요!', round);
  }
}
