import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_application.dart';
import 'package:go_router/go_router.dart';

class OwnerPartnerApplicationsScreen extends StatefulWidget {
  const OwnerPartnerApplicationsScreen({super.key});

  @override
  State<OwnerPartnerApplicationsScreen> createState() =>
      _OwnerPartnerApplicationsScreenState();
}

class _OwnerPartnerApplicationsScreenState
    extends State<OwnerPartnerApplicationsScreen> {
  PartnerType? _selectedPartnerType;
  PartnerApplicationStatus? _selectedStatus;

  static const _visibleStatuses = [
    PartnerApplicationStatus.submitted,
    PartnerApplicationStatus.underReview,
    PartnerApplicationStatus.changesRequested,
    PartnerApplicationStatus.approved,
    PartnerApplicationStatus.rejected,
    PartnerApplicationStatus.suspended,
    PartnerApplicationStatus.inactive,
  ];

  Query<Map<String, dynamic>> get _applicationsQuery => FirebaseFirestore
      .instance
      .collection('partner_applications')
      .where('status', whereIn: _visibleStatuses.map((s) => s.name).toList());

  String _partnerTypeCategoryLabel(PartnerType type) => switch (type) {
    PartnerType.tailor => 'Tailoring',
    PartnerType.measurementPartner => 'Measurements',
    PartnerType.garmentCare => 'Garment Care',
    PartnerType.doorstepServices => 'Quick Care & Home Services',
    _ => _PartnerApplicationCard._partnerTypeLabel(type),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Applications'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _applicationsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error);
          }

          final loadedApplications =
              snapshot.data?.docs.map(PartnerApplication.fromDoc).toList() ??
              <PartnerApplication>[];

          final applications = _canonicalApplications(loadedApplications);

          if (applications.isEmpty) {
            return _buildEmptyState();
          }

          final categoryApplications = applications
              .where(
                (application) =>
                    _selectedPartnerType == null ||
                    application.partnerType == _selectedPartnerType,
              )
              .toList(growable: false);
          final visibleApplications = categoryApplications
              .where(
                (application) =>
                    _selectedStatus == null ||
                    application.status == _selectedStatus,
              )
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async {
              await _applicationsQuery.get();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(categoryApplications),
                const SizedBox(height: 16),
                _buildPartnerTypeFilters(applications),
                const SizedBox(height: 12),
                _buildStatusFilters(categoryApplications),
                const SizedBox(height: 20),
                Text(
                  _selectedStatus == null
                      ? 'Applications'
                      : '${_PartnerApplicationCard._statusLabel(_selectedStatus!)} applications',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (visibleApplications.isEmpty)
                  _buildFilteredEmptyState()
                else
                  ..._buildGroupedApplications(visibleApplications),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedApplications(
    List<PartnerApplication> applications,
  ) {
    final types = _selectedPartnerType == null
        ? PartnerType.values
        : [_selectedPartnerType!];
    final children = <Widget>[];
    for (final type in types) {
      final group = applications
          .where((application) => application.partnerType == type)
          .toList(growable: false);
      if (group.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            '${_partnerTypeCategoryLabel(type)} applications · ${group.length}',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      children.addAll(
        group.map(
          (application) => _PartnerApplicationCard(application: application),
        ),
      );
    }
    return children;
  }

  Widget _buildPartnerTypeFilters(List<PartnerApplication> applications) {
    int countFor(PartnerType? type) => applications.where((application) {
      final matchesType = type == null || application.partnerType == type;
      final matchesStatus =
          _selectedStatus == null || application.status == _selectedStatus;
      return matchesType && matchesStatus;
    }).length;

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final type in <PartnerType?>[null, ...PartnerType.values])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _selectedPartnerType == type,
                onSelected: (_) => setState(() => _selectedPartnerType = type),
                label: Text(
                  '${type == null ? 'All partner types' : _partnerTypeCategoryLabel(type)} (${countFor(type)})',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters(List<PartnerApplication> applications) {
    int countFor(PartnerApplicationStatus? status) => applications
        .where((application) => status == null || application.status == status)
        .length;

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final status in <PartnerApplicationStatus?>[
            null,
            ..._visibleStatuses,
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _selectedStatus == status,
                onSelected: (_) => setState(() => _selectedStatus = status),
                label: Text(
                  '${status == null ? 'All statuses' : _PartnerApplicationCard._statusLabel(status)} (${countFor(status)})',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      children: [
        const Icon(Icons.filter_alt_off_outlined, color: AppColors.textHint),
        const SizedBox(height: 8),
        Text(
          'No applications match these filters.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        TextButton(
          onPressed: () => setState(() {
            _selectedPartnerType = null;
            _selectedStatus = null;
          }),
          child: const Text('Clear filters'),
        ),
      ],
    ),
  );

  List<PartnerApplication> _canonicalApplications(
    List<PartnerApplication> source,
  ) {
    final byAccountProfileAndType = <String, PartnerApplication>{};

    for (final application in source) {
      final key = [
        application.accountId,
        application.customerProfileId,
        application.partnerType.name,
      ].join('|');

      final existing = byAccountProfileAndType[key];

      if (existing == null ||
          application.updatedAt.isAfter(existing.updatedAt)) {
        byAccountProfileAndType[key] = application;
      }
    }

    final applications = byAccountProfileAndType.values.toList();

    applications.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );

    return applications;
  }

  Widget _buildSummaryCard(List<PartnerApplication> applications) {
    return Container(
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
              const CircleAvatar(
                backgroundColor: Color(0x1A673AB7),
                child: Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Application Summary',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              _selectedPartnerType == null
                  ? 'All partner types'
                  : '${_partnerTypeCategoryLabel(_selectedPartnerType!)} applications',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _visibleStatuses.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (context, index) {
                  final status = _visibleStatuses[index];
                  return _SummaryValue(
                    label: _PartnerApplicationCard._statusLabel(status),
                    value: applications
                        .where((application) => application.status == status)
                        .length,
                    color: _PartnerApplicationCard._statusColor(status),
                    selected: _selectedStatus == status,
                    onTap: () => setState(() {
                      _selectedStatus = _selectedStatus == status
                          ? null
                          : status;
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: AppColors.textHint,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No partner applications',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted partner applications will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 58,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load applications',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerApplicationCard extends StatelessWidget {
  const _PartnerApplicationCard({required this.application});

  final PartnerApplication application;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(application.status);
    final submittedAt = application.submittedAt ?? application.updatedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(
                  application.partnerType == PartnerType.tailor
                      ? Icons.content_cut_rounded
                      : Icons.handshake_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.businessName?.trim().isNotEmpty == true
                          ? application.businessName!.trim()
                          : _partnerTypeLabel(application.partnerType),
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _partnerTypeLabel(application.partnerType),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(application.status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Contact',
            value: application.contactName ?? 'Not provided',
          ),
          _DetailRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: application.mobileE164 ?? 'Not provided',
          ),
          if (application.email?.trim().isNotEmpty == true)
            _DetailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: application.email!.trim(),
            ),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Submitted',
            value: _formatDateTime(submittedAt),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push('/owner/partner-applications/${application.id}');
              },
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View Application'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  static String _partnerTypeLabel(PartnerType type) {
    switch (type) {
      case PartnerType.tailor:
        return 'Tailor';

      // MEASUREMENT PARTNER EXTENSION
      // Keep this explicit case so Dart detects any future Partner category
      // that has not yet been intentionally added to the Admin interface.
      case PartnerType.measurementPartner:
        return 'Measurement Partner';
      case PartnerType.garmentCare:
        return 'Garment Care';
      case PartnerType.boutique:
        return 'Boutique';
      case PartnerType.designer:
        return 'Designer / Fashion Services';
      case PartnerType.fabricSupplier:
        return 'Fabric Store / Supplier';
      case PartnerType.printing:
        return 'Printing';
      case PartnerType.embroidery:
        return 'Embroidery';
      case PartnerType.rental:
        return 'Rental';
      case PartnerType.accessories:
        return 'Accessories';
      case PartnerType.brand:
        return 'Brand';
      case PartnerType.deliveryPartner:
        return 'Delivery Partner';
      case PartnerType.doorstepServices:
        return 'Doorstep Services';
      case PartnerType.other:
        return 'Other Partner';
    }
  }

  static String _statusLabel(PartnerApplicationStatus status) {
    switch (status) {
      case PartnerApplicationStatus.draft:
        return 'Draft';
      case PartnerApplicationStatus.submitted:
        return 'Pending to Review';
      case PartnerApplicationStatus.underReview:
        return 'In Progress';
      case PartnerApplicationStatus.changesRequested:
        return 'Send Back to Customer';
      case PartnerApplicationStatus.approved:
        return 'Approved';
      case PartnerApplicationStatus.rejected:
        return 'Rejected';
      case PartnerApplicationStatus.suspended:
        return 'Suspended';
      case PartnerApplicationStatus.inactive:
        return 'Inactive';
    }
  }

  static Color _statusColor(PartnerApplicationStatus status) {
    switch (status) {
      case PartnerApplicationStatus.draft:
        return AppColors.textHint;
      case PartnerApplicationStatus.submitted:
        return const Color(0xFFFF9800);
      case PartnerApplicationStatus.underReview:
        return const Color(0xFF2196F3);
      case PartnerApplicationStatus.changesRequested:
        return const Color(0xFF8E44AD);
      case PartnerApplicationStatus.approved:
        return const Color(0xFF4CAF50);
      case PartnerApplicationStatus.rejected:
        return AppColors.error;
      case PartnerApplicationStatus.suspended:
        return const Color(0xFF9C27B0);
      case PartnerApplicationStatus.inactive:
        return AppColors.textHint;
    }
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
