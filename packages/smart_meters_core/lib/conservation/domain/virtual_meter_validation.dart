import '../../models/enums.dart';
import '../../models/meter.dart';

/// Maximum nesting depth for virtual meters (bounded recursion).
const int kVirtualMeterMaxDepth = 8;

enum VirtualMeterValidationSeverity { error, warning }

class VirtualMeterValidationIssue {
  const VirtualMeterValidationIssue({
    required this.code,
    required this.message,
    this.severity = VirtualMeterValidationSeverity.error,
  });

  final String code;
  final String message;
  final VirtualMeterValidationSeverity severity;

  bool get isError => severity == VirtualMeterValidationSeverity.error;
}

class VirtualMeterValidationResult {
  const VirtualMeterValidationResult({
    required this.ok,
    required this.issues,
    this.leafMeterIds = const [],
    this.hierarchyDepth = 0,
  });

  final bool ok;
  final List<VirtualMeterValidationIssue> issues;
  final List<String> leafMeterIds;
  final int hierarchyDepth;

  factory VirtualMeterValidationResult.pass({
    List<String> leafMeterIds = const [],
    int hierarchyDepth = 0,
    List<VirtualMeterValidationIssue> warnings = const [],
  }) =>
      VirtualMeterValidationResult(
        ok: true,
        issues: warnings,
        leafMeterIds: leafMeterIds,
        hierarchyDepth: hierarchyDepth,
      );

  factory VirtualMeterValidationResult.fail(
    List<VirtualMeterValidationIssue> issues,
  ) =>
      VirtualMeterValidationResult(ok: false, issues: issues);
}

/// Pure hierarchy / config validation for virtual meters (defense in depth).
class VirtualMeterValidation {
  const VirtualMeterValidation();

  /// Validate a proposed virtual meter configuration before persist/calc.
  VirtualMeterValidationResult validateConfig({
    required MeterKind meterKind,
    required CalculationType calculationType,
    required String siteId,
    required String categoryId,
    required String unitCode,
    required String? parentMeterId,
    required List<Meter> memberMeters,
    required Map<String, Meter> metersById,
    String? virtualMeterId,
    String? organizationId,
    Map<String, List<String>>? memberIdsByVirtualId,
  }) {
    final issues = <VirtualMeterValidationIssue>[];

    if (meterKind != MeterKind.virtual) {
      issues.add(const VirtualMeterValidationIssue(
        code: 'not_virtual',
        message: 'Meter kind must be virtual.',
      ));
    }

    if (calculationType != CalculationType.sumChildren &&
        calculationType != CalculationType.parentMinusChildren) {
      issues.add(VirtualMeterValidationIssue(
        code: 'invalid_calculation_type',
        message:
            'P1E supports sum_children and parent_minus_children only (got ${calculationType.dbValue}).',
      ));
    }

    if (calculationType == CalculationType.parentMinusChildren &&
        (parentMeterId == null || parentMeterId.isEmpty)) {
      issues.add(const VirtualMeterValidationIssue(
        code: 'parent_required',
        message: 'parent_minus_children requires a parent meter reference.',
      ));
    }

    if (calculationType == CalculationType.sumChildren &&
        parentMeterId != null) {
      // Allowed to be null; warn if set unexpectedly for sum_children.
      issues.add(const VirtualMeterValidationIssue(
        code: 'sum_children_parent_ignored',
        message: 'sum_children ignores parent_meter_id; use members only.',
        severity: VirtualMeterValidationSeverity.warning,
      ));
    }

    if (memberMeters.isEmpty) {
      issues.add(const VirtualMeterValidationIssue(
        code: 'no_members',
        message: 'At least one child/member meter is required.',
      ));
    }

    final seenMembers = <String>{};
    for (final m in memberMeters) {
      if (!seenMembers.add(m.id)) {
        issues.add(VirtualMeterValidationIssue(
          code: 'duplicate_child',
          message: 'Duplicate child meter ${m.id}.',
        ));
      }
      if (virtualMeterId != null && m.id == virtualMeterId) {
        issues.add(const VirtualMeterValidationIssue(
          code: 'self_member',
          message: 'Virtual meter cannot include itself as a member.',
        ));
      }
      if (m.siteId != siteId) {
        issues.add(VirtualMeterValidationIssue(
          code: 'cross_site',
          message: 'Child ${m.meterCode} is on a different site (rejected).',
        ));
      }
      if (m.categoryId != categoryId) {
        issues.add(VirtualMeterValidationIssue(
          code: 'utility_mismatch',
          message:
              'Child ${m.meterCode} category/utility incompatible with virtual meter.',
        ));
      }
      final childUnit = m.baseUnit.isNotEmpty ? m.baseUnit : m.unit.dbValue;
      if (childUnit != unitCode) {
        issues.add(VirtualMeterValidationIssue(
          code: 'unit_mismatch',
          message:
              'Child ${m.meterCode} unit incompatible ($childUnit vs $unitCode).',
        ));
      }
    }

    if (parentMeterId != null) {
      if (virtualMeterId != null && parentMeterId == virtualMeterId) {
        issues.add(const VirtualMeterValidationIssue(
          code: 'self_parent',
          message: 'Meter cannot be parent of itself.',
        ));
      }
      final parent = metersById[parentMeterId];
      if (parent == null) {
        issues.add(const VirtualMeterValidationIssue(
          code: 'parent_missing',
          message: 'Parent meter not found in site catalog.',
        ));
      } else {
        if (parent.siteId != siteId) {
          issues.add(const VirtualMeterValidationIssue(
            code: 'cross_site_parent',
            message: 'Parent meter must be on the same site.',
          ));
        }
        if (parent.categoryId != categoryId) {
          issues.add(const VirtualMeterValidationIssue(
            code: 'utility_mismatch_parent',
            message: 'Parent meter utility/category mismatch.',
          ));
        }
      }
    }

    // Nested expansion / cycle / double-count among virtual members.
    final memberMap = memberIdsByVirtualId ?? const <String, List<String>>{};
    final expansion = expandLeaves(
      rootVirtualId: virtualMeterId ?? '__draft__',
      directMemberIds: memberMeters.map((m) => m.id).toList(),
      metersById: metersById,
      memberIdsByVirtualId: {
        ...memberMap,
        ?virtualMeterId: memberMeters.map((m) => m.id).toList(),
      },
      draftMemberIds: virtualMeterId == null
          ? memberMeters.map((m) => m.id).toList()
          : null,
    );
    issues.addAll(expansion.issues);

    final errors = issues.where((i) => i.isError).toList();
    if (errors.isNotEmpty) {
      return VirtualMeterValidationResult.fail(issues);
    }
    return VirtualMeterValidationResult.pass(
      leafMeterIds: expansion.leafMeterIds,
      hierarchyDepth: expansion.depth,
      warnings: issues.where((i) => !i.isError).toList(),
    );
  }

  /// Expand nested virtual members to physical leaves; detect cycles/dupes.
  ({
    List<String> leafMeterIds,
    int depth,
    List<VirtualMeterValidationIssue> issues,
  }) expandLeaves({
    required String rootVirtualId,
    required List<String> directMemberIds,
    required Map<String, Meter> metersById,
    required Map<String, List<String>> memberIdsByVirtualId,
    List<String>? draftMemberIds,
  }) {
    final issues = <VirtualMeterValidationIssue>[];
    final leaves = <String>[];
    final leafSeen = <String>{};
    var maxDepth = 0;

    void walk(String meterId, Set<String> path, int depth) {
      if (depth > kVirtualMeterMaxDepth) {
        issues.add(VirtualMeterValidationIssue(
          code: 'max_depth',
          message:
              'Virtual hierarchy depth exceeds $kVirtualMeterMaxDepth (bounded recursion).',
        ));
        return;
      }
      if (path.contains(meterId)) {
        issues.add(VirtualMeterValidationIssue(
          code: 'cycle',
          message: 'Circular hierarchy detected at meter $meterId.',
        ));
        return;
      }
      maxDepth = depth > maxDepth ? depth : maxDepth;

      final meter = metersById[meterId];
      final nextPath = {...path, meterId};

      List<String>? childIds;
      if (draftMemberIds != null && meterId == rootVirtualId) {
        childIds = draftMemberIds;
      } else if (meter != null && meter.meterKind == MeterKind.virtual) {
        childIds = memberIdsByVirtualId[meterId];
      }

      if (childIds != null) {
        if (childIds.isEmpty) {
          issues.add(VirtualMeterValidationIssue(
            code: 'empty_nested_virtual',
            message: 'Nested virtual $meterId has no members.',
          ));
          return;
        }
        for (final c in childIds) {
          walk(c, nextPath, depth + 1);
        }
        return;
      }

      // Physical (or unknown) leaf.
      if (!leafSeen.add(meterId)) {
        issues.add(VirtualMeterValidationIssue(
          code: 'duplicate_leaf',
          message:
              'Duplicate leaf $meterId in nested expansion (double-counting risk).',
        ));
        return;
      }
      leaves.add(meterId);
    }

    for (final id in directMemberIds) {
      walk(id, {rootVirtualId}, 1);
    }

    return (leafMeterIds: leaves, depth: maxDepth, issues: issues);
  }
}
