import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_application.dart';
import '../../services/partner_service.dart';

class OwnerPartnerApplicationReviewScreen extends StatelessWidget {
  const OwnerPartnerApplicationReviewScreen({
    required this.applicationId,
    super.key,
  });

  final String applicationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Review Application'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('partner_applications')
            .doc(applicationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error?.toString() ?? 'Unable to load the application.',
            );
          }

          final document = snapshot.data;

          if (document == null || !document.exists) {
            return _buildErrorState(
              'The Partner application could not be found.',
            );
          }

          final application = PartnerApplication.fromDoc(document);

          return _buildReviewContent(context, application);
        },
      ),
    );
  }

  Widget _buildReviewContent(
    BuildContext context,
    PartnerApplication application,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(application),
        const SizedBox(height: 18),
        _buildApplicantDetails(application),
        const SizedBox(height: 18),
        _buildOnboardingProgress(),
        const SizedBox(height: 18),
        _buildKycCard(),
        const SizedBox(height: 18),
        _buildReviewActions(context, application),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildStatusCard(PartnerApplication application) {
    final statusColor = _statusColor(application.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: statusColor.withValues(alpha: 0.14),
            child: Icon(
              application.partnerType == PartnerType.tailor
                  ? Icons.content_cut_rounded
                  : Icons.handshake_outlined,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _partnerTypeLabel(application.partnerType),
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Application status: '
                  '${_statusLabel(application.status)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Application ID: ${application.id}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantDetails(PartnerApplication application) {
    final submittedAt = application.submittedAt ?? application.updatedAt;

    return _ReviewSection(
      title: 'Applicant Details',
      icon: Icons.person_outline_rounded,
      children: [
        _ReviewDetail(
          label: 'Contact name',
          value: application.contactName ?? 'Not provided',
        ),
        _ReviewDetail(
          label: 'Business or workshop',
          value: application.businessName ?? 'Not provided',
        ),
        _ReviewDetail(
          label: 'Mobile',
          value: application.mobileE164 ?? 'Not provided',
        ),
        _ReviewDetail(
          label: 'Email',
          value: application.email ?? 'Not provided',
        ),
        _ReviewDetail(
          label: 'Partner type',
          value: _partnerTypeLabel(application.partnerType),
        ),
        _ReviewDetail(label: 'Submitted', value: _formatDateTime(submittedAt)),
        _ReviewDetail(label: 'Account ID', value: application.accountId),
        _ReviewDetail(
          label: 'Customer profile ID',
          value: application.customerProfileId,
        ),
      ],
    );
  }

  Widget _buildOnboardingProgress() {
    return const _ReviewSection(
      title: 'Onboarding Progress',
      icon: Icons.checklist_rounded,
      children: [
        _ProgressItem(label: 'Basic details', completed: true),
        _ProgressItem(label: 'Workshop details', completed: false),
        _ProgressItem(label: 'Services and specialization', completed: false),
        _ProgressItem(label: 'Capacity and availability', completed: false),
        _ProgressItem(label: 'Measurement preferences', completed: false),
        _ProgressItem(label: 'Quality and verification', completed: false),
        _ProgressItem(label: 'Expected rate information', completed: false),
        _ProgressItem(label: 'Documents and declaration', completed: false),
      ],
    );
  }

  Widget _buildKycCard() {
    return const _ReviewSection(
      title: 'KYC and Verification',
      icon: Icons.verified_user_outlined,
      children: [
        _ReviewDetail(label: 'KYC status', value: 'Not started'),
        _ReviewDetail(label: 'Documents', value: 'Not uploaded'),
        _ReviewDetail(label: 'Verified by', value: 'Not assigned'),
        _ReviewDetail(label: 'Verification date', value: 'Not available'),
      ],
    );
  }

  Future<void> _startReview(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Partner Review'),
          content: const Text(
            'This application will move from Submitted to Under Review.\n\n'
            'No Partner profile will be approved or activated at this stage.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Start Review'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await PartnerService.startReview(applicationId: application.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner application moved to Under Review'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start review.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildReviewActions(
    BuildContext context,
    PartnerApplication application,
  ) {
    return _ReviewSection(
      title: 'Admin Actions',
      icon: Icons.admin_panel_settings_outlined,
      children: [
        Text(
          'Review actions will be enabled after the secure Admin '
          'authorization and review service are added.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: application.status == PartnerApplicationStatus.submitted
                ? () {
                    _startReview(context, application);
                  }
                : null,
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(
              application.status == PartnerApplicationStatus.underReview
                  ? 'Review Started'
                  : 'Start Review',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Request Changes'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject Application'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Approve Application'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
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
              'Unable to review application',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ReviewDetail extends StatelessWidget {
  const _ReviewDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? const Color(0xFF4CAF50) : AppColors.textHint;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: completed
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: completed ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
