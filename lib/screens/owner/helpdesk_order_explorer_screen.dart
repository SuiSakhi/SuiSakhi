import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

String _formatHelpdeskOrderReference(Object? value) {
  final reference = value?.toString().trim() ?? '';
  if (RegExp(r'^\d{12}$').hasMatch(reference)) {
    return '${reference.substring(0, 6)}-${reference.substring(6)}';
  }
  return reference;
}

class HelpdeskOrderExplorerScreen extends StatefulWidget {
  const HelpdeskOrderExplorerScreen({super.key});

  @override
  State<HelpdeskOrderExplorerScreen> createState() =>
      _HelpdeskOrderExplorerScreenState();
}

class _HelpdeskOrderExplorerScreenState
    extends State<HelpdeskOrderExplorerScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;
  String? _error;
  String _quickCareQueue = 'All';

  static const _quickCareQueues = [
    'All',
    'Needs partner',
    'In progress',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('listHelpdeskOrders')
          .call(<String, dynamic>{'limit': 500});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final orders = (payload['orders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'permission-denied'
            ? 'Configured Helpdesk access is required to view customer orders.'
            : 'Could not load orders. ${error.message ?? 'Please retry.'}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load orders. Please retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    Iterable<Map<String, dynamic>> result = _orders;
    if (_quickCareQueue != 'All') {
      result = result.where((order) {
        if (order['orderType'] != 'quick_care') return false;
        final workflow = (order['workflowStatus'] ?? order['status'] ?? '')
            .toString()
            .toLowerCase();
        final assignment = (order['assignmentStatus'] ?? 'searching')
            .toString()
            .toLowerCase();
        return switch (_quickCareQueue) {
          'Needs partner' =>
            ![
                  'accepted',
                  'inprogress',
                  'paused',
                  'awaitingcustomerapproval',
                  'paymentpending',
                  'completed',
                  'cancelled',
                ].contains(workflow) &&
                !['accepted', 'completed', 'cancelled'].contains(assignment),
          'In progress' =>
            [
                  'accepted',
                  'inprogress',
                  'paused',
                  'awaitingcustomerapproval',
                  'paymentpending',
                ].contains(workflow) ||
                assignment == 'accepted',
          'Closed' =>
            ['completed', 'cancelled'].contains(workflow) ||
                assignment == 'cancelled',
          _ => true,
        };
      });
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return result.toList();
    final normalizedQuery = query.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return result.where((order) {
      final searchable = [
        order['orderNumber'],
        order['orderId'],
        order['customerName'],
        order['customerUid'],
        order['summary'],
        order['status'],
        order['orderType'],
        order['assignmentStatus'],
        order['workflowStatus'],
      ].join(' ').toLowerCase();
      final normalizedSearchable = searchable.replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      return searchable.contains(query) ||
          (normalizedQuery.isNotEmpty &&
              normalizedSearchable.contains(normalizedQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F6FC),
    appBar: AppBar(
      title: const Text('All customer orders'),
      backgroundColor: const Color(0xFFF8F6FC),
      actions: [
        IconButton(
          tooltip: 'Refresh orders',
          onPressed: _loadOrders,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search order, customer or service',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: _quickCareQueues.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final queue = _quickCareQueues[index];
              final count = _orders.where((order) {
                if (order['orderType'] != 'quick_care') return false;
                final workflow =
                    (order['workflowStatus'] ?? order['status'] ?? '')
                        .toString()
                        .toLowerCase();
                final assignment = (order['assignmentStatus'] ?? 'searching')
                    .toString()
                    .toLowerCase();
                return switch (queue) {
                  'Needs partner' =>
                    ![
                          'accepted',
                          'inprogress',
                          'paused',
                          'awaitingcustomerapproval',
                          'paymentpending',
                          'completed',
                          'cancelled',
                        ].contains(workflow) &&
                        ![
                          'accepted',
                          'completed',
                          'cancelled',
                        ].contains(assignment),
                  'In progress' =>
                    [
                          'accepted',
                          'inprogress',
                          'paused',
                          'awaitingcustomerapproval',
                          'paymentpending',
                        ].contains(workflow) ||
                        assignment == 'accepted',
                  'Closed' =>
                    ['completed', 'cancelled'].contains(workflow) ||
                        assignment == 'cancelled',
                  _ => true,
                };
              }).length;
              final label = queue == 'All' ? 'All orders' : queue;
              return ChoiceChip(
                selected: _quickCareQueue == queue,
                onSelected: (_) => setState(() => _quickCareQueue = queue),
                label: Text('$label ($count)'),
              );
            },
          ),
        ),
        Expanded(child: _buildOrders(context)),
      ],
    ),
  );

  Widget _buildOrders(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return const Center(child: Text('No matching orders found.'));
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final order = orders[index];
          final type = _typeLabel(order['orderType']?.toString() ?? '');
          final id = order['orderId']?.toString() ?? '';
          final workflow =
              (order['workflowStatus'] ?? order['status'] ?? 'Unknown')
                  .toString();
          final workflowLabel = _quickCareStatusLabel(workflow);
          final paymentFollowup =
              order['orderType'] == 'quick_care' &&
              _needsQuickCarePaymentFollowup(order);
          final statusText = order['orderType'] == 'quick_care'
              ? paymentFollowup
                    ? 'Payment follow-up'
                    : workflowLabel
              : _humanizeOrderListStatus(order['status']?.toString() ?? '');
          return Card(
            color: Colors.white,
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEFE7FA),
                child: Icon(
                  _typeIcon(order['orderType']?.toString() ?? ''),
                  color: const Color(0xFF5B35D5),
                ),
              ),
              title: Text(
                order['summary']?.toString().trim().isNotEmpty == true
                    ? order['summary'].toString()
                    : '$type order',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$type · ${order['customerName'] ?? 'Customer'}\n'
                  '${_formatHelpdeskOrderReference(order['orderNumber'] ?? id)} · $statusText',
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showHelpdeskOrderDetails(
                context,
                orderId: id,
                orderType: order['orderType']?.toString() ?? '',
              ),
            ),
          );
        },
      ),
    );
  }
}

String _quickCareStatusLabel(String status) => switch (status.toLowerCase()) {
  'requestsubmitted' => 'Request submitted',
  'partnerassigned' => 'Partner assigned',
  'accepted' => 'Accepted',
  'inprogress' => 'In progress',
  'paused' => 'Paused',
  'awaitingcustomerapproval' => 'Quote awaiting customer',
  'paymentpending' => 'Payment pending',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};

String _humanizeOrderListStatus(String status) {
  if (status.trim().isEmpty || status.toLowerCase() == 'unknown') {
    return 'Status unavailable';
  }
  return status
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _typeLabel(String value) => switch (value) {
  'garment_care' => 'Garment Care',
  'quick_care' => 'Quick Care',
  'tailoring' => 'Tailoring',
  'measurements' => 'Measurements',
  _ => 'Other service',
};

IconData _typeIcon(String value) => switch (value) {
  'garment_care' => Icons.local_laundry_service_outlined,
  'quick_care' => Icons.home_repair_service_outlined,
  'tailoring' => Icons.design_services_outlined,
  _ => Icons.receipt_long_outlined,
};

Future<void> showHelpdeskOrderDetails(
  BuildContext context, {
  required String orderId,
  required String orderType,
}) async {
  try {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getHelpdeskOrderDetails')
        .call(<String, dynamic>{'orderId': orderId, 'orderType': orderType});
    final data = Map<String, dynamic>.from(result.data as Map);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _HelpdeskOrderDetailsSheet(
        orderId: orderId,
        orderType: orderType,
        data: data,
      ),
    );
  } on FirebaseFunctionsException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message ?? 'Could not load order details.')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not load order details. Please retry.'),
      ),
    );
  }
}

class _HelpdeskOrderDetailsSheet extends StatefulWidget {
  const _HelpdeskOrderDetailsSheet({
    required this.orderId,
    required this.orderType,
    required this.data,
  });

  final String orderId;
  final String orderType;
  final Map<String, dynamic> data;

  @override
  State<_HelpdeskOrderDetailsSheet> createState() =>
      _HelpdeskOrderDetailsSheetState();
}

class _HelpdeskOrderDetailsSheetState
    extends State<_HelpdeskOrderDetailsSheet> {
  bool _cancelling = false;
  bool _assigning = false;

  Future<void> _assignQuickCarePartner() async {
    setState(() => _assigning = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getQuickCareAssignmentCandidates')
          .call(<String, dynamic>{'orderId': widget.orderId});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final candidates = (payload['candidates'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((candidate) => Map<String, dynamic>.from(candidate))
          .toList();
      if (!mounted) return;
      setState(() => _assigning = false);
      if (candidates.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('No QuickCare Partners found'),
            content: const Text(
              'There are no active, approved QuickCare Partner profiles yet. Check that a Partner profile is approved and operational.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        builder: (sheetContext) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Assign QuickCare Partner',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final candidate in candidates)
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.home_repair_service_outlined),
                  ),
                  title: Text(
                    candidate['name']?.toString() ?? 'QuickCare Partner',
                  ),
                  subtitle: Text(
                    '${candidate['eligible'] == true ? 'Recommended · online' : (candidate['reasons'] as List<dynamic>? ?? const []).join(' · ')}\n'
                    'PINs: ${(candidate['serviceAreaPincodes'] as List<dynamic>? ?? const []).join(', ')} · '
                    'Skills: ${(candidate['capabilities'] as List<dynamic>? ?? const []).map((value) => value.toString().replaceFirst('doorstepServices.', '')).join(', ')}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(sheetContext, candidate),
                ),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      final allowOverride = selected['eligible'] != true;
      if (allowOverride) {
        final reasons = (selected['reasons'] as List<dynamic>? ?? const [])
            .map((reason) => reason.toString())
            .join('\n');
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Assign this Partner anyway?'),
            content: Text(
              'This Partner does not match all current request settings:\n\n$reasons\n\nContinue with a manual Helpdesk assignment?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Assign anyway'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      setState(() => _assigning = true);
      await FirebaseFunctions.instance
          .httpsCallable('assignQuickCarePartner')
          .call(<String, dynamic>{
            'orderId': widget.orderId,
            'partnerAccountId': selected['accountId'],
            'partnerProfileId': selected['profileId'],
            'allowOverride': allowOverride,
          });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected['name'] ?? 'Partner'} assigned to the Quick Care request.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _assigning = false);
      final message = error.code == 'internal'
          ? 'Could not load the QuickCare Partner list. Please retry.'
          : error.message ?? 'Could not assign a Partner.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not assign a Partner. Please retry.'),
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this Quick Care booking?'),
        content: const Text(
          'This records a cancellation with no cancellation fee. Any paid amount will be flagged for Helpdesk refund review; it will not be deleted from the audit history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('cancelHelpdeskQuickCareOrder')
          .call(<String, dynamic>{'orderId': widget.orderId});
      final resultData = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      final refundDue = (resultData['refundDue'] as num?)?.toDouble() ?? 0;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refundDue > 0
                ? 'Booking cancelled with no fee. A ₹${refundDue.toStringAsFixed(0)} refund is flagged for review.'
                : 'Booking cancelled with no fee.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not cancel booking.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel booking. Please retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = widget.data['canCancel'] == true;
    final isQuickCare = widget.orderType == 'quick_care';
    final order = widget.data['order'] is Map
        ? Map<String, dynamic>.from(widget.data['order'] as Map)
        : <String, dynamic>{};
    final customer = widget.data['customer'] is Map
        ? Map<String, dynamic>.from(widget.data['customer'] as Map)
        : <String, dynamic>{};
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        8,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        maxChildSize: .95,
        minChildSize: .45,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_typeLabel(widget.orderType)} · ${_formatHelpdeskOrderReference(widget.data['orderNumber'] ?? order['orderTrackingId'] ?? widget.orderId)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (isQuickCare && order.isNotEmpty)
                    _QuickCareOverview(order: order, customer: customer),
                  for (final key
                      in isQuickCare
                          ? const <String>[]
                          : [
                              'order',
                              'customer',
                              'assignmentState',
                              'items',
                              'deliveryGroups',
                              'serviceJobs',
                              'shipments',
                              'invoices',
                              'custodyEvents',
                              'events',
                            ])
                    if (widget.data[key] != null)
                      _DetailExpansion(
                        title: _detailLabel(key),
                        value: widget.data[key],
                        initiallyExpanded: key == 'order',
                      ),
                  if (isQuickCare)
                    _QuickCareHistorySection(
                      events:
                          (widget.data['events'] as List<dynamic>? ?? const [])
                              .whereType<Map>()
                              .map((event) => Map<String, dynamic>.from(event))
                              .toList(),
                    ),
                  if (widget.orderType == 'quick_care' &&
                      ((widget.data['order'] as Map?)?['quickCareEvidence']
                                  as List<dynamic>?)
                              ?.isNotEmpty ==
                          true)
                    _QuickCareEvidenceSection(
                      evidence:
                          ((widget.data['order'] as Map)['quickCareEvidence']
                                  as List<dynamic>)
                              .whereType<Map>()
                              .map((item) => Map<String, dynamic>.from(item))
                              .toList(),
                    ),
                  if (!canCancel &&
                      (widget.data['cancelReason']?.toString().isNotEmpty ??
                          false))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        widget.data['cancelReason'].toString(),
                        style: const TextStyle(color: Color(0xFF777286)),
                      ),
                    ),
                ],
              ),
            ),
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelOrder,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined),
                  label: Text(
                    _cancelling ? 'Cancelling…' : 'Cancel Quick Care booking',
                  ),
                ),
              ),
            if (widget.orderType == 'quick_care' &&
                (widget.data['order'] as Map?)?['quickCareWorkflowStatus'] !=
                    'completed' &&
                (widget.data['order'] as Map?)?['quickCareWorkflowStatus'] !=
                    'cancelled') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _assigning ? null : _assignQuickCarePartner,
                  icon: _assigning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(
                    _assigning
                        ? 'Loading eligible Partners…'
                        : 'Assign / Reassign QuickCare Partner',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _detailLabel(String key) => switch (key) {
  'order' => 'Order and customer details',
  'customer' => 'Customer contact and profile',
  'assignmentState' => 'Tailoring assignment',
  'items' => 'Garments / service items',
  'deliveryGroups' => 'Service groups',
  'serviceJobs' => 'Garment Care service jobs',
  'shipments' => 'Pickups and transfers',
  'invoices' => 'Invoices and payments',
  'custodyEvents' => 'Custody trail',
  'events' => 'Order history',
  _ => key,
};

class _DetailExpansion extends StatelessWidget {
  const _DetailExpansion({
    required this.title,
    required this.value,
    required this.initiallyExpanded,
  });

  final String title;
  final Object value;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _ReadableHelpdeskValue(value: value),
        ),
      ],
    ),
  );
}

const _hiddenHelpdeskFields = <String>{
  'id',
  'orderId',
  'customerUid',
  'customerId',
  'customerAccountId',
  'customerProfileId',
  'deliveryGroupIds',
  'packageIds',
  'createdFromPricingVersionId',
  'pricingPolicyVersionId',
  'schemaVersion',
  'nextSubOrderSequence',
};

const _helpdeskFieldLabels = <String, String>{
  'createdAt': 'Created at',
  'updatedAt': 'Last updated',
  'statusProjection': 'Workflow stage',
  'estimateStatus': 'Estimate status',
  'pricingState': 'Pricing stage',
  'serviceGroupCode': 'Service group',
  'mobileE164': 'Mobile number',
  'customerMobileE164': 'Mobile number',
  'deliveryPincode': 'Delivery PIN code',
  'servicePincode': 'Service PIN code',
  'pickupPincode': 'Pickup PIN code',
  'estimatedGrandTotal': 'Estimated total',
  'grandTotal': 'Total',
  'advanceAmount': 'Advance paid',
  'balanceAmount': 'Balance due',
  'customerNameSnapshot': 'Customer name',
  'toPartnerAccountId': 'Assigned partner account',
};

String _helpdeskFieldLabel(String key) {
  final override = _helpdeskFieldLabels[key];
  if (override != null) return override;
  final words = key
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim()
      .split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

bool _isHiddenHelpdeskField(String key) =>
    _hiddenHelpdeskFields.contains(key) || key.startsWith('_');

String _humanizeHelpdeskText(String value) {
  final words = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim()
      .split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _formatHelpdeskDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year} · $hour:$minute $meridiem';
}

String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

String _readableHelpdeskScalar(Object? value, String fieldName) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is num) {
    final isMoney = RegExp(
      r'(price|amount|total|fee|cost|rate|charge)',
      caseSensitive: false,
    ).hasMatch(fieldName);
    if (isMoney) {
      final amount = value.toDouble();
      return '₹${amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)}';
    }
    return value.toString();
  }
  final text = value.toString().trim();
  if (text.isEmpty) return '—';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}[T ]').hasMatch(text)) {
    return _formatHelpdeskDate(text);
  }
  if (RegExp(
    r'(status|stage|state|code)$',
    caseSensitive: false,
  ).hasMatch(fieldName)) {
    return _humanizeHelpdeskText(text);
  }
  return text;
}

class _ReadableHelpdeskValue extends StatelessWidget {
  const _ReadableHelpdeskValue({required this.value, this.fieldName = ''});

  final Object? value;
  final String fieldName;

  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      final record = Map<String, dynamic>.from(value as Map)
        ..removeWhere(
          (key, value) => _isHiddenHelpdeskField(key) || _isEmpty(value),
        );
      if (record.isEmpty) return const _EmptyHelpdeskDetails();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in record.entries)
            _ReadableHelpdeskField(name: entry.key, value: entry.value),
        ],
      );
    }
    if (value is List) {
      final items = (value as List).where((item) => !_isEmpty(item)).toList();
      if (items.isEmpty) return const _EmptyHelpdeskDetails();
      if (items.every((item) => item is! Map && item is! List)) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) =>
                    Chip(label: Text(_readableHelpdeskScalar(item, fieldName))),
              )
              .toList(),
        );
      }
      return Column(
        children: [
          for (var index = 0; index < items.length; index++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1DCE5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _helpdeskRecordTitle(items[index], index),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _ReadableHelpdeskValue(
                    value: items[index],
                    fieldName: fieldName,
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Text(_readableHelpdeskScalar(value, fieldName));
  }
}

class _ReadableHelpdeskField extends StatelessWidget {
  const _ReadableHelpdeskField({required this.name, required this.value});

  final String name;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final isNested = value is Map || value is List;
    if (isNested) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _helpdeskFieldLabel(name),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF6E3150),
              ),
            ),
            const SizedBox(height: 4),
            _ReadableHelpdeskValue(value: value, fieldName: name),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              _helpdeskFieldLabel(name),
              style: const TextStyle(color: Color(0xFF777286), fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              _readableHelpdeskScalar(value, name),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHelpdeskDetails extends StatelessWidget {
  const _EmptyHelpdeskDetails();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'No records available yet.',
      style: TextStyle(color: Color(0xFF777286)),
    ),
  );
}

bool _isEmpty(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty || value.every(_isEmpty);
  if (value is Map) {
    return value.isEmpty ||
        value.entries.every(
          (entry) => _isHiddenHelpdeskField(entry.key) || _isEmpty(entry.value),
        );
  }
  return false;
}

String _helpdeskRecordTitle(Object? value, int index) {
  if (value is Map) {
    for (final key in const [
      'name',
      'title',
      'serviceName',
      'orderNumber',
      'orderTrackingId',
      'dressType',
      'status',
      'jobType',
    ]) {
      final text = value[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return _humanizeHelpdeskText(text);
    }
  }
  return 'Record ${index + 1}';
}

class _QuickCareOverview extends StatelessWidget {
  const _QuickCareOverview({required this.order, required this.customer});

  final Map<String, dynamic> order;
  final Map<String, dynamic> customer;

  static const _serviceNames = <String, String>{
    'pico_fall': 'Saree Pico / Fall',
    'rafu': 'Rafu (Tear Repair)',
    'zip': 'Zip repair',
    'button': 'Button fixing',
    'minor_alt': 'Minor alterations',
    'express_stitch': 'Express stitching',
    'wardrobe': 'Wardrobe management',
    'saree_draping': 'Saree draping',
    'other_quote': 'Other service',
  };

  String _text(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _date(Object? value) {
    final raw = value?.toString() ?? '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year} · $hour:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    final profile = customer['profile'] is Map
        ? Map<String, dynamic>.from(customer['profile'] as Map)
        : const <String, dynamic>{};
    final account = customer['account'] is Map
        ? Map<String, dynamic>.from(customer['account'] as Map)
        : const <String, dynamic>{};
    final services = (order['quickFixServiceIds'] as List<dynamic>? ?? const [])
        .map((id) => _serviceNames[id.toString()] ?? id.toString())
        .join(' · ');
    final title = _text([
      order['quickCareTitle'],
      order['title'],
      order['serviceName'],
      order['dressType'],
    ]);
    final customerName = _text([
      order['customerName'],
      order['customerDisplayName'],
      profile['displayName'],
      profile['name'],
      account['displayName'],
    ]);
    final phone = _text([
      account['mobileE164'],
      profile['mobileE164'],
      order['customerPhone'],
    ]);
    final address = _text([
      order['deliveryAddress'],
      order['serviceVisitAddress'],
      order['serviceAddress'],
    ]);
    final appointment = _date(
      order['quickCareScheduledAt'] ?? order['orderDate'] ?? order['createdAt'],
    );
    final workflow = _statusLabel(
      _text([order['quickCareWorkflowStatus'], order['status']]),
    );
    final assignment = _assignmentLabel(
      _text([order['quickCareAssignmentStatus']]),
    );
    final price = (order['estimatedPrice'] ?? order['price'] ?? 0).toString();
    final pincode = _text([
      order['deliveryPincode'],
      order['servicePincode'],
      order['pincode'],
    ]);
    final servicePincode = pincode.isNotEmpty
        ? pincode
        : (RegExp(r'\b\d{6}\b').firstMatch(address)?.group(0) ?? '');
    final fullAddress = [
      address,
      if ((order['serviceVisitLandmark']?.toString() ?? '').trim().isNotEmpty)
        'Landmark: ${order['serviceVisitLandmark']}',
      if (servicePincode.isNotEmpty && !address.contains(servicePincode))
        servicePincode,
    ].where((value) => value.isNotEmpty).join('\n');

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Care booking',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (title.isNotEmpty) _overviewRow('Request', title),
            if (services.isNotEmpty) _overviewRow('Services', services),
            if (customerName.isNotEmpty) _overviewRow('Customer', customerName),
            if (phone.isNotEmpty) _overviewRow('Phone', phone),
            if (appointment.isNotEmpty)
              _overviewRow('Appointment', appointment),
            if (fullAddress.isNotEmpty)
              _overviewRow('Service address', fullAddress),
            _overviewRow('Estimate', '₹$price'),
            if (workflow.isNotEmpty) _overviewRow('Service status', workflow),
            if (assignment.isNotEmpty)
              _overviewRow('Partner assignment', assignment),
            if ((order['paymentStatus']?.toString() ?? '').isNotEmpty)
              _overviewRow(
                'Payment',
                _quickCarePaymentLabel(order['paymentStatus'].toString()),
              ),
            if (_needsQuickCarePaymentFollowup(order))
              _overviewRow(
                'Payment follow-up',
                'Customer payment pending · ₹${order['quickCareFinalAmount'] ?? order['price'] ?? 0}',
              ),
            if ((order['notes']?.toString() ?? '').trim().isNotEmpty)
              _overviewRow('Customer notes', order['notes'].toString()),
          ],
        ),
      ),
    );
  }
}

Widget _overviewRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 108,
        child: Text(label, style: const TextStyle(color: Color(0xFF777286))),
      ),
      Expanded(child: Text(value)),
    ],
  ),
);

String _statusLabel(String status) => switch (status.toLowerCase()) {
  'requestsubmitted' => 'Request submitted',
  'partnerassigned' => 'Partner assigned',
  'accepted' => 'Accepted',
  'inprogress' => 'In progress',
  'paused' => 'Paused',
  'awaitingcustomerapproval' => 'Awaiting customer quote approval',
  'paymentpending' => 'Payment pending',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};

String _assignmentLabel(String status) => switch (status.toLowerCase()) {
  '' ||
  'searching' ||
  'available' ||
  'unassigned' ||
  'reassigning' => 'Needs partner',
  'assigned' => 'Awaiting partner acceptance',
  'accepted' => 'Partner accepted',
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  _ => status,
};

String _quickCarePaymentLabel(String status) => switch (status.toLowerCase()) {
  'fullypaid' || 'paid' => 'Fully paid',
  'unpaid' => 'Unpaid',
  'pending_payment' || 'pending' => 'Payment pending',
  _ => status,
};

bool _needsQuickCarePaymentFollowup(Map<String, dynamic> order) {
  final workflow =
      (order['quickCareWorkflowStatus'] ??
              order['workflowStatus'] ??
              order['status'] ??
              '')
          .toString()
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)}_${match.group(2)}',
          )
          .toLowerCase()
          .replaceAll('_', '');
  final payment = (order['paymentStatus'] ?? '').toString().toLowerCase();
  return const {'paymentpending', 'completed'}.contains(workflow) &&
      !const {'fullypaid', 'paid'}.contains(payment);
}

class _QuickCareHistorySection extends StatelessWidget {
  const _QuickCareHistorySection({required this.events});

  final List<Map<String, dynamic>> events;

  String _eventTitle(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    final note = (event['note'] ?? '').toString();
    return switch (type) {
      'quick_care_partner_assigned' => 'Quick Care Partner assigned',
      'quick_care_partner_accepted' => 'Partner accepted the job',
      'quick_care_work_started' => 'Work started',
      'quick_care_pause' => 'Work paused',
      'quick_care_resume' => 'Work resumed',
      'quick_care_complete' => 'Service marked complete',
      'quick_care_extra_charge_approved' => 'Additional work approved',
      'quick_care_extra_charge_declined' => 'Additional work declined',
      'quick_care_customer_rated' => 'Customer submitted a rating',
      'quick_care_payment_completed' => 'Customer payment verified',
      'quick_care_photo_evidence_added' =>
        note == 'after_work'
            ? 'After-work photo attached'
            : 'Before-work photo attached',
      'quick_care_audio_evidence_added' => 'Voice note attached',
      'customer_requested_quick_care_cancellation' =>
        'Customer requested cancellation',
      'helpdesk_cancelled_quick_care_order' => 'Helpdesk cancelled service',
      _ => _humanizeQuickCareEvent(type),
    };
  }

  String _eventTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} · $hour:$minute $meridiem';
  }

  String _actor(Map<String, dynamic> event) =>
      switch ((event['actorType'] ?? '').toString().toLowerCase()) {
        'partner' => 'Partner',
        'customer' => 'Customer',
        'admin' || 'support' || 'helpdesk' => 'Helpdesk',
        'payment_gateway' => 'Payment gateway',
        _ => 'System',
      };

  String _description(Map<String, dynamic> event) {
    final parts = <String>[];
    final reason = (event['reason'] ?? '').toString().trim();
    final note = (event['note'] ?? '').toString().trim();
    final amount = event['amount'];
    final rating = event['rating'];
    if (reason.isNotEmpty) parts.add(reason);
    if (note.isNotEmpty && note != 'before_work' && note != 'after_work') {
      parts.add(note);
    }
    if (amount is num && amount > 0) parts.add('₹${amount.toStringAsFixed(0)}');
    if (rating is num) parts.add('Rating · ${rating.toStringAsFixed(0)}/5');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      title: const Text(
        'Order history',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${events.length} service update${events.length == 1 ? '' : 's'}',
      ),
      children: events.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('No service updates recorded yet.'),
              ),
            ]
          : [
              for (final event in events)
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFFB70D5C),
                  ),
                  title: Text(_eventTitle(event)),
                  subtitle: Text(
                    [
                      _actor(event),
                      _eventTime(event['occurredAt']),
                      _description(event),
                    ].where((part) => part.isNotEmpty).join(' · '),
                  ),
                ),
            ],
    ),
  );
}

String _humanizeQuickCareEvent(String type) {
  final normalized = type
      .replaceFirst(RegExp(r'^quick_care_'), '')
      .replaceAll('_', ' ')
      .trim();
  if (normalized.isEmpty) return 'Service update';
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

class _QuickCareEvidenceSection extends StatelessWidget {
  const _QuickCareEvidenceSection({required this.evidence});

  final List<Map<String, dynamic>> evidence;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      title: const Text(
        'Quick Care photos and voice notes',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      children: [
        for (final item in evidence)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['kind'] == 'audio' ? 'Voice note' : 'Photo'} · ${item['note'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (item['expired'] == true)
                  Text(
                    'Media removed after the 7-day retention period · ${item['expiredAt'] ?? ''}',
                  )
                else if (item['kind'] == 'photo' || item['kind'] == 'audio')
                  _QuickCareEvidenceMedia(item: item)
                else
                  const Text(
                    'Evidence preview unavailable. Refresh the order details to retry.',
                  ),
                if (item['expired'] != true) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['keepPermanently'] == true ||
                            item['retentionLabel'] == 'permanent'
                        ? 'Wardrobe Management evidence is retained for the service record.'
                        : 'Evidence is retained for 7 days after service closure.',
                    style: const TextStyle(color: Color(0xFF777286)),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

class _QuickCareEvidenceMedia extends StatelessWidget {
  const _QuickCareEvidenceMedia({required this.item});

  final Map<String, dynamic> item;

  Future<String> _downloadUrl() async {
    final path = item['storagePath']?.toString().trim() ?? '';
    if (path.isNotEmpty) {
      try {
        return await FirebaseStorage.instance.ref(path).getDownloadURL();
      } catch (_) {
        // The Helpdesk signed URL remains a fallback for existing uploads.
      }
    }
    return item['previewUrl']?.toString() ?? '';
  }

  Future<Uint8List?> _photoBytes() async {
    final path = item['storagePath']?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref(path).getData(15 * 1024 * 1024);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (item['kind'] == 'audio') {
      return FutureBuilder<String>(
        future: _downloadUrl(),
        builder: (context, snapshot) {
          final url = snapshot.data?.trim() ?? '';
          if (url.isEmpty) {
            return const Text(
              'Evidence preview unavailable. Refresh the order details to retry.',
            );
          }
          return Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play voice note'),
            ),
          );
        },
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _photoBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        final fallbackUrl = item['previewUrl']?.toString() ?? '';
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (bytes == null && fallbackUrl.isEmpty) {
          return const Text(
            'Evidence preview unavailable. Refresh the order details to retry.',
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: bytes != null
              ? Image.memory(
                  bytes,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  fallbackUrl,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Text('Photo preview unavailable.'),
                ),
        );
      },
    );
  }
}
