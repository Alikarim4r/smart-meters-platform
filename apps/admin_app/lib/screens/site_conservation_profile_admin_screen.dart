import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteConservationProfileEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  final module = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
  if (!module) return false;
  final benchmarking = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.benchmarking,
    siteId: siteId,
  );
  if (benchmarking) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.intensity,
    siteId: siteId,
  );
});

final _siteConservationProfileProvider = FutureProvider.autoDispose
    .family<SiteConservationProfile?, String>((ref, siteId) {
  return SiteConservationProfileRepository(ref.read(supabaseClientProvider))
      .get(siteId);
});

/// Admin editor for site conservation profile (floor area / occupancy / peer).
class SiteConservationProfileAdminScreen extends ConsumerWidget {
  const SiteConservationProfileAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync =
        ref.watch(_siteConservationProfileEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.isAr ? 'ملف ترشيد الموقع' : 'Site conservation profile',
        ),
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_siteConservationProfileEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'غير مفعّل' : 'Profile editing disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و benchmarking أو intensity.'
                  : 'Enable conservation_module and benchmarking or intensity.',
              icon: Icons.flag_outlined,
            );
          }
          final profileAsync =
              ref.watch(_siteConservationProfileProvider(siteId));
          return profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () =>
                  ref.invalidate(_siteConservationProfileProvider(siteId)),
            ),
            data: (profile) => _ProfileForm(
              siteId: siteId,
              profile: profile,
              canManage: canManage,
            ),
          );
        },
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    required this.siteId,
    required this.profile,
    required this.canManage,
  });

  final String siteId;
  final SiteConservationProfile? profile;
  final bool canManage;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _areaCtrl;
  late final TextEditingController _occCtrl;
  late final TextEditingController _notesCtrl;
  ConservationPeerGroup? _peerGroup;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _areaCtrl = TextEditingController(
      text: p?.floorAreaM2?.toString() ?? '',
    );
    _occCtrl = TextEditingController(
      text: p?.occupancyCount?.toString() ?? '',
    );
    _notesCtrl = TextEditingController(text: p?.profileNotes ?? '');
    _peerGroup = p?.peerGroup;
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _occCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.isAr
                      ? 'بيانات التطبيع (لا تُختلق تلقائياً)'
                      : 'Normalization metadata (never invented)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _areaCtrl,
                  enabled: widget.canManage,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.isAr ? 'مساحة الطابق (م²)' : 'Floor area (m²)',
                    helperText: 'Empty → Normalization Data Missing',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _occCtrl,
                  enabled: widget.canManage,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.isAr ? 'الإشغال' : 'Occupancy count',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ConservationPeerGroup?>(
                  initialValue: _peerGroup,
                  decoration: InputDecoration(
                    labelText: s.isAr ? 'مجموعة الأقران' : 'Peer group',
                  ),
                  items: [
                    DropdownMenuItem<ConservationPeerGroup?>(
                      value: null,
                      child: Text(s.isAr ? 'بدون' : 'None'),
                    ),
                    for (final g in ConservationPeerGroup.values)
                      DropdownMenuItem(
                        value: g,
                        child: Text(g.dbValue),
                      ),
                  ],
                  onChanged: widget.canManage
                      ? (v) => setState(() => _peerGroup = v)
                      : null,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  enabled: widget.canManage,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s.isAr ? 'ملاحظات' : 'Notes',
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.canManage)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(s.isAr ? 'حفظ' : 'Save'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final s = AdminStrings(ref.read(adminLocaleProvider));
    setState(() => _saving = true);
    try {
      final areaText = _areaCtrl.text.trim();
      final occText = _occCtrl.text.trim();
      final area = areaText.isEmpty ? null : double.tryParse(areaText);
      final occ = occText.isEmpty ? null : int.tryParse(occText);
      if (areaText.isNotEmpty && (area == null || area <= 0)) {
        throw ArgumentError('floor_area_m2 must be empty or > 0');
      }
      if (occText.isNotEmpty && (occ == null || occ < 0)) {
        throw ArgumentError('occupancy_count must be empty or >= 0');
      }
      await SiteConservationProfileRepository(
        ref.read(supabaseClientProvider),
      ).upsert(
        siteId: widget.siteId,
        floorAreaM2: area,
        occupancyCount: occ,
        peerGroup: _peerGroup,
        profileNotes:
            _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        updatedBy: ref.read(supabaseClientProvider).auth.currentUser?.id,
      );
      ref.invalidate(_siteConservationProfileProvider(widget.siteId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.isAr ? 'تم الحفظ' : 'Profile saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
