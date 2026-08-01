import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/ingestion/ingestion.dart';

void main() {
  group('PlatformFeatureFlags', () {
    test('all Phase 6 keys present and OFF-by-default semantics', () {
      expect(PlatformFeatureFlags.all, containsAll([
        PlatformFeatureFlags.unifiedIngestion,
        PlatformFeatureFlags.fileImport,
        PlatformFeatureFlags.apiIngestion,
        PlatformFeatureFlags.smartMeterSources,
        PlatformFeatureFlags.bmsSources,
        PlatformFeatureFlags.ingestionJobs,
        PlatformFeatureFlags.sourceHealth,
        PlatformFeatureFlags.notificationCenter,
        PlatformFeatureFlags.automationRules,
        PlatformFeatureFlags.aiAssistant,
        PlatformFeatureFlags.ocrReadiness,
      ]));
      expect(PlatformFeatureFlags.all.length, 11);
    });
  });

  group('ImportValidationService', () {
    const mapping = ImportColumnMapping(
      meterCodeColumn: 'meter_code',
      readingDateColumn: 'reading_date',
      rawValueColumn: 'raw_value',
      unitColumn: 'unit',
      externalIdColumn: 'external_reading_id',
    );
    const meters = {
      'M-1': ImportMeterRef(
        id: 'meter-1',
        code: 'M-1',
        siteId: 'site-a',
        unitCode: 'm3',
      ),
    };
    const svc = ImportValidationService();

    test('valid file rows accepted', () {
      final rows = svc.parseCsv(
        'meter_code,reading_date,raw_value,unit,external_reading_id\n'
        'M-1,2026-07-01,100,m3,ext-1\n',
      );
      final preview = svc.validate(
        headers: ImportValidationService.templateHeaders.take(5).toList(),
        rows: rows,
        mapping: mapping,
        metersByCode: meters,
        expectedSiteId: 'site-a',
      );
      expect(preview.headersValid, isTrue);
      expect(preview.acceptedCount, 1);
      expect(preview.rejectedCount, 0);
    });

    test('invalid headers rejected', () {
      final preview = svc.validate(
        headers: const ['foo', 'bar'],
        rows: const [],
        mapping: mapping,
        metersByCode: meters,
      );
      expect(preview.headersValid, isFalse);
      expect(preview.headerErrors, isNotEmpty);
    });

    test('unknown meter and unit mismatch', () {
      final preview = svc.validate(
        headers: const [
          'meter_code',
          'reading_date',
          'raw_value',
          'unit',
          'external_reading_id',
        ],
        rows: [
          {
            'meter_code': 'NOPE',
            'reading_date': '2026-07-01',
            'raw_value': '1',
            'unit': 'm3',
            'external_reading_id': '',
          },
          {
            'meter_code': 'M-1',
            'reading_date': '2026-07-02',
            'raw_value': '1',
            'unit': 'kWh',
            'external_reading_id': '',
          },
        ],
        mapping: mapping,
        metersByCode: meters,
        expectedSiteId: 'site-a',
      );
      expect(preview.rejectedCount, 2);
      expect(preview.rows.map((r) => r.errorCode), containsAll([
        'unknown_meter',
        'unit_mismatch',
      ]));
    });

    test('duplicate row and cross-site rejection', () {
      final preview = svc.validate(
        headers: const [
          'meter_code',
          'reading_date',
          'raw_value',
          'unit',
          'external_reading_id',
        ],
        rows: [
          {
            'meter_code': 'M-1',
            'reading_date': '2026-07-01',
            'raw_value': '10',
            'unit': 'm3',
            'external_reading_id': 'e1',
          },
          {
            'meter_code': 'M-1',
            'reading_date': '2026-07-01',
            'raw_value': '11',
            'unit': 'm3',
            'external_reading_id': 'e2',
          },
        ],
        mapping: mapping,
        metersByCode: meters,
        expectedSiteId: 'site-b',
      );
      expect(preview.rows.first.errorCode, 'cross_site_rejection');
    });

    test('partial acceptance policy', () {
      final preview = svc.validate(
        headers: const [
          'meter_code',
          'reading_date',
          'raw_value',
          'unit',
          'external_reading_id',
        ],
        rows: [
          {
            'meter_code': 'M-1',
            'reading_date': '2026-07-01',
            'raw_value': '10',
            'unit': 'm3',
            'external_reading_id': '',
          },
          {
            'meter_code': 'NOPE',
            'reading_date': '2026-07-01',
            'raw_value': '10',
            'unit': 'm3',
            'external_reading_id': '',
          },
        ],
        mapping: mapping,
        metersByCode: meters,
        expectedSiteId: 'site-a',
      );
      expect(preview.canCommitPartial, isTrue);
      expect(preview.canCommitAll, isFalse);
      expect(preview.acceptedCount, 1);
      expect(preview.rejectedCount, 1);
    });

    test('file fingerprint stable for same content', () {
      final a = computeImportContentFingerprint('a,b\n1,2\n');
      final b = computeImportContentFingerprint('a,b\n1,2\n');
      final c = computeImportContentFingerprint('a,b\n1,3\n');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('ApiIngestionContract', () {
    const contract = ApiIngestionContract();

    test('validates batch and idempotency', () {
      final req = ApiIngestBatchRequest(
        organizationId: 'org-1',
        sourceSystem: 'partner-a',
        sourceType: 'api',
        idempotencyKey: 'batch-1',
        items: [
          ApiIngestItem(
            meterId: 'm1',
            siteId: 's1',
            readingDate: DateTime(2026, 7, 1),
            rawValue: 12,
          ),
        ],
      );
      expect(contract.validateRequest(req), isEmpty);
      expect(contract.hasIdempotencyKey(req), isTrue);
    });

    test('rejects invalid auth-shaped payloads', () {
      final req = ApiIngestBatchRequest(
        organizationId: '',
        sourceSystem: '',
        sourceType: 'public',
        items: const [],
      );
      final errors = contract.validateRequest(req);
      expect(errors.map((e) => e.code), containsAll([
        'missing_organization',
        'missing_source_system',
        'invalid_source_type',
        'empty_batch',
      ]));
    });

    test('parses mixed RPC results', () {
      final result = contract.parseRpcResponse({
        'accepted': 1,
        'rejected': 1,
        'duplicated': 1,
        'conflicts': 1,
        'results': [
          {'index': 1, 'status': 'accepted', 'reading_id': 'r1'},
          {'index': 2, 'status': 'rejected', 'error': 'site_unauthorized'},
          {'index': 3, 'status': 'duplicated', 'reading_id': 'r0'},
          {'index': 4, 'status': 'conflict', 'error': 'requires_review'},
        ],
      });
      expect(result.accepted, 1);
      expect(result.rejected, 1);
      expect(result.duplicated, 1);
      expect(result.conflicts, 1);
      expect(result.results.length, 4);
    });
  });

  group('ConflictPolicy', () {
    const policy = ConflictPolicy();

    test('identical duplicate — no silent overwrite', () {
      final a = policy.assess(
        existingRawValue: 10,
        existingSource: ReadingSource.manual,
        incomingRawValue: 10,
        incomingSource: ReadingSource.api,
      );
      expect(a.kind, ConflictKind.duplicateIdentical);
      expect(a.silentOverwriteAllowed, isFalse);
    });

    test('manual vs API differing values requires review', () {
      final a = policy.assess(
        existingRawValue: 10,
        existingSource: ReadingSource.manualPhoto,
        incomingRawValue: 12,
        incomingSource: ReadingSource.api,
      );
      expect(a.kind, ConflictKind.manualVsAutomated);
      expect(a.requiresHumanReview, isTrue);
      expect(a.silentOverwriteAllowed, isFalse);
      expect(policy.canAutoSelectCanonical(ConflictResolution.acceptIncoming),
          isFalse);
    });
  });

  group('SourceHealthService', () {
    const svc = SourceHealthService();

    test('never synced and delayed', () {
      expect(
        svc
            .evaluate(const SourceHealthInput(enabled: true))
            .status,
        SourceHealthStatus.neverSynced,
      );
      final delayed = svc.evaluate(SourceHealthInput(
        enabled: true,
        lastDataTimestamp: DateTime.utc(2026, 1, 1),
        expectedFrequency: DataFrequency.daily,
        now: DateTime.utc(2026, 1, 5),
      ));
      expect(delayed.status, SourceHealthStatus.delayed);
      expect(delayed.message, contains('Data Availability'));
      expect(delayed.message, isNot(contains('Equipment Fault')));
    });

    test('disabled and auth required', () {
      expect(
        svc
            .evaluate(const SourceHealthInput(enabled: false))
            .status,
        SourceHealthStatus.disabled,
      );
      expect(
        svc
            .evaluate(const SourceHealthInput(
              enabled: true,
              authenticationRequired: true,
            ))
            .status,
        SourceHealthStatus.authenticationRequired,
      );
    });
  });

  group('NotificationDedupe', () {
    test('suppresses duplicate within cooldown', () {
      final d = NotificationDedupe(cooldown: const Duration(hours: 1));
      final key = d.eventKey(
        notificationType: 'source_delayed',
        organizationId: 'o1',
        siteId: 's1',
        relatedEntityId: 'src1',
      );
      final t0 = DateTime.utc(2026, 7, 1, 10);
      expect(d.shouldEmit(key, now: t0), isTrue);
      expect(d.shouldEmit(key, now: t0.add(const Duration(minutes: 10))), isFalse);
      expect(d.shouldEmit(key, now: t0.add(const Duration(hours: 2))), isTrue);
    });
  });

  group('AutomationRuleEngine', () {
    test('fires once for same firing_key; no diagnosis/control', () {
      final engine = AutomationRuleEngine();
      const rule = AutomationRuleDefinition(
        ruleKey: 'high_anomaly_repeat',
        ruleVersion: 1,
        displayName: 'Repeated high anomaly',
        explanation: 'Suggest opportunity when anomaly repeats',
        minConfidence: 0.7,
        repeatedPeriods: 2,
        enabled: true,
      );
      const ctx = AutomationTriggerContext(
        anomalyHigh: true,
        confidence: 0.9,
        repeatedPeriods: 3,
        meterId: 'm1',
        periodKey: '2026-07',
      );
      final first = engine.evaluate(rule: rule, ctx: ctx);
      final second = engine.evaluate(rule: rule, ctx: ctx);
      expect(first.fired, isTrue);
      expect(first.confirmedDiagnosis, isFalse);
      expect(first.equipmentControl, isFalse);
      expect(second.fired, isFalse);
      expect(second.suppressedReason, 'idempotent_duplicate');
    });

    test('low confidence capped', () {
      final engine = AutomationRuleEngine();
      final result = engine.evaluate(
        rule: const AutomationRuleDefinition(
          ruleKey: 'r',
          ruleVersion: 1,
          displayName: 'r',
          explanation: 'e',
          minConfidence: 0.8,
          repeatedPeriods: 1,
          enabled: true,
        ),
        ctx: const AutomationTriggerContext(
          anomalyHigh: true,
          confidence: 0.5,
          repeatedPeriods: 2,
          meterId: 'm1',
          periodKey: 'p',
        ),
      );
      expect(result.fired, isFalse);
      expect(result.suppressedReason, 'low_confidence');
    });
  });

  group('AiAssistantService', () {
    test('grounded fallback with references; cannot execute protected', () async {
      final ai = AiAssistantService();
      expect(ai.canExecute('verify_saving'), isFalse);
      expect(ai.canExecute('control_equipment'), isFalse);
      expect(ai.canExecute('summarize_status'), isTrue);

      final resp = await ai.summarize(const AiAssistantRequest(
        suggestionType: 'status_summary',
        references: [
          AiGroundedReference(
            type: 'meter',
            id: 'm1',
            label: 'CHW-01',
            value: 1200,
          ),
          AiGroundedReference(
            type: 'baseline',
            id: 'b1',
            label: 'Baseline v2',
            value: 1000,
          ),
          AiGroundedReference(
            type: 'confidence',
            id: 'c1',
            value: 0.82,
          ),
        ],
        missingDataNotes: ['tariff missing → cost N/A'],
      ));
      expect(resp.usedFallback, isTrue);
      expect(resp.requiresHumanReview, isTrue);
      expect(resp.text, contains(AiAssistantResponse.humanReviewBanner));
      expect(resp.text, contains('1200'));
      expect(resp.text, contains('0.82'));
      expect(resp.text, contains('tariff missing'));
    });

    test('unavailable AI uses deterministic fallback', () async {
      final ai = AiAssistantService(
        modelInvoker: (_) async => throw StateError('AI down'),
      );
      final resp = await ai.summarize(const AiAssistantRequest(
        suggestionType: 'alert_explanation',
        references: [
          AiGroundedReference(type: 'alert', id: 'a1', label: 'Delayed source'),
        ],
        alertReason: 'Data Availability — source delayed',
      ));
      expect(resp.usedFallback, isTrue);
      expect(resp.modelName, 'deterministic_fallback');
    });
  });

  group('CapabilityMatrix', () {
    test('mechanical vs interval', () {
      const matrix = CapabilityMatrix();
      expect(
        matrix.isSupported(
          DataFrequency.periodicManual,
          DataCapabilities.periodComparisons,
        ),
        isTrue,
      );
      expect(
        matrix.isSupported(
          DataFrequency.periodicManual,
          DataCapabilities.loadProfile,
        ),
        isFalse,
      );
      expect(
        matrix.isSupported(
          DataFrequency.interval15m,
          DataCapabilities.nightFlow,
        ),
        isTrue,
      );
    });
  });

  group('OCR / adapters / pipeline', () {
    test('OCR never auto-saves', () {
      const policy = OcrSuggestionPolicy();
      expect(policy.canAutoSave(confidence: 0.99), isFalse);
      expect(
        policy.canConfirm(
          status: OcrSuggestionStatus.pendingConfirm,
          humanConfirmed: true,
        ),
        isTrue,
      );
    });

    test('BMS adapter forbids control and does not claim vendor', () async {
      final bms = BmsAdapter();
      expect(bms.allowsEquipmentControl, isFalse);
      final r = await bms.testConnection(const AdapterConfig(
        sourceKey: 'bms-1',
        connectionConfig: {},
      ));
      expect(r.vendorVerified, isFalse);
    });

    test('pipeline stages documented', () {
      const p = UnifiedIngestionPipeline();
      expect(p.stages.first, IngestionStage.adapt);
      expect(p.stages.last, IngestionStage.audit);
      final dry = p.dryRunValidate(IngestionCandidate(
        siteId: 's',
        meterId: 'm',
        readingDate: DateTime(2026, 7, 1),
        rawValue: 1,
        source: ReadingSource.api,
      ));
      expect(dry.every((s) => s.ok), isTrue);
    });
  });

  group('ReadingSource legacy policy', () {
    test('null → legacy', () {
      expect(ReadingSource.resolveLegacySafe(null), ReadingSource.legacy);
      expect(ReadingSource.resolveLegacySafe('manual'), ReadingSource.manual);
    });
  });
}
