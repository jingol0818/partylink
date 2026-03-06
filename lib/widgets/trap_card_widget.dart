import 'dart:async';
import 'package:flutter/material.dart';
import '../models/trap_card.dart';
import '../services/trap_card_service.dart';
import '../theme/app_theme.dart';

/// 함정 카드 위젯 (자체 데이터 로딩)
/// gameId로 활성 카드를 조회하여 표시
class TrapCardWidget extends StatefulWidget {
  final String gameId;
  final String playerId;
  final int round;
  final Duration remaining;
  final VoidCallback? onAnswered;

  const TrapCardWidget({
    super.key,
    required this.gameId,
    required this.playerId,
    required this.round,
    required this.remaining,
    this.onAnswered,
  });

  @override
  State<TrapCardWidget> createState() => _TrapCardWidgetState();
}

class _TrapCardWidgetState extends State<TrapCardWidget>
    with SingleTickerProviderStateMixin {
  final _trapCardService = TrapCardService();
  final _answerController = TextEditingController();
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  TrapAnswer? _trapAnswer;
  bool _loading = true;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadCard();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadCard() async {
    try {
      final answer = await _trapCardService.getActiveCard(widget.gameId, widget.round);
      if (mounted) {
        setState(() {
          _trapAnswer = answer;
          _loading = false;
        });
        // 카드 뒤집기 애니메이션
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _flipController.forward();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAnswer() async {
    if (_trapAnswer == null || _submitted) return;
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    try {
      await _trapCardService.submitAnswer(answerId: _trapAnswer!.id, answer: text);
      setState(() => _submitted = true);
      widget.onAnswered?.call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: CyberColors.accentPurple),
      );
    }

    if (_trapAnswer == null) {
      return const Center(
        child: Text(
          '함정 카드를 불러올 수 없습니다.',
          style: TextStyle(color: CyberColors.textSecondary),
        ),
      );
    }

    final category = _trapAnswer!.category ?? 'context';
    final question = _trapAnswer!.question ?? '질문을 불러오는 중...';
    final tempCard = TrapCard(id: '', category: category, question: '');
    final emoji = tempCard.categoryEmoji;
    final label = tempCard.categoryLabel;
    final isTarget = _trapAnswer!.targetId == widget.playerId;

    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.14159;
        if (angle > 1.5708) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(3.14159 - angle),
            child: _buildFront(emoji, label, question, isTarget),
          );
        }
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: _buildBack(),
        );
      },
    );
  }

  Widget _buildBack() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A0A3E)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CyberColors.accentPurple.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: CyberColors.accentPurple.withAlpha(40),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('\u{1F0CF}', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            '함정 카드',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CyberColors.accentPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront(String emoji, String label, String question, bool isTarget) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CyberColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CyberColors.accentPurple.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: CyberColors.accentPurple.withAlpha(30),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 카테고리 뱃지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CyberColors.accentPurple.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$emoji $label',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CyberColors.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 남은 시간
          Text(
            '${widget.remaining.inSeconds}초',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CyberColors.warningAmber,
            ),
          ),
          const SizedBox(height: 12),
          // 질문
          Text(
            question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: CyberColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // 답변 입력 (대상자만)
          if (isTarget && !_submitted) ...[
            TextField(
              controller: _answerController,
              maxLength: 100,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                color: CyberColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '답변을 입력하세요...',
                hintStyle: const TextStyle(color: CyberColors.textMuted),
                counterStyle: const TextStyle(color: CyberColors.textMuted),
                filled: true,
                fillColor: CyberColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CyberColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CyberColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: CyberColors.accentPurple, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CyberColors.accentPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '답변 제출',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          if (_submitted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CyberColors.accentPurple.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CyberColors.accentPurple.withAlpha(40)),
              ),
              child: const Text(
                '답변 완료!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CyberColors.accentPurple,
                ),
              ),
            ),
          if (!isTarget)
            const Text(
              '상대방이 답변 중입니다...',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                color: CyberColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
