import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 인스턴스
SupabaseClient supa() => Supabase.instance.client;

/// 앱 베이스 URL (초대 링크 생성 시 사용)
/// 웹에서는 현재 접속 URL을 자동 감지, 그 외에는 기본값 사용
String get appBaseUrl {
  if (kIsWeb) {
    // 웹에서 현재 URL 기반으로 생성
    return Uri.base.origin;
  }
  // 네이티브 앱에서는 배포 도메인 사용
  return 'https://partylink.app';
}
