
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_scope.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'services/download_manager.dart';
import 'services/history_store.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings();

  try {
    await Future.wait<void>([
      settings.load(),
      HistoryStore.instance.load(),
    ]).timeout(const Duration(seconds: 5));
  } catch (e, stackTrace) {
    debugPrint('Startup initialization error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  DownloadManager.instance.settings = settings;

  runApp(
    AppScope(
      settings: settings,
      child: const FlowDropApp(),
    ),
  );
}

class FlowDropApp extends StatelessWidget {
  const FlowDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return MaterialApp(
      title: 'FlowDrop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: s.themeMode,
      builder: (context, child) {
        final dark =
            Theme.of(context).brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                dark ? AppColors.cardDark : AppColors.cardLight,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
          child: Directionality(
            textDirection:
                s.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
