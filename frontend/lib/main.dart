import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'services/data_saver_service.dart';
import 'services/offline_cache_service.dart';
import 'widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataSaverService().init();
  await OfflineCacheService().init();
  runApp(const PenroseScholarApp());
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
        ],
        child: Consumer3<AuthProvider, LocaleProvider, ThemeProvider>(
          builder: (context, auth, localeProvider, themeProvider, _) {
            _appRouter ??= AppRouter(auth);
            return ErrorBoundary(
              child: MaterialApp.router(
                title: 'Penrose ScholarMW',
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
              ),
            );
          },
        ),
      );
}
