import 'dart:convert';

/// Stable fingerprint for import file idempotency (no external crypto dep).
String computeImportFileFingerprint({
  required String fileName,
  required List<int> bytes,
  String? organizationId,
}) {
  final contentHash = _fnv1aHex(bytes);
  final org = organizationId ?? '';
  return _fnv1aHex(utf8.encode('$org|$fileName|$contentHash'));
}

String computeImportContentFingerprint(String content) {
  return _fnv1aHex(utf8.encode(content));
}

String _fnv1aHex(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
