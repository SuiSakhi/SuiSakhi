import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/order_lifecycle_service.dart';
import '../../widgets/orders/order_tracking_tag.dart';
import '../../widgets/orders/pickup_photo_attachment_button.dart';

class OwnerOrderRoutingScreen extends StatefulWidget {
  const OwnerOrderRoutingScreen({super.key});

  @override
  State<OwnerOrderRoutingScreen> createState() =>
      _OwnerOrderRoutingScreenState();
}

class _OwnerOrderRoutingScreenState extends State<OwnerOrderRoutingScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _pinFilter = '';
  String _statusFilter = 'All';
  String? _error;

  static const _filters = [
    'All',
    'Waiting',
    'Offered',
    'Accepted',
    'Finalized',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getAdminOrderRoutingQueue')
          .call(<String, dynamic>{'limit': 500});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final rows = (payload['orders'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      rows.sort(
        (a, b) => _number(b['orderDate']).compareTo(_number(a['orderDate'])),
      );
      if (!mounted) return;
      setState(() {
        _orders = rows;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.code == 'permission-denied'
            ? 'Configured Admin access is required to view order routing.'
            : 'Could not load order routing. ${error.message ?? 'Please retry.'}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load order routing. Please retry.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final pin = _pinFilter.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return _orders.where((order) {
      final status = (order['assignmentStatus'] ?? '').toString();
      final matchesStatus = switch (_statusFilter) {
        'Waiting' => [
          'searching',
          'queued_for_dispatch',
          'needs_admin_follow_up',
        ].contains(status),
        'Offered' => status == 'offered',
        'Accepted' => status == 'awaiting_customer_decision',
        'Finalized' => status == 'finalized',
        _ => true,
      };
      final orderPin = (order['deliveryPincode'] ?? '')
          .toString()
          .toUpperCase();
      final matchesPin = pin.isEmpty || orderPin.contains(pin);
      return matchesStatus && matchesPin;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByPin(
    List<Map<String, dynamic>> orders,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final order in orders) {
      final pin = (order['deliveryPincode'] ?? '').toString().trim();
      grouped
          .putIfAbsent(pin.isEmpty ? 'PIN missing' : pin, () => [])
          .add(order);
    }
    return grouped;
  }

  Future<void> _manageOrder(Map<String, dynamic> order) async {
    final orderId = (order['orderId'] ?? '').toString();
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getAdminOrderRoutingCandidates')
          .call(<String, dynamic>{'orderId': orderId});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final candidates = _mapList(payload['candidates']);
      final overrideCandidates = _mapList(payload['overrideCandidates']);
      final currentOffer = payload['currentOffer'] is Map
          ? Map<String, dynamic>.from(payload['currentOffer'] as Map)
          : null;
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.background,
        builder: (sheetContext) => _RoutingCandidatesSheet(
          order: order,
          candidates: candidates,
          overrideCandidates: overrideCandidates,
          currentOffer: currentOffer,
          onSavePriority: (ordered) => _savePriority(orderId, ordered),
          onSendOffer: (candidate, {required manualOverride, reason}) =>
              _sendOffer(
                orderId,
                candidate,
                manualOverride: manualOverride,
                reason: reason,
              ),
        ),
      );
      if (mounted) await _loadOrders();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not load Tailor routing options.');
    } catch (_) {
      _showMessage('Could not load Tailor routing options. Please retry.');
    }
  }

  Future<void> _savePriority(
    String orderId,
    List<Map<String, dynamic>> ordered,
  ) async {
    await FirebaseFunctions.instance
        .httpsCallable('updateTailorRoutingPriority')
        .call({
          'orderId': orderId,
          'orderedTailors': ordered
              .map(
                (item) => {
                  'accountId': item['accountId'],
                  'profileId': item['profileId'],
                },
              )
              .toList(),
        });
    _showMessage('PIN priority order saved.');
  }

  Future<void> _sendOffer(
    String orderId,
    Map<String, dynamic> candidate, {
    required bool manualOverride,
    String? reason,
  }) async {
    await FirebaseFunctions.instance
        .httpsCallable('sendAdminTailorOrderOffer')
        .call({
          'orderId': orderId,
          'accountId': candidate['accountId'],
          'profileId': candidate['profileId'],
          'manualOverride': manualOverride,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        });
    _showMessage(
      'Offer sent to ${(candidate['displayName'] ?? 'Tailor').toString()}.',
    );
  }

  Future<void> _assignInboundPickup(Map<String, dynamic> order) async {
    final orderId = (order['orderId'] ?? '').toString();
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getAdminInboundPickupCandidates')
          .call(<String, dynamic>{'orderId': orderId});
      final payload = Map<String, dynamic>.from(result.data as Map);
      final candidates = _mapList(payload['candidates']);
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Assign inbound pickup'),
          content: SizedBox(
            width: double.maxFinite,
            child: candidates.isEmpty
                ? const Text(
                    'No eligible Tailor, Measurement Partner, or Delivery Partner is available for this order’s PIN.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, index) {
                      final candidate = candidates[index];
                      final phone = (candidate['contactPhone'] ?? '')
                          .toString();
                      final partnerType =
                          (candidate['partnerType'] ?? 'deliveryPartner')
                              .toString();
                      final partnerLabel = switch (partnerType) {
                        'tailor' => 'Tailor Partner',
                        'measurementPartner' => 'Measurement Partner',
                        _ => 'Delivery Partner',
                      };
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (candidate['displayName'] ?? partnerLabel).toString(),
                        ),
                        subtitle: Text(
                          phone.isEmpty
                              ? '$partnerLabel · Contact number unavailable'
                              : '$partnerLabel · $phone',
                        ),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await OrderLifecycleService.assignInboundPickupPartner(
        orderId: orderId,
        accountId: (selected['accountId'] ?? '').toString(),
        profileId: (selected['profileId'] ?? '').toString(),
        partnerType: (selected['partnerType'] ?? 'deliveryPartner').toString(),
      );
      _showMessage(
        'Pickup assigned to ${(selected['displayName'] ?? 'Partner').toString()}.',
      );
      await _loadOrders();
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found' &&
          (error.message == null ||
              error.message!.trim().toUpperCase() == 'NOT_FOUND')) {
        _showMessage(
          'Admin pickup routing is not deployed in this Firebase project. Deploy getAdminInboundPickupCandidates and assignInboundPickupPartner, then retry.',
        );
      } else {
        _showMessage(error.message ?? 'Could not assign the pickup.');
      }
    } catch (_) {
      _showMessage('Could not load pickup Partners. Please retry.');
    }
  }

  Future<void> _assignOutboundHandover(Map<String, dynamic> order) async {
    final orderId = (order['orderId'] ?? '').toString();
    try {
      final candidates =
          await OrderLifecycleService.getAdminOutboundHandoverCandidates(
            orderId,
          );
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Assign return delivery'),
          content: SizedBox(
            width: double.maxFinite,
            child: candidates.isEmpty
                ? const Text(
                    'No active Tailor, Measurement Partner, or Delivery Partner can deliver to this order’s PIN.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, index) {
                      final candidate = candidates[index];
                      final phone = (candidate['contactPhone'] ?? '')
                          .toString();
                      final partnerType =
                          (candidate['partnerType'] ?? 'deliveryPartner')
                              .toString();
                      final role = switch (partnerType) {
                        'tailor' => 'Tailor Partner',
                        'measurementPartner' => 'Measurement Partner',
                        _ => 'Delivery Partner',
                      };
                      final samePickup =
                          candidate['accountId'] ==
                              order['inboundPickupPartnerAccountId'] &&
                          candidate['profileId'] ==
                              order['inboundPickupPartnerProfileId'];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${(candidate['displayName'] ?? role).toString()}${samePickup ? ' · Pickup partner' : ''}',
                        ),
                        subtitle: Text(
                          phone.isEmpty
                              ? '$role · Contact unavailable'
                              : '$role · $phone',
                        ),
                        onTap: () => Navigator.pop(dialogContext, candidate),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await OrderLifecycleService.assignAdminOutboundHandoverPartner(
        orderId: orderId,
        accountId: (selected['accountId'] ?? '').toString(),
        profileId: (selected['profileId'] ?? '').toString(),
        partnerType: (selected['partnerType'] ?? 'deliveryPartner').toString(),
      );
      _showMessage(
        'Return delivery assigned to ${(selected['displayName'] ?? 'Partner').toString()}. Customer delivery PIN is ready.',
      );
      await _loadOrders();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(
        error.code == 'not-found'
            ? 'Return-delivery assignment Functions are not deployed to this Firebase project yet. Deploy the latest Functions and retry.'
            : error.message ?? 'Could not assign return delivery.',
      );
    } catch (_) {
      _showMessage('Could not load delivery Partners. Please retry.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final groups = _groupByPin(filtered);
    final pins = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'PIN missing') return 1;
        if (b == 'PIN missing') return -1;
        return a.compareTo(b);
      });
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Order Routing by PIN'),
        actions: [
          IconButton(
            onPressed: _editOrderPolicy,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Order policy',
          ),
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review every order by delivery area, adjust Tailor priority, and route one offer at a time.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() => _pinFilter = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    hintText: 'Search by delivery PIN',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _pinFilter.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() => _pinFilter = ''),
                            icon: const Icon(Icons.clear_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _statusFilter == filter,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = filter),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _statusFilter == filter
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _messageState(
                    _error!,
                    action: 'Retry',
                    onPressed: _loadOrders,
                  )
                : filtered.isEmpty
                ? _messageState('No production orders match this filter.')
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
                      itemCount: pins.length,
                      itemBuilder: (context, index) {
                        final pin = pins[index];
                        final orders = groups[pin]!;
                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded:
                                _pinFilter.isNotEmpty || index == 0,
                            leading: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              pin == 'PIN missing' ? pin : 'PIN $pin',
                              style: AppTextStyles.titleLarge,
                            ),
                            subtitle: Text(
                              '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
                              style: AppTextStyles.bodySmall,
                            ),
                            children: orders.map(_orderTile).toList(),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOrderPolicy() async {
    var policy = const OrderLifecyclePolicy();
    try {
      policy = await OrderLifecyclePolicy.fetch();
    } catch (_) {}
    if (!mounted) return;
    final feeController = TextEditingController(
      text: policy.cancellationFeePercent.toStringAsFixed(
        policy.cancellationFeePercent % 1 == 0 ? 0 : 2,
      ),
    );
    final warrantyController = TextEditingController(
      text: '${policy.warrantyDays}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order policy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Cancellation fee (%)',
                helperText:
                    'Applies to finalized orders cancelled before stitching.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: warrantyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Warranty period (days)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) {
      feeController.dispose();
      warrantyController.dispose();
      return;
    }
    final feePercent = double.tryParse(feeController.text.trim());
    final warrantyDays = int.tryParse(warrantyController.text.trim());
    feeController.dispose();
    warrantyController.dispose();
    if (feePercent == null ||
        feePercent < 0 ||
        feePercent > 100 ||
        warrantyDays == null ||
        warrantyDays < 1 ||
        warrantyDays > 365) {
      _showMessage(
        'Enter a fee from 0 to 100% and a warranty from 1 to 365 days.',
      );
      return;
    }
    try {
      await OrderLifecycleService.savePolicy(
        OrderLifecyclePolicy(
          cancellationFeePercent: feePercent,
          warrantyDays: warrantyDays,
        ),
      );
      _showMessage(
        'Order policy saved. New cancellations and deliveries will use it.',
      );
    } on FirebaseException catch (error) {
      _showMessage(error.message ?? 'Could not save the order policy.');
    } catch (_) {
      _showMessage('Could not save the order policy. Please retry.');
    }
  }

  Widget _orderTile(Map<String, dynamic> order) {
    final id = (order['orderId'] ?? '').toString();
    final status = (order['assignmentStatus'] ?? 'searching').toString();
    final offer = order['currentOffer'] is Map
        ? Map<String, dynamic>.from(order['currentOffer'] as Map)
        : null;
    final history = _mapList(order['recentEvents'])
        .where(
          (event) => _historyLabel((event['type'] ?? '').toString()) != null,
        )
        .take(4)
        .toList();
    final offeredTo = offer?['targetDisplayName']?.toString();
    final partner = order['assignedTailor'] is Map
        ? Map<String, dynamic>.from(order['assignedTailor'] as Map)
        : offer?['targetProfile'] is Map
        ? Map<String, dynamic>.from(offer!['targetProfile'] as Map)
        : null;
    final partnerPhone =
        (partner?['contactPhone'] ?? offer?['targetContactPhone'] ?? '')
            .toString();
    final date = _date(order['orderDate']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (order['dressType'] ?? 'Tailoring order').toString(),
                    style: AppTextStyles.headlineSmall,
                  ),
                ),
                _statusBadge(status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              (order['customerName']?.toString().trim().isNotEmpty == true)
                  ? 'For ${order['customerName']}'
                  : 'Order ${id.length > 8 ? id.substring(0, 8) : id}',
              style: AppTextStyles.bodyMedium,
            ),
            if ((order['customerPhone'] ?? '').toString().isNotEmpty)
              Text(
                'Customer · ${order['customerPhone']}',
                style: AppTextStyles.bodySmall,
              ),
            Text(
              '${order['cityName'] ?? ''}${order['stateName'] == null ? '' : ', ${order['stateName']}'}  ·  ${_formatDate(date)}',
              style: AppTextStyles.bodySmall,
            ),
            if ((order['orderTrackingId'] ?? '').toString().isNotEmpty)
              Text(
                'Order ID · ${order['orderTrackingId']}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            OrderTrackingTag.button(
              context,
              order['orderTrackingId']?.toString(),
            ),
            if ((order['assignedTailorName'] ?? '')
                .toString()
                .trim()
                .isNotEmpty)
              Text(
                'Tailor · ${order['assignedTailorName']}',
                style: AppTextStyles.bodySmall,
              ),
            if (partnerPhone.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _callPartnerNumber(context, partnerPhone),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text('Call Tailor · $partnerPhone'),
                ),
              ),
            if (partner != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showPartnerProfileSheet(context, partner),
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('View Tailor profile and other contacts'),
                ),
              ),
            if ((order['designTemplateTitle'] ?? '').toString().isNotEmpty)
              Text(
                'Design · ${order['designTemplateTitle']}',
                style: AppTextStyles.bodySmall,
              ),
            if ((order['fabricChoice'] ?? '').toString().isNotEmpty)
              Text(
                'Material · ${order['fabricChoice']}',
                style: AppTextStyles.bodySmall,
              ),
            if ((order['fabricDescription'] ?? '').toString().isNotEmpty)
              Text(
                'Material details · ${order['fabricDescription']}',
                style: AppTextStyles.bodySmall,
              ),
            Text(
              'Stitching estimate · ₹${_number(order['price']).toStringAsFixed(0)} · Payment ${order['paymentStatus'] ?? 'unpaid'}',
              style: AppTextStyles.bodySmall,
            ),
            if (_number(order['balanceAmount']) > 0)
              Text(
                'Remaining · ₹${_number(order['balanceAmount']).toStringAsFixed(0)}',
                style: AppTextStyles.bodySmall,
              ),
            if (_date(order['expectedReadyAt']).millisecondsSinceEpoch > 0)
              Text(
                'Expected completion · ${_formatDate(_date(order['expectedReadyAt']))}',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if ((order['orderStatus'] ?? '').toString().isNotEmpty)
              Text(
                'Order stage · ${(order['orderStatus'] as String).replaceAll('_', ' ')}',
                style: AppTextStyles.bodySmall,
              ),
            Text(
              'Measurement · ${(order['measurementStatus'] ?? 'not started').toString().replaceAll('_', ' ')}',
              style: AppTextStyles.bodySmall,
            ),
            Text(
              'Inbound pickup · ${_inboundPickupLabel(order['inboundPickupStatus'])}',
              style: AppTextStyles.bodySmall,
            ),
            if (order['inboundPickupPartner'] is Map)
              Text(
                'Pickup Partner · ${(order['inboundPickupPartner'] as Map)['displayName'] ?? 'Delivery Partner'}'
                '${((order['inboundPickupPartner'] as Map)['contactPhone'] ?? '').toString().isEmpty ? '' : ' · ${(order['inboundPickupPartner'] as Map)['contactPhone']}'}',
                style: AppTextStyles.bodySmall,
              ),
            if ((order['inboundPickupPhotoPath'] ?? '').toString().isNotEmpty)
              PickupPhotoAttachmentButton(
                storagePath: order['inboundPickupPhotoPath'].toString(),
              ),
            if (['advancePaid', 'fullyPaid'].contains(order['paymentStatus']) &&
                [
                  'awaiting_assignment',
                  'assigned',
                ].contains(order['inboundPickupStatus']))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _assignInboundPickup(order),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      order['inboundPickupStatus'] == 'assigned'
                          ? 'Assign / change pickup partner'
                          : 'Assign pickup partner',
                    ),
                  ),
                ),
              ),
            if (order['assignmentStatus'] == 'finalized' &&
                order['orderStatus'] == 'readyForPickup' &&
                order['paymentStatus'] == 'fullyPaid' &&
                [
                  'awaiting_assignment',
                  'assigned',
                ].contains(order['outboundHandoverStatus'])) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Return delivery · ${order['outboundHandoverStatus'] == 'assigned' ? 'partner assigned' : 'awaiting assignment'}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _assignOutboundHandover(order),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      order['outboundHandoverStatus'] == 'assigned'
                          ? 'Assign / change delivery partner'
                          : 'Assign delivery partner',
                    ),
                  ),
                ),
              ),
            ],
            if (status == 'offered' && offeredTo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Offer active${offeredTo.isEmpty ? '' : ' · $offeredTo'} · expires ${_formatDateTime(_date(offer?['expiresAt']))}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            if ((order['adminQueueReason'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _reasonLabel(order['adminQueueReason'].toString()),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            if (_number(order['cancellationFeeAmount']) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Cancellation fee · ₹${_number(order['cancellationFeeAmount']).toStringAsFixed(0)} (${_number(order['cancellationFeePercent']).toStringAsFixed(_number(order['cancellationFeePercent']) % 1 == 0 ? 0 : 2)}%) · refund due ₹${_number(order['cancellationRefundDue']).toStringAsFixed(0)}${order['cancellationFeeWaived'] == true ? ' · waived' : ''}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            if ((order['warrantyClaimStatus'] ?? '').toString().isNotEmpty &&
                order['warrantyClaimStatus'] != 'available')
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'Warranty claim · ${order['warrantyClaimStatus']}${(order['warrantyIssueDescription'] ?? '').toString().isEmpty ? '' : ' · ${order['warrantyIssueDescription']}'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            if ((order['warrantyResolution'] ?? '').toString().isNotEmpty)
              Text(
                'Resolution · ${order['warrantyResolution']}',
                style: AppTextStyles.bodySmall,
              ),
            if (history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'History · ${history.map((event) => _historyLabel((event['type'] ?? '').toString())).join('  →  ')}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showOrderDetailsSheet(context, order),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Order details'),
              ),
            ),
            if ([
              'searching',
              'queued_for_dispatch',
              'needs_admin_follow_up',
              'offered',
            ].contains(status))
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _manageOrder(order),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage routing'),
                ),
              ),
            if (order['orderStatus'] == 'cancelled' &&
                _number(order['cancellationFeeAmount']) > 0 &&
                order['cancellationFeeWaived'] != true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _waiveCancellationFee(id),
                  icon: const Icon(Icons.money_off_rounded, size: 18),
                  label: const Text('Waive fee'),
                ),
              ),
            if (order['orderStatus'] == 'delivered' &&
                order['warrantyClaimStatus'] == 'open')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _resolveWarrantyIssue(id),
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('Resolve warranty issue'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _waiveCancellationFee(String orderId) async {
    try {
      await OrderLifecycleService.waiveCancellationFee(orderId);
      _showMessage(
        'Fee waived. Refund due has been updated for Admin follow-up.',
      );
      await _loadOrders();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not waive this fee.');
    } catch (_) {
      _showMessage('Could not waive this fee. Please retry.');
    }
  }

  Future<void> _resolveWarrantyIssue(String orderId) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve warranty issue'),
        content: TextField(
          controller: controller,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Resolution / follow-up note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark resolved'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      await OrderLifecycleService.resolveWarrantyIssue(
        orderId: orderId,
        resolution: controller.text.trim(),
      );
      _showMessage('Warranty issue marked resolved.');
      await _loadOrders();
    } on FirebaseFunctionsException catch (error) {
      _showMessage(error.message ?? 'Could not resolve this warranty issue.');
    } catch (_) {
      _showMessage('Could not resolve this warranty issue. Please retry.');
    } finally {
      controller.dispose();
    }
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'offered' => AppColors.primary,
      'awaiting_customer_decision' => AppColors.success,
      'finalized' => AppColors.success,
      'needs_admin_follow_up' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _messageState(
    String message, {
    String? action,
    VoidCallback? onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 46, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ],
      ),
    ),
  );
}

class _RoutingCandidatesSheet extends StatefulWidget {
  const _RoutingCandidatesSheet({
    required this.order,
    required this.candidates,
    required this.overrideCandidates,
    required this.currentOffer,
    required this.onSavePriority,
    required this.onSendOffer,
  });

  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> candidates;
  final List<Map<String, dynamic>> overrideCandidates;
  final Map<String, dynamic>? currentOffer;
  final Future<void> Function(List<Map<String, dynamic>>) onSavePriority;
  final Future<void> Function(
    Map<String, dynamic>, {
    required bool manualOverride,
    String? reason,
  })
  onSendOffer;

  @override
  State<_RoutingCandidatesSheet> createState() =>
      _RoutingCandidatesSheetState();
}

class _RoutingCandidatesSheetState extends State<_RoutingCandidatesSheet> {
  late List<Map<String, dynamic>> _priority;
  bool _saving = false;
  String? _busyProfileId;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _priority = widget.candidates
        .map((candidate) => Map<String, dynamic>.from(candidate))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSavePriority(_priority);
    } on FirebaseFunctionsException catch (error) {
      _message(error.message ?? 'Could not save priority.');
    } catch (_) {
      _message('Could not save priority. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _send(
    Map<String, dynamic> candidate, {
    required bool override,
  }) async {
    if (widget.currentOffer != null) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace the active offer?'),
          content: const Text(
            'The current offer will be withdrawn before the selected Tailor receives this order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep current offer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace offer'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    String? reason;
    if (override) {
      reason = await _askOverrideReason();
      if (reason == null) return;
    }
    setState(() {
      _busyProfileId = candidate['profileId']?.toString();
      _sendError = null;
    });
    try {
      await widget.onSendOffer(
        candidate,
        manualOverride: override,
        reason: reason,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(
          () =>
              _sendError = error.message ?? 'Could not send the Tailor offer.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _sendError = 'Could not send the Tailor offer. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<String?> _askOverrideReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Manual routing override'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use this after confirming the arrangement directly with the Customer and Tailor.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for override',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 5) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _priority.length) return;
    setState(() {
      final item = _priority.removeAt(index);
      _priority.insert(target, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pin = (widget.order['deliveryPincode'] ?? '').toString();
    final currentCandidates = widget.overrideCandidates.where(
      (candidate) =>
          candidate['accountId'] == widget.currentOffer?['targetAccountId'] &&
          candidate['profileId'] == widget.currentOffer?['targetProfileId'],
    );
    final currentName = currentCandidates.isEmpty
        ? null
        : currentCandidates.first['displayName']?.toString();
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'PIN $pin · Tailor priority',
                        style: AppTextStyles.headlineMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Default order follows Tailor registration date, oldest first. Admin changes apply to this PIN.',
                  style: AppTextStyles.bodySmall,
                ),
                if (widget.currentOffer != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current offer${currentName == null ? '' : ' · $currentName'} · expires ${_formatDateTime(_date(widget.currentOffer?['expiresAt']))}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showOrderDetailsSheet(context, widget.order),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('View full order details'),
                  ),
                ),
                Text('PIN-matched Tailors', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Offline Tailors keep their priority and are skipped until online.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_sendError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _sendError!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                if (_priority.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No approved Tailor currently covers this PIN.',
                    ),
                  ),
                ...List.generate(_priority.length, (index) {
                  final candidate = _priority[index];
                  final online = candidate['availabilityStatus'] == 'available';
                  final busy =
                      _busyProfileId == candidate['profileId']?.toString();
                  return Card(
                    color: AppColors.surface,
                    child: ListTile(
                      onTap: () => _showPartnerProfileSheet(context, candidate),
                      leading: CircleAvatar(
                        backgroundColor: online
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.surfaceVariant,
                        child: Text(
                          '${index + 1}',
                          style: AppTextStyles.labelLarge,
                        ),
                      ),
                      title: Text(
                        (candidate['displayName'] ?? 'Tailor').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${online ? 'Online' : 'Offline'} · PIN matched${(candidate['contactPhone'] ?? '').toString().isEmpty ? '' : ' · ${candidate['contactPhone']}'}${_stringList(candidate['additionalContactPhones']).isEmpty ? '' : ' · +${_stringList(candidate['additionalContactPhones']).length} more'} · tap for profile',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: online
                              ? AppColors.success
                              : AppColors.textHint,
                        ),
                      ),
                      trailing: SizedBox(
                        width: width * 0.40,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: index == 0
                                  ? null
                                  : () => _move(index, -1),
                              icon: const Icon(Icons.keyboard_arrow_up_rounded),
                              tooltip: 'Move up',
                            ),
                            IconButton(
                              onPressed: index == _priority.length - 1
                                  ? null
                                  : () => _move(index, 1),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              tooltip: 'Move down',
                            ),
                            IconButton(
                              onPressed:
                                  online && _busyProfileId == null
                                  ? () => _send(candidate, override: false)
                                  : null,
                              icon: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.send_rounded,
                                      color: AppColors.primary,
                                    ),
                              tooltip: online
                                  ? 'Send offer'
                                  : 'Tailor is offline',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (_priority.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving…' : 'Save PIN priority'),
                  ),
                ],
                const SizedBox(height: 20),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Manual override · all approved Tailors',
                    style: AppTextStyles.headlineSmall,
                  ),
                  subtitle: Text(
                    'Use after confirming with the Customer and Tailor. It sends an offer the Tailor must accept, and can bypass automatic PIN/online priority. Offers can be sent at any time. A Customer decision deadline moves to the next opening if it would otherwise expire while ordering is closed.',
                    style: AppTextStyles.bodySmall,
                  ),
                  children: widget.overrideCandidates.map((candidate) {
                    final online =
                        candidate['availabilityStatus'] == 'available';
                    final matches = candidate['coverageMatches'] == true;
                    if (online && matches) return const SizedBox.shrink();
                    final busy =
                        _busyProfileId == candidate['profileId']?.toString();
                    final coverage = matches
                        ? 'PIN matched'
                        : 'Outside automatic PIN coverage';
                    return ListTile(
                      onTap: () => _showPartnerProfileSheet(context, candidate),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        (candidate['displayName'] ?? 'Tailor').toString(),
                      ),
                      subtitle: Text(
                        '$coverage · ${online ? 'online' : 'offline'}${(candidate['contactPhone'] ?? '').toString().isEmpty ? '' : ' · ${candidate['contactPhone']}'}${_stringList(candidate['additionalContactPhones']).isEmpty ? '' : ' · +${_stringList(candidate['additionalContactPhones']).length} more'} · tap for profile',
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: TextButton(
                        onPressed:
                            _busyProfileId != null
                            ? null
                            : () => _send(candidate, override: true),
                        child: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Override'),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPartnerProfileSheet(
  BuildContext context,
  Map<String, dynamic> profile,
) async {
  final address = profile['businessAddress'] is Map
      ? Map<String, dynamic>.from(profile['businessAddress'] as Map)
      : <String, dynamic>{};
  final primaryPhone = (profile['contactPhone'] ?? '').toString().trim();
  final pincodes = _stringList(profile['serviceAreaPincodes']);
  final city = (profile['city'] ?? '').toString().trim();
  final state = (profile['state'] ?? '').toString().trim();
  final coverageMode = (profile['serviceCoverageMode'] ?? '').toString();
  final registrationAt = _date(profile['registrationAt']);
  final addressText =
      [
            address['addressLine1'],
            address['addressLine2'],
            address['locality'],
            address['city'],
            address['state'],
            address['pincode'],
          ]
          .map((value) => (value ?? '').toString().trim())
          .where((value) => value.isNotEmpty)
          .join(', ');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.86,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (profile['displayName'] ?? 'Tailor profile').toString(),
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    [
                      if ((profile['partnerType'] ?? '').toString().isNotEmpty)
                        (profile['partnerType'] ?? '').toString(),
                      if ((profile['operationalStatus'] ?? '')
                          .toString()
                          .isNotEmpty)
                        (profile['operationalStatus'] ?? '').toString(),
                      if ((profile['availabilityStatus'] ?? '')
                          .toString()
                          .isNotEmpty)
                        (profile['availabilityStatus'] ?? '').toString() ==
                                'available'
                            ? 'Online'
                            : 'Offline',
                    ].join(' · '),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _profileSectionTitle('Contact'),
                  if ((profile['contactName'] ?? '').toString().isNotEmpty)
                    _profileInfo(
                      'Contact person',
                      profile['contactName'].toString(),
                    ),
                  if (primaryPhone.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.call_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(primaryPhone),
                      subtitle: const Text('Primary number · tap to call'),
                      onTap: () => _callPartnerNumber(context, primaryPhone),
                    ),
                  ..._stringList(profile['additionalContactPhones']).map(
                    (phone) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.phone_in_talk_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(phone),
                      subtitle: const Text('Additional number · tap to call'),
                      onTap: () => _callPartnerNumber(context, phone),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final numbers = await _editAdditionalContactNumbers(
                        sheetContext,
                        profile,
                      );
                      if (numbers == null || !sheetContext.mounted) return;
                      final accountId = (profile['accountId'] ?? '')
                          .toString()
                          .trim();
                      final profileId = (profile['profileId'] ?? '')
                          .toString()
                          .trim();
                      if (accountId.isEmpty || profileId.isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Partner profile identity is missing. Refresh the routing list and try again.',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        await FirebaseFirestore.instance
                            .collection('accounts')
                            .doc(accountId)
                            .collection('profiles')
                            .doc(profileId)
                            .update({
                              'additionalContactNumbers': numbers,
                              'additionalContactNumbersUpdatedAt':
                                  FieldValue.serverTimestamp(),
                              'additionalContactNumbersUpdatedByUid':
                                  FirebaseAuth.instance.currentUser?.uid,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        if (!sheetContext.mounted) return;
                        profile['additionalContactPhones'] = numbers;
                        profile['additionalContactNumbers'] = numbers;
                        setSheetState(() {});
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Additional contact numbers saved.'),
                          ),
                        );
                      } catch (_) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save contact numbers. Check Admin access and retry.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit additional contact numbers'),
                  ),
                  if ((profile['email'] ?? '').toString().isNotEmpty)
                    _profileInfo('Email', profile['email'].toString()),
                  _profileSectionTitle('Business and coverage'),
                  if ((profile['businessName'] ?? '').toString().isNotEmpty)
                    _profileInfo(
                      'Business',
                      profile['businessName'].toString(),
                    ),
                  if ((profile['workshopType'] ?? '').toString().isNotEmpty)
                    _profileInfo(
                      'Workshop type',
                      profile['workshopType'].toString(),
                    ),
                  if (addressText.isNotEmpty)
                    _profileInfo('Business address', addressText),
                  _profileInfo(
                    'Service city',
                    [city, state].where((part) => part.isNotEmpty).join(', '),
                  ),
                  _profileInfo(
                    'PIN coverage',
                    coverageMode == 'any'
                        ? 'ANY${city.isEmpty ? '' : ' in $city'}'
                        : pincodes.join(', '),
                  ),
                  if (_number(profile['experienceYears']) > 0)
                    _profileInfo(
                      'Experience',
                      '${_number(profile['experienceYears']).toStringAsFixed(_number(profile['experienceYears']) % 1 == 0 ? 0 : 1)} years',
                    ),
                  if (_number(profile['teamSize']) > 0)
                    _profileInfo(
                      'Team size',
                      '${_number(profile['teamSize']).toInt()}',
                    ),
                  if (_number(profile['normalDailyCapacity']) > 0)
                    _profileInfo(
                      'Normal daily capacity',
                      '${_number(profile['normalDailyCapacity']).toInt()} orders/day',
                    ),
                  if (_number(profile['peakDailyCapacity']) > 0)
                    _profileInfo(
                      'Peak daily capacity',
                      '${_number(profile['peakDailyCapacity']).toInt()} orders/day',
                    ),
                  if (_stringList(profile['machineCodes']).isNotEmpty)
                    _profileInfo(
                      'Equipment',
                      _stringList(profile['machineCodes']).join(', '),
                    ),
                  _profileSectionTitle('Tailoring capabilities'),
                  if (_stringList(profile['capabilityCodes']).isNotEmpty)
                    _profileInfo(
                      'Selected services',
                      _stringList(
                        profile['capabilityCodes'],
                      ).map((code) => code.replaceAll('_', ' ')).join(', '),
                    ),
                  if (_stringList(
                    profile['additionalCapabilityDescriptions'],
                  ).isNotEmpty)
                    _profileInfo(
                      'Additional skills',
                      _stringList(
                        profile['additionalCapabilityDescriptions'],
                      ).join(', '),
                    ),
                  _profileSectionTitle('Approval'),
                  _profileInfo(
                    'Approval status',
                    (profile['approvalStatus'] ?? 'approved').toString(),
                  ),
                  _profileInfo(
                    'KYC',
                    (profile['kycStatus'] ?? 'verified').toString(),
                  ),
                  if (registrationAt.millisecondsSinceEpoch > 0)
                    _profileInfo('Registered', _formatDate(registrationAt)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<List<String>?> _editAdditionalContactNumbers(
  BuildContext context,
  Map<String, dynamic> profile,
) async {
  final controller = TextEditingController(
    text: _stringList(profile['additionalContactPhones']).join(', '),
  );
  final formKey = GlobalKey<FormState>();
  try {
    return await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Additional contact numbers'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone numbers',
              hintText: '9876543210, +14155550123',
              helperText: 'Separate numbers with commas. Leave blank to clear.',
            ),
            validator: (value) =>
                _normalizeAdditionalPhones(
                      value ?? '',
                      (profile['contactPhone'] ?? '').toString(),
                    ) ==
                    null
                ? 'Enter 10 digit Indian numbers or international numbers with +.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final numbers = _normalizeAdditionalPhones(
                controller.text,
                (profile['contactPhone'] ?? '').toString(),
              );
              if (numbers != null) Navigator.pop(dialogContext, numbers);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

List<String>? _normalizeAdditionalPhones(String value, String primaryPhone) {
  final numbers = <String>[];
  final seen = <String>{};
  final primaryDigits = primaryPhone.replaceAll(RegExp(r'\D'), '');
  if (primaryDigits.isNotEmpty) seen.add(primaryDigits);
  final entries = value
      .split(RegExp(r'[,;\n]'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty);
  for (final entry in entries) {
    final compact = entry.replaceAll(RegExp(r'[\s().-]'), '');
    final normalized = RegExp(r'^\d{10}$').hasMatch(compact)
        ? '+91$compact'
        : RegExp(r'^\+\d{8,15}$').hasMatch(compact)
        ? compact
        : null;
    if (normalized == null) return null;
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    if (seen.add(digits)) numbers.add(normalized);
  }
  return numbers;
}

Future<void> _showOrderDetailsSheet(
  BuildContext context,
  Map<String, dynamic> order,
) async {
  final measurements = order['measurements'] is Map
      ? Map<String, dynamic>.from(order['measurements'] as Map)
      : <String, dynamic>{};
  final imageUrl = (order['designImageUrl'] ?? '').toString().trim();
  final fabricImageUrl = (order['fabricImageUrl'] ?? '').toString().trim();
  final id = (order['orderId'] ?? '').toString();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order details · ${id.length > 8 ? id.substring(0, 8) : id}',
                    style: AppTextStyles.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      imageUrl,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 100,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                _profileSectionTitle('Garment and design'),
                _profileInfo(
                  'Dress type',
                  order['dressType']?.toString() ?? '',
                ),
                _profileInfo(
                  'Occasion',
                  order['occasionCategory']?.toString() ?? '',
                ),
                _profileInfo('Fit', order['fit']?.toString() ?? ''),
                _profileInfo(
                  'Design',
                  order['designTemplateTitle']?.toString() ?? '',
                ),
                _profileInfo(
                  'Design notes',
                  order['designDescription']?.toString() ?? '',
                ),
                if ((order['accentColorHex'] ?? '').toString().isNotEmpty)
                  _profileInfo(
                    'Accent color',
                    order['accentColorHex'].toString(),
                  ),
                _profileSectionTitle('Material'),
                if (fabricImageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        fabricImageUrl,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          height: 80,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                _profileInfo(
                  'Selected material',
                  order['fabricChoice']?.toString() ?? '',
                ),
                _profileInfo(
                  'Material details',
                  order['fabricDescription']?.toString() ?? '',
                ),
                _profileSectionTitle('Customer and delivery'),
                _profileInfo(
                  'Order tracking ID',
                  order['orderTrackingId']?.toString() ?? '',
                ),
                _profileInfo(
                  'Measurement status',
                  order['measurementStatus']?.toString() ?? '',
                ),
                _profileInfo(
                  'Measurement method',
                  order['measurementMethod']?.toString() ?? '',
                ),
                _profileInfo(
                  'Measurement submission',
                  order['measurementSubmissionStatus']?.toString() ?? '',
                ),
                if (_date(
                      order['measurementAppointmentAt'],
                    ).millisecondsSinceEpoch >
                    0)
                  _profileInfo(
                    'Measurement appointment',
                    _formatDateTime(_date(order['measurementAppointmentAt'])),
                  ),
                _profileInfo(
                  'Video appointment link',
                  order['measurementAppointmentLink']?.toString() ?? '',
                ),
                _profileInfo(
                  'Measurement instructions',
                  order['measurementNotes']?.toString() ?? '',
                ),
                if (order['measurementPartner'] is Map) ...[
                  _profileSectionTitle('Measurement Partner'),
                  _profileInfo(
                    'Partner',
                    (order['measurementPartner'] as Map)['displayName']
                            ?.toString() ??
                        '',
                  ),
                  _profileInfo(
                    'Contact',
                    (order['measurementPartner'] as Map)['contactPhone']
                            ?.toString() ??
                        '',
                  ),
                ],
                if (order['measurementSubmittedValues'] is Map &&
                    (order['measurementSubmittedValues'] as Map)
                        .isNotEmpty) ...[
                  _profileSectionTitle('Submitted measurements'),
                  _profileInfo(
                    'Unit',
                    order['measurementSubmittedUnit']?.toString() ?? 'in',
                  ),
                  ...Map<String, dynamic>.from(
                    order['measurementSubmittedValues'] as Map,
                  ).entries.map(
                    (entry) => _profileInfo(
                      entry.key,
                      '${entry.value} ${order['measurementSubmittedUnit'] ?? 'in'}',
                    ),
                  ),
                  _profileInfo(
                    'Measurement Partner note',
                    order['measurementPartnerCompletionNote']?.toString() ?? '',
                  ),
                  if (_date(
                        order['measurementPartnerCompletedAt'],
                      ).millisecondsSinceEpoch >
                      0)
                    _profileInfo(
                      'Submitted at',
                      _formatDateTime(
                        _date(order['measurementPartnerCompletedAt']),
                      ),
                    ),
                ],
                if (_date(
                      order['measurementConfirmedAt'],
                    ).millisecondsSinceEpoch >
                    0)
                  _profileInfo(
                    'Tailor confirmed measurements',
                    _formatDateTime(_date(order['measurementConfirmedAt'])),
                  ),
                _profileInfo(
                  'Inbound pickup status',
                  order['inboundPickupStatus']?.toString() ?? '',
                ),
                if (order['inboundPickupPartner'] is Map) ...[
                  _profileSectionTitle('Inbound pickup Partner'),
                  _profileInfo(
                    'Partner',
                    (order['inboundPickupPartner'] as Map)['displayName']
                            ?.toString() ??
                        '',
                  ),
                  _profileInfo(
                    'Contact',
                    (order['inboundPickupPartner'] as Map)['contactPhone']
                            ?.toString() ??
                        '',
                  ),
                  ..._stringList(
                    (order['inboundPickupPartner']
                        as Map)['additionalContactPhones'],
                  ).map((phone) => _profileInfo('Alternate contact', phone)),
                ],
                _profileInfo(
                  'Return handover status',
                  order['outboundHandoverStatus']?.toString() ?? '',
                ),
                if (order['outboundHandoverPartner'] is Map) ...[
                  _profileSectionTitle('Return handover Partner'),
                  _profileInfo(
                    'Partner',
                    (order['outboundHandoverPartner'] as Map)['displayName']
                            ?.toString() ??
                        '',
                  ),
                  _profileInfo(
                    'Partner type',
                    order['outboundHandoverPartnerType']?.toString() ?? '',
                  ),
                  _profileInfo(
                    'Contact',
                    (order['outboundHandoverPartner'] as Map)['contactPhone']
                            ?.toString() ??
                        '',
                  ),
                ],
                _profileInfo(
                  'Customer',
                  order['customerName']?.toString() ?? '',
                ),
                _profileInfo(
                  'Customer phone',
                  order['customerPhone']?.toString() ?? '',
                ),
                _profileInfo(
                  'Delivery address',
                  order['deliveryAddress']?.toString() ?? '',
                ),
                _profileInfo(
                  'Delivery PIN',
                  order['deliveryPincode']?.toString() ?? '',
                ),
                _profileInfo(
                  'City and state',
                  [order['cityName'], order['stateName']]
                      .where(
                        (value) => value != null && value.toString().isNotEmpty,
                      )
                      .join(', '),
                ),
                if (measurements.isNotEmpty) ...[
                  _profileSectionTitle('Measurements'),
                  ...measurements.entries.map(
                    (entry) =>
                        _profileInfo(entry.key, entry.value?.toString() ?? ''),
                  ),
                ],
                if ((order['notes'] ?? '').toString().isNotEmpty) ...[
                  _profileSectionTitle('Customer notes'),
                  _profileInfo('Notes', order['notes'].toString()),
                ],
                if (_mapList(order['recentEvents']).isNotEmpty) ...[
                  _profileSectionTitle('Order timeline'),
                  ..._mapList(order['recentEvents']).map((event) {
                    final occurredAt = _date(event['occurredAt']);
                    final type = (event['type'] ?? '').toString();
                    final label =
                        _historyLabel(type) ?? type.replaceAll('_', ' ');
                    final actor = (event['actor'] ?? '').toString().trim();
                    return _profileInfo(
                      label,
                      '${_formatDateTime(occurredAt)}${actor.isEmpty ? '' : ' · $actor'}',
                    );
                  }),
                ],
                _profileSectionTitle('Estimate and progress'),
                _profileInfo(
                  'Stitching estimate',
                  '₹${_number(order['price']).toStringAsFixed(0)}',
                ),
                _profileInfo(
                  'Payment',
                  (order['paymentStatus'] ?? 'unpaid').toString(),
                ),
                _profileInfo(
                  'Order status',
                  (order['orderStatus'] ?? '').toString().replaceAll('_', ' '),
                ),
                _profileInfo(
                  'Assignment',
                  (order['assignmentStatus'] ?? '').toString().replaceAll(
                    '_',
                    ' ',
                  ),
                ),
                if (_date(order['expectedReadyAt']).millisecondsSinceEpoch > 0)
                  _profileInfo(
                    'Expected completion',
                    _formatDate(_date(order['expectedReadyAt'])),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _callPartnerNumber(BuildContext context, String phone) async {
  try {
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }
}

Widget _profileSectionTitle(String title) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 6),
  child: Text(title, style: AppTextStyles.headlineSmall),
);

Widget _profileInfo(String label, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: AppTextStyles.bodySmall),
        ),
        Expanded(
          child: SelectableText(normalized, style: AppTextStyles.bodyMedium),
        ),
      ],
    ),
  );
}

List<String> _stringList(dynamic value) => (value as List<dynamic>? ?? const [])
    .map((item) => item.toString().trim())
    .where((item) => item.isNotEmpty)
    .toList();

List<Map<String, dynamic>> _mapList(dynamic value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

double _number(dynamic value) => value is num ? value.toDouble() : 0;

DateTime _date(dynamic value) =>
    DateTime.fromMillisecondsSinceEpoch(value is num ? value.toInt() : 0);

String _formatDate(DateTime value) => value.millisecondsSinceEpoch == 0
    ? 'date unavailable'
    : '${value.day} ${_month(value.month)} ${value.year}';

String _formatDateTime(DateTime value) => value.millisecondsSinceEpoch == 0
    ? 'time unavailable'
    : '${value.toLocal().day} ${_month(value.toLocal().month)} · ${_clockTime(value.toLocal())}';

String _clockTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} ${value.hour < 12 ? 'AM' : 'PM'}';
}

String _month(int value) => const [
  '',
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
][value.clamp(0, 12).toInt()];

String _statusLabel(String value) => switch (value) {
  'queued_for_dispatch' => 'Queued',
  'searching' => 'Matching',
  'offered' => 'Offer sent',
  'needs_admin_follow_up' => 'Admin follow-up',
  'awaiting_customer_decision' => 'Tailor accepted',
  'finalized' => 'Finalized',
  _ => value.replaceAll('_', ' '),
};

String _inboundPickupLabel(dynamic rawStatus) => switch (rawStatus) {
  'assigned' => 'assigned · awaiting collection',
  'collectedFromCustomer' => 'collected from Customer · on the way to Tailor',
  'receivedAtTailor' => 'received at Tailor',
  null || '' => 'not started',
  _ => rawStatus.toString().replaceAll('_', ' '),
};

String _reasonLabel(String value) => switch (value) {
  'outside_business_hours' ||
  'too_late_for_offer_window' => 'Queued for automatic routing',
  'no_tailor_in_coverage' =>
    'No automatic PIN match · manual routing available',
  'no_online_tailor_in_coverage' =>
    'Waiting for a PIN-matched Tailor to come online',
  'all_eligible_tailors_contacted' =>
    'All priority offers declined or timed out · Admin action needed',
  'order_price_required' => 'Order price needs Admin review',
  'delivery_pincode_required' => 'Delivery PIN needs correction',
  _ => value.replaceAll('_', ' '),
};

String? _historyLabel(String value) => switch (value) {
  'tailor_offer_sent' => 'Offer sent',
  'tailor_offer_declined' => 'Declined',
  'tailor_offer_timed_out' => 'Timed out',
  'tailor_accepted_customer_decision_opened' => 'Accepted',
  'order_queued_for_tailor_dispatch' => 'Queued',
  'assignment_routed_to_operations' => 'Operations review',
  'tailor_routing_priority_updated' => 'Priority updated',
  'admin_tailor_offer_sent' => 'Admin offer sent',
  'customer_advance_paid_order_finalized' => 'Advance paid · finalized',
  'tailor_measurement_plan_saved' => 'Measurement plan shared',
  'measurement_partner_appointment_scheduled' =>
    'Measurement appointment scheduled',
  'measurement_partner_measurements_submitted' =>
    'Partner submitted measurements',
  'inbound_pickup_assigned' => 'Pickup Partner assigned',
  'inbound_pickup_collected_from_customer' => 'Item collected from Customer',
  'inbound_pickup_received_at_tailor' => 'Item received at Tailor',
  'production_measurement_confirmed_by_tailor' => 'Measurements confirmed',
  'measurement_partner_measurement_reinitiated' => 'Measurement re-initiated',
  'order_ready_for_stitching' => 'Ready for stitching',
  'customer_balance_paid' => 'Balance paid',
  'tailor_order_status_updated' => 'Tailor progress updated',
  'delivery_partner_accepted_order' => 'Delivery accepted',
  'order_delivered_and_closed' => 'Delivered · closed',
  'customer_cancelled_order' => 'Customer cancelled',
  'customer_declined_before_finalization' => 'Customer declined',
  'admin_waived_cancellation_fee' => 'Cancellation fee waived',
  'customer_reported_warranty_issue' => 'Warranty issue reported',
  'tailor_resolved_warranty_issue' => 'Tailor resolved warranty request',
  'admin_resolved_warranty_issue' => 'Admin resolved warranty request',
  'customer_submitted_order_feedback' => 'Feedback received',
  _ => null,
};
