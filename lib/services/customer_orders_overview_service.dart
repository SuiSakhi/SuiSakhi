import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/dress.dart';
import '../models/prd_catalog.dart';

class CustomerOrderDraftSummary {
  const CustomerOrderDraftSummary({
    required this.id,
    required this.dressType,
    required this.personName,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String dressType;
  final String personName;
  final String status;
  final DateTime updatedAt;

  factory CustomerOrderDraftSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawUpdatedAt = data['updatedAt'];
    return CustomerOrderDraftSummary(
      id: data['draftId']?.toString() ?? id,
      dressType: data['dressType']?.toString().trim().isNotEmpty == true
          ? data['dressType'].toString()
          : 'Dress draft',
      personName: data['personName']?.toString().trim().isNotEmpty == true
          ? data['personName'].toString()
          : 'Customer',
      status: data['status']?.toString() ?? 'draft',
      updatedAt: rawUpdatedAt is Timestamp
          ? rawUpdatedAt.toDate()
          : DateTime.now(),
    );
  }
}

class CustomerOrdersOverview {
  const CustomerOrdersOverview({required this.orders, required this.drafts});

  final List<DressOrder> orders;
  final List<CustomerOrderDraftSummary> drafts;

  List<DressOrder> get tailoringOrders => orders
      .where((order) => order.orderModuleType == OrderModuleType.coreTailoring)
      .toList(growable: false);

  List<DressOrder> get activeTailoringOrders => tailoringOrders
      .where(
        (order) =>
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled,
      )
      .toList(growable: false);

  List<DressOrder> get completedTailoringOrders => tailoringOrders
      .where((order) => order.status == OrderStatus.delivered)
      .toList(growable: false);

  List<OrderDashboardAlert> get tailoringAlerts => tailoringOrders
      .map(OrderDashboardAlert.fromOrder)
      .whereType<OrderDashboardAlert>()
      .toList(growable: false);

  static Future<CustomerOrdersOverview> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const CustomerOrdersOverview(orders: [], drafts: []);
    }

    final db = FirebaseFirestore.instance;
    Future<QuerySnapshot<Map<String, dynamic>>?> loadDrafts() async {
      try {
        return await db
            .collection('order_drafts')
            .where('customerUid', isEqualTo: uid)
            .get();
      } catch (_) {
        // Orders remain useful even if the optional draft query is unavailable.
        return null;
      }
    }

    final results = await Future.wait<dynamic>([
      db.collection('orders').where('customerId', isEqualTo: uid).get(),
      loadDrafts(),
    ]);

    final orderSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final draftSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>?;
    final orders =
        orderSnapshot.docs
            .map((doc) => DressOrder.fromFirestore(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final drafts =
        (draftSnapshot?.docs ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            .map(
              (doc) =>
                  CustomerOrderDraftSummary.fromFirestore(doc.id, doc.data()),
            )
            .where((draft) => draft.id.isNotEmpty && draft.status == 'draft')
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return CustomerOrdersOverview(orders: orders, drafts: drafts);
  }
}

class OrderDashboardAlert {
  const OrderDashboardAlert({
    required this.order,
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final DressOrder order;
  final String title;
  final String message;
  final String actionLabel;

  static OrderDashboardAlert? fromOrder(DressOrder order) {
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.delivered) {
      return null;
    }

    final fabricStatus = order.fabricRequirementReview?['status']?.toString();
    if (fabricStatus == 'shortfall_pending_customer') {
      return OrderDashboardAlert(
        order: order,
        title: 'Confirm additional fabric',
        message: 'Your Tailor is waiting for your confirmation.',
        actionLabel: 'Review order',
      );
    }

    if (order.assignmentStatus == 'awaiting_customer_decision') {
      return OrderDashboardAlert(
        order: order,
        title: 'Review your Tailor’s response',
        message: 'Check the expected completion date and next steps.',
        actionLabel: 'Review order',
      );
    }

    if (order.status == OrderStatus.readyForPickup &&
        order.paymentStatus == PaymentStatus.advancePaid) {
      return OrderDashboardAlert(
        order: order,
        title: 'Balance payment needed',
        message: 'Your order is ready for dispatch after payment.',
        actionLabel: 'Pay balance',
      );
    }

    if (order.paymentStatus == PaymentStatus.pendingPayment &&
        (!order.usesProductionAssignment ||
            (order.assignmentStatus == 'awaiting_customer_decision' &&
                order.expectedReadyAt != null))) {
      return OrderDashboardAlert(
        order: order,
        title: 'Advance payment needed',
        message: 'Complete payment to move your order forward.',
        actionLabel: 'Pay advance',
      );
    }

    return null;
  }
}
