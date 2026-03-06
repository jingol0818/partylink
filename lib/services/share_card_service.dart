import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/services.dart';

import '../models/game_player.dart';

@JS('window._downloadShareCard')
external void _jsDownloadCard(JSString jsonStr);

@JS('window._shareShareCard')
external JSPromise<JSString> _jsShareCard(JSString jsonStr);

/// 결과 공유 카드 서비스
///
/// JavaScript Canvas 2D API로 공유용 이미지를 생성하고
/// 다운로드/공유 기능을 제공합니다.
class ShareCardService {
  /// 공유 카드 JSON 데이터 생성
  static String _buildJson({
    required List<GamePlayer> players,
    required String? myPlayerId,
    required String? topic,
    required bool won,
    required int myScore,
  }) {
    final playerList = players.map((p) => {
      'id': p.id,
      'nickname': p.nickname,
      'shape': p.avatarShape,
      'color': p.avatarColor,
      'isAi': p.isAi ?? false,
      'score': p.score,
    }).toList();

    return jsonEncode({
      'players': playerList,
      'myId': myPlayerId,
      'topic': topic ?? '자유 대화',
      'won': won,
      'myScore': myScore,
      'siteUrl': 'partylink.vercel.app',
    });
  }

  /// 이미지 다운로드 (PNG)
  static void download({
    required List<GamePlayer> players,
    required String? myPlayerId,
    required String? topic,
    required bool won,
    required int myScore,
  }) {
    final json = _buildJson(
      players: players,
      myPlayerId: myPlayerId,
      topic: topic,
      won: won,
      myScore: myScore,
    );
    _jsDownloadCard(json.toJS);
  }

  /// Web Share API로 공유 (미지원 시 다운로드 폴백)
  static Future<void> share({
    required List<GamePlayer> players,
    required String? myPlayerId,
    required String? topic,
    required bool won,
    required int myScore,
  }) async {
    final json = _buildJson(
      players: players,
      myPlayerId: myPlayerId,
      topic: topic,
      won: won,
      myScore: myScore,
    );
    await _jsShareCard(json.toJS).toDart;
  }

  /// 초대 링크 복사
  static Future<void> copyLink() async {
    const url = 'https://partylink.vercel.app';
    await Clipboard.setData(const ClipboardData(text: url));
  }
}
