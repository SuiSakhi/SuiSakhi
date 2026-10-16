import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';

class OrderTagLookupScreen extends StatefulWidget {
  const OrderTagLookupScreen({required this.trackingId, super.key});

  final String trackingId;

  @override
  State<OrderTagLookupScreen> createState() => _OrderTagLookupScreenState();
}

class _OrderTagLookupScreenState extends State<OrderTagLookupScreen> {
  String? _lookupUid;
  Future<_OrderTagData?>? _lookupFuture;

  Future<_OrderTagData?> _lookup(String uid, User user) async {
    final matches = await FirebaseFirestore.instance
        .collection('orders')
        .where('orderTrackingId', isEqualTo: widget.trackingId)
        .limit(1)
        .get();
    if (matches.docs.isEmpty) return null;

    final doc = matches.docs.first;
    final data = doc.data();
    var authorized = data['customerId'] == uid;
    final phone = user.phoneNumber?.trim() ?? '';
    if (!authorized && phone.isNotEmpty) {
      final accountId = await AppState.instance.fetchAccountIdForMobile(phone);
      authorized =
          accountId != null &&
          accountId.isNotEmpty &&
          <Object?>[
            data['assignedTailorAccountId'],
            data['measurementPartnerAccountId'],
            data['inboundPickupPartnerAccountId'],
            data['outboundHandoverPartnerAccountId'],
          ].contains(accountId);
    }
    if (!authorized) return null;
    return _OrderTagData(documentId: doc.id, fields: data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order tag')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = authSnapshot.data;
          if (user == null) {
            return const _OrderTagMessage(
              icon: Icons.lock_outline,
              message:
                  'Sign in as the Customer or an assigned Partner to open this order tag.',
            );
          }
          if (_lookupUid != user.uid) {
            _lookupUid = user.uid;
            _lookupFuture = _lookup(user.uid, user);
          }
          return FutureBuilder<_OrderTagData?>(
            future: _lookupFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const _OrderTagMessage(
                  icon: Icons.cloud_off_outlined,
                  message:
                      'Could not load this order. Check the connection and scan the tag again.',
                );
              }
              final order = snapshot.data;
              if (order == null) {
                return const _OrderTagMessage(
                  icon: Icons.search_off_rounded,
                  message: 'No order available for this account and tag.',
                );
              }
              return _OrderTagDetails(
                order: order,
                trackingId: widget.trackingId,
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderTagData {
  const _OrderTagData({required this.documentId, required this.fields});

  final String documentId;
  final Map<String, dynamic> fields;
}

class _OrderTagDetails extends StatelessWidget {
  const _OrderTagDetails({required this.order, required this.trackingId});

  final _OrderTagData order;
  final String trackingId;

  String value(String key) => (order.fields[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final address = value('deliveryAddress');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value('dressType').isEmpty
                      ? 'Tailored order'
                      : value('dressType'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                SelectableText('Order ID · $trackingId'),
                const SizedBox(height: 10),
                Chip(
                  label: Text(
                    value('status').isEmpty ? 'Order' : value('status'),
                  ),
                ),
                _detail('For', value('clientName')),
                _detail('Customer contact', value('customerPhone')),
                _detail('Service PIN', value('deliveryPincode')),
                _detail('Design', value('designTemplateTitle')),
                _detail('Material', value('fabricChoice')),
                if (address.isNotEmpty) _detail('Delivery address', address),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: trackingId)),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy order ID'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text('$label · $value'),
    );
  }
}

class _OrderTagMessage extends StatelessWidget {
  const _OrderTagMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
