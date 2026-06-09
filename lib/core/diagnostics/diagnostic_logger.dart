import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'app_error.dart';

class DiagnosticLogger extends ChangeNotifier {
  static final DiagnosticLogger instance = DiagnosticLogger._();
  static const int _maxMemoryEntries = 200;

  final List<AppError> _recentErrors = [];
  File? _logFile;
  bool _initializing = false;

  DiagnosticLogger._();

  List<AppError> get recentErrors => List.unmodifiable(_recentErrors);
  AppError? get latestError =>
      _recentErrors.isEmpty ? null : _recentErrors.last;

  Future<void> initialize() async {
    if (_logFile != null || _initializing) return;
    _initializing = true;
    try {
      final directory = await getApplicationSupportDirectory();
      final diagnosticsDir = Directory('${directory.path}/diagnostics');
      await diagnosticsDir.create(recursive: true);
      _logFile = File('${diagnosticsDir.path}/diagnostics.jsonl');
    } finally {
      _initializing = false;
    }
  }

  Future<void> recordError(AppError error) async {
    _recentErrors.add(error);
    if (_recentErrors.length > _maxMemoryEntries) {
      _recentErrors.removeRange(0, _recentErrors.length - _maxMemoryEntries);
    }
    notifyListeners();

    try {
      await initialize();
      final file = _logFile;
      if (file == null) return;
      await _rotateIfNeeded(file);
      await file.writeAsString(
        '${jsonEncode(error.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Diagnostics must never break playback or UI flows.
    }
  }

  String exportText() {
    if (_recentErrors.isEmpty) {
      return 'No diagnostics recorded.';
    }
    return _recentErrors.map((error) => error.toExportText()).join('\n\n');
  }

  Future<void> clear() async {
    _recentErrors.clear();
    notifyListeners();
    try {
      final file = _logFile;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final length = await file.length();
    if (length <= 1024 * 1024) return;
    await file.writeAsString('', flush: true);
  }
}
