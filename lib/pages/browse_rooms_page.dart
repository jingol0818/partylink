import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/game.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';

/// 공개 방 목록 화면
class BrowseRoomsPage extends StatefulWidget {
  const BrowseRoomsPage({super.key});

  @override
  State<BrowseRoomsPage> createState() => _BrowseRoomsPageState();
}

class _BrowseRoomsPageState extends State<BrowseRoomsPage> {
  final _svc = RoomService();

  List<RoomWithCount> _rooms = [];
  bool _loading = true;
  String? _error;
  String? _selectedGame;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rooms = await _svc.listOpenRooms(gameKey: _selectedGame);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '방 목록을 불러올 수 없어요.';
          _loading = false;
        });
      }
    }
  }

  void _onGameFilterChanged(String? gameKey) {
    setState(() => _selectedGame = gameKey);
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            // 커스텀 헤더
            _buildHeader(),

            // 게임 필터 + 새로고침
            _buildGameFilter(),

            // 방 목록
            Expanded(child: _buildRoomList()),
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
            '방 찾기',
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

  Widget _buildGameFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 게임 필터 칩들
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: '전체',
                    isSelected: _selectedGame == null,
                    onTap: () => _onGameFilterChanged(null),
                  ),
                  const SizedBox(width: 8),
                  ...GameData.games.map((game) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      label: '${game.icon} ${game.name}',
                      isSelected: _selectedGame == game.key,
                      onTap: () => _onGameFilterChanged(game.key),
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 새로고침 버튼
          Material(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _loading ? null : _loadRooms,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: _loading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentPurple,
                          ),
                        ),
                      )
                    : Icon(Icons.refresh, color: AppColors.textPrimary, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPurple : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildRoomList() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accentPurple),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.accentRed,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRooms,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: AppColors.bgPage,
              ),
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              '열린 방이 없어요',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '직접 방을 만들어보세요!',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/create'),
              icon: Icon(Icons.add, size: 20),
              label: Text('방 만들기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: AppColors.bgPage,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 반응형 그리드: 화면 너비에 따라 열 수 결정 (더 조밀하게)
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1400 ? 5 : width > 1100 ? 4 : width > 800 ? 3 : width > 500 ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: crossAxisCount == 1 ? 4.0 : 1.8,
          ),
          itemCount: _rooms.length,
          itemBuilder: (context, index) => _buildRoomCard(_rooms[index]),
        );
      },
    );
  }

  /// 남은 시간 포맷팅
  String _formatRemainingTime(DateTime expiresAt) {
    final now = DateTime.now().toUtc();
    final diff = expiresAt.difference(now);

    if (diff.isNegative) return '만료됨';

    if (diff.inMinutes < 1) return '1분 미만';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분';

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (minutes == 0) return '${hours}시간';
    return '${hours}시간 ${minutes}분';
  }

  /// 남은 시간에 따른 색상
  Color _getTimeColor(DateTime expiresAt) {
    final now = DateTime.now().toUtc();
    final diff = expiresAt.difference(now);

    if (diff.inMinutes < 10) return AppColors.accentRed;
    if (diff.inMinutes < 30) return AppColors.accentOrange;
    return AppColors.textMuted;
  }

  Widget _buildRoomCard(RoomWithCount roomWithCount) {
    final room = roomWithCount.room;
    final game = GameData.findGame(room.gameKey);
    final goal = GameData.findGoal(room.goal);
    final mode = game?.modes.where((m) => m.key == room.mode).firstOrNull;
    final isFull = roomWithCount.joinedCount >= room.maxMembers;
    final timeColor = _getTimeColor(room.expiresAt);

    // 툴팁 메시지 구성
    final tooltipMessage = [
      '${game?.name ?? room.gameKey} - ${mode?.name ?? room.mode}',
      '목표: ${goal?.name ?? room.goal}',
      '인원: ${roomWithCount.joinedCount}/${room.maxMembers}명',
      '마이크: ${room.requireMic ? "필수" : "선택"}',
      '남은 시간: ${_formatRemainingTime(room.expiresAt)}',
      if (isFull) '⚠️ 방이 가득 찼습니다',
    ].join('\n');

    return Tooltip(
      message: tooltipMessage,
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: isFull ? null : () => context.go('/r/${room.code}'),
        child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Opacity(
          opacity: isFull ? 0.5 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 게임 아이콘 + 이름 + 목표 태그
              Row(
                children: [
                  if (game != null)
                    Text(game.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game?.name ?? room.gameKey.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          mode?.name ?? room.mode,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 목표 태그
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getGoalColor(room.goal).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      goal?.name ?? room.goal,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getGoalColor(room.goal),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // 하단: 인원 + 마이크 + 남은 시간 + 입장
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 12,
                    color: isFull ? AppColors.accentRed : AppColors.accentGreen,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${roomWithCount.joinedCount}/${room.maxMembers}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isFull ? AppColors.accentRed : AppColors.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    room.requireMic ? Icons.mic : Icons.mic_off,
                    size: 12,
                    color: room.requireMic ? AppColors.textSecondary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  // 남은 시간
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: timeColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatRemainingTime(room.expiresAt),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: timeColor,
                    ),
                  ),
                  const Spacer(),
                  // 입장 아이콘
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isFull
                          ? AppColors.textMuted.withValues(alpha: 0.1)
                          : AppColors.accentPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isFull ? Icons.block : Icons.arrow_forward_rounded,
                      size: 14,
                      color: isFull ? AppColors.textMuted : AppColors.accentPurple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Color _getGoalColor(String goal) {
    return switch (goal) {
      'tryhard' => AppColors.accentRed,
      'chill' => AppColors.accentGreen,
      'practice' => AppColors.accentBlue,
      _ => AppColors.textSecondary,
    };
  }
}
