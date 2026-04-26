import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

import 'onset_detector.dart';

class MicrophoneInput {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  final _pitchController = StreamController<PitchData>.broadcast();

  PitchDetector? _pitchDetector;
  bool _isListening = false;
  bool _isProcessingBuffer = false;
  double _minPrecision = 0.7;

  bool get isListening => _isListening;
  Stream<PitchData> get pitchStream => _pitchController.stream;

  Future<void> start({
    int sampleRate = 44100,
    int bufferSize = 8192,
    double minPrecision = 0.7,
    double toleranceCents = 0.6,
  }) async {
    if (_isListening) return;

    final initialized = await _audioCapture.init();
    if (initialized != true) {
      throw Exception('麦克风初始化失败');
    }

    _pitchDetector = PitchDetector(
      audioSampleRate: sampleRate.toDouble(),
      bufferSize: bufferSize,
    );
    _minPrecision = minPrecision;

    await _audioCapture.start(
      _onAudioData,
      (Object error) {
        print('[MicrophoneError] $error');
        if (_pitchController.isClosed) return;
        _pitchController.addError(error);
      },
      sampleRate: sampleRate,
      bufferSize: bufferSize,
      waitForFirstDataOnIOS: false,
    );

    _isListening = true;
  }

  Future<void> stop() async {
    if (!_isListening) return;

    await _audioCapture.stop();
    _isListening = false;
    _isProcessingBuffer = false;
  }

  void _onAudioData(Float32List audioData) {
    if (_pitchController.isClosed || !_isListening) return;

    // 简单的流控：如果正在处理上一帧，跳过这一帧
    if (_isProcessingBuffer) {
      // 不打印跳过信息，避免日志过多
      return;
    }

    _isProcessingBuffer = true;
    _processAudioData(audioData).whenComplete(() {
      _isProcessingBuffer = false;
    }).catchError((error, stackTrace) {
      print('[AudioProcessingError] $error');
      print('[StackTrace] $stackTrace');
      // 不重新抛出错误，避免崩溃
    });
  }

  Future<void> _processAudioData(Float32List audioData) async {
    final detector = _pitchDetector;
    if (detector == null) return;
    if (audioData.length < detector.bufferSize) return;

    try {
      final samples = audioData
          .sublist(0, detector.bufferSize)
          .map((value) => value.toDouble())
          .toList(growable: false);
      final result = await detector.getPitchFromFloatBuffer(samples);

      final volume = _calculateRms(audioData);
      final volumeDbFS = volume <= 0
          ? -100.0
          : 20.0 * math.log(volume) / math.ln10;

      final hasPitch =
          result.pitched && result.pitch > 0 && result.probability >= _minPrecision;
      final frequency = hasPitch ? result.pitch : -1.0;
      final midiNote = hasPitch ? _frequencyToMidi(result.pitch) : -1;
      final precision = _clamp01(result.probability);

      _pitchController.add(PitchData(
        frequency: frequency,
        midiNote: midiNote,
        noteName: midiNote >= 0 ? _midiNoteName(midiNote) : '',
        octave: midiNote >= 0 ? _midiOctave(midiNote) : -1,
        volume: volume,
        volumeDbFS: volumeDbFS,
        precision: precision,
        timestamp: DateTime.now(),
      ));

      // 调试日志：每秒打印一次检测结果
      if (hasPitch && DateTime.now().millisecond % 1000 < 100) {
        print('[Pitch] Note=$midiNote ${midiNote >= 0 ? _midiNoteName(midiNote) : ""} Freq=${frequency.toStringAsFixed(1)}Hz Vol=${volume.toStringAsFixed(4)} Prec=${precision.toStringAsFixed(2)}');
      }
    } catch (error) {
      if (_pitchController.isClosed) return;
      print('[AudioProcessError] $error');
      _pitchController.addError(error);
    }
  }

  double _calculateRms(Float32List audioData) {
    if (audioData.isEmpty) return 0.0;

    var sumSquares = 0.0;
    var maxValue = 0.0;
    for (final sample in audioData) {
      final absSample = sample.abs();
      sumSquares += sample * sample;
      if (absSample > maxValue) {
        maxValue = absSample;
      }
    }

    final rms = math.sqrt(sumSquares / audioData.length);

    // 调试：打印音频数据统计（减少频率避免性能问题）
    if (DateTime.now().millisecond % 2000 < 100) {
      print('[AudioStats] RMS=${rms.toStringAsFixed(6)}, Max=${maxValue.toStringAsFixed(6)}, Samples=${audioData.length}');
    }

    // 直接返回RMS值，不做归一化，保留原始动态范围
    return rms;
  }

  int _frequencyToMidi(double frequency) {
    final midi = (69 + 12 * (math.log(frequency / 440.0) / math.ln2)).round();
    if (midi < 0) return 0;
    if (midi > 127) return 127;
    return midi;
  }

  String _midiNoteName(int midiNote) {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return names[midiNote % 12];
  }

  int _midiOctave(int midiNote) {
    return (midiNote ~/ 12) - 1;
  }

  double _clamp01(double value) {
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
  }

  Future<void> dispose() async {
    await stop();
    await _pitchController.close();
  }
}
