import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import 'import_center_screen.dart';
import 'notification_settings_screen.dart';

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
    final s = AdminStrings(ref.watch(adminLocaleProvider));

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
        children: [
          Text(
            s.dataAndIntegrations,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(s.allPhase6FlagsOff),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          s.dataAndIntegrations,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          s.dataAndIntegrationsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (_on(PlatformFeatureFlags.fileImport))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(s.importCenter),
              subtitle: Text(s.importCenterSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(s.importCenter)),
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
            title: s.dataSources,
            subtitle: s.dataSourcesConfigured(_sources.length),
          ),
        if (_on(PlatformFeatureFlags.smartMeterSources) ||
            _on(PlatformFeatureFlags.bmsSources))
          _tile(
            icon: Icons.link_outlined,
            title: s.meterSourceMapping,
            subtitle: s.meterSourceMappingSubtitle,
          ),
        if (_on(PlatformFeatureFlags.ingestionJobs))
          _tile(
            icon: Icons.schedule_outlined,
            title: s.ingestionJobs,
            subtitle: s.ingestionJobsSubtitle,
          ),
        if (_on(PlatformFeatureFlags.sourceHealth))
          _tile(
            icon: Icons.monitor_heart_outlined,
            title: s.sourceHealth,
            subtitle: s.sourceHealthSubtitle,
          ),
        if (_on(PlatformFeatureFlags.automationRules))
          _tile(
            icon: Icons.rule_outlined,
            title: s.automationRules,
            subtitle: s.automationRulesSubtitle,
          ),
        if (_on(PlatformFeatureFlags.notificationCenter))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(s.notificationSettings),
              subtitle: Text(s.notificationSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(s.notificationSettings)),
                      body: const NotificationSettingsScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_on(PlatformFeatureFlags.aiAssistant))
          _tile(
            icon: Icons.psychology_outlined,
            title: s.aiGovernance,
            subtitle: s.aiGovernanceSubtitle,
          ),
        if (_on(PlatformFeatureFlags.ocrReadiness))
          _tile(
            icon: Icons.document_scanner_outlined,
            title: s.ocrReadiness,
            subtitle: s.ocrReadinessSubtitle,
          ),
        const SizedBox(height: 24),
        Text(
          s.capabilityMatrixNote,
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
