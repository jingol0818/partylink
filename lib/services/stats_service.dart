import '../supabase_client.dart';
import '../models/player_stats.dart';

class StatsService {
  /// 게임 종료 후 통계 업데이트
  Future<void> updateStats({
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

  /// 리더보드 조회
  Future<List<PlayerStats>> getLeaderboard() async {
    final result = await supa().rpc('get_leaderboard');
    final list = result as List;
    return list
        .map((e) => PlayerStats.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
