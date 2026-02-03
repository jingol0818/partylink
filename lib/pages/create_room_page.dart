import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/game.dart';
import '../services/room_service.dart';
import '../services/session_service.dart';
import '../services/profanity_filter_service.dart';
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
  final _roomNameController = TextEditingController();
  bool _loading = false;
  String? _error;

  // ─── 선택 상태 ────────────────────────────────────────
  Game? _selectedGame;
  GameMode? _selectedMode;
  GameGoal? _selectedGoal;
  bool _requireMic = false; // 기본값 OFF로 변경

  // ─── 팀/인원 설정 ────────────────────────────────────────
  int _teamCount = 1;
  int _membersPerTeam = 5;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  /// 게임 선택 시 호출
  void _onGameSelected(Game game) {
    setState(() {
      _selectedGame = game;

      // 게임에 모드가 있으면 첫 번째 모드 자동 선택, 없으면 null
      if (game.hasMode && game.modes.isNotEmpty) {
        _selectedMode = game.modes.first;
        _teamCount = _selectedMode!.teamCount;
        _membersPerTeam = _selectedMode!.membersPerTeam;
      } else {
        _selectedMode = null;
        _teamCount = game.defaultTeamCount;
        _membersPerTeam = game.defaultMembersPerTeam;
      }

      // 목표는 첫 번째 자동 선택
      _selectedGoal = GameData.goals.first;
    });
  }

  /// 모드 선택 시 호출
  void _onModeSelected(GameMode mode) {
    setState(() {
      _selectedMode = mode;
      _teamCount = mode.teamCount;
      _membersPerTeam = mode.membersPerTeam;
    });
  }

  /// 현재 슬롯 목록 계산
  List<String> get _currentSlots {
    if (_selectedMode != null) {
      // 모드 기반 슬롯 (사용자 수정 가능)
      if (_teamCount == _selectedMode!.teamCount &&
          _membersPerTeam == _selectedMode!.membersPerTeam) {
        return _selectedMode!.slots;
      }
    }
    // 커스텀 슬롯 생성
    return GameData.generateSlotNames(_teamCount, _membersPerTeam);
  }

  /// 총 인원 수
  int get _maxMembers => _teamCount * _membersPerTeam;

  // ─── 방 생성 처리 ──────────────────────────────────────

  Future<void> _create() async {
    // 방 이름 유효성 검사
    final roomNameError = ProfanityFilterService.validateRoomName(
      _roomNameController.text,
    );
    if (roomNameError != null) {
      setState(() => _error = roomNameError);
      return;
    }

    // 게임 선택 검사
    if (_selectedGame == null) {
      setState(() => _error = '게임을 선택해주세요.');
      return;
    }

    // 모드 선택 검사 (모드가 있는 게임만)
    if (_selectedGame!.hasMode && _selectedMode == null) {
      setState(() => _error = '모드를 선택해주세요.');
      return;
    }

    // 목표 선택 검사
    if (_selectedGoal == null) {
      setState(() => _error = '목표를 선택해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final code = await _svc.generateUniqueCode();
      final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 1));
      final sessionId = SessionService.sessionId;

      await _svc.createRoom(
        gameKey: _selectedGame!.key,
        mode: _selectedMode?.key,
        goal: _selectedGoal!.key,
        slots: _currentSlots,
        requireMic: _requireMic,
        maxMembers: _maxMembers,
        code: code,
        expiresAt: expiresAt,
        roomName: _roomNameController.text.trim(),
        teamCount: _teamCount,
        membersPerTeam: _membersPerTeam,
        hostSessionId: sessionId,
      );

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
            _buildHeader(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // 방 이름 입력
                      _buildSectionTitle('방 이름'),
                      const SizedBox(height: 12),
                      _buildRoomNameInput(),
                      const SizedBox(height: 24),

                      // 게임 선택
                      _buildSectionTitle('게임 선택'),
                      const SizedBox(height: 12),
                      _buildGameSelector(),
                      const SizedBox(height: 24),

                      // 게임 선택 후 나머지 옵션 표시
                      if (_selectedGame != null) ...[
                        // 모드 선택 (모드가 있는 게임만)
                        if (_selectedGame!.hasMode && _selectedGame!.modes.isNotEmpty) ...[
                          _buildSectionTitle('모드 선택'),
                          const SizedBox(height: 12),
                          _buildModeSelector(),
                          const SizedBox(height: 24),
                        ],

                        // 목표 선택
                        _buildSectionTitle('목표'),
                        const SizedBox(height: 12),
                        _buildGoalSelector(),
                        const SizedBox(height: 24),

                        // 팀/인원 설정
                        _buildSectionTitle('팀 구성'),
                        const SizedBox(height: 12),
                        _buildTeamSettings(),
                        const SizedBox(height: 24),

                        // 추가 설정
                        _buildSettingsCard(),
                        const SizedBox(height: 24),

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

                        // 생성 버튼
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _create,
                            icon: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.bgPage,
                                    ),
                                  )
                                : Icon(Icons.link, size: 20),
                            label: Text(_loading ? '생성 중...' : '링크 생성'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentPurple,
                              foregroundColor: AppColors.bgPage,
                              disabledBackgroundColor:
                                  AppColors.accentPurple.withOpacity(0.5),
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

  /// 방 이름 입력
  Widget _buildRoomNameInput() {
    return TextField(
      controller: _roomNameController,
      maxLength: 20,
      style: TextStyle(
        fontFamily: 'Inter',
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '방 이름을 입력하세요 (예: 다이아 이상만)',
        hintStyle: TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.bgCard,
        counterStyle: TextStyle(color: AppColors.textMuted),
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
              onTap: () => _onGameSelected(game),
              child: Container(
                width: 100,
                height: 100, // 고정 높이로 통일
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPurple.withOpacity(0.15)
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      game.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      game.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: isSelected
                            ? AppColors.accentPurple
                            : AppColors.textPrimary,
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
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline,
                    size: 18, color: AppColors.textSecondary),
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
                    content: Text(
                        '\'${controller.text.trim()}\' 게임 추가 요청이 접수되었습니다!'),
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
    if (_selectedGame == null || !_selectedGame!.hasMode) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _selectedGame!.modes.map((mode) {
        final isSelected = _selectedMode?.key == mode.key;
        return GestureDetector(
          onTap: () => _onModeSelected(mode),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPurple.withOpacity(0.15)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
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
                          color: isSelected
                              ? AppColors.accentPurple
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${mode.teamCount > 1 ? "${mode.teamCount}팀 × " : ""}${mode.membersPerTeam}인',
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
            height: 80, // 고정 높이로 통일
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPurple.withOpacity(0.15)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  goal.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.accentPurple
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    height: 1.2,
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

  /// 팀/인원 설정
  Widget _buildTeamSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // 팀 수
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '팀 수',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildCounterButton(
                    icon: Icons.remove,
                    onPressed: _teamCount > 1
                        ? () => setState(() => _teamCount--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_teamCount',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildCounterButton(
                    icon: Icons.add,
                    onPressed: _teamCount < GameData.maxTeamCount
                        ? () => setState(() => _teamCount++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 팀당 인원
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '팀당 인원',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _buildCounterButton(
                    icon: Icons.remove,
                    onPressed: _membersPerTeam > 1
                        ? () => setState(() => _membersPerTeam--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_membersPerTeam',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _buildCounterButton(
                    icon: Icons.add,
                    onPressed: _membersPerTeam < GameData.maxMembersPerTeam
                        ? () => setState(() => _membersPerTeam++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 총 인원 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '총 $_maxMembers명',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.accentPurple : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isEnabled ? Colors.white : AppColors.textMuted,
        ),
      ),
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
                        _selectedMode != null
                            ? '${_selectedMode!.name} · ${_selectedGoal?.name ?? ''}'
                            : _selectedGoal?.name ?? '',
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
