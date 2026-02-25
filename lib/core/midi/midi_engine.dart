import 'package:flutter_midi_pro/flutter_midi_pro.dart';

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
    _soundfontId = await _midiPro.loadSoundfontAsset(
      assetPath: assetPath,
      bank: 0,
      program: 0,
    );
    _isReady = true;
  }

  /// 从文件路径加载 SoundFont
  Future<void> loadSoundfontFromFile(String filePath) async {
    _soundfontId = await _midiPro.loadSoundfontFile(
      filePath: filePath,
      bank: 0,
      program: 0,
    );
    _isReady = true;
  }

  /// 切换指定通道的乐器
  Future<void> setInstrument({
    required int channel,
    required int program,
    int bank = 0,
  }) async {
    if (_soundfontId == null) return;
    await _midiPro.selectInstrument(
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
    if (!_isReady || _soundfontId == null) return;
    _midiPro.stopAllNotes(sfId: _soundfontId!);
  }

  /// 释放资源
  Future<void> dispose() async {
    allNotesOff();
    if (_soundfontId != null) {
      await _midiPro.unloadSoundfont(_soundfontId!);
    }
    await _midiPro.dispose();
    _isReady = false;
    _soundfontId = null;
  }
}
