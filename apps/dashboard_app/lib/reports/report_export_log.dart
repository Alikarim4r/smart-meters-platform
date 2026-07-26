import 'package:flutter/foundation.dart';

/// Temporary debug logging for the dashboard report export pipeline.
void reportExportLog(String step, String message, {Object? error, StackTrace? stack}) {
  final buffer = StringBuffer('[ReportExport][$step] $message');
  if (error != null) {
    buffer.write(' | error=$error');
  }
  debugPrint(buffer.toString());
  if (stack != null && error != null) {
    debugPrint(stack.toString());
  }
}
