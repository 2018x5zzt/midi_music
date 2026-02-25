import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/midi_track.dart';
import 'midi_engine.dart';
import 'tempo_map.dart';

/// 播放状态
enum PlaybackState { stopped, playing, paused }

/// MIDI 播放控制器
///
/// 负责按时间线调度 MIDI 事件，驱动 MidiEngine 发声。
/// 支持播放/暂停/停止/跳转/变速。
class MidiPlayerController extends ChangeNotifier {
  final MidiEngine _engine = MidiEngine();
  MidiSongData? _songData;
  TempoMap? _tempoMap;

  PlaybackState _state = PlaybackState.stopped;
  double _currentTime = 0.0;
  double _playbackSpeed = 1.0;
  int _currentEventIndex = 0;
  Timer? _ticker;
  DateTime? _lastTickTime;

  // Getters
  PlaybackState get state => _state;
  bool get isPlaying => _state == PlaybackState.playing;
  bool get isPaused => _state == PlaybackState.paused;
  bool get isStopped => _state == PlaybackState.stopped;
  double get currentTime => _currentTime;
  double get playbackSpeed => _playbackSpeed;
  MidiSongData? get songData => _songData;
  MidiEngine get engine => _engine;
  bool get isReady => _engine.isReady && _songData != null;

  /// 总时长（秒）
  double get totalDuration => _songData?.totalDuration ?? 0.0;

  /// 播放进度 (0.0 - 1.0)
  double get progress {
    if (totalDuration <= 0) return 0.0;
    return (_currentTime / totalDuration).clamp(0.0, 1.0);
  }

  /// 当前 BPM
  double get currentBpm {
    if (_tempoMap == null || _songData == null) return 120.0;
    final tick = _tempoMap!.secondsToTick(_currentTime);
    return _tempoMap!.getBpmAtTick(tick);
  }

  /// 加载 SoundFont
  Future<void> loadSoundfont(String assetPath) async {
    await _engine.loadSoundfontFromAsset(assetPath);
    notifyListeners();
  }

  /// 加载歌曲数据
  void loadSong(MidiSongData song) {
    stop();
    _songData = song;
    _tempoMap = TempoMap(
      ticksPerBeat: song.ticksPerBeat,
      tempoChanges: song.tempoChanges,
    );
    // 为每个轨道的乐器设置 program change
    _setupInstruments();
    notifyListeners();
  }

  /// 播放
  void play() {
    if (_songData == null || !_engine.isReady) return;
    if (_state == PlaybackState.playing) return;

    _state = PlaybackState.playing;
    _lastTickTime = DateTime.now();

    // 启动定时器，约 5ms 精度
    _ticker = Timer.periodic(
      const Duration(milliseconds: 5),
      (_) => _onTick(),
    );
    notifyListeners();
  }

  /// 暂停
  void pause() {
    if (_state != PlaybackState.playing) return;
    _state = PlaybackState.paused;
    _ticker?.cancel();
    _ticker = null;
    _engine.allNotesOff();
    notifyListeners();
  }

  /// 停止
  void stop() {
    _state = PlaybackState.stopped;
    _ticker?.cancel();
    _ticker = null;
    _currentTime = 0.0;
    _currentEventIndex = 0;
    _engine.allNotesOff();
    notifyListeners();
  }

  /// 跳转到指定时间（秒）
  void seekTo(double seconds) {
    final wasPlaying = isPlaying;
    if (wasPlaying) pause();

    _currentTime = seconds.clamp(0.0, totalDuration);
    _engine.allNotesOff();
    _updateEventIndex();

    if (wasPlaying) play();
    notifyListeners();
  }

  /// 设置播放速度 (0.25 - 4.0)
  void setSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.25, 4.0);
    notifyListeners();
  }

  /// 设置轨道音量 (0.0 - 1.0)
  void setTrackVolume(int trackIndex, double volume) {
    if (_songData == null) return;
    if (trackIndex >= _songData!.tracks.length) return;
    _songData!.tracks[trackIndex].volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 切换轨道静音
  void toggleTrackMute(int trackIndex) {
    if (_songData == null) return;
    if (trackIndex >= _songData!.tracks.length) return;
    final track = _songData!.tracks[trackIndex];
    track.isMuted = !track.isMuted;
    if (track.isMuted) {
      // 静音时停止该轨道所有音符
      for (final ch in track.channels) {
        _engine.noteOff(channel: ch, note: 0);
      }
    }
    notifyListeners();
  }

  /// 定时器回调：推进时间并触发事件
  void _onTick() {
    if (_songData == null || _state != PlaybackState.playing) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastTickTime!).inMicroseconds / 1000000.0;
    _lastTickTime = now;

    _currentTime += elapsed * _playbackSpeed;

    // 播放结束
    if (_currentTime >= totalDuration) {
      stop();
      return;
    }

    // 触发当前时间之前的所有事件
    _processEvents();
    notifyListeners();
  }

  /// 处理当前时间点之前的所有未触发事件
  void _processEvents() {
    final timeline = _songData!.timeline;
    while (_currentEventIndex < timeline.length) {
      final event = timeline[_currentEventIndex];
      if (event.time > _currentTime) break;

      _dispatchEvent(event);
      _currentEventIndex++;
    }
  }

  /// 分发单个 MIDI 事件到引擎
  void _dispatchEvent(TimelineEvent event) {
    // 检查该事件所属轨道是否被静音
    if (_isChannelMuted(event.channel)) return;

    switch (event.type) {
      case MidiEventType.noteOn:
        final vol = _getChannelVolume(event.channel);
        final adjustedVelocity = (event.data2 * vol).round().clamp(0, 127);
        _engine.noteOn(
          channel: event.channel,
          note: event.data1,
          velocity: adjustedVelocity,
        );
      case MidiEventType.noteOff:
        _engine.noteOff(
          channel: event.channel,
          note: event.data1,
        );
      case MidiEventType.programChange:
        _engine.setInstrument(
          channel: event.channel,
          program: event.data1,
        );
      default:
        break;
    }
  }

  /// 检查通道是否被静音
  bool _isChannelMuted(int channel) {
    if (_songData == null || channel < 0) return false;
    for (final track in _songData!.tracks) {
      if (track.channels.contains(channel) && track.isMuted) {
        return true;
      }
    }
    return false;
  }

  /// 获取通道所属轨道的音量 (0.0 - 1.0)
  double _getChannelVolume(int channel) {
    if (_songData == null || channel < 0) return 1.0;
    for (final track in _songData!.tracks) {
      if (track.channels.contains(channel)) {
        return track.volume;
      }
    }
    return 1.0;
  }

  /// seek 后更新事件索引（二分查找）
  void _updateEventIndex() {
    if (_songData == null) return;
    final timeline = _songData!.timeline;
    int low = 0;
    int high = timeline.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (timeline[mid].time <= _currentTime) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    _currentEventIndex = low;
  }

  /// 初始化各轨道乐器
  void _setupInstruments() {
    if (_songData == null) return;
    for (final track in _songData!.tracks) {
      for (final entry in track.programByChannel.entries) {
        _engine.setInstrument(
          channel: entry.key,
          program: entry.value,
        );
      }
    }
  }

  @override
  void dispose() {
    stop();
    _engine.dispose();
    super.dispose();
  }
}