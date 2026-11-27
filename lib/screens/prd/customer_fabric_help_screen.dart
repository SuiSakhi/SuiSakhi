import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../services/customer_support_service.dart';
import '../../services/smart_assist_service.dart';
import '../../widgets/smart_assist/speech_playback_button.dart';

class CustomerFabricHelpScreen extends StatefulWidget {
  const CustomerFabricHelpScreen({
    super.key,
    this.orderId,
    this.initialTopic,
    this.initialQuestion,
  });
  final String? orderId;
  final String? initialTopic;
  final String? initialQuestion;

  @override
  State<CustomerFabricHelpScreen> createState() =>
      _CustomerFabricHelpScreenState();
}

class _CustomerFabricHelpScreenState extends State<CustomerFabricHelpScreen> {
  static const _topics = <String, String>{
    'fabric_estimate': 'Estimate fabric required',
    'fabric_guidance': 'Help identify fabric / width',
    'design_question': 'Ask about a design',
    'measurement_help': 'Measurement and fit help',
    'estimate_help': 'Help with an estimate',
    'helpdesk': 'Other SuiSakhi help',
  };

  late String _topic;
  bool _submitting = false;
  bool _asking = false;
  String? _message;
  String? _ticketId;
  String? _assistantAnswer;
  List<String> _assistantQuestions = const [];
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _topic = _topics.containsKey(widget.initialTopic)
        ? widget.initialTopic!
        : 'fabric_estimate';
    _notes = TextEditingController(text: widget.initialQuestion);
    if (widget.initialQuestion?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askSuiSakhi();
      });
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _askSuiSakhi() async {
    final question = _notes.text.trim();
    if (question.length < 5) {
      setState(
        () => _message = 'Please describe your question in a few words.',
      );
      return;
    }
    setState(() {
      _asking = true;
      _message = null;
      _assistantAnswer = null;
      _assistantQuestions = const [];
    });
    try {
      final result = await SmartAssistService.answerCustomerHelpQuestion(
        question: question,
        topic: _topic,
      );
      if (!mounted) return;
      setState(() {
        if (result.success) {
          _assistantAnswer = result.suggestions
              .map((suggestion) => suggestion.content)
              .where((content) => content.trim().isNotEmpty)
              .join('\n\n');
          _assistantQuestions = result.clarificationQuestions;
          if (_assistantAnswer?.isEmpty == true &&
              _assistantQuestions.isEmpty) {
            _message =
                'I could not prepare an answer. Please try another question.';
          }
        } else {
          _message = result.text;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'SuiSakhi is unable to answer right now. Please try again or send a Helpdesk request.',
      );
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _submitHelpdeskTicket() async {
    final notes = _notes.text.trim();
    if (notes.length < 5) {
      setState(
        () => _message = 'Please describe your question in a few words.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _message = null;
      _ticketId = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final category = switch (_topic) {
        'fabric_estimate' ||
        'fabric_guidance' ||
        'estimate_help' => 'Fabric Issue',
        'design_question' => 'Designer Issue',
        'measurement_help' => 'Measurement Issue',
        _ => 'Other',
      };
      final ticketId = await CustomerSupportService.createTicket(
        customerName:
            AppState.instance.profile?.name ?? user?.displayName ?? 'Customer',
        category: category,
        subject: _topics[_topic] ?? 'Fabric and design help',
        message: notes,
        linkedOrderId: widget.orderId,
        linkedOrderType: widget.orderId?.trim().isNotEmpty == true
            ? 'tailoring'
            : null,
      );
      if (!mounted) return;
      setState(() {
        _ticketId = ticketId;
        _message =
            'Your Helpdesk request was submitted. SuiSakhi will follow up.';
        _notes.clear();
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(
        () => _message =
            error.message ?? 'Unable to submit your request right now.',
      );
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(
        () => _message =
            error.message?.toString() ?? 'Check your question and try again.',
      );
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'Unable to submit your request right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final requests = uid == null
        ? null
        : FirebaseFirestore.instance
              .collection('customer_consultations')
              .doc(uid)
              .collection('requests')
              .orderBy('appointmentAt', descending: true)
              .limit(10)
              .snapshots();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('SuiSakhi Help')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Ask SuiSakhi for quick guidance about measurements, fabric, design '
            'or our services. Account-specific details are checked in your order '
            'screens. If you still need help, send a request to our team.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _topic,
            decoration: const InputDecoration(
              labelText: 'What do you need help with?',
            ),
            items: _topics.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _topic = value ?? _topic),
          ),
          if (widget.orderId?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Related order: ${widget.orderId}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) {
              if (_assistantAnswer != null) {
                setState(() {
                  _assistantAnswer = null;
                  _assistantQuestions = const [];
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Ask SuiSakhi a question',
              hintText: 'For example: How do I prepare for a fitting?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _asking ? null : _askSuiSakhi,
            icon: _asking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_asking ? 'Preparing an answer…' : 'Ask SuiSakhi'),
          ),
          if (_topic == 'fabric_estimate' || _topic == 'estimate_help')
            TextButton.icon(
              onPressed: () => context.push('/fabric-estimation'),
              icon: const Icon(Icons.straighten_rounded),
              label: const Text('Open AI Measurement & Fabric Estimation'),
            ),
          if (_assistantAnswer?.isNotEmpty == true ||
              _assistantQuestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'SuiSakhi’s answer',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SpeechPlaybackButton(
                          text: [
                            if (_assistantAnswer?.trim().isNotEmpty == true)
                              _assistantAnswer!.trim(),
                            ..._assistantQuestions,
                          ].join('\n\n'),
                        ),
                      ],
                    ),
                    if (_assistantAnswer?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(_assistantAnswer!),
                    ],
                    for (final question in _assistantQuestions) ...[
                      const SizedBox(height: 8),
                      Text(question),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: const TextStyle(color: AppColors.primary)),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _submitting || _asking ? null : _submitHelpdeskTicket,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.support_agent_outlined),
            label: Text(
              _submitting ? 'Submitting…' : 'Still need help? Send to Helpdesk',
            ),
          ),
          if (_ticketId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ticket #$_ticketId',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/customer-help-support'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View Help & Support'),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Past video consultation requests',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
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
                return Column(
                  children: [
                    for (final doc in snapshot.data!.docs)
                      _ConsultationCard(data: doc.data()),
                  ],
                );
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
        subtitle: Text(
          date == null
              ? 'Request ${data['status'] ?? 'saved'}'
              : '${MaterialLocalizations.of(context).formatFullDate(date)} · '
                    '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}',
        ),
        trailing: link.isEmpty
            ? null
            : IconButton(
                tooltip: 'Join consultation',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => launchUrl(
                  Uri.parse(link),
                  mode: LaunchMode.externalApplication,
                ),
              ),
      ),
    );
  }
}
