import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart' show supa, supabaseUrl, supabaseAnonKey;

class MatchingService {
  StreamSubscription? _subscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMatchUpdate => _controller.stream;

  /// 매칭 풀 진입
  /// supabase-dart SDK의 .rpc()가 scalar uuid 반환 시 null을 돌려주는 이슈 우회
  /// → 직접 REST API 호출로 UUID를 안전하게 받아온다
  Future<String> joinPool({
    required String sessionId,
    required String nickname,
    required String avatarShape,
    required String avatarColor,
  }) async {
    final url = supabaseUrl;
    final key = supabaseAnonKey;

    debugPrint('[MATCH] joinPool → POST $url/rest/v1/rpc/join_matching_pool');

    final response = await http.post(
      Uri.parse('$url/rest/v1/rpc/join_matching_pool'),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'p_session_id': sessionId,
        'p_nickname': nickname,
        'p_avatar_shape': avatarShape,
        'p_avatar_color': avatarColor,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('[MATCH] joinPool HTTP ${response.statusCode}: ${response.body}');
      throw Exception('매칭 풀 진입 실패 (${response.statusCode})');
    }

    // PostgREST returns UUID as JSON string: "uuid-string"
    final body = response.body.trim();
    final poolId = body.replaceAll('"', '');
    if (poolId.isEmpty || poolId.startsWith('<')) {
      throw Exception('매칭 풀 진입 실패: 잘못된 응답');
    }
    debugPrint('[MATCH] joinPool OK → $poolId');
    return poolId;
  }

  /// 매칭 시도 (폴링 방식)
  /// try_match는 jsonb를 반환하므로 SDK .rpc()를 그대로 사용
  Future<Map<String, dynamic>> tryMatch(String poolId) async {
    final result = await supa().rpc('try_match', params: {
      'p_pool_id': poolId,
    });
    if (result == null) throw Exception('매칭 시도 실패');
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {'status': 'error', 'message': result.toString()};
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
