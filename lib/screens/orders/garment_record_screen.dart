import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_text_styles.dart';
import '../../widgets/orders/pickup_photo_attachment_button.dart';

class GarmentRecordScreen extends StatelessWidget {
  const GarmentRecordScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garment DNA report')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final uid = authSnapshot.data?.uid;
          if (uid == null) {
            return const _ReportMessage(
              icon: Icons.lock_outline,
              text:
                  'Sign in to the customer account that owns this order, then scan the report QR again.',
            );
          }
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data?.data();
              if (!snapshot.hasData || data == null) {
                return const _ReportMessage(
                  icon: Icons.search_off_rounded,
                  text: 'This order report could not be found.',
                );
              }
              if (data['customerId'] != uid) {
                return const _ReportMessage(
                  icon: Icons.lock_outline,
                  text:
                      'This report is private to the customer account that owns the order.',
                );
              }
              final rawRecord = data['garmentRecord'];
              final record = rawRecord is Map
                  ? Map<String, dynamic>.from(rawRecord)
                  : const <String, dynamic>{};
              if (record.isEmpty || data['garmentRecordPublishedAt'] == null) {
                return const _ReportMessage(
                  icon: Icons.hourglass_empty_rounded,
                  text: 'The Tailor has not published this report yet.',
                );
              }
              return _GarmentRecordBody(
                record: record,
                orderId: orderId,
                orderTrackingId: (data['orderTrackingId'] ?? orderId)
                    .toString(),
              );
            },
          );
        },
      ),
    );
  }
}

class _GarmentRecordBody extends StatelessWidget {
  const _GarmentRecordBody({
    required this.record,
    required this.orderId,
    required this.orderTrackingId,
  });

  final Map<String, dynamic> record;
  final String orderId;
  final String orderTrackingId;

  String _value(Map<String, dynamic> map, String key) =>
      (map[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final material = record['material'] is Map
        ? Map<String, dynamic>.from(record['material'] as Map)
        : const <String, dynamic>{};
    final measurements = record['measurements'] is Map
        ? Map<String, dynamic>.from(record['measurements'] as Map)
        : const <String, dynamic>{};
    final trace = record['traceability'] is Map
        ? Map<String, dynamic>.from(record['traceability'] as Map)
        : const <String, dynamic>{};
    final sortedMeasurements = measurements.entries.toList()
      ..sort((a, b) {
        int number(String key) =>
            int.tryParse(
              RegExp(r'^\s*(\d+)').firstMatch(key)?.group(1) ?? '',
            ) ??
            999;
        return number(a.key).compareTo(number(b.key));
      });

    Widget section(String title, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );

    Widget line(String label, String value) => value.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: Colors.black87),
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

    final imageUrl = _value(record, 'designImageUrl');
    final materialImage = _value(material, 'customerReferenceImageUrl');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Order $orderTrackingId', style: AppTextStyles.labelMedium),
        const SizedBox(height: 12),
        section('Garment and design', [
          line('Garment type', _value(record, 'garmentType')),
          line('Occasion', _value(record, 'occasion')),
          line('Selected design', _value(record, 'designTitle')),
          line('Design notes', _value(record, 'designDescription')),
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.cover, height: 190),
              ),
            ),
        ]),
        section('Material and care', [
          line('Customer selection', _value(material, 'customerSelection')),
          line(
            'Customer material description',
            _value(material, 'customerDescription'),
          ),
          line('Fibre composition', _value(material, 'fiberComposition')),
          line('Composition source', switch (_value(
            material,
            'compositionSource',
          )) {
            'supplier_label' => 'Supplier label transcribed by Tailor',
            'customer_label' => 'Customer-provided label',
            'visual_only' => 'Visual estimate only',
            _ => 'Not provided',
          }),
          line('Care guidance', _value(material, 'careInstructions')),
          line('Care guidance source', switch (_value(
            material,
            'careInstructionsSource',
          )) {
            'tailor_qc' => 'Reviewed or edited by the Tailor during QC',
            'conservative_template' =>
              'Conservative material-aware starter guidance',
            _ => '',
          }),
          if (materialImage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  materialImage,
                  fit: BoxFit.cover,
                  height: 190,
                ),
              ),
            ),
          if (_value(material, 'pickupPhotoPath').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PickupPhotoAttachmentButton(
                storagePath: _value(material, 'pickupPhotoPath'),
              ),
            ),
        ]),
        section('Tailor quality check', [
          line('Construction / finishing', _value(record, 'constructionNotes')),
          line('Quality check', _value(record, 'qualityCheckNotes')),
          line('Fit', _value(record, 'fit')),
          for (final entry in sortedMeasurements)
            line(
              entry.key,
              '${entry.value} ${_value(record, 'measurementUnit')}',
            ),
        ]),
        section('Order traceability', [
          line('Ordered', _date(trace['orderedAt'])),
          line('Collected', _date(trace['collectedAt'])),
          line('Received by Tailor', _date(trace['receivedAtTailorAt'])),
          line('Delivered', _date(trace['deliveredAt'])),
        ]),
        if (_value(record, 'evidenceNote').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _value(record, 'evidenceNote'),
              style: AppTextStyles.bodySmall,
            ),
          ),
      ],
    );
  }

  String _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toLocal().toString();
    return raw?.toString() ?? '';
  }
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
