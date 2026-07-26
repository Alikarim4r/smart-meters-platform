import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('validateReadingCorrection', () {
    test('blocks save when reason is missing', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 110,
        reason: null,
      );
      expect(result.isValid, isFalse);
      expect(result.blockingMessage, contains('reason'));
    });

    test('blocks no-change when value and note unchanged', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 100,
        reason: CorrectionReason.wrongReading,
      );
      expect(result.isValid, isFalse);
      expect(result.blockingMessage, contains('No changes'));
    });

    test('requires confirmation when lower than previous', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 80,
        reason: CorrectionReason.wrongReading,
        previousValue: 90,
      );
      expect(result.isValid, isFalse);
      expect(result.requiresLowerThanPreviousConfirm, isTrue);
      expect(result.requiresGreaterThanNextWarning, isFalse);
    });

    test('allows lower than previous after confirmation', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 80,
        reason: CorrectionReason.wrongReading,
        previousValue: 90,
        lowerThanPreviousConfirmed: true,
      );
      expect(result.isValid, isTrue);
    });

    test('warns when greater than next reading', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 150,
        reason: CorrectionReason.wrongReading,
        nextValue: 120,
      );
      expect(result.isValid, isFalse);
      expect(result.requiresGreaterThanNextWarning, isTrue);
    });

    test('allows greater than next after acknowledgement', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 150,
        reason: CorrectionReason.wrongReading,
        nextValue: 120,
        greaterThanNextAcknowledged: true,
      );
      expect(result.isValid, isTrue);
    });

    test('requires note when reason is other', () {
      final result = validateReadingCorrection(
        currentValue: 100,
        newValue: 110,
        reason: CorrectionReason.other,
      );
      expect(result.isValid, isFalse);
      expect(result.blockingMessage, contains('note'));
    });
  });

  group('hasMeaningfulCorrectionChange', () {
    test('detects value change', () {
      expect(
        hasMeaningfulCorrectionChange(currentValue: 10, newValue: 11),
        isTrue,
      );
    });

    test('detects note change only', () {
      expect(
        hasMeaningfulCorrectionChange(
          currentValue: 10,
          newValue: 10,
          currentNote: 'old',
          newNote: 'new',
        ),
        isTrue,
      );
    });
  });

  group('formatCorrectionNote', () {
    test('embeds reason and admin comment markers', () {
      final note = formatCorrectionNote(
        reason: CorrectionReason.clientRequest,
        internalComment: 'verified with client',
        newNote: 'Adjusted per ticket',
      );
      expect(note, contains('[CORRECTION:clientRequest]'));
      expect(note, contains('[ADMIN:verified with client]'));
      expect(note, contains('Adjusted per ticket'));
      expect(
        parseCorrectionReasonFromNote(note),
        CorrectionReason.clientRequest,
      );
    });
  });
}
