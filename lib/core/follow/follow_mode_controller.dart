import 'dart:async';

import '../../models/midi_track.dart';
import 'onset_detector.dart';

// ============================================================
// 状态定义
// ============================================================

/// 跟随模式状态
enum FollowModeState {
  /// 空闲，未启动跟随
  idle,

  /// 正在跟随演奏者
  following,

  /// 等待演奏者在休止符后重新开始
  waitingForOnset,
}

// ============================================================
// 配置
// ============================================================

/// 跟随模式配置
class FollowModeConfig {
  /// EMA 平滑系数 (0.0-1.0)，越大越灵敏
  final double emaSmoothingAlpha;

  /// speedFactor 允许范围下限
  final double minSpeedFactor;

  /// speedFactor 允许范围上限
  final double maxSpeedFactor;

  /// 音符匹配容差（半音数），允许偏差范围
  final int noteMatchTolerance;

  /// 休止符检测阈值（秒），期望音符间隔超过此值视为休止符
  final double restThresholdSeconds;

  /// 连续未匹配 onset 达到此数量后降低 speedFactor
  final int unmatchedThreshold;

  const FollowModeConfig({
    this.emaSmoothingAlpha = 0.3,
    this.minSpeedFactor = 0.25,
    this.maxSpeedFactor = 4.0,
    this.noteMatchTolerance = 2,
    this.restThresholdSeconds = 1.0,
    this.unmatchedThreshold = 3,
  });
}

// ============================================================
// 速度变化回调类型
// ============================================================

/// 速度变化回调
typedef SpeedChangeCallback = void Function(double speedFactor);

/// 状态变化回调
typedef StateChangeCallback = void Function(FollowModeState state);

// ============================================================
// FollowModeController
// ============================================================

/// 跟随模式控制器
///
/// 状态机：Idle → Following → WaitingForOnset → Following
/// 职责：订阅 OnsetDetector 的 onset 流，与乐谱期望音符匹配，
/// 计算 EMA 平滑的 speedFactor，通过回调通知播放器调速。
class FollowModeController {
  final OnsetDetector _onsetDetector;
  FollowModeConfig _config;

  /// 当前状态
  FollowModeState _state = FollowModeState.idle;

  /// 当前平滑后的 speedFactor
  double _speedFactor = 1.0;

  /// 乐谱中的期望音符序列（按 startTime 排序）
  List<MidiNote> _scoreNotes = [];

  /// 当前期望音符索引
  int _expectedNoteIndex = 0;

  /// 上一次 onset 的时间戳
  DateTime? _lastOnsetTimestamp;

  /// 连续未匹配计数
  int _unmatchedCount = 0;

  /// onset 流订阅
  StreamSubscription<OnsetEvent>? _onsetSubscription;

  /// 回调
  SpeedChangeCallback? onSpeedChanged;
  StateChangeCallback? onStateChanged;

  // Getters
  FollowModeState get state => _state;
  double get speedFactor => _speedFactor;
  FollowModeConfig get config => _config;
  bool get isActive => _state != FollowModeState.idle;

  FollowModeController({
    required OnsetDetector onsetDetector,
    FollowModeConfig? config,
  })  : _onsetDetector = onsetDetector,
        _config = config ?? const FollowModeConfig();

  /// 更新配置
  void updateConfig(FollowModeConfig config) {
    _config = config;
  }

  /// 加载乐谱音符序列（主旋律轨道的音符，按 startTime 排序）
  void loadScore(List<MidiNote> notes) {
    _scoreNotes = List.of(notes)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 启动跟随模式
  void start() {
    if (_scoreNotes.isEmpty) return;

    _expectedNoteIndex = 0;
    _speedFactor = 1.0;
    _unmatchedCount = 0;
    _lastOnsetTimestamp = null;

    _onsetSubscription?.cancel();
    _onsetSubscription = _onsetDetector.onsetStream.listen(
      _handleOnset,
    );

    _setState(FollowModeState.following);
  }

  /// 停止跟随模式
  void stop() {
    _onsetSubscription?.cancel();
    _onsetSubscription = null;
    _speedFactor = 1.0;
    _setState(FollowModeState.idle);
    onSpeedChanged?.call(1.0);
  }

  /// 从指定音符索引恢复（用于 seek 后重新对齐）
  void resumeFromIndex(int noteIndex) {
    if (noteIndex < 0 || noteIndex >= _scoreNotes.length) return;
    _expectedNoteIndex = noteIndex;
    _unmatchedCount = 0;
    _lastOnsetTimestamp = null;
    if (_state == FollowModeState.idle) {
      start();
    } else {
      _setState(FollowModeState.following);
    }
  }

  // ============================================================
  // 核心逻辑：onset 处理
  // ============================================================

  /// 处理 onset 事件
  void _handleOnset(OnsetEvent onset) {
    if (_state == FollowModeState.idle) return;
    if (_expectedNoteIndex >= _scoreNotes.length) {
      // 乐谱已结束
      stop();
      return;
    }

    final expectedNote = _scoreNotes[_expectedNoteIndex];
    final isMatch = _matchesExpectedNote(onset.midiNote, expectedNote);

    if (isMatch) {
      _onNoteMatched(onset, expectedNote);
    } else {
      _onNoteUnmatched(onset);
    }
  }

  /// 音符匹配成功
  void _onNoteMatched(OnsetEvent onset, MidiNote expectedNote) {
    _unmatchedCount = 0;

    // 如果是从 WaitingForOnset 恢复，切回 Following
    if (_state == FollowModeState.waitingForOnset) {
      _setState(FollowModeState.following);
    }

    // 计算 speedFactor
    if (_lastOnsetTimestamp != null) {
      final actualInterval =
          onset.timestamp.difference(_lastOnsetTimestamp!).inMilliseconds /
              1000.0;

      // 期望间隔 = 当前音符 startTime - 上一个匹配音符 startTime
      final prevIndex = _expectedNoteIndex - 1;
      if (prevIndex >= 0 && actualInterval > 0.01) {
        final expectedInterval =
            expectedNote.startTime - _scoreNotes[prevIndex].startTime;

        if (expectedInterval > 0.01) {
          final rawFactor = expectedInterval / actualInterval;
          _applyEmaSpeed(rawFactor);
        }
      }
    }

    _lastOnsetTimestamp = onset.timestamp;
    _expectedNoteIndex++;

    // 检查下一个音符是否为休止符（间隔大）
    _checkForRest();
  }

  /// 音符未匹配
  void _onNoteUnmatched(OnsetEvent onset) {
    _unmatchedCount++;

    // 尝试向前搜索：演奏者可能跳过了一些音符
    final lookAhead = _findMatchInRange(
      onset.midiNote,
      _expectedNoteIndex + 1,
      _expectedNoteIndex + 4, // 最多向前看 3 个音符
    );

    if (lookAhead >= 0) {
      // 找到匹配，跳过中间音符
      _expectedNoteIndex = lookAhead;
      _onNoteMatched(onset, _scoreNotes[lookAhead]);
      return;
    }

    // 连续未匹配过多，逐渐降速
    if (_unmatchedCount >= _config.unmatchedThreshold) {
      _applyEmaSpeed(_speedFactor * 0.9);
    }
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 检查下一个期望音符前是否有休止符
  void _checkForRest() {
    if (_expectedNoteIndex >= _scoreNotes.length) return;
    if (_expectedNoteIndex == 0) return;

    final prevNote = _scoreNotes[_expectedNoteIndex - 1];
    final nextNote = _scoreNotes[_expectedNoteIndex];
    final gap = nextNote.startTime - prevNote.endTime;

    if (gap >= _config.restThresholdSeconds) {
      _setState(FollowModeState.waitingForOnset);
    }
  }

  /// 判断 onset 音符是否匹配期望音符（允许容差）
  bool _matchesExpectedNote(int onsetMidi, MidiNote expected) {
    final diff = (onsetMidi - expected.noteNumber).abs();
    return diff <= _config.noteMatchTolerance;
  }

  /// 在指定范围内查找匹配音符，返回索引，未找到返回 -1
  int _findMatchInRange(int onsetMidi, int fromIndex, int toIndex) {
    final end = toIndex.clamp(0, _scoreNotes.length);
    final start = fromIndex.clamp(0, end);
    for (int i = start; i < end; i++) {
      if (_matchesExpectedNote(onsetMidi, _scoreNotes[i])) {
        return i;
      }
    }
    return -1;
  }

  /// EMA 平滑更新 speedFactor 并通知回调
  void _applyEmaSpeed(double rawFactor) {
    final clamped = rawFactor.clamp(
      _config.minSpeedFactor,
      _config.maxSpeedFactor,
    );
    final alpha = _config.emaSmoothingAlpha;
    _speedFactor = alpha * clamped + (1 - alpha) * _speedFactor;
    onSpeedChanged?.call(_speedFactor);
  }

  /// 切换状态并通知回调
  void _setState(FollowModeState newState) {
    if (_state == newState) return;
    _state = newState;
    onStateChanged?.call(newState);
  }

  /// 释放资源
  void dispose() {
    stop();
  }
}
