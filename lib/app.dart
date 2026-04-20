import 'package:flutter/cupertino.dart';

import 'ui/pages/home_page.dart';
import 'ui/theme/luxury_theme.dart';

class MidiMusicApp extends StatelessWidget {
  const MidiMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'MIDI 伴奏',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: LuxuryPalette.gold,
        scaffoldBackgroundColor: LuxuryPalette.background,
        barBackgroundColor: Color(0xCC090909),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
