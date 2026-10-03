/// Shared dialog helpers for restricted vs force delete.
library;

import 'package:flutter/material.dart';
import '../l10n/admin_strings.dart';

Future<bool?> confirmRestrictedDelete({
  required BuildContext context,
  required String title,
  required String entityName,
  required String restrictionMessage,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        'Delete "$entityName"?\n\n'
        'Warning: $restrictionMessage',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(adminText(context, 'Cancel', 'إلغاء')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(adminText(context, 'Delete', 'حذف')),
        ),
      ],
    ),
  );
}

Future<bool?> confirmForceDelete({
  required BuildContext context,
  required String title,
  required String entityName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        'Force-delete "$entityName" as super admin?\n\n'
        'This removes related readings and links without the usual restrictions.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(adminText(context, 'Cancel', 'إلغاء')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(adminText(context, 'Force delete', 'حذف إجباري')),
        ),
      ],
    ),
  );
}
