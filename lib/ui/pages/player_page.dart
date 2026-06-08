import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/follow/follow_mode_controller.dart';
import '../../core/follow/follow_mode_session.dart';
import '../../core/follow/onset_detector.dart';
import '../../core/midi/midi_player.dart';
import '../../core/settings/app_settings.dart';
import '../theme/luxury_theme.dart';
import '../widgets/performance_console.dart';
import '../widgets/player_helpers.dart';
import '../widgets/soundfont_banner.dart';
import '../widgets/stage_console.dart';
import '../widgets/track_salon.dart';
import 'settings_page.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        previousPageTitle: '乐库',
        middle: Consumer<MidiPlayerController>(
          builder: (_, player, _) => Text(
            player.songData == null
                ? 'Nocturne Stage'
                : displaySongTitle(player.songData!.fileName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          onPressed: () => unawaited(
            Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
          child: const Icon(
            CupertinoIcons.gear_alt_fill,
            size: 18,
            color: LuxuryPalette.goldBright,
          ),
        ),
      ),
      child: LuxuryBackdrop(
        child: SafeArea(
          bottom: false,
          child: Consumer<MidiPlayerController>(
            builder: (context, player, _) {
              if (!player.isReady && player.songData == null) {
                return const _EmptyStage();
              }
              return _PlayerBody(player: player);
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LuxuryPanel(
          highlighted: true,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionEyebrow(label: 'NO SCORE LOADED'),
              const SizedBox(height: 18),
              Text(
                '先导入一份 MIDI 乐谱。',
                style: luxuryDisplayStyle(context, size: 30),
              ),
              const SizedBox(height: 10),
              const Text(
                '播放器已经就位，但当前还没有可演出的曲目。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: LuxuryPalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerBody extends StatefulWidget {
  final MidiPlayerController player;

  const _PlayerBody({required this.player});

  @override
  State<_PlayerBody> createState() => _PlayerBodyState();
}

class _PlayerBodyState extends State<_PlayerBody> {
  FollowModeSession? _followSession;
  bool _isFollowMode = false;
  FollowModeState _followState = FollowModeState.idle;
  double _followSpeedFactor = 1.0;
  int? _melodyTrackIndex;
  String? _playbackError;
  Timer? _errorDismissTimer;

  @override
  void initState() {
    super.initState();
    widget.player.onPlaybackError = _onPlaybackError;
  }

  void _onPlaybackError(Object error, String context) {
    if (!mounted) return;
    _errorDismissTimer?.cancel();
    setState(() => _playbackError = '播放异常：$context');
    _errorDismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _playbackError = null);
      }
    });
  }

  @override
  void dispose() {
    _errorDismissTimer?.cancel();
    if (widget.player.onPlaybackError == _onPlaybackError) {
      widget.player.onPlaybackError = null;
    }
    unawaited(_releaseFollowResources().catchError((Object _) {}));
    super.dispose();
  }

  void _setMelodyTrack(int trackIndex) {
    setState(() => _melodyTrackIndex = trackIndex);
  }

  Future<void> _toggleFollowMode() async {
    if (_isFollowMode) {
      await _stopFollowMode();
      return;
    }

    if (_melodyTrackIndex == null) {
      _showAlert('请先选择主旋律轨道', '先在轨道列表中指定主旋律，再开启实时跟随。');
      return;
    }

    final granted = await _requestMicPermission();
    if (!granted) return;

    try {
      await _startFollowMode();
      if (mounted) {
        setState(() => _isFollowMode = true);
      }
    } catch (e) {
      await _stopFollowMode(updateUi: false);
      if (mounted) {
        setState(() {
          _isFollowMode = false;
          _followState = FollowModeState.idle;
          _followSpeedFactor = 1.0;
        });
        _showAlert('跟随模式启动失败', '无法启动麦克风检测：$e');
      }
    }
  }

  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (mounted) {
      _showAlert('需要麦克风权限', '跟随模式会通过麦克风识别起拍和速度，请在系统设置中允许访问。');
    }
    return false;
  }

  Future<void> _startFollowMode() async {
    final player = widget.player;
    final song = player.songData;
    final melodyTrackIndex = _melodyTrackIndex;
    if (song == null) {
      throw StateError('未加载 MIDI 乐谱');
    }
    if (melodyTrackIndex == null) {
      throw StateError('未选择主旋律轨道');
    }

    final melodyTrack = FollowModeSession.findMelodyTrack(
      song,
      melodyTrackIndex,
    );
    if (melodyTrack == null) {
      throw StateError('主旋律轨道不存在');
    }

    final settings = context.read<AppSettingsController>();

    await _releaseFollowResources(resetPlayerSpeed: false);

    final onsetDetector = OnsetDetector(config: settings.onsetDetectorConfig);
    final session = FollowModeSession.forMidi(
      player: player,
      melodyTrack: melodyTrack,
      onsetDetector: onsetDetector,
      followController: FollowModeController(
        onsetDetector: onsetDetector,
        config: settings.followModeConfig,
      ),
      config: settings.followSessionConfig,
    );
    _followSession = session;

    session.onSpeedChanged = (speed) {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _followSpeedFactor = speed);
          }
        });
      }
    };
    session.onStateChanged = (state) {
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _followState = state;
              if (state == FollowModeState.idle) {
                _isFollowMode = false;
                _followSpeedFactor = 1.0;
              }
            });
            if (state == FollowModeState.idle) {
              unawaited(_releaseFollowResources().catchError((Object _) {}));
            }
          }
        });
      }
    };

    try {
      await session.start();
      session.resumeFromTime(player.currentTime);
    } catch (_) {
      if (_followSession == session) {
        _followSession = null;
      }
      rethrow;
    }
  }

  Future<void> _stopFollowMode({bool updateUi = true}) async {
    await _releaseFollowResources();

    if (mounted && updateUi) {
      setState(() {
        _isFollowMode = false;
        _followState = FollowModeState.idle;
        _followSpeedFactor = 1.0;
      });
    }
  }

  Future<void> _releaseFollowResources({bool resetPlayerSpeed = true}) async {
    final session = _followSession;
    _followSession = null;
    if (session != null) {
      await session.dispose(resetPlayerSpeed: resetPlayerSpeed);
    }
  }

  void _seekTo(double seconds) {
    final player = widget.player;
    player.seekTo(seconds);
    _followSession?.resumeFromTime(player.currentTime);
  }

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
    final song = player.songData;
    if (song == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_playbackError != null) ...[
            _ErrorBanner(message: _playbackError!),
            const SizedBox(height: 10),
          ],
          if (!player.isSoundfontReady) ...[
            SoundfontBanner(player: player),
            const SizedBox(height: 14),
          ],
          StageConsole(
            player: player,
            isFollowMode: _isFollowMode,
            followState: _followState,
            followSpeedFactor: _followSpeedFactor,
            onSeek: _seekTo,
          ),
          const SizedBox(height: 14),
          PerformanceConsole(
            player: player,
            isFollowMode: _isFollowMode,
            followState: _followState,
            followSpeedFactor: _followSpeedFactor,
            melodyTrackIndex: _melodyTrackIndex,
            onToggleFollow: _toggleFollowMode,
          ),
          const SizedBox(height: 14),
          TrackSalon(
            player: player,
            melodyTrackIndex: _melodyTrackIndex,
            onSetMelody: _setMelodyTrack,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LuxuryPalette.ruby.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LuxuryPalette.ruby.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 16,
            color: LuxuryPalette.ruby,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: LuxuryPalette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
