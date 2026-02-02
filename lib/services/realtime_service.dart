import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

/// Supabase Realtime을 통한 방/멤버 변경 이벤트 수신
///
/// rooms, members 테이블의 변경사항을 실시간으로 감지하여
/// UI 갱신 트리거를 발행합니다.
class RealtimeService {
  RealtimeChannel? _channel;
  final _events = StreamController<void>.broadcast();

  /// 변경 이벤트 스트림 (UI에서 listen하여 데이터 재조회)
  Stream<void> get onChanged => _events.stream;

  /// 특정 방의 실시간 구독 시작
  ///
  /// 이전 구독이 있으면 자동으로 해제 후 새로 구독합니다.
  void subscribeRoom(String roomId) {
    unsubscribe();

    _channel = supa().channel('room:$roomId')
      // members 테이블 변경 감지
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) => _events.add(null),
      )
      // rooms 테이블 변경 감지
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: roomId,
        ),
        callback: (_) => _events.add(null),
      );

    _channel!.subscribe();
  }

  /// 구독 해제
  void unsubscribe() {
    if (_channel != null) {
      supa().removeChannel(_channel!);
      _channel = null;
    }
  }

  /// 리소스 정리 (페이지 dispose 시 호출)
  void dispose() {
    unsubscribe();
    _events.close();
  }
}
