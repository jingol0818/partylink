import 'dart:math';

/// 랜덤 닉네임 + 아바타 생성 서비스
///
/// PRD 9장 기반: 형용사+동물 조합 닉네임, 도형×색상 아바타
class NicknameService {
  static final _random = Random();

  static const _adjectives = [
    '잠자는', '배고픈', '신나는', '졸린', '용감한',
    '수상한', '조용한', '웃긴', '빠른', '느긋한',
    '똑똑한', '엉뚱한', '귀여운', '무서운', '행복한',
    '심심한', '바쁜', '한가한', '당당한', '소심한',
  ];

  static const _animals = [
    '호랑이', '펭귄', '고양이', '강아지', '토끼',
    '여우', '곰', '판다', '햄스터', '부엉이',
    '사자', '코끼리', '돌고래', '다람쥐', '수달',
    '앵무새', '미어캣', '카멜레온', '너구리', '오리',
  ];

  static const shapes = ['circle', 'triangle', 'square', 'diamond', 'star'];

  static const colors = [
    '#FF4757', '#3742FA', '#2ED573', '#FFA502',
    '#8B5CF6', '#FF6B9D', '#00D2D3', '#FF793F',
  ];

  /// 랜덤 닉네임 생성 (형용사+동물)
  static String generateNickname() {
    final adj = _adjectives[_random.nextInt(_adjectives.length)];
    final animal = _animals[_random.nextInt(_animals.length)];
    return '$adj$animal';
  }

  /// 랜덤 아바타 생성 (도형+색상)
  static ({String shape, String color}) generateAvatar() {
    return (
      shape: shapes[_random.nextInt(shapes.length)],
      color: colors[_random.nextInt(colors.length)],
    );
  }
}
