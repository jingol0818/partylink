/// 파티 방 모델
///
/// DB 테이블 `rooms`와 1:1 대응
class Room {
  final String id;
  final String code;
  final String gameKey;
  final String mode;
  final String goal;
  final int maxMembers;
  final List<String> slots;
  final bool requireMic;
  final String status; // open, closed
  final DateTime expiresAt;

  Room({
    required this.id,
    required this.code,
    required this.gameKey,
    required this.mode,
    required this.goal,
    required this.maxMembers,
    required this.slots,
    required this.requireMic,
    required this.status,
    required this.expiresAt,
  });

  /// Supabase row → Room 객체 변환
  factory Room.fromMap(Map<String, dynamic> m) {
    final slotsRaw = m['slots'];
    final slots = (slotsRaw is List)
        ? slotsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return Room(
      id: m['id'].toString(),
      code: m['code'].toString(),
      gameKey: m['game_key'].toString(),
      mode: m['mode'].toString(),
      goal: m['goal'].toString(),
      maxMembers: (m['max_members'] as num).toInt(),
      slots: slots,
      requireMic: (m['require_mic'] as bool?) ?? false,
      status: m['status'].toString(),
      expiresAt: DateTime.parse(m['expires_at'].toString()),
    );
  }

  /// 방이 만료되었는지 확인
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// 방이 활성(입장 가능) 상태인지 확인
  bool get isOpen => status == 'open' && !isExpired;
}
