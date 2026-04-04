import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/prd_catalog.dart';
import '../../services/order_service.dart';
import '../../widgets/common/custom_button.dart';

/// PRD Module 2 — Quick Fix & Essentials (minimal input, fast estimate).
class QuickFixScreen extends StatefulWidget {
  const QuickFixScreen({super.key});

  @override
  State<QuickFixScreen> createState() => _QuickFixScreenState();
}

class _QuickFixScreenState extends State<QuickFixScreen> {
  final Set<String> _selected = {};
  final _notes = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  String _slot = 'Next day — 10am–2pm';
  bool _express = false;
  bool _submitting = false;

  static const _slots = [
    'Same day (Express) — 2pm–6pm',
    'Next day — 10am–2pm',
    'Next day — 2pm–6pm',
    'Choose later (admin will call)',
  ];

  @override
  void dispose() {
    _notes.dispose();
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  double get _estimate {
    if (_selected.isEmpty) return 0;
    var sum = 0.0;
    for (final id in _selected) {
      final s = QuickFixService.byId(id);
      if (s != null) sum += s.midEstimate;
    }
    final visit = 49.0;
    final express = _express || _slot.startsWith('Same day') ? 99.0 : 0.0;
    return sum + visit + express;
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one service')),
      );
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your address')),
      );
      return;
    }
    setState(() => _submitting = true);
    final id = await OrderService.createQuickFixOrder(
      serviceIds: _selected.toList(),
      estimatedTotal: _estimate,
      notes: _notes.text.trim(),
      slotLabel: _slot,
      addressLine: _address.text.trim(),
      landmark: _landmark.text.trim(),
      express: _express || _slot.startsWith('Same day'),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quick Fix request submitted')),
      );
      context.push('/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quick Fix & Essentials'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Services', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Per-task pricing (estimate). Expert visits your doorstep.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QuickFixService.catalog.map((s) {
              final on = _selected.contains(s.id);
              return FilterChip(
                selected: on,
                label: Text(s.title),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selected.add(s.id);
                    } else {
                      _selected.remove(s.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          ...QuickFixService.catalog.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${s.title}: ₹${s.minInr}–${s.maxInr}',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
              ),
            );
          }),
          const SizedBox(height: 20),
          Text('Notes', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Urgency, fabric type, special instructions…',
            ),
          ),
          const SizedBox(height: 20),
          Text('Time slot', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          ..._slots.map((s) {
            return RadioListTile<String>(
              dense: true,
              value: s,
              groupValue: _slot,
              onChanged: (v) => setState(() => _slot = v ?? _slot),
              title: Text(s, style: AppTextStyles.bodyMedium),
            );
          }),
          SwitchListTile(
            value: _express,
            onChanged: (v) => setState(() => _express = v),
            title: const Text('Express fee (+₹99)'),
            subtitle: const Text('Priority scheduling when available'),
          ),
          const SizedBox(height: 12),
          Text('Address', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Home address for doorstep service',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _landmark,
            decoration: const InputDecoration(
              hintText: 'Landmark (optional)',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price estimate', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Services + visit (₹49)${(_express || _slot.startsWith('Same day')) ? ' + express (₹99)' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_estimate.toStringAsFixed(0)}',
                  style: AppTextStyles.headlineMedium.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _submitting ? 'Submitting…' : 'Submit Quick Fix request',
            icon: Icons.bolt_rounded,
            onTap: _submitting ? () {} : _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
