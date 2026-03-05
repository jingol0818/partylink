class TrapCard {
  final String id;
  final String category; // context | speed | memory | emotion | logic
  final String question;

  TrapCard({
    required this.id,
    required this.category,
    required this.question,
  });

  factory TrapCard.fromMap(Map<String, dynamic> map) {
    return TrapCard(
      id: map['id'] as String,
      category: map['category'] as String,
      question: map['question'] as String,
    );
  }

  String get categoryLabel => switch (category) {
    'context' => '맥락',
    'speed' => '속도',
    'memory' => '기억',
    'emotion' => '감정',
    'logic' => '논리',
    _ => category,
  };

  String get categoryEmoji => switch (category) {
    'context' => '🔍',
    'speed' => '⚡',
    'memory' => '🧠',
    'emotion' => '💜',
    'logic' => '🧩',
    _ => '🃏',
  };
}

class TrapAnswer {
  final String id;
  final String gameId;
  final int round;
  final String cardId;
  final String askerId;
  final String targetId;
  final String? answer;
  final DateTime? answeredAt;
  final DateTime createdAt;

  // 조인된 카드 정보 (옵션)
  final String? category;
  final String? question;

  TrapAnswer({
    required this.id,
    required this.gameId,
    required this.round,
    required this.cardId,
    required this.askerId,
    required this.targetId,
    this.answer,
    this.answeredAt,
    required this.createdAt,
    this.category,
    this.question,
  });

  factory TrapAnswer.fromMap(Map<String, dynamic> map) {
    return TrapAnswer(
      id: map['id'] as String,
      gameId: map['game_id'] as String,
      round: map['round'] as int? ?? 1,
      cardId: map['card_id'] as String,
      askerId: map['asker_id'] as String,
      targetId: map['target_id'] as String,
      answer: map['answer'] as String?,
      answeredAt: map['answered_at'] != null
          ? DateTime.parse(map['answered_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      category: map['category'] as String?,
      question: map['question'] as String?,
    );
  }

  bool get isAnswered => answer != null;
}
