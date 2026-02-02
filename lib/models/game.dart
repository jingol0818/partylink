/// 게임 정보 모델
class Game {
  final String key;
  final String name;
  final String icon;
  final List<GameMode> modes;
  final bool hasMode; // 모드 선택이 필요한지 여부
  final int defaultTeamCount; // 기본 팀 수
  final int defaultMembersPerTeam; // 기본 팀당 인원

  // 팀/인원 제한 상수
  static const int maxTeamCount = 4;
  static const int maxMembersPerTeam = 8;

  const Game({
    required this.key,
    required this.name,
    required this.icon,
    required this.modes,
    this.hasMode = true,
    this.defaultTeamCount = 1,
    this.defaultMembersPerTeam = 5,
  });

  /// 게임 모드에 맞는 슬롯 이름 생성
  List<String> generateSlotNames({
    String? modeKey,
    required int teamCount,
    required int membersPerTeam,
  }) {
    // 모드가 있으면 해당 모드의 기본 슬롯 패턴 사용
    if (modeKey != null && modes.isNotEmpty) {
      final mode = modes.where((m) => m.key == modeKey).firstOrNull;
      if (mode != null) {
        // 롤/발로 기본 역할이 있는 경우 (TOP, JUNGLE 등)
        if (teamCount == 1 && membersPerTeam == mode.membersPerTeam) {
          return mode.slots;
        }
      }
    }

    // 그 외에는 기본 슬롯 이름 생성
    return GameData.generateSlotNames(teamCount, membersPerTeam);
  }
}

/// 게임 모드 정보
class GameMode {
  final String key;
  final String name;
  final List<String> slots;
  final int maxMembers;
  final int teamCount; // 팀 수 (내전용)
  final int membersPerTeam; // 팀당 인원

  const GameMode({
    required this.key,
    required this.name,
    required this.slots,
    required this.maxMembers,
    this.teamCount = 1,
    this.membersPerTeam = 5,
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
  // 팀/인원 제한
  static const int maxTeamCount = 4;
  static const int maxMembersPerTeam = 8;

  static const List<Game> games = [
    // 종합 게임 (범용)
    Game(
      key: 'general',
      name: '종합 게임',
      icon: '🎯',
      modes: [], // 모드 없음
      hasMode: false,
      defaultTeamCount: 1,
      defaultMembersPerTeam: 2,
    ),
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
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'flex',
          name: '자유 랭크',
          slots: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUP'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'normal',
          name: '일반 게임',
          slots: ['TOP', 'JUNGLE', 'MID', 'ADC', 'SUP'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'aram',
          name: '칼바람 나락',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'asura',
          name: '아수라장',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'custom',
          name: '내전',
          slots: ['팀1-1', '팀1-2', '팀1-3', '팀1-4', '팀1-5', '팀2-1', '팀2-2', '팀2-3', '팀2-4', '팀2-5'],
          maxMembers: 10,
          teamCount: 2,
          membersPerTeam: 5,
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
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'unrated',
          name: '일반전',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'spike_rush',
          name: '스파이크 러시',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'custom',
          name: '내전',
          slots: ['팀1-1', '팀1-2', '팀1-3', '팀1-4', '팀1-5', '팀2-1', '팀2-2', '팀2-3', '팀2-4', '팀2-5'],
          maxMembers: 10,
          teamCount: 2,
          membersPerTeam: 5,
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
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'quickplay',
          name: '빠른 대전',
          slots: ['TANK', 'DPS1', 'DPS2', 'SUP1', 'SUP2'],
          maxMembers: 5,
          teamCount: 1,
          membersPerTeam: 5,
        ),
        GameMode(
          key: 'arcade',
          name: '아케이드',
          slots: ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'],
          maxMembers: 6,
          teamCount: 1,
          membersPerTeam: 6,
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
          teamCount: 1,
          membersPerTeam: 4,
        ),
        GameMode(
          key: 'duo',
          name: '듀오',
          slots: ['P1', 'P2'],
          maxMembers: 2,
          teamCount: 1,
          membersPerTeam: 2,
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
          teamCount: 1,
          membersPerTeam: 3,
        ),
        GameMode(
          key: 'trios',
          name: '트리오',
          slots: ['P1', 'P2', 'P3'],
          maxMembers: 3,
          teamCount: 1,
          membersPerTeam: 3,
        ),
        GameMode(
          key: 'duos',
          name: '듀오',
          slots: ['P1', 'P2'],
          maxMembers: 2,
          teamCount: 1,
          membersPerTeam: 2,
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
      description: '새로운 캐릭터나 전략 연습',
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

  /// 팀 수와 팀당 인원으로 슬롯 이름 생성
  static List<String> generateSlotNames(int teamCount, int membersPerTeam) {
    final List<String> slots = [];
    if (teamCount == 1) {
      for (int i = 1; i <= membersPerTeam; i++) {
        slots.add('P$i');
      }
    } else {
      for (int t = 1; t <= teamCount; t++) {
        for (int m = 1; m <= membersPerTeam; m++) {
          slots.add('팀$t-$m');
        }
      }
    }
    return slots;
  }
}
