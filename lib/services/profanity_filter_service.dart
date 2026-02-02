/// 욕설/비속어 필터링 서비스
class ProfanityFilterService {
  // 금칙어 목록 (기본)
  static const List<String> _blockedWords = [
    // 한국어 비속어
    '시발', '씨발', '씹', '좆', '병신', '지랄', '개새끼', '새끼',
    '느금마', '니미', '엠창', '썅', '쌍년', '쌍놈', '미친놈', '미친년',
    '장애인', '애자', '등신', '찐따', '한남', '한녀', '김치녀', '된장녀',
    '맘충', '틀딱', '급식충', '일베', '메갈',
    // 변형 (띄어쓰기, 특수문자 포함)
    'ㅅㅂ', 'ㅂㅅ', 'ㅈㄹ', 'ㅗ', 'ㅆㅂ', 'ㅅㅍ', 'ㄴㄱㅁ',
    // 영어 비속어
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy', 'cock',
    'nigger', 'faggot', 'retard', 'cunt',
  ];

  // 필터링 대체 문자
  static const String _replacement = '***';

  /// 텍스트에 금칙어가 포함되어 있는지 확인
  static bool containsProfanity(String text) {
    final lowerText = text.toLowerCase();
    final normalizedText = _normalizeText(lowerText);

    for (final word in _blockedWords) {
      if (normalizedText.contains(word.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 금칙어를 필터링하여 대체
  static String filter(String text) {
    String result = text;
    final lowerText = text.toLowerCase();

    for (final word in _blockedWords) {
      final lowerWord = word.toLowerCase();
      // 대소문자 무시하고 찾아서 대체
      final regex = RegExp(RegExp.escape(lowerWord), caseSensitive: false);
      result = result.replaceAll(regex, _replacement);
    }

    return result;
  }

  /// 방 이름 유효성 검사
  /// 반환: null이면 유효, 문자열이면 에러 메시지
  static String? validateRoomName(String? roomName) {
    if (roomName == null || roomName.trim().isEmpty) {
      return '방 이름을 입력해주세요.';
    }

    final trimmed = roomName.trim();

    // 길이 검사 (20자 제한)
    if (trimmed.length > 20) {
      return '방 이름은 20자 이내로 입력해주세요.';
    }

    // 최소 길이 검사
    if (trimmed.length < 2) {
      return '방 이름은 2자 이상 입력해주세요.';
    }

    // 금칙어 검사
    if (containsProfanity(trimmed)) {
      return '부적절한 단어가 포함되어 있습니다.';
    }

    return null; // 유효함
  }

  /// 닉네임 유효성 검사
  static String? validateNickname(String? nickname) {
    if (nickname == null || nickname.trim().isEmpty) {
      return '닉네임을 입력해주세요.';
    }

    final trimmed = nickname.trim();

    if (trimmed.length > 20) {
      return '닉네임은 20자 이내로 입력해주세요.';
    }

    if (containsProfanity(trimmed)) {
      return '부적절한 단어가 포함되어 있습니다.';
    }

    return null;
  }

  /// 텍스트 정규화 (특수문자, 공백 제거)
  static String _normalizeText(String text) {
    // 공백 제거
    String result = text.replaceAll(RegExp(r'\s+'), '');
    // 특수문자를 유사한 글자로 변환
    result = result
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's');
    return result;
  }
}
