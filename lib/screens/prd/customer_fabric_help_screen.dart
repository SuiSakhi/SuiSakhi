import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';

class CustomerFabricHelpScreen extends StatefulWidget {
  const CustomerFabricHelpScreen({super.key, this.orderId});
  final String? orderId;

  @override
  State<CustomerFabricHelpScreen> createState() =>
      _CustomerFabricHelpScreenState();
}

class _CustomerFabricHelpScreenState extends State<CustomerFabricHelpScreen> {
  static const _topics = <String, String>{
    'fabric_estimate': 'Estimate fabric required',
    'fabric_guidance': 'Help identify fabric / width',
    'design_question': 'Ask about a design',
    'helpdesk': 'General helpdesk',
  };

  String _topic = 'fabric_estimate';
  DateTime? _appointmentAt;
  bool _submitting = false;
  String? _message;
  String? _meetingLink;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: _appointmentAt ?? now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _appointmentAt ?? now.add(const Duration(days: 1)),
      ),
    );
    if (time == null || !mounted) return;
    setState(() => _appointmentAt = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    ));
  }

  Future<void> _schedule() async {
    final appointmentAt = _appointmentAt;
    if (appointmentAt == null) {
      setState(() => _message = 'Choose a date and time first.');
      return;
    }
    setState(() { _submitting = true; _message = null; _meetingLink = null; });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('scheduleCustomerFabricConsultation')
          .call<Map<String, dynamic>>({
        'topic': _topic,
        'appointmentAt': appointmentAt.toUtc().toIso8601String(),
        'orderId': widget.orderId,
        'notes': _notes.text.trim(),
      });
      final link = result.data['meetingLink']?.toString() ?? '';
      final partnerInvited = result.data['partnerInvited'] == true;
      if (!mounted) return;
      setState(() {
        _meetingLink = link;
        _message = link.isEmpty
            ? 'Your request was saved. The helpdesk will follow up in the app.'
            : partnerInvited
                ? 'Your video consultation is scheduled. The assigned partner was invited.'
                : 'Your video consultation is scheduled. The link is ready in the app; no assigned partner email was available to invite.';
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message ?? 'Unable to schedule right now.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'Unable to schedule right now. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final appointmentAt = _appointmentAt;
    final appointmentLabel = appointmentAt == null
        ? 'Choose a time'
        : '${MaterialLocalizations.of(context).formatFullDate(appointmentAt)} · '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(appointmentAt))}';
    final requests = uid == null
        ? null
        : FirebaseFirestore.instance
            .collection('customer_consultations').doc(uid)
            .collection('requests').orderBy('appointmentAt', descending: true)
            .limit(10).snapshots();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Fabric & design help')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Book a short video call for fabric width, fabric quantity or design questions. '
            'The estimate is guidance; your Tailor confirms the amount before cutting.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _topic,
            decoration: const InputDecoration(labelText: 'What do you need help with?'),
            items: _topics.entries.map((entry) => DropdownMenuItem(
              value: entry.key, child: Text(entry.value),
            )).toList(),
            onChanged: (value) => setState(() => _topic = value ?? _topic),
          ),
          if (widget.orderId?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text('Related order: ${widget.orderId}',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _chooseTime,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(appointmentLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Question or notes (optional)',
              hintText: 'For example: 44-inch cotton, lined Anarkali',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting ? null : _schedule,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.video_call_outlined),
            label: Text(_submitting ? 'Scheduling…' : 'Schedule video help'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: AppColors.primary)),
          ],
          if (_meetingLink != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(_meetingLink!),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Join call'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final link = _meetingLink!;
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!mounted) return;
                  messenger.showSnackBar(const SnackBar(
                    content: Text('Meeting link copied. You can share it by SMS or WhatsApp.'),
                  ));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy link'),
              ),
            ]),
          ],
          const SizedBox(height: 28),
          const Text('Your consultation requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (requests != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: requests,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const SizedBox.shrink();
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No consultation requests yet.'),
                  );
                }
                return Column(children: [
                  for (final doc in snapshot.data!.docs)
                    _ConsultationCard(data: doc.data()),
                ]);
              },
            ),
        ],
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final link = data['meetingLink']?.toString() ?? '';
    final time = data['appointmentAt'];
    final date = time is Timestamp ? time.toDate().toLocal() : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.video_call_outlined),
        title: Text(data['topicLabel']?.toString() ?? 'Fabric and design help'),
        subtitle: Text(date == null ? 'Request ${data['status'] ?? 'saved'}' :
          '${MaterialLocalizations.of(context).formatFullDate(date)} · '
          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}'),
        trailing: link.isEmpty ? null : IconButton(
          tooltip: 'Join consultation',
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () => launchUrl(Uri.parse(link),
              mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}
