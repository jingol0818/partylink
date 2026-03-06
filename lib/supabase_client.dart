import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 접속 정보 (anon key는 공개 키이므로 하드코딩 가능)
/// 웹 빌드에서 .env 로딩이 실패할 수 있어 폴백용으로 사용
const supabaseUrl = 'https://dtsvayaiolvcscgewodr.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR0c3ZheWFpb2x2Y3NjZ2V3b2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDcwNDMsImV4cCI6MjA4NTUyMzA0M30.X2x2yCk5m4960mYY1TuPbDOXr0RSIlAxIj_5L88orbk';

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
