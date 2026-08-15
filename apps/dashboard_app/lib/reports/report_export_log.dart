import 'package:flutter/foundation.dart';

DateTime? _reportExportT0;

/// Reset export timing at the start of each export attempt.
void reportExportLogReset() {
  _reportExportT0 = DateTime.now();
}

/// Temporary debug logging for the dashboard report export pipeline.
void reportExportLog(String step, String message, {Object? error, StackTrace? stack}) {
  _reportExportT0 ??= DateTime.now();
  final ms = DateTime.now().difference(_reportExportT0!).inMilliseconds;
  final buffer = StringBuffer('[ReportExport][$step] +${ms}ms $message');
  if (error != null) {
    buffer.write(' | error=$error');
  }
  debugPrint(buffer.toString());
  if (stack != null && error != null) {
    debugPrint(stack.toString());
  }
}
