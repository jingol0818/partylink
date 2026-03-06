import 'package:flutter/material.dart';
import '../models/player_stats.dart';
import '../theme/app_theme.dart';

/// 리더보드 위젯 (로비에 표시)
class LeaderboardWidget extends StatelessWidget {
  final List<PlayerStats> leaderboard;
  final bool isLoading;

  const LeaderboardWidget({
    super.key,
    required this.leaderboard,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: CyberColors.accentTeal),
        ),
      );
    }

    if (leaderboard.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '아직 기록이 없습니다.\n게임을 플레이해보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: CyberColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        // 헤더
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 32, child: Text('순위', style: _headerStyle)),
              Expanded(child: Text('닉네임', style: _headerStyle)),
              SizedBox(width: 60, child: Text('점수', textAlign: TextAlign.right, style: _headerStyle)),
              SizedBox(width: 48, child: Text('승률', textAlign: TextAlign.right, style: _headerStyle)),
            ],
          ),
        ),
        const Divider(color: CyberColors.borderSubtle, height: 1),
        // 목록
        ...leaderboard.take(10).map((stat) => _buildRow(stat)),
      ],
    );
  }

  Widget _buildRow(PlayerStats stat) {
    final isTop3 = stat.rank <= 3;
    final rankIcon = switch (stat.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${stat.rank}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3 ? CyberColors.accentTeal.withAlpha(8) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: CyberColors.borderSubtle.withAlpha(60)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              rankIcon,
              style: TextStyle(
                fontFamily: isTop3 ? null : 'Pretendard',
                fontSize: isTop3 ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: isTop3 ? null : CyberColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              stat.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400,
                color: isTop3 ? CyberColors.textPrimary : CyberColors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${stat.totalScore}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isTop3 ? CyberColors.accentTeal : CyberColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${(stat.winRate * 100).toInt()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CyberColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: CyberColors.textMuted,
  );
}
