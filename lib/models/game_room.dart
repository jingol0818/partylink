/// 게임 세션 모델
///
/// DB 테이블 `games`와 1:1 대응
class GameRoom {
  final String id;
  final String code;
  final String status;    // waiting | active | finished
  final String phase;     // waiting | chatting | trap_question | voting | result
  final int round;
  final int playerCount;
  final int aiCount;
  final String? topic;
  final DateTime? phaseEndsAt;
  final DateTime createdAt;
  final DateTime? finishedAt;

  GameRoom({
    required this.id,
    required this.code,
    required this.status,
    required this.phase,
    required this.round,
    required this.playerCount,
    required this.aiCount,
    this.topic,
    this.phaseEndsAt,
    required this.createdAt,
    this.finishedAt,
  });

  factory GameRoom.fromMap(Map<String, dynamic> m) => GameRoom(
        id: m['id'].toString(),
        code: m['code'].toString(),
        status: m['status'].toString(),
        phase: m['phase'].toString(),
        round: (m['round'] as num?)?.toInt() ?? 1,
        playerCount: (m['player_count'] as num?)?.toInt() ?? 1,
        aiCount: (m['ai_count'] as num?)?.toInt() ?? 1,
        topic: m['topic']?.toString(),
        phaseEndsAt: m['phase_ends_at'] != null
            ? DateTime.parse(m['phase_ends_at'].toString())
            : null,
        createdAt: DateTime.parse(m['created_at'].toString()),
        finishedAt: m['finished_at'] != null
            ? DateTime.parse(m['finished_at'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'status': status,
        'phase': phase,
        'round': round,
        'player_count': playerCount,
        'ai_count': aiCount,
        'topic': topic,
        'phase_ends_at': phaseEndsAt?.toIso8601String(),
        'finished_at': finishedAt?.toIso8601String(),
      };

  bool get isWaiting => phase == 'waiting';
  bool get isChatting => phase == 'chatting';
  bool get isTrapQuestion => phase == 'trap_question';
  bool get isVoting => phase == 'voting';
  bool get isResult => phase == 'result';
  bool get isFinished => status == 'finished';

  /// 총 인원 (인간 + AI)
  int get totalPlayers => playerCount + aiCount;

  /// 최대 라운드 수 (2인→2R, 3인+→3R)
  int get maxRounds => totalPlayers <= 2 ? 2 : 3;

  /// 다음 라운드 존재 여부
  bool get hasNextRound => round < maxRounds;

  /// 현재 라운드가 최종 라운드인지
  bool get isFinalRound => round >= maxRounds;

  /// 라운드별 대화 시간 (초)
  /// R1: 탐색(90s) / R2: 반론(60s) / R3: 최종심판(45s)
  int get chattingSeconds => switch (round) {
    1 => 90,
    2 => 60,
    _ => 45,
  };

  /// 라운드별 투표 시간 (초)
  /// R1 중간투표: 20s / 최종투표: 30s
  int get votingSeconds => switch (round) {
    1 => 20,   // 중간투표
    _ => 30,   // 최종투표
  };

  /// 라운드 이름
  String get roundName => switch (round) {
    1 => '탐색',
    2 => '반론',
    3 => '최종 심판',
    _ => '라운드 $round',
  };

  GameRoom copyWith({
    String? id,
    String? code,
    String? status,
    String? phase,
    int? round,
    int? playerCount,
    int? aiCount,
    String? topic,
    DateTime? phaseEndsAt,
    DateTime? createdAt,
    DateTime? finishedAt,
  }) {
    return GameRoom(
      id: id ?? this.id,
      code: code ?? this.code,
      status: status ?? this.status,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      playerCount: playerCount ?? this.playerCount,
      aiCount: aiCount ?? this.aiCount,
      topic: topic ?? this.topic,
      phaseEndsAt: phaseEndsAt ?? this.phaseEndsAt,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
