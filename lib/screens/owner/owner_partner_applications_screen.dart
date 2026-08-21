import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_application.dart';
import 'package:go_router/go_router.dart';

class OwnerPartnerApplicationsScreen extends StatelessWidget {
  const OwnerPartnerApplicationsScreen({super.key});

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
        stream: FirebaseFirestore.instance
            .collection('partner_applications')
            .where(
              'status',
              whereIn: [
                PartnerApplicationStatus.submitted.name,
                PartnerApplicationStatus.underReview.name,
                PartnerApplicationStatus.changesRequested.name,
                PartnerApplicationStatus.rejected.name,
                PartnerApplicationStatus.approved.name,
              ],
            )
            .snapshots(),
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

          return RefreshIndicator(
            onRefresh: () async {
              await FirebaseFirestore.instance
                  .collection('partner_applications')
                  .where(
                    'status',
                    whereIn: [
                      PartnerApplicationStatus.submitted.name,
                      PartnerApplicationStatus.underReview.name,
                      PartnerApplicationStatus.changesRequested.name,
                      PartnerApplicationStatus.rejected.name,
                      PartnerApplicationStatus.approved.name,
                    ],
                  )
                  .get();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(applications),
                const SizedBox(height: 20),
                Text('Applications', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 12),
                ...applications.map(
                  (application) =>
                      _PartnerApplicationCard(application: application),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

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
    final submittedCount = applications
        .where(
          (application) =>
              application.status == PartnerApplicationStatus.submitted,
        )
        .length;

    final underReviewCount = applications
        .where(
          (application) =>
              application.status == PartnerApplicationStatus.underReview,
        )
        .length;

    final approvedCount = applications
        .where(
          (application) =>
              application.status == PartnerApplicationStatus.approved,
        )
        .length;

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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  label: 'Submitted',
                  value: submittedCount,
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryValue(
                  label: 'In Review',
                  value: underReviewCount,
                  color: const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryValue(
                  label: 'Approved',
                  value: approvedCount,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 10),
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
        return 'Submitted';
      case PartnerApplicationStatus.underReview:
        return 'Under Review';
      case PartnerApplicationStatus.changesRequested:
        return 'Changes Requested';
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
        return const Color(0xFFFF9800);
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
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
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
