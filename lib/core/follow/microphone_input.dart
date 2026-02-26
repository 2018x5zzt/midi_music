import 'dart:async';

import 'package:flutter_pitch_detection/flutter_pitch_detection.dart';

import 'onset_detector.dart';

/// 麦克风输入封装
///
/// 封装 flutter_pitch_detection，提供 [Stream<PitchData>] 给 [OnsetDetector]。
/// 负责麦克风权限、启停控制和原始数据转换。
class MicrophoneInput {
  final FlutterPitchDetection _pitchDetector = FlutterPitchDetection();
  final _pitchController = StreamController<PitchData>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _rawSubscription;
  bool _isListening = false;

  /// 是否正在监听
  bool get isListening => _isListening;

  /// PitchData 输出流，供 OnsetDetector 订阅
  Stream<PitchData> get pitchStream => _pitchController.stream;

  /// 启动麦克风监听
  ///
  /// 配置 pitch detection 参数并开始接收数据。
  Future<void> start({
    int sampleRate = 44100,
    int bufferSize = 8192,
    double minPrecision = 0.7,
    double toleranceCents = 0.6,
  }) async {
    if (_isListening) return;

    // 配置参数
    _pitchDetector.setParameters(
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      minPrecision: minPrecision,
      toleranceCents: toleranceCents,
    );

    // 启动检测（权限由插件自动处理）
    await _pitchDetector.startDetection();
    _isListening = true;

    // 订阅原始 pitch 数据流
    _rawSubscription = _pitchDetector.onPitchDetected.listen(
      _onRawPitchData,
      onError: (e) => _pitchController.addError(e),
    );
  }

  /// 停止麦克风监听
  Future<void> stop() async {
    if (!_isListening) return;

    _rawSubscription?.cancel();
    _rawSubscription = null;

    await _pitchDetector.stopDetection();
    _isListening = false;
  }

  /// 处理原始 pitch 数据，转换为 PitchData
  void _onRawPitchData(Map<String, dynamic> data) {
    if (_pitchController.isClosed) return;

    final pitchData = PitchData(
      frequency: (data['frequency'] as num?)?.toDouble() ?? -1.0,
      midiNote: (data['midiNote'] as num?)?.toInt() ?? -1,
      noteName: (data['note'] as String?) ?? '',
      octave: (data['octave'] as num?)?.toInt() ?? -1,
      volume: (data['volume'] as num?)?.toDouble() ?? 0.0,
      volumeDbFS: (data['volumeDbFS'] as num?)?.toDouble() ?? -100.0,
      precision: (data['precision'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );

    _pitchController.add(pitchData);
  }

  /// 释放资源
  Future<void> dispose() async {
    await stop();
    await _pitchController.close();
  }
}
