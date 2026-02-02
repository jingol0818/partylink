/// 채팅 메시지 모델
class ChatMessage {
  final String id;
  final String roomId;
  final String? memberId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    this.memberId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'].toString(),
      roomId: map['room_id'].toString(),
      memberId: map['member_id']?.toString(),
      senderName: map['sender_name'] ?? '알 수 없음',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'member_id': memberId,
      'sender_name': senderName,
      'content': content,
    };
  }
}
