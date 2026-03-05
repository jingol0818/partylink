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

  /// 최대 라운드 수 (2인→1R, 3인+→2R)
  int get maxRounds => playerCount <= 2 ? 1 : 2;

  /// 다음 라운드 존재 여부
  bool get hasNextRound => round < maxRounds;

  /// 인원 기반 대화 시간 (초)
  int get chattingSeconds => switch (playerCount) {
    <= 2 => 90,
    3 => 120,
    4 => 150,
    _ => 180,
  };

  /// 인원 기반 투표 시간 (초)
  int get votingSeconds => switch (playerCount) {
    <= 2 => 15,
    3 => 20,
    4 => 25,
    _ => 30,
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
