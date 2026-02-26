import 'dart:async';

// ============================================================
// 数据模型
// ============================================================

/// 麦克风检测到的音高数据
class PitchData {
  /// 检测到的频率 (Hz)，-1 表示无有效音高
  final double frequency;

  /// MIDI 音符编号 (0-127)，-1 表示无效
  final int midiNote;

  /// 音符名称（如 "C", "D#"）
  final String noteName;

  /// 八度
  final int octave;

  /// 音量 (0.0 - 1.0 归一化)
  final double volume;

  /// 音量 (dBFS)
  final double volumeDbFS;

  /// 检测精度 (0.0 - 1.0)
  final double precision;

  /// 时间戳
  final DateTime timestamp;

  PitchData({
    required this.frequency,
    required this.midiNote,
    this.noteName = '',
    this.octave = -1,
    this.volume = 0.0,
    this.volumeDbFS = -100.0,
    this.precision = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 是否为有效音高
  bool get isValid => frequency > 0 && midiNote >= 0 && midiNote <= 127;

  @override
  String toString() =>
      'PitchData(midi:$midiNote, freq:${frequency.toStringAsFixed(1)}Hz, '
      'vol:${volume.toStringAsFixed(2)})';
}

/// Onset 事件：检测到演奏者弹奏了一个音符
class OnsetEvent {
  /// 检测到的 MIDI 音符编号
  final int midiNote;

  /// 检测到的频率 (Hz)
  final double frequency;

  /// 音量
  final double volume;

  /// 事件时间戳
  final DateTime timestamp;

  OnsetEvent({
    required this.midiNote,
    required this.frequency,
    required this.volume,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'OnsetEvent(midi:$midiNote, freq:${frequency.toStringAsFixed(1)}Hz)';
}

// ============================================================
// OnsetDetector - 纯信号检测，不依赖 Flutter/UI
// ============================================================

/// Onset 检测器配置
class OnsetDetectorConfig {
  /// 最小音量阈值（归一化 0.0-1.0），低于此值忽略
  final double volumeThreshold;

  /// 最小检测精度阈值 (0.0-1.0)
  final double precisionThreshold;

  /// 同一音符的去抖时间（毫秒），防止重复触发
  final int debounceMs;

  /// 有效 MIDI 音符范围下限
  final int minMidiNote;

  /// 有效 MIDI 音符范围上限
  final int maxMidiNote;

  const OnsetDetectorConfig({
    this.volumeThreshold = 0.05,
    this.precisionThreshold = 0.5,
    this.debounceMs = 80,
    this.minMidiNote = 21,  // A0
    this.maxMidiNote = 108, // C8
  });
}

/// Onset 检测器
///
/// 纯 Dart 类，输入 [PitchData] 流，输出 [OnsetEvent] 流。
/// 检测逻辑：音量超过阈值 + 频率有效 + 去抖 → 触发 onset。
class OnsetDetector {
  OnsetDetectorConfig _config;
  final _onsetController = StreamController<OnsetEvent>.broadcast();
  StreamSubscription<PitchData>? _pitchSubscription;

  /// 上一次触发 onset 的 MIDI 音符
  int _lastOnsetNote = -1;

  /// 上一次触发 onset 的时间
  DateTime _lastOnsetTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// 当前是否处于"有音"状态
  bool _isNoteActive = false;

  /// 连续无效帧计数（用于判断音符结束）
  int _silenceFrames = 0;

  /// 连续无效帧达到此数量视为音符结束
  static const int _silenceThreshold = 3;

  OnsetDetector({OnsetDetectorConfig? config})
      : _config = config ?? const OnsetDetectorConfig();

  /// Onset 事件输出流
  Stream<OnsetEvent> get onsetStream => _onsetController.stream;

  /// 当前配置
  OnsetDetectorConfig get config => _config;

  /// 更新配置
  void updateConfig(OnsetDetectorConfig config) {
    _config = config;
  }

  /// 绑定 pitch 数据流，开始检测
  void attachPitchStream(Stream<PitchData> pitchStream) {
    _pitchSubscription?.cancel();
    reset();
    _pitchSubscription = pitchStream.listen(
      _processPitchData,
      onError: (e) => _onsetController.addError(e),
    );
  }

  /// 断开 pitch 数据流
  void detach() {
    _pitchSubscription?.cancel();
    _pitchSubscription = null;
  }

  /// 重置内部状态
  void reset() {
    _lastOnsetNote = -1;
    _lastOnsetTime = DateTime.fromMillisecondsSinceEpoch(0);
    _isNoteActive = false;
    _silenceFrames = 0;
  }

  /// 处理单帧 pitch 数据 — 核心检测逻辑
  void _processPitchData(PitchData data) {
    if (_onsetController.isClosed) return;

    // 判断当前帧是否为有效音符
    final isValidFrame = _isValidPitch(data);

    if (isValidFrame) {
      _silenceFrames = 0;

      if (!_isNoteActive) {
        // 从静音→有音：新 onset
        _tryEmitOnset(data);
        _isNoteActive = true;
      } else if (data.midiNote != _lastOnsetNote) {
        // 音符变化：新 onset（不同音符）
        _tryEmitOnset(data);
      }
    } else {
      // 无效帧
      _silenceFrames++;
      if (_silenceFrames >= _silenceThreshold && _isNoteActive) {
        _isNoteActive = false;
      }
    }
  }

  /// 判断 pitch 数据是否满足有效音符条件
  bool _isValidPitch(PitchData data) {
    if (!data.isValid) return false;
    if (data.volume < _config.volumeThreshold) return false;
    if (data.precision < _config.precisionThreshold) return false;
    if (data.midiNote < _config.minMidiNote) return false;
    if (data.midiNote > _config.maxMidiNote) return false;
    return true;
  }

  /// 尝试发射 onset 事件（带去抖）
  void _tryEmitOnset(PitchData data) {
    final now = data.timestamp;
    final elapsed = now.difference(_lastOnsetTime).inMilliseconds;

    // 同一音符的去抖
    if (data.midiNote == _lastOnsetNote &&
        elapsed < _config.debounceMs) {
      return;
    }

    _lastOnsetNote = data.midiNote;
    _lastOnsetTime = now;

    _onsetController.add(OnsetEvent(
      midiNote: data.midiNote,
      frequency: data.frequency,
      volume: data.volume,
      timestamp: now,
    ));
  }

  /// 释放资源
  void dispose() {
    detach();
    _onsetController.close();
  }
}
