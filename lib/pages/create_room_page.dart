import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/game.dart';
import '../services/room_service.dart';
import '../services/rate_limit_service.dart';
import '../theme/app_theme.dart';

/// 방 생성 화면
///
/// 게임, 모드, 목표를 선택하고 방을 생성합니다.
class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _svc = RoomService();
  bool _loading = false;
  String? _error;

  // ─── 선택 상태 ────────────────────────────────────────
  Game? _selectedGame;
  GameMode? _selectedMode;
  GameGoal? _selectedGoal;
  bool _requireMic = true;

  // ─── 쿨다운 상태 ────────────────────────────────────────
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  int _remainingDailyCount = RateLimitService.maxRoomsPerDay;

  @override
  void initState() {
    super.initState();
    _checkRateLimit();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkRateLimit() async {
    final result = await RateLimitService.canCreateRoom();
    final remaining = await RateLimitService.getRemainingDailyCount();

    if (mounted) {
      setState(() {
        _remainingDailyCount = remaining;
        if (!result.canCreate && result.remainingSeconds > 0) {
          _cooldownSeconds = result.remainingSeconds;
          _startCooldownTimer();
        }
      });
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _cooldownSeconds--;
          if (_cooldownSeconds <= 0) {
            timer.cancel();
            _cooldownSeconds = 0;
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes분 ${secs.toString().padLeft(2, '0')}초';
    }
    return '$secs초';
  }

  // ─── 방 생성 처리 ──────────────────────────────────────

  Future<void> _create() async {
    // 유효성 검사
    if (_selectedGame == null) {
      setState(() => _error = '게임을 선택해주세요.');
      return;
    }
    if (_selectedMode == null) {
      setState(() => _error = '모드를 선택해주세요.');
      return;
    }
    if (_selectedGoal == null) {
      setState(() => _error = '목표를 선택해주세요.');
      return;
    }

    // 생성 제한 확인
    final rateCheck = await RateLimitService.canCreateRoom();
    if (!rateCheck.canCreate) {
      setState(() {
        _error = rateCheck.message;
        if (rateCheck.remainingSeconds > 0) {
          _cooldownSeconds = rateCheck.remainingSeconds;
          _startCooldownTimer();
        }
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final code = await _svc.generateUniqueCode();
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));

      await _svc.createRoom(
        gameKey: _selectedGame!.key,
        mode: _selectedMode!.key,
        goal: _selectedGoal!.key,
        slots: _selectedMode!.slots,
        requireMic: _requireMic,
        maxMembers: _selectedMode!.maxMembers,
        code: code,
        expiresAt: expiresAt,
      );

      // 방 생성 기록
      await RateLimitService.recordRoomCreation();

      if (!mounted) return;
      context.go('/r/$code');
    } catch (e) {
      setState(() => _error = '방 생성에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            // 커스텀 헤더
            _buildHeader(),
            // 본문
            Expanded(
              child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // 게임 선택
              _buildSectionTitle('게임 선택'),
              const SizedBox(height: 12),
              _buildGameSelector(),
              const SizedBox(height: 24),

              // 모드 선택 (게임 선택 후)
              if (_selectedGame != null) ...[
                _buildSectionTitle('모드 선택'),
                const SizedBox(height: 12),
                _buildModeSelector(),
                const SizedBox(height: 24),
              ],

              // 목표 선택 (모드 선택 후)
              if (_selectedMode != null) ...[
                _buildSectionTitle('목표'),
                const SizedBox(height: 12),
                _buildGoalSelector(),
                const SizedBox(height: 24),
              ],

              // 추가 설정 (목표 선택 후)
              if (_selectedGoal != null) ...[
                _buildSettingsCard(),
                const SizedBox(height: 24),
              ],

              // 에러 메시지
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.accentRed,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 생성 버튼 (모든 선택 완료 후)
              if (_selectedGoal != null) ...[
                // 생성 제한 안내
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '방 생성 후 5분간 쿨다운 · 오늘 남은 횟수: $_remainingDailyCount회',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_loading || _cooldownSeconds > 0) ? null : _create,
                    icon: _loading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bgPage,
                            ),
                          )
                        : _cooldownSeconds > 0
                            ? Icon(Icons.timer, size: 20)
                            : Icon(Icons.link, size: 20),
                    label: Text(
                      _loading
                          ? '생성 중...'
                          : _cooldownSeconds > 0
                              ? '${_formatCooldown(_cooldownSeconds)} 후 생성 가능'
                              : '링크 생성',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cooldownSeconds > 0
                          ? AppColors.textMuted
                          : AppColors.accentPurple,
                      foregroundColor: AppColors.bgPage,
                      disabledBackgroundColor: _cooldownSeconds > 0
                          ? AppColors.textMuted.withOpacity(0.5)
                          : AppColors.accentPurple.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back,
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 8),
          Text(
            '방 만들기',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 공통 아이콘 버튼 (둥근 사각형 호버)
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 40,
    double iconSize = 20,
  }) {
    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// 게임 선택 그리드
  Widget _buildGameSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: GameData.games.map((game) {
            final isSelected = _selectedGame?.key == game.key;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGame = game;
                  _selectedMode = null;
                  _selectedGoal = null;
                });
              },
              child: Container(
                width: 100,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentPurple.withValues(alpha: 0.15) : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      game.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.accentPurple : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 게임 추가 요청 버튼
        GestureDetector(
          onTap: _showGameRequestDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle, style: BorderStyle.solid),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '다른 게임 추가 요청',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGameRequestDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '게임 추가 요청',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '추가를 원하는 게임 이름을 입력해주세요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '예: 메이플스토리, FIFA 등',
                hintStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.bgPage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accentPurple),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('\'${controller.text.trim()}\' 게임 추가 요청이 접수되었습니다!'),
                    backgroundColor: AppColors.accentGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
  }

  /// 모드 선택 리스트
  Widget _buildModeSelector() {
    if (_selectedGame == null) return const SizedBox.shrink();

    return Column(
      children: _selectedGame!.modes.map((mode) {
        final isSelected = _selectedMode?.key == mode.key;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMode = mode;
              _selectedGoal = null;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentPurple.withOpacity(0.15) : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.accentPurple : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mode.maxMembers}인 · ${mode.slots.join(" / ")}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.accentPurple,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 목표 선택
  Widget _buildGoalSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: GameData.goals.map((goal) {
        final isSelected = _selectedGoal?.key == goal.key;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedGoal = goal);
          },
          child: Container(
            width: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentPurple.withOpacity(0.15) : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.accentPurple : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal.description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 추가 설정 카드
  Widget _buildSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 선택 요약
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(
                  _selectedGame!.icon,
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedGame!.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_selectedMode!.name} · ${_selectedGoal!.name}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            height: 1,
            color: AppColors.borderSubtle,
          ),

          // 마이크 설정
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '마이크 필요',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '파티원에게 마이크 사용을 요구합니다',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _requireMic,
                onChanged: (v) => setState(() => _requireMic = v),
                thumbColor: WidgetStateProperty.all(Colors.white),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.accentPurple;
                  }
                  return AppColors.bgElevated;
                }),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
