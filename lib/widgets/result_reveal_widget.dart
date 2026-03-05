import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_player.dart';
import '../theme/app_theme.dart';
import 'avatar_icon.dart';

/// 결과 순차 공개 위젯
/// 플레이어를 1초 간격으로 하나씩 공개 + 카드 플립 + HUMAN/AI 스탬프
/// 라벤더 파스텔 배경 대응
class ResultRevealWidget extends StatefulWidget {
  final List<GamePlayer> players;
  final String? myPlayerId;
  final VoidCallback? onRevealComplete;
  final GameRoundTheme? theme;

  const ResultRevealWidget({
    super.key,
    required this.players,
    this.myPlayerId,
    this.onRevealComplete,
    this.theme,
  });

  @override
  State<ResultRevealWidget> createState() => _ResultRevealWidgetState();
}

class _ResultRevealWidgetState extends State<ResultRevealWidget>
    with TickerProviderStateMixin {
  int _revealedCount = 0;
  final List<AnimationController> _flipControllers = [];
  final List<Animation<double>> _flipAnimations = [];

  GameRoundTheme get _theme => widget.theme ?? GameRoundTheme.result;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startReveal();
  }

  void _initAnimations() {
    for (var i = 0; i < widget.players.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final animation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
      _flipControllers.add(controller);
      _flipAnimations.add(animation);
    }
  }

  void _startReveal() async {
    for (var i = 0; i < widget.players.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _flipControllers[i].forward();
      setState(() => _revealedCount = i + 1);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onRevealComplete?.call();
  }

  @override
  void dispose() {
    for (final c in _flipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (var i = 0; i < widget.players.length; i++)
          _buildPlayerCard(widget.players[i], i),
      ],
    );
  }

  Widget _buildPlayerCard(GamePlayer player, int index) {
    final isRevealed = index < _revealedCount;
    final isAi = player.isAi == true;
    final isMe = player.id == widget.myPlayerId;

    final aiColor = const Color(0xFFE53935);
    final humanColor = const Color(0xFF2E7D32);

    return AnimatedOpacity(
      opacity: isRevealed ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _theme.bubbleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !isRevealed
                ? _theme.bubbleBorder
                : isAi
                    ? aiColor.withAlpha(150)
                    : humanColor.withAlpha(150),
            width: isRevealed ? 2 : 1,
          ),
          boxShadow: isRevealed
              ? [
                  BoxShadow(
                    color: (isAi ? aiColor : humanColor).withAlpha(40),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // 아바타
            AvatarIcon(
              shape: player.avatarShape,
              colorHex: player.avatarColor,
              size: 44,
            ),
            const SizedBox(width: 14),
            // 닉네임 + 점수
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        player.nickname,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _theme.textColor,
                        ),
                      ),
                      if (isMe)
                        Text(
                          ' (나)',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            color: _theme.subTextColor,
                          ),
                        ),
                    ],
                  ),
                  if (isRevealed && player.isAi != true)
                    Text(
                      player.score > 0
                          ? '+${player.score}점'
                          : '${player.score}점',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: player.score > 0 ? humanColor : aiColor,
                      ),
                    ),
                ],
              ),
            ),
            // HUMAN/AI 스탬프 (카드 플립)
            if (isRevealed)
              ScaleTransition(
                scale: _flipAnimations[index],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isAi ? aiColor : humanColor).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isAi ? aiColor : humanColor, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isAi ? '🤖' : '👤',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAi ? 'AI' : 'HUMAN',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isAi ? aiColor : humanColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _theme.isDark
                      ? CyberColors.bgCardMedium
                      : Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _theme.bubbleBorder),
                ),
                child: Text(
                  '???',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _theme.subTextColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
