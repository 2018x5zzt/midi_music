class RecentMidiEntry {
  final String id;
  final String fileName;
  final String filePath;
  final int? fileSize;
  final int? modifiedMs;
  final int importedAtMs;
  final int lastOpenedAtMs;

  const RecentMidiEntry({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.fileSize,
    this.modifiedMs,
    required this.importedAtMs,
    required this.lastOpenedAtMs,
  });

  factory RecentMidiEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final fileName = json['fileName'];
    final filePath = json['filePath'];
    final importedAtMs = _readInt(json['importedAtMs'], 0);
    final lastOpenedAtMs = _readInt(json['lastOpenedAtMs'], importedAtMs);
    if (id is! String || fileName is! String || filePath is! String) {
      throw const FormatException('Invalid recent MIDI entry');
    }
    return RecentMidiEntry(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileSize: _readNullableInt(json['fileSize']),
      modifiedMs: _readNullableInt(json['modifiedMs']),
      importedAtMs: importedAtMs,
      lastOpenedAtMs: lastOpenedAtMs,
    );
  }

  static String buildId({
    required String filePath,
    int? fileSize,
    int? modifiedMs,
  }) {
    return '$filePath|${fileSize ?? 0}|${modifiedMs ?? 0}';
  }

  RecentMidiEntry copyWith({int? importedAtMs, int? lastOpenedAtMs}) {
    return RecentMidiEntry(
      id: id,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      modifiedMs: modifiedMs,
      importedAtMs: importedAtMs ?? this.importedAtMs,
      lastOpenedAtMs: lastOpenedAtMs ?? this.lastOpenedAtMs,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'fileName': fileName,
    'filePath': filePath,
    if (fileSize != null) 'fileSize': fileSize,
    if (modifiedMs != null) 'modifiedMs': modifiedMs,
    'importedAtMs': importedAtMs,
    'lastOpenedAtMs': lastOpenedAtMs,
  };
}

class TrackPreference {
  final bool isMuted;
  final double volume;

  const TrackPreference({required this.isMuted, required this.volume});

  factory TrackPreference.fromJson(Map<String, Object?> json) {
    return TrackPreference(
      isMuted: json['isMuted'] is bool ? json['isMuted']! as bool : false,
      volume: _clampDouble(_readDouble(json['volume'], 1.0), 0.0, 1.0),
    );
  }

  Map<String, Object?> toJson() => {'isMuted': isMuted, 'volume': volume};
}

class MidiSessionSnapshot {
  final String songId;
  final double currentTime;
  final double playbackSpeed;
  final int? melodyTrackIndex;
  final Map<int, TrackPreference> trackPreferences;
  final int updatedAtMs;

  const MidiSessionSnapshot({
    required this.songId,
    required this.currentTime,
    required this.playbackSpeed,
    this.melodyTrackIndex,
    Map<int, TrackPreference>? trackPreferences,
    required this.updatedAtMs,
  }) : trackPreferences = trackPreferences ?? const {};

  factory MidiSessionSnapshot.empty(String songId, int nowMs) {
    return MidiSessionSnapshot(
      songId: songId,
      currentTime: 0,
      playbackSpeed: 1,
      updatedAtMs: nowMs,
    );
  }

  factory MidiSessionSnapshot.fromJson(Map<String, Object?> json) {
    final songId = json['songId'];
    if (songId is! String) {
      throw const FormatException('Invalid session song id');
    }
    final rawPreferences = json['trackPreferences'];
    final preferences = <int, TrackPreference>{};
    if (rawPreferences is Map) {
      for (final entry in rawPreferences.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key == null || value is! Map) continue;
        preferences[key] = TrackPreference.fromJson(
          Map<String, Object?>.from(value),
        );
      }
    }
    return MidiSessionSnapshot(
      songId: songId,
      currentTime: _clampDouble(
        _readDouble(json['currentTime'], 0),
        0.0,
        (1 << 30).toDouble(),
      ),
      playbackSpeed: _clampDouble(
        _readDouble(json['playbackSpeed'], 1),
        0.25,
        4.0,
      ),
      melodyTrackIndex: _readNullableInt(json['melodyTrackIndex']),
      trackPreferences: preferences,
      updatedAtMs: _readInt(json['updatedAtMs'], 0),
    );
  }

  MidiSessionSnapshot copyWith({
    double? currentTime,
    double? playbackSpeed,
    Object? melodyTrackIndex = _sentinel,
    Map<int, TrackPreference>? trackPreferences,
    int? updatedAtMs,
  }) {
    final resolvedMelody = melodyTrackIndex == _sentinel
        ? this.melodyTrackIndex
        : melodyTrackIndex as int?;
    return MidiSessionSnapshot(
      songId: songId,
      currentTime: currentTime ?? this.currentTime,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      melodyTrackIndex: resolvedMelody,
      trackPreferences: trackPreferences ?? this.trackPreferences,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toJson() => {
    'songId': songId,
    'currentTime': currentTime,
    'playbackSpeed': playbackSpeed,
    if (melodyTrackIndex != null) 'melodyTrackIndex': melodyTrackIndex,
    'trackPreferences': trackPreferences.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    ),
    'updatedAtMs': updatedAtMs,
  };
}

const _sentinel = Object();

int _readInt(Object? value, int fallback) {
  if (value is num) return value.round();
  return fallback;
}

int? _readNullableInt(Object? value) {
  if (value is num) return value.round();
  return null;
}

double _readDouble(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

double _clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
