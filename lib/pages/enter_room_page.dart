import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/room_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// 링크 진입 화면 (/r/:code)
///
/// 초대 링크를 통해 접속한 사용자가 닉네임을 입력하고
/// "관전(watching)" 상태로 방에 입장합니다.
class EnterRoomPage extends StatefulWidget {
  final String code;
  const EnterRoomPage({super.key, required this.code});

  @override
  State<EnterRoomPage> createState() => _EnterRoomPageState();
}

class _EnterRoomPageState extends State<EnterRoomPage> {
  final _svc = RoomService();
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  // ─── 입장 처리 ────────────────────────────────────────

  Future<void> _enter() async {
    // 닉네임 유효성 검사
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '닉네임을 입력해주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 방 조회
      final room = await _svc.getRoomByCode(widget.code);

      // 방 상태 확인
      if (!room.isOpen) {
        setState(() => _error = '이 방은 마감되었거나 만료되었어요.');
        return;
      }

      // watching 상태로 입장
      final tag = _tagCtrl.text.trim();
      final memberId = await _svc.enterAsWatching(
        roomId: room.id,
        displayName: name,
        tag: tag.isEmpty ? null : tag,
      );

      // 세션에 memberId 저장
      SessionService.setMemberId(memberId);

      if (!mounted) return;
      context.go('/room/${widget.code}');
    } catch (e) {
      setState(() => _error = '방을 찾지 못했어요. 코드가 맞는지 확인해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── 생명주기 ─────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ─── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        title: Text(
          '입장: ${widget.code}',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 입장 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // 안내 메시지
                      Icon(
                        Icons.info_outline,
                        size: 32,
                        color: AppColors.accentPurple,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '입장만으로는 자리가 확정되지 않아요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '방에 들어간 뒤 "참여하기"를 눌러야 자리 확정!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 닉네임 입력
                      _buildInputField(
                        controller: _nameCtrl,
                        label: '닉네임',
                        hint: '닉네임을 입력하세요',
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // 태그 입력 (선택)
                      _buildInputField(
                        controller: _tagCtrl,
                        label: '태그 (선택)',
                        hint: '#KR1',
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _enter(),
                      ),
                      const SizedBox(height: 20),

                      // 에러 메시지
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
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

                      // 입장 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _enter,
                          icon: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.bgPage,
                                  ),
                                )
                              : Icon(Icons.visibility, size: 20),
                          label: Text(_loading ? '입장 중...' : '관전으로 입장'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            foregroundColor: AppColors.bgPage,
                            disabledBackgroundColor: AppColors.accentPurple.withOpacity(0.5),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.bgInput,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              borderSide: BorderSide(color: AppColors.accentPurple, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
