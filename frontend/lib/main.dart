import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          _appRouter ??= AppRouter(auth);
          return MaterialApp.router(
            title: 'Penrose ScholarMW',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            routerConfig: _appRouter!.router,
          );
        },
      ),
    );
  }
}
