import 'package:flutter/cupertino.dart';

import '../../core/follow/follow_mode_controller.dart';
import '../theme/luxury_theme.dart';

/// 跟随状态对应的强调色
Color followAccent(bool isFollowMode, FollowModeState state, bool isPlaying) {
  if (!isFollowMode) {
    return isPlaying ? LuxuryPalette.goldBright : LuxuryPalette.gold;
  }
  return switch (state) {
    FollowModeState.following => LuxuryPalette.emerald,
    FollowModeState.waitingForOnset => LuxuryPalette.ruby,
    FollowModeState.idle => LuxuryPalette.goldBright,
  };
}

/// 跟随状态对应的中文标签
String followLabel(bool isFollowMode, FollowModeState state, bool isPlaying) {
  if (!isFollowMode) {
    return isPlaying ? '手动播放' : '待机';
  }
  return switch (state) {
    FollowModeState.following => '实时跟随',
    FollowModeState.waitingForOnset => '等待起拍',
    FollowModeState.idle => '跟随待命',
  };
}

/// 秒数格式化为 m:ss
String formatClock(double seconds) {
  final totalSeconds = seconds.clamp(0.0, double.infinity).round();
  final minutes = totalSeconds ~/ 60;
  final remainSeconds = totalSeconds % 60;
  return '$minutes:${remainSeconds.toString().padLeft(2, '0')}';
}

/// 从文件名提取可读曲名
String displaySongTitle(String fileName) {
  final stripped = fileName.replaceAll(
    RegExp(r'\.mid$', caseSensitive: false),
    '',
  );
  final normalized = stripped.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return normalized.isEmpty ? fileName : normalized;
}

/// 通用小节标签
class SectionEyebrow extends StatelessWidget {
  final String label;

  const SectionEyebrow({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 2.1,
        color: LuxuryPalette.textSubtle,
      ),
    );
  }
}

/// 装饰分隔线
class OrnamentLine extends StatelessWidget {
  const OrnamentLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 36, height: 2, color: LuxuryPalette.goldBright),
        const SizedBox(width: 10),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: LuxuryPalette.goldBright,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: LuxuryPalette.divider)),
      ],
    );
  }
}

/// 状态徽章
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
