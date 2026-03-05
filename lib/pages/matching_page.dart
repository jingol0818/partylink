import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/matching_service.dart';
import '../services/session_service.dart';

/// 매칭 대기 화면
/// 풀 기반 매칭: 혼자→1v1, 2명→3~4인, 3명+→4~5인
class MatchingPage extends StatefulWidget {
  final String nickname;
  final String avatarShape;
  final String avatarColor;

  const MatchingPage({
    super.key,
    required this.nickname,
    required this.avatarShape,
    required this.avatarColor,
  });

  @override
  State<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage>
    with SingleTickerProviderStateMixin {
  final _matchingService = MatchingService();

  String? _poolId;
  bool _isSearching = true;
  int _waitingCount = 1;
  int _elapsedSeconds = 0;
  Timer? _pollTimer;
  Timer? _tickTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _joinPool();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _pulseController.dispose();
    if (_poolId != null && _isSearching) {
      _matchingService.cancelMatch(_poolId!);
    }
    _matchingService.dispose();
    super.dispose();
  }

  Future<void> _joinPool() async {
    try {
      final sessionId = SessionService.sessionId;
      _poolId = await _matchingService.joinPool(
        sessionId: sessionId,
        nickname: widget.nickname,
        avatarShape: widget.avatarShape,
        avatarColor: widget.avatarColor,
      );

      // Realtime 구독
      _matchingService.subscribeToPool(_poolId!);
      _matchingService.onMatchUpdate.listen((data) {
        if (data['status'] == 'matched' && mounted) {
          _onMatched(
            data['matched_game_id'] as String,
            data['matched_player_id'] as String,
          );
        }
      });

      // 1초마다 매칭 시도
      _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tryMatch());
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매칭 오류: $e')),
        );
        context.go('/');
      }
    }
  }

  Future<void> _tryMatch() async {
    if (_poolId == null || !_isSearching) return;

    try {
      final result = await _matchingService.tryMatch(_poolId!);
      final status = result['status'] as String;

      if (status == 'matched') {
        _onMatched(
          result['game_id'] as String,
          result['player_id'] as String,
        );
      } else if (status == 'waiting') {
        final count = result['waiting_count'] as int? ?? 1;
        if (mounted) setState(() => _waitingCount = count);
      }
    } catch (e) {
      // 조용히 재시도
    }
  }

  void _onMatched(String gameId, String playerId) {
    if (!_isSearching) return;
    _isSearching = false;
    _pollTimer?.cancel();
    _tickTimer?.cancel();

    SessionService.setMemberId(playerId);

    // 매칭 완료 → 게임 화면으로
    context.go('/game/match?gid=$gameId&pid=$playerId');
  }

  void _cancel() {
    if (_poolId != null) {
      _matchingService.cancelMatch(_poolId!);
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF00897B);
    const textDark = Color(0xFF2D3436);
    const textSub = Color(0xFF636E72);
    const cardBg = Color(0xCCFFFFFF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 펄스 애니메이션 아이콘
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 1.0 + _pulseController.value * 0.15;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withAlpha(25),
                          border: Border.all(
                            color: primaryColor.withAlpha(
                              (80 + _pulseController.value * 80).toInt(),
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withAlpha(
                                (15 + _pulseController.value * 25).toInt(),
                              ),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.search,
                          size: 44,
                          color: primaryColor,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // 매칭 중 텍스트
                const Text(
                  '매칭 중...',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '상대를 찾고 있습니다',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    color: textSub,
                  ),
                ),
                const SizedBox(height: 32),
                // 대기 정보
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(120)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '대기 중인 플레이어',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              color: textSub,
                            ),
                          ),
                          Text(
                            '$_waitingCount명',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '대기 시간',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              color: textSub,
                            ),
                          ),
                          Text(
                            '${_elapsedSeconds}초',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 10초 타임아웃 안내
                if (_elapsedSeconds >= 8)
                  const Text(
                    '곧 AI와 매칭됩니다...',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: Color(0xFFE65100),
                    ),
                  ),
                const SizedBox(height: 32),
                // 취소 버튼
                OutlinedButton(
                  onPressed: _cancel,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.black.withAlpha(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textSub,
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
