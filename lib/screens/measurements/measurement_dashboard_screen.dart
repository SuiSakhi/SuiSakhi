import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/measurement_unit.dart';
import '../../models/measurement.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/measurement_card.dart';
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

      bool _loadingPeople = true;
      bool _loadingDraft = false;
      Map<String, dynamic>? _latestDraft;

    @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loadingPeople = true;
    });

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
        final accountId =
            await AppState.instance.fetchAccountIdForMobile(phone.trim());

        if (accountId != null && accountId.isNotEmpty) {
          final profiles =
              await AppState.instance.fetchActiveProfilesForAccount(accountId);

          Map<String, dynamic>? customerProfile;

          for (final p in profiles) {
            final role = (p['role'] ?? '').toString();
            if (role == 'customer') {
              customerProfile = p;
              break;
            }
          }

          final customerProfileId =
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
        _selectedPerson = people.first;
        _loadingPeople = false;
      });

      await _loadLatestMeasurementDraft();
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
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .where((data) {
                final status = (data['status'] ?? '').toString();
                final source = (data['source'] ?? '').toString();

                final isActiveMeasurementStatus = status == 'draft' ||
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
    @override
    Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final measurements = AppState.instance.measurements;
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
                onPressed: () {},
                tooltip: 'Edit',
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
                  if (measurements == null) ...[
                    _buildNoMeasurementState(context),
                    const SizedBox(height: 28),
                  ] else ...[
                    _buildMeasurementSummaryCard(measurements, unit),
                    const SizedBox(height: 28),
                    Text('Body Measurements', style: AppTextStyles.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated: Today · values shown in ${unit.abbrev} (with alternate)',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _buildGrid(measurements, unit),
                    const SizedBox(height: 28),
                  ],
                   PrimaryButton(
                    label: 'Start New Measurement',
                    icon: Icons.add_circle_outline_rounded,
                    onTap: () {
                      final person = _selectedPerson;

                      if (person == null) {
                        context.push('/measurement-context');
                        return;
                      }

                      context.push(
                        '/measurement-context'
                        '?clientName=${Uri.encodeComponent(person.name)}'
                        '&personId=${Uri.encodeComponent(person.id)}'
                        '&relationship=${Uri.encodeComponent(person.relationship)}',
                      );
                    },
                  ),
                  if (measurements != null) ...[
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Design a Dress with These',
                      icon: Icons.design_services_rounded,
                      onTap: () {
                        final person = _selectedPerson;

                        if (person == null) {
                          context.push('/designer');
                          return;
                        }

                        context.push(
                          '/designer'
                          '?clientName=${Uri.encodeComponent(person.name)}'
                          '&personId=${Uri.encodeComponent(person.id)}'
                          '&relationship=${Uri.encodeComponent(person.relationship)}',
                        );
                      },
                    ),
                  ],
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
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Measurements shown below belong to the selected person.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
          ),
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
        (draft['relationship'] ?? _selectedPerson?.relationship ?? '').toString();

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
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.28),
        ),
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
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: $readableStatus',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
            ),
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

    final personId =
        (draft['personId'] ?? _selectedPerson?.id ?? '').toString();
    final personName =
        (draft['personName'] ?? _selectedPerson?.name ?? '').toString();
    final relationship =
        (draft['relationship'] ?? _selectedPerson?.relationship ?? '').toString();

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
            'No saved measurements are available for $personName yet.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Start a new measurement using AI Camera or another supported measurement method before designing a dress.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementSummaryCard(BodyMeasurements m, MeasurementUnit unit) {
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
                  'Body Profile',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  m.height != null
                      ? MeasurementFormat.formatDual(m.height, unit,
                          fractionDigits: 0)
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

  Widget _buildGrid(BodyMeasurements m, MeasurementUnit unit) {
    final items = [
      ('Chest', m.chest, Icons.straighten_rounded, AppColors.primary),
      ('Waist', m.waist, Icons.radio_button_unchecked, const Color(0xFFFF6B6B)),
      ('Hips', m.hips, Icons.accessibility_rounded, const Color(0xFFF5A623)),
      ('Shoulder', m.shoulder, Icons.width_wide_rounded, const Color(0xFF4CAF50)),
      ('Arm Length', m.armLength, Icons.back_hand_outlined, AppColors.primaryDark),
      ('Height', m.height, Icons.height_rounded, const Color(0xFF9C27B0)),
      ('Neck', m.neck, Icons.circle_outlined, const Color(0xFF00BCD4)),
      ('Thigh', m.thigh, Icons.airline_seat_legroom_normal, const Color(0xFFFF5722)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => MeasurementTile(
        label: items[i].$1,
        valueCm: items[i].$2,
        unit: unit,
        icon: items[i].$3,
        color: items[i].$4,
      ),
    );
  }
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