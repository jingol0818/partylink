import 'package:flutter/material.dart';
import '../models/room.dart';
import '../models/member.dart';

/// 슬롯(역할) 현황 카드
///
/// 방의 각 역할(TOP, JG, MID 등)별로
/// 점유 상태와 Ready 여부를 표시합니다.
/// 빈 슬롯을 탭하면 바로 참여할 수 있습니다.
class SlotList extends StatelessWidget {
  final Room room;
  final List<Member> members;

  /// 현재 사용자의 역할 (내 슬롯 표시용)
  final String? myRole;

  /// 빈 슬롯 탭 콜백 (null이면 클릭 비활성)
  final void Function(String role)? onSlotTap;

  const SlotList({
    super.key,
    required this.room,
    required this.members,
    this.myRole,
    this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final joinedMembers = members.where((m) => m.isJoined).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '슬롯 현황',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < room.slots.length; i++) ...[
              _SlotRow(
                role: room.slots[i],
                member: _findByRole(joinedMembers, room.slots[i]),
                isMySlot: myRole == room.slots[i],
                onTap: onSlotTap,
              ),
              if (i < room.slots.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  /// 특정 역할을 점유한 멤버 찾기
  Member? _findByRole(List<Member> joined, String role) {
    final matches = joined.where((m) => m.role == role);
    return matches.isEmpty ? null : matches.first;
  }
}

// ─── 개별 슬롯 행 ──────────────────────────────────────

class _SlotRow extends StatelessWidget {
  final String role;
  final Member? member;
  final bool isMySlot;
  final void Function(String role)? onTap;

  const _SlotRow({
    required this.role,
    required this.member,
    this.isMySlot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOccupied = member != null;
    // 빈 슬롯이고 콜백 있으면 탭 가능 (내 슬롯은 탭 불가)
    final canTap = !isOccupied && onTap != null;

    return GestureDetector(
      onTap: canTap ? () => onTap!(role) : null,
      child: MouseRegion(
        cursor: canTap ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMySlot
                  ? Colors.blue
                  : isOccupied
                      ? Colors.green
                      : Colors.grey.shade700,
              width: (isOccupied || isMySlot) ? 1.5 : 1,
            ),
            color: isMySlot
                ? Colors.blue.withValues(alpha: 0.1)
                : isOccupied
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.transparent,
          ),
          child: Row(
            children: [
              // 역할 이름
              SizedBox(
                width: 80,
                child: Text(
                  role,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // 점유 상태
              Expanded(
                child: isOccupied ? _buildOccupied() : _buildEmpty(canTap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 점유된 슬롯 표시 (닉네임 + 태그 + Ready 상태)
  Widget _buildOccupied() {
    final m = member!;
    final tagText = m.tag != null ? ' (${m.tag})' : '';

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text('${m.displayName}$tagText'),
              if (isMySlot) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ME',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          m.ready ? Icons.check_circle : Icons.schedule,
          color: m.ready ? Colors.green : Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 4),
        Text(
          m.ready ? 'Ready' : '준비 중',
          style: TextStyle(
            color: m.ready ? Colors.green : Colors.orange,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 빈 슬롯 표시
  Widget _buildEmpty(bool canTap) {
    return Row(
      children: [
        Expanded(
          child: Text(
            canTap ? '참여하기' : '비어있음',
            style: TextStyle(
              color: canTap ? Colors.blue.shade300 : Colors.grey.shade500,
              fontWeight: canTap ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        if (canTap)
          Icon(
            Icons.touch_app,
            color: Colors.blue.shade300,
            size: 18,
          ),
      ],
    );
  }
}
