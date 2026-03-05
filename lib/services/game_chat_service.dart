import 'dart:async';
import '../models/game_chat_message.dart';
import '../supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 게임 채팅 서비스
///
/// Realtime 구독 + 메시지 CRUD
/// 기존 ChatService 패턴을 따르되, sender_type 마스킹 적용
class GameChatService {
  RealtimeChannel? _channel;
  final _controller = StreamController<GameChatMessage>.broadcast();

  Stream<GameChatMessage> get onMessage => _controller.stream;

  /// 게임 채팅 채널 구독
  void subscribeToGame(String gameId) {
    _channel?.unsubscribe();

    _channel = supa()
        .channel('game_chat:$gameId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'game_id',
            value: gameId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              // Realtime은 raw 테이블 데이터 → sender_type 마스킹 적용
              _controller.add(GameChatMessage.fromRealtimeSafe(newRecord));
            }
          },
        )
        .subscribe();
  }

  /// 메시지 목록 조회 (safe VIEW 사용)
  Future<List<GameChatMessage>> getMessages(String gameId) async {
    final rows = await supa()
        .from('game_chat_messages_safe')
        .select()
        .eq('game_id', gameId)
        .order('created_at', ascending: true)
        .limit(100);

    return rows
        .map<GameChatMessage>((m) => GameChatMessage.fromMap(m))
        .toList();
  }

  /// 메시지 전송 (인간 플레이어)
  Future<void> sendMessage({
    required String gameId,
    required String senderId,
    required String nickname,
    required String content,
    required int round,
  }) async {
    await supa().from('game_chat_messages').insert({
      'game_id': gameId,
      'sender_id': senderId,
      'sender_type': 'player',
      'nickname': nickname,
      'content': content,
      'round': round,
    });
  }

  /// 구독 해제 + 리소스 정리
  void dispose() {
    _channel?.unsubscribe();
    _controller.close();
  }
}
