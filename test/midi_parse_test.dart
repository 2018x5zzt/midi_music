import 'dart:io';
import 'package:dart_midi_pro/dart_midi_pro.dart' as midi;

/// 独立测试脚本：验证 Beethoven-Moonlight-Sonata.mid 能否被正确解析
void main() {
  final filePath = 'assets/midi/Beethoven-Moonlight-Sonata.mid';
  final file = File(filePath);

  if (!file.existsSync()) {
    print('ERROR: File not found: $filePath');
    return;
  }

  print('=== MIDI File Parse Test ===');
  print('File: $filePath');
  print('Size: ${file.lengthSync()} bytes');
  print('');

  try {
    final bytes = file.readAsBytesSync();
    final parser = midi.MidiParser();
    final midiFile = parser.parseMidiFromBuffer(bytes);

    // Header info
    print('--- Header ---');
    print('Format: ${midiFile.header.format}');
    print('Tracks: ${midiFile.header.numTracks}');
    print('TicksPerBeat: ${midiFile.header.ticksPerBeat}');
    print('');

    // Per-track summary
    for (int i = 0; i < midiFile.tracks.length; i++) {
      final track = midiFile.tracks[i];
      _analyzeTrack(track, i);
    }

    print('');
    print('=== Parse SUCCESS ===');
  } catch (e, st) {
    print('=== Parse FAILED ===');
    print('Error: $e');
    print('Stack: $st');
  }
}

void _analyzeTrack(List<midi.MidiEvent> events, int index) {
  int noteOnCount = 0;
  int noteOffCount = 0;
  int programChangeCount = 0;
  int controlChangeCount = 0;
  int tempoCount = 0;
  int timeSignatureCount = 0;
  int otherCount = 0;
  String trackName = '';
  int absoluteTick = 0;
  final channels = <int>{};

  for (final event in events) {
    absoluteTick += event.deltaTime;

    if (event is midi.NoteOnEvent) {
      noteOnCount++;
      channels.add(event.channel);
    } else if (event is midi.NoteOffEvent) {
      noteOffCount++;
      channels.add(event.channel);
    } else if (event is midi.ProgramChangeMidiEvent) {
      programChangeCount++;
      channels.add(event.channel);
    } else if (event is midi.ControllerEvent) {
      controlChangeCount++;
      channels.add(event.channel);
    } else if (event is midi.SetTempoEvent) {
      tempoCount++;
      final bpm = 60000000.0 / event.microsecondsPerBeat;
      print('  Track $index: Tempo at tick $absoluteTick = ${bpm.toStringAsFixed(1)} BPM');
    } else if (event is midi.TimeSignatureEvent) {
      timeSignatureCount++;
      print('  Track $index: TimeSignature at tick $absoluteTick = ${event.numerator}/${event.denominator}');
    } else if (event is midi.TrackNameEvent) {
      trackName = event.text;
    } else {
      otherCount++;
    }
  }

  print('Track $index: "$trackName" | ticks=$absoluteTick | ch=$channels');
  print('  NoteOn=$noteOnCount NoteOff=$noteOffCount PC=$programChangeCount CC=$controlChangeCount Tempo=$tempoCount TS=$timeSignatureCount Other=$otherCount');
}
