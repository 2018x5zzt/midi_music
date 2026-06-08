import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/midi/midi_player.dart';
import '../../core/settings/app_settings.dart';
import '../theme/luxury_theme.dart';
import '../widgets/player_helpers.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        border: null,
        previousPageTitle: '返回',
        middle: Text('设置'),
      ),
      child: LuxuryBackdrop(
        child: SafeArea(
          bottom: false,
          child: Consumer2<AppSettingsController, MidiPlayerController>(
            builder: (context, settings, player, _) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingsHeader(),
                    const SizedBox(height: 14),
                    _SoundfontSettingsCard(player: player),
                    const SizedBox(height: 14),
                    _PlaybackSettingsCard(settings: settings, player: player),
                    const SizedBox(height: 14),
                    _FollowSettingsCard(settings: settings),
                    const SizedBox(height: 14),
                    const _PrivacyCard(),
                    const SizedBox(height: 14),
                    _ResetCard(settings: settings),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return LuxuryPanel(
      highlighted: true,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionEyebrow(label: 'LIGHTWEIGHT SETUP'),
          const SizedBox(height: 14),
          Text('排练偏好', style: luxuryDisplayStyle(context, size: 34)),
          const SizedBox(height: 10),
          const Text(
            '只保留轻量项目最常用的播放、音色和跟随参数。跟随相关修改会在下次开启跟随模式时生效。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: LuxuryPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundfontSettingsCard extends StatelessWidget {
  final MidiPlayerController player;

  const _SoundfontSettingsCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final progressPercent = (player.soundfontDownloadProgress * 100)
        .clamp(0, 100)
        .round();
    final accent = switch (player.soundfontState) {
      SoundfontSetupState.ready => LuxuryPalette.emerald,
      SoundfontSetupState.failed => LuxuryPalette.ruby,
      _ => LuxuryPalette.goldBright,
    };
    final stateText = switch (player.soundfontState) {
      SoundfontSetupState.ready => '已就绪',
      SoundfontSetupState.failed => '下载失败',
      SoundfontSetupState.downloading => '下载中 $progressPercent%',
      SoundfontSetupState.checking => '检查中',
      SoundfontSetupState.idle => '准备中',
    };
    final detailText = switch (player.soundfontState) {
      SoundfontSetupState.ready => '本地演出音色已经可用，可以直接播放 MIDI。',
      SoundfontSetupState.failed =>
        player.soundfontErrorMessage ?? '音色库准备失败，请检查网络后重试。',
      SoundfontSetupState.downloading => '正在自动下载 TimGM6mb.sf2。',
      SoundfontSetupState.checking => '正在检查本地缓存的 SoundFont。',
      SoundfontSetupState.idle => '等待自动准备演出音色。',
    };

    return LuxuryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            label: 'SOUNDFONT',
            title: '音色库',
            badge: StatusBadge(label: stateText, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            detailText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: LuxuryPalette.textMuted,
            ),
          ),
          if (player.soundfontState == SoundfontSetupState.downloading) ...[
            const SizedBox(height: 14),
            _ProgressBar(progress: player.soundfontDownloadProgress),
          ],
          if (player.soundfontState == SoundfontSetupState.failed) ...[
            const SizedBox(height: 14),
            _SmallActionButton(
              label: '重新准备音色',
              icon: CupertinoIcons.arrow_clockwise,
              onPressed: player.retrySoundfontSetup,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaybackSettingsCard extends StatelessWidget {
  final AppSettingsController settings;
  final MidiPlayerController player;

  const _PlaybackSettingsCard({required this.settings, required this.player});

  @override
  Widget build(BuildContext context) {
    return LuxuryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(label: 'PLAYBACK', title: '播放默认值'),
          const SizedBox(height: 14),
          _ValueSlider(
            title: '默认速度',
            description: '新导入曲目时使用的初始播放倍率。',
            value: settings.defaultPlaybackSpeed,
            min: 0.25,
            max: 4.0,
            divisions: 15,
            valueText: '${settings.defaultPlaybackSpeed.toStringAsFixed(2)}x',
            onChanged: settings.setDefaultPlaybackSpeed,
          ),
          const SizedBox(height: 12),
          _SmallActionButton(
            label: '应用到当前曲目',
            icon: CupertinoIcons.slider_horizontal_3,
            onPressed: () => player.setSpeed(settings.defaultPlaybackSpeed),
          ),
        ],
      ),
    );
  }
}

class _FollowSettingsCard extends StatelessWidget {
  final AppSettingsController settings;

  const _FollowSettingsCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    return LuxuryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(label: 'FOLLOW MODE', title: '实时跟随'),
          const SizedBox(height: 14),
          _ValueSlider(
            title: '音高可信度',
            description: '越高越保守，能减少环境噪声误判。',
            value: settings.microphoneMinPrecision,
            min: 0.4,
            max: 0.95,
            divisions: 11,
            valueText: settings.microphoneMinPrecision.toStringAsFixed(2),
            onChanged: settings.setMicrophoneMinPrecision,
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            title: '起拍音量阈值',
            description: '越低越灵敏；环境较吵时建议调高。',
            value: settings.onsetVolumeThreshold,
            min: 0.0001,
            max: 0.005,
            divisions: 49,
            valueText: settings.onsetVolumeThreshold.toStringAsFixed(4),
            onChanged: settings.setOnsetVolumeThreshold,
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            title: '音符匹配容差',
            description: '允许识别音高和谱面音符相差的半音数。',
            value: settings.noteMatchTolerance.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            valueText: '${settings.noteMatchTolerance} 半音',
            onChanged: (value) => settings.setNoteMatchTolerance(value.round()),
          ),
          const SizedBox(height: 16),
          _SettingsSwitchRow(
            title: '允许八度误检',
            description: '同名音不同八度也可视为匹配，适合手机麦克风识别。',
            value: settings.allowOctaveError,
            onChanged: (value) => settings.setAllowOctaveError(value: value),
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            title: '可信速度下限',
            description: '低于该倍率的单次测量会被忽略。',
            value: settings.minMeasuredSpeedFactor,
            min: 0.4,
            max: 1.0,
            divisions: 12,
            valueText: '${settings.minMeasuredSpeedFactor.toStringAsFixed(2)}x',
            onChanged: settings.setMinMeasuredSpeedFactor,
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            title: '可信速度上限',
            description: '高于该倍率的单次测量会被忽略。',
            value: settings.maxMeasuredSpeedFactor,
            min: 1.0,
            max: 2.2,
            divisions: 12,
            valueText: '${settings.maxMeasuredSpeedFactor.toStringAsFixed(2)}x',
            onChanged: settings.setMaxMeasuredSpeedFactor,
          ),
          const SizedBox(height: 16),
          _ValueSlider(
            title: '休止等待阈值',
            description: '谱面间隔超过该时长时，跟随模式会暂停等待下一次起拍。',
            value: settings.restThresholdSeconds,
            min: 0.5,
            max: 3.0,
            divisions: 10,
            valueText: '${settings.restThresholdSeconds.toStringAsFixed(1)} 秒',
            onChanged: settings.setRestThresholdSeconds,
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return const LuxuryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(label: 'PRIVACY', title: '麦克风隐私'),
          SizedBox(height: 12),
          Text(
            '跟随模式只在本机分析音高和起拍，不上传、不保存录音。关闭跟随模式后会释放麦克风输入。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: LuxuryPalette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  final AppSettingsController settings;

  const _ResetCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    return LuxuryPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '如果跟随参数调乱了，可以恢复推荐默认值。',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: LuxuryPalette.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 14),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: LuxuryPalette.ruby.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            onPressed: () => _confirmReset(context),
            child: const Text(
              '恢复默认',
              style: TextStyle(fontSize: 13, color: LuxuryPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('恢复默认设置？'),
        content: const Text('这会重置播放默认速度和跟随模式参数。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('恢复'),
            onPressed: () {
              settings.resetToDefaults();
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String label;
  final String title;
  final Widget? badge;

  const _SectionHeading({required this.label, required this.title, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionEyebrow(label: label),
              const SizedBox(height: 10),
              Text(title, style: luxuryDisplayStyle(context, size: 26)),
            ],
          ),
        ),
        if (badge != null) ...[const SizedBox(width: 12), badge!],
      ],
    );
  }
}

class _ValueSlider extends StatelessWidget {
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueText;
  final ValueChanged<double> onChanged;

  const _ValueSlider({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxuryPalette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LuxuryPalette.textPrimary,
                  ),
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 13,
                  color: LuxuryPalette.goldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: LuxuryPalette.textSubtle,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxuryPalette.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: LuxuryPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: LuxuryPalette.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LuxuryPalette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LuxuryPalette.gold.withValues(alpha: 0.28)),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: BorderRadius.circular(18),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: LuxuryPalette.goldBright),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LuxuryPalette.goldBright,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  double get _safeProgress {
    if (progress < 0.0) return 0.0;
    if (progress > 1.0) return 1.0;
    return progress;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 7,
        color: CupertinoColors.white.withValues(alpha: 0.06),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _safeProgress,
            child: Container(color: LuxuryPalette.goldBright),
          ),
        ),
      ),
    );
  }
}
