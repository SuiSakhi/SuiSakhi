import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Admin view of Partner payouts due or recorded as paid across service lines.
/// Payouts are external transfers; this screen records the net transfer and
/// itemized deductions against the Partner rate-card payable.
class OwnerPartnerPayoutsSection extends StatefulWidget {
  const OwnerPartnerPayoutsSection({super.key});

  @override
  State<OwnerPartnerPayoutsSection> createState() =>
      _OwnerPartnerPayoutsSectionState();
}

class _OwnerPartnerPayoutsSectionState
    extends State<OwnerPartnerPayoutsSection> {
  static final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  List<_PayoutRecord> _records = const [];
  List<_PayoutStatement> _statements = const [];
  String _category = 'all';
  String _status = 'due';
  DateTime _selectedWeekStart = _weekStart(DateTime.now());
  bool _allPendingWeeks = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _db
            .collection('orders')
            .orderBy('orderDate', descending: true)
            .limit(300)
            .get(),
        _db
            .collection('garment_care_partner_payables')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get(),
        _db
            .collection('garment_care_orders')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get(),
        _db
            .collection('partner_payout_transfers')
            .orderBy('paidAt', descending: true)
            .limit(300)
            .get(),
      ]);
      final orders = results[0];
      final payables = results[1];
      final careOrders = results[2];
      final payoutTransfers = results[3];
      final careById = {for (final doc in careOrders.docs) doc.id: doc.data()};
      final records = <_PayoutRecord>[];

      for (final doc in orders.docs) {
        final data = doc.data();
        final module = data['orderModuleType']?.toString();
        if (module == 'coreTailoring' &&
            data['paymentStatus'] == 'fullyPaid' &&
            (data['partnerPayoutStatus'] == 'paid' ||
                ['delivered', 'closed'].contains(data['status']))) {
          final amount =
              (data['stitchingBaseCharge'] as num?)?.toDouble() ??
              (data['partnerPayoutGrossAmount'] as num?)?.toDouble() ??
              (data['partnerPayoutAmount'] as num?)?.toDouble() ??
              0;
          if (amount <= 0) continue;
          records.add(
            _PayoutRecord(
              id: doc.id,
              category: 'tailoring',
              categoryLabel: 'Stitching',
              orderLabel: _orderLabel(doc.id, data),
              partnerName: _partnerLabel(
                data['partnerPayoutPartnerName'] ??
                    data['assignedTailorName'] ??
                    data['tailorName'],
                data['assignedTailorAccountId'],
                'Tailor',
              ),
              partnerAccountId:
                  (data['assignedTailorAccountId'] ??
                          data['partnerPayoutPartnerAccountId'])
                      ?.toString(),
              amount: amount,
              completedAt:
                  _date(data['deliveredAt']) ??
                  _date(data['closedAt']) ??
                  _date(data['updatedAt']) ??
                  _date(data['orderDate']),
              isPaid: data['partnerPayoutStatus'] == 'paid',
              paidAmount:
                  (data['partnerPayoutNetAmount'] as num?)?.toDouble() ??
                  (data['partnerPayoutAmount'] as num?)?.toDouble(),
              deductions: _readDeductions(data['partnerPayoutDeductions']),
              reference: data['partnerPayoutReference']?.toString(),
            ),
          );
        } else if (module == 'quickFix' &&
            data['paymentStatus'] == 'fullyPaid' &&
            data['quickCareWorkflowStatus'] == 'completed') {
          final amount =
              (data['quickCarePartnerPayoutAmount'] as num?)?.toDouble() ??
              (data['quickCarePartnerPayoutEstimate'] as num?)?.toDouble() ??
              (data['partnerPayoutGrossAmount'] as num?)?.toDouble() ??
              (data['partnerPayoutAmount'] as num?)?.toDouble() ??
              0;
          if (amount <= 0) continue;
          records.add(
            _PayoutRecord(
              id: doc.id,
              category: 'quickCare',
              categoryLabel: 'Quick Care & Home Services',
              orderLabel: _orderLabel(doc.id, data),
              partnerName: _partnerLabel(
                data['partnerPayoutPartnerName'] ??
                    data['quickCareAssignedPartnerName'],
                data['quickCareAssignedPartnerAccountId'] ??
                    data['quickCarePartnerAccountId'],
                'Quick Care Partner',
              ),
              partnerAccountId:
                  (data['quickCareAssignedPartnerAccountId'] ??
                          data['quickCarePartnerAccountId'] ??
                          data['partnerPayoutPartnerAccountId'])
                      ?.toString(),
              amount: amount,
              completedAt:
                  _date(data['quickCareCompletedAt']) ??
                  _date(data['completedAt']) ??
                  _date(data['updatedAt']) ??
                  _date(data['orderDate']),
              isPaid: data['partnerPayoutStatus'] == 'paid',
              paidAmount:
                  (data['partnerPayoutNetAmount'] as num?)?.toDouble() ??
                  (data['partnerPayoutAmount'] as num?)?.toDouble(),
              deductions: _readDeductions(data['partnerPayoutDeductions']),
              reference: data['partnerPayoutReference']?.toString(),
            ),
          );
        }
      }

      for (final doc in payables.docs) {
        final data = doc.data();
        final order = careById[data['orderId']?.toString()];
        if (order == null || order['paymentStatus'] != 'paid') continue;
        final amount = (data['grossPartnerPayable'] as num?)?.toDouble() ?? 0;
        final partnerAccountId = data['partnerAccountId']?.toString();
        if (amount <= 0 || partnerAccountId?.trim().isNotEmpty != true) {
          continue;
        }
        records.add(
          _PayoutRecord(
            id: doc.id,
            category: 'garmentCare',
            categoryLabel: 'Garment Care',
            orderLabel: _orderLabel(data['orderId']?.toString() ?? '', {
              'orderNumber': data['orderNumber'] ?? order['orderNumber'],
            }),
            partnerName: _partnerLabel(
              data['partnerName'],
              data['partnerAccountId'],
              'Garment Care Partner',
            ),
            partnerAccountId: partnerAccountId,
            amount: amount,
            completedAt:
                _date(data['completedAt']) ??
                _date(data['createdAt']) ??
                _date(data['updatedAt']),
            isPaid: data['settlementStatus'] == 'paid',
            paidAmount:
                (data['settlementNetAmount'] as num?)?.toDouble() ?? amount,
            deductions: _readDeductions(data['settlementDeductions']),
            reference: data['settlementReference']?.toString(),
          ),
        );
      }

      records.sort((a, b) => b.orderLabel.compareTo(a.orderLabel));
      final statements = payoutTransfers.docs
          .where(
            (doc) => [
              'partner_weekly_payout',
              'partner_payout_statement',
            ].contains(doc.data()['statementType']),
          )
          .map(
            (doc) =>
                _PayoutStatement.fromMap(doc.id, doc.data(), _readDeductions),
          )
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _records = records;
          _statements = statements;
          _loading = false;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.code == 'permission-denied'
              ? 'You need Admin access to view Partner payout records.'
              : 'Could not load payout records. Please refresh.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load payout records. Please refresh.';
        });
      }
    }
  }

  String _orderLabel(String id, Map<String, dynamic> data) {
    final number = data['orderNumber']?.toString().trim();
    return number != null && number.isNotEmpty
        ? 'Order $number'
        : 'Order ${id.length > 10 ? id.substring(0, 10) : id}';
  }

  String _partnerLabel(dynamic name, dynamic accountId, String fallback) {
    final value = name?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
    final account = accountId?.toString().trim();
    if (account != null && account.isNotEmpty) return '$fallback · $account';
    return fallback;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  List<Map<String, dynamic>> _readDeductions(dynamic raw) {
    if (raw is! List) return const [];
    final deductions = <Map<String, dynamic>>[];
    for (final rawEntry in raw) {
      if (rawEntry is! Map) continue;
      final amount = rawEntry['amount'];
      final remark = rawEntry['remark']?.toString().trim();
      if (amount is! num ||
          !amount.isFinite ||
          amount <= 0 ||
          remark == null ||
          remark.isEmpty) {
        continue;
      }
      deductions.add({'amount': amount.toDouble(), 'remark': remark});
    }
    return deductions;
  }

  List<_PayoutRecord> get _visiblePaidRecords => _records
      .where((record) {
        final categoryMatches =
            _category == 'all' || record.category == _category;
        return categoryMatches && record.isPaid && _status != 'due';
      })
      .toList(growable: false);

  List<_PayoutStatement> get _visibleStatements => _statements
      .where((statement) {
        final categoryMatches =
            _category == 'all' || statement.categories.contains(_category);
        return categoryMatches && _status != 'due';
      })
      .toList(growable: false);

  List<_PayoutRecord> get _visibleDueRecords => _records
      .where((record) {
        final categoryMatches =
            _category == 'all' || record.category == _category;
        if (!categoryMatches || record.isPaid || _status == 'paid') {
          return false;
        }
        if (_allPendingWeeks) return true;
        final completedAt = record.completedAt;
        if (completedAt == null) return false;
        final end = _selectedWeekStart.add(const Duration(days: 7));
        return !completedAt.isBefore(_selectedWeekStart) &&
            completedAt.isBefore(end);
      })
      .toList(growable: false);

  List<_PartnerPayoutGroup> get _visiblePartnerGroups {
    final groups = <String, List<_PayoutRecord>>{};
    for (final record in _visibleDueRecords) {
      final accountId = record.partnerAccountId?.trim();
      if (accountId == null || accountId.isEmpty) continue;
      groups.putIfAbsent(accountId, () => []).add(record);
    }
    final result = groups.entries.map((entry) {
      final records = entry.value
        ..sort((a, b) {
          final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
      return _PartnerPayoutGroup(
        partnerAccountId: entry.key,
        partnerName: records.first.partnerName,
        records: List.unmodifiable(records),
        weekStart: _allPendingWeeks ? null : _selectedWeekStart,
      );
    }).toList();
    result.sort((a, b) => a.partnerName.compareTo(b.partnerName));
    return result;
  }

  Future<void> _recordBatchPayout(_PartnerPayoutGroup group) async {
    final value =
        await showDialog<
          ({String reference, List<Map<String, dynamic>> deductions})
        >(
          context: context,
          builder: (_) => _RecordPartnerPayoutDialog(group: group),
        );
    if (value == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final periodStart = group.weekStart;
      final periodEnd = periodStart?.add(const Duration(days: 7));
      await _functions.httpsCallable('recordAdminPartnerPayoutBatch').call({
        'partnerAccountId': group.partnerAccountId,
        'entries': group.records
            .map(
              (record) => {'category': record.category, 'recordId': record.id},
            )
            .toList(growable: false),
        'periodStartMillis': periodStart?.toUtc().millisecondsSinceEpoch,
        'periodEndMillis': periodEnd?.toUtc().millisecondsSinceEpoch,
        'periodLabel': group.periodLabel,
        'deductions': value.deductions,
        'reference': value.reference,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weekly payout statement recorded for ${group.records.length} orders.',
          ),
        ),
      );
      setState(() => _saving = false);
      await _refresh();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final detail = error.message?.trim();
      final message =
          error.code == 'not-found' &&
              (detail == null ||
                  detail.isEmpty ||
                  detail.toUpperCase() == 'NOT_FOUND')
          ? 'Payout recording service is not deployed in this Firebase environment yet. Deploy recordAdminPartnerPayoutBatch, then retry. No payment gateway is needed to record a payout.'
          : detail ?? 'Could not record the payout.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record the payout. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(top: 24),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Partner payout tracking',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _loading || _saving ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select a Partner to prepare one statement for all due orders in the selected week across Stitching, Garment Care and Quick Care. Itemized deductions include a reason.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _filter(
                'All categories',
                'all',
                _category,
                (value) => setState(() => _category = value),
              ),
              _filter(
                'Stitching',
                'tailoring',
                _category,
                (value) => setState(() => _category = value),
              ),
              _filter(
                'Garment Care',
                'garmentCare',
                _category,
                (value) => setState(() => _category = value),
              ),
              _filter(
                'Quick Care',
                'quickCare',
                _category,
                (value) => setState(() => _category = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filter(
                'Due',
                'due',
                _status,
                (value) => setState(() => _status = value),
              ),
              _filter(
                'Completed',
                'paid',
                _status,
                (value) => setState(() => _status = value),
              ),
              _filter(
                'All statuses',
                'all',
                _status,
                (value) => setState(() => _status = value),
              ),
            ],
          ),
          if (_status != 'paid') ...[
            const SizedBox(height: 8),
            _periodControls(),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          if (!_loading &&
              _error == null &&
              _visiblePartnerGroups.isEmpty &&
              _visiblePaidRecords.isEmpty &&
              _visibleStatements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  _status == 'paid'
                      ? 'No completed Partner payouts in this view.'
                      : _allPendingWeeks
                      ? 'No Partner payouts are due in this view.'
                      : 'No Partner payouts are due for this week.',
                ),
              ),
            ),
          for (final group in _visiblePartnerGroups) _partnerGroupTile(group),
          for (final statement in _visibleStatements) _statementTile(statement),
          for (final record in _visiblePaidRecords) _recordTile(record),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
    ),
  );

  Widget _filter(
    String label,
    String value,
    String selected,
    ValueChanged<String> onTap,
  ) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) => onTap(value),
  );

  Widget _periodControls() {
    final currentWeek = _weekStart(DateTime.now());
    final weekEnd = _selectedWeekStart.add(const Duration(days: 6));
    String shortDate(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    final canMoveForward = _selectedWeekStart.isBefore(currentWeek);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Previous week',
          onPressed: _allPendingWeeks
              ? null
              : () => setState(() {
                  _selectedWeekStart = _selectedWeekStart.subtract(
                    const Duration(days: 7),
                  );
                }),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          _allPendingWeeks
              ? 'All pending weeks'
              : '${shortDate(_selectedWeekStart)}–${shortDate(weekEnd)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Next week',
          onPressed: _allPendingWeeks || !canMoveForward
              ? null
              : () => setState(() {
                  _selectedWeekStart = _selectedWeekStart.add(
                    const Duration(days: 7),
                  );
                }),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(
          onPressed: _allPendingWeeks
              ? () => setState(() => _allPendingWeeks = false)
              : () => setState(() => _allPendingWeeks = true),
          child: Text(_allPendingWeeks ? 'Choose week' : 'All pending'),
        ),
      ],
    );
  }

  Widget _partnerGroupTile(_PartnerPayoutGroup group) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.partnerName, style: AppTextStyles.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Partner · ${group.partnerAccountId}',
          style: AppTextStyles.bodySmall,
        ),
        Text(
          '${group.periodLabel} · ${group.records.length} pending orders',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final record in group.records.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${record.categoryLabel} · ${record.orderLabel}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                Text('₹${record.amount.toStringAsFixed(2)}'),
              ],
            ),
          ),
        if (group.records.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'And ${group.records.length - 5} more pending orders are included.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        const Divider(),
        Row(
          children: [
            Expanded(
              child: Text(
                'Partner rate payable · ₹${group.totalAmount.toStringAsFixed(2)}',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _saving || group.records.length > 200
                  ? null
                  : () => _recordBatchPayout(group),
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: Text(
                group.records.length > 200 ? 'Select a week' : 'Payout orders',
              ),
            ),
          ],
        ),
        if (group.records.length > 200)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Select a single week to keep this payout statement within the processing limit.',
              style: AppTextStyles.bodySmall,
            ),
          ),
      ],
    ),
  );

  Widget _statementTile(_PayoutStatement statement) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                statement.partnerName,
                style: AppTextStyles.titleMedium,
              ),
            ),
            Text('Paid', style: TextStyle(color: Colors.green.shade700)),
          ],
        ),
        Text(
          '${statement.periodLabel} · ${statement.orderCount} orders · ${statement.categoryLabels.join(', ')}',
          style: AppTextStyles.bodySmall,
        ),
        Text('Statement · ${statement.id}', style: AppTextStyles.bodySmall),
        const SizedBox(height: 8),
        Text('Gross payable · ₹${statement.grossAmount.toStringAsFixed(2)}'),
        Text('Deductions · ₹${statement.deductionAmount.toStringAsFixed(2)}'),
        Text(
          'Partner transfer · ₹${statement.netAmount.toStringAsFixed(2)}',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
        ),
        for (var index = 0; index < statement.deductions.length; index++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Charge ${index + 1} · ₹${(statement.deductions[index]['amount'] as num).toStringAsFixed(2)} — ${statement.deductions[index]['remark']}',
              style: AppTextStyles.bodySmall,
            ),
          ),
        if (statement.reference.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(statement.reference, style: AppTextStyles.bodySmall),
          ),
      ],
    ),
  );

  Widget _recordTile(_PayoutRecord record) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                record.categoryLabel,
                style: AppTextStyles.titleMedium,
              ),
            ),
            Text(
              record.isPaid ? 'Paid' : 'Due',
              style: TextStyle(
                color: record.isPaid
                    ? Colors.green.shade700
                    : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Text(
          '${record.orderLabel} · ${record.partnerName}',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Partner rate payable · ₹${record.amount.toStringAsFixed(2)}',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary),
        ),
        if (record.isPaid) ...[
          const SizedBox(height: 3),
          Text(
            'Transferred · ₹${(record.paidAmount ?? record.amount).toStringAsFixed(2)}',
            style: AppTextStyles.bodySmall,
          ),
          for (var i = 0; i < record.deductions.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Charge ${i + 1} · ₹${((record.deductions[i]['amount'] as num).toDouble()).toStringAsFixed(2)} — ${record.deductions[i]['remark']}',
                style: AppTextStyles.bodySmall,
              ),
            ),
          if (record.reference?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(record.reference!, style: AppTextStyles.bodySmall),
            ),
        ],
      ],
    ),
  );
}

class _RecordPartnerPayoutDialog extends StatefulWidget {
  const _RecordPartnerPayoutDialog({required this.group});

  final _PartnerPayoutGroup group;

  @override
  State<_RecordPartnerPayoutDialog> createState() =>
      _RecordPartnerPayoutDialogState();
}

class _RecordPartnerPayoutDialogState
    extends State<_RecordPartnerPayoutDialog> {
  final _reference = TextEditingController();
  final _charges = <_PayoutDeductionDraft>[_PayoutDeductionDraft()];

  @override
  void dispose() {
    _reference.dispose();
    for (final charge in _charges) {
      charge.dispose();
    }
    super.dispose();
  }

  void _removeCharge(int index) {
    final removed = _charges.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final gross = group.totalAmount;
    final deductions = <Map<String, dynamic>>[];
    var invalidCharge = false;
    for (final charge in _charges) {
      final rawAmount = charge.amount.text.trim().replaceAll(',', '.');
      final remark = charge.remark.text.trim();
      if (rawAmount.isEmpty && remark.isEmpty) continue;
      final parsed = double.tryParse(rawAmount);
      if (parsed == null || !parsed.isFinite || parsed <= 0 || remark.isEmpty) {
        invalidCharge = true;
        continue;
      }
      final roundedAmount = (parsed * 100).round() / 100.0;
      if (roundedAmount <= 0) {
        invalidCharge = true;
        continue;
      }
      deductions.add({'amount': roundedAmount, 'remark': remark});
    }
    final deductionTotal = deductions.fold<double>(
      0,
      (total, charge) => total + (charge['amount'] as double),
    );
    final netAmount = gross - deductionTotal;
    final invalidTotal = deductionTotal > gross + 0.001;
    final canConfirm =
        (_reference.text.trim().isNotEmpty || netAmount <= 0.001) &&
        !invalidCharge &&
        !invalidTotal &&
        netAmount >= -0.001;

    return AlertDialog(
      title: const Text('Record Partner payout'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.partnerName),
              Text('Partner ID · ${group.partnerAccountId}'),
              Text(group.periodLabel),
              const SizedBox(height: 8),
              Text(
                'All ${group.records.length} pending orders below are included in this statement.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 6),
              for (final record in group.records)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• ${record.categoryLabel} · ${record.orderLabel} · ₹${record.amount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const Divider(),
              Text(
                'Partner rate payable: ₹${gross.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter any charges withheld by SuiSakhi and give a reason for each. The remaining amount is the Partner transfer.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _charges.length; index++)
                _chargeFields(index),
              TextButton.icon(
                onPressed: _charges.length >= 10
                    ? null
                    : () =>
                          setState(() => _charges.add(_PayoutDeductionDraft())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add charge'),
              ),
              const Divider(),
              Text('Deductions: ₹${deductionTotal.toStringAsFixed(2)}'),
              Text(
                'Partner transfer: ₹${netAmount.clamp(0, gross).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (invalidCharge)
                const Text(
                  'Enter a positive amount and a reason for each charge.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              if (invalidTotal)
                const Text(
                  'Deductions cannot exceed the Partner payable.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Bank / UPI transaction reference',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'This records an external transfer; it does not move money.',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.pop(context, (
                  reference: _reference.text.trim(),
                  deductions: deductions,
                ))
              : null,
          child: const Text('Confirm payout'),
        ),
      ],
    );
  }

  Widget _chargeFields(int index) {
    final charge = _charges[index];
    return Column(
      key: ObjectKey(charge),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Charge ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_charges.length > 1)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove charge',
                onPressed: () => _removeCharge(index),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 112,
              child: TextField(
                controller: charge.amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount ₹',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: charge.remark,
                decoration: const InputDecoration(
                  labelText: 'Reason / remark',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                maxLength: 300,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PayoutRecord {
  const _PayoutRecord({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.orderLabel,
    required this.partnerName,
    required this.partnerAccountId,
    required this.amount,
    this.completedAt,
    required this.isPaid,
    this.paidAmount,
    this.deductions = const [],
    this.reference,
  });

  final String id;
  final String category;
  final String categoryLabel;
  final String orderLabel;
  final String partnerName;
  final String? partnerAccountId;
  final double amount;
  final DateTime? completedAt;
  final bool isPaid;
  final double? paidAmount;
  final List<Map<String, dynamic>> deductions;
  final String? reference;
}

class _PartnerPayoutGroup {
  const _PartnerPayoutGroup({
    required this.partnerAccountId,
    required this.partnerName,
    required this.records,
    required this.weekStart,
  });

  final String partnerAccountId;
  final String partnerName;
  final List<_PayoutRecord> records;
  final DateTime? weekStart;

  double get totalAmount =>
      records.fold<double>(0, (total, record) => total + record.amount);

  String get periodLabel {
    final start = weekStart;
    if (start == null) return 'All pending weeks';
    final end = start.add(const Duration(days: 6));
    return 'Week ${_formatDate(start)}–${_formatDate(end)}';
  }
}

class _PayoutStatement {
  const _PayoutStatement({
    required this.id,
    required this.partnerName,
    required this.periodLabel,
    required this.orderCount,
    required this.categories,
    required this.grossAmount,
    required this.deductionAmount,
    required this.netAmount,
    required this.deductions,
    required this.reference,
  });

  final String id;
  final String partnerName;
  final String periodLabel;
  final int orderCount;
  final List<String> categories;
  final double grossAmount;
  final double deductionAmount;
  final double netAmount;
  final List<Map<String, dynamic>> deductions;
  final String reference;

  List<String> get categoryLabels => categories
      .map((category) {
        return switch (category) {
          'tailoring' => 'Stitching',
          'garmentCare' => 'Garment Care',
          'quickCare' => 'Quick Care',
          _ => category,
        };
      })
      .toList(growable: false);

  factory _PayoutStatement.fromMap(
    String id,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> Function(dynamic) readDeductions,
  ) {
    final rawCategories = data['categories'];
    final categories = rawCategories is Iterable
        ? rawCategories.map((value) => value.toString()).toList(growable: false)
        : const <String>[];
    double amount(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return _PayoutStatement(
      id: id,
      partnerName: data['partnerName']?.toString() ?? 'Partner',
      periodLabel: data['periodLabel']?.toString() ?? 'Payout statement',
      orderCount: (data['orderCount'] as num?)?.toInt() ?? 0,
      categories: categories,
      grossAmount: amount('grossAmount'),
      deductionAmount: amount('deductionAmount'),
      netAmount: amount('netAmount'),
      deductions: readDeductions(data['deductions']),
      reference: data['transferReference']?.toString() ?? '',
    );
  }
}

DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _PayoutDeductionDraft {
  final amount = TextEditingController();
  final remark = TextEditingController();

  void dispose() {
    amount.dispose();
    remark.dispose();
  }
}
