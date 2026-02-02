import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dtsvayaiolvcscgewodr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR0c3ZheWFpb2x2Y3NjZ2V3b2RyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk5NDcwNDMsImV4cCI6MjA4NTUyMzA0M30.X2x2yCk5m4960mYY1TuPbDOXr0RSIlAxIj_5L88orbk',
  );

  runApp(const PartyLinkApp());
}

class PartyLinkApp extends StatefulWidget {
  const PartyLinkApp({super.key});

  static _PartyLinkAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_PartyLinkAppState>();

  @override
  State<PartyLinkApp> createState() => _PartyLinkAppState();
}

class _PartyLinkAppState extends State<PartyLinkApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
      AppColors.setDarkMode(mode == ThemeMode.dark ||
          (mode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark));
    });
  }

  @override
  void initState() {
    super.initState();
    // 초기 테마 설정
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppColors.setDarkMode(brightness == Brightness.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PartyLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      routerConfig: router,
    );
  }
}
