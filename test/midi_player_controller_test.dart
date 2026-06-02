import 'package:flutter_test/flutter_test.dart';
import 'package:midi_music/core/midi/midi_engine.dart';
import 'package:midi_music/core/midi/midi_player.dart';
import 'package:midi_music/models/midi_track.dart';

void main() {
  test('加载歌曲时发送每个轨道的初始乐器设置', () {
    final engine = _FakeMidiPlaybackEngine();
    final player = MidiPlayerController(engine: engine);

    player.loadSong(
      _song(
        tracks: [
          MidiTrackInfo(index: 0, programByChannel: {0: 40}),
          MidiTrackInfo(index: 1, programByChannel: {3: 12}),
        ],
      ),
    );

    expect(engine.calls.where((call) => call.type == 'setInstrument'), [
      _EngineCall.setInstrument(channel: 0, program: 40),
      _EngineCall.setInstrument(channel: 3, program: 12),
    ]);

    player.dispose();
  });

  test('负数轨道控制不会抛出越界异常', () {
    final engine = _FakeMidiPlaybackEngine();
    final player = MidiPlayerController(engine: engine);
    player.loadSong(_song(tracks: [_track(index: 0)]));

    expect(() => player.setTrackVolume(-1, 0.5), returnsNormally);
    expect(() => player.toggleTrackMute(-1), returnsNormally);

    player.dispose();
  });

  testWidgets('播放时按轨道音量折算 NoteOn 力度', (tester) async {
    final engine = _FakeMidiPlaybackEngine();
    final player = MidiPlayerController(engine: engine);
    player.loadSong(
      _song(
        tracks: [_track(index: 0)],
        timeline: [
          _noteOn(trackIndex: 0, channel: 0, note: 60, velocity: 100, time: 0),
        ],
      ),
    );
    player.setTrackVolume(0, 0.5);
    engine.clear();

    player.play();
    await tester.pump(const Duration(milliseconds: 6));

    expect(engine.calls.where((call) => call.type == 'noteOn'), [
      _EngineCall.noteOn(channel: 0, note: 60, velocity: 50),
    ]);

    player.dispose();
  });

  testWidgets('静音轨道不会分发 NoteOn', (tester) async {
    final engine = _FakeMidiPlaybackEngine();
    final player = MidiPlayerController(engine: engine);
    player.loadSong(
      _song(
        tracks: [
          _track(index: 0, channels: {0}),
        ],
        timeline: [
          _noteOn(trackIndex: 0, channel: 0, note: 60, velocity: 100, time: 0),
        ],
      ),
    );
    player.toggleTrackMute(0);
    engine.clear();

    player.play();
    await tester.pump(const Duration(milliseconds: 6));

    expect(engine.calls.where((call) => call.type == 'noteOn'), isEmpty);

    player.dispose();
  });

  testWidgets('seek 到事件之后再播放不会重放旧事件', (tester) async {
    final engine = _FakeMidiPlaybackEngine();
    final player = MidiPlayerController(engine: engine);
    player.loadSong(
      _song(
        tracks: [_track(index: 0)],
        timeline: [
          _noteOn(
            trackIndex: 0,
            channel: 0,
            note: 60,
            velocity: 100,
            time: 0.1,
          ),
        ],
      ),
    );
    player.seekTo(0.2);
    engine.clear();

    player.play();
    await tester.pump(const Duration(milliseconds: 6));

    expect(engine.calls.where((call) => call.type == 'noteOn'), isEmpty);

    player.dispose();
  });
}

MidiSongData _song({
  List<MidiTrackInfo>? tracks,
  List<TimelineEvent>? timeline,
}) {
  return MidiSongData(
    fileName: 'controller-test.mid',
    format: 1,
    ticksPerBeat: 480,
    tracks: tracks ?? [_track(index: 0)],
    timeline: timeline ?? const [],
    tempoChanges: [TempoChange(tick: 0, microsecondsPerBeat: 500000)],
    timeSignatureChanges: const [],
    totalTicks: 960,
    totalDuration: 2,
  );
}

MidiTrackInfo _track({required int index, Set<int>? channels}) {
  return MidiTrackInfo(index: index, channels: channels ?? {0});
}

TimelineEvent _noteOn({
  required int trackIndex,
  required int channel,
  required int note,
  required int velocity,
  required double time,
}) {
  return TimelineEvent(
    type: MidiEventType.noteOn,
    tick: (time * 960).round(),
    time: time,
    channel: channel,
    trackIndex: trackIndex,
    data1: note,
    data2: velocity,
  );
}

class _FakeMidiPlaybackEngine implements MidiPlaybackEngine {
  final calls = <_EngineCall>[];
  bool ready = true;

  @override
  bool get isReady => ready;

  void clear() => calls.clear();

  @override
  Future<void> loadSoundfontFromAsset(String assetPath) async {
    ready = true;
    calls.add(_EngineCall.loadAsset(assetPath));
  }

  @override
  Future<void> loadSoundfontFromFile(String filePath) async {
    ready = true;
    calls.add(_EngineCall.loadFile(filePath));
  }

  @override
  Future<void> setInstrument({
    required int channel,
    required int program,
    int bank = 0,
  }) async {
    calls.add(_EngineCall.setInstrument(channel: channel, program: program));
  }

  @override
  Future<void> noteOn({
    required int channel,
    required int note,
    required int velocity,
  }) async {
    calls.add(
      _EngineCall.noteOn(channel: channel, note: note, velocity: velocity),
    );
  }

  @override
  Future<void> noteOff({required int channel, required int note}) async {
    calls.add(_EngineCall.noteOff(channel: channel, note: note));
  }

  @override
  Future<void> allNotesOff() async {
    calls.add(const _EngineCall(type: 'allNotesOff'));
  }

  @override
  Future<void> waitForPendingOperations() async {}

  @override
  Future<void> dispose() async {
    ready = false;
    calls.add(const _EngineCall(type: 'dispose'));
  }
}

class _EngineCall {
  final String type;
  final int? channel;
  final int? program;
  final int? note;
  final int? velocity;
  final String? path;

  const _EngineCall({
    required this.type,
    this.channel,
    this.program,
    this.note,
    this.velocity,
    this.path,
  });

  const _EngineCall.loadAsset(String assetPath)
    : this(type: 'loadAsset', path: assetPath);

  const _EngineCall.loadFile(String filePath)
    : this(type: 'loadFile', path: filePath);

  const _EngineCall.setInstrument({required int channel, required int program})
    : this(type: 'setInstrument', channel: channel, program: program);

  const _EngineCall.noteOn({
    required int channel,
    required int note,
    required int velocity,
  }) : this(type: 'noteOn', channel: channel, note: note, velocity: velocity);

  const _EngineCall.noteOff({required int channel, required int note})
    : this(type: 'noteOff', channel: channel, note: note);

  @override
  bool operator ==(Object other) {
    return other is _EngineCall &&
        other.type == type &&
        other.channel == channel &&
        other.program == program &&
        other.note == note &&
        other.velocity == velocity &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(type, channel, program, note, velocity, path);

  @override
  String toString() {
    return '_EngineCall($type, channel:$channel, program:$program, '
        'note:$note, velocity:$velocity, path:$path)';
  }
}
