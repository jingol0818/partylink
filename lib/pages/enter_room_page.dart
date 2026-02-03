import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/room_service.dart';
import '../services/session_service.dart';
import '../services/profanity_filter_service.dart';
import '../theme/app_theme.dart';

/// 링크 진입 화면 (/r/:code)
///
/// 초대 링크를 통해 접속한 사용자가 자동으로 빈 슬롯에 배정됩니다.
/// 닉네임은 기본 "사용자 N"으로 설정되며, 방에서 수정 가능합니다.
class EnterRoomPage extends StatefulWidget {
  final String code;
  const EnterRoomPage({super.key, required this.code});

  @override
  State<EnterRoomPage> createState() => _EnterRoomPageState();
}

class _EnterRoomPageState extends State<EnterRoomPage> {
  final _svc = RoomService();
  final _nameCtrl = TextEditingController();
  final _inviteIdCtrl = TextEditingController();
  bool _loading = true;
  bool _joining = false;
  String? _error;
  String? _roomName;
  String? _gameName;
  int? _currentMembers;
  int? _maxMembers;

  @override
  void initState() {
    super.initState();
    _loadRoomInfo();
  }

  // ─── 방 정보 로드 ────────────────────────────────────────

  Future<void> _loadRoomInfo() async {
    try {
      final room = await _svc.getRoomByCode(widget.code);

      if (!room.isOpen) {
        setState(() {
          _error = '이 방은 마감되었거나 만료되었어요.';
          _loading = false;
        });
        return;
      }

      // 참여 인원 수 조회
      final members = await _svc.listMembers(room.id);
      final joinedCount = members.where((m) => m.isJoined).length;

      // 기본 닉네임 설정
      final nextUserNum = await _svc.getNextUserNumber(room.id);
      _nameCtrl.text = '사용자 $nextUserNum';

      setState(() {
        _roomName = room.roomName;
        _gameName = room.gameKey;
        _currentMembers = joinedCount;
        _maxMembers = room.maxMembers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '방을 찾지 못했어요. 코드가 맞는지 확인해주세요.';
        _loading = false;
      });
    }
  }

  // ─── 입장 처리 (자동 슬롯 배정) ─────────────────────────────

  Future<void> _enter() async {
    // 닉네임 유효성 검사
    final name = _nameCtrl.text.trim();
    final nameError = ProfanityFilterService.validateNickname(name);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    setState(() {
      _joining = true;
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

      // 빈 슬롯 찾기
      final emptySlot = await _svc.findEmptySlot(room.id);

      if (emptySlot == null) {
        // 빈 슬롯 없으면 관전자로 입장
        final inviteId = _inviteIdCtrl.text.trim();
        final memberId = await _svc.enterAsWatching(
          roomId: room.id,
          displayName: name,
          inviteId: inviteId.isEmpty ? null : inviteId,
          sessionId: SessionService.sessionId,
        );

        SessionService.setMemberId(memberId);

        if (!mounted) return;
        context.go('/room/${widget.code}');
        return;
      }

      // 빈 슬롯에 바로 참여
      final inviteId = _inviteIdCtrl.text.trim();
      final memberId = await _svc.enterAndJoinSlot(
        roomId: room.id,
        displayName: name,
        role: emptySlot,
        inviteId: inviteId.isEmpty ? null : inviteId,
        sessionId: SessionService.sessionId,
      );

      // 세션에 memberId 저장
      SessionService.setMemberId(memberId);

      if (!mounted) return;
      context.go('/room/${widget.code}');
    } catch (e) {
      setState(() => _error = '입장 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  // ─── 관전자로 입장 ─────────────────────────────────────────

  Future<void> _enterAsWatcher() async {
    // 닉네임 유효성 검사
    final name = _nameCtrl.text.trim();
    final nameError = ProfanityFilterService.validateNickname(name);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final room = await _svc.getRoomByCode(widget.code);

      if (!room.isOpen) {
        setState(() => _error = '이 방은 마감되었거나 만료되었어요.');
        return;
      }

      final inviteId = _inviteIdCtrl.text.trim();
      final memberId = await _svc.enterAsWatching(
        roomId: room.id,
        displayName: name,
        inviteId: inviteId.isEmpty ? null : inviteId,
        sessionId: SessionService.sessionId,
      );

      SessionService.setMemberId(memberId);

      if (!mounted) return;
      context.go('/room/${widget.code}');
    } catch (e) {
      setState(() => _error = '입장 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  // ─── 생명주기 ─────────────────────────────────────────

  @override
  void dispose() {
    _nameCtrl.dispose();
    _inviteIdCtrl.dispose();
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
          _roomName ?? '입장: ${widget.code}',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading ? _buildLoading() : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accentPurple),
          const SizedBox(height: 16),
          Text(
            '방 정보를 불러오는 중...',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 방 정보 카드
              if (_roomName != null || _gameName != null) ...[
                _buildRoomInfoCard(),
                const SizedBox(height: 16),
              ],

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
                      Icons.login,
                      size: 32,
                      color: AppColors.accentPurple,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '입장하면 자동으로 빈 자리에 배정돼요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '닉네임과 초대 정보는 방에서 수정 가능해요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
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
                      maxLength: 20,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 초대 방법 입력 (선택)
                    _buildInputField(
                      controller: _inviteIdCtrl,
                      label: '초대 방법 (선택)',
                      hint: '게임 닉네임, 배틀태그 등',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _enter(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '예: Hide on bush#KR1, 닉네임#1234',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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
                            fontFamily: 'Pretendard',
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
                        onPressed: _joining ? null : _enter,
                        icon: _joining
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.bgPage,
                                ),
                              )
                            : Icon(Icons.login, size: 20),
                        label: Text(_joining ? '입장 중...' : '입장하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPurple,
                          foregroundColor: AppColors.bgPage,
                          disabledBackgroundColor:
                              AppColors.accentPurple.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 관전 입장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _joining ? null : _enterAsWatcher,
                        icon: Icon(Icons.visibility, size: 20),
                        label: Text('관전으로 입장'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.borderSubtle),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildRoomInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_roomName != null) ...[
            Text(
              _roomName!,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (_gameName != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _gameName!,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentPurple,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (_currentMembers != null && _maxMembers != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentMembers / $_maxMembers',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? maxLength,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
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
          maxLength: maxLength,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.bgInput,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
