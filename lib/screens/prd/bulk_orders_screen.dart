import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/prd_catalog.dart';
import '../../services/order_service.dart';
import '../../widgets/common/custom_button.dart';

/// PRD Module 3 — Bulk orders (consultation → quote → milestone tracking).
class BulkOrdersScreen extends StatefulWidget {
  const BulkOrdersScreen({super.key});

  @override
  State<BulkOrdersScreen> createState() => _BulkOrdersScreenState();
}

class _BulkOrdersScreenState extends State<BulkOrdersScreen> {
  BulkOrderKind _kind = BulkOrderKind.weddingPackage;
  final _eventType = TextEditingController();
  int _dressCount = 5;
  String _category = 'Bride';
  final _consult = 'home_visit';
  DateTime _eventDate = DateTime.now().add(const Duration(days: 60));
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  static const _categories = ['Bride', 'Family', 'Kids'];

  @override
  void dispose() {
    _eventType.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d != null) setState(() => _eventDate = d);
  }

  Future<void> _submit() async {
    if (_eventType.text.trim().isEmpty || _location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event type and location are required')),
      );
      return;
    }
    setState(() => _submitting = true);
    final id = await OrderService.createBulkOrderRequest(
      kind: _kind,
      eventType: _eventType.text.trim(),
      dressCount: _dressCount,
      categoryLabel: _category,
      eventDate: _eventDate,
      location: _location.text.trim(),
      consultationPreference: _consult == 'home_visit'
          ? 'Home visit'
          : _consult == 'video'
              ? 'Video consultation'
              : 'Not sure — call me',
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request received. Our team will contact you for consultation & quote.',
          ),
        ),
      );
      context.push('/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a bulk request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bulk Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Package type', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          SegmentedButton<BulkOrderKind>(
            segments: [
              ButtonSegment(
                value: BulkOrderKind.weddingPackage,
                label: Text(BulkOrderKind.weddingPackage.displayName),
              ),
              ButtonSegment(
                value: BulkOrderKind.eventPackage,
                label: Text(BulkOrderKind.eventPackage.displayName),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 20),
          Text('Event type', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _eventType,
            decoration: const InputDecoration(
              hintText: 'e.g. Destination wedding, corporate annual day',
            ),
          ),
          const SizedBox(height: 16),
          Text('Approx. number of outfits', style: AppTextStyles.headlineSmall),
          Row(
            children: [
              IconButton(
                onPressed: _dressCount > 1
                    ? () => setState(() => _dressCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_dressCount', style: AppTextStyles.headlineMedium),
              IconButton(
                onPressed: () => setState(() => _dressCount++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Who is this for?', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 16),
          Text('Event date', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_eventDate.day}/${_eventDate.month}/${_eventDate.year}',
              style: AppTextStyles.titleMedium,
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          Text('Location / city', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              hintText: 'Venue or city for logistics',
            ),
          ),
          const SizedBox(height: 16),
          Text('Consultation', style: AppTextStyles.headlineSmall),
          RadioListTile<String>(
            value: 'home_visit',
            title: const Text('Home visit'),
          ),
          RadioListTile<String>(
            value: 'video',
            title: const Text('Video consultation'),
          ),
          RadioListTile<String>(
            value: 'call',
            title: const Text('Call me to schedule'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional notes',
              hintText: 'Design direction, budget range…',
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _submitting ? 'Sending…' : 'Book consultation request',
            icon: Icons.event_rounded,
            onTap: _submitting ? () {} : _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'Quotation, advance payment, and dedicated tailor are confirmed after consultation (per PRD).',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
