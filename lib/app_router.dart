import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/create_room_page.dart';
import 'pages/enter_room_page.dart';
import 'pages/room_page.dart';
import 'pages/browse_rooms_page.dart';

/// 앱 라우팅 설정
///
/// /           → 홈 (방 만들기 진입)
/// /create     → 방 생성 화면
/// /browse     → 방 찾기 화면
/// /r/:code    → 링크 진입 화면 (닉네임 입력)
/// /room/:code → 방 메인 화면 (슬롯 + Ready)
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomePage(),
    ),
    GoRoute(
      path: '/create',
      builder: (_, __) => const CreateRoomPage(),
    ),
    GoRoute(
      path: '/browse',
      builder: (_, __) => const BrowseRoomsPage(),
    ),
    GoRoute(
      path: '/r/:code',
      builder: (_, state) => EnterRoomPage(
        code: state.pathParameters['code']!,
      ),
    ),
    GoRoute(
      path: '/room/:code',
      builder: (_, state) => RoomPage(
        code: state.pathParameters['code']!,
      ),
    ),
  ],
);
