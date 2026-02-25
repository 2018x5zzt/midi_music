import 'package:flutter/cupertino.dart';
import 'ui/pages/home_page.dart';

/// App 根组件 - iOS 风格
class MidiMusicApp extends StatelessWidget {
  const MidiMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'MIDI 伴奏',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
