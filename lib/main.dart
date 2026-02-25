import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'core/midi/midi_player.dart';
import 'app.dart';

/// SoundFont asset 路径（放入 assets/soundfonts/ 后自动加载）
const _kDefaultSoundfont = 'assets/soundfonts/default.sf2';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) {
        final controller = MidiPlayerController();
        // 异步加载 SoundFont，失败时静默降级（用户可手动选择）
        controller.loadSoundfont(_kDefaultSoundfont).catchError((_) {});
        return controller;
      },
      child: const MidiMusicApp(),
    ),
  );
}
