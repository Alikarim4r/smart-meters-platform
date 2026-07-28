import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/efficiency_meters_policy_section.dart';
import '../widgets/report_logo_slots_editor.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  PolicySettings? _draft;
  bool _saving = false;
  bool _dirty = false;

  void _ensureDraft(PolicySettings settings) {
    if (_draft == null || !_dirty) {
      _draft = settings;
    }
  }

  void _updateDraft(PolicySettings Function(PolicySettings current) updater) {
    final current = _draft;
    if (current == null) return;
    setState(() {
      _draft = updater(current);
      _dirty = true;
    });
  }

  Future<void> _save(String organizationId, AdminStrings s) async {
    final draft = _draft;
    if (draft == null) return;

    final validation = validatePolicySettings(draft);
    if (!validation.isValid) {
      _showMessage(validation.blockingMessage ?? 'Invalid policy settings.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(policySettingsRepositoryProvider)
          .updateOrganizationPolicySettings(draft);
      ref.invalidate(organizationPolicyProvider(organizationId));
      setState(() {
        _dirty = false;
        _saving = false;
      });
      _showMessage(s.settingsSaved);
    } catch (error) {
      setState(() => _saving = false);
      _showMessage('Failed to save settings: $error');
    }
  }

  Future<void> _reset(String organizationId, AdminStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.resetDefaultsTitle),
        content: Text(s.resetDefaultsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.reset),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final reset = await ref
          .read(policySettingsRepositoryProvider)
          .resetToDefaults(organizationId);
      ref.invalidate(organizationPolicyProvider(organizationId));
      setState(() {
        _draft = reset;
        _dirty = false;
        _saving = false;
      });
      _showMessage(s.settingsResetDone);
    } catch (error) {
      setState(() => _saving = false);
      _showMessage('Failed to reset settings: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManagePolicySettingsProvider);
    final canEditPrimaryLogo = ref.watch(canEditReportLogoPrimaryProvider);
    final canEditSecondaryLogo = ref.watch(canEditReportLogoSecondaryProvider);
    final canSaveLogos = canEditPrimaryLogo || canEditSecondaryLogo;
    final orgsAsync = ref.watch(adminOrganizationsProvider);
    final selectedOrgId = ref.watch(selectedPolicyOrganizationIdProvider);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      primary: false,
      body: SafeArea(
        top: false,
        child: orgsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Failed to load organizations: $error')),
          data: (organizations) {
            if (organizations.isEmpty) {
              return const Center(child: Text('No organizations available.'));
            }

            final orgId = selectedOrgId ?? organizations.first.id;
            if (selectedOrgId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(selectedPolicyOrganizationIdProvider.notifier).state =
                    orgId;
              });
            }

            final policyAsync = ref.watch(organizationPolicyProvider(orgId));
            return policyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Failed to load policy settings: $error')),
              data: (settings) {
                _ensureDraft(settings);
                final draft = _draft ?? settings;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      s.policyIntro,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: orgId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: s.organization,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final org in organizations)
                          DropdownMenuItem(
                            value: org.id,
                            child: Text(
                              org.nameEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _draft = null;
                          _dirty = false;
                        });
                        ref
                                .read(
                                  selectedPolicyOrganizationIdProvider.notifier,
                                )
                                .state =
                            value;
                      },
                    ),
                    if (!canManage)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Chip(label: Text(s.readOnlySuperAdmin)),
                      ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: s.readingPolicy,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.allowLateReadings),
                          subtitle: Text(s.allowLateReadingsHint),
                          value: draft.allowLateReadings,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) => current.copyWith(
                                    allowLateReadings: value,
                                  ),
                                )
                              : null,
                        ),
                        _TextFieldTile(
                          label: s.dailyCutoff,
                          hint: s.cutoffHint,
                          value: draft.dailyReadingCutoffTime,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              dailyReadingCutoffTime: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                              clearDailyReadingCutoffTime: value.trim().isEmpty,
                            ),
                          ),
                        ),
                        // Informational rows: these two rules are fixed by
                        // design (not per-organization switches). Backdating
                        // is granted per user from the Users tab.
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.backdatePerUser),
                          subtitle: Text(s.backdatePerUserHint),
                          trailing: const Icon(Icons.people_outline, size: 18),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.correctionReason),
                          subtitle: Text(s.correctionReasonHint),
                          trailing: const Icon(Icons.info_outline, size: 18),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.photoPolicy,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.photoRequired),
                          subtitle: Text(s.photoRequiredHint),
                          value: draft.photoRequired,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) =>
                                      current.copyWith(photoRequired: value),
                                )
                              : null,
                        ),
                        DropdownButtonFormField<MissingPhotoSeverity>(
                          initialValue: draft.missingPhotoSeverity,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.missingPhotoSeverity,
                            border: const OutlineInputBorder(),
                          ),
                          items: MissingPhotoSeverity.values
                              .map(
                                (severity) => DropdownMenuItem(
                                  value: severity,
                                  child: Text(
                                    severity.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: canManage
                              ? (value) {
                                  if (value == null) return;
                                  _updateDraft(
                                    (current) => current.copyWith(
                                      missingPhotoSeverity: value,
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.alertThresholds,
                      children: [
                        _NumberField(
                          label: s.highConsumptionMultiplier,
                          value: draft.highConsumptionMultiplier,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              highConsumptionMultiplier: value,
                            ),
                          ),
                        ),
                        _NumberField(
                          label: s.criticalHighConsumptionMultiplier,
                          value: draft.highConsumptionCriticalMultiplier,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              highConsumptionCriticalMultiplier: value,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.zeroConsumptionAlert),
                          value: draft.zeroConsumptionAlertEnabled,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) => current.copyWith(
                                    zeroConsumptionAlertEnabled: value,
                                  ),
                                )
                              : null,
                        ),
                        _IntField(
                          label: s.leakWarningDays,
                          value: draft.possibleLeakDaysWarning,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              possibleLeakDaysWarning: value,
                            ),
                          ),
                        ),
                        _IntField(
                          label: s.leakCriticalDays,
                          value: draft.possibleLeakDaysCritical,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              possibleLeakDaysCritical: value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.completionTargets,
                      children: [
                        _NumberField(
                          label: s.warningBelowPercent,
                          value: draft.lowCompletionWarningPercent,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              lowCompletionWarningPercent: value,
                            ),
                          ),
                        ),
                        _NumberField(
                          label: s.criticalBelowPercent,
                          value: draft.lowCompletionCriticalPercent,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              lowCompletionCriticalPercent: value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.copPolicy,
                      children: [
                        _NumberField(
                          label: s.lowCopWarning,
                          value: draft.lowCopWarningThreshold,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) =>
                                current.copyWith(lowCopWarningThreshold: value),
                          ),
                        ),
                        _NumberField(
                          label: s.lowCopCritical,
                          value: draft.lowCopCriticalThreshold,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              lowCopCriticalThreshold: value,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.copMissingDataAlert),
                          value: draft.copMissingDataAlertEnabled,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) => current.copyWith(
                                    copMissingDataAlertEnabled: value,
                                  ),
                                )
                              : null,
                        ),
                        EfficiencyMetersPolicySection(
                          organizationId: orgId,
                          enabled: canManage,
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.reportSettings,
                      children: [
                        _TextFieldTile(
                          label: s.reportFooterText,
                          value: draft.reportFooterText,
                          enabled: canManage,
                          maxLines: 2,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              reportFooterText: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                              clearReportFooterText: value.trim().isEmpty,
                            ),
                          ),
                        ),
                        _TextFieldTile(
                          label: s.orgDisplayName,
                          value: draft.organizationDisplayName,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              organizationDisplayName: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                              clearOrganizationDisplayName: value
                                  .trim()
                                  .isEmpty,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.includeAlertsDefault),
                          value: draft.includeAlertSectionDefault,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) => current.copyWith(
                                    includeAlertSectionDefault: value,
                                  ),
                                )
                              : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.includePhotoDefault),
                          value: draft.includePhotoIndicatorDefault,
                          onChanged: canManage
                              ? (value) => _updateDraft(
                                  (current) => current.copyWith(
                                    includePhotoIndicatorDefault: value,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    _SectionCard(
                      title: s.brandingBasics,
                      children: [
                        _TextFieldTile(
                          label: s.orgDisplayName,
                          value: draft.organizationDisplayName,
                          enabled: canManage,
                          onChanged: (value) => _updateDraft(
                            (current) => current.copyWith(
                              organizationDisplayName: value.trim().isEmpty
                                  ? null
                                  : value.trim(),
                              clearOrganizationDisplayName: value
                                  .trim()
                                  .isEmpty,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ReportLogoSlotsEditor(
                          organizationId: orgId,
                          draft: draft,
                          enabled: canManage || canSaveLogos,
                          canEditPrimary: canEditPrimaryLogo,
                          canEditSecondary: canEditSecondaryLogo,
                          onChanged: (next) {
                            setState(() {
                              _draft = next;
                              _dirty = true;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: (!_dirty ||
                                    _saving ||
                                    !(canManage || canSaveLogos))
                                ? null
                                : () => _save(orgId, s),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_saving ? s.saving : s.saveSettings),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: OutlinedButton(
                            onPressed: (_saving || !canManage)
                                ? null
                                : () => _reset(orgId, s),
                            child: Text(
                              s.resetDefaults,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TextFieldTile extends StatelessWidget {
  const _TextFieldTile({
    required this.label,
    required this.onChanged,
    this.value,
    this.hint,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final String? value;
  final String? hint;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        onChanged: (text) {
          final parsed = double.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}
