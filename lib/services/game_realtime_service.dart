import 'dart:async';
import 'dart:math';
import '../supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 게임 상태 Realtime 서비스
///
/// games + game_players 테이블의 변경을 감지하여 UI 갱신 트리거
/// 재연결 로직 포함 (지수 백오프)
class GameRealtimeService {
  RealtimeChannel? _channel;
  final _controller = StreamController<void>.broadcast();
  String? _currentGameId;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  Stream<void> get onChanged => _controller.stream;

  /// 게임 상태 변경 구독
  void subscribeToGame(String gameId) {
    unsubscribe();
    _currentGameId = gameId;
    _reconnectAttempts = 0;

    _channel = supa().channel('game_state:$gameId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'games',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: gameId,
        ),
        callback: (_) => _controller.add(null),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'game_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'game_id',
          value: gameId,
        ),
        callback: (_) => _controller.add(null),
      );

    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.channelError) {
        _attemptReconnect();
      }
      if (status == RealtimeSubscribeStatus.subscribed) {
        _reconnectAttempts = 0;
      }
    });
  }

  void _attemptReconnect() {
    if (_currentGameId == null || _reconnectAttempts >= 5) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: min(pow(2, _reconnectAttempts).toInt(), 30));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentGameId != null) {
        subscribeToGame(_currentGameId!);
      }
    });
  }

  void unsubscribe() {
    _reconnectTimer?.cancel();
    _channel?.unsubscribe();
    _channel = null;
    _currentGameId = null;
  }

  void dispose() {
    unsubscribe();
    _controller.close();
  }
}
