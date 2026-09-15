import 'package:flutter/material.dart';

/// Displays the common confirmation used before creating a new Draft from a
/// rejected Partner application.
Future<bool> showPartnerReapplyDialog({
  required BuildContext context,
  required String partnerLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Apply Again?'),
            content: Text(
              'A new $partnerLabel application will be created using the '
              'applicant-entered information from the rejected application.\n\n'
              'You can review and modify the copied information, save the new '
              'application as a Draft, or submit it for Admin review.\n\n'
              'The rejected application will remain unchanged for audit history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Create New Application'),
              ),
            ],
          );
        },
      ) ??
      false;
}
