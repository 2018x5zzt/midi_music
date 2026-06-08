import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/midi/midi_player.dart';
import 'core/settings/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
}
