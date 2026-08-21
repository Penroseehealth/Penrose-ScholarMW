import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'router/app_router.dart';
import 'services/data_saver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataSaverService().init();
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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<AuthProvider, LocaleProvider>(
        builder: (context, auth, localeProvider, _) {
          _appRouter ??= AppRouter(auth);
          return MaterialApp.router(
            title: 'Penrose ScholarMW',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _appRouter!.router,
          );
        },
      ),
    );
  }
}
