import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CustomerSupportService {
  CustomerSupportService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<String> categories = [
    'Order Issue',
    'Measurement Issue',
    'Fabric Issue',
    'Designer Issue',
    'Payment Issue',
    'Garment Care Issue',
    'Quick Care Issue',
    'Delivery Issue',
    'Other',
  ];

  static String teamForCategory(String category) => switch (category) {
    'Order Issue' => 'orders',
    'Measurement Issue' => 'measurements',
    'Fabric Issue' || 'Designer Issue' => 'design_and_fabric',
    'Payment Issue' => 'payments',
    'Garment Care Issue' => 'garment_care',
    'Quick Care Issue' => 'quick_care',
    'Delivery Issue' => 'delivery',
    _ => 'customer_support',
  };

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMyTickets() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return const Stream.empty();
    return _db
        .collection('support_tickets')
        .where('customerUid', isEqualTo: uid)
        .snapshots();
  }

  static Future<void> createTicket({
    required String customerName,
    required String category,
    required String subject,
    required String message,
    String? linkedOrderId,
    String? linkedOrderType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to contact support.');

    final normalizedMessage = message.trim();
    final normalizedSubject = subject.trim();
    if (!categories.contains(category)) {
      throw ArgumentError.value(category, 'category', 'Invalid support topic.');
    }
    if (normalizedSubject.isEmpty || normalizedSubject.length > 100) {
      throw ArgumentError('Add a short subject (up to 100 characters).');
    }
    if (normalizedMessage.length < 5 || normalizedMessage.length > 2000) {
      throw ArgumentError('Describe the issue in 5 to 2,000 characters.');
    }

    final orderId = linkedOrderId?.trim();
    final orderType = linkedOrderType?.trim();
    if (orderId != null &&
        orderId.isNotEmpty &&
        !const {
          'tailoring',
          'garment_care',
          'quick_care',
        }.contains(orderType)) {
      throw ArgumentError.value(
        linkedOrderType,
        'linkedOrderType',
        'Choose a supported order type.',
      );
    }
    await FirebaseFunctions.instance
        .httpsCallable('createCustomerSupportTicket')
        .call({
          'customerName': customerName.trim().isEmpty
              ? (user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'Customer')
              : customerName.trim(),
          'category': category,
          'subject': normalizedSubject,
          'message': normalizedMessage,
          'linkedOrderId': orderId == null || orderId.isEmpty ? null : orderId,
          'linkedOrderType': orderId == null || orderId.isEmpty
              ? null
              : orderType,
        });
  }

  /// Opens an offline quotation request as a Helpdesk ticket. This deliberately
  /// does not create an order or payment record.
  static Future<String> createServiceRequest({
    required String requestType,
    required String customerName,
    required String subject,
    required String message,
    required Map<String, Object?> details,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to send this request.');
    if (!const {'bulk_order', 'dress_rental'}.contains(requestType)) {
      throw ArgumentError.value(requestType, 'requestType');
    }
    if (subject.trim().isEmpty || subject.trim().length > 100) {
      throw ArgumentError('Add a short request title.');
    }
    if (message.trim().length < 5 || message.trim().length > 2000) {
      throw ArgumentError('Request details must be under 2,000 characters.');
    }

    final result = await FirebaseFunctions.instance
        .httpsCallable('createCustomerSupportTicket')
        .call({
          'customerName': customerName.trim().isEmpty
              ? (user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'Customer')
              : customerName.trim(),
          'category': 'Other',
          'subject': subject.trim(),
          'message': message.trim(),
          'requestType': requestType,
          'requestDetails': details,
        });
    final ticketId = (result.data as Map?)?['ticketId']?.toString().trim();
    if (ticketId == null || ticketId.isEmpty) {
      throw StateError('The Helpdesk did not return a request number.');
    }
    return ticketId;
  }

  /// Lets the customer add a note, confirm completion, or cancel their own
  /// offline service request. The callable verifies ticket ownership.
  static Future<void> updateServiceRequest({
    required String ticketId,
    required String action,
    String? comment,
  }) async {
    if (!const {'comment', 'completed', 'cancel'}.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    final normalizedComment = comment?.trim() ?? '';
    if (action == 'comment' &&
        (normalizedComment.length < 2 || normalizedComment.length > 1000)) {
      throw ArgumentError('Comments must be between 2 and 1,000 characters.');
    }
    await FirebaseFunctions.instance
        .httpsCallable('updateCustomerServiceRequest')
        .call({
          'ticketId': ticketId,
          'action': action,
          if (action == 'comment') 'comment': normalizedComment,
        });
  }
}
