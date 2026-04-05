import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/config/app_theme.dart';
import 'package:nsfw_chat/core/services/chat_image_cleanup_service.dart';
import 'package:nsfw_chat/l10n/app_localizations.dart';
import 'package:nsfw_chat/presentation/providers/persona_provider.dart';
import 'package:nsfw_chat/presentation/providers/recent_chats_provider.dart';
import 'package:nsfw_chat/presentation/providers/settings_provider.dart';
import 'package:nsfw_chat/presentation/screens/age_gate_screen.dart';
import 'package:nsfw_chat/presentation/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/factory/database_helper.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // DB открывается первой — как и было
  await DatabaseHelper.instance.initDB();

  // Прогреваем провайдеры ДО runApp, чтобы первый кадр
  // не блокировался их инициализацией
  final container = ProviderContainer();
  await Future.wait([
    container.read(personaProvider.future),
    container.read(recentChatsProvider.future),
  ]);

  runApp(
    // Передаём уже прогретый контейнер — данные закешированы
    UncontrolledProviderScope(
      container: container,
      child: const NsfwChatApp(),
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class NsfwChatApp extends ConsumerWidget {
  const NsfwChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(settingsProvider.select((s) => s.selectedLocale));
    final locale = localeCode != null ? Locale(localeCode) : null;

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Uncensored Souls',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale, // null = следовать системе
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkApiKeyAndNavigate();
  }

  Future<void> _checkApiKeyAndNavigate() async {
    // Сначала все быстрые операции
    final prefs = await SharedPreferences.getInstance();
    final ageConfirmed = prefs.getBool('age_confirmed') ?? false;

    if (!mounted) return;

    // Снимаем splash только перед самой навигацией
    FlutterNativeSplash.remove();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ageConfirmed ? const HomeScreen() : const AgeGateScreen(),
      ),
    );

    // Cleanup запускаем ПОСЛЕ навигации, в фоне
    final container = ProviderScope.containerOf(context);
    final settings = container.read(settingsProvider);
    unawaited(ChatImageCleanupService.instance.runIfEnabled(settings));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Uncensored Souls',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}