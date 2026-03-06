import 'package:flutter/material.dart';

/// 아바타 아이콘 위젯
///
/// 도형(circle/triangle/square/diamond/star) × 색상(hex) 조합
/// v2.1: 기하학적 도형 → 동물/캐릭터 이모지로 변경
class AvatarIcon extends StatelessWidget {
  final String shape;
  final String colorHex;
  final double size;

  const AvatarIcon({
    super.key,
    required this.shape,
    required this.colorHex,
    this.size = 40,
  });

  Color get _color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Text(
          _animalEmoji,
          style: TextStyle(
            fontSize: size * 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }

  /// 도형 → 동물 이모지 매핑
  String get _animalEmoji {
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
