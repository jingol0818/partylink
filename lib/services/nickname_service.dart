import 'dart:math';

/// 랜덤 닉네임 + 아바타 생성 서비스
///
/// PRD 9장 기반: 형용사+동물 조합 닉네임, 도형×색상 아바타
/// v2.1: 아바타 이모지와 닉네임 동물 일치
class NicknameService {
  static final _random = Random();

  static const _adjectives = [
    '잠자는', '배고픈', '신나는', '졸린', '용감한',
    '수상한', '조용한', '웃긴', '빠른', '느긋한',
    '똑똑한', '엉뚱한', '귀여운', '무서운', '행복한',
    '심심한', '바쁜', '한가한', '당당한', '소심한',
  ];

  static const shapes = ['circle', 'triangle', 'square', 'diamond', 'star'];

  static const colors = [
    '#FF4757', '#3742FA', '#2ED573', '#FFA502',
    '#8B5CF6', '#FF6B9D', '#00D2D3', '#FF793F',
  ];

  /// shape → 한국어 동물 이름 매핑 (아바타 이모지와 동일)
  /// circle→🐱고양이, triangle→🐶강아지, square→🐰토끼, diamond→🦊여우, star→🐻곰
  static const _shapeToAnimal = {
    'circle': '고양이',
    'triangle': '강아지',
    'square': '토끼',
    'diamond': '여우',
    'star': '곰',
  };

  /// shape에 맞는 동물 이름 반환
  static String animalForShape(String shape) {
    return _shapeToAnimal[shape] ?? '고양이';
  }

  /// 랜덤 닉네임 생성 (형용사 + shape에 맞는 동물, 띄어쓰기 포함)
  static String generateNickname({String? shape}) {
    final adj = _adjectives[_random.nextInt(_adjectives.length)];
    final animal = shape != null
        ? animalForShape(shape)
        : _shapeToAnimal.values.elementAt(
            _random.nextInt(_shapeToAnimal.length));
    return '$adj $animal';
  }

  /// 랜덤 아바타 생성 (도형+색상)
  static ({String shape, String color}) generateAvatar() {
    return (
      shape: shapes[_random.nextInt(shapes.length)],
      color: colors[_random.nextInt(colors.length)],
    );
  }
}
