import 'package:shared_preferences/shared_preferences.dart';

/// 방 생성 제한 서비스
///
/// 세션 기반으로 방 생성 쿨다운을 관리합니다.
class RateLimitService {
  static const String _lastRoomCreatedKey = 'last_room_created_at';
  static const String _roomCreatedCountKey = 'room_created_count';
  static const String _roomCreatedDateKey = 'room_created_date';

  /// 방 생성 쿨다운 (5분)
  static const Duration cooldownDuration = Duration(minutes: 5);

  /// 하루 최대 방 생성 수
  static const int maxRoomsPerDay = 10;

  /// 방 생성이 가능한지 확인
  /// 반환: (canCreate: 생성 가능 여부, message: 메시지, remainingSeconds: 남은 쿨다운 초)
  static Future<({bool canCreate, String? message, int remainingSeconds})> canCreateRoom() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 일일 생성 횟수 확인
    final today = _getTodayString();
    final savedDate = prefs.getString(_roomCreatedDateKey);
    int todayCount = prefs.getInt(_roomCreatedCountKey) ?? 0;

    // 날짜가 바뀌면 카운트 리셋
    if (savedDate != today) {
      todayCount = 0;
    }

    if (todayCount >= maxRoomsPerDay) {
      return (
        canCreate: false,
        message: '오늘 방 생성 횟수를 초과했어요. (최대 $maxRoomsPerDay개)',
        remainingSeconds: 0,
      );
    }

    // 2. 쿨다운 확인
    final lastCreatedStr = prefs.getString(_lastRoomCreatedKey);
    if (lastCreatedStr != null) {
      final lastCreated = DateTime.tryParse(lastCreatedStr);
      if (lastCreated != null) {
        final elapsed = DateTime.now().difference(lastCreated);
        if (elapsed < cooldownDuration) {
          final remaining = cooldownDuration - elapsed;
          return (
            canCreate: false,
            message: '잠시 후 다시 시도해주세요.',
            remainingSeconds: remaining.inSeconds,
          );
        }
      }
    }

    return (
      canCreate: true,
      message: null,
      remainingSeconds: 0,
    );
  }

  /// 방 생성 기록
  static Future<void> recordRoomCreation() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = _getTodayString();

    // 마지막 생성 시간 기록
    await prefs.setString(_lastRoomCreatedKey, now.toIso8601String());

    // 일일 카운트 업데이트
    final savedDate = prefs.getString(_roomCreatedDateKey);
    int todayCount = prefs.getInt(_roomCreatedCountKey) ?? 0;

    if (savedDate != today) {
      // 날짜가 바뀌면 리셋
      todayCount = 1;
      await prefs.setString(_roomCreatedDateKey, today);
    } else {
      todayCount++;
    }

    await prefs.setInt(_roomCreatedCountKey, todayCount);
  }

  /// 남은 일일 생성 가능 횟수 조회
  static Future<int> getRemainingDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_roomCreatedDateKey);

    if (savedDate != today) {
      return maxRoomsPerDay;
    }

    final todayCount = prefs.getInt(_roomCreatedCountKey) ?? 0;
    return (maxRoomsPerDay - todayCount).clamp(0, maxRoomsPerDay);
  }

  /// 오늘 날짜 문자열 (YYYY-MM-DD)
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
