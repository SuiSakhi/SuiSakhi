import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';

class OwnerSupportAccessScreen extends StatelessWidget {
  const OwnerSupportAccessScreen({super.key});

  Future<void> _addPhone(BuildContext context) async {
    var enteredPhone = '+917385872697';
    final rawPhone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Grant Helpdesk access'),
        content: TextFormField(
          keyboardType: TextInputType.phone,
          initialValue: enteredPhone,
          onChanged: (value) => enteredPhone = value,
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            helperText:
                'Use a verified OTP sign-in number. India numbers accept 10 digits.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, enteredPhone),
            child: const Text('Grant access'),
          ),
        ],
      ),
    );
    if (rawPhone == null || !context.mounted) return;
    final phone = AppState.normalizePhoneE164(rawPhone);
    if (phone == null || phone.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid mobile number.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('config').doc('support').set({
        'supportPhones': FieldValue.arrayUnion([phone]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Helpdesk access granted to $phone.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update Helpdesk access. Sign in as a configured Admin and retry.',
          ),
        ),
      );
    }
  }

  Future<void> _removePhone(BuildContext context, String phone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Helpdesk access?'),
        content: Text(
          'The verified phone $phone will no longer be able to open Helpdesk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep access'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseFirestore.instance.collection('config').doc('support').set({
        'supportPhones': FieldValue.arrayRemove([phone]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Helpdesk access removed from $phone.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove Helpdesk access.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('Helpdesk Access'),
      backgroundColor: const Color(0xFFF8F6FC),
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('config')
          .doc('support')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Admin access is required to manage Helpdesk staff.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final numbers =
            (snapshot.data?.data()?['supportPhones'] as List<dynamic>? ??
                    const [])
                .map((value) => value.toString())
                .toList()
              ..sort();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Only verified phone numbers listed here can open the Helpdesk inbox and inspect customer orders. Admin UID access remains governed separately.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _addPhone(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Grant access to a phone'),
            ),
            const SizedBox(height: 16),
            if (numbers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No Helpdesk phone access has been granted.'),
                ),
              ),
            for (final phone in numbers)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.support_agent_outlined),
                  ),
                  title: Text(phone),
                  subtitle: const Text('Verified-phone Helpdesk access'),
                  trailing: IconButton(
                    tooltip: 'Remove access',
                    onPressed: () => _removePhone(context, phone),
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
