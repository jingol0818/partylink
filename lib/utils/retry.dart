import 'dart:math';

/// RPC 호출에 사용하는 재시도 유틸리티.
/// 지수 백오프로 최대 [maxAttempts]번 재시도.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i == maxAttempts - 1) rethrow;
      await Future.delayed(Duration(seconds: pow(2, i).toInt()));
    }
  }
  throw StateError('unreachable');
}
