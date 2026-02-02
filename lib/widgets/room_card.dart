import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/room.dart';

/// 방 정보 요약 카드
///
/// 게임/모드/목표, 인원 현황, 마이크 여부, 만료 시간을 표시합니다.
class RoomCard extends StatelessWidget {
  final Room room;
  final int joinedCount;

  const RoomCard({super.key, required this.room, required this.joinedCount});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd HH:mm');
    final expireText = dateFormat.format(room.expiresAt.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 게임 · 모드 · 목표
            Text(
              '${room.gameKey.toUpperCase()} · ${room.mode} · ${room.goal}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 인원 + 태그들
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 인원 카운트
                Text(
                  '$joinedCount/${room.maxMembers}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // 마이크 태그
                Chip(
                  label: Text(
                    room.requireMic ? '🎙 마이크 O' : '🔇 마이크 X',
                  ),
                  visualDensity: VisualDensity.compact,
                ),

                // 만료 시간 태그
                Chip(
                  label: Text('⏰ $expireText'),
                  visualDensity: VisualDensity.compact,
                ),

                // 마감 태그 (방이 닫혔을 때만)
                if (!room.isOpen)
                  Chip(
                    label: const Text('마감됨'),
                    backgroundColor: Colors.red.shade800,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
