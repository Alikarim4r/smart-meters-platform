import 'dart:convert';

/// Stable fingerprint for import file idempotency (no external crypto dep).
///
/// Uses BigInt so FNV-1a 64-bit constants compile on web (dart2js).
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

final BigInt _fnvOffset = BigInt.parse('cbf29ce484222325', radix: 16);
final BigInt _fnvPrime = BigInt.parse('100000001b3', radix: 16);
final BigInt _u64Mask = BigInt.parse('ffffffffffffffff', radix: 16);

String _fnv1aHex(List<int> bytes) {
  var hash = _fnvOffset;
  for (final b in bytes) {
    hash = (hash ^ BigInt.from(b)) & _u64Mask;
    hash = (hash * _fnvPrime) & _u64Mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
