import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// 알림음 서비스 (Web Audio API 사용)
class SoundService {
  static web.AudioContext? _audioContext;

  /// AudioContext 초기화
  static void _initAudioContext() {
    _audioContext ??= web.AudioContext();
  }

  /// "띵!" 알림음 재생 (모든 사람이 준비되었을 때)
  static Future<void> playReadySound() async {
    try {
      _initAudioContext();
      final ctx = _audioContext!;

      // 사용자 인터랙션 후 resume 필요할 수 있음
      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      final oscillator = ctx.createOscillator();
      final gainNode = ctx.createGain();

      // "띵!" 소리 설정
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(880.0, ctx.currentTime); // A5 음

      // 볼륨 엔벨로프 (부드러운 시작과 끝)
      gainNode.gain.setValueAtTime(0.0, ctx.currentTime);
      gainNode.gain.linearRampToValueAtTime(0.3, ctx.currentTime + 0.01);
      gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3);

      // 연결
      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      // 재생
      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + 0.3);
    } catch (e) {
      // 오디오 재생 실패 시 무시 (사용자 인터랙션 필요할 수 있음)
      print('Sound play failed: $e');
    }
  }

  /// 부드러운 알림음 (두 음의 화음)
  static Future<void> playNotificationSound() async {
    try {
      _initAudioContext();
      final ctx = _audioContext!;

      if (ctx.state == 'suspended') {
        await ctx.resume().toDart;
      }

      // 첫 번째 음 (C5)
      final osc1 = ctx.createOscillator();
      final gain1 = ctx.createGain();
      osc1.type = 'sine';
      osc1.frequency.setValueAtTime(523.25, ctx.currentTime);
      gain1.gain.setValueAtTime(0.0, ctx.currentTime);
      gain1.gain.linearRampToValueAtTime(0.2, ctx.currentTime + 0.01);
      gain1.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.2);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);

      // 두 번째 음 (E5) - 살짝 딜레이
      final osc2 = ctx.createOscillator();
      final gain2 = ctx.createGain();
      osc2.type = 'sine';
      osc2.frequency.setValueAtTime(659.25, ctx.currentTime + 0.1);
      gain2.gain.setValueAtTime(0.0, ctx.currentTime + 0.1);
      gain2.gain.linearRampToValueAtTime(0.2, ctx.currentTime + 0.11);
      gain2.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.35);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);

      // 재생
      osc1.start(ctx.currentTime);
      osc1.stop(ctx.currentTime + 0.2);
      osc2.start(ctx.currentTime + 0.1);
      osc2.stop(ctx.currentTime + 0.35);
    } catch (e) {
      print('Sound play failed: $e');
    }
  }
}
