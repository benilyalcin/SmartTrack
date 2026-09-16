import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_state.dart';
import 'core/services/app_log_service.dart';

void main() {
  final defaultDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) AppLogService.instance.add(message);
    defaultDebugPrint(message, wrapWidth: wrapWidth);
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(
      'FlutterError (yakalandı, uygulama kapanmadı): ${details.exceptionAsString()}',
    );
  };

  runZonedGuarded(() => runApp(const SmartTrackApp()), (
    Object error,
    StackTrace stack,
  ) {
    debugPrint('Yakalanmamış hata (uygulama kapanmadı): $error\n$stack');
  });
}

class SmartTrackApp extends StatelessWidget {
  const SmartTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      child: Builder(
        builder: (context) {
          final appState = AppStateProvider.of(context);
          return MaterialApp.router(
            title: 'SmartTrack',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,
            routerConfig: goRouter,

            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('tr'), Locale('en'), Locale('de')],
            locale: const Locale('tr'),
          );
        },
      ),
    );
  }
}
