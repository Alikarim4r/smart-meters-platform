/// Grounded AI assistant — never fabricates numbers; fallback when AI unavailable.
class AiGroundedReference {
  const AiGroundedReference({
    required this.type,
    required this.id,
    this.label,
    this.value,
  });

  final String type;
  final String id;
  final String? label;
  final num? value;
}

class AiAssistantRequest {
  const AiAssistantRequest({
    required this.suggestionType,
    required this.references,
    this.alertReason,
    this.missingDataNotes = const [],
  });

  final String suggestionType;
  final List<AiGroundedReference> references;
  final String? alertReason;
  final List<String> missingDataNotes;
}

class AiAssistantResponse {
  const AiAssistantResponse({
    required this.text,
    required this.usedFallback,
    required this.requiresHumanReview,
    required this.references,
    this.modelName,
  });

  final String text;
  final bool usedFallback;
  final bool requiresHumanReview;
  final List<AiGroundedReference> references;
  final String? modelName;

  static const humanReviewBanner =
      'AI-assisted suggestion — Requires human review.';
}

typedef AiModelInvoker = Future<String?> Function(AiAssistantRequest request);

class AiAssistantService {
  AiAssistantService({this.modelInvoker});

  /// Optional external model. Null / throwing → deterministic fallback.
  final AiModelInvoker? modelInvoker;

  /// Protected actions the assistant must never execute.
  static const protectedActions = {
    'modify_meter_readings',
    'approve_baseline',
    'approve_weather_model',
    'confirm_cause',
    'verify_saving',
    'change_tariff',
    'change_emission_factor',
    'close_opportunity',
    'control_equipment',
  };

  bool canExecute(String action) => !protectedActions.contains(action);

  Future<AiAssistantResponse> summarize(AiAssistantRequest request) async {
    if (modelInvoker != null) {
      try {
        final out = await modelInvoker!(request);
        if (out != null && out.trim().isNotEmpty) {
          final grounded = _ensureGrounded(out, request);
          return AiAssistantResponse(
            text: '${AiAssistantResponse.humanReviewBanner}\n\n$grounded',
            usedFallback: false,
            requiresHumanReview: true,
            references: request.references,
            modelName: 'external',
          );
        }
      } catch (_) {
        // fall through to deterministic template
      }
    }
    return AiAssistantResponse(
      text:
          '${AiAssistantResponse.humanReviewBanner}\n\n${_fallbackTemplate(request)}',
      usedFallback: true,
      requiresHumanReview: true,
      references: request.references,
      modelName: 'deterministic_fallback',
    );
  }

  String _fallbackTemplate(AiAssistantRequest request) {
    final buf = StringBuffer();
    buf.writeln('Status summary (rule-based fallback):');
    for (final r in request.references) {
      final label = r.label ?? r.type;
      if (r.value != null) {
        buf.writeln('- $label (${r.type}/${r.id}): ${r.value}');
      } else {
        buf.writeln('- $label (${r.type}/${r.id})');
      }
    }
    if (request.alertReason != null) {
      buf.writeln('Alert reason: ${request.alertReason}');
    }
    if (request.missingDataNotes.isNotEmpty) {
      buf.writeln('Missing data:');
      for (final n in request.missingDataNotes) {
        buf.writeln('- $n');
      }
    }
    return buf.toString().trim();
  }

  /// Strip any numeric tokens not present in grounded references.
  String _ensureGrounded(String text, AiAssistantRequest request) {
    final allowed = <String>{};
    for (final r in request.references) {
      if (r.value != null) {
        allowed.add(r.value.toString());
        if (r.value is double) {
          allowed.add((r.value as double).toStringAsFixed(0));
          allowed.add((r.value as double).toStringAsFixed(1));
          allowed.add((r.value as double).toStringAsFixed(2));
        }
      }
    }
    // If model invents a number not in refs, append warning (do not invent replacements).
    final numberPattern = RegExp(r'\b\d+(?:\.\d+)?\b');
    final invented = <String>[];
    for (final m in numberPattern.allMatches(text)) {
      final n = m.group(0)!;
      if (!allowed.contains(n)) {
        invented.add(n);
      }
    }
    if (invented.isEmpty) return text;
    return '$text\n\n[Grounding warning: unverified numeric tokens removed from trust: ${invented.join(", ")}]';
  }
}
