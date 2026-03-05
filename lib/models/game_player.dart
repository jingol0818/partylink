/// 게임 참가자 모델
///
/// DB VIEW `game_players_safe` 기반 (is_ai는 result phase에서만 노출)
class GamePlayer {
  final String id;
  final String gameId;
  final String? sessionId;
  final bool? isAi;         // null until result phase (VIEW masks it)
  final String? personaId;
  final String nickname;
  final String avatarShape;  // circle | triangle | square | diamond | star
  final String avatarColor;  // hex color
  final String? votedFor;
  final int score;
  final bool isConnected;
  final DateTime createdAt;

  GamePlayer({
    required this.id,
    required this.gameId,
    this.sessionId,
    this.isAi,
    this.personaId,
    required this.nickname,
    required this.avatarShape,
    required this.avatarColor,
    this.votedFor,
    required this.score,
    required this.isConnected,
    required this.createdAt,
  });

  factory GamePlayer.fromMap(Map<String, dynamic> m) => GamePlayer(
        id: m['id'].toString(),
        gameId: m['game_id'].toString(),
        sessionId: m['session_id']?.toString(),
        isAi: m['is_ai'] as bool?,
        personaId: m['persona_id']?.toString(),
        nickname: m['nickname'].toString(),
        avatarShape: m['avatar_shape'].toString(),
        avatarColor: m['avatar_color'].toString(),
        votedFor: m['voted_for']?.toString(),
        score: (m['score'] as num?)?.toInt() ?? 0,
        isConnected: (m['is_connected'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'game_id': gameId,
        'session_id': sessionId,
        'nickname': nickname,
        'avatar_shape': avatarShape,
        'avatar_color': avatarColor,
      };

  bool get isMe => sessionId != null;
  bool get hasVoted => votedFor != null;

  GamePlayer copyWith({
    String? id,
    String? gameId,
    String? sessionId,
    bool? isAi,
    String? personaId,
    String? nickname,
    String? avatarShape,
    String? avatarColor,
    String? votedFor,
    int? score,
    bool? isConnected,
    DateTime? createdAt,
  }) {
    return GamePlayer(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      sessionId: sessionId ?? this.sessionId,
      isAi: isAi ?? this.isAi,
      personaId: personaId ?? this.personaId,
      nickname: nickname ?? this.nickname,
      avatarShape: avatarShape ?? this.avatarShape,
      avatarColor: avatarColor ?? this.avatarColor,
      votedFor: votedFor ?? this.votedFor,
      score: score ?? this.score,
      isConnected: isConnected ?? this.isConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
