import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/garment_measurement_catalog.dart';
import '../../services/order_lifecycle_service.dart';
import '../../services/partner_workspace_service.dart';
import '../../widgets/orders/delivery_pin_dialog.dart';
import '../../widgets/orders/optional_pickup_photo_dialog.dart';

class MeasurementPartnerAssignmentsScreen extends StatefulWidget {
  const MeasurementPartnerAssignmentsScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    this.partnerName,
  });

  final String accountId;
  final String profileId;
  final String? partnerName;

  @override
  State<MeasurementPartnerAssignmentsScreen> createState() =>
      _MeasurementPartnerAssignmentsScreenState();
}

class _MeasurementPartnerAssignmentsScreenState
    extends State<MeasurementPartnerAssignmentsScreen> {
  late Future<List<Map<String, dynamic>>> _assignmentsFuture;
  late Future<String> _partnerNameFuture;
  String _pinFilter = '';
  String _orderCategory = 'active';

  @override
  void initState() {
    super.initState();
    final suppliedPartnerName = widget.partnerName?.trim() ?? '';
    _partnerNameFuture = suppliedPartnerName.isNotEmpty
        ? Future.value(suppliedPartnerName)
        : PartnerWorkspaceService.requirePartnerProfile(
            accountId: widget.accountId,
            profileId: widget.profileId,
          ).then((profile) => profile.businessDisplayName);
    _reload();
  }

  void _reload() {
    _assignmentsFuture = OrderLifecycleService.getMeasurementPartnerAssignments(
      accountId: widget.accountId,
      profileId: widget.profileId,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _assignmentsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: FutureBuilder<String>(
          future: _partnerNameFuture,
          builder: (context, snapshot) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Partner Workspace',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                snapshot.data ?? 'Measurement Partner',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Partner account',
            onPressed: () => context.push(
              '/partner/account?accountId=${Uri.encodeQueryComponent(widget.accountId)}&profileId=${Uri.encodeQueryComponent(widget.profileId)}&category=measurementPartner',
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _assignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load measurement assignments. Pull down to retry.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Icon(
                    Icons.straighten_rounded,
                    size: 54,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No measurement assignments yet',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Orders assigned by a Tailor will appear here. The Tailor’s instructions will be shown with each request.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            );
          }
          final pin = _pinFilter.replaceAll(RegExp(r'\s+'), '').toUpperCase();
          final visibleOrders = orders.where((order) {
            final orderPin = (order['deliveryPincode'] ?? '')
                .toString()
                .toUpperCase();
            return pin.isEmpty || orderPin.contains(pin);
          }).toList();
          final completedMeasurements = visibleOrders
              .where(
                (order) =>
                    order['measurementPartnerCompletedByProfileId'] ==
                        widget.profileId &&
                    order['measurementSubmissionStatus'] == 'completed',
              )
              .toList();
          final activeOrders = visibleOrders.where((order) {
            final measurementTask = order['measurementTask'] == true;
            final inbound =
                order['inboundPickupStatus'] == 'assigned' &&
                order['inboundPickupPartnerType'] == 'measurementPartner' &&
                order['inboundPickupPartnerProfileId'] == widget.profileId;
            final outbound =
                [
                  'assigned',
                  'in_transit',
                ].contains(order['outboundHandoverStatus']) &&
                order['outboundHandoverPartnerType'] == 'measurementPartner' &&
                order['outboundHandoverPartnerProfileId'] == widget.profileId;
            return measurementTask || inbound || outbound;
          }).toList();
          final categoryOrders = _orderCategory == 'active'
              ? activeOrders
              : completedMeasurements;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() => _pinFilter = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    hintText: 'Search orders by PIN',
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        selected: _orderCategory == 'active',
                        onSelected: (_) =>
                            setState(() => _orderCategory = 'active'),
                        label: const SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Active Orders\nCurrent Orders',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        selected: _orderCategory == 'completed',
                        onSelected: (_) =>
                            setState(() => _orderCategory = 'completed'),
                        label: const SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Completed / History\nOrders',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (visibleOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Text(
                      'No measurement orders found for this PIN.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                else if (categoryOrders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 36),
                    child: Text(
                      _orderCategory == 'active'
                          ? 'No active or current measurement orders.'
                          : 'No completed measurement history yet.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
                    child: Text(
                      _orderCategory == 'active'
                          ? 'Active Orders / Current Orders'
                          : 'Completed / History Orders',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  ...categoryOrders.map(
                    (order) => _MeasurementAssignmentCard(
                      orderId: (order['orderId'] ?? '').toString(),
                      data: order,
                      accountId: widget.accountId,
                      profileId: widget.profileId,
                      onSaved: _refresh,
                      showActions: _orderCategory == 'active',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MeasurementAssignmentCard extends StatelessWidget {
  const _MeasurementAssignmentCard({
    required this.orderId,
    required this.data,
    required this.accountId,
    required this.profileId,
    required this.onSaved,
    required this.showActions,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final String accountId;
  final String profileId;
  final Future<void> Function() onSaved;
  final bool showActions;

  String _text(String key, [String fallback = '']) =>
      (data[key] ?? fallback).toString().trim();

  DateTime? get _appointmentAt =>
      DateTime.tryParse(_text('measurementAppointmentAt'))?.toLocal();

  bool get _measurementCompleted =>
      _text('measurementSubmissionStatus') == 'completed' &&
      _text('measurementPartnerCompletedByProfileId') == profileId;

  bool get _hasMeasurementTask {
    if (_text('measurementTask') == 'true') return true;
    return _text('measurementPartnerProfileId') == profileId &&
        _text('measurementStatus') != 'completed' &&
        _text('measurementSubmissionStatus') != 'completed';
  }

  String get _methodLabel => switch (_text('measurementMethod')) {
    'tailor_home_visit' => 'Tailor home visit (self-assigned)',
    'measurement_partner_home_visit' => 'Home visit requested by Tailor',
    'video_appointment' => 'Video measurement requested by Tailor',
    _ => 'Measurement request',
  };

  List<String> get _measurementCriteria {
    // Always use the full current chart, even if a device has a cached response
    // from an older backend that returned fewer measurements.
    return GarmentMeasurementCatalog.keys;
  }

  Future<void> _schedule(BuildContext context) async {
    final isVideo = _text('measurementMethod') == 'video_appointment';
    final draft = await showDialog<_AppointmentDraft>(
      context: context,
      builder: (_) => _MeasurementAppointmentDialog(
        initialDate: _appointmentAt,
        isVideo: isVideo,
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      await OrderLifecycleService.setMeasurementPartnerAppointment(
        orderId: orderId,
        accountId: accountId,
        profileId: profileId,
        appointmentAt: draft.at,
        isVideo: isVideo,
      );
      await onSaved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVideo
                  ? 'Google Meet appointment scheduled and shared with the Customer and Tailor.'
                  : 'Appointment scheduled and shared with the Customer and Tailor.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Could not schedule this appointment.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not schedule this appointment. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _submitMeasurements(BuildContext context) async {
    final draft = await showDialog<_MeasurementSubmissionDraft>(
      context: context,
      builder: (_) => _MeasurementSubmissionDialog(
        criteria: _measurementCriteria,
        dressType: _text('dressType', 'Garment'),
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      await OrderLifecycleService.submitMeasurementPartnerMeasurements(
        orderId: orderId,
        accountId: accountId,
        profileId: profileId,
        measurements: draft.measurements,
        measurementUnit: draft.measurementUnit,
        note: draft.note,
      );
      await onSaved();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Measurements sent to the Tailor for final review.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not submit measurements.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not submit measurements. Please retry.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _text('measurementMethod') == 'video_appointment';
    final appointment = _appointmentAt;
    final title = _text('dressType', 'Tailoring order');
    final customerName = _text('customerName', 'Customer');
    final design = _text('designTemplateTitle');
    final material = _text('fabricChoice', _text('fabricDescription'));
    final designImageUrl = _text('designImageUrl');
    final statusLabel = _hasMeasurementTask
        ? appointment == null
              ? 'Needs scheduling'
              : 'Scheduled'
        : _measurementCompleted
        ? 'Measurement completed'
        : _text('inboundPickupStatus') == 'assigned'
        ? 'Pickup assigned'
        : 'Return delivery assigned';
    final submittedValues = data['measurementSubmittedValues'] is Map
        ? Map<String, dynamic>.from(data['measurementSubmittedValues'] as Map)
        : <String, dynamic>{};
    final completedAt = DateTime.tryParse(
      _text('measurementPartnerCompletedAt'),
    )?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
                Text(
                  statusLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _hasMeasurementTask && appointment == null
                        ? AppColors.warning
                        : AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Order · ${_text('orderTrackingId', orderId)}',
              style: AppTextStyles.bodySmall,
            ),
            if (_text('deliveryPincode').isNotEmpty)
              Text(
                'PIN · ${_text('deliveryPincode')}',
                style: AppTextStyles.bodySmall,
              ),
            Text('Customer · $customerName', style: AppTextStyles.bodySmall),
            if (_text('customerPhone').isNotEmpty)
              Text(
                'Contact · ${_text('customerPhone')}',
                style: AppTextStyles.bodySmall,
              ),
            if (_text('deliveryAddress').isNotEmpty)
              Text(
                'Visit address · ${_text('deliveryAddress')}',
                style: AppTextStyles.bodySmall,
              ),
            if (_hasMeasurementTask)
              Text(_methodLabel, style: AppTextStyles.bodySmall),
            if (design.isNotEmpty)
              Text('Design · $design', style: AppTextStyles.bodySmall),
            if (material.isNotEmpty)
              Text('Material · $material', style: AppTextStyles.bodySmall),
            if (designImageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  designImageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            if (_hasMeasurementTask &&
                _text('measurementNotes').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Tailor’s guidance', style: AppTextStyles.labelMedium),
              Text(_text('measurementNotes'), style: AppTextStyles.bodySmall),
            ],
            if (_hasMeasurementTask && appointment != null) ...[
              const SizedBox(height: 8),
              Text(
                'Appointment · ${MaterialLocalizations.of(context).formatMediumDate(appointment)} · ${TimeOfDay.fromDateTime(appointment).format(context)}',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (_hasMeasurementTask &&
                isVideo &&
                _text('measurementAppointmentLink').isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(_text('measurementAppointmentLink')),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Join video measurement'),
              ),
            ],
            if (_measurementCompleted) ...[
              const SizedBox(height: 8),
              Text(
                completedAt == null
                    ? 'Measurements completed and sent to the Tailor.'
                    : 'Measurements completed · ${MaterialLocalizations.of(context).formatMediumDate(completedAt)} · ${TimeOfDay.fromDateTime(completedAt).format(context)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
              if (submittedValues.isNotEmpty) ...[
                const SizedBox(height: 6),
                ..._measurementCriteria.where(submittedValues.containsKey).map((
                  criterion,
                ) {
                  final value = submittedValues[criterion];
                  final number = value is num
                      ? value.toString()
                      : value?.toString() ?? '';
                  final cleanNumber = number.endsWith('.0')
                      ? number.substring(0, number.length - 2)
                      : number;
                  return Text(
                    '$criterion · $cleanNumber ${_text('measurementSubmittedUnit', 'in')}',
                    style: AppTextStyles.bodySmall,
                  );
                }),
              ],
              if (_text('measurementPartnerCompletionNote').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Note to Tailor', style: AppTextStyles.labelMedium),
                Text(
                  _text('measurementPartnerCompletionNote'),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ],
            if (showActions && _hasMeasurementTask) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _schedule(context),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    appointment == null
                        ? 'Assign appointment slot'
                        : 'Update appointment slot',
                  ),
                ),
              ),
              if (appointment != null &&
                  _text('measurementSubmissionStatus') != 'completed' &&
                  _text('measurementStatus') != 'completed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _submitMeasurements(context),
                    icon: const Icon(Icons.straighten_rounded),
                    label: const Text(
                      'Complete measurement and send to Tailor',
                    ),
                  ),
                ),
              ],
            ],
            if (showActions &&
                _text('inboundPickupStatus') == 'assigned' &&
                _text('inboundPickupPartnerType') == 'measurementPartner' &&
                _text('inboundPickupPartnerProfileId') == profileId) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _advanceHandover(context, 'collectInbound'),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirm pickup completed'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _advanceHandover(context, 'declineInbound'),
                  child: const Text('Can’t take this pickup'),
                ),
              ),
            ],
            if (_text('inboundPickupStatus') == 'collectedFromCustomer' &&
                _text('inboundPickupPartnerType') == 'measurementPartner' &&
                _text('inboundPickupPartnerProfileId') == profileId &&
                _text('inboundPickupCollectedAt').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Pickup completed · ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(_text('inboundPickupCollectedAt')).toLocal())} · ${TimeOfDay.fromDateTime(DateTime.parse(_text('inboundPickupCollectedAt')).toLocal()).format(context)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
            if (showActions &&
                _text('outboundHandoverStatus') == 'assigned' &&
                _text('outboundHandoverPartnerType') == 'measurementPartner' &&
                _text('outboundHandoverPartnerProfileId') == profileId &&
                _text('orderStatus') == 'readyForPickup' &&
                _text('paymentStatus') == 'fullyPaid') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _advanceHandover(context, 'accept'),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Start return delivery'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _advanceHandover(context, 'declineOutbound'),
                  child: const Text('Can’t take this delivery'),
                ),
              ),
            ],
            if (showActions &&
                _text('outboundHandoverStatus') == 'in_transit' &&
                _text('outboundHandoverPartnerType') == 'measurementPartner' &&
                _text('outboundHandoverPartnerProfileId') == profileId &&
                _text('orderStatus') == 'outForDelivery') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _advanceHandover(context, 'delivered'),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Confirm Customer handover'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _advanceHandover(BuildContext context, String action) async {
    String? deliveryPin;
    String? pickupPhotoPath;
    if (action == 'collectInbound') {
      final photoResult = await showOptionalPickupPhotoDialog(
        context: context,
        orderId: orderId,
      );
      if (photoResult.cancelled) return;
      pickupPhotoPath = photoResult.storagePath;
    }
    if (action == 'delivered') {
      if (!context.mounted) return;
      deliveryPin = await showDeliveryPinDialog(context);
      if (deliveryPin == null) return;
      if (!RegExp(r'^\d{4}$').hasMatch(deliveryPin)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter the 4-digit customer delivery PIN.'),
            ),
          );
        }
        return;
      }
    }
    try {
      await OrderLifecycleService.advanceDeliveryOrder(
        orderId: orderId,
        accountId: accountId,
        profileId: profileId,
        action: action,
        deliveryPin: deliveryPin,
        pickupPhotoPath: pickupPhotoPath,
      );
      await onSaved();
      if (context.mounted) {
        final message = switch (action) {
          'collectInbound' => 'Customer pickup recorded.',
          'declineInbound' =>
            'Pickup task passed to the next eligible Partner.',
          'accept' => 'Return delivery started.',
          'declineOutbound' =>
            'Delivery task passed to the next eligible Partner.',
          _ => 'Order delivered to the Customer.',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not update handover.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update handover. Please retry.'),
          ),
        );
      }
    }
  }
}

class _AppointmentDraft {
  const _AppointmentDraft({required this.at});

  final DateTime at;
}

class _MeasurementSubmissionDraft {
  const _MeasurementSubmissionDraft({
    required this.measurements,
    required this.measurementUnit,
    required this.note,
  });

  final Map<String, double> measurements;
  final String measurementUnit;
  final String note;
}

class _MeasurementSubmissionDialog extends StatefulWidget {
  const _MeasurementSubmissionDialog({
    required this.criteria,
    required this.dressType,
  });

  final List<String> criteria;
  final String dressType;

  @override
  State<_MeasurementSubmissionDialog> createState() =>
      _MeasurementSubmissionDialogState();
}

class _MeasurementSubmissionDialogState
    extends State<_MeasurementSubmissionDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _noteController;
  String _measurementUnit = 'in';

  Set<int> get _recommended =>
      GarmentMeasurementCatalog.recommendedNumbers(widget.dressType);

  bool get _canSubmit => widget.criteria.every((criterion) {
    final raw = _controllers[criterion]!.text.trim();
    if (raw.isEmpty) return true;
    final value = double.tryParse(raw);
    final maxValue = _measurementUnit == 'in' ? 200 : 500;
    return value != null && value > 0 && value <= maxValue;
  });

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final criterion in widget.criteria)
        criterion: TextEditingController()..addListener(_refresh),
    };
    _noteController = TextEditingController();
    _noteController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    _noteController.removeListener(_refresh);
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      _MeasurementSubmissionDraft(
        measurements: {
          for (final criterion in widget.criteria)
            if (_controllers[criterion]!.text.trim().isNotEmpty)
              criterion: double.parse(_controllers[criterion]!.text.trim()),
        },
        measurementUnit: _measurementUnit,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderedCriteria = widget.criteria.toList()
      ..sort((a, b) {
        final aNumber = GarmentMeasurementCatalog.forKey(a)?.number ?? 999;
        final bNumber = GarmentMeasurementCatalog.forKey(b)?.number ?? 999;
        return aNumber.compareTo(bNumber);
      });
    return AlertDialog(
      title: const Text('Complete measurement'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Universal Women’s Measurement Chart · ${widget.dressType}\nEnter only measurements collected for this garment. Every field is optional; you can submit with all measurements blank and add a note if useful. Centimeters are preferred. Keep the tape horizontal for circumferences and vertical for lengths; the Tailor confirms the final fit.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('Inches')),
                  ButtonSegment(value: 'cm', label: Text('Centimeters')),
                ],
                selected: {_measurementUnit},
                onSelectionChanged: (selection) {
                  setState(() => _measurementUnit = selection.first);
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Measurements 1–22 · all optional. Suggested fields for ${widget.dressType} are marked.',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final criterion in orderedCriteria)
                _measurementField(criterion),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Note for the Tailor (optional)',
                  hintText:
                      'Fit observations or anything the Tailor should know',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Send to Tailor'),
        ),
      ],
    );
  }

  Widget _measurementField(String criterion) {
    final spec = GarmentMeasurementCatalog.forKey(criterion);
    final color = spec?.color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: _controllers[criterion],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText:
              '${criterion.replaceFirst(RegExp(r'^\d+\s*·\s*'), '')} · optional',
          helperText: spec != null && _recommended.contains(spec.number)
              ? 'Suggested for ${widget.dressType} · optional'
              : 'Optional',
          suffixText: _measurementUnit,
          prefixIcon: spec == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: color,
                    child: Text(
                      '${spec.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color.withValues(alpha: .35)),
          ),
        ),
      ),
    );
  }
}

class _MeasurementAppointmentDialog extends StatefulWidget {
  const _MeasurementAppointmentDialog({
    required this.initialDate,
    required this.isVideo,
  });

  final DateTime? initialDate;
  final bool isVideo;

  @override
  State<_MeasurementAppointmentDialog> createState() =>
      _MeasurementAppointmentDialogState();
}

class _MeasurementAppointmentDialogState
    extends State<_MeasurementAppointmentDialog> {
  DateTime? _appointmentAt;

  bool get _canSave =>
      _appointmentAt != null && _appointmentAt!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _appointmentAt = widget.initialDate?.toLocal();
  }

  Future<void> _chooseAppointment() async {
    final now = DateTime.now();
    final current = _appointmentAt ?? now.add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(now) ? now : current,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _appointmentAt == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(_appointmentAt!),
    );
    if (!mounted || time == null) return;
    setState(() {
      _appointmentAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final at = _appointmentAt;
    final dateText = at == null
        ? 'Choose date and time'
        : '${MaterialLocalizations.of(context).formatMediumDate(at)} · ${TimeOfDay.fromDateTime(at).format(context)}';
    return AlertDialog(
      title: Text(
        widget.isVideo ? 'Schedule video measurement' : 'Schedule home visit',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isVideo
                ? 'Choose a time. SuiSakhi will create a Google Meet link and share it with the Customer and Tailor.'
                : 'Choose a time for the Customer. The Tailor will confirm the final measurements.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseAppointment,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(
                  context,
                ).pop(_AppointmentDraft(at: _appointmentAt!))
              : null,
          child: const Text('Share appointment'),
        ),
      ],
    );
  }
}
