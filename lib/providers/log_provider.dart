import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? details;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

final logProvider = StateNotifierProvider<LogNotifier, List<LogEntry>>((ref) {
  return LogNotifier();
});

class LogNotifier extends StateNotifier<List<LogEntry>> {
  LogNotifier() : super([]);

  void log(String level, String message, {String? details}) {
    state = [
      LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        details: details,
      ),
      ...state,
    ];
    // Keep only last 100 logs
    if (state.length > 100) {
      state = state.sublist(0, 100);
    }
  }

  void info(String message, {String? details}) {
    log('INFO', message, details: details);
  }

  void error(String message, {String? details}) {
    log('ERROR', message, details: details);
  }

  void warning(String message, {String? details}) {
    log('WARN', message, details: details);
  }

  void success(String message, {String? details}) {
    log('SUCCESS', message, details: details);
  }

  void clear() {
    state = [];
  }
}
