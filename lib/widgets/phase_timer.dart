import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 페이즈 카운트다운 타이머 위젯
///
/// 남은 시간을 바 + 텍스트로 표시
/// 시간이 줄어들수록 Teal → Red 그라데이션
/// 라이트/다크 모드 대응
class PhaseTimer extends StatelessWidget {
  final Duration remaining;
  final Duration total;
  final bool isDark;

  const PhaseTimer({
    super.key,
    required this.remaining,
    required this.total,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total.inSeconds > 0
        ? (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    // 다크: Teal → Red, 라이트: 초록 → 빨강
    final Color normalColor = isDark
        ? CyberColors.accentTeal
        : const Color(0xFF00897B);
    final Color dangerColor = isDark
        ? CyberColors.errorRed
        : const Color(0xFFC62828);
    final color = progress > 0.3 ? normalColor : dangerColor;

    final seconds = remaining.inSeconds;
    final timeText = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

    // 10초 이하: 텍스트 크기 키우기 + 펄스 효과
    final isUrgent = seconds <= 10 && seconds > 0;

    return Column(
      children: [
        // 시간 텍스트
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: isUrgent ? 22 : 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          child: Text(timeText),
        ),
        const SizedBox(height: 6),
        // 프로그레스 바
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark
                ? CyberColors.borderSubtle
                : Colors.black.withAlpha(20),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: isUrgent ? 6 : 4,
          ),
        ),
      ],
    );
  }
}
