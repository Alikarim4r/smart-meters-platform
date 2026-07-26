import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

/// Toggle + tank dropdown / create-new name field.
class MeterTankDestinationFields extends ConsumerWidget {
  const MeterTankDestinationFields({
    super.key,
    required this.siteId,
    required this.poursIntoTank,
    required this.tankId,
    required this.newTankNameController,
    required this.enabled,
    required this.onPoursChanged,
    required this.onTankIdChanged,
  });

  final String siteId;
  final bool poursIntoTank;
  final String? tankId;
  final TextEditingController newTankNameController;
  final bool enabled;
  final ValueChanged<bool> onPoursChanged;
  final ValueChanged<String?> onTankIdChanged;

  static const createNewValue = '__create_new_tank__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final tanksAsync = ref.watch(siteTanksProvider(siteId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.poursIntoTank),
          value: poursIntoTank,
          onChanged: enabled ? onPoursChanged : null,
        ),
        if (poursIntoTank)
          tanksAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (tanks) {
              final knownIds = {for (final tank in tanks) tank.id};
              String? value;
              if (tankId == createNewValue) {
                value = createNewValue;
              } else if (tankId != null && knownIds.contains(tankId)) {
                value = tankId;
              } else if (tanks.isEmpty || tankId == null) {
                value = createNewValue;
              } else {
                // Stale/deleted tank id — fall back to create-new safely.
                value = createNewValue;
              }

              if (tankId != value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onTankIdChanged(value);
                });
              }

              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey('tank-$value-${tanks.length}'),
                    initialValue: value,
                    isExpanded: true,
                    decoration: catalogFieldDecoration(
                      labelText: '${s.tank} *',
                      helperText: s.tankHint,
                    ),
                    items: [
                      for (final tank in tanks)
                        DropdownMenuItem(
                          value: tank.id,
                          child: Text(
                            tank.label(isAr: s.isAr),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      DropdownMenuItem(
                        value: createNewValue,
                        child: Text(
                          s.createNewTank,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: enabled ? onTankIdChanged : null,
                    validator: (v) {
                      if (!poursIntoTank) return null;
                      if (v == null || v.isEmpty) {
                        return s.isAr ? 'الخزان مطلوب' : 'Tank is required';
                      }
                      if (v == createNewValue &&
                          newTankNameController.text.trim().isEmpty) {
                        return s.isAr
                            ? 'أدخل اسم الخزان الجديد'
                            : 'Enter the new tank name';
                      }
                      return null;
                    },
                  ),
                  if (value == createNewValue) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newTankNameController,
                      enabled: enabled,
                      decoration: catalogFieldDecoration(
                        labelText: '${s.newTankName} *',
                        hintText: s.isAr
                            ? 'مثال: خزان السطح'
                            : 'e.g. Roof tank',
                      ),
                      validator: (v) {
                        if (value == createNewValue &&
                            (v == null || v.trim().isEmpty)) {
                          return s.isAr
                              ? 'اسم الخزان مطلوب'
                              : 'Tank name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
