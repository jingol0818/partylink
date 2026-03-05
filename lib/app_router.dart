import 'package:go_router/go_router.dart';
import 'pages/lobby_page.dart';
import 'pages/game_page.dart';
import 'pages/matching_page.dart';

/// 앱 라우팅 설정
///
/// /           → 로비 (게임 시작)
/// /matching   → 매칭 대기 화면
/// /game/:code → 게임 메인 화면 (채팅/투표/결과)
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const LobbyPage(),
    ),
    GoRoute(
      path: '/matching',
      builder: (_, state) => MatchingPage(
        nickname: state.uri.queryParameters['nick'] ?? '',
        avatarShape: state.uri.queryParameters['shape'] ?? 'circle',
        avatarColor: state.uri.queryParameters['color'] ?? '#00D9FF',
      ),
    ),
    GoRoute(
      path: '/game/:code',
      builder: (_, state) => GamePage(
        code: state.pathParameters['code']!,
        gameId: state.uri.queryParameters['gid'],
        playerId: state.uri.queryParameters['pid'],
      ),
    ),
  ],
);
