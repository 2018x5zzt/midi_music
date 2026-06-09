import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/diagnostics/app_error.dart';
import 'core/diagnostics/diagnostic_logger.dart';
import 'core/midi/midi_player.dart';
import 'core/settings/app_settings.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorHandlers();
      unawaited(DiagnosticLogger.instance.initialize());

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                final settings = AppSettingsController();
                unawaited(settings.load());
                return settings;
              },
            ),
            ChangeNotifierProvider(
              create: (_) {
                final controller = MidiPlayerController();
                unawaited(controller.ensureSoundfontReady());
                return controller;
              },
            ),
          ],
          child: const MidiMusicApp(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        DiagnosticLogger.instance.recordError(
          AppError.unhandled(error, stackTrace),
        ),
      );
    },
  );
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      DiagnosticLogger.instance.recordError(
        AppError.unhandled(
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      DiagnosticLogger.instance.recordError(
        AppError.unhandled(error, stackTrace),
      ),
    );
    return true;
  };
}
