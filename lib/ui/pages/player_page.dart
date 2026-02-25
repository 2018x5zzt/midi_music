import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../core/midi/midi_player.dart';
import '../../models/midi_track.dart';

/// 播放器页面 - MIDI 播放控制
///
/// iOS 风格：歌曲信息 + 进度条 + 播放控制 + 速度调节 + 轨道列表。
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Consumer<MidiPlayerController>(
          builder: (_, player, __) => Text(
            player.songData?.fileName ?? 'MIDI 播放器',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<MidiPlayerController>(
          builder: (context, player, _) {
            if (!player.isReady && player.songData == null) {
              return const Center(child: Text('未加载歌曲'));
            }
            return _PlayerBody(player: player);
          },
        ),
      ),
    );
  }
}

/// 播放器主体内容
class _PlayerBody extends StatelessWidget {
  final MidiPlayerController player;
  const _PlayerBody({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        // 歌曲信息
        _SongInfoSection(player: player),
        const SizedBox(height: 32),
        // 进度条
        _ProgressSection(player: player),
        const SizedBox(height: 24),
        // 播放控制按钮
        _PlaybackControls(player: player),
        const SizedBox(height: 24),
        // 速度调节
        _SpeedControl(player: player),
        const SizedBox(height: 16),
        // 轨道列表
        Expanded(child: _TrackList(player: player)),
      ],
    );
  }
}

/// 歌曲信息区域
class _SongInfoSection extends StatelessWidget {
  final MidiPlayerController player;
  const _SongInfoSection({required this.player});

  @override
  Widget build(BuildContext context) {
    final song = player.songData;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // BPM 显示
          Text(
            '${player.currentBpm.toStringAsFixed(0)} BPM',
            style: CupertinoTheme.of(context)
                .textTheme
                .navLargeTitleTextStyle
                .copyWith(
                  color: CupertinoColors.systemBlue,
                  fontSize: 28,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${song.noteTracks.length} 轨道 · ${song.format == 0 ? "Format 0" : "Format 1"}',
            style: CupertinoTheme.of(context)
                .textTheme
                .textStyle
                .copyWith(color: CupertinoColors.secondaryLabel),
          ),
        ],
      ),
    );
  }
}

/// 进度条区域
class _ProgressSection extends StatelessWidget {
  final MidiPlayerController player;
  const _ProgressSection({required this.player});

  String _formatTime(double seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          CupertinoSlider(
            value: player.progress,
            onChanged: (value) {
              player.seekTo(value * player.totalDuration);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(player.currentTime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                Text(
                  _formatTime(player.totalDuration),
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 播放控制按钮区域
class _PlaybackControls extends StatelessWidget {
  final MidiPlayerController player;
  const _PlaybackControls({required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 停止
        CupertinoButton(
          onPressed: player.stop,
          child: const Icon(
            CupertinoIcons.stop_fill,
            size: 32,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(width: 24),
        // 播放/暂停
        CupertinoButton(
          onPressed: () {
            if (player.isPlaying) {
              player.pause();
            } else {
              player.play();
            }
          },
          child: Icon(
            player.isPlaying
                ? CupertinoIcons.pause_circle_fill
                : CupertinoIcons.play_circle_fill,
            size: 64,
            color: CupertinoColors.systemBlue,
          ),
        ),
        const SizedBox(width: 24),
        // 快进 10 秒
        CupertinoButton(
          onPressed: () => player.seekTo(player.currentTime + 10),
          child: const Icon(
            CupertinoIcons.goforward_10,
            size: 32,
            color: CupertinoColors.systemGrey,
          ),
        ),
      ],
    );
  }
}

/// 速度调节区域
class _SpeedControl extends StatelessWidget {
  final MidiPlayerController player;
  const _SpeedControl({required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.speedometer,
            size: 18,
            color: CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: 8),
          Text(
            '${player.playbackSpeed.toStringAsFixed(2)}x',
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.label,
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: player.playbackSpeed,
              min: 0.25,
              max: 4.0,
              divisions: 15,
              onChanged: player.setSpeed,
            ),
          ),
        ],
      ),
    );
  }
}

/// 轨道列表区域
class _TrackList extends StatelessWidget {
  final MidiPlayerController player;
  const _TrackList({required this.player});

  @override
  Widget build(BuildContext context) {
    final tracks = player.songData?.noteTracks ?? [];
    if (tracks.isEmpty) {
      return const Center(child: Text('无轨道数据'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackTile(
          track: track,
          onToggleMute: () => player.toggleTrackMute(track.index),
        );
      },
    );
  }
}

/// 单个轨道行
class _TrackTile extends StatelessWidget {
  final MidiTrackInfo track;
  final VoidCallback onToggleMute;

  const _TrackTile({
    required this.track,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    final name = track.name.isNotEmpty ? track.name : '轨道 ${track.index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 静音按钮
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 32,
            onPressed: onToggleMute,
            child: Icon(
              track.isMuted
                  ? CupertinoIcons.speaker_slash_fill
                  : CupertinoIcons.speaker_2_fill,
              size: 20,
              color: track.isMuted
                  ? CupertinoColors.systemGrey
                  : CupertinoColors.systemBlue,
            ),
          ),
          const SizedBox(width: 12),
          // 轨道名称
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15,
                color: track.isMuted
                    ? CupertinoColors.secondaryLabel
                    : CupertinoColors.label,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 音符数量
          Text(
            '${track.noteCount} 音符',
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
