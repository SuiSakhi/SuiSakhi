import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../core/garment_care_guidance.dart';
import '../../models/garment_care_completion_template.dart';
import '../../models/garment_care_domain.dart';
import '../../services/garment_care_service.dart';

class GarmentCareJobsScreen extends StatefulWidget {
  const GarmentCareJobsScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    required this.partnerName,
  });

  final String accountId;
  final String profileId;
  final String partnerName;

  @override
  State<GarmentCareJobsScreen> createState() => _GarmentCareJobsScreenState();
}

class _GarmentCareJobsScreenState extends State<GarmentCareJobsScreen> {
  String get accountId => widget.accountId;
  String get profileId => widget.profileId;
  String get partnerName => widget.partnerName;

  final Set<String> _busyJobIds = <String>{};
  final GlobalKey _workContentKey = GlobalKey();
  String _selectedWorkTab = 'today';
  String _orderSearchQuery = '';
  int _selectedBottomDestination = 0;

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SUISAKHI PARTNER',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: GarmentCareColors.primary,
                letterSpacing: .7,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'My Garment Care Shop',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            Text(
              partnerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: GarmentCareColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Care completion templates',
            onPressed: () => context.push(
              '/partner/garment-care/completion-templates?accountId=${Uri.encodeQueryComponent(accountId)}&profileId=${Uri.encodeQueryComponent(profileId)}',
            ),
            icon: const Icon(Icons.note_alt_outlined),
          ),
          IconButton(
            tooltip: 'Partner account',
            onPressed: () => context.push(
              '/partner/account?accountId=${Uri.encodeQueryComponent(accountId)}&profileId=${Uri.encodeQueryComponent(profileId)}&category=garmentCare',
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomDestination,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: GarmentCareColors.primary,
        unselectedItemColor: GarmentCareColors.textSecondary,
        showUnselectedLabels: true,
        onTap: _onBottomDestination,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping_rounded),
            label: 'Pickup',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: GarmentCareService.partnerJobs(
          accountId: accountId,
          profileId: profileId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _loadError(context, snapshot.error);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final jobs = [...snapshot.data!.docs]
            ..sort((first, second) {
              final priority = <String, int>{
                'offered': 0,
                'accepted': 1,
                'inspectionPending': 2,
                'awaitingConsent': 3,
                'readyToStart': 4,
                'inProgress': 5,
                'qualityCheck': 6,
                'completed': 7,
              };
              return (priority[first.data()['status']?.toString()] ?? 8)
                  .compareTo(
                    priority[second.data()['status']?.toString()] ?? 8,
                  );
            });
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: GarmentCareService.partnerOutgoingShipments(
              accountId: accountId,
              profileId: profileId,
            ),
            builder: (context, outgoingSnapshot) {
              // A service job can be care-complete while its order is still
              // awaiting payment or final delivery. Only a delivered return
              // shipment closes the order in the Partner work tabs.
              final outgoingShipments =
                  outgoingSnapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final deliveredJobIds = jobs
                  .where(
                    (job) => _isPartnerServiceOrderDelivered(
                      job.data(),
                      outgoingShipments,
                    ),
                  )
                  .map((job) => job.id)
                  .toSet();
              final visibleJobs = jobs
                  .where((job) {
                    final status = job.data()['status']?.toString() ?? '';
                    final orderDelivered = deliveredJobIds.contains(job.id);
                    return switch (_selectedWorkTab) {
                      // Keep pickup rejections in All Services as a traceable
                      // terminal outcome; they are still hidden from active work.
                      'all' => status != 'rejected',
                      'new' => status == 'offered',
                      'check' =>
                        status == 'accepted' || status == 'inspectionPending',
                      'waiting' =>
                        status == 'awaitingConsent' ||
                            status == 'awaitingCustomerEdit',
                      'ready' => status == 'readyToStart',
                      'care' => status == 'inProgress',
                      'quality' => status == 'qualityCheck',
                      'completed' => status == 'completed' && orderDelivered,
                      _ =>
                        ![
                              'offered',
                              'cancelled',
                              'rejected',
                            ].contains(status) &&
                            !(status == 'completed' && orderDelivered),
                    };
                  })
                  .toList(growable: false);
              final orderGroups = _groupJobsByOrder(visibleJobs);
              final matchingOrderGroups = orderGroups.entries
                  .where(
                    (entry) => _orderGroupMatchesSearch(entry.key, entry.value),
                  )
                  .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _workspaceOverview(context, jobs),
                  const SizedBox(height: 8),
                  Column(
                    key: _workContentKey,
                    children: [
                      _workTabs(jobs, deliveredJobIds),
                      const SizedBox(height: 12),
                      _orderSearchField(),
                      const SizedBox(height: 10),
                      if (matchingOrderGroups.isEmpty &&
                          _orderSearchQuery.trim().isNotEmpty)
                        _noMatchingOrderCard()
                      else if (matchingOrderGroups.isEmpty)
                        _emptyWorkCard(context, _selectedWorkTab)
                      else
                        for (final orderGroup in matchingOrderGroups)
                          _parentOrderCard(
                            context,
                            orderGroup.key,
                            orderGroup.value,
                            jobs,
                          ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );

  Widget _workTabs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
    Set<String> deliveredJobIds,
  ) {
    final orderCount = jobs
        .where((job) => job.data()['status'] != 'rejected')
        .map(_parentOrderKey)
        .toSet()
        .length;
    final newCount = jobs
        .where((job) => job.data()['status'] == 'offered')
        .length;
    final checkCount = jobs
        .where(
          (job) =>
              ['accepted', 'inspectionPending'].contains(job.data()['status']),
        )
        .length;
    final waitingCount = jobs
        .where(
          (job) => [
            'awaitingConsent',
            'awaitingCustomerEdit',
          ].contains(job.data()['status']),
        )
        .length;
    final readyCount = jobs
        .where((job) => job.data()['status'] == 'readyToStart')
        .length;
    final careCount = jobs
        .where((job) => job.data()['status'] == 'inProgress')
        .length;
    final qualityCount = jobs
        .where((job) => job.data()['status'] == 'qualityCheck')
        .length;
    final completedCount = jobs
        .where((job) => deliveredJobIds.contains(job.id))
        .map(_parentOrderKey)
        .toSet()
        .length;
    final tabs = <(String, String, int?)>[
      ('all', 'All Orders', orderCount),
      ('today', "Today's Work", null),
      ('new', 'Care Steps to Accept', newCount),
      ('check', 'Check Clothes', checkCount),
      ('waiting', 'Waiting for Customer', waitingCount),
      ('ready', 'Ready to Start', readyCount),
      ('care', 'Care in Progress', careCount),
      ('quality', 'Quality Check', qualityCount),
      ('completed', 'Completed Orders', completedCount),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            ChoiceChip(
              label: Text(
                tab.$3 == null ? tab.$2 : '${tab.$2} (${tab.$3})',
                style: TextStyle(
                  color: _selectedWorkTab == tab.$1
                      ? Colors.white
                      : GarmentCareColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: _selectedWorkTab == tab.$1,
              onSelected: (_) => setState(() {
                _selectedWorkTab = tab.$1;
                _selectedBottomDestination = tab.$1 == 'today' ? 0 : 1;
              }),
              selectedColor: GarmentCareColors.primary,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _selectedWorkTab == tab.$1
                    ? GarmentCareColors.primary
                    : GarmentCareColors.divider,
              ),
              shape: const StadiumBorder(),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _parentOrderKey(QueryDocumentSnapshot<Map<String, dynamic>> job) {
    final data = job.data();
    return data['orderId']?.toString().trim().isNotEmpty == true
        ? data['orderId'].toString().trim()
        : job.id;
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupJobsByOrder(List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs) {
    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final job in jobs) {
      groups.putIfAbsent(_parentOrderKey(job), () => []).add(job);
    }
    return groups;
  }

  String _garmentSubOrderKey(QueryDocumentSnapshot<Map<String, dynamic>> job) {
    final data = job.data();
    for (final field in ['subOrderNumber', 'garmentId', 'deliveryGroupId']) {
      final value = data[field]?.toString().trim() ?? '';
      if (value.isNotEmpty) return '$field:$value';
    }
    return job.id;
  }

  bool _sameGarmentSubOrder(
    QueryDocumentSnapshot<Map<String, dynamic>> first,
    QueryDocumentSnapshot<Map<String, dynamic>> second,
  ) {
    final firstData = first.data();
    final secondData = second.data();
    for (final field in ['subOrderNumber', 'garmentId']) {
      final firstValue = firstData[field]?.toString().trim() ?? '';
      final secondValue = secondData[field]?.toString().trim() ?? '';
      if (firstValue.isNotEmpty && secondValue.isNotEmpty) {
        return firstValue == secondValue;
      }
    }
    final firstHasGarmentIdentity =
        (firstData['subOrderNumber']?.toString().trim().isNotEmpty ?? false) ||
        (firstData['garmentId']?.toString().trim().isNotEmpty ?? false);
    final secondHasGarmentIdentity =
        (secondData['subOrderNumber']?.toString().trim().isNotEmpty ?? false) ||
        (secondData['garmentId']?.toString().trim().isNotEmpty ?? false);
    if (firstHasGarmentIdentity || secondHasGarmentIdentity) return false;
    final firstDeliveryGroup =
        firstData['deliveryGroupId']?.toString().trim() ?? '';
    final secondDeliveryGroup =
        secondData['deliveryGroupId']?.toString().trim() ?? '';
    return firstDeliveryGroup.isNotEmpty &&
        firstDeliveryGroup == secondDeliveryGroup;
  }

  Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _groupJobsByGarmentSubOrder(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
  ) {
    final groups =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final job in jobs) {
      String? matchingKey;
      for (final entry in groups.entries) {
        if (_sameGarmentSubOrder(entry.value.first, job)) {
          matchingKey = entry.key;
          break;
        }
      }
      if (matchingKey != null) {
        groups[matchingKey]!.add(job);
      } else {
        var key = _garmentSubOrderKey(job);
        if (groups.containsKey(key)) key = '$key:${job.id}';
        groups[key] = [job];
      }
    }
    return groups;
  }

  bool _orderGroupMatchesSearch(
    String orderId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> group,
  ) {
    final query = _orderSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (orderId.toLowerCase().contains(query)) return true;
    return group.any((job) {
      final data = job.data();
      return [
        data['orderNumber'],
        data['subOrderNumber'],
        data['garmentId'],
        data['displayName'],
        data['serviceName'],
        data['serviceId'],
      ].any((value) => value?.toString().toLowerCase().contains(query) == true);
    });
  }

  Widget _orderSearchField() => TextField(
    onChanged: (value) => setState(() => _orderSearchQuery = value),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: 'Search order, sub-order or garment ID',
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _orderSearchQuery.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(() => _orderSearchQuery = ''),
              icon: const Icon(Icons.close_rounded),
            ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: GarmentCareColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: GarmentCareColors.divider),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );

  Widget _noMatchingOrderCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: GarmentCareColors.divider),
    ),
    child: const Text(
      'No matching orders. Search with an order number, sub-order number or garment ID.',
      textAlign: TextAlign.center,
    ),
  );

  Widget _parentOrderCard(
    BuildContext context,
    String orderId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> group,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allJobs,
  ) {
    final orderNumber = group
        .map((job) => job.data()['orderNumber']?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final sortedJobs = [...group]
      ..sort((first, second) {
        final firstSubOrder = first.data()['subOrderNumber']?.toString() ?? '';
        final secondSubOrder =
            second.data()['subOrderNumber']?.toString() ?? '';
        final subOrderOrder = firstSubOrder.compareTo(secondSubOrder);
        if (subOrderOrder != 0) return subOrderOrder;
        return _serviceStepNumber(
          first,
          allJobs,
        ).compareTo(_serviceStepNumber(second, allJobs));
      });
    final subOrders = _groupJobsByGarmentSubOrder(sortedJobs);
    final pickupRejectedGarmentIds = sortedJobs
        .where(
          (job) =>
              job.data()['pickupRejectionCode']?.toString().trim().isNotEmpty ==
              true,
        )
        .map((job) => job.data()['garmentId']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final acceptedSubOrderNumbers = sortedJobs
        .where(
          (job) =>
              job.data()['pickupRejectionCode']?.toString().trim().isNotEmpty !=
                  true &&
              job.data()['subOrderNumber']?.toString().trim().isNotEmpty ==
                  true,
        )
        .map((job) => job.data()['subOrderNumber']!.toString().trim())
        .toSet();
    final careJobs = sortedJobs
        .where(
          (job) =>
              job.data()['pickupRejectionCode']?.toString().trim().isNotEmpty !=
              true,
        )
        .toList(growable: false);
    final statusSummary = _orderGroupStatusSummary(careJobs);
    final summary = [
      statusSummary,
      if (pickupRejectedGarmentIds.isNotEmpty)
        '${pickupRejectedGarmentIds.length} not collected · remains with Customer',
    ].where((part) => part.isNotEmpty).join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GarmentCareColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey<String>(
            'partner-order-$orderId-$_selectedWorkTab',
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          title: Text(
            orderNumber.isEmpty ? 'Order details' : 'Order $orderNumber',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${acceptedSubOrderNumbers.length} collected garment sub-orders · ${careJobs.length} service steps${summary.isEmpty ? '' : '\n$summary'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GarmentCareColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          children: [
            for (final entry in subOrders.entries)
              _garmentSubOrderCard(context, entry.value, allJobs),
          ],
        ),
      ),
    );
  }

  Widget _garmentSubOrderCard(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleJobs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allJobs,
  ) {
    final first = visibleJobs.first;
    final data = first.data();
    final orderId = data['orderId']?.toString().trim() ?? '';
    final subOrderNumber = data['subOrderNumber']?.toString().trim() ?? '';
    final subOrderKey = _garmentSubOrderKey(first);
    final subOrderJobs = allJobs
        .where((job) {
          final candidate = job.data();
          if (candidate['orderId']?.toString().trim() != orderId) return false;
          return _sameGarmentSubOrder(first, job);
        })
        .toList(growable: false);
    final sortedSubOrderJobs = [...subOrderJobs]
      ..sort(
        (a, b) => _serviceStepNumber(
          a,
          subOrderJobs,
        ).compareTo(_serviceStepNumber(b, subOrderJobs)),
      );
    final completedCount = sortedSubOrderJobs
        .where((job) => job.data()['status'] == 'completed')
        .length;
    final totalSteps = sortedSubOrderJobs.length;
    const actionableStatuses = {
      'offered',
      'accepted',
      'inspectionPending',
      'awaitingConsent',
      'awaitingCustomerEdit',
      'readyToStart',
      'inProgress',
      'qualityCheck',
    };
    final activeJobs = visibleJobs
        .where((job) => actionableStatuses.contains(job.data()['status']))
        .toList(growable: false);
    final historyJobs = visibleJobs
        .where((job) => !actionableStatuses.contains(job.data()['status']))
        .toList(growable: false);
    final garmentName =
        data['displayName']?.toString().trim().isNotEmpty == true
        ? data['displayName'].toString().trim()
        : data['itemTypeCode']?.toString() ?? 'Garment';
    final serviceId = data['serviceId']?.toString() ?? '';
    final progressLabel = totalSteps == 0
        ? 'Service status unavailable'
        : '$completedCount of $totalSteps service steps complete';

    return Container(
      key: ValueKey<String>('partner-garment-suborder-$orderId-$subOrderKey'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFD),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: GarmentCareColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _garmentEmoji(serviceId),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subOrderNumber.isEmpty
                          ? garmentName
                          : '$garmentName · Sub-order $subOrderNumber',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$progressLabel${activeJobs.isEmpty ? '' : ' · ${activeJobs.length} action${activeJobs.length == 1 ? '' : 's'}'}',
                      style: const TextStyle(
                        color: GarmentCareColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activeJobs.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final job in activeJobs) _jobCard(context, job, allJobs),
          ],
          if (historyJobs.isNotEmpty) ...[
            if (activeJobs.isNotEmpty) const Divider(height: 14),
            for (final job in historyJobs) _compactServiceStep(job, allJobs),
          ],
        ],
      ),
    );
  }

  Widget _compactServiceStep(
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allJobs,
  ) {
    final data = job.data();
    final status = data['status']?.toString() ?? '';
    final serviceName = GarmentCareServiceCatalog.labelFor(
      data['serviceId']?.toString() ?? '',
    );
    final note = data['customerDecisionNote']?.toString().trim() ?? '';
    final statusLabel = switch (status) {
      'completed' => 'Complete',
      'blocked' =>
        note.toLowerCase().startsWith('declined by customer')
            ? 'Declined by customer'
            : 'Blocked',
      'cancelled' =>
        data['cancellationReason'] == 'customer_declined_suborder'
            ? 'Stopped after customer decline'
            : 'Cancelled',
      'queued' =>
        data['dispatchEligible'] == true
            ? 'Waiting for partner assignment'
            : 'Waiting for earlier step',
      _ => 'Updated',
    };
    final stepNumber = _serviceStepNumber(job, allJobs);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checkroom_outlined,
                size: 16,
                color: GarmentCareColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Step $stepNumber · $serviceName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: const TextStyle(
                  color: GarmentCareColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (status == 'blocked' && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 23, top: 2),
              child: Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GarmentCareColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _orderGroupStatusSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
  ) {
    final statuses = jobs
        .map((job) => job.data()['status']?.toString() ?? '')
        .toList(growable: false);
    final parts = <String>[];
    void add(String label, int count) {
      if (count > 0) parts.add('$count $label');
    }

    final offeredJobs = jobs
        .where((job) => job.data()['status'] == 'offered')
        .toList(growable: false);
    final nextStepOffers = offeredJobs
        .where(
          (job) =>
              job.data()['dependsOnJobId']?.toString().trim().isNotEmpty ??
              false,
        )
        .length;
    add('next steps to accept', nextStepOffers);
    add('care services to accept', offeredJobs.length - nextStepOffers);
    add(
      'to inspect',
      statuses
          .where((status) => ['accepted', 'inspectionPending'].contains(status))
          .length,
    );
    add(
      'ready to start',
      statuses.where((status) => status == 'readyToStart').length,
    );
    add('in care', statuses.where((status) => status == 'inProgress').length);
    add(
      'quality checks',
      statuses.where((status) => status == 'qualityCheck').length,
    );
    add(
      'waiting for customer',
      statuses
          .where(
            (status) =>
                ['awaitingConsent', 'awaitingCustomerEdit'].contains(status),
          )
          .length,
    );
    add(
      'care complete',
      statuses.where((status) => status == 'completed').length,
    );
    add('declined', statuses.where((status) => status == 'blocked').length);
    return parts.join(' · ');
  }

  Widget _emptyWorkCard(BuildContext context, String tab) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: GarmentCareColors.divider),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.checkroom_outlined,
          size: 38,
          color: GarmentCareColors.primary,
        ),
        const SizedBox(height: 10),
        Text(
          switch (tab) {
            'all' => 'Orders will appear here',
            'new' => 'No care steps are waiting for you to accept',
            'check' => 'No garments need inspection',
            'waiting' => 'No customer response is pending',
            'ready' => 'No care service is ready to start',
            'care' => 'No care service is in progress',
            'quality' => 'No quality check is waiting',
            'completed' => 'Delivered orders will appear here',
            _ => 'No work needs your attention right now',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          tab == 'today'
              ? 'New service requests and handover tasks will appear when they are ready.'
              : 'Your work updates automatically as the order moves forward.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: GarmentCareColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _jobCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> allJobs,
  ) {
    final data = job.data();
    final status = data['status']?.toString() ?? 'queued';
    final orderId = data['orderId']?.toString().trim() ?? '';
    final deliveryGroupId = data['deliveryGroupId']?.toString().trim() ?? '';
    final outgoingShipmentIds =
        (data['outgoingShipmentIds'] as List<dynamic>? ?? const [])
            .map((id) => id.toString().trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
    final latestOutgoingShipmentId = outgoingShipmentIds.isEmpty
        ? null
        : outgoingShipmentIds.last;
    final linkedReturnShipmentId =
        data['returnWithShipmentId']?.toString().trim() ?? '';
    final subOrderJobs = allJobs
        .where((candidate) {
          final candidateData = candidate.data();
          return candidateData['orderId']?.toString().trim() == orderId &&
              _sameGarmentSubOrder(job, candidate);
        })
        .toList(growable: false);
    final subOrderStatuses = subOrderJobs
        .map((candidate) => candidate.data()['status']?.toString() ?? '')
        .toList(growable: false);
    final subOrderCareComplete =
        subOrderStatuses.isNotEmpty &&
        (outgoingShipmentIds.isNotEmpty || linkedReturnShipmentId.isNotEmpty) &&
        subOrderStatuses.every(
          (value) => ['completed', 'cancelled', 'blocked'].contains(value),
        );
    final pendingSubOrderStatuses = subOrderStatuses
        .where(
          (value) => !['completed', 'cancelled', 'blocked'].contains(value),
        )
        .toList(growable: false);
    final serviceStepNumber = _serviceStepNumber(job, subOrderJobs);
    final actionBusy = _busyJobIds.contains(job.id);
    final serviceId = data['serviceId']?.toString() ?? '';
    final garmentName =
        data['displayName']?.toString().trim().isNotEmpty == true
        ? data['displayName'].toString().trim()
        : data['itemTypeCode']?.toString() ?? 'Garment';
    final serviceName = GarmentCareServiceCatalog.labelFor(serviceId);
    final isNextService =
        (data['dependsOnJobId']?.toString().trim() ?? '').isNotEmpty;
    final orderNumber = data['orderNumber']?.toString().trim() ?? '';
    final subOrderNumber = data['subOrderNumber']?.toString().trim() ?? '';
    final garmentId = data['garmentId']?.toString().trim() ?? '';
    final shortGarmentId = garmentId.length > 6
        ? garmentId.substring(garmentId.length - 6)
        : garmentId;
    final subOrderType = GarmentCareServiceGroup.fromCode(
      data['serviceGroupCode']?.toString(),
    )?.label;
    final orderLabel = orderNumber.isEmpty
        ? 'Order number pending'
        : 'Order $orderNumber';
    final pickupDetailsRelevant =
        !isNextService && (status == 'offered' || status == 'accepted');
    final hasMaterial = (data['material']?.toString().trim() ?? '').isNotEmpty;
    final timestampKeys = switch (status) {
      'completed' => ['completedAt', 'updatedAt', 'createdAt'],
      'inspectionPending' => ['inspectionStartedAt', 'updatedAt', 'createdAt'],
      'readyToStart' ||
      'inProgress' ||
      'qualityCheck' => ['updatedAt', 'createdAt'],
      'awaitingConsent' || 'awaitingCustomerEdit' => [
        'updatedAt',
        'inspectionStartedAt',
        'createdAt',
      ],
      'accepted' => ['acceptedAt', 'updatedAt', 'createdAt'],
      _ => ['updatedAt', 'createdAt'],
    };
    Timestamp? statusTimestamp;
    for (final key in timestampKeys) {
      if (data[key] is Timestamp) {
        statusTimestamp = data[key] as Timestamp;
        break;
      }
    }
    final timestampLabel = switch (status) {
      'completed' => 'Care completed',
      'qualityCheck' => 'Quality check',
      'inProgress' => 'Care updated',
      'inspectionPending' => 'Inspection started',
      'awaitingConsent' => 'Sent for approval',
      'awaitingCustomerEdit' => 'Customer update requested',
      'accepted' => 'Accepted',
      _ => 'Order received',
    };
    final photoPaths = <String>{
      ...(data['conditionPhotoPaths'] as List<dynamic>? ?? const []).map(
        (value) => value.toString(),
      ),
      ...(data['inspectionEvidencePaths'] as List<dynamic>? ?? const []).map(
        (value) => value.toString(),
      ),
    }.where((path) => path.isNotEmpty).toList(growable: false);

    return Container(
      key: ValueKey<String>('garment-care-job-${job.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: GarmentCareColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _garmentEmoji(serviceId),
                    style: const TextStyle(fontSize: 23),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$garmentName · $serviceName',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subOrderNumber.isEmpty
                              ? orderLabel
                              : '$orderLabel · Sub-order $subOrderNumber${subOrderType == null ? '' : ' · $subOrderType'} · Service step $serviceStepNumber of ${subOrderJobs.length}',
                          style: const TextStyle(
                            color: GarmentCareColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (shortGarmentId.isNotEmpty)
                          Text(
                            'Garment ID $shortGarmentId',
                            style: const TextStyle(
                              color: GarmentCareColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        if (statusTimestamp != null)
                          Text(
                            '$timestampLabel · ${_formatCareTimestamp(statusTimestamp)}',
                            style: const TextStyle(
                              color: GarmentCareColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PartnerJobStatusPill(
                    status: status,
                    isNextService: isNextService,
                    shipmentId: status == 'completed'
                        ? latestOutgoingShipmentId
                        : null,
                    deliveryGroupId: data['deliveryGroupId']?.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'What to do next',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _nextStepMessage(
                  status,
                  garmentName,
                  isNextService,
                  subOrderCareComplete: subOrderCareComplete,
                  subOrderNumber: subOrderNumber,
                  pendingServiceSteps: pendingSubOrderStatuses.length,
                  customerDecisionNote: data['customerDecisionNote']
                      ?.toString(),
                  pickupRejectionCode: data['pickupRejectionCode']?.toString(),
                ),
                style: const TextStyle(
                  color: GarmentCareColors.textPrimary,
                  height: 1.35,
                ),
              ),
              if ((status == 'completed' && subOrderCareComplete) ||
                  (status == 'blocked' &&
                      (data['returnWithShipmentId']
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false))) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _openHandoverTasks(
                      orderId: orderId,
                      orderNumber: orderNumber,
                      deliveryGroupId: deliveryGroupId,
                      subOrderNumber: subOrderNumber,
                      shipmentId: status == 'completed'
                          ? latestOutgoingShipmentId
                          : data['returnWithShipmentId']?.toString(),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      status == 'completed'
                          ? 'Open payment & handover'
                          : 'View linked return task',
                    ),
                  ),
                ),
              ],
              if (photoPaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Garment photos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final path in photoPaths)
                      _PartnerGarmentCarePhoto(path: path),
                  ],
                ),
              ],
              if (pickupDetailsRelevant)
                _PartnerJobOrderDetails(
                  jobId: job.id,
                  accountId: accountId,
                  profileId: profileId,
                ),
              if (hasMaterial) ...[
                const SizedBox(height: 7),
                _PartnerCareGuidanceNotice(
                  material: data['material'].toString(),
                  serviceId: serviceId,
                ),
              ],
              if ((data['conditionNotes']?.toString().trim() ?? '')
                      .isNotEmpty ||
                  (data['careNotes']?.toString().trim() ?? '').isNotEmpty ||
                  data['hygieneWashRequested'] == true) ...[
                const SizedBox(height: 2),
                ExpansionTile(
                  key: PageStorageKey<String>(
                    'partner-job-${job.id}-customer-notes',
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  title: const Text('Customer notes'),
                  children: [
                    if (data['hygieneWashRequested'] == true)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Hygiene wash'),
                        subtitle: Text(
                          'Customer requested it if suitable. Confirm the care label and inspection before applying.',
                        ),
                      ),
                    if ((data['conditionNotes']?.toString().trim() ?? '')
                        .isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Condition'),
                        subtitle: Text(data['conditionNotes'].toString()),
                      ),
                    if ((data['careNotes']?.toString().trim() ?? '').isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Care instructions'),
                        subtitle: Text(data['careNotes'].toString()),
                      ),
                  ],
                ),
              ],
              ExpansionTile(
                key: PageStorageKey<String>(
                  'partner-job-${job.id}-internal-references',
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: const Text('Internal references'),
                children: [
                  SelectableText(
                    'Job ID: ${job.id}',
                    key: PageStorageKey<String>(
                      'partner-job-${job.id}-internal-reference-job-id',
                    ),
                  ),
                  if ((data['garmentId']?.toString() ?? '').isNotEmpty)
                    SelectableText(
                      'Garment ID: ${data['garmentId']}',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-garment-id',
                      ),
                    ),
                  if ((data['orderId']?.toString() ?? '').isNotEmpty)
                    SelectableText(
                      'Parent order ID: ${data['orderId']}',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-order-id',
                      ),
                    ),
                  if ((data['deliveryGroupId']?.toString() ?? '').isNotEmpty)
                    SelectableText(
                      'Service group ID: ${data['deliveryGroupId']}',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-service-group-id',
                      ),
                    ),
                  if ((data['incomingShipmentId']?.toString() ?? '').isNotEmpty)
                    SelectableText(
                      'Incoming shipment ID: ${data['incomingShipmentId']}',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-incoming-shipment-id',
                      ),
                    ),
                  if ((data['pickupShipmentId']?.toString() ?? '').isNotEmpty)
                    SelectableText(
                      'Pickup shipment ID: ${data['pickupShipmentId']}',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-pickup-shipment-id',
                      ),
                    ),
                  for (final shipmentId
                      in (data['outgoingShipmentIds'] as List<dynamic>? ??
                          const []))
                    SelectableText(
                      'Outgoing shipment ID: $shipmentId',
                      key: PageStorageKey<String>(
                        'partner-job-${job.id}-internal-reference-outgoing-shipment-$shipmentId',
                      ),
                    ),
                  if (data['acceptedAt'] is Timestamp)
                    Text(
                      'Accepted: ${_formatCareTimestamp(data['acceptedAt'] as Timestamp)}',
                    ),
                  if (data['inspectionStartedAt'] is Timestamp)
                    Text(
                      'Inspection started: ${_formatCareTimestamp(data['inspectionStartedAt'] as Timestamp)}',
                    ),
                ],
              ),
              if (actionBusy) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (status == 'offered') ...[
                const SizedBox(height: 10),
                _primaryAction(
                  label: isNextService
                      ? 'Accept next care step'
                      : 'Accept care service',
                  icon: Icons.assignment_turned_in_outlined,
                  busy: actionBusy,
                  onPressed: () => _runJobAction(
                    job.id,
                    () => _advance(context, job.id, 'accepted'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: actionBusy
                        ? null
                        : () => _runJobAction(
                            job.id,
                            () => _advance(context, job.id, 'rejected'),
                          ),
                    child: const Text('Decline service'),
                  ),
                ),
              ] else if (status == 'accepted') ...[
                const SizedBox(height: 10),
                _primaryAction(
                  label: 'Check Clothes',
                  icon: Icons.search_rounded,
                  busy: actionBusy,
                  onPressed: () => _runJobAction(
                    job.id,
                    () => _advance(context, job.id, 'inspectionPending'),
                  ),
                ),
              ] else if (status == 'inspectionPending')
                _PartnerInspectionForm(
                  jobId: job.id,
                  job: data,
                  accountId: accountId,
                  profileId: profileId,
                  busy: actionBusy,
                  onSubmit: (inspection) => _runJobAction(
                    job.id,
                    () => _submitInspectionQuote(context, job.id, inspection),
                  ),
                )
              else if (status == 'awaitingConsent')
                _WaitingForCustomerApprovalCard()
              else if (status == 'awaitingCustomerEdit')
                _WaitingForCustomerApprovalCard(
                  title: 'Waiting for Customer',
                  message:
                      data['revisionReason']?.toString().trim().isNotEmpty ==
                          true
                      ? data['revisionReason'].toString()
                      : 'The Customer needs to respond before this service can continue.',
                )
              else if (status == 'readyToStart') ...[
                const SizedBox(height: 10),
                _primaryAction(
                  label: 'Start Care',
                  icon: Icons.play_arrow_rounded,
                  busy: actionBusy,
                  onPressed: () => _runJobAction(
                    job.id,
                    () => _advance(context, job.id, 'inProgress'),
                  ),
                ),
              ] else if (status == 'inProgress') ...[
                const SizedBox(height: 10),
                _primaryAction(
                  label: 'Send for quality check',
                  icon: Icons.fact_check_outlined,
                  busy: actionBusy,
                  onPressed: () => _runJobAction(
                    job.id,
                    () => _advance(context, job.id, 'qualityCheck'),
                  ),
                ),
              ] else if (status == 'qualityCheck') ...[
                const SizedBox(height: 10),
                _primaryAction(
                  label: 'Mark Care Complete',
                  icon: Icons.check_circle_outline_rounded,
                  busy: actionBusy,
                  onPressed: () => _runJobAction(job.id, () async {
                    final treatmentRecord = await _requestTreatmentRecord(
                      context,
                      serviceName,
                      serviceId,
                      data['material']?.toString() ?? '',
                    );
                    if (!context.mounted || treatmentRecord == null) return;
                    await _advance(
                      context,
                      job.id,
                      'completed',
                      treatmentRecord: treatmentRecord,
                    );
                  }),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: actionBusy
                        ? null
                        : () => _runJobAction(
                            job.id,
                            () => _advance(context, job.id, 'inProgress'),
                          ),
                    child: const Text('Needs more care? Rework'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _serviceStepNumber(
    QueryDocumentSnapshot<Map<String, dynamic>> job,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> subOrderJobs,
  ) {
    final jobsById = {
      for (final candidate in subOrderJobs) candidate.id: candidate,
    };
    final visited = <String>{job.id};
    var dependencyId = job.data()['dependsOnJobId']?.toString().trim() ?? '';
    var stepNumber = 1;
    while (dependencyId.isNotEmpty && visited.add(dependencyId)) {
      final dependency = jobsById[dependencyId];
      if (dependency == null) break;
      stepNumber++;
      dependencyId =
          dependency.data()['dependsOnJobId']?.toString().trim() ?? '';
    }
    return stepNumber;
  }

  Widget _primaryAction({
    required String label,
    required IconData icon,
    required bool busy,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );

  String _nextStepMessage(
    String status,
    String garmentName,
    bool isNextService, {
    required bool subOrderCareComplete,
    required String subOrderNumber,
    required int pendingServiceSteps,
    String? customerDecisionNote,
    String? pickupRejectionCode,
  }) => switch (status) {
    'offered' =>
      isNextService
          ? 'The earlier care step is complete. Review the garment details, then accept this next step into your work queue. Inspection and care actions follow.'
          : 'Review the care request and garment details, then accept this care service. Pickup is confirmed separately.',
    'accepted' => 'Check the $garmentName and record its inspection.',
    'inspectionPending' => 'Record the garment condition before care begins.',
    'awaitingConsent' =>
      'Care is paused until the Customer approves the inspection.',
    'awaitingCustomerEdit' =>
      'Wait for the Customer to respond to the requested change.',
    'readyToStart' => 'Inspection is clear. Start the approved care service.',
    'inProgress' =>
      'Finish the service and send it through the required quality check.',
    'qualityCheck' =>
      'Review quality, then mark care complete or send it for rework.',
    'completed' =>
      subOrderCareComplete
          ? 'All service steps for this garment sub-order are complete. The invoice includes completed services only. Wait for Customer payment; this sub-order’s handover task opens after payment.'
          : pendingServiceSteps > 0
          ? 'This service step is complete. ${pendingServiceSteps == 1 ? 'One other service step remains' : '$pendingServiceSteps other service steps remain'} for sub-order ${subOrderNumber.isEmpty ? 'this garment' : subOrderNumber}. Continue from that step; the invoice and handover task appear after all steps are resolved.'
          : 'This service step is complete, but this garment sub-order is not ready for payment or handover yet. The remaining service assignment may still be processing; check this sub-order again shortly.',
    'blocked' =>
      subOrderCareComplete
          ? customerDecisionNote?.trim().isNotEmpty == true
                ? customerDecisionNote!.trim()
                : 'Declined by customer. Do not perform this service; return the garment with completed garments after payment.'
          : 'Declined by customer. Do not perform this service. Resolve the remaining service steps for this garment; the declined service is excluded from the invoice.',
    'cancelled' =>
      'Pickup was declined. The garment was not collected, remains with the Customer, and has no service sub-order or invoice. Reason: ${_pickupRejectionReasonLabel(pickupRejectionCode)}.',
    _ => 'Open the order details to see the next step.',
  };

  String _garmentEmoji(String serviceId) => switch (serviceId) {
    'advanced_stain_removal' => '✨',
    'fabric_starching' => '👕',
    'bridal_care' => '👘',
    'couture_care' => '👗',
    'steam_ironing' || 'roll_pressing' || 'form_pressing' => '👔',
    'dry_cleaning' || 'leather_suede_fur_care' => '🧥',
    _ => '👗',
  };

  Widget _workspaceOverview(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> jobs,
  ) {
    final newOffers = jobs
        .where((job) => job.data()['status'] == 'offered')
        .length;
    final checkClothes = jobs.where((job) {
      final status = job.data()['status']?.toString();
      return status == 'accepted' || status == 'inspectionPending';
    }).length;
    final waitingForCustomer = jobs.where((job) {
      final status = job.data()['status']?.toString();
      return status == 'awaitingConsent' || status == 'awaitingCustomerEdit';
    }).length;
    final readyToStart = jobs
        .where((job) => job.data()['status'] == 'readyToStart')
        .length;
    final careInProgress = jobs
        .where((job) => job.data()['status'] == 'inProgress')
        .length;
    final qualityChecks = jobs
        .where((job) => job.data()['status'] == 'qualityCheck')
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CarePartnerAvailabilityCard(
            accountId: accountId,
            profileId: profileId,
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: GarmentCareService.partnerIncomingShipments(
              accountId: accountId,
              profileId: profileId,
            ),
            builder: (context, incomingSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: GarmentCareService.partnerOutgoingShipments(
                  accountId: accountId,
                  profileId: profileId,
                ),
                builder: (context, outgoingSnapshot) {
                  final incomingTasks =
                      incomingSnapshot.data?.docs
                          .where(
                            (shipment) =>
                                _isPartnerIncomingHandover(shipment.data()),
                          )
                          .toList(growable: false) ??
                      [];
                  final outgoingTasks =
                      outgoingSnapshot.data?.docs
                          .where(
                            (shipment) =>
                                _isPartnerOutgoingReady(shipment.data()),
                          )
                          .toList(growable: false) ??
                      [];
                  final pendingPaymentTasks =
                      outgoingSnapshot.data?.docs
                          .where(
                            (shipment) =>
                                _isPartnerPaymentPending(shipment.data()),
                          )
                          .toList(growable: false) ??
                      [];
                  // A parent order may contain several independently billed
                  // garment sub-orders. Count each garment delivery group so
                  // the partner sees the work actually waiting for payment.
                  final pendingPaymentSubOrderKeys = pendingPaymentTasks.map((
                    shipment,
                  ) {
                    final data = shipment.data();
                    final orderId = data['orderId']?.toString().trim() ?? '';
                    final deliveryGroupId =
                        data['deliveryGroupId']?.toString().trim() ?? '';
                    final subOrderNumber =
                        data['subOrderNumber']?.toString().trim() ?? '';
                    if (deliveryGroupId.isNotEmpty) {
                      return '$orderId|$deliveryGroupId';
                    }
                    if (subOrderNumber.isNotEmpty) {
                      return '$orderId|$subOrderNumber';
                    }
                    return shipment.id;
                  }).toSet();
                  final pendingPaymentCount = pendingPaymentSubOrderKeys.length;
                  final pickupCount = incomingTasks
                      .where(
                        (shipment) =>
                            shipment.data()['shipmentType'] ==
                            'customer_pickup',
                      )
                      .length;
                  final deliveryPinCount = outgoingTasks
                      .where(
                        (shipment) =>
                            _isPartnerCustomerDeliveryPinTask(shipment.data()),
                      )
                      .length;
                  final readyDeliveryCount = outgoingTasks
                      .where(
                        (shipment) => _isPartnerReadyDelivery(shipment.data()),
                      )
                      .length;
                  final handoverCount =
                      incomingTasks.length + outgoingTasks.length;
                  final onlyPickupRequests =
                      pickupCount > 0 && pickupCount == handoverCount;
                  final onlyReadyDeliveries =
                      readyDeliveryCount > 0 &&
                      readyDeliveryCount == handoverCount;
                  final onlyCustomerDeliveryPins =
                      deliveryPinCount > 0 && deliveryPinCount == handoverCount;
                  final showCombinedHandoverButton =
                      handoverCount > 0 &&
                      !onlyPickupRequests &&
                      !onlyReadyDeliveries &&
                      !onlyCustomerDeliveryPins;
                  return Column(
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.62,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _summaryCard(
                            'Care Steps to Accept',
                            '$newOffers',
                            Icons.assignment_outlined,
                            onTap: newOffers > 0
                                ? () => _selectWorkTab('new')
                                : null,
                          ),
                          _summaryCard(
                            'Check Clothes',
                            '$checkClothes',
                            Icons.search_rounded,
                            onTap: checkClothes > 0
                                ? () => _selectWorkTab('check')
                                : null,
                          ),
                          _summaryCard(
                            'Ready to Start',
                            '$readyToStart',
                            Icons.play_circle_outline_rounded,
                            onTap: readyToStart > 0
                                ? () => _selectWorkTab('ready')
                                : null,
                          ),
                          _summaryCard(
                            'Care in Progress',
                            '$careInProgress',
                            Icons.local_laundry_service_outlined,
                            onTap: careInProgress > 0
                                ? () => _selectWorkTab('care')
                                : null,
                          ),
                          _summaryCard(
                            'Quality Check',
                            '$qualityChecks',
                            Icons.fact_check_outlined,
                            onTap: qualityChecks > 0
                                ? () => _selectWorkTab('quality')
                                : null,
                          ),
                          _summaryCard(
                            'Waiting for Customer',
                            '$waitingForCustomer',
                            Icons.hourglass_top_rounded,
                            onTap: waitingForCustomer > 0
                                ? () => _selectWorkTab('waiting')
                                : null,
                          ),
                          _summaryCard(
                            'Payment Pending',
                            outgoingSnapshot.hasError
                                ? '—'
                                : '$pendingPaymentCount',
                            Icons.payment_rounded,
                            onTap: pendingPaymentTasks.isNotEmpty
                                ? () => _openHandoverTasks(
                                    paymentPendingOnly: true,
                                  )
                                : null,
                          ),
                          _summaryCard(
                            'Ready for Delivery',
                            outgoingSnapshot.hasError
                                ? '—'
                                : '$readyDeliveryCount',
                            Icons.inventory_2_outlined,
                            onTap: readyDeliveryCount > 0
                                ? () => _openHandoverTasks(
                                    readyDeliveryOnly: true,
                                  )
                                : null,
                          ),
                          _summaryCard(
                            'Out for Delivery',
                            outgoingSnapshot.hasError
                                ? '—'
                                : '$deliveryPinCount',
                            Icons.delivery_dining_outlined,
                            onTap: deliveryPinCount > 0
                                ? () => _openHandoverTasks(
                                    customerDeliveryOnly: true,
                                  )
                                : null,
                          ),
                          _summaryCard(
                            'Pickup Requests',
                            incomingSnapshot.hasError ? '—' : '$pickupCount',
                            Icons.local_shipping_outlined,
                            onTap: pickupCount > 0
                                ? () => _openHandoverTasks(pickupsOnly: true)
                                : null,
                          ),
                        ],
                      ),
                      if (pendingPaymentTasks.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Card(
                          color: const Color(0xFFFFF5F8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                            side: const BorderSide(
                              color: GarmentCareColors.primary,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CUSTOMER PAYMENT PENDING',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: GarmentCareColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$pendingPaymentCount garment ${pendingPaymentCount == 1 ? 'sub-order is' : 'sub-orders are'} waiting for customer payment. The Customer can pay ready garments together on one service-order invoice. Dispatch starts after payment.',
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openHandoverTasks(
                                      paymentPendingOnly: true,
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text(
                                      'Review payment pending garments',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (showCombinedHandoverButton) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openHandoverTasks(),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text(
                              'View all pickup and handover tasks',
                            ),
                          ),
                        ),
                      ],
                      if (incomingSnapshot.hasError ||
                          outgoingSnapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Task count is temporarily unavailable. Open tasks to retry.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 11, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: GarmentCareColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: GarmentCareColors.primary, size: 20),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.1),
            ),
          ],
        ),
      ),
    ),
  );

  void _openHandoverTasks({
    bool pickupsOnly = false,
    bool customerDeliveryOnly = false,
    bool readyDeliveryOnly = false,
    bool paymentPendingOnly = false,
    String? orderId,
    String? orderNumber,
    String? deliveryGroupId,
    String? subOrderNumber,
    String? shipmentId,
  }) {
    final queryParameters = <String, String>{
      'accountId': accountId,
      'profileId': profileId,
      if (pickupsOnly)
        'filter': 'pickup'
      else if (customerDeliveryOnly)
        'filter': 'customer_delivery'
      else if (readyDeliveryOnly)
        'filter': 'ready_delivery'
      else if (paymentPendingOnly)
        'filter': 'payment_pending',
      if (orderId?.trim().isNotEmpty == true) 'orderId': orderId!.trim(),
      if (orderNumber?.trim().isNotEmpty == true)
        'orderNumber': orderNumber!.trim(),
      if (deliveryGroupId?.trim().isNotEmpty == true)
        'deliveryGroupId': deliveryGroupId!.trim(),
      if (subOrderNumber?.trim().isNotEmpty == true)
        'subOrderNumber': subOrderNumber!.trim(),
      if (shipmentId?.trim().isNotEmpty == true)
        'shipmentId': shipmentId!.trim(),
    };
    context.push(
      Uri(
        path: '/partner/garment-care/custody',
        queryParameters: queryParameters,
      ).toString(),
    );
  }

  void _selectWorkTab(String tab) {
    setState(() {
      _selectedBottomDestination = 1;
      _selectedWorkTab = tab;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _workContentKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          alignment: 0,
        );
      }
    });
  }

  Future<void> _onBottomDestination(int index) async {
    if (index < 2) {
      setState(() {
        _selectedBottomDestination = index;
        _selectedWorkTab = index == 0 ? 'today' : 'all';
      });
      return;
    }
    setState(() => _selectedBottomDestination = index);
    final route = index == 2
        ? '/partner/garment-care/custody?accountId=${Uri.encodeQueryComponent(accountId)}&profileId=${Uri.encodeQueryComponent(profileId)}'
        : '/partner/account?accountId=${Uri.encodeQueryComponent(accountId)}&profileId=${Uri.encodeQueryComponent(profileId)}&category=garmentCare';
    await context.push(route);
    if (mounted) setState(() => _selectedBottomDestination = 0);
  }

  Widget _loadError(BuildContext context, Object? error) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _workspaceOverview(context, const []),
      Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: GarmentCareColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'Could not load assigned jobs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(_friendlyLoadError(error), textAlign: TextAlign.center),
              if (error != null) ...[
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  title: const Text('Diagnostic details'),
                  children: [SelectableText(error.toString())],
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go(
                  '/partner/garment-care?accountId=${Uri.encodeQueryComponent(accountId)}&profileId=${Uri.encodeQueryComponent(profileId)}',
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  String _friendlyLoadError(Object? error) {
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Firestore rejected this Partner profile. Confirm the current Garment Care rules are deployed and the active profile is approved, verified and operational.',
        'failed-precondition' =>
          'Firestore needs an index for assigned jobs. Deploy the current firestore.indexes.json and retry.',
        'unauthenticated' => 'Your sign-in expired. Sign in again and retry.',
        'unavailable' =>
          'The database is temporarily unavailable. Check the connection and retry.',
        _ => error.message ?? 'Could not load assigned Garment Care jobs.',
      };
    }
    return 'Could not load assigned Garment Care jobs. Check the diagnostic details below.';
  }

  Future<void> _runJobAction(
    String jobId,
    Future<void> Function() action,
  ) async {
    if (_busyJobIds.contains(jobId)) return;
    setState(() => _busyJobIds.add(jobId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyJobIds.remove(jobId));
    }
  }

  bool _isDeadlineExceeded(FirebaseFunctionsException error) =>
      error.code.toLowerCase().replaceAll('_', '-') == 'deadline-exceeded';

  Future<Map<String, String>?> _requestTreatmentRecord(
    BuildContext context,
    String serviceName,
    String serviceId,
    String material,
  ) => showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CareTreatmentRecordDialog(
      serviceName: serviceName,
      serviceId: serviceId,
      material: material,
      accountId: accountId,
      profileId: profileId,
    ),
  );

  Future<void> _advance(
    BuildContext context,
    String jobId,
    String status, {
    Map<String, String> treatmentRecord = const {},
  }) async {
    try {
      await GarmentCareService.advanceJob(
        jobId: jobId,
        accountId: accountId,
        profileId: profileId,
        targetStatus: status,
        treatmentRecord: treatmentRecord,
      );
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isDeadlineExceeded(error)
                  ? 'This update is taking longer. The order stays active; refresh its status and retry if needed.'
                  : error.message ?? 'Could not update the job.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the job.')),
        );
      }
    }
  }

  Future<void> _submitInspectionQuote(
    BuildContext context,
    String jobId,
    Map<String, dynamic> inspection,
  ) async {
    try {
      final result = await GarmentCareService.submitInspectionQuote(
        jobId: jobId,
        accountId: accountId,
        profileId: profileId,
        inspectionNotes: inspection['inspectionNotes']?.toString() ?? '',
        conditionFindings: inspection['conditionFindings']?.toString() ?? '',
        additionalServiceFee:
            (inspection['additionalServiceFee'] as num?)?.toDouble() ?? 0,
        additionalServiceReason:
            inspection['additionalServiceReason']?.toString() ?? '',
        inspectionMode: inspection['inspectionMode']?.toString() ?? '',
        conditionCode: inspection['conditionCode']?.toString() ?? '',
        observationCodes:
            (inspection['observationCodes'] as List<dynamic>? ?? const [])
                .map((value) => value.toString())
                .toList(growable: false),
        recommendedActionCode:
            inspection['recommendedActionCode']?.toString() ?? '',
        priceImpactCode: inspection['priceImpactCode']?.toString() ?? '',
        customerMessage: inspection['customerMessage']?.toString() ?? '',
        optionalNote: inspection['optionalNote']?.toString() ?? '',
        inspectionTemplateId:
            inspection['inspectionTemplateId']?.toString() ?? '',
        inspectionTemplateVersionId:
            inspection['inspectionTemplateVersionId']?.toString() ?? '',
        inspectionTemplateVersion:
            (inspection['inspectionTemplateVersion'] as num?)?.toInt(),
        inspectionEvidencePaths:
            (inspection['inspectionEvidencePaths'] as List<dynamic>? ??
                    const [])
                .map((value) => value.toString())
                .toList(growable: false),
      );
      if (!context.mounted) return;
      final consentRequired = result['consentRequired'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            consentRequired
                ? 'Inspection sent to the Customer for approval.'
                : 'Inspection complete. This service is ready to start.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isDeadlineExceeded(error)
                ? 'This update is taking longer than expected. Check the order status before retrying; it has not been rejected.'
                : error.message ?? 'Could not submit the inspection.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit the inspection.')),
      );
    }
  }

  String _formatCareTimestamp(Timestamp timestamp) {
    final value = timestamp.toDate().toLocal();
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }
}

class _CareTreatmentRecordDialog extends StatefulWidget {
  const _CareTreatmentRecordDialog({
    required this.serviceName,
    required this.serviceId,
    required this.material,
    required this.accountId,
    required this.profileId,
  });

  final String serviceName;
  final String serviceId;
  final String material;
  final String accountId;
  final String profileId;

  @override
  State<_CareTreatmentRecordDialog> createState() =>
      _CareTreatmentRecordDialogState();
}

class _CareTreatmentRecordDialogState
    extends State<_CareTreatmentRecordDialog> {
  final _methodController = TextEditingController();
  final _processController = TextEditingController();
  final _finishingController = TextEditingController();
  final _qualityController = TextEditingController();
  List<GarmentCareCompletionTemplate> _templates =
      garmentCareStarterCompletionTemplates;
  String? _selectedTemplateId;
  String _selectedTemplateVersionId = '';
  bool _loadingTemplates = true;

  List<GarmentCareCompletionTemplate> get _applicableTemplates {
    final matches = _templates
        .where(
          (item) => item.appliesTo(
            serviceId: widget.serviceId,
            material: widget.material,
          ),
        )
        .toList(growable: false);
    return matches.isEmpty ? _templates : matches;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final result = await GarmentCareService.completionTemplates(
        isAdmin: false,
        accountId: widget.accountId,
        profileId: widget.profileId,
      );
      final versionId = result['versionId']?.toString() ?? '';
      final partner = (result['partnerTemplates'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => GarmentCareCompletionTemplate.fromMap(
              Map<String, dynamic>.from(item),
              versionId: 'partner',
            ),
          );
      final shared = (result['templates'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => GarmentCareCompletionTemplate.fromMap(
              Map<String, dynamic>.from(item),
              versionId: versionId,
            ),
          );
      if (!mounted) return;
      setState(() {
        _templates = [...partner, ...shared];
        if (_templates.isEmpty) {
          _templates = garmentCareStarterCompletionTemplates;
        }
        _loadingTemplates = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  void _applyTemplate(String? id) {
    if (id == null) return;
    final template = _templates.firstWhere((item) => item.id == id);
    _methodController.text = template.methodUsed;
    _processController.text = template.processDetails;
    _finishingController.text = template.finishingDetails;
    _qualityController.text = template.qualityNotes;
    setState(() {
      _selectedTemplateId = template.id;
      _selectedTemplateVersionId = template.versionId;
    });
  }

  @override
  void dispose() {
    _methodController.dispose();
    _processController.dispose();
    _finishingController.dispose();
    _qualityController.dispose();
    super.dispose();
  }

  void _saveAndComplete() {
    final selectedId = _selectedTemplateId;
    final selectedTemplate = selectedId == null
        ? null
        : _templates.firstWhere((item) => item.id == selectedId);
    Navigator.of(context).pop(<String, String>{
      'methodUsed': _methodController.text.trim(),
      'processDetails': _processController.text.trim(),
      'finishingDetails': _finishingController.text.trim(),
      'qualityNotes': _qualityController.text.trim(),
      if (selectedTemplate != null) 'templateId': selectedTemplate.id,
      if (selectedTemplate != null) 'templateName': selectedTemplate.name,
      if (_selectedTemplateVersionId.isNotEmpty)
        'templateVersionId': _selectedTemplateVersionId,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Record completed ${widget.serviceName}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow the garment care label, inspection findings and approved service. Record the process actually used; do not select a generic method that was not performed.',
          ),
          const SizedBox(height: 12),
          if (_loadingTemplates)
            const LinearProgressIndicator()
          else if (_templates.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedTemplateId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Use a completion template',
              ),
              hint: const Text('Choose a suitable template'),
              items: [
                for (final template in _applicableTemplates)
                  DropdownMenuItem(
                    value: template.id,
                    child: Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _applyTemplate,
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _methodController,
            maxLength: 240,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Care method used *',
              hintText: 'e.g. hand wash, machine wash, dry clean, steam press',
            ),
          ),
          TextField(
            controller: _processController,
            maxLines: 2,
            maxLength: 800,
            decoration: const InputDecoration(
              labelText: 'Process details',
              hintText:
                  'Detergent / solvent, temperature or settings if relevant',
            ),
          ),
          TextField(
            controller: _finishingController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Finishing details'),
          ),
          TextField(
            controller: _qualityController,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Quality check notes'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _methodController.text.trim().isNotEmpty
            ? _saveAndComplete
            : null,
        child: const Text('Save and complete'),
      ),
    ],
  );
}

class _PartnerGarmentCarePhoto extends StatelessWidget {
  const _PartnerGarmentCarePhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: FirebaseStorage.instance.ref(path).getDownloadURL(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          width: 88,
          height: 88,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          snapshot.data!,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 88,
            height: 88,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      );
    },
  );
}

class _PartnerJobStatusPill extends StatelessWidget {
  const _PartnerJobStatusPill({
    required this.status,
    required this.isNextService,
    this.shipmentId,
    this.deliveryGroupId,
  });

  final String status;
  final bool isNextService;
  final String? shipmentId;
  final String? deliveryGroupId;

  @override
  Widget build(BuildContext context) {
    if (status == 'completed' && (shipmentId?.isNotEmpty ?? false)) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: GarmentCareService.partnerShipmentStatus(shipmentId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _pill(
              'Payment status unavailable',
              GarmentCareColors.textSecondary,
              const Color(0xFFF1EFF0),
            );
          }
          if (!snapshot.hasData) {
            return _pill(
              'Checking payment',
              GarmentCareColors.textSecondary,
              const Color(0xFFF1EFF0),
            );
          }
          final shipment = snapshot.data?.data();
          if (shipment == null ||
              shipment['shipmentType'] != 'customer_return' ||
              shipment['deliveryGroupId']?.toString() != deliveryGroupId) {
            return _pill(
              'Service complete',
              const Color(0xFF2C7A46),
              const Color(0xFFE8F5EC),
            );
          }
          if (_isPartnerPaymentPending(shipment)) {
            return _pill(
              'Payment pending',
              GarmentCareColors.primaryDark,
              const Color(0xFFFFE5EE),
            );
          }
          if (shipment['careComplete'] == true &&
              shipment['paymentStatusAtDelivery'] == 'paid' &&
              shipment['status'] == 'planned') {
            return _pill(
              'Ready for delivery',
              const Color(0xFF3478D4),
              const Color(0xFFE8F1FF),
            );
          }
          if (shipment['status'] == 'inTransit') {
            return _pill(
              'Out for delivery · PIN',
              const Color(0xFF3478D4),
              const Color(0xFFE8F1FF),
            );
          }
          if (shipment['status'] == 'delivered') {
            return _pill(
              'Delivered',
              const Color(0xFF2C7A46),
              const Color(0xFFE8F5EC),
            );
          }
          return _pill(
            'Service complete',
            const Color(0xFF2C7A46),
            const Color(0xFFE8F5EC),
          );
        },
      );
    }

    final (label, foreground, background) = switch (status) {
      'offered' => (
        isNextService ? 'Next care step' : 'New care service',
        const Color(0xFF3478D4),
        const Color(0xFFE8F1FF),
      ),
      'accepted' || 'inspectionPending' => (
        'Check Clothes',
        const Color(0xFF3478D4),
        const Color(0xFFE8F1FF),
      ),
      'awaitingConsent' || 'awaitingCustomerEdit' => (
        'Waiting Customer',
        const Color(0xFF9A5B00),
        const Color(0xFFFFF1D6),
      ),
      'readyToStart' => (
        'Ready for care',
        GarmentCareColors.primaryDark,
        GarmentCareColors.selected,
      ),
      'inProgress' => (
        'In progress',
        GarmentCareColors.primaryDark,
        GarmentCareColors.selected,
      ),
      'qualityCheck' => (
        'Quality check',
        GarmentCareColors.primaryDark,
        GarmentCareColors.selected,
      ),
      'completed' => (
        'Service complete',
        const Color(0xFF2C7A46),
        const Color(0xFFE8F5EC),
      ),
      'blocked' => (
        'Declined by customer',
        const Color(0xFF9A5B00),
        const Color(0xFFFFF1D6),
      ),
      _ => (
        _jobStatusFallback(status),
        GarmentCareColors.textSecondary,
        const Color(0xFFF1EFF0),
      ),
    };
    return _pill(label, foreground, background);
  }

  Widget _pill(String label, Color foreground, Color background) => Container(
    constraints: const BoxConstraints(maxWidth: 112),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String _jobStatusFallback(String status) => status == 'blocked'
    ? 'Declined by customer'
    : status == 'cancelled'
    ? 'Not collected at pickup'
    : status
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match[1]} ${match[2]}',
          )
          .replaceAll('_', ' ');

String _pickupRejectionReasonLabel(String? code) => switch (code) {
  'complex_care' => 'Too complex for this service',
  'unsafe_condition' => 'Condition needs a specialist',
  'service_mismatch' => 'Selected service does not suit this garment',
  'service_unavailable' => 'This service is unavailable at pickup',
  'garment_not_present' => 'Garment was not available',
  'other' => 'Other reason',
  _ => 'No pickup reason recorded',
};

class _WaitingForCustomerApprovalCard extends StatelessWidget {
  const _WaitingForCustomerApprovalCard({
    this.title = 'Waiting for Customer Approval',
    this.message =
        'Care stays paused until the Customer approves the inspection and any revised price.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E4),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFF2D59A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.hourglass_top_rounded, color: Color(0xFF9A5B00)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(message),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PartnerCareGuidanceNotice extends StatelessWidget {
  const _PartnerCareGuidanceNotice({
    required this.material,
    required this.serviceId,
  });

  final String material;
  final String serviceId;

  @override
  Widget build(BuildContext context) {
    final fullGuidance = GarmentCareGuidance.forMaterial(material, '');
    return Container(
      decoration: BoxDecoration(
        color: GarmentCareColors.selected.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: GarmentCareColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$material needs careful handling. Check the care label, avoid bleach and high heat, and test colourfastness before cleaning.',
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              dense: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 9),
              title: const Text('Full fabric-care guidance'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(fullGuidance),
                ),
                if (serviceId == 'fabric_starching') ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      GarmentCareGuidance.starchingRecommendation(material),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerInspectionForm extends StatefulWidget {
  const _PartnerInspectionForm({
    required this.jobId,
    required this.job,
    required this.accountId,
    required this.profileId,
    required this.busy,
    required this.onSubmit,
  });

  final String jobId;
  final Map<String, dynamic> job;
  final String accountId;
  final String profileId;
  final bool busy;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_PartnerInspectionForm> createState() => _PartnerInspectionFormState();
}

class _PartnerInspectionFormState extends State<_PartnerInspectionForm> {
  static const _conditions = <String, String>{
    'good': 'Good',
    'minor_wear': 'Minor wear',
    'existing_stain': 'Existing stain',
    'existing_damage': 'Existing damage',
    'colour_bleeding': 'Possible colour transfer risk',
    'fabric_weakness': 'Fabric weakness',
  };
  static const _observations = <String, String>{
    'minor_stains': 'Minor stains',
    'existing_stain': 'Existing stain',
    'colour_bleeding': 'Possible colour bleeding',
    'loose_seam': 'Loose seam',
    'missing_button': 'Missing button or fastener',
    'existing_damage': 'Existing damage',
    'delicate_embellishment': 'Delicate embellishment',
    'fabric_weakness': 'Fabric weakness',
    'missing_embellishment': 'Missing embellishment',
    'other': 'Other visible issue',
  };
  static const _actions = <String, String>{
    'proceed_as_requested': 'Proceed as requested',
    'gentle_handling': 'Use gentle handling',
    'recommend_additional_treatment': 'Recommend additional treatment',
    'recommend_different_service': 'Recommend a different service',
    'hold_for_customer_approval': 'Pause until the Customer decides',
  };
  static const _priceImpacts = <String, String>{
    'no_additional_charge': 'No additional charge',
    'revised_quote_required': 'Add a charge for Customer approval',
  };

  Map<String, String> _conditionOptionsFor(String serviceId) =>
      serviceId.startsWith('steam_') ||
          serviceId == 'roll_pressing' ||
          serviceId == 'form_pressing'
      ? {
          'good': _conditions['good']!,
          'minor_wear': _conditions['minor_wear']!,
          'existing_damage': _conditions['existing_damage']!,
          'fabric_weakness': _conditions['fabric_weakness']!,
        }
      : _conditions;

  Map<String, String> _observationOptionsFor(String serviceId) {
    if (serviceId.startsWith('steam_') ||
        serviceId == 'roll_pressing' ||
        serviceId == 'form_pressing') {
      return {
        for (final code in [
          'loose_seam',
          'missing_button',
          'delicate_embellishment',
          'fabric_weakness',
          'existing_damage',
          'other',
        ])
          code: _observations[code]!,
      };
    }
    if ([
      'advanced_stain_removal',
      'fabric_starching',
      'saree_polishing',
      'fabric_conditioning',
    ].contains(serviceId)) {
      return {
        for (final code in [
          'minor_stains',
          'existing_stain',
          'colour_bleeding',
          'fabric_weakness',
          'existing_damage',
          'other',
        ])
          code: _observations[code]!,
      };
    }
    if ([
      'couture_care',
      'bridal_care',
      'embellishment_protection',
      'leather_suede_fur_care',
    ].contains(serviceId)) {
      return {
        for (final code in [
          'existing_damage',
          'delicate_embellishment',
          'missing_embellishment',
          'existing_stain',
          'colour_bleeding',
          'fabric_weakness',
          'other',
        ])
          code: _observations[code]!,
      };
    }
    return _observations;
  }

  Map<String, String> _actionOptionsFor(String serviceId) =>
      serviceId.startsWith('steam_') ||
          serviceId == 'roll_pressing' ||
          serviceId == 'form_pressing'
      ? {
          'proceed_as_requested': _actions['proceed_as_requested']!,
          'gentle_handling': _actions['gentle_handling']!,
          'recommend_different_service':
              _actions['recommend_different_service']!,
          'hold_for_customer_approval': _actions['hold_for_customer_approval']!,
        }
      : _actions;

  final _additionalFee = TextEditingController();
  final _optionalNote = TextEditingController();
  final PageStorageBucket _inspectionFormStorage = PageStorageBucket();
  late Future<Map<String, dynamic>> _inspectionContext;
  bool _issueFound = false;
  String _conditionCode = 'good';
  String _actionCode = 'proceed_as_requested';
  String _priceImpactCode = 'no_additional_charge';
  final Set<String> _observationCodes = <String>{};
  String? _evidencePath;
  bool _capturingPhoto = false;

  @override
  void initState() {
    super.initState();
    _inspectionContext = _loadInspectionContext();
  }

  Future<Map<String, dynamic>> _loadInspectionContext() =>
      GarmentCareService.partnerInspectionContext(
        jobId: widget.jobId,
        accountId: widget.accountId,
        profileId: widget.profileId,
      );

  @override
  void dispose() {
    _additionalFee.dispose();
    _optionalNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageStorage(
    bucket: _inspectionFormStorage,
    child: FutureBuilder<Map<String, dynamic>>(
      future: _inspectionContext,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inspection details could not be loaded.'),
              TextButton.icon(
                onPressed: () => setState(
                  () => _inspectionContext = _loadInspectionContext(),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        final data = snapshot.data!;
        return _buildInspectionForm(context, data);
      },
    ),
  );

  Widget _buildInspectionForm(
    BuildContext context,
    Map<String, dynamic> contextData,
  ) {
    final serviceId = contextData['serviceId']?.toString() ?? '';
    final conditionOptions = _conditionOptionsFor(serviceId);
    final observationOptions = _observationOptionsFor(serviceId);
    final actionOptions = _actionOptionsFor(serviceId);
    final versionId =
        contextData['inspectionTemplateVersionId']?.toString() ?? 'default_v1';
    final version =
        (contextData['inspectionTemplateVersion'] as num?)?.toInt() ?? 1;
    final allTemplates = Map<String, dynamic>.from(
      contextData['templates'] as Map? ?? const {},
    );
    final serviceTemplate = Map<String, dynamic>.from(
      allTemplates[serviceId] as Map? ?? const {},
    );
    final templateId = '${serviceId}_${_issueFound ? 'issueFound' : 'allGood'}';
    final template =
        serviceTemplate[_issueFound ? 'issueFound' : 'allGood']?.toString() ??
        (_issueFound
            ? 'During the {service} inspection, we found: {observations}. Condition: {condition}. Recommended next step: {action}. {priceImpact} {note}'
            : 'Your {service} inspection is complete. The garment is suitable for the selected service. We’ll proceed as requested. {note}');
    final observations = _issueFound
        ? _observationCodes
              .map((code) => _observations[code] ?? code)
              .join(', ')
        : 'No visible issues';
    final note = _optionalNote.text.trim();
    final baseMessage = template
        .replaceAll(
          '{service}',
          contextData['serviceName']?.toString() ?? 'Garment Care',
        )
        .replaceAll('{condition}', _conditions[_conditionCode] ?? 'Good')
        .replaceAll('{observations}', observations)
        .replaceAll('{action}', _actions[_actionCode] ?? 'Proceed as requested')
        .replaceAll(
          '{priceImpact}',
          _priceImpactCode == 'revised_quote_required'
              ? 'A revised quote is included for your approval.'
              : 'There is no additional charge.',
        )
        .replaceAll('{note}', note.isEmpty ? '' : 'Additional note: $note')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final fee = double.tryParse(_additionalFee.text.trim()) ?? 0;
    final serviceRate = (contextData['serviceRate'] as num?)?.toDouble() ?? 0;
    final canSubmit =
        !widget.busy &&
        !_capturingPhoto &&
        (!_issueFound || _observationCodes.isNotEmpty) &&
        (_priceImpactCode != 'revised_quote_required' || fee > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text('Quick inspection', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _inspectionChoice(
                label: 'All Good',
                subtitle: 'No visible issues',
                selected: !_issueFound,
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF13A45A),
                onTap: () => setState(() {
                  _issueFound = false;
                  _conditionCode = 'good';
                  _actionCode = 'proceed_as_requested';
                  _priceImpactCode = 'no_additional_charge';
                  _observationCodes.clear();
                  _additionalFee.clear();
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _inspectionChoice(
                label: 'Issue Found',
                subtitle: 'Record a finding',
                selected: _issueFound,
                icon: Icons.error_outline_rounded,
                iconColor: GarmentCareColors.primary,
                onTap: () => setState(() => _issueFound = true),
              ),
            ),
          ],
        ),
        if (_issueFound) ...[
          const SizedBox(height: 10),
          _inspectionDropdown(
            key: ValueKey<String>('inspection-condition-${widget.jobId}'),
            label: 'Garment condition',
            value: _conditionCode,
            options: conditionOptions,
            onChanged: (value) => setState(() => _conditionCode = value),
          ),
          const SizedBox(height: 8),
          _observationSelector(observationOptions),
          const SizedBox(height: 8),
          _inspectionDropdown(
            key: ValueKey<String>('inspection-action-${widget.jobId}'),
            label: 'Recommended action',
            value: _actionCode,
            options: actionOptions,
            onChanged: (value) => setState(() => _actionCode = value),
          ),
          const SizedBox(height: 8),
          _inspectionDropdown(
            key: ValueKey<String>('inspection-price-impact-${widget.jobId}'),
            label: 'Price impact',
            value: _priceImpactCode,
            options: _priceImpacts,
            onChanged: (value) => setState(() {
              _priceImpactCode = value;
              if (value == 'no_additional_charge') _additionalFee.clear();
            }),
          ),
          if (_priceImpactCode == 'revised_quote_required')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                key: ValueKey<String>(
                  'inspection-additional-fee-${widget.jobId}',
                ),
                controller: _additionalFee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Additional service charge',
                  prefixText: '₹ ',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  key: ValueKey<String>(
                    'inspection-condition-photo-${widget.jobId}',
                  ),
                  onPressed: widget.busy || _capturingPhoto
                      ? null
                      : () => _captureInspectionPhoto(context, contextData),
                  icon: Icon(
                    _evidencePath == null
                        ? Icons.camera_alt_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    _capturingPhoto
                        ? 'Uploading photo…'
                        : _evidencePath == null
                        ? 'Add condition photo (optional)'
                        : 'Condition photo attached',
                  ),
                ),
                const Text(
                  'Optional. Add a photo or describe the finding in the note below.',
                  style: TextStyle(
                    color: GarmentCareColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: ValueKey<String>('inspection-note-${widget.jobId}'),
            controller: _optionalNote,
            maxLines: 2,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Additional note (optional)',
              hintText: 'Only for an unusual detail',
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: GarmentCareColors.selected.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GarmentCareColors.divider),
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Customer message',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Automatic',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(baseMessage, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 8),
              Text(
                'Service rate: ₹${serviceRate.toStringAsFixed(2)}${fee > 0 ? ' · Additional: ₹${fee.toStringAsFixed(2)}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF101010),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: () => _showMessagePreview(context, baseMessage),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Preview / Copy Note'),
          ),
        ),
        const SizedBox(height: 6),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: const Text('Inspection template details'),
          children: [
            Text('Version $version · $serviceId'),
            Text('Template reference: $templateId · $versionId'),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            onPressed: canSubmit
                ? () => widget.onSubmit({
                    'inspectionMode': _issueFound ? 'issueFound' : 'allGood',
                    'conditionCode': _conditionCode,
                    'observationCodes': _issueFound
                        ? _observationCodes.toList(growable: false)
                        : <String>['no_visible_issues'],
                    'recommendedActionCode': _actionCode,
                    'priceImpactCode': _priceImpactCode,
                    'inspectionNotes': observations,
                    'conditionFindings': _conditions[_conditionCode] ?? 'Good',
                    'additionalServiceFee': fee,
                    'additionalServiceReason': _issueFound
                        ? 'Inspection finding: $observations'
                        : '',
                    'customerMessage': baseMessage,
                    'optionalNote': note,
                    'inspectionTemplateId': templateId,
                    'inspectionTemplateVersionId': versionId,
                    'inspectionTemplateVersion': version,
                    'inspectionEvidencePaths': _evidencePath == null
                        ? <String>[]
                        : <String>[_evidencePath!],
                  })
                : null,
            icon: widget.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _issueFound && _priceImpactCode != 'no_additional_charge'
                  ? 'Send for Customer approval'
                  : 'Submit inspection',
            ),
          ),
        ),
      ],
    );
  }

  Widget _inspectionChoice({
    required String label,
    required String subtitle,
    required bool selected,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: widget.busy ? null : onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? GarmentCareColors.selected : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? GarmentCareColors.primary : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );

  Widget _observationSelector(Map<String, String> options) {
    final selectedLabels = options.entries
        .where((entry) => _observationCodes.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);
    final valueText = selectedLabels.isEmpty
        ? 'Choose observations'
        : selectedLabels.length <= 2
        ? selectedLabels.join(', ')
        : '${selectedLabels.length} observations selected';
    return InkWell(
      key: ValueKey<String>('inspection-observations-${widget.jobId}'),
      borderRadius: BorderRadius.circular(14),
      onTap: widget.busy ? null : () => _chooseObservations(options),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Inspection observations',
          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          valueText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedLabels.isEmpty
                ? GarmentCareColors.textHint
                : GarmentCareColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _chooseObservations(Map<String, String> options) async {
    final selected = Set<String>.from(_observationCodes);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What did you notice?',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text('Select all observations that apply.'),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final entry in options.entries)
                          CheckboxListTile(
                            value: selected.contains(entry.key),
                            title: Text(entry.value),
                            contentPadding: EdgeInsets.zero,
                            onChanged: (value) => setSheetState(() {
                              if (value == true) {
                                selected.add(entry.key);
                              } else {
                                selected.remove(entry.key);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _observationCodes
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _showMessagePreview(BuildContext context, String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customer message preview'),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer note copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy note'),
          ),
        ],
      ),
    );
  }

  Widget _inspectionDropdown({
    Key? key,
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: widget.busy
        ? null
        : (next) {
            if (next != null) onChanged(next);
          },
  );

  Future<void> _captureInspectionPhoto(
    BuildContext context,
    Map<String, dynamic> inspectionContext,
  ) async {
    setState(() => _capturingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (image == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) throw StateError('Sign in again before saving a photo.');
      final path =
          'garment_care_evidence/${inspectionContext['orderId']}/inspection/${widget.jobId}/${inspectionContext['garmentId']}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await FirebaseStorage.instance
          .ref(path)
          .putFile(
            File(image.path),
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {'partnerUid': uid, 'jobId': widget.jobId},
            ),
          );
      if (mounted) setState(() => _evidencePath = path);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturingPhoto = false);
    }
  }
}

class _PartnerJobOrderDetails extends StatefulWidget {
  const _PartnerJobOrderDetails({
    required this.jobId,
    required this.accountId,
    required this.profileId,
  });

  final String jobId;
  final String accountId;
  final String profileId;

  @override
  State<_PartnerJobOrderDetails> createState() =>
      _PartnerJobOrderDetailsState();
}

class _PartnerJobOrderDetailsState extends State<_PartnerJobOrderDetails> {
  late Future<Map<String, dynamic>> _details;

  Future<Map<String, dynamic>> _loadDetails() =>
      GarmentCareService.partnerServiceJobDetails(
        jobId: widget.jobId,
        accountId: widget.accountId,
        profileId: widget.profileId,
      );

  @override
  void initState() {
    super.initState();
    _details = _loadDetails();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    title: const Text('Pickup and Customer details'),
    children: [
      FutureBuilder<Map<String, dynamic>>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order details could not be loaded.'),
                TextButton.icon(
                  onPressed: () => setState(() => _details = _loadDetails()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const LinearProgressIndicator();
          }
          final pickupAt = DateTime.tryParse(
            data['pickupAt']?.toString() ?? '',
          );
          final pickupWindow = [
            if (pickupAt != null)
              '${pickupAt.day}/${pickupAt.month}/${pickupAt.year}',
            if ((data['pickupSlot']?.toString() ?? '').isNotEmpty)
              data['pickupSlot'].toString(),
          ].join(' · ');
          final phone = data['customerPhone']?.toString().trim() ?? '';
          final address = data['pickupAddress']?.toString().trim() ?? '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((data['customerName']?.toString() ?? '').isNotEmpty)
                Text('Customer: ${data['customerName']}'),
              if (phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () =>
                      _launchAction(context, Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text('Call $phone'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              if (pickupWindow.isNotEmpty) Text('Pickup: $pickupWindow'),
              if (address.isNotEmpty) ...[
                Text('Pickup address: $address'),
                TextButton.icon(
                  onPressed: () => _launchAction(
                    context,
                    Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query': address,
                    }),
                  ),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Get directions'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ],
          );
        },
      ),
    ],
  );

  Future<void> _launchAction(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This action is unavailable on this device.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This action is unavailable on this device.'),
          ),
        );
      }
    }
  }
}

class _ShipmentAction extends StatefulWidget {
  const _ShipmentAction({
    required this.shipmentId,
    required this.accountId,
    required this.profileId,
    required this.action,
    this.pickupWorkDetails,
  });
  final String shipmentId;
  final String accountId;
  final String profileId;
  final String action;
  final Future<Map<String, dynamic>>? pickupWorkDetails;

  @override
  State<_ShipmentAction> createState() => _ShipmentActionState();
}

class _ShipmentActionState extends State<_ShipmentAction> {
  static const _rejectionReasons = <String, String>{
    'complex_care': 'Too complex for this service',
    'unsafe_condition': 'Condition needs a specialist',
    'service_mismatch': 'Selected service does not suit this garment',
    'service_unavailable': 'This service is unavailable at pickup',
    'garment_not_present': 'Garment was not available',
    'other': 'Other reason',
  };

  bool _working = false;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('garment_care_shipments')
            .doc(widget.shipmentId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          if (data == null) return const SizedBox.shrink();
          final status = data['status']?.toString() ?? '';
          final isCustomerPickup = data['shipmentType'] == 'customer_pickup';
          final ready = widget.action == 'release'
              ? status == 'planned'
              : isCustomerPickup
              ? status == 'assigned'
              : status == 'inTransit';
          if (!ready) return Text('Transfer: ${status.replaceAll('_', ' ')}');
          final garmentIds = (data['garmentIds'] as List<dynamic>? ?? const [])
              .map((id) => id.toString())
              .where((id) => id.isNotEmpty)
              .toList(growable: false);
          final ids = garmentIds.isEmpty
              ? [data['garmentId']?.toString() ?? '']
              : garmentIds;
          final needsEvidence =
              widget.action == 'receive' &&
              data['shipmentType'] == 'customer_pickup';
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working
                  ? null
                  : () => _confirm(context, ids, data, needsEvidence),
              icon: Icon(
                widget.action == 'release'
                    ? Icons.output_rounded
                    : Icons.input_rounded,
              ),
              label: Text(
                needsEvidence
                    ? 'Review pickup · accept or reject garments'
                    : widget.action == 'release'
                    ? 'Verify IDs and release garments'
                    : 'Verify IDs and confirm receipt',
              ),
            ),
          );
        },
      );

  Future<void> _confirm(
    BuildContext context,
    List<String> garmentIds,
    Map<String, dynamic> shipment,
    bool needsEvidence,
  ) async {
    final pickupGarmentsById = <String, Map<String, dynamic>>{};
    if (needsEvidence) {
      try {
        final pickupDetailsFuture = widget.pickupWorkDetails;
        if (pickupDetailsFuture == null) {
          throw StateError('Pickup service details are unavailable.');
        }
        final pickupDetails = await pickupDetailsFuture;
        for (final value
            in (pickupDetails['garments'] as List<dynamic>? ?? const [])) {
          if (value is Map) {
            final garment = Map<String, dynamic>.from(value);
            final id = garment['garmentId']?.toString().trim() ?? '';
            if (id.isNotEmpty) pickupGarmentsById[id] = garment;
          }
        }
        if (garmentIds.any((id) => !pickupGarmentsById.containsKey(id))) {
          throw StateError(
            'Could not match every garment to its booked service group. Refresh pickup details and try again.',
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Bad state: ', '')),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final subOrderNumbers = <String, String>{};
    final rawSubOrderNumbers = shipment['subOrderNumbersByGarmentId'];
    if (rawSubOrderNumbers is Map) {
      rawSubOrderNumbers.forEach((key, value) {
        subOrderNumbers[key.toString()] = value.toString();
      });
    }
    final garmentDisplayNames = <String, String>{};
    final rawGarmentDisplayNames = shipment['garmentDisplayNamesById'];
    if (rawGarmentDisplayNames is Map) {
      rawGarmentDisplayNames.forEach((key, value) {
        garmentDisplayNames[key.toString()] = value.toString();
      });
    }
    final decisions = <String, bool?>{for (final id in garmentIds) id: null};
    final rejectionReasons = <String, String>{};
    final verifiedIds = <String>{};
    String garmentLabel(String id) {
      final displayName =
          pickupGarmentsById[id]?['displayName']?.toString() ??
          garmentDisplayNames[id] ??
          'Garment';
      final subOrderNumber = needsEvidence ? '' : subOrderNumbers[id] ?? '';
      final shortId = id.length > 6 ? id.substring(id.length - 6) : id;
      return subOrderNumber.isNotEmpty
          ? 'Sub-order $subOrderNumber · $displayName · ID $shortId'
          : '$displayName · ID $shortId';
    }

    List<Widget> pickupGroupDetails(String id) {
      final garment = pickupGarmentsById[id];
      if (garment == null) return const [];
      final groupCode = garment['serviceGroupCode']?.toString() ?? '';
      final group = GarmentCareServiceGroup.fromCode(groupCode);
      final prefix = switch (groupCode) {
        'washing_cleaning' => 'L',
        'pressing_finishing' => 'I',
        'special_treatments' => 'S',
        'designer_luxury' => 'D',
        'home_textile' => 'H',
        'shoes_accessories' => 'A',
        _ => 'G',
      };
      final services = (garment['services'] as List<dynamic>? ?? const [])
          .map((service) => service.toString().trim())
          .where((service) => service.isNotEmpty)
          .toList(growable: false);
      final material = garment['material']?.toString().trim() ?? '';
      return [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expected sub-order group: $prefix · ${group?.label ?? 'Service group'}',
                style: const TextStyle(color: GarmentCareColors.textSecondary),
              ),
              if (services.isNotEmpty)
                Text('Booked services: ${services.join(' · ')}'),
              if (material.isNotEmpty) Text('Material: $material'),
            ],
          ),
        ),
      ];
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(needsEvidence ? 'Confirm pickup' : 'Confirm handover'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${shipment['orderNumber']?.toString().trim().isNotEmpty == true ? shipment['orderNumber'] : 'number pending'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  needsEvidence
                      ? 'Check each garment. Choose what you can safely collect; a photo is required for every collected garment.'
                      : 'Visually verify every Garment ID before confirming this handover.',
                ),
                if (needsEvidence) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Each accepted garment gets its own sub-order number after pickup decisions. Garments rejected at pickup are not assigned a service sub-order.',
                  ),
                ],
                for (final garmentId in garmentIds) ...[
                  const SizedBox(height: 12),
                  Text(
                    garmentLabel(garmentId),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (needsEvidence) ...pickupGroupDetails(garmentId),
                  if (needsEvidence) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Accept pickup'),
                          selected: decisions[garmentId] == true,
                          onSelected: (selected) => setDialogState(() {
                            decisions[garmentId] = selected ? true : null;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Reject pickup'),
                          selected: decisions[garmentId] == false,
                          onSelected: (selected) => setDialogState(() {
                            decisions[garmentId] = selected ? false : null;
                            if (!selected) rejectionReasons.remove(garmentId);
                          }),
                        ),
                      ],
                    ),
                    if (decisions[garmentId] == false)
                      DropdownButtonFormField<String>(
                        initialValue:
                            rejectionReasons[garmentId] ?? 'complex_care',
                        decoration: const InputDecoration(labelText: 'Reason'),
                        items: [
                          for (final entry in _rejectionReasons.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(
                              () => rejectionReasons[garmentId] = value,
                            );
                          }
                        },
                      ),
                  ] else
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Garment ID visually verified'),
                      value: verifiedIds.contains(garmentId),
                      onChanged: (selected) => setDialogState(() {
                        if (selected == true) {
                          verifiedIds.add(garmentId);
                        } else {
                          verifiedIds.remove(garmentId);
                        }
                      }),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: needsEvidence
                  ? (decisions.values.every((value) => value != null)
                        ? () => Navigator.pop(dialogContext, true)
                        : null)
                  : (verifiedIds.length == garmentIds.length
                        ? () => Navigator.pop(dialogContext, true)
                        : null),
              child: Text(
                needsEvidence ? 'Confirm pickup' : 'Confirm handover',
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final collectedIds = needsEvidence
        ? garmentIds
              .where((id) => decisions[id] == true)
              .toList(growable: false)
        : garmentIds;
    final rejectedIds = needsEvidence
        ? garmentIds
              .where((id) => decisions[id] == false)
              .toList(growable: false)
        : const <String>[];
    final rejectionCodes = <String, String>{
      for (final id in rejectedIds) id: rejectionReasons[id] ?? 'complex_care',
    };
    setState(() => _working = true);
    final evidence = <String, String>{};
    try {
      if (needsEvidence) {
        final picker = ImagePicker();
        for (final garmentId in collectedIds) {
          final image = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 78,
            maxWidth: 1600,
          );
          if (image == null) {
            throw StateError(
              'Take one condition photo for every garment you collect.',
            );
          }
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (currentUid.isEmpty) {
            throw StateError('Sign in again before recording pickup.');
          }
          final stamp = DateTime.now().microsecondsSinceEpoch;
          final path =
              'garment_care_evidence/${shipment['orderId']}/${widget.shipmentId}/$garmentId/$currentUid/$stamp.jpg';
          await FirebaseStorage.instance
              .ref(path)
              .putFile(
                File(image.path),
                SettableMetadata(
                  contentType: 'image/jpeg',
                  customMetadata: {
                    'partnerUid': currentUid,
                    'orderId': shipment['orderId'].toString(),
                    'shipmentId': widget.shipmentId,
                    'garmentId': garmentId,
                  },
                ),
              );
          evidence[garmentId] = path;
        }
      }
      await GarmentCareService.recordHandover(
        shipmentId: widget.shipmentId,
        accountId: widget.accountId,
        profileId: widget.profileId,
        action: widget.action,
        confirmedGarmentIds: collectedIds,
        rejectedGarmentIds: rejectedIds,
        pickupRejectionReasons: rejectionCodes,
        evidencePhotosByGarmentId: evidence,
      );
      if (context.mounted && needsEvidence) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              collectedIds.isEmpty
                  ? 'Pickup rejected. The Customer can create a new order with a suitable service.'
                  : rejectedIds.isEmpty
                  ? 'Pickup accepted. Eligible service work is ready for inspection.'
                  : '${collectedIds.length} accepted; ${rejectedIds.length} rejected. Rejected garments will not be reassigned.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _CarePartnerAvailabilityCard extends StatefulWidget {
  const _CarePartnerAvailabilityCard({
    required this.accountId,
    required this.profileId,
  });
  final String accountId;
  final String profileId;

  @override
  State<_CarePartnerAvailabilityCard> createState() =>
      _CarePartnerAvailabilityCardState();
}

class _CarePartnerAvailabilityCardState
    extends State<_CarePartnerAvailabilityCard> {
  bool _saving = false;

  DocumentReference<Map<String, dynamic>> get _profileRef => FirebaseFirestore
      .instance
      .collection('accounts')
      .doc(widget.accountId)
      .collection('profiles')
      .doc(widget.profileId);

  Map<String, dynamic> _operational(Map<String, dynamic>? profile) {
    final partner = Map<String, dynamic>.from(
      profile?['partnerData'] as Map? ?? const {},
    );
    final extensions = Map<String, dynamic>.from(
      partner['extensions'] as Map? ?? const {},
    );
    final care = Map<String, dynamic>.from(
      extensions['garmentCare'] as Map? ?? const {},
    );
    return Map<String, dynamic>.from(care['operational'] as Map? ?? const {});
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _profileRef.snapshots(),
    builder: (context, snapshot) {
      final settings = _operational(snapshot.data?.data());
      final available = settings['availableForOrders'] != false;
      final openAt = settings['openAt']?.toString() ?? '09:00';
      final closeAt = settings['closeAt']?.toString() ?? '20:00';
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GarmentCareColors.divider),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Accepting New Orders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Shop hours: ${_formatTime(context, openAt)} – ${_formatTime(context, closeAt)}',
                        style: const TextStyle(
                          color: GarmentCareColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: available
                        ? const Color(0xFFDDF4E6)
                        : const Color(0xFFF1EFF0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    available ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: available
                          ? const Color(0xFF287A45)
                          : GarmentCareColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: available,
                  activeTrackColor: GarmentCareColors.primary,
                  onChanged: _saving
                      ? null
                      : (value) => _save(value, openAt, closeAt),
                ),
              ],
            ),
            const Divider(height: 13),
            Row(
              children: [
                Expanded(
                  child: _timeButton(
                    context,
                    'Opens',
                    openAt,
                    (value) => _save(available, value, closeAt),
                  ),
                ),
                Expanded(
                  child: _timeButton(
                    context,
                    'Closes',
                    closeAt,
                    (value) => _save(available, openAt, value),
                  ),
                ),
              ],
            ),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      );
    },
  );

  Widget _timeButton(
    BuildContext context,
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) => TextButton.icon(
    onPressed: _saving
        ? null
        : () async {
            final parts = value.split(':');
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: int.tryParse(parts.first) ?? (label == 'Opens' ? 9 : 20),
                minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
              ),
            );
            if (picked != null) {
              onChanged(
                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
              );
            }
          },
    icon: const Icon(Icons.schedule_rounded, size: 18),
    label: Text('$label ${_formatTime(context, value)}'),
  );

  String _formatTime(BuildContext context, String value) {
    final parts = value.split(':');
    final time = TimeOfDay(
      hour: parts.isNotEmpty ? int.tryParse(parts.first) ?? 9 : 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    return time.format(context);
  }

  Future<void> _save(bool available, String openAt, String closeAt) async {
    setState(() => _saving = true);
    try {
      await GarmentCareService.updatePartnerPreferences(
        accountId: widget.accountId,
        profileId: widget.profileId,
        availableForOrders: available,
        openAt: openAt,
        closeAt: closeAt,
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not save availability.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save availability.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class GarmentCareDispatchScreen extends StatefulWidget {
  const GarmentCareDispatchScreen({super.key});

  @override
  State<GarmentCareDispatchScreen> createState() =>
      _GarmentCareDispatchScreenState();
}

class _GarmentCareDispatchScreenState extends State<GarmentCareDispatchScreen> {
  List<Map<String, dynamic>>? _partners;
  bool _loadingPartners = false;
  String? _loadError;

  Future<void> _loadPartners() async {
    if (_partners != null || _loadingPartners) return;
    setState(() {
      _loadingPartners = true;
      _loadError = null;
    });
    try {
      _partners = await GarmentCareService.partnerCandidates();
    } on FirebaseFunctionsException catch (error) {
      _loadError = error.message ?? 'Could not load approved Partners.';
    } catch (_) {
      _loadError = 'Could not load approved Partners.';
    }
    if (mounted) setState(() => _loadingPartners = false);
  }

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Garment Care Dispatch')),
      body: StreamBuilder(
        stream: GarmentCareService.dispatchQueue(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load the Garment Care dispatch queue.',
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check Admin access and deploy the current Firestore rules and indexes to the Firebase project used by this app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final jobs = snapshot.data!.docs;
          if (jobs.isEmpty) {
            return const Center(
              child: Text('No unassigned Garment Care jobs.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              final data = job.data();
              return Card(
                child: ListTile(
                  title: Text(
                    GarmentCareServiceCatalog.labelFor(
                      data['serviceId']?.toString() ?? '',
                    ),
                  ),
                  subtitle: Text(
                    'Garment ${data['garmentId'] ?? ''} · Order ${data['orderNumber'] ?? data['orderId'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.person_add_alt_1_rounded),
                  onTap: () => _assign(context, job.id),
                ),
              );
            },
          );
        },
      ),
    ),
  );

  Future<void> _setPriority(
    BuildContext sheetContext,
    Map<String, dynamic> partner,
  ) async {
    final controller = TextEditingController(
      text: (partner['priority'] ?? 0).toString(),
    );
    final priority = await showDialog<int>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Dispatch priority · ${partner['name'] ?? 'Partner'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Priority from 0 to 100',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (priority == null) return;
    try {
      await GarmentCareService.updatePartnerPriority(
        accountId: partner['accountId'].toString(),
        profileId: partner['profileId'].toString(),
        priority: priority,
      );
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      _partners = null;
      await _loadPartners();
    } on FirebaseFunctionsException catch (error) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Could not save priority.')),
        );
      }
    } catch (_) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(content: Text('Could not save priority.')),
        );
      }
    }
  }

  Future<void> _assign(BuildContext context, String jobId) async {
    await _loadPartners();
    if (!context.mounted) return;
    final candidates = _partners ?? const <Map<String, dynamic>>[];
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _loadError ?? 'No approved Garment Care Partners are available.',
          ),
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Assign to a Partner',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final partner in candidates)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(
                  partner['name']?.toString() ?? 'Garment Care Partner',
                ),
                subtitle: Text(
                  [
                    (partner['capabilityCodes'] as List<dynamic>? ?? const [])
                        .map(
                          (code) =>
                              code.toString().replaceFirst('garmentCare.', ''),
                        )
                        .join(' · '),
                    if ((partner['openAt']?.toString() ?? '').isNotEmpty &&
                        (partner['closeAt']?.toString() ?? '').isNotEmpty)
                      'Hours ${partner['openAt']}–${partner['closeAt']}',
                    'Priority ${partner['priority'] ?? 0}',
                  ].where((value) => value.isNotEmpty).join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Set Admin priority',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => _setPriority(context, partner),
                ),
                onTap: () => Navigator.pop(context, partner),
              ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await GarmentCareService.assignJob(
        jobId: jobId,
        partnerAccountId: chosen['accountId'].toString(),
        partnerProfileId: chosen['profileId'].toString(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Service offer sent to ${chosen['name'] ?? 'the Partner'}. They can accept or decline in Garment Care.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not assign this job.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not assign this job.')),
        );
      }
    }
  }
}

class GarmentCarePickupDispatchScreen extends StatefulWidget {
  const GarmentCarePickupDispatchScreen({super.key});

  @override
  State<GarmentCarePickupDispatchScreen> createState() =>
      _GarmentCarePickupDispatchScreenState();
}

class _GarmentCarePickupDispatchScreenState
    extends State<GarmentCarePickupDispatchScreen> {
  List<Map<String, dynamic>>? _partners;
  bool _loadingPartners = false;

  Future<void> _loadPartners() async {
    if (_partners != null || _loadingPartners) return;
    setState(() => _loadingPartners = true);
    try {
      _partners = await GarmentCareService.partnerCandidates();
    } catch (_) {
      _partners = const [];
    }
    if (mounted) setState(() => _loadingPartners = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Garment Care Pickup Routing')),
    body: StreamBuilder(
      stream: GarmentCareService.pickupQueue(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load pickup requests.'),
                  const SizedBox(height: 8),
                  SelectableText(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check Admin access and deploy the current Firestore rules and indexes to the Firebase project used by this app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final shipments = snapshot.data!.docs;
        if (shipments.isEmpty) {
          return const Center(child: Text('No pickup requests need routing.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: shipments.length,
          itemBuilder: (context, index) {
            final shipment = shipments[index];
            final data = shipment.data();
            final address = data['pickupAddressSnapshot'] is Map
                ? Map<String, dynamic>.from(
                    data['pickupAddressSnapshot'] as Map,
                  )
                : const <String, dynamic>{};
            final garments =
                (data['garmentIds'] as List<dynamic>? ?? const []).length;
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(
                  'Order ${data['orderNumber'] ?? data['orderId'] ?? ''} · $garments garments',
                ),
                subtitle: Text(
                  [
                    address['formattedAddress']?.toString() ?? '',
                    'Pickup ${data['pickupSlot'] ?? ''}',
                  ].where((value) => value.isNotEmpty).join('\n'),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Assign pickup partner',
                  onPressed: () => _assign(context, shipment.id),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _assign(BuildContext context, String shipmentId) async {
    await _loadPartners();
    if (!context.mounted) return;
    final partners = _partners ?? const <Map<String, dynamic>>[];
    if (partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No approved Garment Care Partners are available.'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Assign pickup to a Partner',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final partner in partners)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(
                  partner['name']?.toString() ?? 'Garment Care Partner',
                ),
                subtitle: Text(
                  (partner['capabilityCodes'] as List<dynamic>? ?? const [])
                      .map(
                        (code) =>
                            code.toString().replaceFirst('garmentCare.', ''),
                      )
                      .join(' · '),
                ),
                onTap: () => Navigator.pop(context, partner),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await GarmentCareService.assignPickup(
        shipmentId: shipmentId,
        partnerAccountId: selected['accountId'].toString(),
        partnerProfileId: selected['profileId'].toString(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pickup assigned to ${selected['name'] ?? 'the Partner'}. It appears under Pickup & transfers.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Could not assign this pickup.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not assign this pickup.')),
        );
      }
    }
  }
}

class GarmentCareCustodyScreen extends StatelessWidget {
  const GarmentCareCustodyScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    this.pickupOnly = false,
    this.customerDeliveryOnly = false,
    this.readyDeliveryOnly = false,
    this.paymentPendingOnly = false,
    this.deliveryPartnerOnly = false,
    this.focusOrderId = '',
    this.focusOrderNumber = '',
    this.focusDeliveryGroupId = '',
    this.focusSubOrderNumber = '',
    this.focusShipmentId = '',
  });

  final String accountId;
  final String profileId;
  final bool pickupOnly;
  final bool customerDeliveryOnly;
  final bool readyDeliveryOnly;
  final bool paymentPendingOnly;
  final bool deliveryPartnerOnly;
  final String focusOrderId;
  final String focusOrderNumber;
  final String focusDeliveryGroupId;
  final String focusSubOrderNumber;
  final String focusShipmentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GarmentCareColors.background,
    appBar: AppBar(
      title: Text(
        pickupOnly
            ? 'Pickup requests'
            : deliveryPartnerOnly
            ? 'Garment Care returns'
            : paymentPendingOnly
            ? 'Payment pending garments'
            : readyDeliveryOnly
            ? 'Ready for delivery'
            : focusOrderId.isNotEmpty
            ? 'Payment & handover'
            : 'Pickup & transfers',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          paymentPendingOnly
              ? 'Review each completed garment sub-order awaiting customer payment. Delivery becomes available after its invoice is paid.'
              : deliveryPartnerOnly
              ? 'Accept or decline assigned returns, confirm garment handover, start customer delivery and verify the Customer PIN.'
              : readyDeliveryOnly
              ? 'These paid garment sub-orders are ready to hand over to the Customer.'
              : focusOrderId.isNotEmpty
              ? 'Review the payment or delivery task for this garment sub-order.'
              : pickupOnly
              ? 'Review the garments in each pickup request. Accept the garments you can safely handle, or reject them with a reason.'
              : 'Review each pickup, Partner transfer or Customer delivery here. Customer delivery is available only after every final invoice is paid.',
        ),
        if (focusOrderNumber.isNotEmpty || focusSubOrderNumber.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (focusOrderNumber.isNotEmpty) 'Order $focusOrderNumber',
              if (focusSubOrderNumber.isNotEmpty)
                'Sub-order $focusSubOrderNumber',
            ].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 12),
        if (deliveryPartnerOnly)
          _ShipmentStreamSection(
            title: 'Today’s Garment Care deliveries',
            stream: GarmentCareService.deliveryPartnerShipments(
              accountId: accountId,
              profileId: profileId,
            ),
            accountId: accountId,
            profileId: profileId,
            incoming: false,
            deliveryPartnerOnly: true,
          )
        else if (!customerDeliveryOnly &&
            !readyDeliveryOnly &&
            !paymentPendingOnly &&
            focusOrderId.isEmpty)
          _ShipmentStreamSection(
            title: deliveryPartnerOnly
                ? 'Assigned Customer returns'
                : 'Customer pickups and incoming Partner transfers',
            stream: GarmentCareService.partnerIncomingShipments(
              accountId: accountId,
              profileId: profileId,
            ),
            accountId: accountId,
            profileId: profileId,
            incoming: true,
            pickupOnly: pickupOnly,
            deliveryPartnerOnly: deliveryPartnerOnly,
            focusOrderId: focusOrderId,
            focusOrderNumber: focusOrderNumber,
            focusDeliveryGroupId: focusDeliveryGroupId,
            focusSubOrderNumber: focusSubOrderNumber,
            focusShipmentId: focusShipmentId,
          ),
        if (!deliveryPartnerOnly && !pickupOnly) ...[
          const SizedBox(height: 16),
          _ShipmentStreamSection(
            title: paymentPendingOnly
                ? 'Garment sub-orders awaiting customer payment'
                : readyDeliveryOnly
                ? 'Ready for customer delivery'
                : 'Handover tasks and payment holds',
            stream: GarmentCareService.partnerOutgoingShipments(
              accountId: accountId,
              profileId: profileId,
            ),
            accountId: accountId,
            profileId: profileId,
            incoming: false,
            deliveryPartnerOnly: deliveryPartnerOnly,
            customerDeliveryOnly: customerDeliveryOnly,
            readyDeliveryOnly: readyDeliveryOnly,
            paymentPendingOnly: paymentPendingOnly,
            focusOrderId: focusOrderId,
            focusOrderNumber: focusOrderNumber,
            focusDeliveryGroupId: focusDeliveryGroupId,
            focusSubOrderNumber: focusSubOrderNumber,
            focusShipmentId: focusShipmentId,
          ),
        ],
      ],
    ),
  );
}

class _ShipmentStreamSection extends StatelessWidget {
  const _ShipmentStreamSection({
    required this.title,
    required this.stream,
    required this.accountId,
    required this.profileId,
    required this.incoming,
    this.pickupOnly = false,
    this.customerDeliveryOnly = false,
    this.readyDeliveryOnly = false,
    this.paymentPendingOnly = false,
    this.deliveryPartnerOnly = false,
    this.focusOrderId = '',
    this.focusOrderNumber = '',
    this.focusDeliveryGroupId = '',
    this.focusSubOrderNumber = '',
    this.focusShipmentId = '',
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String accountId;
  final String profileId;
  final bool incoming;
  final bool pickupOnly;
  final bool customerDeliveryOnly;
  final bool readyDeliveryOnly;
  final bool paymentPendingOnly;
  final bool deliveryPartnerOnly;
  final String focusOrderId;
  final String focusOrderNumber;
  final String focusDeliveryGroupId;
  final String focusSubOrderNumber;
  final String focusShipmentId;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Could not load shipments. ${_careLoadError(snapshot.error)}',
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final shipments = snapshot.data!.docs
              .where((shipment) {
                final record = shipment.data();
                if (focusOrderId.isNotEmpty &&
                    record['orderId']?.toString() != focusOrderId) {
                  return false;
                }
                if (focusDeliveryGroupId.isNotEmpty &&
                    record['deliveryGroupId']?.toString() !=
                        focusDeliveryGroupId) {
                  return false;
                }
                if (focusShipmentId.isNotEmpty &&
                    shipment.id != focusShipmentId) {
                  return false;
                }
                if (deliveryPartnerOnly) {
                  return record['shipmentType'] == 'customer_return' &&
                      record['deliveryPartnerType'] == 'deliveryPartner' &&
                      record['deliveryPartnerAccountId'] == accountId &&
                      record['deliveryPartnerProfileId'] == profileId &&
                      ['planned', 'inTransit'].contains(record['status']);
                }
                if (incoming) {
                  return (!pickupOnly ||
                          record['shipmentType'] == 'customer_pickup') &&
                      _isPartnerIncomingHandover(record);
                }
                return paymentPendingOnly
                    ? _isPartnerPaymentPending(record)
                    : readyDeliveryOnly
                    ? _isPartnerReadyDelivery(record)
                    : customerDeliveryOnly
                    ? _isPartnerCustomerDeliveryPinTask(record)
                    : _isPartnerOutgoingAction(record);
              })
              .toList(growable: false);
          if (shipments.isEmpty) {
            final pickupWasReceived =
                incoming &&
                snapshot.data!.docs.any((shipment) {
                  final record = shipment.data();
                  return record['shipmentType'] == 'customer_pickup' &&
                      record['status'] == 'delivered';
                });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  focusOrderNumber.isNotEmpty
                      ? 'No payment or handover task is ready for Order $focusOrderNumber${focusSubOrderNumber.isEmpty ? '' : ' · Sub-order $focusSubOrderNumber'}. If this garment’s services are complete, refresh shortly; otherwise continue the remaining service step.'
                      : paymentPendingOnly
                      ? 'No garment sub-orders are waiting for customer payment right now.'
                      : readyDeliveryOnly
                      ? 'No paid garment sub-orders are ready for delivery right now.'
                      : pickupOnly
                      ? 'No pickup requests need action right now.'
                      : deliveryPartnerOnly
                      ? 'No Garment Care delivery assignments need action right now.'
                      : pickupWasReceived
                      ? 'Pickup is confirmed. Any service work assigned to this shop is ready in Today’s Work.'
                      : incoming
                      ? 'No incoming handover needs confirmation.'
                      : 'No outgoing handover needs confirmation.',
                ),
                if (pickupWasReceived && !pickupOnly)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Today’s Work'),
                  ),
              ],
            );
          }
          final grouped =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
          for (final shipment in shipments) {
            final record = shipment.data();
            final otherPartner = incoming
                ? record['fromPartnerAccountId']?.toString() ?? ''
                : record['toPartnerAccountId']?.toString() ?? '';
            final key = [
              record['orderNumber'] ?? record['orderId'] ?? '',
              record['shipmentType'] ?? '',
              record['status'] ?? '',
              record['deliveryMode'] ?? '',
              otherPartner,
            ].join('|');
            grouped
                .putIfAbsent(
                  key,
                  () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                )
                .add(shipment);
          }
          return Column(
            children: [
              for (final transferGroup in grouped.values)
                if (transferGroup.length == 1)
                  _CustodyShipmentCard(
                    key: ValueKey(
                      '${incoming ? 'in' : 'out'}_${transferGroup.first.id}',
                    ),
                    shipmentId: transferGroup.first.id,
                    data: transferGroup.first.data(),
                    accountId: accountId,
                    profileId: profileId,
                    incoming: incoming,
                    deliveryPartnerOnly: deliveryPartnerOnly,
                  )
                else
                  _GroupedCustodyTransferCard(
                    key: ValueKey(
                      '${incoming ? 'in' : 'out'}_${transferGroup.first.id}_group',
                    ),
                    shipments: transferGroup,
                    accountId: accountId,
                    profileId: profileId,
                    incoming: incoming,
                    deliveryPartnerOnly: deliveryPartnerOnly,
                  ),
            ],
          );
        },
      ),
    ],
  );
}

class _GroupedCustodyTransferCard extends StatelessWidget {
  const _GroupedCustodyTransferCard({
    super.key,
    required this.shipments,
    required this.accountId,
    required this.profileId,
    required this.incoming,
    this.deliveryPartnerOnly = false,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> shipments;
  final String accountId;
  final String profileId;
  final bool incoming;
  final bool deliveryPartnerOnly;

  @override
  Widget build(BuildContext context) {
    final first = shipments.first.data();
    final order = _shortOrderLabel(first['orderNumber'], first['orderId']);
    final hasPartnerRecipient =
        first['deliveryMode'] == 'other_partner' &&
        (first['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
    final transferType = first['shipmentType'] == 'customer_pickup'
        ? 'Customer pickup'
        : hasPartnerRecipient
        ? 'Partner transfer'
        : 'Customer delivery';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GarmentCareColors.divider),
      ),
      child: ExpansionTile(
        title: Text(
          '$transferType · $order',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${shipments.length} garment transfers · review each custody record',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: [
          for (final shipment in shipments)
            _CustodyShipmentCard(
              key: ValueKey('grouped_${shipment.id}'),
              shipmentId: shipment.id,
              data: shipment.data(),
              accountId: accountId,
              profileId: profileId,
              incoming: incoming,
              deliveryPartnerOnly: deliveryPartnerOnly,
            ),
        ],
      ),
    );
  }
}

class _CustodyShipmentCard extends StatefulWidget {
  const _CustodyShipmentCard({
    super.key,
    required this.shipmentId,
    required this.data,
    required this.accountId,
    required this.profileId,
    required this.incoming,
    this.deliveryPartnerOnly = false,
  });

  final String shipmentId;
  final Map<String, dynamic> data;
  final String accountId;
  final String profileId;
  final bool incoming;
  final bool deliveryPartnerOnly;

  @override
  State<_CustodyShipmentCard> createState() => _CustodyShipmentCardState();
}

bool _isPartnerIncomingHandover(Map<String, dynamic> data) {
  final status = data['status']?.toString();
  final type = data['shipmentType']?.toString();
  if (type == 'customer_pickup') return status == 'assigned';
  if (type == 'customer_return') {
    return (status == 'planned' || status == 'inTransit') &&
        data['deliveryMode'] == 'other_partner' &&
        (data['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
  }
  return status == 'inTransit';
}

bool _isPartnerOutgoingAction(Map<String, dynamic> data) {
  final type = data['shipmentType']?.toString();
  final status = data['status']?.toString();
  if (type == 'customer_pickup') return false;
  return status == 'planned' ||
      (type == 'customer_return' &&
          status == 'inTransit' &&
          !_isPartnerIncomingHandover(data));
}

bool _isPartnerServiceOrderDelivered(
  Map<String, dynamic> job,
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> shipments,
) {
  if (job['status'] != 'completed') return false;
  final orderId = job['orderId']?.toString().trim() ?? '';
  final deliveryGroupId = job['deliveryGroupId']?.toString().trim() ?? '';
  if (orderId.isEmpty || deliveryGroupId.isEmpty) return false;
  final returns = shipments
      .where((shipment) {
        final data = shipment.data();
        return data['orderId']?.toString() == orderId &&
            data['deliveryGroupId']?.toString() == deliveryGroupId &&
            data['shipmentType'] == 'customer_return' &&
            data['deliveryMode'] != 'other_partner';
      })
      .toList(growable: false);
  return returns.isNotEmpty &&
      returns.every((shipment) => shipment.data()['status'] == 'delivered');
}

bool _isPartnerPaymentPending(Map<String, dynamic> data) =>
    data['shipmentType'] == 'customer_return' &&
    data['deliveryMode'] != 'other_partner' &&
    data['status'] == 'planned' &&
    data['careComplete'] == true &&
    [
      'requiresCustomerAction',
      'partiallyPaid',
    ].contains(data['paymentStatusAtDelivery']);

bool _isPartnerReadyDelivery(Map<String, dynamic> data) =>
    data['shipmentType'] == 'customer_return' &&
    data['deliveryMode'] != 'other_partner' &&
    data['status'] == 'planned' &&
    data['careComplete'] == true &&
    (data['paymentStatusAtDelivery'] == 'paid' ||
        (data['returnOnly'] == true &&
            data['paymentStatusAtDelivery'] == 'not_due'));

bool _isPartnerOutgoingReady(Map<String, dynamic> data) {
  if (!_isPartnerOutgoingAction(data)) return false;
  if (data['shipmentType'] == 'customer_return' &&
      data['deliveryMode'] != 'other_partner' &&
      data['status'] == 'planned' &&
      (data['careComplete'] != true ||
          (data['paymentStatusAtDelivery'] != 'paid' &&
              !(data['returnOnly'] == true &&
                  data['paymentStatusAtDelivery'] == 'not_due')))) {
    return false;
  }
  return true;
}

bool _isPartnerCustomerDeliveryPinTask(Map<String, dynamic> data) =>
    data['shipmentType'] == 'customer_return' &&
    data['status'] == 'inTransit' &&
    !(data['deliveryMode'] == 'other_partner' &&
        (data['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false));

const Map<String, String> _deliveryAssignmentDeclineReasons = {
  'not_available': 'Not available for this delivery',
  'outside_service_area': 'Outside my service area',
  'capacity_full': 'No delivery capacity right now',
  'vehicle_issue': 'Vehicle or transport issue',
  'other': 'Other reason',
};

String _deliveryAssignmentDeclineReasonLabel(String? code) =>
    _deliveryAssignmentDeclineReasons[code] ?? 'Other reason';

String _shipmentStatusLabel(Map<String, dynamic> data) {
  final type = data['shipmentType']?.toString() ?? 'shipment';
  final status = data['status']?.toString() ?? 'unknown';
  if (type == 'customer_pickup') {
    return status == 'assigned'
        ? 'Customer pickup · action needed'
        : 'Pickup received';
  }
  if (type == 'customer_return') {
    if (data['deliveryPartnerType'] == 'deliveryPartner') {
      final decision = data['deliveryPartnerAcceptanceStatus']?.toString();
      final isTransfer =
          data['deliveryMode'] == 'other_partner' &&
          (data['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
      if (decision == 'pending' && status == 'planned') {
        return 'Delivery assignment · action needed';
      }
      if (decision == 'accepted' && status == 'planned' && isTransfer) {
        return 'Accepted · waiting for Partner handover';
      }
      if (status == 'inTransit' && isTransfer) {
        return 'Partner transfer · on the way to you';
      }
      if (status == 'planned' &&
          data['receivedByAccountId'] == data['deliveryPartnerAccountId'] &&
          data['receivedByProfileId'] == data['deliveryPartnerProfileId']) {
        return 'Ready for customer delivery';
      }
      if (status == 'inTransit') return 'Out for delivery · PIN required';
      if (status == 'delivered') return 'Delivered to Customer';
    }
    final partnerTransfer =
        data['deliveryMode'] == 'other_partner' &&
        (data['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
    if (partnerTransfer && status == 'inTransit') {
      return 'Incoming transfer · confirm receipt';
    }
    if (partnerTransfer && status == 'planned') {
      return 'Ready for Partner handover';
    }
    if (!partnerTransfer &&
        status == 'planned' &&
        data['careComplete'] != true) {
      return 'Care in progress · no payment action yet';
    }
    if (!partnerTransfer && _isPartnerPaymentPending(data)) {
      return 'Waiting for Customer payment';
    }
    if (!partnerTransfer &&
        status == 'planned' &&
        !(data['invoiceId']?.toString().trim().isNotEmpty ?? false)) {
      return 'Invoice not ready · no payment action yet';
    }
    if (status == 'planned') {
      return 'Ready for Customer delivery';
    }
    if (status == 'inTransit') {
      return 'Out for delivery · PIN required';
    }
    if (status == 'delivered') {
      return 'Delivered to Customer';
    }
  }
  if (status == 'inTransit') {
    return 'Incoming transfer · confirm receipt';
  }
  if (status == 'planned') {
    return 'Ready for Partner handover';
  }
  return '${type.replaceAll('_', ' ')} · ${status.replaceAll('_', ' ')}';
}

String _shortOrderLabel(dynamic orderNumber, dynamic orderId) {
  final raw = orderNumber?.toString().trim().isNotEmpty == true
      ? orderNumber.toString().trim()
      : orderId?.toString().trim() ?? '';
  if (raw.isEmpty) return 'Order';
  final short = raw.length > 14 ? raw.substring(0, 11) : raw;
  return 'Order ${short.toUpperCase()}';
}

class _CustodyShipmentCardState extends State<_CustodyShipmentCard> {
  final Set<String> _verifiedIds = {};
  bool _saving = false;
  late final Future<Map<String, dynamic>> _pickupWorkDetails;

  @override
  void initState() {
    super.initState();
    _pickupWorkDetails = widget.data['shipmentType'] == 'customer_pickup'
        ? GarmentCareService.partnerPickupWorkDetails(
            shipmentId: widget.shipmentId,
            accountId: widget.accountId,
            profileId: widget.profileId,
          )
        : Future<Map<String, dynamic>>.value(const <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ids = (data['garmentIds'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final subOrderNumbersByGarmentId = data['subOrderNumbersByGarmentId'] is Map
        ? Map<String, dynamic>.from(data['subOrderNumbersByGarmentId'] as Map)
        : const <String, dynamic>{};
    final declinedReturnIds = Set<String>.from(
      (data['returnIncludesCustomerDeclinedGarmentIds'] as List<dynamic>? ??
              const [])
          .map((id) => id.toString()),
    );
    final type = data['shipmentType']?.toString() ?? 'shipment';
    final status = data['status']?.toString() ?? 'unknown';
    final pickup = type == 'customer_pickup';
    final deliveryPartnerAccountId =
        data['deliveryPartnerAccountId']?.toString() ??
        data['fromPartnerAccountId']?.toString() ??
        '';
    final deliveryPartnerProfileId =
        data['deliveryPartnerProfileId']?.toString() ??
        data['fromPartnerProfileId']?.toString() ??
        '';
    final deliveryAssignedToThisPartner =
        deliveryPartnerAccountId == widget.accountId &&
        deliveryPartnerProfileId == widget.profileId;
    final isPartnerToPartnerTransfer =
        type == 'customer_return' &&
        data['deliveryMode'] == 'other_partner' &&
        (data['toPartnerAccountId']?.toString().trim().isNotEmpty ?? false);
    final isFinalCustomerDelivery =
        type == 'customer_return' && !isPartnerToPartnerTransfer;
    final deliveryPartnerAcceptanceStatus =
        data['deliveryPartnerAcceptanceStatus']?.toString() ?? 'pending';
    final needsDeliveryAssignmentResponse =
        widget.deliveryPartnerOnly &&
        type == 'customer_return' &&
        status == 'planned' &&
        deliveryPartnerAcceptanceStatus == 'pending';
    final acceptedPartnerAwaitingTransfer =
        widget.deliveryPartnerOnly &&
        type == 'customer_return' &&
        status == 'planned' &&
        deliveryPartnerAcceptanceStatus == 'accepted' &&
        data['receivedByAccountId'] != widget.accountId;
    final canConfirmCustomerDelivery =
        !widget.incoming &&
        isFinalCustomerDelivery &&
        status == 'inTransit' &&
        deliveryAssignedToThisPartner;
    final needsPickupAcceptance =
        widget.incoming && pickup && status == 'assigned';
    final canReceive = widget.deliveryPartnerOnly
        ? type == 'customer_return' &&
              status == 'inTransit' &&
              data['deliveryMode'] == 'other_partner' &&
              data['toPartnerAccountId'] == widget.accountId &&
              data['toPartnerProfileId'] == widget.profileId
        : widget.incoming && !pickup && status == 'inTransit';
    final canRelease = widget.deliveryPartnerOnly
        ? !pickup &&
              status == 'planned' &&
              data['receivedByAccountId'] == widget.accountId &&
              data['receivedByProfileId'] == widget.profileId &&
              deliveryAssignedToThisPartner &&
              isFinalCustomerDelivery &&
              data['careComplete'] == true &&
              (data['paymentStatusAtDelivery'] == 'paid' ||
                  (data['returnOnly'] == true &&
                      data['paymentStatusAtDelivery'] == 'not_due'))
        : !widget.incoming &&
              !pickup &&
              status == 'planned' &&
              (!isFinalCustomerDelivery ||
                  (data['careComplete'] == true &&
                      data['paymentStatusAtDelivery'] == 'paid')) &&
              !(isPartnerToPartnerTransfer &&
                  data['deliveryPartnerType'] == 'deliveryPartner' &&
                  deliveryPartnerAcceptanceStatus != 'accepted');
    final action = canReceive ? 'receive' : 'release';
    final ready = canReceive || canRelease;
    final address = data['pickupAddressSnapshot'] is Map
        ? Map<String, dynamic>.from(data['pickupAddressSnapshot'] as Map)
        : const <String, dynamic>{};
    final addressLabel =
        (address['formattedAddress']?.toString().trim().isNotEmpty ?? false)
        ? address['formattedAddress'].toString().trim()
        : [
                address['addressLine1'],
                address['addressLine2'],
                address['landmark'],
                address['city'],
                address['state'],
                address['pincode'],
              ]
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .join(', ');
    final phone = address['mobileNumber']?.toString().trim() ?? '';
    final orderId = data['orderId']?.toString() ?? '';
    final subOrderNumber =
        data['subOrderNumber']?.toString().trim().isNotEmpty == true
        ? data['subOrderNumber'].toString().trim()
        : ids.length == 1 && data['subOrderNumbersByGarmentId'] is Map
        ? (data['subOrderNumbersByGarmentId'] as Map)[ids.first]?.toString() ??
              ''
        : '';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: GarmentCareColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _shipmentStatusLabel(data),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${_shortOrderLabel(data['orderNumber'], data['orderId'])}${subOrderNumber.isEmpty ? '' : ' · Sub-order $subOrderNumber'} · ${ids.length} garment${ids.length == 1 ? '' : 's'}',
              style: const TextStyle(color: GarmentCareColors.textSecondary),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 6),
              title: const Text('Transfer details'),
              children: [
                if (orderId.isNotEmpty) SelectableText('Order ID: $orderId'),
                SelectableText('Shipment ID: ${widget.shipmentId}'),
              ],
            ),
            if (pickup)
              Text(
                'Pickup window: ${_pickupScheduleLabel(data['preferredPickupAt'], data['pickupSlot'])}',
              ),
            if (pickup && address.isNotEmpty) ...[
              const SizedBox(height: 6),
              if ((address['name']?.toString().trim() ?? '').isNotEmpty)
                Text('Customer: ${address['name']}'),
              if (phone.isNotEmpty) Text('Phone: $phone'),
              if (addressLabel.isNotEmpty)
                Text('Pickup address: $addressLabel'),
              if (phone.isNotEmpty || addressLabel.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    if (phone.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _openExternalUri(
                          context,
                          Uri(scheme: 'tel', path: phone),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Call'),
                      ),
                    if (addressLabel.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _openExternalUri(
                          context,
                          Uri.https('www.google.com', '/maps/search/', {
                            'api': '1',
                            'query': addressLabel,
                          }),
                        ),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Directions'),
                      ),
                  ],
                ),
            ],
            if (pickup) _pickupServices(),
            if (type == 'customer_return' &&
                !widget.incoming &&
                status == 'planned') ...[
              Text(
                'Delivery partner: ${data['deliveryPartnerName'] ?? data['fromPartnerName'] ?? 'This service Partner'}${(data['deliveryPartnerContactPhone']?.toString() ?? '').isEmpty ? '' : ' · ${data['deliveryPartnerContactPhone']}'}',
              ),
              if (isFinalCustomerDelivery &&
                  (data['careComplete'] != true ||
                      data['paymentStatusAtDelivery'] != 'paid'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GarmentCareColors.primary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['careComplete'] != true
                              ? 'CARE IN PROGRESS'
                              : _isPartnerPaymentPending(data)
                              ? 'CUSTOMER ACTION REQUIRED · PAYMENT PENDING'
                              : 'INVOICE NOT READY · NO PAYMENT ACTION',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          data['careComplete'] != true
                              ? 'Complete this garment sub-order’s service steps before delivery.'
                              : _isPartnerPaymentPending(data)
                              ? 'The final invoice must be paid in the app before you can dispatch this garment sub-order.'
                              : 'Do not ask the Customer to pay or dispatch this garment until its invoice is issued.',
                        ),
                      ],
                    ),
                  ),
                ),
              if (isFinalCustomerDelivery &&
                  data['careComplete'] == true &&
                  data['paymentStatusAtDelivery'] == 'paid')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Payment is complete. Verify the garment IDs, then start delivery to the Customer.',
                  ),
                ),
              if (!isPartnerToPartnerTransfer)
                const Text(
                  'This Partner is assigned to return the garments to the Customer.',
                ),
              if (isPartnerToPartnerTransfer &&
                  data['deliveryPartnerType'] == 'deliveryPartner')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    deliveryPartnerAcceptanceStatus == 'accepted'
                        ? 'The Delivery Partner accepted. Release the garments only after they are ready for handover.'
                        : 'Waiting for the Delivery Partner to accept this assignment before handover.',
                  ),
                ),
              if (!widget.deliveryPartnerOnly &&
                  (data['deliveryPartnerDeclinedReason']
                          ?.toString()
                          .isNotEmpty ??
                      false))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Delivery Partner declined: ${_deliveryAssignmentDeclineReasonLabel(data['deliveryPartnerDeclinedReason']?.toString())}. Choose another Delivery Partner or return the garments from this Partner.',
                    style: const TextStyle(color: GarmentCareColors.primary),
                  ),
                ),
              if (data['deliveryMode'] == 'service_partner' &&
                  data['careComplete'] == true &&
                  (data['paymentStatusAtDelivery'] == 'paid' ||
                      (data['returnOnly'] == true &&
                          data['paymentStatusAtDelivery'] == 'not_due')))
                OutlinedButton.icon(
                  onPressed: _saving ? null : _assignOtherDeliveryPartner,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Choose another delivery Partner'),
                ),
            ],
            if (needsDeliveryAssignmentResponse) ...[
              const SizedBox(height: 10),
              const Text(
                'Accept this Customer delivery assignment, or decline it with a reason. The Garment Care Partner will then choose another delivery Partner or handle the return.',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _respondToDeliveryAssignment('accept'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Accept delivery'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _respondToDeliveryAssignment('reject'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ] else if (acceptedPartnerAwaitingTransfer) ...[
              const SizedBox(height: 8),
              const Text(
                'You accepted this delivery. It will move to your delivery steps after the Garment Care Partner hands over the garments.',
              ),
            ],
            if (needsPickupAcceptance) ...[
              const SizedBox(height: 8),
              const Text(
                'Choose which garments you accept. Add a reason for any rejection; condition photos are required only for accepted garments.',
              ),
              const SizedBox(height: 8),
              _ShipmentAction(
                shipmentId: widget.shipmentId,
                accountId: widget.accountId,
                profileId: widget.profileId,
                action: 'receive',
                pickupWorkDetails: _pickupWorkDetails,
              ),
            ] else if (ready) ...[
              const SizedBox(height: 8),
              Text(
                isFinalCustomerDelivery && status == 'planned'
                    ? 'Confirm each garment is present before delivery:'
                    : 'Confirm each garment is present:',
              ),
              if (pickup && canReceive)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Take one condition photo for each garment to record pickup.',
                  ),
                ),
              for (var index = 0; index < ids.length; index++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _verifiedIds.contains(ids[index]),
                  title: Text(
                    'Garment ${index + 1}${declinedReturnIds.contains(ids[index]) ? ' · customer declined' : ''}',
                  ),
                  subtitle: Text(
                    [
                      if ((subOrderNumbersByGarmentId[ids[index]]
                                  ?.toString()
                                  .trim() ??
                              '')
                          .isNotEmpty)
                        'Sub-order ${subOrderNumbersByGarmentId[ids[index]]}',
                      'Reference · ${ids[index].length > 6 ? ids[index].substring(ids[index].length - 6) : ids[index]}',
                      if (declinedReturnIds.contains(ids[index]))
                        'not billed · return with paid garment',
                    ].join(' · '),
                  ),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      _verifiedIds.add(ids[index]);
                    } else {
                      _verifiedIds.remove(ids[index]);
                    }
                  }),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Show full garment IDs'),
                children: [for (final id in ids) SelectableText(id)],
              ),
              FilledButton.icon(
                onPressed:
                    _saving || ids.isEmpty || _verifiedIds.length != ids.length
                    ? null
                    : () => _confirm(action, ids),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        canReceive ? Icons.input_rounded : Icons.output_rounded,
                      ),
                label: Text(
                  canReceive
                      ? type == 'customer_return'
                            ? 'Confirm receipt'
                            : 'Confirm pickup'
                      : isFinalCustomerDelivery
                      ? 'Hand Over'
                      : isPartnerToPartnerTransfer
                      ? 'Hand over to delivery Partner'
                      : 'Confirm handover',
                ),
              ),
            ] else if (type == 'customer_return' &&
                !widget.incoming &&
                isFinalCustomerDelivery &&
                status == 'planned' &&
                (data['careComplete'] != true ||
                    data['paymentStatusAtDelivery'] != 'paid'))
              const SizedBox.shrink()
            else if (canConfirmCustomerDelivery) ...[
              const Text(
                'Ask the Customer for the last four digits of their registered phone number. The app will verify this garment’s care and invoice before completing delivery.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _confirmCustomerDelivery,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: const Text('Confirm handover'),
                ),
              ),
            ] else if (type == 'customer_return' &&
                isPartnerToPartnerTransfer &&
                status == 'inTransit')
              const Text('This transfer is on its way to the delivery Partner.')
            else
              Text('Individual garment custody status: $status'),
          ],
        ),
      ),
    );
  }

  Future<void> _openExternalUri(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This action is unavailable on this device.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This action is unavailable on this device.'),
          ),
        );
      }
    }
  }

  Widget _pickupServices() => FutureBuilder<Map<String, dynamic>>(
    future: _pickupWorkDetails,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Booked services could not be loaded: ${_careLoadError(snapshot.error)}',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(),
        );
      }
      final garments =
          (snapshot.data?['garments'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((garment) => Map<String, dynamic>.from(garment))
              .toList(growable: false);
      if (garments.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('No service details were found for this pickup.'),
        );
      }
      final groupedGarments = <String, Map<String, dynamic>>{};
      for (final garment in garments) {
        final displayName = garment['displayName']?.toString().trim();
        final services =
            (garment['services'] as List<dynamic>? ?? const [])
                .map((service) => service.toString().trim())
                .where((service) => service.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final material = garment['material']?.toString().trim() ?? '';
        final key = jsonEncode([
          displayName?.isNotEmpty == true ? displayName : 'Garment',
          services,
          material,
        ]);
        final existing = groupedGarments[key];
        if (existing == null) {
          groupedGarments[key] = {
            'displayName': displayName?.isNotEmpty == true
                ? displayName
                : 'Garment',
            'services': services,
            'material': material,
            'quantity': 1,
          };
        } else {
          existing['quantity'] = (existing['quantity'] as int) + 1;
        }
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((snapshot.data?['orderNumber']?.toString().trim() ?? '')
                .isNotEmpty)
              Text(
                'Order ${snapshot.data?['orderNumber']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const Text(
              'Booked garments · grouped by type',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final garment in groupedGarments.values) ...[
              const SizedBox(height: 4),
              Text(
                '${garment['quantity']} × ${garment['displayName']}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                [
                  ...(garment['services'] as List<dynamic>? ?? const []).map(
                    (service) => service.toString(),
                  ),
                  if ((garment['material']?.toString() ?? '').isNotEmpty)
                    'Material: ${garment['material']}',
                ].join(' · '),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _assignOtherDeliveryPartner() async {
    setState(() => _saving = true);
    try {
      final partners = await GarmentCareService.deliveryPartnerCandidates(
        accountId: widget.accountId,
        profileId: widget.profileId,
        shipmentId: widget.shipmentId,
      );
      if (!mounted) return;
      if (partners.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No available delivery Partner covers this Customer’s PIN. Ask a registered Delivery Partner to turn on Garment Care delivery availability and add this PIN to their service area.',
            ),
          ),
        );
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Choose a delivery Partner')),
              for (final partner in partners)
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(
                    partner['name']?.toString() ?? 'Delivery Partner',
                  ),
                  subtitle: Text(
                    [
                      partner['partnerType'] == 'deliveryPartner'
                          ? 'Delivery Partner · PIN matched'
                          : 'Garment Care Partner',
                      if ((partner['contactPhone']?.toString() ?? '')
                          .isNotEmpty)
                        partner['contactPhone'].toString(),
                    ].join(' · '),
                  ),
                  onTap: () => Navigator.pop(sheetContext, partner),
                ),
            ],
          ),
        ),
      );
      if (!mounted || selected == null) return;
      await GarmentCareService.assignReturnDeliveryPartner(
        shipmentId: widget.shipmentId,
        accountId: widget.accountId,
        profileId: widget.profileId,
        deliveryPartnerAccountId: selected['accountId'].toString(),
        deliveryPartnerProfileId: selected['profileId'].toString(),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Could not assign a delivery Partner.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not assign a delivery Partner.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmCustomerDelivery() async {
    var enteredPin = '';
    var validPin = false;
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirm Customer handover'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ask the Customer for the last four digits of their registered phone number and enter them here.',
              ),
              const SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (value) {
                  enteredPin = value.trim();
                  setDialogState(() {
                    validPin = RegExp(r'^\d{4}$').hasMatch(enteredPin);
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Customer delivery PIN',
                  counterText: '',
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
              onPressed: validPin
                  ? () => Navigator.pop(dialogContext, enteredPin)
                  : null,
              child: const Text('Confirm handover'),
            ),
          ],
        ),
      ),
    );
    if (pin == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await GarmentCareService.confirmCustomerDelivery(
        shipmentId: widget.shipmentId,
        pin: pin,
        accountId: widget.accountId,
        profileId: widget.profileId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handover confirmed for this garment sub-order.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        final errorMessage = error.message?.trim();
        final message =
            error.code == 'not-found' &&
                (errorMessage == null ||
                    errorMessage.isEmpty ||
                    errorMessage.toUpperCase() == 'NOT_FOUND')
            ? 'Delivery confirmation is unavailable. Please ask the app administrator to update the Garment Care service.'
            : errorMessage ?? 'Could not confirm Customer handover.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not confirm handover. Check the connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _respondToDeliveryAssignment(String decision) async {
    String reasonCode = '';
    if (decision == 'reject') {
      final chosenReason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          var selected = 'not_available';
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: const Text('Decline delivery assignment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a reason. The Garment Care Partner will see it.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    items: [
                      for (final entry
                          in _deliveryAssignmentDeclineReasons.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selected = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selected),
                  child: const Text('Decline delivery'),
                ),
              ],
            ),
          );
        },
      );
      if (chosenReason == null) return;
      reasonCode = chosenReason;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await GarmentCareService.respondToGarmentCareDeliveryAssignment(
        shipmentId: widget.shipmentId,
        accountId: widget.accountId,
        profileId: widget.profileId,
        decision: decision,
        reasonCode: reasonCode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'accept'
                  ? 'Delivery assignment accepted.'
                  : 'Delivery assignment declined. The Garment Care Partner can reassign it.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Could not update the delivery assignment.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the delivery assignment.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _pickupScheduleLabel(dynamic value, dynamic slot) {
    final date = value is Timestamp ? value.toDate() : null;
    final dateLabel = date == null
        ? 'Date not set'
        : '${date.day}/${date.month}/${date.year}';
    final slotLabel = slot?.toString().trim() ?? '';
    return slotLabel.isEmpty ? dateLabel : '$dateLabel · $slotLabel';
  }

  Future<void> _confirm(String action, List<String> garmentIds) async {
    setState(() => _saving = true);
    try {
      final evidence = <String, String>{};
      final pickupReceipt =
          action == 'receive' &&
          widget.data['shipmentType'] == 'customer_pickup';
      if (pickupReceipt) {
        final picker = ImagePicker();
        for (final garmentId in garmentIds) {
          final image = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 78,
            maxWidth: 1600,
          );
          if (image == null) {
            throw StateError(
              'Capture a condition photo for every garment to confirm pickup.',
            );
          }
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (uid.isEmpty) {
            throw StateError('Sign in again before recording pickup.');
          }
          final orderId = widget.data['orderId']?.toString() ?? '';
          final stamp = DateTime.now().microsecondsSinceEpoch;
          final path =
              'garment_care_evidence/$orderId/${widget.shipmentId}/$garmentId/$uid/$stamp.jpg';
          await FirebaseStorage.instance
              .ref(path)
              .putFile(
                File(image.path),
                SettableMetadata(
                  contentType: 'image/jpeg',
                  customMetadata: {
                    'orderId': orderId,
                    'shipmentId': widget.shipmentId,
                    'garmentId': garmentId,
                    'partnerUid': uid,
                  },
                ),
              );
          evidence[garmentId] = path;
        }
      }
      await GarmentCareService.recordHandover(
        shipmentId: widget.shipmentId,
        accountId: widget.accountId,
        profileId: widget.profileId,
        action: action,
        confirmedGarmentIds: garmentIds,
        evidencePhotosByGarmentId: evidence,
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          'unavailable' =>
            'Garment Care could not reach the server. Check the connection and retry.',
          'not-found' =>
            'The pickup or its package record could not be found. Refresh the list and retry.',
          _ => error.message ?? 'Could not record custody (${error.code}).',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}

String _careLoadError(Object? error) {
  final message = error?.toString().trim() ?? '';
  if (message.isEmpty) return 'Please try again.';
  return message.length > 180 ? '${message.substring(0, 180)}…' : message;
}
