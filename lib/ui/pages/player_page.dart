import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/follow/follow_mode_controller.dart';
import '../../core/follow/microphone_input.dart';
import '../../core/follow/onset_detector.dart';
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
          builder: (_, player, _) => Text(
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

/// 播放器主体内容（StatefulWidget，管理跟随模式生命周期）
class _PlayerBody extends StatefulWidget {
  final MidiPlayerController player;
  const _PlayerBody({required this.player});

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> {
  // 跟随模式相关
  MicrophoneInput? _micInput;
  OnsetDetector? _onsetDetector;
  FollowModeController? _followController;
  bool _isFollowMode = false;
  FollowModeState _followState = FollowModeState.idle;
  double _followSpeedFactor = 1.0;
  int? _melodyTrackIndex;

  @override
  void dispose() {
    _stopFollowMode();
    _followController?.dispose();
    _onsetDetector?.dispose();
    _micInput?.dispose();
    super.dispose();
  }

  /// 设置主旋律轨道
  void _setMelodyTrack(int trackIndex) {
    setState(() => _melodyTrackIndex = trackIndex);
  }

  /// 切换跟随模式
  Future<void> _toggleFollowMode() async {
    if (_isFollowMode) {
      _stopFollowMode();
      setState(() => _isFollowMode = false);
      return;
    }

    // 检查是否选择了主旋律轨道
    if (_melodyTrackIndex == null) {
      _showAlert('请先选择主旋律轨道', '在轨道列表中点击"主旋律"按钮选择一个轨道。');
      return;
    }

    // 请求麦克风权限
    final granted = await _requestMicPermission();
    if (!granted) return;

    // 启动跟随模式
    _startFollowMode();
    setState(() => _isFollowMode = true);
  }

  /// 请求麦克风权限
  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
      _showAlert('需要麦克风权限', '跟随模式需要使用麦克风检测您的演奏。请在系统设置中允许麦克风访问。');
    }
    return false;
  }

  /// 启动跟随模式
  void _startFollowMode() {
    final player = widget.player;
    final song = player.songData;
    if (song == null || _melodyTrackIndex == null) return;

    // 获取主旋律轨道的音符
    final melodyTrack = song.tracks.firstWhere(
      (t) => t.index == _melodyTrackIndex,
      orElse: () => song.tracks.first,
    );

    // 初始化三层模块
    _micInput = MicrophoneInput();
    _onsetDetector = OnsetDetector();
    _followController = FollowModeController(
      onsetDetector: _onsetDetector!,
    );

    // 设置回调
    _followController!.onSpeedChanged = (speed) {
      player.setSpeed(speed);
      if (mounted) setState(() => _followSpeedFactor = speed);
    };
    _followController!.onStateChanged = (state) {
      if (mounted) setState(() => _followState = state);
    };

    // 加载乐谱 → 连接流 → 启动
    _followController!.loadScore(melodyTrack.notes);
    _onsetDetector!.attachPitchStream(_micInput!.pitchStream);
    _micInput!.start();
    _followController!.start();
  }

  /// 停止跟随模式
  void _stopFollowMode() {
    _followController?.stop();
    _onsetDetector?.detach();
    _micInput?.stop();

    // 恢复手动速度
    widget.player.setSpeed(1.0);
    setState(() {
      _followState = FollowModeState.idle;
      _followSpeedFactor = 1.0;
    });
  }

  /// 显示提示弹窗
  void _showAlert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Column(
      children: [
        // SoundFont 未加载提示
        if (!player.engine.isReady)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: CupertinoColors.systemYellow.withValues(alpha: 0.2),
            child: const Text(
              '⚠ SoundFont 未加载，请将 .sf2 文件放入 assets/soundfonts/',
              style: TextStyle(fontSize: 13, color: CupertinoColors.systemOrange),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 24),
        _SongInfoSection(player: player),
        const SizedBox(height: 32),
        _ProgressSection(player: player),
        const SizedBox(height: 24),
        _PlaybackControls(player: player),
        const SizedBox(height: 24),
        // 跟随模式 / 手动速度调节
        _isFollowMode
            ? _FollowModeStatus(
                state: _followState,
                speedFactor: _followSpeedFactor,
                onStop: _toggleFollowMode,
              )
            : _SpeedControl(player: player),
        const SizedBox(height: 8),
        // 跟随模式开关
        _FollowModeToggle(
          isFollowMode: _isFollowMode,
          melodyTrackIndex: _melodyTrackIndex,
          onToggle: _toggleFollowMode,
        ),
        const SizedBox(height: 8),
        // 轨道列表
        Expanded(
          child: _TrackList(
            player: player,
            melodyTrackIndex: _melodyTrackIndex,
            onSetMelody: _setMelodyTrack,
          ),
        ),
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

/// 跟随模式状态显示
class _FollowModeStatus extends StatelessWidget {
  final FollowModeState state;
  final double speedFactor;
  final VoidCallback onStop;

  const _FollowModeStatus({
    required this.state,
    required this.speedFactor,
    required this.onStop,
  });

  String get _stateLabel => switch (state) {
        FollowModeState.idle => '空闲',
        FollowModeState.following => '跟随中',
        FollowModeState.waitingForOnset => '等待演奏…',
      };

  Color get _stateColor => switch (state) {
        FollowModeState.idle => CupertinoColors.systemGrey,
        FollowModeState.following => CupertinoColors.systemGreen,
        FollowModeState.waitingForOnset => CupertinoColors.systemOrange,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(CupertinoIcons.mic_fill, size: 18, color: _stateColor),
          const SizedBox(width: 8),
          Text(
            _stateLabel,
            style: TextStyle(fontSize: 14, color: _stateColor),
          ),
          const Spacer(),
          Text(
            '${speedFactor.toStringAsFixed(2)}x',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            onPressed: onStop,
            child: const Icon(
              CupertinoIcons.stop_circle,
              size: 24,
              color: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }
}

/// 跟随模式开关行
class _FollowModeToggle extends StatelessWidget {
  final bool isFollowMode;
  final int? melodyTrackIndex;
  final VoidCallback onToggle;

  const _FollowModeToggle({
    required this.isFollowMode,
    required this.melodyTrackIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.waveform,
            size: 18,
            color: CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: 8),
          const Text('跟随模式', style: TextStyle(fontSize: 14)),
          if (melodyTrackIndex == null && !isFollowMode)
            const Text(
              '  (请先选择主旋律)',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemOrange,
              ),
            ),
          const Spacer(),
          CupertinoSwitch(
            value: isFollowMode,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
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
  final int? melodyTrackIndex;
  final ValueChanged<int> onSetMelody;

  const _TrackList({
    required this.player,
    required this.melodyTrackIndex,
    required this.onSetMelody,
  });

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
          isMelody: track.index == melodyTrackIndex,
          onToggleMute: () => player.toggleTrackMute(track.index),
          onVolumeChanged: (v) => player.setTrackVolume(track.index, v),
          onSetMelody: () => onSetMelody(track.index),
        );
      },
    );
  }
}

/// 单个轨道行
class _TrackTile extends StatelessWidget {
  final MidiTrackInfo track;
  final bool isMelody;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onSetMelody;

  const _TrackTile({
    required this.track,
    required this.isMelody,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.onSetMelody,
  });

  @override
  Widget build(BuildContext context) {
    final name = track.name.isNotEmpty
        ? track.name
        : '轨道 ${track.index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // 第一行：静音 + 名称 + 音符数
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
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
              const SizedBox(width: 8),
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
              Text(
                '${track.noteCount} 音符',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel,
                ),
              ),
              const SizedBox(width: 8),
              // 主旋律标记/按钮
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 24),
                onPressed: onSetMelody,
                child: Text(
                  isMelody ? '★ 主旋律' : '主旋律',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMelody
                        ? CupertinoColors.systemOrange
                        : CupertinoColors.tertiaryLabel,
                  ),
                ),
              ),
            ],
          ),
          // 第二行：音量滑块
          Row(
            children: [
              const SizedBox(width: 40),
              const Icon(
                CupertinoIcons.volume_down,
                size: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
              Expanded(
                child: CupertinoSlider(
                  value: track.isMuted ? 0.0 : track.volume,
                  onChanged: track.isMuted ? null : onVolumeChanged,
                ),
              ),
              const Icon(
                CupertinoIcons.volume_up,
                size: 14,
                color: CupertinoColors.tertiaryLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
