import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../theme/app_theme.dart';

/// 홈 화면 — 앱 진입점
///
/// "방 만들기" 버튼으로 파티 생성 플로우를 시작합니다.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme.of(context)를 통해 현재 테마 감지 (리빌드 트리거)
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final appState = PartyLinkApp.of(context);

    // 테마에 따른 색상 직접 참조
    final bgPage = isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF2F2F7);
    final bgElevated = isDark ? const Color(0xFF222226) : const Color(0xFFE8E8ED);
    final textPrimary = isDark ? const Color(0xFFFAFAF9) : const Color(0xFF1C1C1E);
    final textSecondary = isDark ? const Color(0xFF8E8E93) : const Color(0xFF48484A);
    final accentPurple = isDark ? const Color(0xFFBF9FFF) : const Color(0xFF7C3AED);
    final borderSubtle = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD1D1D6);

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 로고 + 테마 토글
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PartyLink',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  // 테마 토글 버튼
                  Material(
                    color: bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        appState?.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 중앙 콘텐츠 + 버튼
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 로고 이미지 (투명 배경)
                        Image.asset(
                          'assets/images/logo_v3.png',
                          width: 360,
                          height: 360,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 24),

                        // 타이틀
                        Text(
                          '링크로 파티 모으기',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 설명
                        Text(
                          '방을 만들고, 링크를 공유하고, 파티원을 모아보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            color: textSecondary,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 방 만들기 버튼
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go('/create'),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('방 만들기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                        ),

                        const SizedBox(height: 12),

                        // 방 찾기 버튼
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/browse'),
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text('방 찾기'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderSubtle),
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 하단 푸터
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 카피라이트
                  Text(
                    '© 2026 PartyLink. All rights reserved.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                  // 개발자 응원하기 버튼
                  TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://ctee.kr/place/sge');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: Icon(Icons.favorite, size: 16, color: accentPurple),
                    label: Text(
                      '개발자 응원하기',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: accentPurple,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
