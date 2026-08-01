/// OCR readiness: Suggested Reading → Human Confirm → Saved.
enum OcrSuggestionStatus { pendingConfirm, confirmed, rejected, expired }

class OcrSuggestionPolicy {
  const OcrSuggestionPolicy({this.minConfidenceForSuggest = 0.5});

  final double minConfidenceForSuggest;

  bool canAutoSave({required double? confidence}) => false;

  bool canPresentSuggestion({required double? confidence}) {
    if (confidence == null) return true; // still needs human confirm
    return confidence >= minConfidenceForSuggest;
  }

  bool canConfirm({
    required OcrSuggestionStatus status,
    required bool humanConfirmed,
  }) {
    return humanConfirmed && status == OcrSuggestionStatus.pendingConfirm;
  }

  String labelForUi() => 'Suggested Reading — confirm before save';
}
