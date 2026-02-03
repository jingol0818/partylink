import 'package:flutter/material.dart';

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
    final colors = isDark ? AppColorsDark : AppColorsLight;
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
