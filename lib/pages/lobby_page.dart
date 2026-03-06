import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/game_service.dart';
import '../services/nickname_service.dart';
import '../services/session_service.dart';
import '../services/stats_service.dart';
import '../services/sound_service.dart';
import '../models/player_stats.dart';
import '../widgets/leaderboard_widget.dart';

/// 로비 화면 — 게임 진입점
///
/// "게임 시작" 버튼으로 1:1 게임을 생성하고 게임 화면으로 이동
class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _gameService = GameService();
  final _statsService = StatsService();
  late String _nickname;
  late String _avatarShape;
  late String _avatarColor;
  bool _loading = false;
  List<PlayerStats> _leaderboard = [];
  bool _leaderboardLoading = true;

  @override
  void initState() {
    super.initState();
    _regenerateProfile();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final lb = await _statsService.getLeaderboard();
      if (mounted) setState(() { _leaderboard = lb; _leaderboardLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _leaderboardLoading = false);
    }
  }

  void _regenerateProfile() {
    final avatar = NicknameService.generateAvatar();
    _avatarShape = avatar.shape;
    _avatarColor = avatar.color;
    _nickname = NicknameService.generateNickname(shape: _avatarShape);
    setState(() {});
  }

  Future<void> _startGame() async {
    if (_loading) return;
    SoundService.activate(); // 브라우저 오디오 활성화
    SoundService.matchFound();
    setState(() => _loading = true);

    try {
      final result = await _gameService.create1v1Game(
        sessionId: SessionService.sessionId,
        nickname: _nickname,
        avatarShape: _avatarShape,
        avatarColor: _avatarColor,
      );

      SessionService.setMemberId(result.playerId);

      if (mounted) {
        context.go('/game/${result.code}?gid=${result.gameId}&pid=${result.playerId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게임 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOnboarding() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => const _OnboardingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColorParsed = Color(
      int.parse(_avatarColor.replaceFirst('#', '0xFF')),
    );

    // 밝은 파스텔 색상
    const primaryColor = Color(0xFF00897B); // 티일 그린
    const bgGradientTop = Color(0xFFE8F5E9);
    const bgGradientBottom = Color(0xFFB2DFDB);
    const textDark = Color(0xFF2D3436);
    const textSub = Color(0xFF636E72);
    const cardBg = Color(0xCCFFFFFF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgGradientTop, bgGradientBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                // 타이틀
                const Text(
                  '누가 AI야?',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Who is the AI?',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: textSub,
                  ),
                ),

                const SizedBox(height: 32),

                // 프로필 카드
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(120)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // 아바타 (동물 이모지)
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: avatarColorParsed.withAlpha(30),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: avatarColorParsed,
                                width: 2.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _getShapeEmoji(_avatarShape),
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 닉네임
                          Text(
                            _nickname,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 닉네임 재생성 버튼
                          TextButton.icon(
                            onPressed: _regenerateProfile,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('다시 뽑기'),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              textStyle: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 게임 시작 버튼 (매칭)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () {
                          context.go('/matching?nick=${Uri.encodeComponent(_nickname)}&shape=$_avatarShape&color=${Uri.encodeComponent(_avatarColor)}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: primaryColor.withAlpha(80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('게임 시작'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 빠른 시작 (1:1)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _startGame,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : const Text('빠른 시작 (1:1)'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 게임 방법 버튼
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _showOnboarding,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSub,
                          side: BorderSide(color: Colors.black.withAlpha(25)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('게임 방법'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 리더보드 (접이식)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(120)),
                      ),
                      child: ExpansionTile(
                        title: const Text(
                          '🏆 리더보드',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        iconColor: textSub,
                        collapsedIconColor: textSub,
                        children: [
                          LeaderboardWidget(
                            leaderboard: _leaderboard,
                            isLoading: _leaderboardLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 푸터
                const Text(
                  '(c) 2026 SG Entertech',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getShapeEmoji(String shape) {
    switch (shape) {
      case 'circle':
        return '🐱';
      case 'triangle':
        return '🐶';
      case 'square':
        return '🐰';
      case 'diamond':
        return '🦊';
      case 'star':
        return '🐻';
      default:
        return '🐱';
    }
  }
}

/// 온보딩 바텀시트 (3 슬라이드)
class _OnboardingSheet extends StatefulWidget {
  const _OnboardingSheet();

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _slides = const [
    _OnboardingSlide(
      icon: Icons.chat_bubble_outline_rounded,
      title: '자유롭게 대화하세요',
      description: '채팅방에서 다른 참가자와 자유롭게 대화합니다.\n하지만 이 중 한 명은 AI입니다!',
    ),
    _OnboardingSlide(
      icon: Icons.search_rounded,
      title: 'AI를 찾아내세요',
      description: '대화 속 단서를 통해 누가 AI인지 추리하세요.\n말투, 반응 속도, 답변 패턴이 힌트입니다.',
    ),
    _OnboardingSlide(
      icon: Icons.how_to_vote_rounded,
      title: '투표로 지목하세요',
      description: 'AI라고 생각되는 사람을 투표로 지목합니다.\n정확히 맞추면 점수를 획득합니다!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00897B);

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 핸들바
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(30),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // 슬라이드
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: _slides,
            ),
          ),

          const SizedBox(height: 16),

          // 인디케이터
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                width: _currentPage == i ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? primaryColor
                      : Colors.black.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // 다음 / 닫기 버튼 (항상 표시)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < 2) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_currentPage < 2 ? '다음' : '확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: const Color(0xFF00897B)),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            color: Color(0xFF636E72),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
