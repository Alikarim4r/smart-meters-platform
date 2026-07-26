import '../models/reading_correction_models.dart';

class CorrectionValidationResult {
  const CorrectionValidationResult({
    required this.isValid,
    this.blockingMessage,
    this.requiresLowerThanPreviousConfirm = false,
    this.requiresGreaterThanNextWarning = false,
  });

  final bool isValid;
  final String? blockingMessage;
  final bool requiresLowerThanPreviousConfirm;
  final bool requiresGreaterThanNextWarning;

  bool get canSaveWithConfirmations =>
      isValid ||
      (blockingMessage == null &&
          (requiresLowerThanPreviousConfirm || requiresGreaterThanNextWarning));
}

CorrectionValidationResult validateReadingCorrection({
  required double currentValue,
  required double newValue,
  CorrectionReason? reason,
  String? newNote,
  double? previousValue,
  double? nextValue,
  bool lowerThanPreviousConfirmed = false,
  bool greaterThanNextAcknowledged = false,
}) {
  if (reason == null) {
    return const CorrectionValidationResult(
      isValid: false,
      blockingMessage: 'Correction reason is required.',
    );
  }

  if (newValue == currentValue && (newNote == null || newNote.trim().isEmpty)) {
    return const CorrectionValidationResult(
      isValid: false,
      blockingMessage: 'No changes to save. Enter a new value or note.',
    );
  }

  if (newValue < 0) {
    return const CorrectionValidationResult(
      isValid: false,
      blockingMessage: 'Value must be zero or greater.',
    );
  }

  if (reason == CorrectionReason.other &&
      (newNote == null || newNote.trim().length < 5)) {
    return const CorrectionValidationResult(
      isValid: false,
      blockingMessage: 'A note is required when reason is Other.',
    );
  }

  var requiresLower = false;
  var requiresGreater = false;

  if (previousValue != null && newValue < previousValue) {
    if (!lowerThanPreviousConfirmed) {
      requiresLower = true;
    }
  }

  if (nextValue != null && newValue > nextValue) {
    if (!greaterThanNextAcknowledged) {
      requiresGreater = true;
    }
  }

  if (requiresLower || requiresGreater) {
    return CorrectionValidationResult(
      isValid: false,
      requiresLowerThanPreviousConfirm: requiresLower,
      requiresGreaterThanNextWarning: requiresGreater,
    );
  }

  return const CorrectionValidationResult(isValid: true);
}

String formatCorrectionNote({
  required CorrectionReason reason,
  String? internalComment,
  String? newNote,
}) {
  final parts = <String>['[CORRECTION:${reason.code}]'];
  if (internalComment != null && internalComment.trim().isNotEmpty) {
    parts.add('[ADMIN:${internalComment.trim()}]');
  }
  if (newNote != null && newNote.trim().isNotEmpty) {
    parts.add(newNote.trim());
  }
  return parts.join(' ');
}

CorrectionReason? parseCorrectionReasonFromNote(String? note) {
  if (note == null) return null;
  final match = RegExp(r'\[CORRECTION:(\w+)\]').firstMatch(note);
  if (match == null) return null;
  final code = match.group(1);
  if (code == null) return null;
  for (final reason in CorrectionReason.values) {
    if (reason.code == code) return reason;
  }
  return null;
}

String? stripCorrectionMarkers(String? note) {
  if (note == null) return null;
  var text = note;
  text = text.replaceAll(RegExp(r'\[CORRECTION:\w+\]\s*'), '');
  text = text.replaceAll(RegExp(r'\[ADMIN:[^\]]+\]\s*'), '');
  return text.trim().isEmpty ? null : text.trim();
}

bool notesAreEquivalent(String? a, String? b) {
  return stripCorrectionMarkers(a) == stripCorrectionMarkers(b);
}

bool hasMeaningfulCorrectionChange({
  required double currentValue,
  required double newValue,
  String? currentNote,
  String? newNote,
}) {
  if (newValue != currentValue) return true;
  return !notesAreEquivalent(currentNote, newNote);
}
