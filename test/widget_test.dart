import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:midi_music/app.dart';
import 'package:midi_music/core/midi/midi_player.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MidiPlayerController(),
        child: const MidiMusicApp(),
      ),
    );

    // 验证首页渲染成功
    expect(find.text('MIDI 音乐'), findsOneWidget);
  });
}
