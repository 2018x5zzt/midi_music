import 'package:flutter/cupertino.dart';

import '../../core/midi/midi_player.dart';
import '../theme/luxury_theme.dart';

/// SoundFont 加载状态横幅
class SoundfontBanner extends StatelessWidget {
  final MidiPlayerController player;

  const SoundfontBanner({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final progressPercent = (player.soundfontDownloadProgress * 100)
        .clamp(0, 100)
        .round();
    final message = switch (player.soundfontState) {
      SoundfontSetupState.downloading => '正在下载音色 $progressPercent%',
      SoundfontSetupState.failed =>
        player.soundfontErrorMessage ?? '音色下载失败，请稍后重试。',
      SoundfontSetupState.checking => '正在检查本地音色。',
      SoundfontSetupState.idle => '正在准备音色。',
      SoundfontSetupState.ready => '音色已就绪。',
    };
    final accent = switch (player.soundfontState) {
      SoundfontSetupState.failed => LuxuryPalette.ruby,
      SoundfontSetupState.ready => LuxuryPalette.emerald,
      _ => LuxuryPalette.goldBright,
    };
    final icon = switch (player.soundfontState) {
      SoundfontSetupState.failed =>
        CupertinoIcons.exclamationmark_triangle_fill,
      SoundfontSetupState.ready => CupertinoIcons.check_mark_circled_solid,
      _ => CupertinoIcons.cloud_download_fill,
    };

    return LuxuryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: LuxuryPalette.textMuted,
              ),
            ),
          ),
          if (player.soundfontState == SoundfontSetupState.failed) ...[
            const SizedBox(width: 12),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              onPressed: player.retrySoundfontSetup,
              child: const Text(
                '重试',
                style: TextStyle(fontSize: 13, color: LuxuryPalette.goldBright),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
