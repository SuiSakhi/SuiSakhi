import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../models/garment_care_domain.dart';
import '../../services/garment_care_service.dart';

class GarmentCareRoutingScreen extends StatefulWidget {
  const GarmentCareRoutingScreen({super.key});

  @override
  State<GarmentCareRoutingScreen> createState() =>
      _GarmentCareRoutingScreenState();
}

class _GarmentCareRoutingScreenState extends State<GarmentCareRoutingScreen> {
  List<Map<String, dynamic>>? _partners;
  bool _loadingPartners = false;

  Future<List<Map<String, dynamic>>> _loadPartners() async {
    if (_partners != null) return _partners!;
    if (_loadingPartners) return const [];
    _loadingPartners = true;
    try {
      _partners = await GarmentCareService.partnerCandidates();
      return _partners!;
    } finally {
      _loadingPartners = false;
    }
  }

  Future<void> _assignPickup(String shipmentId) async {
    await _assign(shipmentId: shipmentId, isPickup: true);
  }

  Future<void> _assignJob(String jobId) async {
    await _assign(jobId: jobId, isPickup: false);
  }

  Future<void> _assign({
    String? shipmentId,
    String? jobId,
    required bool isPickup,
  }) async {
    try {
      final partners = await _loadPartners();
      if (!mounted) return;
      if (partners.isEmpty) {
        _showMessage('No available Garment Care Partners match this order.');
        return;
      }
      final partner = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isPickup ? 'Assign pickup' : 'Offer service to a Partner',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final candidate in partners)
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(candidate['name']?.toString() ?? 'Partner'),
                  subtitle: Text(
                    [
                      (candidate['capabilityCodes'] as List<dynamic>? ??
                              const [])
                          .map(
                            (code) => code.toString().replaceFirst(
                              'garmentCare.',
                              '',
                            ),
                          )
                          .join(' · '),
                      'Priority ${candidate['priority'] ?? 0}',
                    ].where((line) => line.isNotEmpty).join('\n'),
                  ),
                  onTap: () => Navigator.pop(context, candidate),
                ),
            ],
          ),
        ),
      );
      if (!mounted || partner == null) return;
      if (isPickup) {
        await GarmentCareService.assignPickup(
          shipmentId: shipmentId!,
          partnerAccountId: partner['accountId'].toString(),
          partnerProfileId: partner['profileId'].toString(),
        );
      } else {
        await GarmentCareService.assignJob(
          jobId: jobId!,
          partnerAccountId: partner['accountId'].toString(),
          partnerProfileId: partner['profileId'].toString(),
        );
      }
      if (mounted) {
        _showMessage(
          isPickup
              ? 'Pickup assigned to ${partner['name']}. The Partner will see it under Pickup & transfers.'
              : 'Service offer sent to ${partner['name']}. They can accept or decline in Garment Care.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _showMessage(error.message ?? 'Could not route this order.');
    } catch (_) {
      if (mounted) _showMessage('Could not route this order.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Garment Care Routing')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: GarmentCareService.adminOrders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _messageState(
              'Could not load Garment Care orders.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;
          if (orders.isEmpty) {
            return _messageState('No Garment Care orders yet.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'One order view for pickup and service routing.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pickup is assigned first. Once the Partner confirms receipt, eligible service steps can be offered. Open, available Partners are routed automatically by priority and capability.',
              ),
              const SizedBox(height: 12),
              for (final order in orders)
                _GarmentCareRoutingOrderCard(
                  orderId: order.id,
                  data: order.data(),
                  onAssignPickup: _assignPickup,
                  onAssignJob: _assignJob,
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _messageState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _GarmentCareRoutingOrderCard extends StatelessWidget {
  const _GarmentCareRoutingOrderCard({
    required this.orderId,
    required this.data,
    required this.onAssignPickup,
    required this.onAssignJob,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final ValueChanged<String> onAssignPickup;
  final ValueChanged<String> onAssignJob;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: GarmentCareService.adminOrderJobs(orderId),
    builder: (context, jobsSnapshot) {
      if (jobsSnapshot.hasError) {
        return _orderCard(context, const Text('Could not load service steps.'));
      }
      if (!jobsSnapshot.hasData) {
        return _orderCard(context, const LinearProgressIndicator());
      }
      return StreamBuilder(
        stream: GarmentCareService.adminOrderShipments(orderId),
        builder: (context, shipmentsSnapshot) {
          if (shipmentsSnapshot.hasError) {
            return _orderCard(
              context,
              const Text('Could not load pickup status.'),
            );
          }
          if (!shipmentsSnapshot.hasData) {
            return _orderCard(context, const LinearProgressIndicator());
          }
          final jobs = jobsSnapshot.data!.docs.toList();
          final shipments = shipmentsSnapshot.data!.docs;
          final pickups = shipments
              .where(
                (shipment) =>
                    shipment.data()['shipmentType'] == 'customer_pickup',
              )
              .toList();
          return _orderCard(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pickup in pickups) _pickupSection(context, pickup),
                if (pickups.isEmpty)
                  const Text('No pickup shipment is required for this order.'),
                const Divider(height: 24),
                Text(
                  'Service steps (${jobs.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final job in jobs) _jobSection(context, job, pickups),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _orderCard(BuildContext context, Widget contents) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['orderNumber']?.toString() ?? 'Garment Care order',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${data['itemCount'] ?? 0} garments · ${data['serviceGroupCode'] ?? ''} · ${_label(data['statusProjection']?.toString() ?? 'open')}',
          ),
          const SizedBox(height: 8),
          _customerDetails(context),
          const SizedBox(height: 8),
          contents,
        ],
      ),
    ),
  );

  Widget _customerDetails(BuildContext context) {
    final snapshot = data['pickupAddressSnapshot'] is Map
        ? Map<String, dynamic>.from(data['pickupAddressSnapshot'] as Map)
        : const <String, dynamic>{};
    final snapshotName = snapshot['name']?.toString().trim() ?? '';
    final snapshotPhone = snapshot['mobileNumber']?.toString().trim() ?? '';
    final snapshotAddress = _pickupAddressLabel(snapshot);
    if (snapshotName.isNotEmpty || snapshotPhone.isNotEmpty || snapshotAddress.isNotEmpty) {
      return _detailsCard(
        context,
        title: 'Customer / pickup',
        lines: [
          if (snapshotName.isNotEmpty) 'Customer: $snapshotName',
          if (snapshotPhone.isNotEmpty) 'Contact: $snapshotPhone',
          if (snapshotAddress.isNotEmpty) 'Address: $snapshotAddress',
        ],
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: GarmentCareService.adminCustomerDetails(orderId),
      builder: (context, result) {
        if (!result.hasData && !result.hasError) {
          return const LinearProgressIndicator();
        }
        final customer = result.data ?? const <String, dynamic>{};
        final name = customer['name']?.toString().trim() ?? '';
        final phone = customer['contactPhone']?.toString().trim() ?? '';
        final address = customer['formattedAddress']?.toString().trim() ?? '';
        if (name.isEmpty && phone.isEmpty && address.isEmpty) {
          return Text(
            'Customer pickup details could not be loaded${result.hasError ? ': ${result.error}' : '.'}',
          );
        }
        return _detailsCard(
          context,
          title: 'Customer / pickup',
          lines: [
            if (name.isNotEmpty) 'Customer: $name',
            if (phone.isNotEmpty) 'Contact: $phone',
            if (address.isNotEmpty) 'Address: $address',
          ],
        );
      },
    );
  }

  Widget _detailsCard(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: GarmentCareColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final line in lines) Text(line),
          ],
        ),
      );

  String _pickupAddressLabel(Map<String, dynamic> address) {
    final formatted = address['formattedAddress']?.toString().trim() ?? '';
    if (formatted.isNotEmpty) return formatted;
    return [
      address['addressLine1'],
      address['addressLine2'],
      address['landmark'],
      address['city'],
      address['state'],
      address['pincode'],
    ].map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(', ');
  }

  Widget _pickupSection(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> pickup,
  ) {
    final record = pickup.data();
    final status = record['status']?.toString() ?? 'unknown';
    final partner = record['assignedPartnerName']?.toString().trim() ?? '';
    final partnerPhone =
        record['assignedPartnerContactPhone']?.toString().trim() ?? '';
    final partnerAccountId = (record['toPartnerAccountId'] ??
            record['assignedPartnerAccountId'] ??
            '')
        .toString();
    final partnerProfileId = (record['toPartnerProfileId'] ??
            record['assignedPartnerProfileId'] ??
            '')
        .toString();
    final assigned = partnerAccountId.isNotEmpty && partnerProfileId.isNotEmpty;
    final orderPickup = data['pickupAddressSnapshot'] is Map
        ? Map<String, dynamic>.from(data['pickupAddressSnapshot'] as Map)
        : const <String, dynamic>{};
    final orderHasCustomerDetails =
        (orderPickup['name']?.toString().trim().isNotEmpty ?? false) ||
        (orderPickup['mobileNumber']?.toString().trim().isNotEmpty ?? false) ||
        _pickupAddressLabel(orderPickup).isNotEmpty;
    final pickupAddressSnapshot = record['pickupAddressSnapshot'] is Map
        ? Map<String, dynamic>.from(record['pickupAddressSnapshot'] as Map)
        : const <String, dynamic>{};
    final pickupName = pickupAddressSnapshot['name']?.toString().trim() ?? '';
    final pickupPhone =
        pickupAddressSnapshot['mobileNumber']?.toString().trim() ?? '';
    final pickupAddress = _pickupAddressLabel(pickupAddressSnapshot);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GarmentCareColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pickup · ${_label(status)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '${_dateLabel(record['preferredPickupAt'])} · ${record['pickupSlot'] ?? 'Pickup time not set'}',
          ),
          if (!orderHasCustomerDetails &&
              (pickupName.isNotEmpty || pickupPhone.isNotEmpty || pickupAddress.isNotEmpty))
            _detailsCard(
              context,
              title: 'Customer / pickup',
              lines: [
                if (pickupName.isNotEmpty) 'Customer: $pickupName',
                if (pickupPhone.isNotEmpty) 'Contact: $pickupPhone',
                if (pickupAddress.isNotEmpty) 'Address: $pickupAddress',
              ],
            ),
          if (assigned && partner.isNotEmpty && partnerPhone.isNotEmpty)
            _detailsCard(
              context,
              title: 'Assigned Partner',
              lines: ['Partner: $partner', 'Contact: $partnerPhone'],
            )
          else if (assigned)
            FutureBuilder<Map<String, dynamic>>(
              future: GarmentCareService.adminPickupPartnerDetails(
                shipmentId: pickup.id,
                accountId: partnerAccountId,
                profileId: partnerProfileId,
              ),
              builder: (context, snapshot) {
                final name = partner.isNotEmpty
                    ? partner
                    : snapshot.data?['name']?.toString() ?? '';
                final phone = partnerPhone.isNotEmpty
                    ? partnerPhone
                    : snapshot.data?['contactPhone']?.toString() ?? '';
                final alternatePhones =
                    (snapshot.data?['additionalContactPhones']
                                as List<dynamic>? ??
                            const [])
                        .map((value) => value.toString())
                        .where((value) => value.isNotEmpty)
                        .join(' · ');
                if (snapshot.hasError) {
                  return Text(
                    'Assigned Partner details unavailable: ${snapshot.error}',
                  );
                }
                if (name.isEmpty) {
                  return const Text('Loading Partner details…');
                }
                return _detailsCard(
                  context,
                  title: 'Assigned Partner',
                  lines: [
                    'Partner: $name',
                    if (phone.isNotEmpty) 'Contact: $phone',
                    if (alternatePhones.isNotEmpty)
                      'Alternate contact: $alternatePhones',
                  ],
                );
              },
            )
          else
            const Text('Partner assignment needs attention.'),
          if (status == 'queued') ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onAssignPickup(pickup.id),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Assign pickup'),
              ),
            ),
          ] else if (status == 'assigned')
            const Text(
              'Waiting for the Partner to collect and confirm the garments.',
            ),
          if (status == 'delivered')
            const Text('Garments received by Partner.'),
        ],
      ),
    );
  }

  Widget _jobSection(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> pickups,
  ) {
    final record = job.data();
    final status = record['status']?.toString() ?? 'queued';
    final pickupId = record['pickupShipmentId']?.toString() ?? '';
    final matchingPickups = pickups.where((item) => item.id == pickupId);
    final pickup = matchingPickups.isEmpty ? null : matchingPickups.first;
    final pickupDelivered = pickup?.data()['status'] == 'delivered';
    final assignedName = record['assignedPartnerName']?.toString().trim() ?? '';
    final canAssign =
        (status == 'queued' || status == 'rejected') &&
        record['dispatchEligible'] == true &&
        (pickupId.isEmpty || pickupDelivered);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.checkroom_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  GarmentCareServiceCatalog.labelFor(
                    record['serviceId']?.toString() ?? '',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${record['displayName'] ?? record['itemTypeCode'] ?? 'Garment'} · ${_label(status)}',
                ),
                if (assignedName.isNotEmpty) Text('Partner: $assignedName'),
                if (canAssign)
                  TextButton.icon(
                    onPressed: () => onAssignJob(job.id),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Offer service to Partner'),
                  )
                else if (status == 'queued' &&
                    record['dispatchEligible'] == true &&
                    pickupId.isNotEmpty &&
                    !pickupDelivered)
                  const Text(
                    'Available after pickup is confirmed by the Partner.',
                  )
                else if (status == 'offered')
                  const Text('Waiting for the Partner to accept or decline.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(dynamic value) {
    final date = value is Timestamp ? value.toDate() : null;
    if (date == null) return 'Pickup date not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  static String _label(String value) => value
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
