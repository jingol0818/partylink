import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_router.dart';
import 'supabase_client.dart' show supabaseUrl, supabaseAnonKey;
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // dotenv 시도 (실패해도 하드코딩 폴백 사용)
  String url = supabaseUrl;
  String key = supabaseAnonKey;
  try {
    await dotenv.load(fileName: '.env');
    final envUrl = dotenv.env['SUPABASE_URL'];
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envUrl != null && envUrl.isNotEmpty) url = envUrl;
    if (envKey != null && envKey.isNotEmpty) key = envKey;
  } catch (e) {
    debugPrint('[INIT] dotenv load failed, using fallback: $e');
  }

  debugPrint('[INIT] Supabase URL: ${url.substring(0, 30)}...');

  try {
    await Supabase.initialize(url: url, anonKey: key);
  } catch (e) {
    debugPrint('[INIT] Supabase init failed: $e');
  }

  runApp(const PartyLinkApp());
}

class PartyLinkApp extends StatelessWidget {
  const PartyLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(true);
    return MaterialApp.router(
      title: '누가 AI야?',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
