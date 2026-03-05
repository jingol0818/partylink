import 'package:flutter/material.dart';
import '../models/game_chat_message.dart';
import '../theme/app_theme.dart';
import 'avatar_icon.dart';

/// 게임 채팅 버블 위젯
///
/// 라운드별 파스텔 테마에 맞게 색상이 변하는 말풍선
/// SlideTransition으로 부드러운 등장 애니메이션
class ChatBubble extends StatefulWidget {
  final GameChatMessage message;
  final bool isMine;
  final String? avatarShape;
  final String? avatarColor;
  final GameRoundTheme? theme;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.avatarShape,
    this.avatarColor,
    this.theme,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  GameRoundTheme get _theme => widget.theme ?? GameRoundTheme.waiting;

  @override
  Widget build(BuildContext context) {
    if (widget.message.isGm) return _buildGmBubble();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.isMine ? _buildMyBubble() : _buildOtherBubble(),
      ),
    );
  }

  Widget _buildGmBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _theme.isDark
                ? CyberColors.gmAmber.withAlpha(25)
                : const Color(0x20FF8F00),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _theme.isDark
                  ? CyberColors.gmAmber.withAlpha(60)
                  : const Color(0x40FF8F00),
            ),
          ),
          child: Text(
            widget.message.content,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: _theme.isDark ? CyberColors.gmAmber : const Color(0xFFE65100),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 12, top: 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _theme.myBubbleBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: _theme.myBubbleBorder.withAlpha(80)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.message.content,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  color: _theme.isDark ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 60, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.avatarShape != null && widget.avatarColor != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AvatarIcon(
                shape: widget.avatarShape!,
                colorHex: widget.avatarColor!,
                size: 32,
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임 + 아바타 컬러 dot
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.avatarColor != null)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(int.parse(
                            widget.avatarColor!.replaceFirst('#', '0xFF'),
                          )),
                        ),
                      ),
                    Text(
                      widget.message.nickname,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _theme.subTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _theme.bubbleBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: _theme.bubbleBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      color: _theme.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
