import 'dart:convert';
import 'dart:io';

enum AppErrorSource {
  midiParser,
  soundfont,
  midiPlayback,
  midiEngine,
  microphone,
  followMode,
  permission,
  settings,
  unknown,
}

enum AppErrorSeverity { info, warning, error, fatal }

class AppError implements Exception {
  final String code;
  final AppErrorSource source;
  final AppErrorSeverity severity;
  final String userMessage;
  final String technicalMessage;
  final Map<String, Object?> context;
  final Object? cause;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final bool retryable;

  AppError({
    required this.code,
    required this.source,
    required this.severity,
    required this.userMessage,
    required this.technicalMessage,
    Map<String, Object?>? context,
    this.cause,
    this.stackTrace,
    DateTime? timestamp,
    this.retryable = false,
  }) : context = context ?? const {},
       timestamp = timestamp ?? DateTime.now();

  factory AppError.midiFileMissing({
    required String filePath,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'midi.file_missing',
      source: AppErrorSource.midiParser,
      severity: AppErrorSeverity.warning,
      userMessage: '找不到 MIDI 文件，请确认文件没有被移动或删除。',
      technicalMessage: 'MIDI file not found: ${_basename(filePath)}',
      context: {'fileName': _basename(filePath)},
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory AppError.midiParseFailed({
    required String fileName,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'midi.parse_failed',
      source: AppErrorSource.midiParser,
      severity: AppErrorSeverity.error,
      userMessage: '无法解析这份 MIDI 文件，请确认文件格式有效。',
      technicalMessage: 'MIDI parse failed: ${_basename(fileName)}',
      context: {'fileName': _basename(fileName)},
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory AppError.soundfontSetupFailed({
    Object? cause,
    StackTrace? stackTrace,
    bool retryable = true,
  }) {
    final isNetwork = cause is SocketException || cause is HttpException;
    return AppError(
      code: isNetwork ? 'soundfont.download_failed' : 'soundfont.load_failed',
      source: AppErrorSource.soundfont,
      severity: AppErrorSeverity.error,
      userMessage: isNetwork ? '音色库下载失败，请检查网络后重试。' : '音色库准备失败，请重试。',
      technicalMessage: cause?.toString() ?? 'SoundFont setup failed',
      cause: cause,
      stackTrace: stackTrace,
      retryable: retryable,
    );
  }

  factory AppError.playbackOperationFailed({
    required String context,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'playback.engine_operation_failed',
      source: AppErrorSource.midiPlayback,
      severity: AppErrorSeverity.warning,
      userMessage: '播放引擎遇到一次异常，已尝试继续播放。',
      technicalMessage: cause?.toString() ?? 'Playback operation failed',
      context: {'operation': context},
      cause: cause,
      stackTrace: stackTrace,
      retryable: true,
    );
  }

  factory AppError.microphoneInitFailed({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'microphone.init_failed',
      source: AppErrorSource.microphone,
      severity: AppErrorSeverity.error,
      userMessage: '无法启动麦克风，请检查权限或是否被其他应用占用。',
      technicalMessage: cause?.toString() ?? 'Microphone initialization failed',
      cause: cause,
      stackTrace: stackTrace,
      retryable: true,
    );
  }

  factory AppError.microphonePermissionDenied({required String status}) {
    final permanentlyDenied = status == 'permanentlyDenied';
    final restricted = status == 'restricted';
    return AppError(
      code: 'permission.microphone_denied',
      source: AppErrorSource.permission,
      severity: AppErrorSeverity.warning,
      userMessage: restricted
          ? '麦克风访问受系统限制，无法开启跟随模式。'
          : permanentlyDenied
          ? '麦克风权限已关闭，请在系统设置中允许访问。'
          : '需要麦克风权限才能开启跟随模式。',
      technicalMessage: 'Microphone permission status: $status',
      context: {'permission': 'microphone', 'status': status},
      retryable: !restricted,
    );
  }

  factory AppError.followModeFailed({
    required String message,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'follow.start_failed',
      source: AppErrorSource.followMode,
      severity: AppErrorSeverity.error,
      userMessage: message,
      technicalMessage: cause?.toString() ?? message,
      cause: cause,
      stackTrace: stackTrace,
      retryable: true,
    );
  }

  factory AppError.followRuntimeFailed({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return AppError(
      code: 'follow.runtime_failed',
      source: AppErrorSource.followMode,
      severity: AppErrorSeverity.error,
      userMessage: '跟随模式已停止：麦克风输入或音高检测发生异常。',
      technicalMessage: cause?.toString() ?? 'Follow mode runtime failed',
      cause: cause,
      stackTrace: stackTrace,
      retryable: true,
    );
  }

  factory AppError.unhandled(Object error, StackTrace stackTrace) {
    return AppError(
      code: 'app.unhandled',
      source: AppErrorSource.unknown,
      severity: AppErrorSeverity.fatal,
      userMessage: '应用遇到未预期错误。',
      technicalMessage: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'code': code,
    'source': source.name,
    'severity': severity.name,
    'userMessage': userMessage,
    'technicalMessage': _sanitizeText(technicalMessage),
    'context': _sanitizeContext(context),
    'retryable': retryable,
    if (cause != null) 'cause': _sanitizeText(cause.toString()),
    if (stackTrace != null) 'stackTrace': stackTrace.toString(),
  };

  String toExportText() => const JsonEncoder.withIndent('  ').convert(toJson());

  @override
  String toString() => '$code: $userMessage';
}

class MidiParseException implements Exception {
  final AppError error;

  const MidiParseException(this.error);

  @override
  String toString() => error.userMessage;
}

Map<String, Object?> _sanitizeContext(Map<String, Object?> context) {
  return context.map((key, value) {
    if (value is String && key.toLowerCase().contains('path')) {
      return MapEntry(key, _basename(value));
    }
    if (value is String) {
      return MapEntry(key, _sanitizeText(value));
    }
    return MapEntry(key, value);
  });
}

String _sanitizeText(String value) {
  return value.replaceAll(RegExp(r'/[^\s:]+/([^/\s]+)'), r'.../$1');
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/').where((part) => part.isNotEmpty);
  return segments.isEmpty ? path : segments.last;
}
