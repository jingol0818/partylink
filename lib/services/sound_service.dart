import 'dart:js_interop';
import 'dart:async';

/// JS eval 호출 (최상위 함수)
@JS('eval')
external JSAny? _jsEval(JSString code);

/// 게임 사운드 서비스 (Web Audio API 기반)
///
/// JavaScript 직접 호출로 외부 파일 없이 효과음 생성
class SoundService {
  static bool _activated = false;

  /// 오디오 컨텍스트 활성화 (사용자 상호작용 후 1회 호출)
  static void activate() {
    if (_activated) return;
    _activated = true;
    _ensureContext();
  }

  static void _ensureContext() {
    _jsEval('''
      if (!window._gameAudioCtx) {
        window._gameAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      if (window._gameAudioCtx.state === 'suspended') {
        window._gameAudioCtx.resume();
      }
    '''.toJS);
  }

  /// 단일 톤 재생
  static void _playTone(double freq, double duration, {double volume = 0.3, String type = 'sine'}) {
    if (!_activated) return;
    _jsEval('''
      (function() {
        var ctx = window._gameAudioCtx;
        if (!ctx) return;
        if (ctx.state === 'suspended') ctx.resume();
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = '$type';
        osc.frequency.value = $freq;
        gain.gain.value = $volume;
        gain.gain.setValueAtTime($volume, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + $duration);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + $duration);
      })()
    '''.toJS);
  }

  /// 매칭 완료
  static void matchFound() {
    _playTone(523.25, 0.15, volume: 0.25);
    Future.delayed(const Duration(milliseconds: 150), () {
      _playTone(659.25, 0.3, volume: 0.25);
    });
  }

  /// 플레이어 입장
  static void playerJoin() {
    _playTone(698.46, 0.08, volume: 0.15);
    Future.delayed(const Duration(milliseconds: 80), () {
      _playTone(880, 0.12, volume: 0.15);
    });
  }

  /// 미션카드 등장
  static void trapCard() {
    _playTone(392, 0.1, type: 'triangle', volume: 0.2);
    Future.delayed(const Duration(milliseconds: 150), () {
      _playTone(523.25, 0.1, type: 'triangle', volume: 0.2);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _playTone(659.25, 0.2, type: 'triangle', volume: 0.25);
    });
  }

  /// 메시지 수신
  static void messageReceived() {
    _playTone(880, 0.08, volume: 0.15);
  }

  /// 페이즈 전환
  static void phaseChange() {
    _playTone(440, 0.12, volume: 0.2);
    Future.delayed(const Duration(milliseconds: 120), () {
      _playTone(554.37, 0.2, volume: 0.2);
    });
  }

  /// 투표
  static void vote() {
    _playTone(392, 0.1, volume: 0.2);
    Future.delayed(const Duration(milliseconds: 100), () {
      _playTone(523.25, 0.15, volume: 0.2);
    });
  }

  /// 결과 공개
  static void resultReveal() {
    _playTone(261.63, 0.2, volume: 0.25);
    Future.delayed(const Duration(milliseconds: 200), () {
      _playTone(329.63, 0.2, volume: 0.25);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _playTone(392, 0.2, volume: 0.25);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      _playTone(523.25, 0.4, volume: 0.3);
    });
  }

  /// 타이머 경고
  static void timerWarning() {
    _playTone(660, 0.06, type: 'square', volume: 0.1);
  }

  /// 게임 시작
  static void gameStart() {
    _playTone(440, 0.15, volume: 0.2);
    Future.delayed(const Duration(milliseconds: 150), () {
      _playTone(554.37, 0.15, volume: 0.2);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _playTone(659.25, 0.3, volume: 0.25);
    });
  }
}
