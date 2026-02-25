import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:path_provider/path_provider.dart';

/// SoundFont 引擎封装
///
/// 封装 flutter_midi_pro，提供 SoundFont 加载和 MIDI 音符播放能力。
class MidiEngine {
  final MidiPro _midiPro = MidiPro();
  int? _soundfontId;
  bool _isReady = false;

  bool get isReady => _isReady;
  int? get soundfontId => _soundfontId;

  /// 从 assets 加载 SoundFont 文件
  Future<void> loadSoundfontFromAsset(String assetPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');

    // 如果本地不存在则从 assets 复制
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
    }

    _soundfontId = await _midiPro.loadSoundfont(
      path: file.path,
      bank: 0,
      program: 0,
    );
    _isReady = _soundfontId != null;
  }

  /// 从文件路径加载 SoundFont
  Future<void> loadSoundfontFromFile(String filePath) async {
    _soundfontId = await _midiPro.loadSoundfont(
      path: filePath,
      bank: 0,
      program: 0,
    );
    _isReady = _soundfontId != null;
  }

  /// 切换指定通道的乐器
  Future<void> setInstrument({
    required int channel,
    required int program,
    int bank = 0,
  }) async {
    if (_soundfontId == null) return;
    await _midiPro.loadInstrument(
      sfId: _soundfontId!,
      channel: channel,
      bank: bank,
      program: program,
    );
  }

  /// 发送 Note On
  void noteOn({
    required int channel,
    required int note,
    required int velocity,
  }) {
    if (!_isReady) return;
    _midiPro.playNote(
      channel: channel,
      key: note,
      velocity: velocity,
    );
  }

  /// 发送 Note Off
  void noteOff({
    required int channel,
    required int note,
  }) {
    if (!_isReady) return;
    _midiPro.stopNote(
      channel: channel,
      key: note,
    );
  }

  /// 停止所有音符
  void allNotesOff() {
    if (!_isReady) return;
    for (int ch = 0; ch < 16; ch++) {
      _midiPro.allNotesOff(channel: ch);
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    allNotesOff();
    _isReady = false;
    _soundfontId = null;
  }
}
