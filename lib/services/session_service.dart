/// 게스트 세션 관리 서비스
///
/// MVP: 메모리 기반으로 동작 (브라우저 새로고침 시 세션 소실)
/// TODO: shared_preferences 도입으로 브라우저 저장소에 유지
class SessionService {
  static String? _memberId;

  /// 현재 세션의 memberId 저장
  static void setMemberId(String id) => _memberId = id;

  /// 현재 세션의 memberId 조회
  static String? get memberId => _memberId;

  /// 세션 초기화 (로그아웃/퇴장 시)
  static void clear() => _memberId = null;

  /// 유효한 세션이 있는지 확인
  static bool get hasSession => _memberId != null;
}
