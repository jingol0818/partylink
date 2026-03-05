import 'package:flutter/material.dart';

/// 기하학적 도형 아바타 위젯
///
/// 도형(circle/triangle/square/diamond/star) × 색상(hex) 조합
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
        color: _color.withAlpha(40),
        shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape != 'circle' ? BorderRadius.circular(size * 0.2) : null,
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Text(
          _shapeChar,
          style: TextStyle(
            fontSize: size * 0.45,
            color: _color,
            height: 1,
          ),
        ),
      ),
    );
  }

  String get _shapeChar {
    switch (shape) {
      case 'circle':
        return '\u25CF'; // ●
      case 'triangle':
        return '\u25B2'; // ▲
      case 'square':
        return '\u25A0'; // ■
      case 'diamond':
        return '\u25C6'; // ◆
      case 'star':
        return '\u2605'; // ★
      default:
        return '\u25CF';
    }
  }
}
