import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/garment_measurement_catalog.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../services/customer_measurement_history_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_unit_toggle.dart';

class MeasurementDashboardScreen extends StatefulWidget {
  const MeasurementDashboardScreen({super.key});

  @override
  State<MeasurementDashboardScreen> createState() =>
      _MeasurementDashboardScreenState();
}

class _MeasurementDashboardScreenState
    extends State<MeasurementDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<_MeasurementDashboardPerson> _people = [];
  _MeasurementDashboardPerson? _selectedPerson;
  String? _customerProfileId;

  bool _loadingPeople = true;
  bool _loadingDraft = false;
  bool _loadingPersonMeasurements = false;

  Map<String, dynamic>? _latestDraft;
  BodyMeasurements? _selectedPersonMeasurements;
  List<CustomerMeasurementRecord> _measurementHistory = const [];
  CustomerMeasurementRecord? _currentCustomerReference;
  bool _savingCustomerReference = false;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
    });

    String? customerProfileId;
    try {
      final profile = AppState.instance.profile;
      final customerName = profile?.name.trim().isNotEmpty == true
          ? profile!.name.trim()
          : AppState.instance.displayName;

      final people = <_MeasurementDashboardPerson>[
        _MeasurementDashboardPerson(
          id: 'self',
          name: customerName,
          relationship: 'Self',
        ),
      ];

      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

      if (phone != null && phone.trim().isNotEmpty) {
        final accountId = await AppState.instance.fetchAccountIdForMobile(
          phone.trim(),
        );

        if (accountId != null && accountId.isNotEmpty) {
          final profiles = await AppState.instance
              .fetchActiveProfilesForAccount(accountId);

          Map<String, dynamic>? customerProfile;

          for (final p in profiles) {
            final role = (p['role'] ?? '').toString();
            if (role == 'customer') {
              customerProfile = p;
              break;
            }
          }

          customerProfileId =
              customerProfile?['profileId']?.toString() ??
              customerProfile?['docId']?.toString();

          if (customerProfileId != null &&
              customerProfileId.trim().isNotEmpty) {
            final familySnap = await _db
                .collection('accounts')
                .doc(accountId)
                .collection('profiles')
                .doc(customerProfileId)
                .collection('family_members')
                .where('status', isEqualTo: 'active')
                .get();

            for (final doc in familySnap.docs) {
              final data = doc.data();

              people.add(
                _MeasurementDashboardPerson(
                  id: doc.id,
                  name: data['name']?.toString() ?? 'Family Member',
                  relationship: data['relationship']?.toString() ?? 'Other',
                ),
              );
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _people
          ..clear()
          ..addAll(people);
        _customerProfileId = customerProfileId;
        _selectedPerson = people.first;
        _loadingPeople = false;
      });

      await _loadLatestMeasurementDraft();
      await _loadLatestPersonMeasurements();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingPeople = false;
      });
    }
  }

  Future<String?> _currentAccountId() async {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      return null;
    }

    return AppState.instance.fetchAccountIdForMobile(phone.trim());
  }

  BodyMeasurements? _bodyMeasurementsFromValues(Map<String, dynamic>? values) {
    if (values == null || values.isEmpty) return null;

    double? read(String key) {
      final value = values[key];
      if (value == null) return null;

      if (value is num) {
        return value.toDouble();
      }

      return double.tryParse(value.toString());
    }

    final height = read('height');
    final chest = read('chest');
    final waist = read('waist');
    final hips = read('hips');
    final shoulder = read('shoulder');
    final armLength = read('armLength');
    final neck = read('neck');
    final thigh = read('thigh');
    final inseam = read('inseam');

    final hasAnyValue = [
      height,
      chest,
      waist,
      hips,
      shoulder,
      armLength,
      neck,
      thigh,
      inseam,
    ].any((value) => value != null && value > 0);

    if (!hasAnyValue) return null;

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
      capturedAt: DateTime.now(),
    );
  }

  Future<void> _loadLatestMeasurementDraft() async {
    final person = _selectedPerson;

    if (person == null) return;

    setState(() {
      _loadingDraft = true;
      _latestDraft = null;
    });

    try {
      final accountId = await _currentAccountId();

      if (accountId == null || accountId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingDraft = false;
        });
        return;
      }

      final snap = await _db
          .collection('measurements')
          .where('accountId', isEqualTo: accountId)
          .where('personId', isEqualTo: person.id)
          .get();

      final activeDrafts = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((data) {
            final storedProfileId = (data['customerProfileId'] ?? '')
                .toString();
            if (_customerProfileId?.isNotEmpty == true &&
                storedProfileId.isNotEmpty &&
                storedProfileId != _customerProfileId) {
              return false;
            }
            final status = (data['status'] ?? '').toString();
            final source = (data['source'] ?? '').toString();

            final isActiveMeasurementStatus =
                status == 'draft' ||
                status == 'ai_estimated' ||
                status == 'customer_review_required';

            final isCurrentlyResumableSource = source == 'ai_camera';

            return isActiveMeasurementStatus && isCurrentlyResumableSource;
          })
          .toList();

      activeDrafts.sort((a, b) {
        final aTime = a['updatedAt'];
        final bTime = b['updatedAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }

        return 0;
      });

      if (!mounted) return;

      setState(() {
        _latestDraft = activeDrafts.isEmpty ? null : activeDrafts.first;
        _loadingDraft = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingDraft = false;
      });
    }
  }

  Future<void> _loadLatestPersonMeasurements() async {
    final person = _selectedPerson;

    if (person == null) return;

    setState(() {
      _loadingPersonMeasurements = true;
      _selectedPersonMeasurements = null;
      _measurementHistory = const [];
      _currentCustomerReference = null;
    });

    try {
      final accountId = await _currentAccountId();

      if (accountId == null || accountId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _loadingPersonMeasurements = false;
        });
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      var history = const <CustomerMeasurementRecord>[];
      BodyMeasurements? confirmedMeasurements;
      if (uid != null) {
        try {
          history = await CustomerMeasurementHistoryService.loadHistory(
            customerUid: uid,
            accountId: accountId,
            customerProfileId: _customerProfileId,
            personId: person.id,
            personName: person.name,
            limit: 10,
          );
        } catch (_) {}
        try {
          confirmedMeasurements =
              await CustomerMeasurementHistoryService.loadLatestTailorConfirmed(
                customerUid: uid,
                accountId: accountId,
                personId: person.id,
                personName: person.name,
                customerProfileId: _customerProfileId,
              );
        } catch (_) {}
      }

      final snap = await _db
          .collection('measurements')
          .where('accountId', isEqualTo: accountId)
          .where('personId', isEqualTo: person.id)
          .get();

      final usableDocs = snap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((data) {
            final storedProfileId = (data['customerProfileId'] ?? '')
                .toString();
            if (_customerProfileId?.isNotEmpty == true &&
                storedProfileId.isNotEmpty &&
                storedProfileId != _customerProfileId) {
              return false;
            }
            final status = (data['status'] ?? '').toString();

            return status == 'ai_estimated' ||
                status == 'customer_review_required' ||
                status == 'partner_review_required' ||
                status == 'tailor_confirmed' ||
                status == 'verified' ||
                status == 'accepted' ||
                status == 'order_created';
          })
          .toList();

      usableDocs.sort((a, b) {
        final aTime = a['updatedAt'];
        final bTime = b['updatedAt'];

        if (aTime is Timestamp && bTime is Timestamp) {
          return bTime.compareTo(aTime);
        }

        return 0;
      });

      BodyMeasurements? loadedMeasurements = confirmedMeasurements;

      for (final data in usableDocs) {
        if (loadedMeasurements != null) break;
        final values = data['measurementValues'];

        if (values is Map<String, dynamic>) {
          loadedMeasurements = _bodyMeasurementsFromValues(values);
        } else if (values is Map) {
          loadedMeasurements = _bodyMeasurementsFromValues(
            Map<String, dynamic>.from(values),
          );
        }

        if (loadedMeasurements != null) {
          break;
        }
      }

      if (!mounted) return;
      CustomerMeasurementRecord? currentCustomerReference;
      for (final record in history) {
        if (record.isCustomerReference) {
          currentCustomerReference = record;
          break;
        }
      }

      setState(() {
        _selectedPersonMeasurements = loadedMeasurements;
        _measurementHistory = history;
        _currentCustomerReference = currentCustomerReference;
        _loadingPersonMeasurements = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingPersonMeasurements = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final measurements = _selectedPersonMeasurements;
        final unit = AppState.instance.measurementUnit;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Measurements'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: MeasurementUnitToggle()),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _savingCustomerReference
                    ? null
                    : _editCustomerMeasurements,
                tooltip: 'Edit customer measurements',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPersonSelector(),
                const SizedBox(height: 20),
                _buildMeasurementDraftCard(context),
                if (_latestDraft != null) const SizedBox(height: 20),
                if (_loadingPersonMeasurements) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                ],
                if (measurements == null &&
                    _currentCustomerReference == null &&
                    _measurementHistory.isEmpty) ...[
                  _buildNoMeasurementState(context),
                  const SizedBox(height: 20),
                ],
                if (measurements != null) ...[
                  _buildMeasurementSummaryCard(measurements, unit),
                  const SizedBox(height: 28),
                ],
                Text('Body Measurements', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  _currentCustomerReference == null
                      ? 'No customer reference saved yet · shown in ${unit.abbrev} (with alternate)'
                      : 'Customer reference · updated ${_formatMeasurementDate(_currentCustomerReference!.capturedAt)} · shown in ${unit.abbrev} (with alternate)',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Existing saved values are shown where available. Edit or replace them to create your customer reference; Tailor-confirmed measurements remain separate.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMeasurementChartGuide(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _savingCustomerReference
                          ? null
                          : _editCustomerMeasurements,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit all 22'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _savingCustomerReference
                          ? null
                          : _replaceFromMeasurementHistory,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Replace from history'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildGrid(measurements, unit),
                const SizedBox(height: 28),
                if (_measurementHistory.isNotEmpty) ...[
                  _buildMeasurementHistory(),
                  const SizedBox(height: 24),
                ],
                PrimaryButton(
                  label: 'Start New Measurement',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () async {
                    final person = _selectedPerson;

                    if (person == null) {
                      await context.push('/measurement-context');
                    } else {
                      await context.push(
                        '/measurement-context'
                        '?clientName=${Uri.encodeComponent(person.name)}'
                        '&personId=${Uri.encodeComponent(person.id)}'
                        '&relationship=${Uri.encodeComponent(person.relationship)}',
                      );
                    }
                    if (!mounted) return;
                    await _loadLatestPersonMeasurements();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersonSelector() {
    if (_loadingPeople) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measurement For', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      );
    }

    if (_people.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = _selectedPerson ?? _people.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Measurement For', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selected.id,
          decoration: const InputDecoration(
            labelText: 'Select person',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: _people
              .map(
                (person) => DropdownMenuItem<String>(
                  value: person.id,
                  child: Text(
                    '${person.name} (${person.relationship})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) async {
            if (value == null) return;

            final selectedPerson = _people.firstWhere(
              (person) => person.id == value,
              orElse: () => _people.first,
            );

            setState(() {
              _selectedPerson = selectedPerson;
            });

            await _loadLatestMeasurementDraft();
            await _loadLatestPersonMeasurements();
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Measurements shown below belong to the selected person.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _buildMeasurementDraftCard(BuildContext context) {
    if (_loadingDraft) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: const LinearProgressIndicator(),
      );
    }

    final draft = _latestDraft;

    if (draft == null) {
      return const SizedBox.shrink();
    }

    final status = (draft['status'] ?? 'draft').toString();
    final source = (draft['source'] ?? '').toString();
    final personName =
        (draft['personName'] ?? _selectedPerson?.name ?? 'Selected Person')
            .toString();
    final relationship =
        (draft['relationship'] ?? _selectedPerson?.relationship ?? '')
            .toString();

    final readableStatus = switch (status) {
      'ai_estimated' => 'AI Estimate Ready',
      'customer_review_required' => 'Customer Review Required',
      'draft' => 'Draft Started',
      _ => status,
    };

    final readableSource = switch (source) {
      'ai_camera' => 'AI Camera',
      'manual' => 'Manual Measurement',
      'video_call' => 'Video Call',
      'home_visit' => 'Home Visit',
      'nearest_tailor' => 'Nearest Tailor',
      'old_dress' => 'Old Dress Reference',
      'design_existing' => 'Design From Measurements',
      _ => source.isEmpty ? 'Measurement' : source,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Measurement Draft In Progress',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'For: $personName${relationship.isNotEmpty ? ' ($relationship)' : ''}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Source: $readableSource',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: $readableStatus',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Resume Measurement',
            icon: Icons.play_arrow_rounded,
            onTap: () => _resumeMeasurementDraft(context, draft),
          ),
        ],
      ),
    );
  }

  void _resumeMeasurementDraft(
    BuildContext context,
    Map<String, dynamic> draft,
  ) {
    final draftId = (draft['draftId'] ?? draft['id'] ?? '').toString();
    final source = (draft['source'] ?? '').toString();
    final status = (draft['status'] ?? '').toString();

    final personId = (draft['personId'] ?? _selectedPerson?.id ?? '')
        .toString();
    final personName = (draft['personName'] ?? _selectedPerson?.name ?? '')
        .toString();
    final relationship =
        (draft['relationship'] ?? _selectedPerson?.relationship ?? '')
            .toString();

    if (draftId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resume this measurement draft.'),
        ),
      );
      return;
    }

    if (source == 'ai_camera' && status == 'ai_estimated') {
      context.push(
        '/measurement-result'
        '?draftId=${Uri.encodeComponent(draftId)}'
        '&clientName=${Uri.encodeComponent(personName)}'
        '&personId=${Uri.encodeComponent(personId)}'
        '&relationship=${Uri.encodeComponent(relationship)}',
      );
      return;
    }

    if (source == 'ai_camera' && status == 'draft') {
      context.push(
        '/camera'
        '?draftId=${Uri.encodeComponent(draftId)}'
        '&clientName=${Uri.encodeComponent(personName)}'
        '&personId=${Uri.encodeComponent(personId)}'
        '&relationship=${Uri.encodeComponent(relationship)}',
      );
      return;
    }

    if (source == 'design_existing') {
      context.push(
        '/designer'
        '?draftId=${Uri.encodeComponent(draftId)}'
        '&clientName=${Uri.encodeComponent(personName)}'
        '&personId=${Uri.encodeComponent(personId)}'
        '&relationship=${Uri.encodeComponent(relationship)}',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resume for this measurement method will be added next.'),
      ),
    );
  }

  Widget _buildNoMeasurementState(BuildContext context) {
    final personName = _selectedPerson?.name ?? 'this person';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
              Icon(
                Icons.straighten_outlined,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No measurements found',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No saved measurement history is available for $personName yet.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'You can add a customer reference at any time. The Tailor or measurement partner will confirm the final measurements for an order.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Measurement History', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Showing the latest ${_measurementHistory.length} records. Customer references do not replace tailor-confirmed measurements.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        for (final record in _measurementHistory)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showMeasurementRecord(record),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: record.isCustomerReference
                                ? AppColors.accent.withValues(alpha: .1)
                                : AppColors.success.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _measurementStatusLabel(record),
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMeasurementDate(record.capturedAt)} · ${record.values.length} fields',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    if (record.values.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        record.values.entries
                            .take(3)
                            .map(
                              (entry) =>
                                  '${_measurementLabel(entry.key)}: ${entry.value} ${record.unit}',
                            )
                            .join('   ·   '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    if (record.referenceImageUrl?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          record.referenceImageUrl!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showMeasurementRecord(CustomerMeasurementRecord record) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(record.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatMeasurementDate(record.capturedAt)} · ${_measurementStatusLabel(record)}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final entry in record.values.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Text(
                      '${entry.key}: ${entry.value} ${record.unit}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                if (record.values.isEmpty)
                  const Text(
                    'This saved garment reference has no measurement values.',
                  ),
                if (record.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(record.note!, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementSummaryCard(
    BodyMeasurements m,
    MeasurementUnit unit,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest saved body summary',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  m.height != null
                      ? MeasurementFormat.formatDual(
                          m.height,
                          unit,
                          fractionDigits: 0,
                        )
                      : 'Height: —',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _statChip('Chest', m.chest, unit),
                    _statChip('Waist', m.waist, unit),
                    _statChip('Hips', m.hips, unit),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, double? val, MeasurementUnit unit) {
    final t = val != null
        ? MeasurementFormat.formatDual(val, unit, fractionDigits: 0)
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $t',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  double? _measurementValueCm(
    GarmentMeasurementSpec spec,
    BodyMeasurements? fallback,
  ) {
    final record = _currentCustomerReference;
    if (record != null) {
      for (final entry in record.values.entries) {
        if (GarmentMeasurementCatalog.forAnyKey(entry.key)?.number !=
            spec.number) {
          continue;
        }
        final value = double.tryParse(entry.value);
        if (value == null || value <= 0 || !value.isFinite) return null;
        final unit =
            measurementUnitFromStorage(record.unit) ?? MeasurementUnit.cm;
        return unit.toCm(value);
      }
      return null;
    }

    if (fallback == null) return null;
    return switch (spec.number) {
      1 => fallback.neck,
      3 => fallback.chest,
      5 => fallback.waist,
      6 => fallback.hips,
      7 => fallback.height,
      9 => fallback.inseam,
      10 => fallback.armLength,
      19 => fallback.shoulder,
      _ => null,
    };
  }

  Future<void> _editCustomerMeasurements() async {
    final unit = AppState.instance.measurementUnit;
    final initialValues = <String, double>{};
    for (final spec in GarmentMeasurementCatalog.all) {
      final valueCm = _measurementValueCm(spec, _selectedPersonMeasurements);
      if (valueCm != null) initialValues[spec.key] = unit.fromCm(valueCm);
    }

    final editedValues = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => _CustomerMeasurementsEditorSheet(
        unit: unit,
        initialValues: initialValues,
      ),
    );

    if (editedValues == null || !mounted) return;
    await _saveCustomerReference(
      values: editedValues,
      unit: unit,
      source: 'manual_customer_reference',
      title: 'My measurements',
      note: 'Customer-edited measurement reference.',
      referenceOfId: _currentCustomerReference?.id,
    );
  }

  Future<void> _replaceFromMeasurementHistory() async {
    final person = _selectedPerson;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (person == null || uid == null) return;

    final options = <_MeasurementReferenceOption>[
      for (final record in _measurementHistory)
        if (record.values.isNotEmpty)
          _MeasurementReferenceOption(
            title: record.title,
            subtitle:
                '${_measurementStatusLabel(record)} · ${_formatMeasurementDate(record.capturedAt)} · ${record.values.length} fields',
            values: record.values,
            unit: record.unit,
            source: 'previous_measurement_reference',
            referenceId: record.id,
            sourceOrderId: record.sourceOrderId,
            imageUrl: record.referenceImageUrl,
          ),
    ];
    try {
      final oldDressReferences =
          await CustomerMeasurementHistoryService.loadDressReferences(
            customerUid: uid,
            personId: person.id,
            personName: person.name,
          );
      options.addAll(
        oldDressReferences
            .where((reference) => reference.values.isNotEmpty)
            .map(
              (reference) => _MeasurementReferenceOption(
                title: reference.title,
                subtitle: 'Previous order · ${reference.values.length} fields',
                values: reference.values,
                unit: reference.unit,
                source: 'old_dress_reference',
                referenceId: null,
                sourceOrderId: reference.orderId,
                imageUrl: reference.imageUrl,
              ),
            ),
      );
    } catch (_) {
      // Measurement history choices can still be used if old orders are unavailable.
    }

    if (!mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved measurement references found.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<_MeasurementReferenceOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .78,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Replace from saved measurements',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Choosing a record saves a new customer reference. The original history and tailor-confirmed record stay unchanged.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            for (final option in options)
              Card(
                color: AppColors.surface,
                child: ListTile(
                  title: Text(option.title),
                  subtitle: Text(option.subtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final values = <String, double>{};
    for (final entry in selected.values.entries) {
      final spec = GarmentMeasurementCatalog.forAnyKey(entry.key);
      final value = double.tryParse(entry.value);
      if (spec != null && value != null && value > 0 && value.isFinite) {
        values[spec.key] = value;
      }
    }
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This record has no values that can be copied.'),
        ),
      );
      return;
    }
    await _saveCustomerReference(
      values: values,
      unit: measurementUnitFromStorage(selected.unit) ?? MeasurementUnit.cm,
      source: selected.source,
      title: 'My measurements · ${selected.title}',
      note: 'Customer reference copied from ${selected.title}.',
      referenceOfId: selected.referenceId,
      sourceOrderId: selected.sourceOrderId,
      referenceImageUrl: selected.imageUrl,
    );
  }

  Future<void> _saveCustomerReference({
    required Map<String, double> values,
    required MeasurementUnit unit,
    required String source,
    required String title,
    required String note,
    String? referenceOfId,
    String? sourceOrderId,
    String? referenceImageUrl,
  }) async {
    final person = _selectedPerson;
    if (person == null) return;
    setState(() => _savingCustomerReference = true);
    try {
      final accountId = await _currentAccountId();
      final profileId = _customerProfileId?.trim() ?? '';
      if (accountId == null || accountId.isEmpty || profileId.isEmpty) {
        throw StateError('Customer profile is unavailable.');
      }
      final ref = _db.collection('measurements').doc();
      await ref.set({
        'schemaVersion': 1,
        'draftId': ref.id,
        'accountId': accountId,
        'customerProfileId': profileId,
        'personId': person.id,
        'personName': person.name,
        'relationship': person.relationship,
        'source': source,
        'measurementType': 'customer_reference',
        'measurementSchema': 'suisakhi_womens_22_v2',
        'status': 'customer_reference',
        'referenceOnly': true,
        'measurementValues': values,
        'measurementUnit': unit.abbrev,
        'customerNote': note,
        'referenceTitle': title,
        if (referenceImageUrl?.trim().isNotEmpty == true)
          'referenceImageUrl': referenceImageUrl!.trim(),
        if (sourceOrderId?.trim().isNotEmpty == true)
          'sourceOrderId': sourceOrderId!.trim(),
        if (referenceOfId?.trim().isNotEmpty == true)
          'referenceOfId': referenceOfId!.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer measurement reference saved.')),
      );
      await _loadLatestPersonMeasurements();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to save customer measurements. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCustomerReference = false);
    }
  }

  Widget _buildGrid(BodyMeasurements? m, MeasurementUnit unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (
            var index = 0;
            index < GarmentMeasurementCatalog.all.length;
            index++
          ) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: AppColors.divider.withValues(alpha: .7),
              ),
            _buildMeasurementRow(GarmentMeasurementCatalog.all[index], m, unit),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(
    GarmentMeasurementSpec spec,
    BodyMeasurements? fallback,
    MeasurementUnit unit,
  ) {
    final valueCm = _measurementValueCm(spec, fallback);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Text(
              spec.number.toString().padLeft(2, '0'),
              style: TextStyle(
                color: spec.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 5,
            child: Text(
              spec.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              valueCm == null
                  ? 'Not added'
                  : MeasurementFormat.formatDual(
                      valueCm,
                      unit,
                      fractionDigits: 1,
                    ),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueCm == null ? AppColors.textHint : spec.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementChartGuide() {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.accessibility_new_rounded),
        title: Text(
          'Universal measurement chart',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Visual guide for all 22 measurement points',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          Text(
            'Match the number beside a measurement to the diagram. Use this as a guide; your tailor will confirm the measurements for an order.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showMeasurementChart,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/universal_measurement_chart.png',
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: 'Universal women and girls measurement chart',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the chart to zoom in.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  void _showMeasurementChart() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close chart',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.asset(
                    'assets/images/universal_measurement_chart.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerMeasurementsEditorSheet extends StatefulWidget {
  const _CustomerMeasurementsEditorSheet({
    required this.unit,
    required this.initialValues,
  });

  final MeasurementUnit unit;
  final Map<String, double> initialValues;

  @override
  State<_CustomerMeasurementsEditorSheet> createState() =>
      _CustomerMeasurementsEditorSheetState();
}

class _CustomerMeasurementsEditorSheetState
    extends State<_CustomerMeasurementsEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final spec in GarmentMeasurementCatalog.all)
        spec.key: TextEditingController(
          text: widget.initialValues[spec.key]
              ?.toStringAsFixed(1)
              .replaceFirst(RegExp(r'\.0$'), ''),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final values = <String, double>{};
    for (final spec in GarmentMeasurementCatalog.all) {
      final raw = _controllers[spec.key]!.text.trim();
      final value = double.tryParse(raw);
      if (value != null) values[spec.key] = value;
    }
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one measurement.')),
      );
      return;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final maximum = unit == MeasurementUnit.cm ? 500 : 200;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit customer measurements',
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Enter what you know in ${unit.abbrev}; leave other fields blank. Saving creates a new customer reference and keeps measurement history unchanged.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    _buildUniversalChartReference(),
                    const SizedBox(height: 12),
                    ...GarmentMeasurementCatalog.all.map((spec) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: TextFormField(
                          controller: _controllers[spec.key],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            labelText:
                                '${spec.number.toString().padLeft(2, '0')} · ${spec.label}',
                            labelStyle: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12.5,
                            ),
                            suffixText: unit.abbrev,
                          ),
                          validator: (raw) {
                            final value = raw?.trim() ?? '';
                            if (value.isEmpty) return null;
                            final parsed = double.tryParse(value);
                            if (parsed == null ||
                                !parsed.isFinite ||
                                parsed <= 0 ||
                                parsed > maximum) {
                              return 'Enter a value from 0 to $maximum ${unit.abbrev}.';
                            }
                            return null;
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save customer measurements'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversalChartReference() {
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.divider),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.accessibility_new_rounded),
        title: Text(
          'Universal measurement chart',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Visual reference for all 22 points',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          Text(
            'Use the numbered chart to identify each measurement. Tap the image to zoom in.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _showUniversalChart,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/universal_measurement_chart.png',
                width: double.infinity,
                height: 200,
                fit: BoxFit.contain,
                semanticLabel: 'Universal women and girls measurement chart',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUniversalChart() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close chart',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.asset(
                    'assets/images/universal_measurement_chart.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeasurementReferenceOption {
  const _MeasurementReferenceOption({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.unit,
    required this.source,
    required this.referenceId,
    required this.sourceOrderId,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final Map<String, String> values;
  final String unit;
  final String source;
  final String? referenceId;
  final String? sourceOrderId;
  final String? imageUrl;
}

class _MeasurementDashboardPerson {
  final String id;
  final String name;
  final String relationship;

  const _MeasurementDashboardPerson({
    required this.id,
    required this.name,
    required this.relationship,
  });
}

String _formatMeasurementDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _measurementLabel(String key) =>
    key.replaceFirst(RegExp(r'^\s*\d+\s*[·.\-:]?\s*'), '');

String _measurementStatusLabel(CustomerMeasurementRecord record) {
  if (record.isCustomerReference) return 'Your reference';
  if (record.source == 'partner_confirmed') return 'Tailor confirmed';
  if (record.measurementType == 'professional_capture') {
    return record.status == 'tailor_confirmed'
        ? 'Tailor confirmed'
        : 'Partner captured · awaiting tailor review';
  }
  if (record.source == 'ai_camera') return 'AI estimate · review needed';
  return 'Needs confirmation';
}
