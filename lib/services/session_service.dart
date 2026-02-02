import 'dart:math';

/// 게스트 세션 관리 서비스
///
/// MVP: 메모리 기반으로 동작 (브라우저 새로고침 시 세션 소실)
class SessionService {
  static String? _memberId;
  static String? _sessionId;

  /// 세션 ID 초기화 (앱 시작 시 호출)
  static void _ensureSessionId() {
    if (_sessionId == null) {
      // 랜덤 세션 ID 생성
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final random = Random();
      _sessionId = List.generate(
        16,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
    }
  }

  /// 현재 세션 ID (방장 확인, 퇴장 처리 등에 사용)
  static String get sessionId {
    _ensureSessionId();
    return _sessionId!;
  }

  /// 현재 세션의 memberId 저장
  static void setMemberId(String id) => _memberId = id;

  /// 현재 세션의 memberId 조회
  static String? get memberId => _memberId;

  /// 세션 초기화 (로그아웃/퇴장 시)
  static void clear() {
    _memberId = null;
    // sessionId는 유지 (같은 브라우저 세션에서는 동일한 ID 사용)
  }

  /// 유효한 세션이 있는지 확인
  static bool get hasSession => _memberId != null;
}
