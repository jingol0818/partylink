import '../models/game_room.dart';
import '../models/game_player.dart';
import '../supabase_client.dart';

/// 게임 CRUD + RPC 호출 서비스
class GameService {
  /// 1:1 게임 생성
  Future<({String gameId, String code, String playerId, String topic})>
      create1v1Game({
    required String sessionId,
    required String nickname,
    required String avatarShape,
    required String avatarColor,
  }) async {
    final result = await supa().rpc('create_1v1_game', params: {
      'p_session_id': sessionId,
      'p_nickname': nickname,
      'p_avatar_shape': avatarShape,
      'p_avatar_color': avatarColor,
    });

    if (result == null) throw Exception('게임 생성 실패: 응답 없음');
    final data = Map<String, dynamic>.from(result as Map);
    return (
      gameId: data['game_id'].toString(),
      code: data['code'].toString(),
      playerId: data['player_id'].toString(),
      topic: data['topic']?.toString() ?? '자유 대화',
    );
  }

  /// 게임 조회 (by ID)
  Future<GameRoom?> getGameById(String gameId) async {
    final rows = await supa()
        .from('games')
        .select()
        .eq('id', gameId)
        .limit(1);

    if (rows.isEmpty) return null;
    return GameRoom.fromMap(rows.first);
  }

  /// 게임 조회 (by code)
  Future<GameRoom?> getGameByCode(String code) async {
    final rows = await supa()
        .from('games')
        .select()
        .eq('code', code)
        .limit(1);

    if (rows.isEmpty) return null;
    return GameRoom.fromMap(rows.first);
  }

  /// 플레이어 목록 조회 (safe VIEW 사용 → is_ai 마스킹)
  Future<List<GamePlayer>> getPlayers(String gameId) async {
    final rows = await supa()
        .from('game_players_safe')
        .select()
        .eq('game_id', gameId)
        .order('created_at', ascending: true);

    return rows.map<GamePlayer>((m) => GamePlayer.fromMap(m)).toList();
  }

  /// 결과 화면용 플레이어 목록 (is_ai 포함)
  Future<List<GamePlayer>> getPlayersForResult(String gameId) async {
    // result phase에서는 VIEW가 is_ai를 공개하므로 동일한 뷰 사용
    return getPlayers(gameId);
  }

  /// 페이즈 전환
  Future<void> advancePhase(String gameId, String nextPhase) async {
    await supa().rpc('advance_phase', params: {
      'p_game_id': gameId,
      'p_next_phase': nextPhase,
    });
  }

  /// 투표
  Future<bool> castVote(String playerId, String targetId) async {
    final result = await supa().rpc('cast_vote', params: {
      'p_player_id': playerId,
      'p_target_id': targetId,
    });
    return result as bool? ?? false;
  }

  /// AI 자동 투표
  Future<void> aiAutoVote(String gameId) async {
    await supa().rpc('ai_auto_vote', params: {
      'p_game_id': gameId,
    });
  }

  /// 점수 계산
  Future<void> calculateScore(String gameId) async {
    await supa().rpc('calculate_score', params: {
      'p_game_id': gameId,
    });
  }

  /// AI 응답 트리거 (Edge Function 호출)
  Future<Map<String, dynamic>> triggerAiResponse(String gameId, {String? aiPlayerId}) async {
    try {
      final res = await supa().functions.invoke(
        'ai-engine',
        body: {
          'game_id': gameId,
          if (aiPlayerId != null) 'ai_player_id': aiPlayerId,
        },
      );
      final data = res.data;
      // ignore: avoid_print
      print('[AI] status=${res.status}, data=$data');

      if (data is Map<String, dynamic>) {
        if (data['error'] != null) {
          // ignore: avoid_print
          print('[AI] ⚠️ ERROR from edge function: ${data['error']}');
        }
        return data;
      }
      return {'ok': true, 'raw': '$data'};
    } catch (e) {
      // ignore: avoid_print
      print('[AI] ❌ trigger FAILED: $e');
      rethrow; // 에러를 전파하여 재시도 가능하게
    }
  }

  /// 다음 라운드 진행
  Future<void> advanceToNextRound(String gameId) async {
    await supa().rpc('advance_to_next_round', params: {
      'p_game_id': gameId,
    });
  }

  /// 플레이어 통계 업데이트
  Future<void> updatePlayerStats({
    required String sessionId,
    required String displayName,
    required int score,
    required bool won,
  }) async {
    await supa().rpc('update_player_stats', params: {
      'p_session_id': sessionId,
      'p_display_name': displayName,
      'p_score': score,
      'p_won': won,
    });
  }
}
