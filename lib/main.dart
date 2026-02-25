import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'core/midi/midi_player.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => MidiPlayerController(),
      child: const MidiMusicApp(),
    ),
  );
}
