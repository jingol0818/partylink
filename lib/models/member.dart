/// 파티 멤버 모델
///
/// DB 테이블 `members`와 1:1 대응
///
/// [state] 값 정의:
/// - `watching` : 관전 중 (입장했지만 자리 미확정)
/// - `joined`   : 자리 확정됨 (역할 선택 완료)
/// - `waiting`  : 대기열 (다음 단계에서 구현)
/// - `left`     : 자발적 퇴장
/// - `kicked`   : 강퇴됨
class Member {
  final String id;
  final String roomId;
  final String displayName;
  final String? tag;
  final String? role;
  final String state;
  final bool ready;

  // 신규 필드
  final String? inviteId; // 게임ID/배틀태그 등 초대 방법
  final String? sessionId; // 세션 ID (방장 확인용)

  Member({
    required this.id,
    required this.roomId,
    required this.displayName,
    this.tag,
    this.role,
    required this.state,
    required this.ready,
    this.inviteId,
    this.sessionId,
  });

  /// Supabase row → Member 객체 변환
  factory Member.fromMap(Map<String, dynamic> m) => Member(
        id: m['id'].toString(),
        roomId: m['room_id'].toString(),
        displayName: m['display_name'].toString(),
        tag: m['tag']?.toString(),
        role: m['role']?.toString(),
        state: m['state'].toString(),
        ready: (m['ready'] as bool?) ?? false,
        inviteId: m['invite_id']?.toString(),
        sessionId: m['session_id']?.toString(),
      );

  /// Member → Map 변환 (업데이트용)
  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'display_name': displayName,
      'tag': tag,
      'role': role,
      'state': state,
      'ready': ready,
      'invite_id': inviteId,
      'session_id': sessionId,
    };
  }

  /// 자리 확정된 상태인지
  bool get isJoined => state == 'joined';

  /// 관전 중인 상태인지
  bool get isWatching => state == 'watching';

  /// copyWith 메서드
  Member copyWith({
    String? id,
    String? roomId,
    String? displayName,
    String? tag,
    String? role,
    String? state,
    bool? ready,
    String? inviteId,
    String? sessionId,
  }) {
    return Member(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      displayName: displayName ?? this.displayName,
      tag: tag ?? this.tag,
      role: role ?? this.role,
      state: state ?? this.state,
      ready: ready ?? this.ready,
      inviteId: inviteId ?? this.inviteId,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}
