import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../follow/follow_mode_controller.dart';
import '../follow/follow_mode_session.dart';
import '../follow/onset_detector.dart';

abstract class AppSettingsStorage {
  Future<Map<String, Object?>> read();
  Future<void> write(Map<String, Object?> values);
}

class FileAppSettingsStorage implements AppSettingsStorage {
  static const _fileName = 'settings.json';

  @override
  Future<Map<String, Object?>> read() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return const {};
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      return const {};
    }
    return Map<String, Object?>.from(decoded);
  }

  @override
  Future<void> write(Map<String, Object?> values) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(values));
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }
}

class AppSettingsController extends ChangeNotifier {
  static const double defaultPlaybackSpeedValue = 1.0;
  static const double defaultMicrophoneMinPrecisionValue = 0.6;
  static const double defaultOnsetVolumeThresholdValue = 0.0005;
  static const int defaultNoteMatchToleranceValue = 2;
  static const bool defaultAllowOctaveErrorValue = true;
  static const double defaultMinMeasuredSpeedFactorValue = 0.6;
  static const double defaultMaxMeasuredSpeedFactorValue = 1.6;
  static const double defaultRestThresholdSecondsValue = 1.0;

  final AppSettingsStorage _storage;

  double _defaultPlaybackSpeed = defaultPlaybackSpeedValue;
  double _microphoneMinPrecision = defaultMicrophoneMinPrecisionValue;
  double _onsetVolumeThreshold = defaultOnsetVolumeThresholdValue;
  int _noteMatchTolerance = defaultNoteMatchToleranceValue;
  bool _allowOctaveError = defaultAllowOctaveErrorValue;
  double _minMeasuredSpeedFactor = defaultMinMeasuredSpeedFactorValue;
  double _maxMeasuredSpeedFactor = defaultMaxMeasuredSpeedFactorValue;
  double _restThresholdSeconds = defaultRestThresholdSecondsValue;
  bool _isLoaded = false;

  AppSettingsController({AppSettingsStorage? storage})
    : _storage = storage ?? FileAppSettingsStorage();

  double get defaultPlaybackSpeed => _defaultPlaybackSpeed;
  double get microphoneMinPrecision => _microphoneMinPrecision;
  double get onsetVolumeThreshold => _onsetVolumeThreshold;
  int get noteMatchTolerance => _noteMatchTolerance;
  bool get allowOctaveError => _allowOctaveError;
  double get minMeasuredSpeedFactor => _minMeasuredSpeedFactor;
  double get maxMeasuredSpeedFactor => _maxMeasuredSpeedFactor;
  double get restThresholdSeconds => _restThresholdSeconds;
  bool get isLoaded => _isLoaded;

  FollowModeSessionConfig get followSessionConfig =>
      FollowModeSessionConfig(minPrecision: _microphoneMinPrecision);

  OnsetDetectorConfig get onsetDetectorConfig => OnsetDetectorConfig(
    volumeThreshold: _onsetVolumeThreshold,
    precisionThreshold: _microphoneMinPrecision,
  );

  FollowModeConfig get followModeConfig => FollowModeConfig(
    noteMatchTolerance: _noteMatchTolerance,
    allowOctaveError: _allowOctaveError,
    minMeasuredSpeedFactor: _minMeasuredSpeedFactor,
    maxMeasuredSpeedFactor: _maxMeasuredSpeedFactor,
    restThresholdSeconds: _restThresholdSeconds,
  );

  Future<void> load() async {
    var values = const <String, Object?>{};
    try {
      values = await _storage.read();
      _defaultPlaybackSpeed = _readDouble(
        values,
        'defaultPlaybackSpeed',
        defaultPlaybackSpeedValue,
        min: 0.25,
        max: 4.0,
      );
      _microphoneMinPrecision = _readDouble(
        values,
        'microphoneMinPrecision',
        defaultMicrophoneMinPrecisionValue,
        min: 0.4,
        max: 0.95,
      );
      _onsetVolumeThreshold = _readDouble(
        values,
        'onsetVolumeThreshold',
        defaultOnsetVolumeThresholdValue,
        min: 0.0001,
        max: 0.005,
      );
      _noteMatchTolerance = _readInt(
        values,
        'noteMatchTolerance',
        defaultNoteMatchToleranceValue,
        min: 0,
        max: 4,
      );
      _allowOctaveError = _readBool(
        values,
        'allowOctaveError',
        defaultAllowOctaveErrorValue,
      );
      _minMeasuredSpeedFactor = _readDouble(
        values,
        'minMeasuredSpeedFactor',
        defaultMinMeasuredSpeedFactorValue,
        min: 0.4,
        max: 1.0,
      );
      _maxMeasuredSpeedFactor = _readDouble(
        values,
        'maxMeasuredSpeedFactor',
        defaultMaxMeasuredSpeedFactorValue,
        min: 1.0,
        max: 2.2,
      );
      _restThresholdSeconds = _readDouble(
        values,
        'restThresholdSeconds',
        defaultRestThresholdSecondsValue,
        min: 0.5,
        max: 3.0,
      );
      _normalizeMeasuredSpeedRange();
    } catch (_) {
      // Keep safe defaults if the settings file is missing or malformed.
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  void setDefaultPlaybackSpeed(double value) {
    _update(() => _defaultPlaybackSpeed = _clampDouble(value, 0.25, 4.0));
  }

  void setMicrophoneMinPrecision(double value) {
    _update(() => _microphoneMinPrecision = _clampDouble(value, 0.4, 0.95));
  }

  void setOnsetVolumeThreshold(double value) {
    _update(() => _onsetVolumeThreshold = _clampDouble(value, 0.0001, 0.005));
  }

  void setNoteMatchTolerance(int value) {
    _update(() => _noteMatchTolerance = _clampInt(value, 0, 4));
  }

  void setAllowOctaveError({required bool value}) {
    _update(() => _allowOctaveError = value);
  }

  void setMinMeasuredSpeedFactor(double value) {
    _update(() {
      _minMeasuredSpeedFactor = _clampDouble(value, 0.4, 1.0);
      _normalizeMeasuredSpeedRange();
    });
  }

  void setMaxMeasuredSpeedFactor(double value) {
    _update(() {
      _maxMeasuredSpeedFactor = _clampDouble(value, 1.0, 2.2);
      _normalizeMeasuredSpeedRange();
    });
  }

  void setRestThresholdSeconds(double value) {
    _update(() => _restThresholdSeconds = _clampDouble(value, 0.5, 3.0));
  }

  void resetToDefaults() {
    _update(() {
      _defaultPlaybackSpeed = defaultPlaybackSpeedValue;
      _microphoneMinPrecision = defaultMicrophoneMinPrecisionValue;
      _onsetVolumeThreshold = defaultOnsetVolumeThresholdValue;
      _noteMatchTolerance = defaultNoteMatchToleranceValue;
      _allowOctaveError = defaultAllowOctaveErrorValue;
      _minMeasuredSpeedFactor = defaultMinMeasuredSpeedFactorValue;
      _maxMeasuredSpeedFactor = defaultMaxMeasuredSpeedFactorValue;
      _restThresholdSeconds = defaultRestThresholdSecondsValue;
    });
  }

  void _update(VoidCallback updateValues) {
    updateValues();
    notifyListeners();
    unawaited(_storage.write(_toJson()).catchError((Object _) {}));
  }

  Map<String, Object?> _toJson() => {
    'defaultPlaybackSpeed': _defaultPlaybackSpeed,
    'microphoneMinPrecision': _microphoneMinPrecision,
    'onsetVolumeThreshold': _onsetVolumeThreshold,
    'noteMatchTolerance': _noteMatchTolerance,
    'allowOctaveError': _allowOctaveError,
    'minMeasuredSpeedFactor': _minMeasuredSpeedFactor,
    'maxMeasuredSpeedFactor': _maxMeasuredSpeedFactor,
    'restThresholdSeconds': _restThresholdSeconds,
  };

  void _normalizeMeasuredSpeedRange() {
    if (_minMeasuredSpeedFactor > _maxMeasuredSpeedFactor) {
      _minMeasuredSpeedFactor = _maxMeasuredSpeedFactor;
    }
  }

  double _readDouble(
    Map<String, Object?> values,
    String key,
    double fallback, {
    required double min,
    required double max,
  }) {
    final value = values[key];
    if (value is num) {
      return _clampDouble(value.toDouble(), min, max);
    }
    return fallback;
  }

  int _readInt(
    Map<String, Object?> values,
    String key,
    int fallback, {
    required int min,
    required int max,
  }) {
    final value = values[key];
    if (value is num) {
      return _clampInt(value.round(), min, max);
    }
    return fallback;
  }

  bool _readBool(Map<String, Object?> values, String key, bool fallback) {
    final value = values[key];
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
