/// 게임 정보 모델
class Game {
  final String key;
  final String name;
  final String icon;
  final List<GameMode> modes;

  const Game({
    required this.key,
    required this.name,
    required this.icon,
    required this.modes,
  });
}

/// 게임 모드 정보
class GameMode {
  final String key;
  final String name;
  final List<String> slots;
  final int maxMembers;

  const GameMode({
    required this.key,
    required this.name,
    required this.slots,
    required this.maxMembers,
  });
}

/// 목표(분위기) 옵션
class GameGoal {
  final String key;
  final String name;
  final String description;

  const GameGoal({
    required this.key,
    required this.name,
    required this.description,
  });
}

/// 지원하는 게임 목록
class GameData {
  static const List<Game> games = [
    Game(
      key: 'lol',
      name: 'League of Legends',
      icon: '🎮',
      modes: [
        GameMode(
          key: 'ranked',
          name: '솔로/듀오 랭크',
          slots: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUP'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'flex',
          name: '자유 랭크',
          slots: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUP'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'normal',
          name: '일반 게임',
          slots: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUP'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'aram',
          name: '칼바람 나락',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
        ),
      ],
    ),
    Game(
      key: 'valorant',
      name: 'VALORANT',
      icon: '🔫',
      modes: [
        GameMode(
          key: 'competitive',
          name: '경쟁전',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'unrated',
          name: '일반전',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'spike_rush',
          name: '스파이크 러시',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
        ),
      ],
    ),
    Game(
      key: 'overwatch',
      name: 'Overwatch 2',
      icon: '🦸',
      modes: [
        GameMode(
          key: 'competitive',
          name: '경쟁전',
          slots: ['TANK', 'DPS1', 'DPS2', 'SUP1', 'SUP2'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'quickplay',
          name: '빠른 대전',
          slots: ['TANK', 'DPS1', 'DPS2', 'SUP1', 'SUP2'],
          maxMembers: 5,
        ),
        GameMode(
          key: 'arcade',
          name: '아케이드',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'],
          maxMembers: 6,
        ),
      ],
    ),
    Game(
      key: 'pubg',
      name: 'PUBG',
      icon: '🪖',
      modes: [
        GameMode(
          key: 'squad',
          name: '스쿼드',
          slots: ['P1', 'P2', 'P3', 'P4'],
          maxMembers: 4,
        ),
        GameMode(
          key: 'duo',
          name: '듀오',
          slots: ['P1', 'P2'],
          maxMembers: 2,
        ),
      ],
    ),
    Game(
      key: 'apex',
      name: 'Apex Legends',
      icon: '🏃',
      modes: [
        GameMode(
          key: 'ranked',
          name: '랭크',
          slots: ['P1', 'P2', 'P3'],
          maxMembers: 3,
        ),
        GameMode(
          key: 'trios',
          name: '트리오',
          slots: ['P1', 'P2', 'P3'],
          maxMembers: 3,
        ),
        GameMode(
          key: 'duos',
          name: '듀오',
          slots: ['P1', 'P2'],
          maxMembers: 2,
        ),
      ],
    ),
  ];

  static const List<GameGoal> goals = [
    GameGoal(
      key: 'tryhard',
      name: '빡겜',
      description: '승리에 집중하며 진지하게 플레이',
    ),
    GameGoal(
      key: 'chill',
      name: '즐겜',
      description: '편하게 즐기며 게임',
    ),
    GameGoal(
      key: 'practice',
      name: '연습',
      description: '새로운 챔피언이나 전략 연습',
    ),
  ];

  /// 게임 키로 게임 찾기
  static Game? findGame(String key) {
    try {
      return games.firstWhere((g) => g.key == key);
    } catch (_) {
      return null;
    }
  }

  /// 목표 키로 목표 찾기
  static GameGoal? findGoal(String key) {
    try {
      return goals.firstWhere((g) => g.key == key);
    } catch (_) {
      return null;
    }
  }
}
