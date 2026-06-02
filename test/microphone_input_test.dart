import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:midi_music/core/follow/microphone_input.dart';

void main() {
  test('start 等待底层采集启动时已经进入监听状态', () async {
    final capture = _FakeAudioCaptureAdapter(startGate: Completer<void>());
    final input = MicrophoneInput(audioCapture: capture);

    final startFuture = input.start();
    await capture.startEntered.future;

    expect(input.isListening, isTrue);

    capture.completeStart();
    await startFuture;
    await input.dispose();
  });

  test('stop 会在等待底层停止前先退出监听状态', () async {
    final capture = _FakeAudioCaptureAdapter(stopGate: Completer<void>());
    final input = MicrophoneInput(audioCapture: capture);

    await input.start();
    final stopFuture = input.stop();
    await capture.stopEntered.future;

    expect(input.isListening, isFalse);

    capture.completeStop();
    await stopFuture;
    await input.dispose();
  });

  test('dispose 可以安全打断尚未完成的 start', () async {
    final capture = _FakeAudioCaptureAdapter(
      startGate: Completer<void>(),
      stopGate: Completer<void>(),
    );
    final input = MicrophoneInput(audioCapture: capture);

    final startFuture = input.start();
    await capture.startEntered.future;

    final disposeFuture = input.dispose();
    await capture.stopEntered.future;

    expect(input.isListening, isFalse);

    capture.completeStop();
    await disposeFuture;

    capture.completeStart();
    await startFuture;

    expect(input.isListening, isFalse);
  });

  test('dispose 后再次 start 会抛出状态错误', () async {
    final input = MicrophoneInput(audioCapture: _FakeAudioCaptureAdapter());

    await input.dispose();

    expect(input.start(), throwsA(isA<StateError>()));
  });
}

class _FakeAudioCaptureAdapter implements AudioCaptureAdapter {
  final startEntered = Completer<void>();
  final stopEntered = Completer<void>();
  final Completer<void> _startGate;
  final Completer<void> _stopGate;

  _FakeAudioCaptureAdapter({
    Completer<void>? startGate,
    Completer<void>? stopGate,
  }) : _startGate = startGate ?? Completer<void>(),
       _stopGate = stopGate ?? Completer<void>() {
    if (startGate == null) {
      _startGate.complete();
    }
    if (stopGate == null) {
      _stopGate.complete();
    }
  }

  @override
  Future<bool?> init() async => true;

  @override
  Future<void> start(
    void Function(Float32List audioData) listener,
    void Function(Object error) onError, {
    required int sampleRate,
    required int bufferSize,
    required bool waitForFirstDataOnIOS,
  }) async {
    if (!startEntered.isCompleted) {
      startEntered.complete();
    }
    await _startGate.future;
  }

  @override
  Future<void> stop() async {
    if (!stopEntered.isCompleted) {
      stopEntered.complete();
    }
    await _stopGate.future;
  }

  void completeStart() {
    if (!_startGate.isCompleted) {
      _startGate.complete();
    }
  }

  void completeStop() {
    if (!_stopGate.isCompleted) {
      _stopGate.complete();
    }
  }
}
