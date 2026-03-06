import '../supabase_client.dart';

/// GameMaster 시스템 메시지 서비스
///
/// 게임 진행 안내 메시지를 game_chat_messages에 삽입
/// v2.0: 라운드별 맞춤 멘트 (탐색/반론/최종심판)
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

  /// 플레이어 입장 알림 (게임 시작 전 각 플레이어 입장 메시지)
  static Future<void> announcePlayerJoin(
    String gameId, List<String> nicknames, int round,
  ) async {
    for (final name in nicknames) {
      await _insert(gameId, '$name님이 입장했습니다.', round);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// 게임 시작 안내 (인트로 후 첫 번째 채팅 시작)
  static Future<void> announceGameStart(
    String gameId, String topic, int round, {int playerCount = 2}
  ) async {
    await _insert(gameId, '모두 모였네요! 게임을 시작합니다.', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '이 중에 AI가 숨어 있습니다. 대화를 통해 누가 AI인지 찾아보세요!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '주제: "$topic"', round);
  }

  /// 라운드별 채팅 시작 안내
  static Future<void> announceRoundStart(
    String gameId, int round, int maxRounds, {
    int chatSeconds = 90,
    String? targetedNickname,
  }) async {
    if (round == 1) {
      await _insert(gameId, '주제에 대해 자유롭게 이야기해보세요!', round);
      await Future.delayed(const Duration(milliseconds: 300));
      await _insert(gameId, '대화 시간: $chatSeconds초', round);
    } else if (round == 2) {
      if (targetedNickname != null) {
        await _insert(gameId, '아까 지목된 $targetedNickname님, 할 말 있으신가요?', round);
      } else {
        await _insert(gameId, '반론의 시간입니다! 의심가는 사람에게 질문하세요.', round);
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _insert(gameId, '대화 시간: $chatSeconds초', round);
    } else if (round >= maxRounds) {
      await _insert(gameId, '이 방에서 AI는 누구일까? 마지막 변론!', round);
      await Future.delayed(const Duration(milliseconds: 300));
      await _insert(gameId, '최종 한마디씩 하세요! ($chatSeconds초)', round);
    }
  }

  /// 중간투표 시작 안내
  static Future<void> announceMidVoting(
    String gameId, int round, {int voteSeconds = 20}
  ) async {
    await _insert(gameId, '⏰ 라운드 $round 대화 종료!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, 'AI인 것 같은 사람을 지목하세요! ($voteSeconds초)', round);
  }

  /// 최종투표 시작 안내
  static Future<void> announceFinalVoting(
    String gameId, int round, {int voteSeconds = 30}
  ) async {
    await _insert(gameId, '⏰ 최종 라운드 대화 종료!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '최종 결정의 시간! AI를 지목하세요! ($voteSeconds초)', round);
  }

  /// 중간투표 결과 안내 (AI 여부 비공개!)
  static Future<void> announceMidVoteResult(
    String gameId, int round, String targetNickname, int voteCount,
  ) async {
    await _insert(gameId, '투표 결과 발표!', round);
    await Future.delayed(const Duration(milliseconds: 500));
    await _insert(gameId, '$targetNickname님이 $voteCount표로 지목되었습니다', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '※ AI인지는 아직 비밀입니다...', round);
  }

  /// 라운드 전환 안내
  static Future<void> announceRoundTransition(
    String gameId, int nextRound, int maxRounds,
  ) async {
    if (nextRound == 2) {
      await _insert(gameId, '라운드 2: 반론의 시간!', nextRound);
    } else if (nextRound >= maxRounds) {
      await _insert(gameId, '최종 라운드: 심판의 시간!', nextRound);
    } else {
      await _insert(gameId, '라운드 $nextRound 시작!', nextRound);
    }
  }

  /// 투표 시작 안내 (기존 호환)
  static Future<void> announceVoting(
    String gameId, int round, {int playerCount = 2}
  ) async {
    final voteTime = switch (playerCount) { <= 2 => 15, 3 => 20, 4 => 25, _ => 30 };
    await _insert(gameId, '⏰ 라운드 $round 대화 종료!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, 'AI라고 생각되는 사람을 지목하세요! ($voteTime초)', round);
  }

  /// 미션카드 예고 (채팅 종료 → 미션카드 전환 전)
  static Future<void> announcePreTrapCard(String gameId, int round) async {
    await _insert(gameId, '⏰ 라운드 $round 대화 종료!', round);
    await Future.delayed(const Duration(milliseconds: 500));
    final roundMsg = switch (round) {
      1 => '잠깐! 미션 카드가 등장합니다 🃏',
      2 => '다시 한번! 미션 카드 시간 🃏',
      _ => '마지막 미션 카드! 🃏',
    };
    await _insert(gameId, roundMsg, round);
  }

  /// 함정 카드 안내 (미션카드 등장 후)
  static Future<void> announceTrapQuestion(
    String gameId, String askerName, String targetName, int round,
  ) async {
    await _insert(gameId, '$askerName님이 $targetName님에게 질문합니다!', round);
  }

  /// 결과 공개 안내
  static Future<void> announceResult(String gameId, int round) async {
    await _insert(gameId, '투표가 마감되었습니다.', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '정체를 공개합니다...', round);
  }

  /// 자유 대화 시간 시작
  static Future<void> announceFreeChatStart(String gameId, int round) async {
    await _insert(gameId, '자유 대화 시간! 15초간 자유롭게 이야기하세요 💬', round);
  }

  /// 자유 대화 시간 종료
  static Future<void> announceFreeChatEnd(String gameId, int round) async {
    await _insert(gameId, '자유 대화 종료! 수고하셨습니다 👋', round);
  }

  /// 다음 라운드 안내 (기존 호환)
  static Future<void> announceNextRound(String gameId, int round) async {
    await _insert(gameId, '라운드 $round 시작!', round);
    await Future.delayed(const Duration(milliseconds: 300));
    await _insert(gameId, '다시 대화를 시작하세요!', round);
  }

  /// 침묵 유도 메시지
  static Future<void> nudgeSilence(String gameId, int round) async {
    await _insert(gameId, '조용하네요~ 서로 이야기해 보세요!', round);
  }
}
