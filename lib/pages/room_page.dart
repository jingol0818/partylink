import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../models/member.dart';
import '../models/game.dart';
import '../models/chat_message.dart';
import '../services/room_service.dart';
import '../services/realtime_service.dart';
import '../services/session_service.dart';
import '../services/share_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

/// 방 메인 화면 (/room/:code)
///
/// 슬롯 현황, 내 상태, 참여/Ready/공유 기능을 제공합니다.
/// Supabase Realtime으로 실시간 갱신됩니다.
class RoomPage extends StatefulWidget {
  final String code;
  const RoomPage({super.key, required this.code});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final _svc = RoomService();
  final _rt = RealtimeService();
  final _chat = ChatService();
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();

  Room? _room;
  List<Member> _members = [];
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _showChat = false;

  StreamSubscription? _realtimeSub;
  StreamSubscription? _chatSub;
  Timer? _expiryTimer;
  Duration? _remainingTime;

  // --- 내 정보 접근자 ---

  String? get _myMemberId => SessionService.memberId;

  /// 현재 세션의 멤버 객체 (없으면 null)
  Member? get _me {
    if (_myMemberId == null) return null;
    final matches = _members.where((m) => m.id == _myMemberId);
    return matches.isEmpty ? null : matches.first;
  }

  // --- 방 상태 계산 ---

  /// 자리 확정된 멤버 목록
  List<Member> get _joinedMembers =>
      _members.where((m) => m.isJoined).toList();

  /// 자리 확정된 인원 수
  int get _joinedCount => _joinedMembers.length;

  /// 아직 비어있는 역할 목록
  List<String> get _missingRoles {
    if (_room == null) return [];
    final takenRoles = _joinedMembers
        .where((m) => m.role != null)
        .map((m) => m.role!)
        .toSet();
    return _room!.slots.where((s) => !takenRoles.contains(s)).toList();
  }

  /// 슬롯 변경 가능 여부 (관전 중이거나, 참여 중이지만 Ready 전)
  bool get _canChangeSlot {
    if (_room == null || !_room!.isOpen) return false;
    final me = _me;
    if (me == null) return false;
    if (me.isWatching) return true;
    if (me.isJoined && !me.ready) return true;
    return false;
  }

  // --- 생명주기 ---

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _chatSub?.cancel();
    _expiryTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _rt.dispose();
    _chat.dispose();
    super.dispose();
  }

  // --- 데이터 로드 ---

  /// 방 정보 + 멤버 목록 전체 로드
  Future<void> _loadRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final room = await _svc.getRoomByCode(widget.code);
      final members = await _svc.listMembers(room.id);

      _room = room;
      _members = members;

      // 실시간 구독
      _rt.subscribeRoom(room.id);
      _realtimeSub = _rt.onChanged.listen((_) => _refreshMembers());

      // 채팅 구독 (테이블이 없어도 에러 무시)
      try {
        _chat.subscribeToRoom(room.id);
        _messages = await _chat.getMessages(room.id);
        _chatSub = _chat.onMessage.listen((msg) {
          if (mounted) {
            setState(() => _messages = [..._messages, msg]);
            _scrollToBottom();
          }
        });
      } catch (_) {
        // chat_messages 테이블이 없으면 채팅 비활성화
      }

      // 만료 타이머 시작
      _startExpiryTimer();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// 만료 시간 카운트다운 타이머 시작
  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _updateRemainingTime();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (_room?.expiresAt == null) {
      setState(() => _remainingTime = null);
      return;
    }
    final now = DateTime.now().toUtc();
    final remaining = _room!.expiresAt!.difference(now);
    setState(() {
      _remainingTime = remaining.isNegative ? Duration.zero : remaining;
    });
  }

  /// 멤버 목록만 갱신
  Future<void> _refreshMembers() async {
    if (_room == null) return;
    try {
      final members = await _svc.listMembers(_room!.id);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- 채팅 ---

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _room == null || _myMemberId == null) return;

    final me = _me;
    if (me == null) return;

    _chatController.clear();

    try {
      await _chat.sendMessage(
        roomId: _room!.id,
        memberId: _myMemberId!,
        senderName: me.displayName,
        content: text,
      );
    } catch (e) {
      _showSnackBar('메시지 전송에 실패했어요');
    }
  }

  // --- 액션 ---

  /// 역할 선택 (슬롯 점유)
  Future<void> _claimRole(String role) async {
    if (_room == null || _myMemberId == null) return;

    // 이미 다른 슬롯에 있으면 확인 다이얼로그
    final me = _me;
    if (me != null && me.isJoined && me.role != role) {
      final confirm = await _showMoveConfirmDialog(me.role!, role);
      if (confirm != true) return;

      // 기존 슬롯 해제 후 새 슬롯으로 이동
      await _svc.releaseSlot(memberId: _myMemberId!);
    }

    final result = await _svc.claimSlot(
      roomCode: widget.code,
      memberId: _myMemberId!,
      role: role,
    );

    if (result.ok) {
      _showSnackBar('$role 슬롯에 참여했어요!');
    } else {
      _showSnackBar(_errorToKorean(result.message));
      await _refreshMembers();
    }
  }

  Future<bool?> _showMoveConfirmDialog(String fromRole, String toRole) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '슬롯 이동',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '$fromRole에서 $toRole(으)로 이동할까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('이동'),
          ),
        ],
      ),
    );
  }

  /// Ready 토글
  Future<void> _toggleReady(bool value) async {
    if (_myMemberId == null) return;
    await _svc.setReady(memberId: _myMemberId!, ready: value);
  }

  /// 초대 공유 (템플릿 선택 + 편집 가능)
  Future<void> _share() async {
    if (_room == null) return;

    final inviteUrl = ShareService.getInviteUrl(widget.code);

    // 템플릿 변수 준비
    final variables = ShareService.buildTemplateVariables(
      room: _room!,
      joinedCount: _joinedCount,
      missingRoles: _missingRoles,
      inviteUrl: inviteUrl,
    );

    showDialog(
      context: context,
      builder: (_) => _InviteShareDialog(
        variables: variables,
        inviteUrl: inviteUrl,
        onCopied: () => _showSnackBar('클립보드에 복사되었어요!'),
      ),
    );
  }

  /// 방 나가기
  Future<void> _leaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '방 나가기',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '정말 이 방을 나갈까요?',
          style: TextStyle(
            fontFamily: 'Inter',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '나가기',
              style: TextStyle(color: AppColors.accentRed),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    if (_myMemberId != null) {
      try {
        await _svc.leaveMember(memberId: _myMemberId!);
      } catch (_) {}
    }

    if (mounted) context.go('/');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
      ),
    );
  }

  String _errorToKorean(String code) {
    switch (code) {
      case 'ROOM_CLOSED':
        return '방이 마감되었어요';
      case 'SLOT_TAKEN':
        return '이미 다른 사람이 선택했어요';
      case 'ALREADY_JOINED':
        return '이미 참여 중이에요';
      default:
        return '오류가 발생했어요';
    }
  }

  String _stateToKorean(String? state) {
    switch (state) {
      case 'joined':
        return '참여 중';
      case 'watching':
        return '관전 중';
      case 'left':
        return '나감';
      default:
        return '알 수 없음';
    }
  }

  // --- UI 빌드 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.accentPurple))
            : _error != null
                ? _buildErrorView()
                : _buildContent(),
      ),
    );
  }

  /// 헤더 버튼 위젯
  Widget _buildHeaderButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    int? badge,
    bool isDanger = false,
  }) {
    return Stack(
      children: [
        Material(
          color: isActive ? AppColors.accentPurple.withValues(alpha: 0.15) : AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDanger
                      ? AppColors.accentRed.withValues(alpha: 0.3)
                      : isActive
                          ? AppColors.accentPurple.withValues(alpha: 0.3)
                          : AppColors.borderSubtle,
                ),
              ),
              child: Icon(
                icon,
                color: isDanger
                    ? AppColors.accentRed
                    : isActive
                        ? AppColors.accentPurple
                        : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 공통 아이콘 버튼 (둥근 사각형 호버)
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 40,
    double iconSize = 20,
    Color? color,
    Color? iconColor,
  }) {
    return Material(
      color: color ?? AppColors.bgElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.textPrimary,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
          const SizedBox(height: 16),
          Text(
            '방을 불러올 수 없어요',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
            ),
            child: Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final room = _room!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // 모바일: 채팅은 오버레이로, 데스크탑: 사이드 패널
    return Stack(
      children: [
        // 메인 콘텐츠
        Column(
          children: [
            // 커스텀 헤더 (콘텐츠 영역과 정렬)
            _buildCustomHeader(isMobile),

            // 스크롤 가능한 콘텐츠
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 12 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 방 정보
                        _buildRoomInfoCard(room),
                        const SizedBox(height: 16),

                        // 만료/마감 경고
                        if (!room.isOpen || _remainingTime == Duration.zero)
                          ...[_buildExpiredBanner(), const SizedBox(height: 16)],

                        // 슬롯 현황
                        _buildSlotsCard(room),
                        const SizedBox(height: 16),

                        // 내 상태
                        _buildMyStatusPanel(),
                        const SizedBox(height: 16),

                        // 액션 버튼
                        _buildActionButtons(),

                        // 모바일에서 채팅 열렸을 때 여백
                        if (isMobile && _showChat) const SizedBox(height: 300),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // 채팅 패널 (모바일: 하단 시트, 데스크탑: 사이드 패널)
        if (_showChat)
          isMobile
              ? _buildMobileChatPanel()
              : Positioned(
                  right: 16,
                  top: 70,
                  bottom: 16,
                  child: _buildChatPanel(),
                ),
      ],
    );
  }

  /// 커스텀 헤더 (콘텐츠와 정렬)
  Widget _buildCustomHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Row(
            children: [
              // 뒤로가기 버튼
              _buildIconButton(
                icon: Icons.arrow_back,
                onPressed: () => context.go('/'),
              ),
              const SizedBox(width: 8),
              // 타이틀
              Expanded(
                child: Text(
                  '파티 #${widget.code}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // 채팅 버튼
              Tooltip(
                message: _showChat ? '채팅 닫기' : '채팅 열기',
                textStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: _buildHeaderButton(
                  icon: _showChat ? Icons.chat : Icons.chat_outlined,
                  isActive: _showChat,
                  onPressed: () => setState(() => _showChat = !_showChat),
                  badge: _messages.isNotEmpty ? _messages.length : null,
                ),
              ),
              const SizedBox(width: 8),
              // 나가기 버튼
              Tooltip(
                message: '방 나가기',
                textStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: _buildHeaderButton(
                  icon: Icons.logout_rounded,
                  isActive: false,
                  onPressed: _leaveRoom,
                  isDanger: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 모바일용 채팅 패널 (하단 시트 스타일)
  Widget _buildMobileChatPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 드래그 핸들 + 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '채팅',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _buildIconButton(
                    icon: Icons.close,
                    onPressed: () => setState(() => _showChat = false),
                    size: 32,
                    iconSize: 18,
                  ),
                ],
              ),
            ),

            // 메시지 목록
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        '아직 메시지가 없어요',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                    ),
            ),

            // 입력창
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '메시지 입력...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.bgPage,
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
                            borderSide: BorderSide(color: AppColors.accentPurple, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메시지 전송 버튼
  Widget _buildSendButton() {
    return Material(
      color: AppColors.accentPurple,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _sendMessage,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 340,
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // 채팅 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_rounded, size: 18, color: AppColors.accentPurple),
                  const SizedBox(width: 8),
                  Text(
                    '채팅',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _buildIconButton(
                    icon: Icons.close,
                    onPressed: () => setState(() => _showChat = false),
                    size: 32,
                    iconSize: 18,
                  ),
                ],
              ),
            ),

            // 메시지 목록
            Expanded(
              child: Container(
                color: AppColors.bgPage,
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              '아직 메시지가 없어요',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                      ),
              ),
            ),

            // 입력창
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                border: Border(
                  top: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '메시지 입력...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.bgElevated,
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
                          borderSide: BorderSide(color: AppColors.accentPurple, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSendButton(),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.memberId == _myMemberId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accentPurple : AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ),
                  Text(
                    msg.content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 방 정보 카드
  Widget _buildRoomInfoCard(Room room) {
    final game = GameData.findGame(room.gameKey);
    final goal = GameData.findGoal(room.goal);
    final mode = game?.modes.where((m) => m.key == room.mode).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 게임 정보 헤더
          Row(
            children: [
              if (game != null) ...[
                Text(
                  game.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game?.name ?? room.gameKey.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${mode?.name ?? room.mode} · ${goal?.name ?? room.goal}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 인원 및 태그
          Row(
            children: [
              Text(
                '$_joinedCount/${room.maxMembers}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _buildTag(
                icon: Icons.mic,
                text: '마이크 ${room.requireMic ? "O" : "X"}',
                color: room.requireMic ? AppColors.accentGreen : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _buildExpiryTag(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 만료 시간 태그 위젯
  Widget _buildExpiryTag() {
    if (_remainingTime == null) {
      return _buildTag(
        icon: Icons.all_inclusive,
        text: '무제한',
        color: AppColors.textSecondary,
      );
    }

    final remaining = _remainingTime!;
    if (remaining == Duration.zero) {
      return _buildTag(
        icon: Icons.warning,
        text: '만료됨',
        color: AppColors.accentRed,
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    String text;
    Color color;

    if (hours > 0) {
      text = '${hours}시간 ${minutes}분';
      color = AppColors.accentGreen;
    } else if (minutes > 10) {
      text = '${minutes}분';
      color = AppColors.accentOrange;
    } else {
      text = '$minutes:${seconds.toString().padLeft(2, '0')}';
      color = AppColors.accentRed;
    }

    return _buildTag(
      icon: Icons.timer,
      text: text,
      color: color,
    );
  }

  /// 슬롯 현황 카드
  Widget _buildSlotsCard(Room room) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '슬롯 현황',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...room.slots.map((role) => _buildSlotItem(role)),
        ],
      ),
    );
  }

  Widget _buildSlotItem(String role) {
    final member = _joinedMembers.where((m) => m.role == role).firstOrNull;
    final isMe = member?.id == _myMemberId;
    final isFilled = member != null;

    return GestureDetector(
      onTap: _canChangeSlot && !isFilled ? () => _claimRole(role) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? AppColors.accentPurple : AppColors.borderSubtle,
            width: isMe ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                role,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: isFilled
                  ? Row(
                      children: [
                        Text(
                          member.displayName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentPurple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ME',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      '참여하기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _canChangeSlot ? AppColors.accentPurple : AppColors.textMuted,
                      ),
                    ),
            ),
            if (isFilled)
              Row(
                children: [
                  Icon(
                    member.ready ? Icons.check_circle : Icons.timer,
                    size: 16,
                    color: member.ready ? AppColors.accentGreen : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    member.ready ? 'Ready' : '준비 중',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: member.ready ? AppColors.accentGreen : AppColors.textSecondary,
                    ),
                  ),
                ],
              )
            else
              Icon(
                Icons.person_add,
                size: 20,
                color: _canChangeSlot ? AppColors.accentPurple : AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }

  /// 방 만료/마감 경고 배너
  Widget _buildExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: AppColors.accentOrange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '이 방은 마감되었거나 만료되었어요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.accentOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 내 상태 패널
  Widget _buildMyStatusPanel() {
    final me = _me;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 헤더
          Row(
            children: [
              Text(
                '내 상태',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _stateToKorean(me?.state),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: me?.isJoined == true ? AppColors.accentPurple : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 상태별 컨텐츠
          if (me == null)
            Text(
              '세션이 없어요. 링크로 다시 입장해주세요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else if (me.isJoined) ...[
            // 참여 중: Ready 토글
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ready',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Switch(
                  value: me.ready,
                  onChanged: _toggleReady,
                  activeColor: AppColors.accentGreen,
                ),
              ],
            ),
          ] else if (me.isWatching)
            Text(
              '슬롯을 선택해서 파티에 참여하세요.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// 하단 액션 버튼
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 초대 공유 버튼
        Expanded(
          child: _ActionButton(
            icon: Icons.share_rounded,
            label: '초대 공유',
            onPressed: _share,
          ),
        ),
        const SizedBox(width: 12),
        // 새로고침 버튼
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: '새로고침',
          onPressed: _loadRoom,
        ),
      ],
    );
  }
}

/// 초대 공유 다이얼로그 (템플릿 선택 + 편집)
class _InviteShareDialog extends StatefulWidget {
  final Map<String, String> variables;
  final String inviteUrl;
  final VoidCallback onCopied;

  const _InviteShareDialog({
    required this.variables,
    required this.inviteUrl,
    required this.onCopied,
  });

  @override
  State<_InviteShareDialog> createState() => _InviteShareDialogState();
}

class _InviteShareDialogState extends State<_InviteShareDialog> {
  late InviteTemplate _selectedTemplate;
  late TextEditingController _editController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = ShareService.templates.first;
    _editController = TextEditingController(
      text: _selectedTemplate.apply(widget.variables),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _onTemplateChanged(InviteTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _editController.text = template.apply(widget.variables);
      _isEditing = false;
    });
  }

  String get _currentText => _isEditing
      ? _editController.text
      : _selectedTemplate.apply(widget.variables);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Text(
                  '초대 공유',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Material(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 템플릿 선택
            Text(
              '템플릿',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ShareService.templates.map((t) {
                  final isSelected = t.id == _selectedTemplate.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onTemplateChanged(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentPurple : AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.accentPurple : AppColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          t.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 메시지 미리보기/편집
            Row(
              children: [
                Text(
                  _isEditing ? '메시지 편집' : '메시지 미리보기',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Material(
                  color: _isEditing
                      ? AppColors.accentPurple.withValues(alpha: 0.1)
                      : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => setState(() => _isEditing = !_isEditing),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isEditing
                              ? AppColors.accentPurple.withValues(alpha: 0.3)
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isEditing ? Icons.visibility : Icons.edit,
                            size: 14,
                            color: _isEditing ? AppColors.accentPurple : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isEditing ? '미리보기' : '편집',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _isEditing ? AppColors.accentPurple : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: _isEditing
                  ? TextField(
                      controller: _editController,
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(16),
                        border: InputBorder.none,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          _currentText,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // 초대 링크
            Text(
              '초대 링크',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.inviteUrl,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: widget.inviteUrl));
                        widget.onCopied();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _currentText));
                      if (context.mounted) Navigator.pop(context);
                      widget.onCopied();
                    },
                    icon: Icon(Icons.copy, size: 18),
                    label: Text('메시지 복사'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 액션 버튼 위젯 (통일된 디자인)
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? AppColors.accentPurple : AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isPrimary ? null : Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
