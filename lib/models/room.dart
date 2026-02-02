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

  // 신규 필드
  final String? roomName; // 방 이름
  final int teamCount; // 팀 수
  final int membersPerTeam; // 팀당 인원
  final List<String>? customSlotNames; // 커스텀 슬롯명
  final String? hostSessionId; // 방장 세션 ID

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
    this.roomName,
    this.teamCount = 1,
    this.membersPerTeam = 5,
    this.customSlotNames,
    this.hostSessionId,
  });

  /// Supabase row → Room 객체 변환
  factory Room.fromMap(Map<String, dynamic> m) {
    final slotsRaw = m['slots'];
    final slots = (slotsRaw is List)
        ? slotsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final customSlotsRaw = m['custom_slot_names'];
    final customSlotNames = (customSlotsRaw is List)
        ? customSlotsRaw.map((e) => e.toString()).toList()
        : null;

    return Room(
      id: m['id'].toString(),
      code: m['code'].toString(),
      gameKey: m['game_key'].toString(),
      mode: m['mode']?.toString() ?? '',
      goal: m['goal'].toString(),
      maxMembers: (m['max_members'] as num).toInt(),
      slots: slots,
      requireMic: (m['require_mic'] as bool?) ?? false,
      status: m['status'].toString(),
      expiresAt: DateTime.parse(m['expires_at'].toString()),
      roomName: m['room_name']?.toString(),
      teamCount: (m['team_count'] as num?)?.toInt() ?? 1,
      membersPerTeam: (m['members_per_team'] as num?)?.toInt() ?? 5,
      customSlotNames: customSlotNames,
      hostSessionId: m['host_session_id']?.toString(),
    );
  }

  /// Room → Map 변환 (업데이트용)
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'game_key': gameKey,
      'mode': mode,
      'goal': goal,
      'max_members': maxMembers,
      'slots': slots,
      'require_mic': requireMic,
      'status': status,
      'expires_at': expiresAt.toIso8601String(),
      'room_name': roomName,
      'team_count': teamCount,
      'members_per_team': membersPerTeam,
      'custom_slot_names': customSlotNames,
      'host_session_id': hostSessionId,
    };
  }

  /// 방이 만료되었는지 확인
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// 방이 활성(입장 가능) 상태인지 확인
  bool get isOpen => status == 'open' && !isExpired;

  /// 현재 슬롯명 (커스텀 또는 기본)
  List<String> get displaySlotNames => customSlotNames ?? slots;

  /// copyWith 메서드
  Room copyWith({
    String? id,
    String? code,
    String? gameKey,
    String? mode,
    String? goal,
    int? maxMembers,
    List<String>? slots,
    bool? requireMic,
    String? status,
    DateTime? expiresAt,
    String? roomName,
    int? teamCount,
    int? membersPerTeam,
    List<String>? customSlotNames,
    String? hostSessionId,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      gameKey: gameKey ?? this.gameKey,
      mode: mode ?? this.mode,
      goal: goal ?? this.goal,
      maxMembers: maxMembers ?? this.maxMembers,
      slots: slots ?? this.slots,
      requireMic: requireMic ?? this.requireMic,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      roomName: roomName ?? this.roomName,
      teamCount: teamCount ?? this.teamCount,
      membersPerTeam: membersPerTeam ?? this.membersPerTeam,
      customSlotNames: customSlotNames ?? this.customSlotNames,
      hostSessionId: hostSessionId ?? this.hostSessionId,
    );
  }
}
