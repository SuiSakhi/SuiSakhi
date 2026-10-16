import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/measurement.dart';
import 'customer_fabric_asset_service.dart';

/// Customer-facing history of measurements. Tailor-confirmed values remain the
/// source of truth for fit; customer references are stored separately and are
/// never returned by [loadLatestTailorConfirmed].
class CustomerMeasurementHistoryService {
  CustomerMeasurementHistoryService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<List<CustomerMeasurementRecord>> loadHistory({
    required String customerUid,
    required String accountId,
    required String personId,
    required String personName,
    int limit = 10,
  }) async {
    final records = <CustomerMeasurementRecord>[];

    final measurementSnapshot = await _db
        .collection('measurements')
        .where('accountId', isEqualTo: accountId)
        .where('personId', isEqualTo: personId)
        .get();

    for (final doc in measurementSnapshot.docs) {
      final data = doc.data();
      final values = _stringMap(data['measurementValues']);
      final status = (data['status'] ?? '').toString();
      if (status == 'draft' || status == 'superseded') continue;
      final isCustomerReference = data['referenceOnly'] == true ||
          status == 'customer_reference';
      if (values.isEmpty &&
          !(isCustomerReference &&
              ((data['referenceImageUrl']?.toString().isNotEmpty ?? false) ||
                  (data['sourceOrderId']?.toString().isNotEmpty ?? false)))) {
        continue;
      }
      records.add(
        CustomerMeasurementRecord(
          id: doc.id,
          title: data['referenceTitle']?.toString().trim().isNotEmpty == true
              ? data['referenceTitle'].toString().trim()
              : _sourceTitle(data['source']?.toString(), status),
          source: (data['source'] ?? 'measurement').toString(),
          status: status,
          capturedAt: _date(data['updatedAt']) ??
              _date(data['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          values: values,
          unit: (data['measurementUnit'] ?? data['unit'] ?? 'cm').toString(),
          note: data['customerNote']?.toString(),
          referenceImageUrl: data['referenceImageUrl']?.toString(),
          sourceOrderId: data['sourceOrderId']?.toString(),
          isCustomerReference: isCustomerReference,
        ),
      );
    }

    QuerySnapshot<Map<String, dynamic>>? orderSnapshot;
    try {
      orderSnapshot = await _db
          .collection('orders')
          .where('customerId', isEqualTo: customerUid)
          .get();
    } catch (_) {
      // Account-owned measurement records can still be shown if older order
      // records are temporarily unavailable.
    }

    for (final doc in orderSnapshot?.docs ?? const []) {
      final order = doc.data();
      if (!_orderMatchesPerson(order, personId, personName)) continue;

      final orderTitle = _orderTitle(order);
      final imageUrl = await _orderImage(order);
      final confirmedAt = _date(order['measurementConfirmedAt']);
      if (order['measurementStatus'] == 'completed' && confirmedAt != null) {
        final values = _stringMap(order['measurementSubmittedValues']);
        if (values.isNotEmpty) {
          records.add(
            CustomerMeasurementRecord(
              id: '${doc.id}_confirmed_${confirmedAt.millisecondsSinceEpoch}',
              title: '$orderTitle · Tailor confirmed',
              source: 'partner_confirmed',
              status: 'confirmed',
              capturedAt: confirmedAt,
              values: values,
              unit: (order['measurementSubmittedUnit'] ?? 'in').toString(),
              referenceImageUrl: imageUrl,
              sourceOrderId: doc.id,
              isCustomerReference: false,
            ),
          );
        }
      }

      final rawHistory = order['measurementHistory'];
      if (rawHistory is! List) continue;
      for (var index = 0; index < rawHistory.length; index++) {
        final entry = rawHistory[index];
        if (entry is! Map) continue;
        final timestamp = _date(entry['confirmedAt']);
        if (timestamp == null) continue;
        final values = _stringMap(
          entry['submittedValues'] ?? entry['measurementSubmittedValues'],
        );
        if (values.isEmpty) continue;
        records.add(
          CustomerMeasurementRecord(
            id: '${doc.id}_history_${index}_${timestamp.millisecondsSinceEpoch}',
            title: '$orderTitle · Tailor confirmed',
            source: 'partner_confirmed',
            status: 'confirmed',
            capturedAt: timestamp,
            values: values,
            unit: (entry['submittedUnit'] ??
                    entry['measurementSubmittedUnit'] ??
                    'in')
                .toString(),
            note: entry['note']?.toString(),
            referenceImageUrl: imageUrl,
            sourceOrderId: doc.id,
            isCustomerReference: false,
          ),
        );
      }
    }

    records.sort((left, right) => right.capturedAt.compareTo(left.capturedAt));
    final seen = <String>{};
    return records
        .where((record) => seen.add(
              '${record.sourceOrderId ?? record.id}|${record.capturedAt.millisecondsSinceEpoch}|${record.source}',
            ))
        .take(limit)
        .toList(growable: false);
  }

  /// Previous customer orders available as garment-photo references.
  static Future<List<CustomerDressReference>> loadDressReferences({
    required String customerUid,
    required String personId,
    required String personName,
  }) async {
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: customerUid)
        .get();
    final references = <CustomerDressReference>[];

    for (final doc in snapshot.docs) {
      final order = doc.data();
      if (!_orderMatchesPerson(order, personId, personName)) continue;
      references.add(
        CustomerDressReference(
          orderId: doc.id,
          title: _orderTitle(order),
          date: _date(order['orderDate']) ?? _date(order['createdAt']),
          imageUrl: await _orderImage(order),
          values: _orderMeasurementValues(order),
          unit: (order['measurementSubmittedUnit'] ?? 'cm').toString(),
          status: (order['status'] ?? 'order').toString(),
          orderNotes: order['notes']?.toString(),
        ),
      );
    }
    references.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return references;
  }

  static Future<BodyMeasurements?> loadLatestTailorConfirmed({
    required String customerUid,
    required String personId,
    required String personName,
  }) async {
    final snapshot = await _db
        .collection('orders')
        .where('customerId', isEqualTo: customerUid)
        .get();

    final candidates = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final order = doc.data();
      if (!_orderMatchesPerson(order, personId, personName)) continue;

      final confirmedAt = _date(order['measurementConfirmedAt']);
      if (order['measurementStatus'] == 'completed' && confirmedAt != null) {
        candidates.add({
          'values': order['measurementSubmittedValues'],
          'unit': order['measurementSubmittedUnit'],
          'confirmedAt': confirmedAt,
        });
      }

      final history = order['measurementHistory'];
      if (history is! List) continue;
      for (final entry in history.whereType<Map>()) {
        final entryConfirmedAt = _date(entry['confirmedAt']);
        if (entryConfirmedAt == null) continue;
        candidates.add({
          'values':
              entry['submittedValues'] ?? entry['measurementSubmittedValues'],
          'unit': entry['submittedUnit'] ?? entry['measurementSubmittedUnit'],
          'confirmedAt': entryConfirmedAt,
        });
      }
    }

    candidates.sort((left, right) {
      final leftDate = left['confirmedAt'] as DateTime;
      final rightDate = right['confirmedAt'] as DateTime;
      return rightDate.compareTo(leftDate);
    });

    for (final candidate in candidates) {
      final measurements = _bodyMeasurementsFromPartnerSubmission(
        rawValues: candidate['values'],
        rawUnit: candidate['unit'],
        capturedAt: candidate['confirmedAt'] as DateTime,
      );
      if (measurements != null) return measurements;
    }
    return null;
  }

  static bool _orderMatchesPerson(
    Map<String, dynamic> order,
    String personId,
    String personName,
  ) {
    final storedPersonId = order['personId']?.toString().trim() ?? '';
    if (storedPersonId.isNotEmpty) return storedPersonId == personId;

    final storedName = (order['personName'] ?? order['clientName'] ?? '')
        .toString()
        .trim();
    return storedName.isNotEmpty &&
        storedName.toLowerCase() == personName.trim().toLowerCase();
  }

  static String _orderTitle(Map<String, dynamic> order) {
    final design = (order['designTemplateTitle'] ?? '').toString().trim();
    final garment = (order['dressType'] ?? '').toString().trim();
    if (design.isNotEmpty && garment.isNotEmpty) return '$design · $garment';
    if (design.isNotEmpty) return design;
    if (garment.isNotEmpty) return garment;
    return 'Previous order';
  }

  static Future<String?> _orderImage(Map<String, dynamic> order) async {
    final fabricAssets = order['customerFabricAssets'];
    if (fabricAssets is Map) {
      final preview = fabricAssets['selectedPreview'];
      if (preview is Map) {
        final storagePath = preview['storagePath']?.toString().trim() ?? '';
        if (storagePath.isNotEmpty) {
          try {
            return await CustomerFabricAssetService.downloadUrl(storagePath);
          } catch (_) {}
        }
        final previewUrl = preview['downloadUrl']?.toString().trim();
        if (previewUrl?.isNotEmpty == true) return previewUrl;
        final imageUrl = preview['imageUrl']?.toString().trim();
        if (imageUrl?.isNotEmpty == true) return imageUrl;
      }
      final previews = fabricAssets['previews'];
      if (previews is Iterable) {
        for (final candidate in previews.whereType<Map>()) {
          final storagePath = candidate['storagePath']?.toString().trim() ?? '';
          if (storagePath.isNotEmpty) {
            try {
              return await CustomerFabricAssetService.downloadUrl(storagePath);
            } catch (_) {}
          }
        }
      }
    }
    final designUrl = order['designImageUrl']?.toString().trim();
    if (designUrl?.isNotEmpty == true) return designUrl;
    return null;
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (entry.value != null && entry.value.toString().trim().isNotEmpty)
          entry.key.toString(): entry.value.toString(),
    };
  }

  static Map<String, String> _orderMeasurementValues(
    Map<String, dynamic> order,
  ) {
    final confirmed = _stringMap(order['measurementSubmittedValues']);
    return confirmed.isNotEmpty ? confirmed : _stringMap(order['measurements']);
  }

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _sourceTitle(String? source, String status) {
    if (status == 'customer_reference') return 'Customer reference';
    return switch (source) {
      'ai_camera' => 'AI Camera measurement',
      'manual_customer_reference' => 'Manual customer reference',
      'old_dress_reference' => 'Old dress reference',
      'previous_measurement_reference' => 'Saved measurement reference',
      _ => 'Measurement',
    };
  }

  static BodyMeasurements? _bodyMeasurementsFromPartnerSubmission({
    required Object? rawValues,
    required Object? rawUnit,
    required DateTime capturedAt,
  }) {
    if (rawValues is! Map) return null;
    final values = Map<String, dynamic>.from(rawValues);
    if (values.isEmpty) return null;

    String normalizeLabel(String label) => label
        .replaceFirst(RegExp(r'^\s*\d+\s*[·.\-:]?\s*'), '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final normalized = values.entries
        .map((entry) => MapEntry(normalizeLabel(entry.key), entry.value))
        .toList(growable: false);

    double? readEntry(MapEntry<String, dynamic>? entry) {
      if (entry == null || entry.value == null) return null;
      final value = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse(entry.value.toString().trim());
      if (value == null || value <= 0) return null;
      final unit = (rawUnit ?? 'in').toString().trim().toLowerCase();
      return unit == 'cm' ? value : value * 2.54;
    }

    MapEntry<String, dynamic>? findExact(Iterable<String> labels) {
      for (final label in labels) {
        for (final entry in normalized) {
          if (entry.key == label) return entry;
        }
      }
      return null;
    }

    MapEntry<String, dynamic>? findStartsWith(String label) {
      for (final entry in normalized) {
        if (entry.key.startsWith(label)) return entry;
      }
      return null;
    }

    final height = readEntry(
      findExact(const [
        'neck to heel total height',
        'neck to heel',
        'total height',
      ]),
    );
    final chest =
        readEntry(findExact(const ['bust full bust', 'full bust', 'bust', 'chest'])) ??
        readEntry(findStartsWith('over bust'));
    final waist = readEntry(findExact(const ['waist', 'waist circumference']));
    final hips = readEntry(
      findExact(const ['hips', 'hip', 'hips circumference', 'hip circumference']),
    );
    final shoulder =
        readEntry(findStartsWith('shoulder width')) ??
        readEntry(findStartsWith('shoulder seam'));
    final armLength = readEntry(findStartsWith('arm length'));
    final neck = readEntry(findExact(const ['neck', 'neck circumference']));
    final thigh = readEntry(findExact(const ['thigh', 'thigh circumference']));
    final inseam = readEntry(findStartsWith('inseam'));

    if ([height, chest, waist, hips, shoulder, armLength, neck, thigh, inseam]
        .every((value) => value == null)) {
      return null;
    }
    return BodyMeasurements(
      height: height,
      chest: chest,
      waist: waist,
      hips: hips,
      shoulder: shoulder,
      armLength: armLength,
      neck: neck,
      thigh: thigh,
      inseam: inseam,
      capturedAt: capturedAt,
    );
  }
}

class CustomerMeasurementRecord {
  const CustomerMeasurementRecord({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    required this.capturedAt,
    required this.values,
    required this.unit,
    this.note,
    this.referenceImageUrl,
    this.sourceOrderId,
    required this.isCustomerReference,
  });

  final String id;
  final String title;
  final String source;
  final String status;
  final DateTime capturedAt;
  final Map<String, String> values;
  final String unit;
  final String? note;
  final String? referenceImageUrl;
  final String? sourceOrderId;
  final bool isCustomerReference;
}

class CustomerDressReference {
  const CustomerDressReference({
    required this.orderId,
    required this.title,
    required this.date,
    required this.imageUrl,
    required this.values,
    required this.unit,
    required this.status,
    required this.orderNotes,
  });

  final String orderId;
  final String title;
  final DateTime? date;
  final String? imageUrl;
  final Map<String, String> values;
  final String unit;
  final String status;
  final String? orderNotes;
}
