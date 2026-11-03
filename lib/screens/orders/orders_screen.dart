import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';
import '../../models/prd_catalog.dart';
import '../../core/app_state.dart';
import '../../services/order_lifecycle_service.dart';
import '../profile/customer_help_support_screen.dart';
import '../../widgets/orders/order_tracking_tag.dart';
import '../../widgets/orders/garment_record_qr_dialog.dart';
import '../../widgets/orders/pickup_photo_attachment_button.dart';
import '../../widgets/orders/order_design_references.dart';

String _normalizeQuickCareWorkflow(String? value) => (value ?? '')
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    )
    .toLowerCase()
    .replaceAll(RegExp(r'[\s-]+'), '_');

String _formatOrderReference(Object? value) {
  final reference = value?.toString().trim() ?? '';
  if (RegExp(r'^\d{12}$').hasMatch(reference)) {
    return '${reference.substring(0, 6)}-${reference.substring(6)}';
  }
  return reference;
}

bool _isActiveOrder(DressOrder order) {
  if (order.orderModuleType == OrderModuleType.quickFix) {
    return !const {
      'completed',
      'cancelled',
    }.contains(_normalizeQuickCareWorkflow(order.quickCareWorkflowStatus));
  }
  return order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled;
}

bool _isPendingOrder(DressOrder order) {
  if (order.orderModuleType == OrderModuleType.quickFix) {
    return const {
      'request_submitted',
      'partner_assigned',
      'awaiting_customer_approval',
      'payment_pending',
    }.contains(_normalizeQuickCareWorkflow(order.quickCareWorkflowStatus));
  }
  return order.status == OrderStatus.pending;
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialFilter, this.initialModuleType});

  /// Optional status filter to select when opening the order list.
  final String? initialFilter;

  /// Optional service category used by the customer Orders hub.
  final String? initialModuleType;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  _OrdersFilter _filter = _OrdersFilter.all;
  OrderModuleType? _moduleFilter;
  List<DressOrder> _orders = [];
  List<_OrderDraftSummary> _draftOrders = [];
  List<_OrderDraftSummary> _archivedDraftOrders = [];
  bool _loading = true;
  bool _loadingDrafts = true;
  OrderLifecyclePolicy _lifecyclePolicy = const OrderLifecyclePolicy();

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialFilter) {
      'active' => _OrdersFilter.active,
      'pending' => _OrdersFilter.pending,
      'delivered' => _OrdersFilter.delivered,
      'onTheWay' => _OrdersFilter.onTheWay,
      _ => _OrdersFilter.all,
    };
    for (final module in OrderModuleType.values) {
      if (module.name == widget.initialModuleType) {
        _moduleFilter = module;
        break;
      }
    }
    _loadOrders();
    _loadDraftOrders();
  }

  Future<void> _loadDraftOrders() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      if (mounted) {
        setState(() => _loadingDrafts = false);
      }
      return;
    }

    try {
      final accountId = await AppState.instance.fetchAccountIdForMobile(
        phone.trim(),
      );

      if (accountId == null || accountId.isEmpty) {
        if (mounted) {
          setState(() => _loadingDrafts = false);
        }
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('order_drafts')
          .where('accountId', isEqualTo: accountId)
          .get();

      final allDrafts = snap.docs
          .map((doc) => _OrderDraftSummary.fromFirestore(doc.id, doc.data()))
          .toList();

      final activeDrafts = allDrafts
          .where((draft) => draft.status == 'draft')
          .toList();

      final archivedDrafts = allDrafts
          .where((draft) => draft.status == 'archived')
          .toList();

      activeDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      archivedDrafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      if (!mounted) return;

      setState(() {
        _draftOrders = activeDrafts;
        _archivedDraftOrders = archivedDrafts;
        _loadingDrafts = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingDrafts = false);
    }
  }

  Future<void> _discardDraftOrder(_OrderDraftSummary draft) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard Draft?'),
          content: Text(
            'Discard ${draft.dressType} draft?\n\n'
            'This draft will be removed from Draft Orders. '
            'It will be archived in the background and can be recovered later when Archived Drafts is available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    if (shouldDiscard != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('order_drafts')
          .doc(draft.draftId)
          .set({
            'status': 'archived',
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      await _refreshOrdersAndDrafts();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft discarded')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to discard draft. Please try again.'),
        ),
      );
    }
  }

  //SUD
  Future<void> _recoverDraftOrder(_OrderDraftSummary draft) async {
    final shouldRecover = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recover Draft?'),
          content: Text(
            'Recover ${draft.dressType} draft?\n\n'
            'This draft will move back to Draft Orders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Recover'),
            ),
          ],
        );
      },
    );

    if (shouldRecover != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('order_drafts')
          .doc(draft.draftId)
          .set({
            'status': 'draft',
            'recoveredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;

      await _refreshOrdersAndDrafts();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft recovered')));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to recover draft. Please try again.'),
        ),
      );
    }
  }

  Future<void> _loadOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      try {
        _lifecyclePolicy = await OrderLifecyclePolicy.fetch();
      } catch (_) {
        _lifecyclePolicy = const OrderLifecyclePolicy();
      }
      final orderQuery = FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid);
      var snap = await orderQuery.get();
      final missingReferences = snap.docs
          .where((document) {
            final value = document.data()['orderTrackingId']?.toString().trim();
            return value == null || value.isEmpty;
          })
          .map((document) => document.id)
          .take(50)
          .toList();
      if (missingReferences.isNotEmpty) {
        try {
          await FirebaseFunctions.instance
              .httpsCallable('ensureCustomerOrderTrackingId')
              .call(<String, dynamic>{'orderIds': missingReferences});
          snap = await orderQuery.get();
        } catch (_) {
          // Continue to show the Firestore ID if reference migration is
          // temporarily unavailable in this Firebase environment.
        }
      }
      if (mounted) {
        setState(() {
          _orders = snap.docs.map((d) => _orderFromDoc(d)).toList()
            ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _declineBeforeFinalization(DressOrder order) async {
    final shouldDecline = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Do not proceed with this order?'),
        content: const Text(
          'This request has not been finalized. No cancellation fee will be charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Close request'),
          ),
        ],
      ),
    );
    if (shouldDecline != true || !mounted) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('declineAcceptedTailorOrder')
          .call({'orderId': order.id});
      if (!mounted) return;
      await _refreshOrdersAndDrafts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request closed. No cancellation fee was charged.'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not close this request.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not close this request. Please retry.'),
        ),
      );
    }
  }

  Future<void> _cancelOrder(DressOrder order) async {
    final finalized =
        order.assignmentStatus == 'finalized' ||
        order.paymentStatus == PaymentStatus.advancePaid ||
        order.paymentStatus == PaymentStatus.fullyPaid;
    final fee = finalized
        ? order.price * _lifecyclePolicy.cancellationFeePercent / 100
        : 0.0;
    final paid = order.paymentStatus == PaymentStatus.fullyPaid
        ? order.price
        : (order.amountPaid ?? 0);
    final refund = (paid - fee).clamp(0.0, double.infinity);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          finalized
              ? 'The order can be cancelled before stitching starts. The current policy fee is ${_lifecyclePolicy.cancellationFeePercent.toStringAsFixed(_lifecyclePolicy.cancellationFeePercent % 1 == 0 ? 0 : 2)}% (₹${fee.toStringAsFixed(0)}). Estimated refund from the amount already paid: ₹${refund.toStringAsFixed(0)}. Admin can waive this fee.'
              : 'This order has not been finalized, so no cancellation fee will be charged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm cancellation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await OrderLifecycleService.cancelOrder(order.id);
      await _refreshOrdersAndDrafts();
      if (!mounted) return;
      final appliedFee =
          (result['cancellationFeeAmount'] as num?)?.toDouble() ?? 0;
      final refundDue = (result['refundDue'] as num?)?.toDouble() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appliedFee > 0
                ? 'Order cancelled. Fee recorded: ₹${appliedFee.toStringAsFixed(0)} · refund due: ₹${refundDue.toStringAsFixed(0)}.'
                : 'Order cancelled with no fee.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not cancel this order.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not cancel this order. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _cancelQuickCareOrder(DressOrder order) async {
    final scheduledAt = order.quickCareScheduledAt;
    final canCancelDirectly =
        scheduledAt != null &&
        scheduledAt.difference(DateTime.now()) > const Duration(hours: 2) &&
        !order.quickCareServiceInProgress;

    if (!canCancelDirectly) {
      final reason = order.quickCareServiceInProgress
          ? 'This service has already started. Helpdesk will review the cancellation with you.'
          : 'This appointment is within two hours or its time is not confirmed. Helpdesk will review the cancellation with you.';
      final contactHelpdesk = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Contact Helpdesk to cancel'),
          content: Text(reason),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep booking'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Contact Helpdesk'),
            ),
          ],
        ),
      );
      if (contactHelpdesk != true || !mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      final profileName = AppState.instance.profile?.name.trim() ?? '';
      await CustomerHelpSupportScreen.openQuickCareCancellationTicket(
        context,
        customerName: profileName.isNotEmpty
            ? profileName
            : user?.displayName ?? 'Customer',
        orderId: order.id,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this Quick Care booking?'),
        content: const Text(
          'This booking is more than two hours away and the service has not started. You can cancel it now with no cancellation fee.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await OrderLifecycleService.cancelQuickCareOrder(order.id);
      await _refreshOrdersAndDrafts();
      if (!mounted) return;
      final refundDue = (result['refundDue'] as num?)?.toDouble() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            refundDue > 0
                ? 'Booking cancelled with no fee. A refund is recorded for review.'
                : 'Booking cancelled. No cancellation fee applies.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final errorCode = error.code.toLowerCase().replaceAll('_', '-');
      if (errorCode == 'failed-precondition') {
        final message = (error.message ?? '').toLowerCase();
        if (message.contains('quote has been approved') ||
            message.contains('service has already started') ||
            message.contains('already closed') ||
            message.contains('awaiting payment')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message!)));
          return;
        }
        final user = FirebaseAuth.instance.currentUser;
        final profileName = AppState.instance.profile?.name.trim() ?? '';
        await CustomerHelpSupportScreen.openQuickCareCancellationTicket(
          context,
          customerName: profileName.isNotEmpty
              ? profileName
              : user?.displayName ?? 'Customer',
          orderId: order.id,
        );
        return;
      }
      if (errorCode == 'not-found') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Direct cancellation is not deployed in this Firebase environment yet. Please deploy the updated backend or contact Helpdesk.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not cancel this booking.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel this booking. Please retry.'),
        ),
      );
    }
  }

  Future<void> _confirmFabricShortfall(DressOrder order) async {
    final review = order.fabricRequirementReview ?? const <String, dynamic>{};
    final shortfall = (review['shortfallMeters'] as num?)?.toDouble() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm additional fabric'),
        content: Text(
          'Your Tailor reports ${shortfall.toStringAsFixed(1)} m more fabric is needed than the estimate. Confirm that the extra fabric can be arranged. Cutting will remain paused until you confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I will arrange it'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await OrderLifecycleService.confirmCustomerFabricShortfall(order.id);
      await _refreshOrdersAndDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Confirmation sent. Your Tailor can continue after the fabric is arranged.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Could not confirm the fabric update.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitFeedback(DressOrder order) async {
    var rating = 5;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate your order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: controller,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Share a comment (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      await OrderLifecycleService.submitFeedback(
        orderId: order.id,
        rating: rating,
        feedback: controller.text.trim(),
      );
      await _refreshOrdersAndDrafts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit feedback. Please retry.'),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _reportWarrantyIssue(DressOrder order) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact your Tailor under warranty'),
        content: TextField(
          controller: controller,
          maxLength: 1500,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText:
                'Describe the repair or change needed. Your Tailor will contact you to arrange pickup and return.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send to my Tailor'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      await OrderLifecycleService.reportWarrantyIssue(
        orderId: order.id,
        description: controller.text.trim(),
      );
      await _refreshOrdersAndDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Warranty request sent to your Tailor. Use Partner contacts to coordinate pickup and return.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not report the issue.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not report the issue. Please retry.'),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showPartnerContacts(DressOrder order) async {
    try {
      final contacts =
          await OrderLifecycleService.getCustomerOrderPartnerContacts(order.id);
      if (!mounted) return;
      final tailorPhone = (contacts['tailorPhone'] ?? '').toString().trim();
      final measurementPhone = (contacts['measurementPartnerPhone'] ?? '')
          .toString()
          .trim();
      final pickupPhone = (contacts['pickupPartnerPhone'] ?? '')
          .toString()
          .trim();
      final deliveryPhone = (contacts['deliveryPartnerPhone'] ?? '')
          .toString()
          .trim();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('SuiSakhi Partner contacts'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PartnerContactRow(
                  label: 'SuiSakhi Tailor Partner',
                  phone: tailorPhone,
                  note: 'for stitching communication',
                ),
                const SizedBox(height: 16),
                _PartnerContactRow(
                  label: 'SuiSakhi Measurement Partner',
                  phone: measurementPhone,
                  note: 'for measurement communication',
                ),
                if (pickupPhone.isNotEmpty &&
                    pickupPhone != measurementPhone) ...[
                  const SizedBox(height: 16),
                  _PartnerContactRow(
                    label: 'SuiSakhi Pickup Partner',
                    phone: pickupPhone,
                    note: 'for collecting the garment from you',
                  ),
                ],
                const SizedBox(height: 16),
                _PartnerContactRow(
                  label: 'SuiSakhi Delivery Partner',
                  phone: deliveryPhone,
                  note: 'for returning the finished garment to you',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not load Partner contacts.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load Partner contacts. Please retry.'),
        ),
      );
    }
  }

  static DressOrder _orderFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    return DressOrder.fromFirestore(d.id, d.data());
  }

  List<DressOrder> get _filtered {
    final orders = _ordersForModule;
    switch (_filter) {
      case _OrdersFilter.all:
        return orders;
      case _OrdersFilter.active:
        return orders.where(_isActiveOrder).toList();
      case _OrdersFilter.pending:
        return orders.where(_isPendingOrder).toList();
      case _OrdersFilter.delivered:
        return orders
            .where((order) => order.status == OrderStatus.delivered)
            .toList();
      case _OrdersFilter.onTheWay:
        return orders
            .where((order) => order.status == OrderStatus.outForDelivery)
            .toList();
    }
  }

  List<DressOrder> get _ordersForModule {
    final module = _moduleFilter;
    if (module == null) return _orders;
    return _orders.where((order) => order.orderModuleType == module).toList();
  }

  bool get _showTailoringDrafts =>
      _moduleFilter == null || _moduleFilter == OrderModuleType.coreTailoring;

  String get _pageTitle => switch (_moduleFilter) {
    OrderModuleType.coreTailoring => 'Tailoring Orders',
    OrderModuleType.quickFix => 'Quick Care & Home Services',
    OrderModuleType.bulkOrder => 'Weddings & Event Orders',
    OrderModuleType.marketplace => 'Fashion Store Requests',
    null => 'My Orders',
  };

  String get _newOrderRoute => switch (_moduleFilter) {
    OrderModuleType.quickFix => '/quick-fix',
    OrderModuleType.bulkOrder => '/bulk-orders',
    OrderModuleType.marketplace => '/shop-explore',
    _ => '/designer',
  };

  /// [context.go('/orders')] leaves no stack entry, so [pop] does nothing.
  void _leaveOrders(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_pageTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => _leaveOrders(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh order status',
              onPressed: _refreshOrdersAndDrafts,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildSummaryCards(),
                  _buildFilterChips(),
                  if (_moduleFilter == null) _buildGarmentCareShortcut(),
                  Expanded(
                    child:
                        _filtered.isEmpty &&
                            (_filter != _OrdersFilter.all ||
                                !_showTailoringDrafts ||
                                (_draftOrders.isEmpty &&
                                    _archivedDraftOrders.isEmpty))
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            children: [
                              if (_filter == _OrdersFilter.all &&
                                  _showTailoringDrafts) ...[
                                _buildDraftOrdersSection(),
                                if (_draftOrders.isNotEmpty &&
                                    _archivedDraftOrders.isNotEmpty)
                                  const SizedBox(height: 18),
                                _buildArchivedDraftOrdersSection(),
                                if ((_draftOrders.isNotEmpty ||
                                        _archivedDraftOrders.isNotEmpty) &&
                                    _filtered.isNotEmpty)
                                  const SizedBox(height: 14),
                              ],

                              if (_filtered.isNotEmpty)
                                ..._filtered.map(
                                  (order) => _OrderCard(
                                    order: order,
                                    cancellationFeePercent:
                                        _lifecyclePolicy.cancellationFeePercent,
                                    onCustomerDecline: () =>
                                        _declineBeforeFinalization(order),
                                    onCancel: () => _cancelOrder(order),
                                    onQuickCareCancel: () =>
                                        _cancelQuickCareOrder(order),
                                    onQuickCarePaymentReturn:
                                        _showQuickCareOrdersAfterPayment,
                                    onFeedback: () => _submitFeedback(order),
                                    onWarrantyIssue: () =>
                                        _reportWarrantyIssue(order),
                                    onPartnerContacts: () =>
                                        _showPartnerContacts(order),
                                    onConfirmFabricShortfall: () =>
                                        _confirmFabricShortfall(order),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.push(_newOrderRoute);

            await _refreshOrdersAndDrafts();
          },
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'New Order',
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshOrdersAndDrafts() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _loadingDrafts = true;
    });

    await _loadOrders();
    await _loadDraftOrders();
  }

  Future<void> _showQuickCareOrdersAfterPayment() async {
    if (!mounted) return;
    setState(() {
      _moduleFilter = OrderModuleType.quickFix;
      _filter = _OrdersFilter.all;
    });
    await _refreshOrdersAndDrafts();
  }

  Widget _buildGarmentCareShortcut() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        color: AppColors.surface,
        child: ListTile(
          leading: Icon(
            Icons.local_laundry_service_outlined,
            color: AppColors.primary,
          ),
          title: const Text('Garment Care orders'),
          subtitle: const Text('Track each care group as its own order'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push('/garment-care/orders'),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final orders = _ordersForModule;
    final active = orders.where(_isActiveOrder).length;
    final ready = orders
        .where((o) => o.status == OrderStatus.readyForPickup)
        .length;
    final total = orders.length;
    final drafts = _showTailoringDrafts ? _draftOrders.length : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _SummaryChip(label: 'Total', count: total, color: AppColors.primary),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Active',
            count: active,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Ready',
            count: ready,
            color: const Color(0xFF9C27B0),
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Drafts',
            count: drafts,
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final orders = _ordersForModule;
    final filters = [
      ('All', _OrdersFilter.all, orders.length),
      ('Active', _OrdersFilter.active, orders.where(_isActiveOrder).length),
      ('Pending', _OrdersFilter.pending, orders.where(_isPendingOrder).length),
      (
        'Delivered',
        _OrdersFilter.delivered,
        orders.where((order) => order.status == OrderStatus.delivered).length,
      ),
      (
        'On the way',
        _OrdersFilter.onTheWay,
        orders
            .where((order) => order.status == OrderStatus.outForDelivery)
            .length,
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final selected = _filter == filter.$2;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _filter = filter.$2),
            label: Text('${filter.$1} (${filter.$3})'),
            labelStyle: AppTextStyles.labelMedium.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildDraftOrdersSection() {
    if (_loadingDrafts) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    if (_draftOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Draft Orders', style: AppTextStyles.headlineMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_draftOrders.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._draftOrders.map(
          (draft) => _DraftOrderCard(
            draft: draft,
            onResume: () async {
              await context.push(
                '/designer?orderDraftId=${Uri.encodeComponent(draft.draftId)}',
              );

              await _refreshOrdersAndDrafts();
            },
            onDiscard: () {
              _discardDraftOrder(draft);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedDraftOrdersSection() {
    if (_loadingDrafts || _archivedDraftOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Archived Drafts', style: AppTextStyles.headlineMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_archivedDraftOrders.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._archivedDraftOrders.map(
          (draft) => _ArchivedDraftOrderCard(
            draft: draft,
            onRecover: () {
              _recoverDraftOrder(draft);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final message = switch (_filter) {
      _OrdersFilter.all => 'No orders yet',
      _OrdersFilter.active => 'No active orders',
      _OrdersFilter.pending => 'No pending orders',
      _OrdersFilter.delivered => 'No delivered orders',
      _OrdersFilter.onTheWay => 'No orders on the way',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(message, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            _filter == _OrdersFilter.all
                ? 'Tap "+ New Order" to place your first order'
                : 'Try another order status to view its orders.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

enum _OrdersFilter { all, active, pending, delivered, onTheWay }

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppTextStyles.headlineLarge.copyWith(color: color),
            ),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _occasionDisplayName(String id) {
  for (final o in OccasionCategory.values) {
    if (o.name == id) return o.displayName;
  }
  return id;
}

String _recordValue(Map<String, dynamic> record, String key) =>
    (record[key] ?? '').toString().trim();

Future<void> _showGarmentRecordDialog(
  BuildContext context,
  DressOrder order,
) async {
  final record = order.garmentRecord ?? const <String, dynamic>{};
  final material = record['material'] is Map
      ? Map<String, dynamic>.from(record['material'] as Map)
      : const <String, dynamic>{};
  final traceability = record['traceability'] is Map
      ? Map<String, dynamic>.from(record['traceability'] as Map)
      : const <String, dynamic>{};
  final measurements = record['measurements'] is Map
      ? Map<String, dynamic>.from(record['measurements'] as Map)
      : const <String, dynamic>{};
  final designImage = _recordValue(record, 'designImageUrl');
  final materialImage = _recordValue(material, 'customerReferenceImageUrl');
  final compositionSource = switch (_recordValue(
    material,
    'compositionSource',
  )) {
    'supplier_label' => 'Supplier label transcribed by Tailor',
    'customer_label' => 'Customer-provided label',
    'visual_only' => 'Visual estimate only',
    _ => 'Not provided',
  };

  String dateValue(Object? raw) {
    if (raw is Timestamp) {
      return MaterialLocalizations.of(
        context,
      ).formatMediumDate(raw.toDate().toLocal());
    }
    return raw?.toString() ?? '';
  }

  Widget line(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          children: [
            TextSpan(
              text: '$label · ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Garment DNA report'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order record · ${_recordValue(record, 'recordId')}',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: 12),
              Text('Garment and design', style: AppTextStyles.titleMedium),
              line('Garment type', _recordValue(record, 'garmentType')),
              line('Occasion', _recordValue(record, 'occasion')),
              line('Selected design', _recordValue(record, 'designTitle')),
              line('Design notes', _recordValue(record, 'designDescription')),
              if (designImage.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    designImage,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Material record', style: AppTextStyles.titleMedium),
              line(
                'Customer selection',
                _recordValue(material, 'customerSelection'),
              ),
              line(
                'Customer description',
                _recordValue(material, 'customerDescription'),
              ),
              line(
                'Fibre composition',
                _recordValue(material, 'fiberComposition'),
              ),
              line('Composition source', compositionSource),
              line(
                'Care instructions',
                _recordValue(material, 'careInstructions'),
              ),
              line('Care guidance source', switch (_recordValue(
                material,
                'careInstructionsSource',
              )) {
                'tailor_qc' => 'Reviewed or edited by the Tailor during QC',
                'conservative_template' =>
                  'Conservative material-aware starter guidance',
                _ => '',
              }),
              if (materialImage.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    materialImage,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              if ((material['pickupPhotoPath'] ?? '').toString().isNotEmpty)
                PickupPhotoAttachmentButton(
                  storagePath: material['pickupPhotoPath'].toString(),
                ),
              const SizedBox(height: 16),
              Text('Tailor quality check', style: AppTextStyles.titleMedium),
              line(
                'Construction notes',
                _recordValue(record, 'constructionNotes'),
              ),
              line('Quality check', _recordValue(record, 'qualityCheckNotes')),
              line('Fit', _recordValue(record, 'fit')),
              for (final entry in measurements.entries)
                line(
                  entry.key,
                  '${entry.value} ${_recordValue(record, 'measurementUnit')}',
                ),
              const SizedBox(height: 16),
              Text('Order traceability', style: AppTextStyles.titleMedium),
              line('Ordered', dateValue(traceability['orderedAt'])),
              line('Collected', dateValue(traceability['collectedAt'])),
              line(
                'Received at Tailor',
                dateValue(traceability['receivedAtTailorAt']),
              ),
              line('Delivered', dateValue(traceability['deliveredAt'])),
              const SizedBox(height: 14),
              Text(
                _recordValue(record, 'evidenceNote'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => GarmentRecordQrDialog.show(context, order.id),
          icon: const Icon(Icons.qr_code_2_rounded),
          label: const Text('Show report QR'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _showSampleOrderInvoice(
  BuildContext context,
  DressOrder order,
) async {
  final paid = order.paymentStatus == PaymentStatus.fullyPaid
      ? order.price
      : (order.amountPaid ?? order.price - order.balanceAmount).clamp(
          0.0,
          order.price,
        );
  final due = order.paymentStatus == PaymentStatus.fullyPaid
      ? 0.0
      : order.balanceAmount.clamp(0.0, order.price);
  final invoiceNumber = 'SS-INV-${order.orderTrackingId ?? order.id}';
  final issueDate = MaterialLocalizations.of(
    context,
  ).formatMediumDate(order.orderDate.toLocal());

  String amount(double value) => '₹${value.toStringAsFixed(2)}';

  Widget row(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: strong ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ),
      ],
    ),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sample order invoice'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SuiSakhi · Tailoring order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              row('Invoice reference', invoiceNumber),
              row('Order ID', order.orderTrackingId ?? order.id),
              row('Issue date', issueDate),
              const Divider(height: 24),
              Text('Bill to', style: AppTextStyles.titleMedium),
              row('Customer', order.orderForText),
              if ((order.customerPhone ?? '').trim().isNotEmpty)
                row('Phone', order.customerPhone!.trim()),
              if ((order.deliveryAddress ?? '').trim().isNotEmpty)
                row('Address', order.deliveryAddress!.trim()),
              const Divider(height: 24),
              Text('Order details', style: AppTextStyles.titleMedium),
              row('Garment', order.dressType),
              if ((order.designTemplateTitle ?? '').trim().isNotEmpty)
                row('Design', order.designTemplateTitle!.trim()),
              if ((order.fabricChoice ?? '').trim().isNotEmpty)
                row('Selected material', order.fabricChoice!.trim()),
              const Divider(height: 24),
              row(
                'Stitching service · 1 garment',
                amount(
                  (order.price - order.approvedDesignCharge).clamp(
                    0.0,
                    order.price,
                  ),
                ),
              ),
              if (order.approvedDesignCharge > 0)
                row(
                  'Approved catalogue design',
                  amount(order.approvedDesignCharge),
                ),
              row('Total', amount(order.price), strong: true),
              row('Amount received', amount(paid)),
              row('Balance due', amount(due), strong: true),
              row('Payment status', order.paymentStatus.label),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Sample order invoice for testing. Tax has not been calculated because seller legal and GST details are not configured. This is not a statutory GST tax invoice.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  final DressOrder order;
  final double cancellationFeePercent;
  final VoidCallback? onCustomerDecline;
  final VoidCallback? onCancel;
  final VoidCallback? onQuickCareCancel;
  final Future<void> Function()? onQuickCarePaymentReturn;
  final VoidCallback? onFeedback;
  final VoidCallback? onWarrantyIssue;
  final VoidCallback? onPartnerContacts;
  final VoidCallback? onConfirmFabricShortfall;
  const _OrderCard({
    required this.order,
    required this.cancellationFeePercent,
    this.onCustomerDecline,
    this.onCancel,
    this.onQuickCareCancel,
    this.onQuickCarePaymentReturn,
    this.onFeedback,
    this.onWarrantyIssue,
    this.onPartnerContacts,
    this.onConfirmFabricShortfall,
  });

  String get _quickCareWorkflow {
    return _normalizeQuickCareWorkflow(order.quickCareWorkflowStatus);
  }

  bool get _quickCareNeedsCustomerPayment {
    if (order.orderModuleType != OrderModuleType.quickFix) {
      return false;
    }
    final verifiedPayment =
        order.paymentStatus == PaymentStatus.fullyPaid &&
        ((order.paymentProvider == 'razorpay' &&
                (order.quickCareGatewayPaymentId?.isNotEmpty ?? false)) ||
            (order.paymentProvider == 'sandbox' &&
                (order.quickCarePaymentMethod?.isNotEmpty ?? false)));
    if (verifiedPayment) return false;
    return _quickCareWorkflow == 'payment_pending' ||
        (_quickCareWorkflow == 'completed' &&
            order.paymentStatus == PaymentStatus.fullyPaid);
  }

  String get _quickCareStatusLabel {
    if (_quickCareNeedsCustomerPayment) return 'Payment pending';
    return switch (_quickCareWorkflow) {
      'request_submitted' => 'Request submitted',
      'partner_assigned' => 'Partner assigned',
      'accepted' => 'Accepted',
      'in_progress' => 'In progress',
      'paused' => 'Paused',
      'awaiting_customer_approval' => 'Quote approval needed',
      'payment_pending' => 'Payment pending',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => order.status.label,
    };
  }

  Future<void> _showDeliveryPin(BuildContext context) async {
    try {
      final pin = await OrderLifecycleService.getCustomerDeliveryPin(order.id);
      if (!context.mounted || pin.isEmpty) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delivery PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pin,
                style: Theme.of(dialogContext).textTheme.headlineLarge
                    ?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share this PIN with the assigned Partner when your order is delivered.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        final message = error.code == 'not-found'
            ? 'The delivery PIN service is not deployed to this Firebase project yet. Deploy the latest Functions and retry.'
            : error.message ?? 'Could not load delivery PIN.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load delivery PIN. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimateMeters = order.fabricPurchaseEstimate?['estimatedMeters'];
    final quickCare = order.orderModuleType == OrderModuleType.quickFix;
    final statusLabel = quickCare ? _quickCareStatusLabel : order.status.label;
    final statusColor = quickCare && _quickCareNeedsCustomerPayment
        ? AppColors.warning
        : order.status.color;
    final paymentLabel = _quickCareNeedsCustomerPayment
        ? 'Payment pending'
        : order.paymentStatus.label;
    final paymentColor = _quickCareNeedsCustomerPayment
        ? PaymentStatus.unpaid.color
        : order.paymentStatus.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.orderModuleType != OrderModuleType.coreTailoring)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          order.orderModuleType.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      order.dressType,
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            'Order no. · ${_formatOrderReference(order.orderTrackingId?.trim().isNotEmpty == true ? order.orderTrackingId : order.id)}',
                            maxLines: 2,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy order number',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          onPressed: () async {
                            final reference =
                                order.orderTrackingId?.trim().isNotEmpty == true
                                ? order.orderTrackingId!.trim()
                                : order.id;
                            await Clipboard.setData(
                              ClipboardData(text: reference),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Order number copied.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    OrderTrackingTag.button(context, order.orderTrackingId),
                    if (order.occasionCategory != null &&
                        order.orderModuleType == OrderModuleType.coreTailoring)
                      Text(
                        _occasionDisplayName(order.occasionCategory!),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: order.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: order.status.color,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (order.orderModuleType.label.toLowerCase() == 'bulk')
            _buildBulkRequestInfo(order)
          else
            _buildOrderForInfo(order),

          if (order.orderModuleType == OrderModuleType.quickFix) ...[
            const SizedBox(height: 10),
            _quickCarePartnerUpdates(context, onQuickCareCancel),
            if (order.quickCareCancellationRequestStatus ==
                'pending_admin') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'A cancellation request is already with Helpdesk. If the service has not started and the appointment is more than two hours away, you can still cancel it directly with no fee.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoItem(
                Icons.calendar_today_outlined,
                _formatDate(order.orderDate),
                'Ordered',
              ),
              const SizedBox(width: 16),
              if (order.deliveryDate != null)
                _infoItem(
                  Icons.local_shipping_outlined,
                  _formatDate(order.deliveryDate!),
                  'Delivery',
                ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.price.toInt()}',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  if (order.usesProductionAssignment)
                    Text(
                      'Stitching estimate',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (order.fabricDescription != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.texture_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.fabricDescription!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (order.usesProductionAssignment &&
              order.status != OrderStatus.cancelled) ...[
            if ((order.designTemplateTitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Design: ${order.designTemplateTitle}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Instructions and measurement reference: ${order.notes}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (order.customerFabricPreviewAssets.isNotEmpty ||
                (order.designImageUrl ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OrderDesignReferences(
                  customerPreviews: order.customerFabricPreviewAssets,
                  originalCatalogueImageUrl: order.designImageUrl,
                ),
              ),
            if ((order.fabricChoice ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Material choice: ${order.fabricChoice}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            if (estimateMeters is num)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Estimated fabric to buy · ${estimateMeters.toStringAsFixed(1)} m (includes 18% allowance). The Tailor will confirm actual quantity before cutting.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (order.expectedReadyAt != null &&
                order.assignmentStatus != 'awaiting_customer_decision')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Expected completion: ${MaterialLocalizations.of(context).formatMediumDate(order.expectedReadyAt!.toLocal())}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.deliveryAddress!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paymentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.currency_rupee_rounded,
                      size: 12,
                      color: paymentColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      paymentLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: order.paymentStatus.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.deliveryFee > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '+ ₹${order.deliveryFee.toInt()} delivery',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ],
          ),
          if (order.usesProductionAssignment) ...[
            const SizedBox(height: 12),
            _buildAssignmentNotice(context),
          ],
          if (order.fabricRequirementReview?['status'] ==
              'shortfall_pending_customer') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fabric confirmation needed before cutting'),
                  const SizedBox(height: 4),
                  Text(
                    'Tailor needs ${(order.fabricRequirementReview?['shortfallMeters'] as num?)?.toStringAsFixed(1) ?? '0.0'} m more than the estimate.',
                    style: AppTextStyles.bodySmall,
                  ),
                  if ((order.fabricRequirementReview?['note']?.toString() ?? '')
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        order.fabricRequirementReview!['note'].toString(),
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    onPressed: onConfirmFabricShortfall,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('I will arrange additional fabric'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        context.push('/fabric-help?orderId=${order.id}'),
                    icon: const Icon(Icons.video_call_outlined),
                    label: const Text('Ask for fabric help'),
                  ),
                ],
              ),
            ),
          ] else if (order.fabricRequirementReview?['actualRequiredMeters']
              is num) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                order.fabricRequirementReview?['status'] == 'customer_confirmed'
                    ? 'Tailor reported a fabric shortfall; your confirmation is recorded. The Tailor will continue after the extra fabric is arranged.'
                    : 'Tailor checked the fabric before cutting · actual requirement ${(order.fabricRequirementReview!['actualRequiredMeters'] as num).toStringAsFixed(1)} m.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          if (order.usesProductionAssignment &&
              order.assignmentStatus == 'finalized' &&
              order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPartnerContacts,
                icon: const Icon(Icons.call_outlined),
                label: const Text('SuiSakhi Partner contacts'),
              ),
            ),
          ],
          if ((order.inboundPickupPhotoPath ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            PickupPhotoAttachmentButton(
              storagePath: order.inboundPickupPhotoPath!,
            ),
          ],
          if (order.usesProductionAssignment &&
              order.paymentStatus == PaymentStatus.fullyPaid &&
              [
                'assigned',
                'in_transit',
              ].contains(order.outboundHandoverStatus) &&
              [
                OrderStatus.readyForPickup,
                OrderStatus.outForDelivery,
              ].contains(order.status)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeliveryPin(context),
                icon: const Icon(Icons.pin_outlined),
                label: const Text('Show delivery PIN'),
              ),
            ),
          ],
          if (order.price > 0 &&
              (!order.usesProductionAssignment ||
                  order.assignmentStatus == 'awaiting_customer_decision' ||
                  order.assignmentStatus == 'finalized')) ...[
            const SizedBox(height: 8),
            Text(
              'Advance ${order.advancePercent}% · ₹${order.advanceAmount.toStringAsFixed(0)} · '
              'Balance ₹${order.balanceAmount.toStringAsFixed(0)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
          if (order.paymentStatus == PaymentStatus.pendingPayment &&
              (!order.usesProductionAssignment ||
                  (order.assignmentStatus == 'awaiting_customer_decision' &&
                      order.expectedReadyAt != null))) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/checkout/${order.id}'),
                child: const Text('Pay advance online'),
              ),
            ),
          ],
          if (order.usesProductionAssignment &&
              order.paymentStatus == PaymentStatus.pendingPayment &&
              order.assignmentStatus == 'awaiting_customer_decision') ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCustomerDecline,
                child: const Text('Cancel request'),
              ),
            ),
          ],
          if (order.usesProductionAssignment &&
              order.status == OrderStatus.readyForPickup &&
              order.paymentStatus == PaymentStatus.advancePaid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/checkout/${order.id}'),
                child: Text(
                  'Pay remaining balance · ₹${order.balanceAmount.toStringAsFixed(0)}',
                ),
              ),
            ),
          ],
          if (order.canCancelBeforeStitching &&
              !(order.paymentStatus == PaymentStatus.pendingPayment &&
                  order.assignmentStatus == 'awaiting_customer_decision')) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
                label: Text(
                  order.assignmentStatus == 'finalized'
                      ? 'Cancel order · ${cancellationFeePercent.toStringAsFixed(cancellationFeePercent % 1 == 0 ? 0 : 2)}% fee policy'
                      : 'Cancel order',
                ),
              ),
            ),
          ],
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 12),
            if (order.closedAt != null)
              Text(
                'Order completed · ${MaterialLocalizations.of(context).formatMediumDate(order.closedAt!.toLocal())}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            if (order.warrantyEndsAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  order.warrantyEndsAt!.isAfter(DateTime.now())
                      ? 'Warranty support until ${MaterialLocalizations.of(context).formatMediumDate(order.warrantyEndsAt!.toLocal())}'
                      : 'Warranty period ended ${MaterialLocalizations.of(context).formatMediumDate(order.warrantyEndsAt!.toLocal())}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
            if (order.feedbackSubmittedAt == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onFeedback,
                  icon: const Icon(Icons.star_outline_rounded),
                  label: const Text('Share feedback'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Your rating · ${order.feedbackRating ?? 0}/5',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            if (order.warrantyIssueReportedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Warranty request with your Tailor · ${order.warrantyClaimStatus ?? 'open'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              )
            else if (order.warrantyEndsAt?.isAfter(DateTime.now()) == true)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWarrantyIssue,
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Report an issue under warranty'),
                ),
              ),
            if ((order.warrantyResolution ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tailor follow-up · ${order.warrantyResolution}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            if (order.garmentRecordPublishedAt != null &&
                order.garmentRecord?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showGarmentRecordDialog(context, order),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View Garment DNA report'),
                ),
              ),
            ],
            if (order.usesProductionAssignment &&
                order.assignmentStatus == 'finalized' &&
                order.price > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showSampleOrderInvoice(context, order),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View sample invoice'),
                ),
              ),
            ],
          ],
          if (order.usesProductionAssignment) ...[
            const SizedBox(height: 12),
            _buildHandoverTimeline(context, order),
          ],
          if (!quickCare &&
              order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 12),
            _buildProgressBar(order),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentNotice(BuildContext context) {
    final status = order.assignmentStatus;
    final String message;
    if (order.status == OrderStatus.cancelled) {
      message = order.cancellationFeeAmount > 0
          ? 'Order cancelled. Fee: ₹${order.cancellationFeeAmount.toStringAsFixed(0)} · refund due: ₹${order.cancellationRefundDue.toStringAsFixed(0)}.'
          : 'Order cancelled. No cancellation fee was charged.';
    } else if (order.status == OrderStatus.delivered) {
      message =
          'Delivered and closed. Warranty support is available until ${order.warrantyEndsAt == null ? 'the stated expiry date' : MaterialLocalizations.of(context).formatMediumDate(order.warrantyEndsAt!.toLocal())}.';
    } else if (order.status == OrderStatus.readyForPickup) {
      message = order.paymentStatus == PaymentStatus.advancePaid
          ? 'Your order is ready. Pay the remaining balance to allow dispatch.'
          : 'Your order is ready and fully paid. We are arranging the return handover.';
    } else if (order.status == OrderStatus.outForDelivery) {
      message = 'Your order is out for delivery.';
    } else if (order.status == OrderStatus.inStitching ||
        order.status == OrderStatus.qcPending ||
        order.status == OrderStatus.qcPassed ||
        order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.atTailor) {
      final eta = order.expectedReadyAt == null
          ? ''
          : ' Expected completion: ${MaterialLocalizations.of(context).formatMediumDate(order.expectedReadyAt!.toLocal())}.';
      message = '${order.status.label}$eta';
    } else if (status == 'awaiting_customer_decision') {
      final deadline = order.customerDecisionExpiresAt;
      final deadlineText = deadline == null
          ? ''
          : ' Decide by ${MaterialLocalizations.of(context).formatMediumDate(deadline.toLocal())} at '
                '${TimeOfDay.fromDateTime(deadline.toLocal()).format(context)}.';
      final expectedReadyAt = order.expectedReadyAt;
      if (expectedReadyAt == null) {
        message =
            'A Tailor has accepted your request. The expected completion date is being confirmed. Please wait before paying.$deadlineText';
      } else {
        final etaText = MaterialLocalizations.of(
          context,
        ).formatMediumDate(expectedReadyAt.toLocal());
        message =
            'A Tailor has accepted your request. Expected completion: $etaText. Pay the 50% advance by the decision deadline shown to finalize.$deadlineText';
      }
    } else if (status == 'finalized') {
      final eta = order.expectedReadyAt == null
          ? ''
          : ' Expected completion: ${MaterialLocalizations.of(context).formatMediumDate(order.expectedReadyAt!.toLocal())}.';
      final measurementMessage = _measurementPlanMessage(context);
      final pickupMessage = switch (order.inboundPickupStatus) {
        'assigned' => switch (order.inboundPickupPartnerType) {
          'tailor' =>
            'Your Tailor is assigned for pickup; collection is still pending.',
          'measurementPartner' =>
            'Your Measurement Partner is assigned for pickup; collection is still pending.',
          _ => 'A Delivery Partner is assigned; collection is still pending.',
        },
        'collectedFromCustomer' =>
          'Pickup completed: your item has been collected and is on the way to the Tailor.',
        'receivedAtTailor' =>
          'Pickup completed: your item has reached the Tailor.',
        _ => 'Pickup is being arranged.',
      };
      message = 'Advance paid. $measurementMessage $pickupMessage$eta';
    } else if (status == 'queued_for_dispatch') {
      final reason = order.adminQueueReason;
      if (reason == 'no_tailor_in_coverage') {
        message =
            'Your order is pending Tailor assignment. Our team is reviewing coverage for your delivery PIN.';
      } else {
        message =
            'Your order is received and pending assignment. We will send it to a PIN-matched Tailor when one is online.';
      }
    } else if (status == 'needs_admin_follow_up') {
      message = 'Our SuiSakhi team will help continue this request.';
    } else if (status == 'offered') {
      message =
          'Your request has been sent to a Tailor. We are waiting for their response.';
    } else {
      message =
          'Your request is received. We are finding a Tailor for your delivery area.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.bodySmall),
          if ((order.measurementNotes ?? '').trim().isNotEmpty &&
              status == 'finalized') ...[
            const SizedBox(height: 6),
            Text(
              order.measurementNotes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if ((order.measurementAppointmentLink ?? '').trim().isNotEmpty &&
              status == 'finalized' &&
              order.status != OrderStatus.delivered &&
              order.closedAt == null &&
              order.measurementStatus != 'partner_completed' &&
              order.measurementStatus != 'completed') ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(order.measurementAppointmentLink!),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.video_call_outlined),
              label: const Text('Join video measurement'),
            ),
          ],
          if (order.usesProductionAssignment &&
              order.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => context.push(
                '/fabric-help?orderId=${Uri.encodeComponent(order.id)}',
              ),
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Fabric & design video help'),
            ),
          ],
        ],
      ),
    );
  }

  String _measurementPlanMessage(BuildContext context) {
    if (order.measurementStatus == 'partner_completed') {
      return 'Your Measurement Partner completed the measurement visit. Your Tailor is reviewing the measurements and will confirm the final fit.';
    }
    if (order.measurementStatus == 'completed') {
      return 'Your Tailor confirmed the final measurements.';
    }
    final date = order.measurementAppointmentAt?.toLocal();
    final appointment = date == null
        ? ''
        : ' ${MaterialLocalizations.of(context).formatMediumDate(date)} at ${TimeOfDay.fromDateTime(date).format(context)}.';
    return switch (order.measurementMethod) {
      'tailor_home_visit' =>
        'Your Tailor arranged a home measurement visit.$appointment',
      'measurement_partner_home_visit' =>
        date == null
            ? 'A Measurement Partner has been assigned and will arrange a home visit slot.'
            : 'Your Measurement Partner scheduled a home visit.$appointment',
      'previous_measurement' =>
        'Your previous measurements will be used as a starting point.',
      'old_garment_reference' =>
        'Please keep the reference dress ready for measurement.',
      'video_appointment' =>
        date == null
            ? 'A Measurement Partner has been assigned and will arrange a video measurement slot.'
            : 'Your video measurement appointment is arranged.$appointment',
      _ => 'Measurement will be arranged.',
    };
  }

  Widget _buildOrderForInfo(DressOrder order) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 17,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Order For: ${order.orderForText}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _quickCarePartnerUpdates(
    BuildContext context,
    VoidCallback? onQuickCareCancel,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .snapshots(),
    builder: (context, snapshot) {
      final data = snapshot.data?.data() ?? const <String, dynamic>{};
      final photoEvidence =
          (data['quickCareEvidence'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(
                (item) =>
                    item['kind'] == 'photo' &&
                    item['expired'] != true &&
                    ((item['storagePath']?.toString() ?? '').isNotEmpty ||
                        (item['previewUrl']?.toString() ?? '').isNotEmpty),
              )
              .toList();
      final name =
          (data['quickCareAssignedPartnerName'] ??
                  data['assignedPartnerName'] ??
                  data['quickCarePartnerName'] ??
                  '')
              .toString()
              .trim();
      final phone =
          (data['quickCareAssignedPartnerPhone'] ??
                  data['assignedPartnerContactPhone'] ??
                  data['quickCarePartnerPhone'] ??
                  '')
              .toString()
              .trim();
      final assignmentStatus =
          (data['quickCareAssignmentStatus'] ??
                  data['partnerAssignmentStatus'] ??
                  (name.isNotEmpty ? 'assigned' : 'searching'))
              .toString()
              .trim()
              .toLowerCase();
      final workflowStatus = (data['quickCareWorkflowStatus'] ?? '')
          .toString()
          .trim();
      final extraStatus = (data['quickCareExtraChargeStatus'] ?? '')
          .toString()
          .trim();
      final quoteStatus = (data['quickCareQuoteStatus'] ?? '')
          .toString()
          .trim();
      final normalizedWorkflow = workflowStatus
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)}_${match.group(2)}',
          )
          .toLowerCase()
          .replaceAll(RegExp(r'[\s-]+'), '_');
      final cancellationRequestPending =
          data['quickCareCancellationRequestStatus'] == 'pending_admin';
      final quoteApproved =
          quoteStatus == 'customerAccepted' || extraStatus == 'approved';
      final cancellationBlocked =
          quoteApproved ||
          cancellationRequestPending ||
          const {
            'started',
            'in_progress',
            'service_started',
            'work_started',
            'paused',
            'payment_pending',
            'completed',
            'service_completed',
            'cancelled',
          }.contains(normalizedWorkflow) ||
          const {
            'completed',
            'delivered',
          }.contains((data['status'] ?? '').toString().toLowerCase()) ||
          data['status'] == 'cancelled' ||
          data['quickCareAssignmentStatus'] == 'cancelled';
      final paymentStatus = (data['paymentStatus'] ?? '').toString();
      final paymentProvider = (data['paymentProvider'] ?? '').toString();
      final verifiedPayment =
          paymentStatus == 'fullyPaid' &&
          ((paymentProvider == 'razorpay' &&
                  (data['quickCareGatewayPaymentId'] as String?)?.isNotEmpty ==
                      true) ||
              (paymentProvider == 'sandbox' &&
                  (data['quickCarePaymentMethod'] as String?)?.isNotEmpty ==
                      true));
      final legacyPartnerPaymentClaim =
          !verifiedPayment &&
          paymentStatus == 'fullyPaid' &&
          (normalizedWorkflow == 'completed' ||
              normalizedWorkflow == 'payment_pending');
      final needsCustomerPayment =
          (normalizedWorkflow == 'payment_pending' && !verifiedPayment) ||
          legacyPartnerPaymentClaim;
      final finalAmount =
          (data['quickCareFinalAmount'] ?? data['price'] ?? 0) as num;
      final amountPaid = (data['amountPaid'] ?? 0) as num;
      final paymentDue = !verifiedPayment
          ? finalAmount
          : (finalAmount - amountPaid).clamp(0, double.infinity);
      final assigned =
          name.isNotEmpty ||
          const {
            'assigned',
            'accepted',
            'partneraccepted',
          }.contains(assignmentStatus.replaceAll('_', ''));
      final accepted = const {
        'accepted',
        'partneraccepted',
      }.contains(assignmentStatus.replaceAll('_', ''));
      final title = needsCustomerPayment
          ? 'Payment needed'
          : assigned
          ? accepted
                ? 'Partner accepted your request'
                : 'Partner assigned'
          : assignmentStatus == 'declined' || assignmentStatus == 'reassigning'
          ? 'Finding another service partner'
          : 'Partner assignment pending';
      final subtitle = workflowStatus == 'accepted'
          ? 'Next action: share the last four digits of your registered mobile so your Partner can start.'
          : workflowStatus == 'inProgress'
          ? 'Your Partner is working on the service. We’ll let you know when payment is due.'
          : workflowStatus == 'paused'
          ? 'The service is paused. Your Partner will update you before resuming.'
          : needsCustomerPayment
          ? 'Next action: pay ₹${paymentDue.toStringAsFixed(0)} securely in the app. The booking closes after payment is verified.'
          : workflowStatus == 'completed'
          ? 'Service completed and paid · final amount ₹${data['quickCareFinalAmount'] ?? data['price'] ?? 0}.'
          : workflowStatus == 'awaitingCustomerApproval'
          ? 'Next action: approve or decline your Partner’s quote below.'
          : assigned
          ? 'Service and booking updates will appear here.'
          : 'We’ll show your assigned Quick Care partner and service updates here.';

      return Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF6D9E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  assigned
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF102451),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (phone.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    phone,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            if (photoEvidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: const Text('Before and after photos'),
                subtitle: Text(
                  '${photoEvidence.length} service photo${photoEvidence.length == 1 ? '' : 's'}',
                ),
                children: [
                  for (final item in photoEvidence)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _quickCareEvidenceLabel(item['note']?.toString()),
                          ),
                          const SizedBox(height: 5),
                          _QuickCareCustomerPhoto(item: item),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (workflowStatus == 'paused' &&
                (data['quickCarePauseReason']?.toString() ?? '')
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Paused: ${data['quickCarePauseReason']}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (workflowStatus == 'completed' && !needsCustomerPayment) ...[
              const SizedBox(height: 5),
              Text(
                'Final amount · ₹${data['quickCareFinalAmount'] ?? data['price'] ?? 0} · ${data['quickCarePointsPending'] ?? 0} Partner points pending review',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (data['quickCareCustomerRating'] is num)
                Text(
                  'Your rating · ${data['quickCareCustomerRating']}/5',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else ...[
                const SizedBox(height: 5),
                const Text('Rate your Quick Care service'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var rating = 1; rating <= 5; rating++)
                      IconButton(
                        tooltip: 'Rate $rating star${rating == 1 ? '' : 's'}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _submitQuickCareRating(context, rating),
                        icon: const Icon(Icons.star_rounded),
                        color: const Color(0xFFF2A900),
                      ),
                  ],
                ),
              ],
            ],
            if (extraStatus == 'pendingCustomerApproval') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['quickCareExtraChargeType'] == 'serviceQuote' ? 'Service quote' : 'Additional work quote'} · ₹${data['quickCareExtraChargeAmount'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if ((data['quickCareExtraChargeReason']?.toString() ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(data['quickCareExtraChargeReason'].toString()),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Approve or decline this amount before the Partner continues.',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _respondQuickCareExtraCharge(
                            context,
                            approve: false,
                          ),
                          child: const Text('Decline'),
                        ),
                        FilledButton(
                          onPressed: () => _respondQuickCareExtraCharge(
                            context,
                            approve: true,
                          ),
                          child: const Text('Approve quote'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (needsCustomerPayment && paymentDue > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pay the customer-approved final amount in the app. The Partner cannot report or confirm payment; the service closes after payment verification.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final paymentConfirmed = await context.push<bool>(
                      '/checkout/${order.id}',
                    );
                    if (paymentConfirmed != true) return;
                    await onQuickCarePaymentReturn?.call();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Quick Care payment verified. The booking is now closed.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text('Pay ₹${paymentDue.toStringAsFixed(0)} now'),
                ),
              ),
            ],
            if (snapshot.hasData &&
                data.isNotEmpty &&
                !cancellationBlocked &&
                onQuickCareCancel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onQuickCareCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel service'),
                ),
              ),
            ],
            if (quoteApproved && normalizedWorkflow != 'completed') ...[
              const SizedBox(height: 8),
              const Text(
                'The quote is approved. This service can no longer be cancelled from the customer app.',
                style: TextStyle(color: Color(0xFF777286)),
              ),
            ],
            if (cancellationRequestPending) ...[
              const SizedBox(height: 8),
              const Text(
                'Your cancellation request is with Helpdesk. They will follow up with you.',
                style: TextStyle(color: Color(0xFF777286)),
              ),
            ],
          ],
        ),
      );
    },
  );

  String _quickCareEvidenceLabel(String? note) => switch (note) {
    'before_work' => 'Before service',
    'after_work' => 'After service',
    _ => 'Service photo',
  };

  Future<void> _respondQuickCareExtraCharge(
    BuildContext context, {
    required bool approve,
  }) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('respondQuickCareExtraCharge')
          .call(<String, dynamic>{'orderId': order.id, 'approve': approve});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Quote approved. Your Partner can proceed with the service.'
                : 'Quote declined. Your Partner can revise the quote or contact you.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not send your response.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your response. Please retry.'),
        ),
      );
    }
  }

  Future<void> _submitQuickCareRating(BuildContext context, int rating) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('submitQuickCareRating')
          .call(<String, dynamic>{'orderId': order.id, 'rating': rating});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks for rating your Quick Care service.'),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not submit your rating.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit your rating. Please retry.'),
        ),
      );
    }
  }

  Widget _buildBulkRequestInfo(DressOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _orderInfoLine(
          icon: Icons.person_outline_rounded,
          text: 'Requested By: ${order.requestedByText}',
        ),
        if (order.eventText != null)
          _orderInfoLine(
            icon: Icons.event_note_outlined,
            text: 'Event: ${order.eventText}',
          ),
        if (order.consultationText != null)
          _orderInfoLine(
            icon: Icons.support_agent_outlined,
            text: 'Consultation: ${order.consultationText}',
          ),
        if (order.eventDate != null)
          _orderInfoLine(
            icon: Icons.calendar_today_outlined,
            text: 'Event Date: ${_formatDate(order.eventDate!)}',
          ),
      ],
    );
  }

  Widget _orderInfoLine({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
        Text(value, style: AppTextStyles.titleMedium),
      ],
    );
  }

  Widget _buildHandoverTimeline(BuildContext context, DressOrder order) {
    final status = order.status;
    final confirmed =
        order.assignmentStatus == 'finalized' ||
        order.paymentStatus == PaymentStatus.advancePaid ||
        order.paymentStatus == PaymentStatus.fullyPaid;
    final pickupDone =
        [
          'collectedFromCustomer',
          'receivedAtTailor',
        ].contains(order.inboundPickupStatus) ||
        [
          OrderStatus.atTailor,
          OrderStatus.inStitching,
          OrderStatus.qcPending,
          OrderStatus.qcPassed,
          OrderStatus.readyForPickup,
          OrderStatus.outForDelivery,
          OrderStatus.delivered,
        ].contains(status);
    final tailorReceived =
        order.inboundPickupStatus == 'receivedAtTailor' ||
        [
          OrderStatus.atTailor,
          OrderStatus.inStitching,
          OrderStatus.qcPending,
          OrderStatus.qcPassed,
          OrderStatus.readyForPickup,
          OrderStatus.outForDelivery,
          OrderStatus.delivered,
        ].contains(status);
    final stitchingStarted = [
      OrderStatus.inStitching,
      OrderStatus.qcPending,
      OrderStatus.qcPassed,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(status);
    final qcReviewCompleted = [
      OrderStatus.qcPassed,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(status);
    final qcPassed = [
      OrderStatus.qcPassed,
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(status);
    final readyForDelivery = [
      OrderStatus.readyForPickup,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(status);
    final balancePaid =
        readyForDelivery && order.paymentStatus == PaymentStatus.fullyPaid;
    final deliveryAssigned =
        (balancePaid &&
            [
              "assigned",
              "in_transit",
              "delivered",
            ].contains(order.outboundHandoverStatus)) ||
        [OrderStatus.outForDelivery, OrderStatus.delivered].contains(status);
    final outForDelivery = [
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(status);
    final delivered = status == OrderStatus.delivered;
    final completed = <bool>[
      confirmed,
      pickupDone,
      tailorReceived,
      stitchingStarted,
      qcReviewCompleted,
      qcPassed,
      readyForDelivery,
      balancePaid,
      deliveryAssigned,
      outForDelivery,
      delivered,
    ];
    final lastComplete = completed.lastIndexWhere((value) => value);
    final activeIndex = delivered ? 10 : (lastComplete + 1).clamp(0, 10);
    const labels = <String>[
      'Confirmed',
      'Pickup',
      'At tailor',
      'Stitching',
      'QC review',
      'QC passed',
      'Ready for delivery',
      'Pay balance',
      'Delivery assigned',
      'Out for delivery',
      'Delivered',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order journey', style: AppTextStyles.bodySmall),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(labels.length * 2 - 1, (index) {
              if (index.isOdd) {
                final step = index ~/ 2;
                return Container(
                  width: 28,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: completed[step] && completed[step + 1]
                      ? AppColors.primary
                      : AppColors.divider,
                );
              }
              final step = index ~/ 2;
              final done = completed[step];
              final current = step == activeIndex;
              final color = done || current
                  ? AppColors.primary
                  : AppColors.textHint;
              return SizedBox(
                width: 72,
                child: Semantics(
                  label:
                      '${labels[step]}${done
                          ? ', complete'
                          : current
                          ? ', current'
                          : ''}',
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? AppColors.primary : AppColors.surface,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: done
                            ? const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : current
                            ? Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[step],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: color,
                          fontSize: 10,
                          fontWeight: current
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        for (final milestone in <(String, DateTime?)>[
          ('Measurement appointment', order.measurementAppointmentAt),
          (
            'Measurement completed by Partner',
            order.measurementPartnerCompletedAt,
          ),
          ('Measurements confirmed by Tailor', order.measurementConfirmedAt),
          ('Pickup assigned', order.inboundPickupAssignedAt),
          ('Pickup completed', order.inboundPickupCollectedAt),
          ('Received at Tailor', order.inboundPickupReceivedAt),
          ('Return handover assigned', order.outboundHandoverAssignedAt),
          ('Return handover started', order.outboundHandoverAcceptedAt),
          ('Delivered', order.deliveredAt),
        ])
          if (milestone.$2 != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${milestone.$1} · ${_formatTimelineTime(context, milestone.$2!)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
      ],
    );
  }

  String _formatTimelineTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  Widget _buildProgressBar(DressOrder order) {
    final p = order.status.pipelineProgress;
    final pct = (p * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order progress', style: AppTextStyles.bodySmall),
            Text(
              '$pct%',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF2196F3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _QuickCareCustomerPhoto extends StatelessWidget {
  const _QuickCareCustomerPhoto({required this.item});

  final Map<String, dynamic> item;

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
    final fallbackUrl = item['previewUrl']?.toString() ?? '';
    return FutureBuilder<Uint8List?>(
      future: _photoBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
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
          return const Text('Photo is temporarily unavailable.');
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
                      const Text('Photo is temporarily unavailable.'),
                ),
        );
      },
    );
  }
}

class _PartnerContactRow extends StatelessWidget {
  const _PartnerContactRow({
    required this.label,
    required this.phone,
    this.note,
  });

  final String label;
  final String phone;
  final String? note;

  Future<void> _call(BuildContext context) async {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        if (note?.isNotEmpty == true)
          Text(note!, style: AppTextStyles.bodySmall),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                phone.isEmpty ? 'Not assigned yet' : phone,
                style: AppTextStyles.bodyMedium,
              ),
            ),
            IconButton(
              tooltip: 'Call $label',
              onPressed: phone.isEmpty ? null : () => _call(context),
              icon: const Icon(Icons.call_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderDraftSummary {
  final String draftId;
  final String dressType;
  final String personName;
  final String relationship;
  final String occasionCategory;
  final String status;
  final DateTime updatedAt;

  const _OrderDraftSummary({
    required this.draftId,
    required this.dressType,
    required this.personName,
    required this.relationship,
    required this.occasionCategory,
    required this.status,
    required this.updatedAt,
  });

  factory _OrderDraftSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final updatedAtRaw = data['updatedAt'];

    DateTime updatedAt = DateTime.now();

    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    }

    return _OrderDraftSummary(
      draftId: data['draftId']?.toString() ?? id,
      dressType: data['dressType']?.toString() ?? 'Dress Draft',
      personName: data['personName']?.toString() ?? 'Customer',
      relationship: data['relationship']?.toString() ?? '',
      occasionCategory: data['occasionCategory']?.toString() ?? '',
      status: data['status']?.toString() ?? 'draft',
      updatedAt: updatedAt,
    );
  }

  String get personText {
    if (relationship.trim().isNotEmpty &&
        relationship.trim().toLowerCase() != 'self') {
      return '$personName ($relationship)';
    }

    return personName;
  }
}

class _DraftOrderCard extends StatelessWidget {
  final _OrderDraftSummary draft;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const _DraftOrderCard({
    required this.draft,
    required this.onResume,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final occasion = draft.occasionCategory.trim().isEmpty
        ? null
        : _occasionDisplayName(draft.occasionCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${draft.dressType} Draft',
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (occasion != null)
                      Text(
                        occasion,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Draft',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _draftLine(
            icon: Icons.person_outline_rounded,
            text: 'For: ${draft.personText}',
          ),
          const SizedBox(height: 4),
          _draftLine(
            icon: Icons.schedule_rounded,
            text: 'Updated: ${_formatDraftDate(draft.updatedAt)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onDiscard,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftLine({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDraftDate(DateTime date) {
    final months = [
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

    return '${date.day} ${months[date.month - 1]}';
  }
}

class _ArchivedDraftOrderCard extends StatelessWidget {
  final _OrderDraftSummary draft;
  final VoidCallback onRecover;

  const _ArchivedDraftOrderCard({required this.draft, required this.onRecover});

  @override
  Widget build(BuildContext context) {
    final occasion = draft.occasionCategory.trim().isEmpty
        ? null
        : _occasionDisplayName(draft.occasionCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.archive_outlined,
                  color: AppColors.textHint,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${draft.dressType} Draft',
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (occasion != null)
                      Text(
                        occasion,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Archived',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _archivedLine(
            icon: Icons.person_outline_rounded,
            text: 'For: ${draft.personText}',
          ),
          const SizedBox(height: 4),
          _archivedLine(
            icon: Icons.archive_outlined,
            text: 'Archived: ${_formatArchivedDraftDate(draft.updatedAt)}',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRecover,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Recover Draft'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _archivedLine({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _formatArchivedDraftDate(DateTime date) {
    final months = [
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

    return '${date.day} ${months[date.month - 1]}';
  }
}
