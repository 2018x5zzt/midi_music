import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/midi/midi_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final controller = MidiPlayerController();
        controller.ensureSoundfontReady();
        return controller;
      },
      child: const MidiMusicApp(),
    ),
  );
}
