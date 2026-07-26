/// Sanitize user-facing report text for PDF (Helvetica / WinAnsi) and Excel cells.
String reportText(dynamic value, {String fallback = '-'}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return fallback;
  }
  return text;
}

/// Replace characters that crash or warn in default PDF fonts.
String sanitizePdfText(dynamic value, {String fallback = '-'}) {
  final text = reportText(value, fallback: fallback);
  return text
      .replaceAll('\u2014', '-')
      .replaceAll('\u2013', '-')
      .replaceAll('\u00B3', '3')
      .replaceAll('m³', 'm3')
      .replaceAll('m\u00b3', 'm3')
      .replaceAllMapped(
        RegExp(r'[^\x09\x0A\x0D\x20-\x7E]'),
        (match) => '?',
      );
}

String sanitizeExcelCell(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  final text = value.toString();
  if (text.trim().isEmpty) {
    return fallback;
  }
  return text;
}
