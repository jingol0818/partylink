import 'package:flutter/material.dart';

/// 주제 드롭 카드 위젯
/// 화면 중앙에서 scale(0.3 -> 1.0) + fade + bounce로 등장
class TopicCard extends StatefulWidget {
  final String topic;
  final VoidCallback? onComplete;

  const TopicCard({
    super.key,
    required this.topic,
    this.onComplete,
  });

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // 등장 애니메이션 시작
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _controller.forward().then((_) {
          // 2초 후 완료 콜백
          Future.delayed(const Duration(seconds: 2), () {
            widget.onComplete?.call();
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withAlpha(40),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF00897B).withAlpha(60),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '\u{1F4AC}',
                    style: TextStyle(fontSize: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '오늘의 주제',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${widget.topic}"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3436),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 상단 고정 주제 바 (채팅 중 표시)
class TopicBar extends StatelessWidget {
  final String topic;
  final Color textColor;
  final Color bgColor;

  const TopicBar({
    super.key,
    required this.topic,
    this.textColor = const Color(0xFF00897B),
    this.bgColor = const Color(0x1500897B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('\u{1F4AC}', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              topic,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
