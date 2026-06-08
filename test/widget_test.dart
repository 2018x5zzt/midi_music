import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:midi_music/app.dart';
import 'package:midi_music/core/midi/midi_player.dart';
import 'package:midi_music/core/settings/app_settings.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                AppSettingsController(storage: _MemorySettingsStorage()),
          ),
          ChangeNotifierProvider(create: (_) => MidiPlayerController()),
        ],
        child: const MidiMusicApp(),
      ),
    );

    expect(find.text('导入 MIDI 乐谱'), findsOneWidget);
  });

  testWidgets('Settings page can be opened from home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                AppSettingsController(storage: _MemorySettingsStorage()),
          ),
          ChangeNotifierProvider(create: (_) => MidiPlayerController()),
        ],
        child: const MidiMusicApp(),
      ),
    );

    await tester.tap(find.byIcon(CupertinoIcons.gear_alt_fill));
    await tester.pumpAndSettle();

    expect(find.text('排练偏好'), findsOneWidget);
    expect(find.text('麦克风隐私'), findsOneWidget);
  });
}

class _MemorySettingsStorage implements AppSettingsStorage {
  Map<String, Object?> values = {};

  @override
  Future<Map<String, Object?>> read() async =>
      Map<String, Object?>.from(values);

  @override
  Future<void> write(Map<String, Object?> values) async {
    this.values = Map<String, Object?>.from(values);
  }
}
