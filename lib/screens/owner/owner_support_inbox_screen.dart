import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerSupportInboxScreen extends StatelessWidget {
  const OwnerSupportInboxScreen({super.key});

  static const _statuses = [
    'Open',
    'In Progress',
    'Waiting Customer',
    'Resolved',
    'Closed',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('Support Requests'),
      backgroundColor: const Color(0xFFF8F6FC),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Support requests are available to configured support staff and administrators.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tickets = snapshot.data!.docs;
        if (tickets.isEmpty) {
          return const Center(child: Text('No support requests yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _SupportRequestCard(
              ticketId: ticket.id,
              data: ticket.data(),
              onTap: () => _editTicket(
                context,
                ticketId: ticket.id,
                data: ticket.data(),
              ),
            );
          },
        );
      },
    ),
  );

  static Future<void> _editTicket(
    BuildContext context, {
    required String ticketId,
    required Map<String, dynamic> data,
  }) async {
    final responseController = TextEditingController(
      text: data['response']?.toString() ?? '',
    );
    var status = _statuses.contains(data['status'])
        ? data['status'].toString()
        : 'Open';
    var saving = false;
    var error = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data['subject']?.toString() ?? 'Support request',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${data['customerName'] ?? 'Customer'} · ${data['category'] ?? 'Other'}',
                  style: const TextStyle(color: Color(0xFF777286)),
                ),
                if ((data['linkedOrderId']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('Order: ${data['linkedOrderId']}'),
                ],
                const SizedBox(height: 14),
                SelectableText(data['message']?.toString() ?? ''),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: ValueKey(status),
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: _statuses
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setSheetState(() => status = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: responseController,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Reply to customer',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(error, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() {
                              saving = true;
                              error = '';
                            });
                            try {
                              await FirebaseFirestore.instance
                                  .collection('support_tickets')
                                  .doc(ticketId)
                                  .update({
                                    'status': status,
                                    'response': responseController.text.trim(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                    'resolvedAt':
                                        status == 'Resolved' ||
                                            status == 'Closed'
                                        ? FieldValue.serverTimestamp()
                                        : null,
                                  });
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (_) {
                              if (sheetContext.mounted) {
                                setSheetState(() {
                                  saving = false;
                                  error =
                                      'Could not update this request. Check support access and retry.';
                                });
                              }
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving…' : 'Save update'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    responseController.dispose();
  }
}

class _SupportRequestCard extends StatelessWidget {
  const _SupportRequestCard({
    required this.ticketId,
    required this.data,
    required this.onTap,
  });

  final String ticketId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['subject']?.toString() ?? 'Support request',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _AdminStatusChip(status: data['status']?.toString() ?? 'Open'),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${data['customerName'] ?? 'Customer'} · ${data['category'] ?? 'Other'}',
              style: const TextStyle(color: Color(0xFF777286), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              data['message']?.toString() ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.assignment_ind_outlined, size: 16),
                const SizedBox(width: 5),
                Text(
                  'Queue: ${data['assignedTeam'] ?? 'customer_support'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                Text(
                  ticketId.length > 8 ? ticketId.substring(0, 8) : ticketId,
                  style: const TextStyle(
                    color: Color(0xFF777286),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AdminStatusChip extends StatelessWidget {
  const _AdminStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF5B35D5).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: Color(0xFF5B35D5),
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
