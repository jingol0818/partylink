import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class MatchingService {
  StreamSubscription? _subscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMatchUpdate => _controller.stream;

  /// 매칭 풀 진입
  Future<String> joinPool({
    required String sessionId,
    required String nickname,
    required String avatarShape,
    required String avatarColor,
  }) async {
    final result = await supa().rpc('join_matching_pool', params: {
      'p_session_id': sessionId,
      'p_nickname': nickname,
      'p_avatar_shape': avatarShape,
      'p_avatar_color': avatarColor,
    });
    return result as String;
  }

  /// 매칭 시도 (폴링 방식)
  Future<Map<String, dynamic>> tryMatch(String poolId) async {
    final result = await supa().rpc('try_match', params: {
      'p_pool_id': poolId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// 매칭 풀 구독 (Realtime)
  void subscribeToPool(String poolId) {
    final channel = supa().channel('matching:$poolId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'matching_pool',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: poolId,
          ),
          callback: (payload) {
            _controller.add(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// 매칭 취소
  Future<void> cancelMatch(String poolId) async {
    await supa().rpc('cancel_match', params: {
      'p_pool_id': poolId,
    });
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
