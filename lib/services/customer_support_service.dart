import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    'Delivery Issue',
    'Other',
  ];

  static String teamForCategory(String category) => switch (category) {
    'Order Issue' => 'orders',
    'Measurement Issue' => 'measurements',
    'Fabric Issue' || 'Designer Issue' => 'design_and_fabric',
    'Payment Issue' => 'payments',
    'Garment Care Issue' => 'garment_care',
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
    await _db.collection('support_tickets').add({
      'customerUid': user.uid,
      'customerName': customerName.trim().isEmpty
          ? (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : 'Customer')
          : customerName.trim(),
      'category': category,
      'subject': normalizedSubject,
      'message': normalizedMessage,
      'linkedOrderId': orderId == null || orderId.isEmpty ? null : orderId,
      'assignedTeam': teamForCategory(category),
      'status': 'Open',
      'source': 'customer_helpdesk',
      'languageCode': 'en',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
