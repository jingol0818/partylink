import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/room.dart';
import '../models/game.dart';
import '../supabase_client.dart';

/// 초대 메시지 템플릿
class InviteTemplate {
  final String id;
  final String name;
  final String template;

  const InviteTemplate({
    required this.id,
    required this.name,
    required this.template,
  });

  /// 템플릿 변수 치환 (개별 파라미터 버전)
  String build({
    required String gameName,
    required String gameIcon,
    required String modeName,
    required String goalName,
    required int joinedCount,
    required int maxMembers,
    required List<String> missingRoles,
    required bool requireMic,
    required String url,
  }) {
    final roles = missingRoles.isEmpty ? '자리 남음' : missingRoles.join(', ');
    final mic = requireMic ? 'O' : 'X';

    return template
        .replaceAll('{game_icon}', gameIcon)
        .replaceAll('{game_name}', gameName)
        .replaceAll('{mode}', modeName)
        .replaceAll('{goal}', goalName)
        .replaceAll('{joined}', joinedCount.toString())
        .replaceAll('{max}', maxMembers.toString())
        .replaceAll('{roles}', roles)
        .replaceAll('{mic}', mic)
        .replaceAll('{url}', url);
  }

  /// 템플릿 변수 치환 (Map 버전)
  String apply(Map<String, String> variables) {
    var result = template;
    variables.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}

/// 초대 링크 생성 및 공유 서비스
class ShareService {
  /// 기본 템플릿 목록
  static const List<InviteTemplate> templates = [
    InviteTemplate(
      id: 'default',
      name: '기본',
      template: '{game_icon} {game_name} {mode} 파티 모집 ({joined}/{max})\n'
          '구함: {roles} · 마이크 {mic}\n'
          '입장: {url}',
    ),
    InviteTemplate(
      id: 'simple',
      name: '심플',
      template: '{game_name} {goal} ({joined}/{max})\n{url}',
    ),
    InviteTemplate(
      id: 'detailed',
      name: '상세',
      template: '━━━━━━━━━━━━━━━━━━━━\n'
          '{game_icon} {game_name} 파티원 모집\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '📋 모드: {mode}\n'
          '🎯 목표: {goal}\n'
          '👥 인원: {joined}/{max}\n'
          '🎙️ 마이크: {mic}\n'
          '🔎 구함: {roles}\n'
          '━━━━━━━━━━━━━━━━━━━━\n'
          '🔗 입장: {url}',
    ),
    InviteTemplate(
      id: 'discord',
      name: '디스코드',
      template: '```\n'
          '{game_name} | {mode} | {goal}\n'
          '인원: {joined}/{max} | 마이크: {mic}\n'
          '구함: {roles}\n'
          '```\n'
          '{url}',
    ),
  ];

  /// 초대 메시지 텍스트 생성 (기본 템플릿)
  static String buildInviteText({
    required Room room,
    required int joinedCount,
    required List<String> missingRoles,
  }) {
    return buildInviteTextWithTemplate(
      room: room,
      joinedCount: joinedCount,
      missingRoles: missingRoles,
      template: templates.first,
    );
  }

  /// 초대 메시지 텍스트 생성 (템플릿 지정)
  static String buildInviteTextWithTemplate({
    required Room room,
    required int joinedCount,
    required List<String> missingRoles,
    required InviteTemplate template,
  }) {
    final game = GameData.findGame(room.gameKey);
    final goal = GameData.findGoal(room.goal);
    final mode = game?.modes.where((m) => m.key == room.mode).firstOrNull;

    return template.build(
      gameName: game?.name ?? room.gameKey.toUpperCase(),
      gameIcon: game?.icon ?? '🎮',
      modeName: mode?.name ?? room.mode,
      goalName: goal?.name ?? room.goal,
      joinedCount: joinedCount,
      maxMembers: room.maxMembers,
      missingRoles: missingRoles,
      requireMic: room.requireMic,
      url: getInviteUrl(room.code),
    );
  }

  /// 커스텀 템플릿으로 초대 메시지 생성
  static String buildCustomInviteText({
    required Room room,
    required int joinedCount,
    required List<String> missingRoles,
    required String customTemplate,
  }) {
    final game = GameData.findGame(room.gameKey);
    final goal = GameData.findGoal(room.goal);
    final mode = game?.modes.where((m) => m.key == room.mode).firstOrNull;
    final url = getInviteUrl(room.code);
    final roles = missingRoles.isEmpty ? '자리 남음' : missingRoles.join(', ');
    final mic = room.requireMic ? 'O' : 'X';

    return customTemplate
        .replaceAll('{game_icon}', game?.icon ?? '🎮')
        .replaceAll('{game_name}', game?.name ?? room.gameKey.toUpperCase())
        .replaceAll('{mode}', mode?.name ?? room.mode)
        .replaceAll('{goal}', goal?.name ?? room.goal)
        .replaceAll('{joined}', joinedCount.toString())
        .replaceAll('{max}', room.maxMembers.toString())
        .replaceAll('{roles}', roles)
        .replaceAll('{mic}', mic)
        .replaceAll('{url}', url);
  }

  /// 공유 실행
  ///
  /// Web Share API 지원 시 네이티브 공유,
  /// 미지원 시 클립보드 복사로 폴백합니다.
  /// 반환: true=공유 성공, false=클립보드 복사로 대체
  static Future<bool> shareInvite(String text) async {
    try {
      await Share.share(text);
      return true;
    } catch (_) {
      // Web Share API 미지원 환경 (HTTP, 데스크톱 등)
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }

  /// 초대 링크 URL만 생성
  static String getInviteUrl(String roomCode) {
    return '$appBaseUrl/#/r/$roomCode';
  }

  /// 템플릿 변수 Map 생성
  static Map<String, String> buildTemplateVariables({
    required Room room,
    required int joinedCount,
    required List<String> missingRoles,
    required String inviteUrl,
  }) {
    final game = GameData.findGame(room.gameKey);
    final goal = GameData.findGoal(room.goal);
    final mode = game?.modes.where((m) => m.key == room.mode).firstOrNull;
    final roles = missingRoles.isEmpty ? '자리 남음' : missingRoles.join(', ');

    return {
      'game_icon': game?.icon ?? '🎮',
      'game_name': game?.name ?? room.gameKey.toUpperCase(),
      'mode': mode?.name ?? room.mode,
      'goal': goal?.name ?? room.goal,
      'joined': joinedCount.toString(),
      'max': room.maxMembers.toString(),
      'roles': roles,
      'mic': room.requireMic ? 'O' : 'X',
      'url': inviteUrl,
    };
  }
}
