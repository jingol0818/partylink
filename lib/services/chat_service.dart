import 'dart:async';
import '../models/chat_message.dart';
import '../supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 채팅 서비스
class ChatService {
  RealtimeChannel? _channel;
  final _controller = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get onMessage => _controller.stream;

  /// 채팅 채널 구독
  void subscribeToRoom(String roomId) {
    _channel?.unsubscribe();

    _channel = supa()
        .channel('chat:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              _controller.add(ChatMessage.fromMap(newRecord));
            }
          },
        )
        .subscribe();
  }

  /// 메시지 목록 조회 (최근 50개)
  Future<List<ChatMessage>> getMessages(String roomId) async {
    final rows = await supa()
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .map<ChatMessage>((m) => ChatMessage.fromMap(m))
        .toList()
        .reversed
        .toList();
  }

  /// 메시지 전송
  Future<void> sendMessage({
    required String roomId,
    required String memberId,
    required String senderName,
    required String content,
  }) async {
    await supa().from('chat_messages').insert({
      'room_id': roomId,
      'member_id': memberId,
      'sender_name': senderName,
      'content': content,
    });
  }

  /// 구독 해제
  void dispose() {
    _channel?.unsubscribe();
    _controller.close();
  }
}
