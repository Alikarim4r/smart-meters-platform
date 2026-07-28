import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';

/// Policy-settings block: pick site cooling + electricity meters for COP/EER.
class EfficiencyMetersPolicySection extends ConsumerStatefulWidget {
  const EfficiencyMetersPolicySection({
    super.key,
    required this.organizationId,
    required this.enabled,
  });

  final String organizationId;
  final bool enabled;

  @override
  ConsumerState<EfficiencyMetersPolicySection> createState() =>
      _EfficiencyMetersPolicySectionState();
}

class _EfficiencyMetersPolicySectionState
    extends ConsumerState<EfficiencyMetersPolicySection> {
  String? _siteId;
  CopGroupDetail? _loadedGroup;
  final Set<String> _btuIds = {};
  final Set<String> _elecIds = {};
  bool _loading = false;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSite());
  }

  Future<void> _bootstrapSite() async {
    final sites = await ref.read(adminSitesProvider.future);
    final orgSites =
        sites.where((s) => s.organizationId == widget.organizationId).toList();
    if (orgSites.isEmpty) return;
    final preferred = ref.read(selectedAdminSiteIdProvider);
    final siteId = (preferred != null &&
            orgSites.any((s) => s.id == preferred))
        ? preferred
        : orgSites.first.id;
    await _selectSite(siteId);
  }

  Future<void> _selectSite(String siteId) async {
    setState(() {
      _siteId = siteId;
      _loading = true;
      _status = null;
      _btuIds.clear();
      _elecIds.clear();
      _loadedGroup = null;
    });
    try {
      final groups =
          await ref.read(copGroupRepositoryProvider).listForSite(siteId);
      final group = groups.isEmpty
          ? null
          : groups.firstWhere((g) => g.isActive, orElse: () => groups.first);
      if (!mounted) return;
      setState(() {
        _loadedGroup = group;
        if (group != null) {
          _btuIds.addAll(group.btuMeterIds);
          _elecIds.addAll(group.electricityMeterIds);
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = error.toString();
      });
    }
  }

  Future<void> _save(AdminStrings s) async {
    final siteId = _siteId;
    if (siteId == null) return;
    if (_btuIds.isEmpty || _elecIds.isEmpty) {
      setState(() => _status = s.copGroupNeedsBothMeterTypes);
      return;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final saved = await ref.read(copGroupRepositoryProvider).upsert(
            CopGroupUpsertInput(
              id: _loadedGroup?.id,
              siteId: siteId,
              nameEn: _loadedGroup?.nameEn ?? 'Plant efficiency (COP/EER)',
              nameAr: _loadedGroup?.nameAr ?? 'كفاءة المحطة (COP/EER)',
              description: _loadedGroup?.description ??
                  'Cooling meters ÷ electricity meters for COP and EER',
              isActive: true,
              btuMeterIds: _btuIds.toList(),
              electricityMeterIds: _elecIds.toList(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _loadedGroup = saved;
        _saving = false;
        _status = s.efficiencyMetersSaved;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final sitesAsync = ref.watch(adminSitesProvider);
    final metersAsync =
        _siteId == null ? null : ref.watch(siteMetersProvider(_siteId!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 28),
        Text(
          s.efficiencyMetersPolicy,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          s.efficiencyMetersPolicyHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          s.copEerFormulaHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        sitesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(e.toString()),
          data: (sites) {
            final orgSites = sites
                .where((site) => site.organizationId == widget.organizationId)
                .toList();
            if (orgSites.isEmpty) {
              return Text(s.noSitesForOrg);
            }
            final siteId = _siteId ?? orgSites.first.id;
            return DropdownButtonFormField<String>(
              initialValue: orgSites.any((x) => x.id == siteId)
                  ? siteId
                  : orgSites.first.id,
              decoration: InputDecoration(labelText: s.site),
              items: [
                for (final site in orgSites)
                  DropdownMenuItem(
                    value: site.id,
                    child: Text(site.nameEn),
                  ),
              ],
              onChanged: widget.enabled
                  ? (value) {
                      if (value != null) _selectSite(value);
                    }
                  : null,
            );
          },
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (metersAsync != null)
          metersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
            data: (meters) {
              final btuMeters = meters
                  .where(
                    (m) =>
                        m.categoryConfig?.supportsCopOutput == true ||
                        m.category == MeterCategory.btu,
                  )
                  .toList();
              final elecMeters = meters
                  .where(
                    (m) =>
                        m.categoryConfig?.supportsElectricInput == true ||
                        m.category == MeterCategory.electricity,
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.copCoolingMeters,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    s.copCoolingMetersHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (btuMeters.isEmpty)
                    Text(s.noBtuMetersForCop)
                  else
                    ...btuMeters.map(
                      (meter) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _btuIds.contains(meter.id),
                        onChanged: widget.enabled
                            ? (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _btuIds.add(meter.id);
                                  } else {
                                    _btuIds.remove(meter.id);
                                  }
                                });
                              }
                            : null,
                        title: Text(s.isAr ? meter.nameAr : meter.nameEn),
                        subtitle: Text('${meter.meterCode} · ${meter.baseUnit}'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    s.copElectricityMeters,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    s.copElectricityMetersHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (elecMeters.isEmpty)
                    Text(s.noElectricityMetersForCop)
                  else
                    ...elecMeters.map(
                      (meter) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _elecIds.contains(meter.id),
                        onChanged: widget.enabled
                            ? (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _elecIds.add(meter.id);
                                  } else {
                                    _elecIds.remove(meter.id);
                                  }
                                });
                              }
                            : null,
                        title: Text(s.isAr ? meter.nameAr : meter.nameEn),
                        subtitle: Text('${meter.meterCode} · ${meter.baseUnit}'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.tonal(
                      onPressed:
                          widget.enabled && !_saving ? () => _save(s) : null,
                      child: Text(_saving ? s.saving : s.saveEfficiencyMeters),
                    ),
                  ),
                ],
              );
            },
          ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ],
    );
  }
}
