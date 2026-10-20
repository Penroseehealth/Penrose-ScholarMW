import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/syllabus_selection_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/connectivity_manager.dart';
import 'services/data_saver_service.dart';
import 'services/offline_cache_service.dart';
import 'widgets/error_boundary.dart';
import 'widgets/floating_chatbot.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reportClientError('async', error, stack));
    return true;
  };
  runApp(const PenroseScholarApp());
  unawaited(_initializeStartupServices());
}

Future<void> _initializeStartupServices() async {
  await Future.wait([
    _initializeStartupService('data-saver', DataSaverService().init),
    _initializeStartupService('offline-cache', OfflineCacheService().init),
  ]);
}

Future<void> _initializeStartupService(String name, Future<void> Function() initialize) async {
  try {
    await initialize();
  } catch (error, stack) {
    await reportClientError('startup-$name', error, stack);
  }
}

class PenroseScholarApp extends StatefulWidget {
  const PenroseScholarApp({super.key});

  @override
  State<PenroseScholarApp> createState() => _PenroseScholarAppState();
}

class _PenroseScholarAppState extends State<PenroseScholarApp> {
  AppRouter? _appRouter;

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider(create: (_) => ConnectivityManager()..startMonitoring()),
          ChangeNotifierProvider(create: (_) => SyllabusSelectionProvider()..init()),
        ],
        child: Consumer3<AuthProvider, LocaleProvider, ThemeProvider>(
          builder: (context, auth, localeProvider, themeProvider, _) {
            _appRouter ??= AppRouter(auth);
            return ErrorBoundary(
              child: MaterialApp.router(
                title: 'Penrose ScholarMw',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: themeProvider.themeMode,
                locale: localeProvider.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routerConfig: _appRouter!.router,
                builder: (context, child) => FloatingChatbot.wrap(context, child),
              ),
            );
          },
        ),
      );
}
