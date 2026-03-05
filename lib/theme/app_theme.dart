import 'package:flutter/material.dart';

/// 누가 AI야? Dark Cyber 팔레트
class CyberColors {
  // 배경
  static const Color bgPrimary = Color(0xFF0A0E1F);       // Deep Navy
  static const Color bgSurface = Color(0xFF141832);        // Dark Indigo
  static const Color bgSurfaceLight = Color(0xFF1E2346);   // Slate Blue
  static const Color bgCard = Color(0xFF111827);
  static const Color bgCardMedium = Color(0xFF1E293B);

  // 텍스트
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF8892B0);

  // 테두리
  static const Color borderSubtle = Color(0xFF2A3441);

  // 액센트
  static const Color accentTeal = Color(0xFF00D9FF);       // 주 액센트
  static const Color accentPurple = Color(0xFF8B5CF6);     // Neon Purple
  static const Color accentPink = Color(0xFFEC4899);       // Neon Pink

  // 상태
  static const Color successGreen = Color(0xFF10B981);
  static const Color neonGreen = Color(0xFF00FF88);        // HUMAN 스탬프
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color gmAmber = Color(0xFFFFB800);          // GM 메시지
  static const Color errorRed = Color(0xFFEF4444);
  static const Color alertRed = Color(0xFFFF4757);         // AI 스탬프
}

/// 라운드별 파스텔 그라데이션 + 색상 시스템
/// 비주얼 가이드 기반: 예능 프로그램 세트장 느낌
class GameRoundTheme {
  final List<Color> gradient;
  final Color textColor;
  final Color subTextColor;
  final Color bubbleBg;
  final Color bubbleBorder;
  final Color myBubbleBg;
  final Color myBubbleBorder;
  final Color topBarBg;
  final Color inputBarBg;
  final Color gmOverlayBg;
  final Color gmTextColor;
  final bool isDark;

  const GameRoundTheme({
    required this.gradient,
    required this.textColor,
    required this.subTextColor,
    required this.bubbleBg,
    required this.bubbleBorder,
    required this.myBubbleBg,
    required this.myBubbleBorder,
    required this.topBarBg,
    required this.inputBarBg,
    required this.gmOverlayBg,
    required this.gmTextColor,
    this.isDark = false,
  });

  /// 대기/매칭 (다크)
  static const waiting = GameRoundTheme(
    gradient: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    textColor: Color(0xFFF1F5F9),
    subTextColor: Color(0xFF94A3B8),
    bubbleBg: Color(0xFF1E293B),
    bubbleBorder: Color(0xFF2A3441),
    myBubbleBg: Color(0x3000D9FF),
    myBubbleBorder: Color(0x6000D9FF),
    topBarBg: Color(0xCC141832),
    inputBarBg: Color(0xCC141832),
    gmOverlayBg: Color(0xE6161B2E),
    gmTextColor: Color(0xFFFFB800),
    isDark: true,
  );

  /// Round 1 — 탐색 (민트 파스텔)
  static const round1 = GameRoundTheme(
    gradient: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
    textColor: Color(0xFF333333),
    subTextColor: Color(0xFF666666),
    bubbleBg: Color(0xCCFFFFFF),
    bubbleBorder: Color(0x30000000),
    myBubbleBg: Color(0xFF80DEEA),
    myBubbleBorder: Color(0xFF4DD0E1),
    topBarBg: Color(0xCCFFFFFF),
    inputBarBg: Color(0xCCFFFFFF),
    gmOverlayBg: Color(0xE6333333),
    gmTextColor: Color(0xFFFFD54F),
    isDark: false,
  );

  /// Round 2 — 심문 (코랄/오렌지 파스텔)
  static const round2 = GameRoundTheme(
    gradient: [Color(0xFFFFF3E0), Color(0xFFFFCC80)],
    textColor: Color(0xFF333333),
    subTextColor: Color(0xFF666666),
    bubbleBg: Color(0xCCFFFFFF),
    bubbleBorder: Color(0x30000000),
    myBubbleBg: Color(0xFFFFE0B2),
    myBubbleBorder: Color(0xFFFFB74D),
    topBarBg: Color(0xCCFFFFFF),
    inputBarBg: Color(0xCCFFFFFF),
    gmOverlayBg: Color(0xE6333333),
    gmTextColor: Color(0xFFFFD54F),
    isDark: false,
  );

  /// Round 3 / 최종투표 (핑크 파스텔)
  static const round3 = GameRoundTheme(
    gradient: [Color(0xFFFCE4EC), Color(0xFFF48FB1)],
    textColor: Color(0xFF333333),
    subTextColor: Color(0xFF666666),
    bubbleBg: Color(0xCCFFFFFF),
    bubbleBorder: Color(0x30000000),
    myBubbleBg: Color(0xFFF8BBD0),
    myBubbleBorder: Color(0xFFF06292),
    topBarBg: Color(0xCCFFFFFF),
    inputBarBg: Color(0xCCFFFFFF),
    gmOverlayBg: Color(0xE6333333),
    gmTextColor: Color(0xFFFFD54F),
    isDark: false,
  );

  /// 결과 발표 (라벤더 파스텔)
  static const result = GameRoundTheme(
    gradient: [Color(0xFFF3E5F5), Color(0xFFCE93D8)],
    textColor: Color(0xFF333333),
    subTextColor: Color(0xFF666666),
    bubbleBg: Color(0xCCFFFFFF),
    bubbleBorder: Color(0x30000000),
    myBubbleBg: Color(0xFFE1BEE7),
    myBubbleBorder: Color(0xFFBA68C8),
    topBarBg: Color(0xCCFFFFFF),
    inputBarBg: Color(0xCCFFFFFF),
    gmOverlayBg: Color(0xE6333333),
    gmTextColor: Color(0xFFFFD54F),
    isDark: false,
  );

  static const voting = round3;
  static const trapQuestion = round2;

  /// 로비/매칭 (밝은 파스텔 — 파티 느낌)
  static const lobby = GameRoundTheme(
    gradient: [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
    textColor: Color(0xFF2D3436),
    subTextColor: Color(0xFF636E72),
    bubbleBg: Color(0xCCFFFFFF),
    bubbleBorder: Color(0x30000000),
    myBubbleBg: Color(0xFF80CBC4),
    myBubbleBorder: Color(0xFF4DB6AC),
    topBarBg: Color(0xCCFFFFFF),
    inputBarBg: Color(0xCCFFFFFF),
    gmOverlayBg: Color(0xE6333333),
    gmTextColor: Color(0xFFFFD54F),
    isDark: false,
  );

  /// phase + round로 적절한 테마 반환
  static GameRoundTheme fromGame(String phase, int round) {
    switch (phase) {
      case 'waiting':
        return waiting;
      case 'chatting':
        if (round <= 1) return round1;
        if (round == 2) return round2;
        return round3;
      case 'trap_question':
        return trapQuestion;
      case 'voting':
        return voting;
      case 'result':
        return result;
      default:
        return waiting;
    }
  }

  /// 라운드 전환 텍스트
  static ({String main, String sub}) transitionText(String phase, int round) {
    switch (phase) {
      case 'chatting':
        if (round <= 1) return (main: 'ROUND 1', sub: '탐색 시작');
        if (round == 2) return (main: 'ROUND 2', sub: '심문 시작');
        return (main: 'FINAL ROUND', sub: '최종 대화');
      case 'trap_question':
        return (main: '⚡ 함정 카드', sub: '긴급 질문!');
      case 'voting':
        return (main: '🗳️ VOTE', sub: 'AI를 찾아라!');
      case 'result':
        return (main: '🎭 REVEAL', sub: '정체를 공개합니다');
      default:
        return (main: '준비', sub: '잠시만...');
    }
  }
}

/// PartyLink 디자인 시스템 색상 (다크 모드)
class AppColorsDark {
  // 배경 색상
  static const Color bgPage = Color(0xFF0D0D0F);
  static const Color bgCard = Color(0xFF1A1A1E);
  static const Color bgElevated = Color(0xFF222226);
  static const Color bgInput = Color(0xFF16161A);

  // 텍스트 색상
  static const Color textPrimary = Color(0xFFFAFAF9);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF636366);
  static const Color textMuted = Color(0xFF48484A);

  // 테두리 색상
  static const Color borderSubtle = Color(0xFF2C2C2E);
  static const Color borderStrong = Color(0xFF3A3A3C);

  // 액센트 색상
  static const Color accentPurple = Color(0xFFBF9FFF);
  static const Color accentPurpleDark = Color(0xFF9F7AEA);
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentRed = Color(0xFFFF453A);
  static const Color accentBlue = Color(0xFF0A84FF);
}

/// PartyLink 디자인 시스템 색상 (라이트 모드)
class AppColorsLight {
  // 배경 색상
  static const Color bgPage = Color(0xFFF2F2F7);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgElevated = Color(0xFFE8E8ED);
  static const Color bgInput = Color(0xFFF5F5F7);

  // 텍스트 색상
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF48484A);
  static const Color textTertiary = Color(0xFF6E6E73);
  static const Color textMuted = Color(0xFF8E8E93);

  // 테두리 색상
  static const Color borderSubtle = Color(0xFFD1D1D6);
  static const Color borderStrong = Color(0xFFC7C7CC);

  // 액센트 색상
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentPurpleDark = Color(0xFF6D28D9);
  static const Color accentGreen = Color(0xFF30A14E);
  static const Color accentOrange = Color(0xFFE85D04);
  static const Color accentRed = Color(0xFFDC2626);
  static const Color accentBlue = Color(0xFF0066CC);
}

/// 동적 색상 접근자 (현재 테마에 맞는 색상 반환)
class AppColors {
  static bool _isDark = true;

  static void setDarkMode(bool isDark) {
    _isDark = isDark;
  }

  static bool get isDark => _isDark;

  // 배경 색상
  static Color get bgPage => _isDark ? AppColorsDark.bgPage : AppColorsLight.bgPage;
  static Color get bgCard => _isDark ? AppColorsDark.bgCard : AppColorsLight.bgCard;
  static Color get bgElevated => _isDark ? AppColorsDark.bgElevated : AppColorsLight.bgElevated;
  static Color get bgInput => _isDark ? AppColorsDark.bgInput : AppColorsLight.bgInput;

  // 텍스트 색상
  static Color get textPrimary => _isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary;
  static Color get textSecondary => _isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary;
  static Color get textTertiary => _isDark ? AppColorsDark.textTertiary : AppColorsLight.textTertiary;
  static Color get textMuted => _isDark ? AppColorsDark.textMuted : AppColorsLight.textMuted;

  // 테두리 색상
  static Color get borderSubtle => _isDark ? AppColorsDark.borderSubtle : AppColorsLight.borderSubtle;
  static Color get borderStrong => _isDark ? AppColorsDark.borderStrong : AppColorsLight.borderStrong;

  // 액센트 색상
  static Color get accentPurple => _isDark ? AppColorsDark.accentPurple : AppColorsLight.accentPurple;
  static Color get accentPurpleDark => _isDark ? AppColorsDark.accentPurpleDark : AppColorsLight.accentPurpleDark;
  static Color get accentGreen => _isDark ? AppColorsDark.accentGreen : AppColorsLight.accentGreen;
  static Color get accentOrange => _isDark ? AppColorsDark.accentOrange : AppColorsLight.accentOrange;
  static Color get accentRed => _isDark ? AppColorsDark.accentRed : AppColorsLight.accentRed;
  static Color get accentBlue => _isDark ? AppColorsDark.accentBlue : AppColorsLight.accentBlue;
}

/// PartyLink 테마
class AppTheme {
  static ThemeData get darkTheme => _buildTheme(true);
  static ThemeData get lightTheme => _buildTheme(false);

  static ThemeData _buildTheme(bool isDark) {
    final bgPage = isDark ? AppColorsDark.bgPage : AppColorsLight.bgPage;
    final bgCard = isDark ? AppColorsDark.bgCard : AppColorsLight.bgCard;
    final bgElevated = isDark ? AppColorsDark.bgElevated : AppColorsLight.bgElevated;
    final bgInput = isDark ? AppColorsDark.bgInput : AppColorsLight.bgInput;
    final textPrimary = isDark ? AppColorsDark.textPrimary : AppColorsLight.textPrimary;
    final textSecondary = isDark ? AppColorsDark.textSecondary : AppColorsLight.textSecondary;
    final textTertiary = isDark ? AppColorsDark.textTertiary : AppColorsLight.textTertiary;
    final textMuted = isDark ? AppColorsDark.textMuted : AppColorsLight.textMuted;
    final borderSubtle = isDark ? AppColorsDark.borderSubtle : AppColorsLight.borderSubtle;
    final borderStrong = isDark ? AppColorsDark.borderStrong : AppColorsLight.borderStrong;
    final accentPurple = isDark ? AppColorsDark.accentPurple : AppColorsLight.accentPurple;
    final accentPurpleDark = isDark ? AppColorsDark.accentPurpleDark : AppColorsLight.accentPurpleDark;
    final accentRed = isDark ? AppColorsDark.accentRed : AppColorsLight.accentRed;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgPage,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: accentPurple,
              secondary: accentPurpleDark,
              surface: bgCard,
              error: accentRed,
              onPrimary: bgPage,
              onSecondary: textPrimary,
              onSurface: textPrimary,
              onError: textPrimary,
            )
          : ColorScheme.light(
              primary: accentPurple,
              secondary: accentPurpleDark,
              surface: bgCard,
              error: accentRed,
              onPrimary: Colors.white,
              onSecondary: textPrimary,
              onSurface: textPrimary,
              onError: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPage,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPurple,
          foregroundColor: isDark ? bgPage : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: borderSubtle),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentPurple, width: 2),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: textSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPurple;
          }
          return bgElevated;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPurple;
          }
          return borderStrong;
        }),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: borderSubtle,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
    );
  }
}
