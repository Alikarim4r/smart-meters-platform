import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'import_center_screen.dart';

/// Admin hub for Phase 6 Data & Integrations (flag-gated sections).
class DataIntegrationsHubScreen extends ConsumerStatefulWidget {
  const DataIntegrationsHubScreen({
    super.key,
    required this.organizationId,
    this.siteId,
  });

  final String organizationId;
  final String? siteId;

  @override
  ConsumerState<DataIntegrationsHubScreen> createState() =>
      _DataIntegrationsHubScreenState();
}

class _DataIntegrationsHubScreenState
    extends ConsumerState<DataIntegrationsHubScreen> {
  Map<String, bool> _flags = {
    for (final k in PlatformFeatureFlags.all) k: false,
  };
  bool _loading = true;
  List<Map<String, dynamic>> _sources = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final flags = PlatformFeatureFlagRepository(client);
      final loaded = await flags.loadAll(
        organizationId: widget.organizationId,
        siteId: widget.siteId,
      );
      var sources = <Map<String, dynamic>>[];
      if (loaded[PlatformFeatureFlags.smartMeterSources] == true ||
          loaded[PlatformFeatureFlags.bmsSources] == true ||
          loaded[PlatformFeatureFlags.apiIngestion] == true ||
          loaded[PlatformFeatureFlags.fileImport] == true) {
        sources = await ExternalDataSourceRepository(client)
            .listForOrg(widget.organizationId);
      }
      if (!mounted) return;
      setState(() {
        _flags = loaded;
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _on(String key) => _flags[key] == true;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    final anyOn = _flags.values.any((v) => v);
    if (!anyOn) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Data & Integrations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            'All Phase 6 feature flags are OFF. Mechanical manual entry remains unchanged. '
            'Enable flags in platform_feature_flags to use Import, API, Sources, Jobs, '
            'Notifications, Automation, or AI Assistant.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Data & Integrations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Simple by default — advanced tools on demand. No BMS control.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_on(PlatformFeatureFlags.fileImport))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Import Center'),
              subtitle: const Text(
                'CSV/Excel template → preview → validate → partial accept. No silent write.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Import Center')),
                      body: ImportCenterScreen(
                        organizationId: widget.organizationId,
                        siteId: widget.siteId,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_on(PlatformFeatureFlags.apiIngestion) ||
            _on(PlatformFeatureFlags.smartMeterSources) ||
            _on(PlatformFeatureFlags.bmsSources))
          _tile(
            icon: Icons.hub_outlined,
            title: 'Data Sources',
            subtitle:
                '${_sources.length} configured. Secrets via secret_ref only. Adapters are readiness stubs until vendor-tested.',
          ),
        if (_on(PlatformFeatureFlags.smartMeterSources) ||
            _on(PlatformFeatureFlags.bmsSources))
          _tile(
            icon: Icons.link_outlined,
            title: 'Meter Source Mapping',
            subtitle:
                'Frequency + source priority. Mechanical remains first-class.',
          ),
        if (_on(PlatformFeatureFlags.ingestionJobs))
          _tile(
            icon: Icons.schedule_outlined,
            title: 'Ingestion Jobs',
            subtitle: 'Idempotent runs, bounded retries, dead-letter retention.',
          ),
        if (_on(PlatformFeatureFlags.sourceHealth))
          _tile(
            icon: Icons.monitor_heart_outlined,
            title: 'Source Health',
            subtitle:
                'Healthy / Delayed / Failed / Never Synced. Data Availability Alerts only.',
          ),
        if (_on(PlatformFeatureFlags.automationRules))
          _tile(
            icon: Icons.rule_outlined,
            title: 'Automation Rules',
            subtitle:
                'Admin-only activation. Suggestions only — no confirmed diagnosis or control.',
          ),
        if (_on(PlatformFeatureFlags.notificationCenter))
          _tile(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            subtitle:
                'In-app preferences, severity, read/unread, event-key dedupe.',
          ),
        if (_on(PlatformFeatureFlags.aiAssistant))
          _tile(
            icon: Icons.psychology_outlined,
            title: 'AI Governance',
            subtitle:
                'Grounded summaries with human review. Deterministic fallback if AI unavailable.',
          ),
        if (_on(PlatformFeatureFlags.ocrReadiness))
          _tile(
            icon: Icons.document_scanner_outlined,
            title: 'OCR Readiness',
            subtitle:
                'Suggested Reading → Human Confirm → Saved. Never auto-accepted.',
          ),
        const SizedBox(height: 24),
        Text(
          'Capability matrix and interval analytics are documented metadata in Phase 6; '
          'heavy time-series migration is deferred.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
