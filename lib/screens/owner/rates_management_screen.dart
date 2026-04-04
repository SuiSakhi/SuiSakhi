import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/stitching_rate.dart';

class RatesManagementScreen extends StatefulWidget {
  const RatesManagementScreen({super.key});

  @override
  State<RatesManagementScreen> createState() => _RatesManagementScreenState();
}

class _RatesManagementScreenState extends State<RatesManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stitching Rates'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showRateDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final rates = AppState.instance.rates;
          return Column(
            children: [
              // Info banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Rates set here are visible to all tailors. Tap any rate to edit.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rates.length,
                  separatorBuilder: (context2, i2) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _RateTile(
                    rate: rates[i],
                    onEdit: () => _showRateDialog(context, rate: rates[i]),
                    onDelete: () => _confirmDelete(context, rates[i].dressType),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRateDialog(BuildContext context,
      {StitchingRate? rate}) async {
    final nameCtrl = TextEditingController(text: rate?.dressType ?? '');
    final priceCtrl =
        TextEditingController(text: rate?.basePrice.toStringAsFixed(0) ?? '');
    final notesCtrl = TextEditingController(text: rate?.notes ?? '');
    final isEdit = rate != null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Rate' : 'Add New Rate',
                  style: AppTextStyles.headlineLarge),
              const SizedBox(height: 20),
              if (!isEdit)
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Dress Type',
                    hintText: 'e.g. Kurti, Blouse…',
                    prefixIcon: Icon(Icons.checkroom_rounded),
                  ),
                ),
              if (!isEdit) const SizedBox(height: 14),
              TextFormField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'Price for ${rate.dressType}'
                      : 'Base Price (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Includes lining, Extra for embroidery',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final price = double.tryParse(priceCtrl.text);
                        if (price == null || price <= 0) return;
                        final name =
                            isEdit ? rate.dressType : nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        await AppState.instance.updateRate(name, price,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(isEdit ? 'Save' : 'Add Rate'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, String dressType) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$dressType"?'),
        content: const Text('This will remove the rate for all tailors.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await AppState.instance.deleteRate(dressType);
  }
}

class _RateTile extends StatelessWidget {
  final StitchingRate rate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RateTile(
      {required this.rate, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.checkroom_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rate.dressType, style: AppTextStyles.titleMedium),
                if (rate.notes != null && rate.notes!.isNotEmpty)
                  Text(rate.notes!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            '₹${rate.basePrice.toStringAsFixed(0)}',
            style: AppTextStyles.headlineMedium
                .copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary, size: 20),
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}
