import 'package:flutter_test/flutter_test.dart';
import 'package:midi_music/core/settings/app_settings.dart';

void main() {
  test('加载设置时会裁剪到安全范围并生成跟随配置', () async {
    final settings = AppSettingsController(
      storage: _MemorySettingsStorage(
        initialValues: {
          'defaultPlaybackSpeed': 8.0,
          'microphoneMinPrecision': 1.0,
          'onsetVolumeThreshold': 0.00001,
          'noteMatchTolerance': 9,
          'allowOctaveError': false,
          'minMeasuredSpeedFactor': 1.2,
          'maxMeasuredSpeedFactor': 0.8,
          'restThresholdSeconds': 9.0,
        },
      ),
    );

    await settings.load();

    expect(settings.defaultPlaybackSpeed, 4.0);
    expect(settings.microphoneMinPrecision, 0.95);
    expect(settings.onsetVolumeThreshold, 0.0001);
    expect(settings.noteMatchTolerance, 4);
    expect(settings.allowOctaveError, isFalse);
    expect(settings.minMeasuredSpeedFactor, 1.0);
    expect(settings.maxMeasuredSpeedFactor, 1.0);
    expect(settings.restThresholdSeconds, 3.0);

    expect(settings.followSessionConfig.minPrecision, 0.95);
    expect(settings.onsetDetectorConfig.volumeThreshold, 0.0001);
    expect(settings.followModeConfig.allowOctaveError, isFalse);
    expect(settings.followModeConfig.noteMatchTolerance, 4);
  });

  test('更新设置会持久化，恢复默认会写回推荐值', () async {
    final storage = _MemorySettingsStorage();
    final settings = AppSettingsController(storage: storage);

    settings.setDefaultPlaybackSpeed(2.5);
    settings.setAllowOctaveError(value: false);
    await pumpEventQueue();

    expect(storage.values['defaultPlaybackSpeed'], 2.5);
    expect(storage.values['allowOctaveError'], isFalse);

    settings.resetToDefaults();
    await pumpEventQueue();

    expect(
      storage.values['defaultPlaybackSpeed'],
      AppSettingsController.defaultPlaybackSpeedValue,
    );
    expect(
      storage.values['allowOctaveError'],
      AppSettingsController.defaultAllowOctaveErrorValue,
    );
  });
}

class _MemorySettingsStorage implements AppSettingsStorage {
  Map<String, Object?> values;

  _MemorySettingsStorage({Map<String, Object?>? initialValues})
    : values = Map<String, Object?>.from(initialValues ?? const {});

  @override
  Future<Map<String, Object?>> read() async =>
      Map<String, Object?>.from(values);

  @override
  Future<void> write(Map<String, Object?> values) async {
    this.values = Map<String, Object?>.from(values);
  }
}
