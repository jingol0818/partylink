class PlayerStats {
  final int rank;
  final String displayName;
  final int totalGames;
  final int totalWins;
  final int totalScore;
  final int bestStreak;

  PlayerStats({
    required this.rank,
    required this.displayName,
    required this.totalGames,
    required this.totalWins,
    required this.totalScore,
    required this.bestStreak,
  });

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      rank: map['rank'] as int? ?? 0,
      displayName: map['display_name'] as String? ?? '',
      totalGames: map['total_games'] as int? ?? 0,
      totalWins: map['total_wins'] as int? ?? 0,
      totalScore: map['total_score'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
    );
  }

  double get winRate => totalGames > 0 ? totalWins / totalGames : 0;
}
