/// 게임 채팅 메시지 모델
///
/// DB VIEW `game_chat_messages_safe` 기반
/// sender_type은 result phase 전에는 'player' 또는 'gm'으로만 노출
class GameChatMessage {
  final String id;
  final String gameId;
  final String? senderId;
  final String senderType;  // player | gm (result 전) / player | ai | gm (result 후)
  final String nickname;
  final String content;
  final int round;
  final DateTime createdAt;

  GameChatMessage({
    required this.id,
    required this.gameId,
    this.senderId,
    required this.senderType,
    required this.nickname,
    required this.content,
    required this.round,
    required this.createdAt,
  });

  factory GameChatMessage.fromMap(Map<String, dynamic> m) => GameChatMessage(
        id: m['id'].toString(),
        gameId: m['game_id'].toString(),
        senderId: m['sender_id']?.toString(),
        senderType: m['sender_type']?.toString() ?? 'player',
        nickname: m['nickname'].toString(),
        content: m['content'].toString(),
        round: (m['round'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(m['created_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'game_id': gameId,
        'sender_id': senderId,
        'sender_type': senderType,
        'nickname': nickname,
        'content': content,
        'round': round,
      };

  bool get isGm => senderType == 'gm';
  bool get isAi => senderType == 'ai';

  /// Realtime에서 받은 raw 데이터를 안전하게 변환 (sender_type 마스킹)
  factory GameChatMessage.fromRealtimeSafe(Map<String, dynamic> m) {
    final rawType = m['sender_type']?.toString() ?? 'player';
    return GameChatMessage(
      id: m['id'].toString(),
      gameId: m['game_id'].toString(),
      senderId: m['sender_id']?.toString(),
      // Realtime에서는 gm만 그대로, 나머지는 player로 마스킹
      senderType: rawType == 'gm' ? 'gm' : 'player',
      nickname: m['nickname'].toString(),
      content: m['content'].toString(),
      round: (m['round'] as num?)?.toInt() ?? 1,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'].toString())
          : DateTime.now(),
    );
  }
}
