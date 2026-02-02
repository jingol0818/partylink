import 'dart:math';
import '../models/room.dart';
import '../models/member.dart';
import '../supabase_client.dart';

/// 방 관련 CRUD 및 비즈니스 로직
class RoomService {
  // ─── 방 조회 ────────────────────────────────────────────

  /// 초대코드로 방 조회
  Future<Room> getRoomByCode(String code) async {
    final data = await supa()
        .from('rooms')
        .select()
        .eq('code', code)
        .single();
    return Room.fromMap(data);
  }

  /// 방 ID로 조회
  Future<Room> getRoomById(String roomId) async {
    final data = await supa()
        .from('rooms')
        .select()
        .eq('id', roomId)
        .single();
    return Room.fromMap(data);
  }

  /// 방 코드 존재 여부 확인 (코드 생성 시 중복 체크용)
  Future<bool> checkCodeExists(String code) async {
    final rows = await supa()
        .from('rooms')
        .select('id')
        .eq('code', code)
        .limit(1);
    return rows.isNotEmpty;
  }

  // ─── 방 생성 ────────────────────────────────────────────

  /// 중복 없는 6자리 초대코드 생성 (최대 5회 시도)
  Future<String> generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(
        6,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      if (!await checkCodeExists(code)) return code;
    }

    throw Exception('고유 코드 생성에 실패했습니다. 다시 시도해주세요.');
  }

  /// 새 방 생성 → 방 ID 반환
  Future<String> createRoom({
    required String gameKey,
    String? mode,
    required String goal,
    required List<String> slots,
    required bool requireMic,
    required int maxMembers,
    required String code,
    required DateTime expiresAt,
    String? roomName,
    int teamCount = 1,
    int membersPerTeam = 5,
    List<String>? customSlotNames,
    String? hostSessionId,
  }) async {
    final row = await supa().from('rooms').insert({
      'code': code,
      'game_key': gameKey,
      'mode': mode,
      'goal': goal,
      'max_members': maxMembers,
      'slots': slots,
      'require_mic': requireMic,
      'status': 'open',
      'expires_at': expiresAt.toIso8601String(),
      'room_name': roomName,
      'team_count': teamCount,
      'members_per_team': membersPerTeam,
      'custom_slot_names': customSlotNames,
      'host_session_id': hostSessionId,
    }).select('id').single();

    return row['id'].toString();
  }

  /// 방 설정 업데이트 (방장 전용)
  Future<void> updateRoom({
    required String roomId,
    int? teamCount,
    int? membersPerTeam,
    List<String>? slots,
    List<String>? customSlotNames,
    bool? requireMic,
    int? maxMembers,
  }) async {
    final Map<String, dynamic> updates = {};

    if (teamCount != null) updates['team_count'] = teamCount;
    if (membersPerTeam != null) updates['members_per_team'] = membersPerTeam;
    if (slots != null) updates['slots'] = slots;
    if (customSlotNames != null) updates['custom_slot_names'] = customSlotNames;
    if (requireMic != null) updates['require_mic'] = requireMic;
    if (maxMembers != null) updates['max_members'] = maxMembers;

    if (updates.isNotEmpty) {
      await supa().from('rooms').update(updates).eq('id', roomId);
    }
  }

  // ─── 멤버 관리 ──────────────────────────────────────────

  /// 방의 전체 멤버 목록 조회 (입장 순 정렬)
  Future<List<Member>> listMembers(String roomId) async {
    final rows = await supa()
        .from('members')
        .select()
        .eq('room_id', roomId)
        .order('joined_at');
    return rows.map<Member>((m) => Member.fromMap(m)).toList();
  }

  /// 관전자(watching)로 입장 → memberId 반환
  ///
  /// 입장 = 관전 상태로 시작. 자리 확정은 [claimSlot]으로 별도 진행.
  Future<String> enterAsWatching({
    required String roomId,
    required String displayName,
    String? tag,
    String? inviteId,
    String? sessionId,
  }) async {
    final row = await supa().from('members').insert({
      'room_id': roomId,
      'display_name': displayName,
      'tag': tag,
      'state': 'watching',
      'invite_id': inviteId,
      'session_id': sessionId,
    }).select('id').single();

    return row['id'].toString();
  }

  /// 슬롯에 바로 참여 (입장 즉시 자리 배정)
  Future<String> enterAndJoinSlot({
    required String roomId,
    required String displayName,
    required String role,
    String? inviteId,
    String? sessionId,
  }) async {
    final row = await supa().from('members').insert({
      'room_id': roomId,
      'display_name': displayName,
      'role': role,
      'state': 'joined',
      'invite_id': inviteId,
      'session_id': sessionId,
    }).select('id').single();

    return row['id'].toString();
  }

  /// 슬롯 점유 (역할 선택 → 자리 확정)
  ///
  /// Supabase RPC `claim_slot`을 호출하여 원자적으로 처리.
  /// 반환: (ok: 성공여부, message: 결과코드)
  Future<({bool ok, String message})> claimSlot({
    required String roomCode,
    required String memberId,
    required String role,
  }) async {
    final result = await supa().rpc('claim_slot', params: {
      'p_room_code': roomCode,
      'p_member_id': memberId,
      'p_role': role,
    });

    if (result is List && result.isNotEmpty) {
      final row = Map<String, dynamic>.from(result[0] as Map);
      return (
        ok: row['ok'] == true,
        message: row['message']?.toString() ?? 'UNKNOWN',
      );
    }

    return (ok: false, message: 'UNKNOWN');
  }

  /// Ready 상태 변경
  Future<void> setReady({
    required String memberId,
    required bool ready,
  }) async {
    await supa().from('members').update({
      'ready': ready,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', memberId);
  }

  /// 멤버 정보 업데이트 (닉네임, 초대방법 등)
  Future<void> updateMember({
    required String memberId,
    String? displayName,
    String? inviteId,
  }) async {
    final Map<String, dynamic> updates = {
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (displayName != null) updates['display_name'] = displayName;
    if (inviteId != null) updates['invite_id'] = inviteId;

    await supa().from('members').update(updates).eq('id', memberId);
  }

  /// 슬롯 해제 (joined → watching, 역할 변경 시 사용)
  Future<void> releaseSlot({required String memberId}) async {
    await supa().from('members').update({
      'state': 'watching',
      'role': null,
      'ready': false,
    }).eq('id', memberId);
  }

  /// 방 나가기 (상태를 left로 변경)
  Future<void> leaveMember({required String memberId}) async {
    await supa().from('members').update({
      'state': 'left',
      'ready': false,
    }).eq('id', memberId);
  }

  /// 세션 ID로 멤버 찾기 (퇴장 처리용)
  Future<Member?> findMemberBySession({
    required String roomId,
    required String sessionId,
  }) async {
    final rows = await supa()
        .from('members')
        .select()
        .eq('room_id', roomId)
        .eq('session_id', sessionId)
        .inFilter('state', ['watching', 'joined'])
        .limit(1);

    if (rows.isEmpty) return null;
    return Member.fromMap(rows.first);
  }

  // ─── 방 목록 조회 ────────────────────────────────────────

  /// 열린 방 목록 조회 (게임 필터, 검색어, 가득 찬 방 숨기기 가능)
  Future<List<RoomWithCount>> listOpenRooms({
    String? gameKey,
    String? searchQuery,
    bool hideFullRooms = false,
  }) async {
    var query = supa()
        .from('rooms')
        .select()
        .eq('status', 'open')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());

    if (gameKey != null && gameKey.isNotEmpty) {
      query = query.eq('game_key', gameKey);
    }

    // 방 이름 검색 (ilike 사용)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('room_name', '%${searchQuery.trim()}%');
    }

    final rows = await query.order('created_at', ascending: false).limit(100);
    final rooms = rows.map<Room>((r) => Room.fromMap(r)).toList();

    // 각 방의 참여 인원 수 조회
    final List<RoomWithCount> result = [];
    for (final room in rooms) {
      final memberCount = await _countJoinedMembers(room.id);

      // 가득 찬 방 숨기기
      if (hideFullRooms && memberCount >= room.maxMembers) {
        continue;
      }

      result.add(RoomWithCount(room: room, joinedCount: memberCount));
    }

    return result;
  }

  /// 방의 참여 인원 수 조회
  Future<int> _countJoinedMembers(String roomId) async {
    final rows = await supa()
        .from('members')
        .select('id')
        .eq('room_id', roomId)
        .eq('state', 'joined');
    return rows.length;
  }

  /// 방에서 빈 슬롯 찾기
  Future<String?> findEmptySlot(String roomId) async {
    final room = await getRoomById(roomId);
    final members = await listMembers(roomId);

    final occupiedRoles = members
        .where((m) => m.isJoined && m.role != null)
        .map((m) => m.role!)
        .toSet();

    for (final slot in room.slots) {
      if (!occupiedRoles.contains(slot)) {
        return slot;
      }
    }
    return null;
  }

  /// 다음 사용자 번호 생성 (사용자 1, 사용자 2, ...)
  Future<int> getNextUserNumber(String roomId) async {
    final members = await listMembers(roomId);
    int maxNum = 0;

    final regex = RegExp(r'사용자 (\d+)');
    for (final m in members) {
      final match = regex.firstMatch(m.displayName);
      if (match != null) {
        final num = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (num > maxNum) maxNum = num;
      }
    }

    return maxNum + 1;
  }
}

/// 방 정보 + 참여 인원 수
class RoomWithCount {
  final Room room;
  final int joinedCount;

  RoomWithCount({required this.room, required this.joinedCount});

  /// 방이 가득 찼는지 확인
  bool get isFull => joinedCount >= room.maxMembers;
}
