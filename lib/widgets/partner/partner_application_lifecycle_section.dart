import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_application.dart';

/// Common lifecycle presentation for every SuiSakhi Partner application.
///
/// This widget is presentation-only. Persistence, navigation, Apply Again,
/// and category-specific hydration remain owned by the application screen.
class PartnerApplicationStatusNotice extends StatelessWidget {
  const PartnerApplicationStatusNotice({
    super.key,
    required this.application,
    required this.partnerLabel,
  });

  final PartnerApplication application;
  final String partnerLabel;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(application, partnerLabel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: presentation.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(presentation.icon, color: presentation.color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: presentation.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  presentation.message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _LifecyclePresentation _presentation(
    PartnerApplication application,
    String partnerLabel,
  ) {
    switch (application.status) {
      case PartnerApplicationStatus.draft:
        return _LifecyclePresentation(
          icon: Icons.edit_document,
          title: 'Application status: Draft',
          message:
              'Complete or update the $partnerLabel application. '
              'Save it for later or submit it for SuiSakhi Admin review.',
          color: const Color(0xFF607D8B),
        );
      case PartnerApplicationStatus.submitted:
        return _LifecyclePresentation(
          icon: Icons.schedule_send_outlined,
          title: 'Application status: Submitted',
          message:
              'The $partnerLabel application has been submitted and is '
              'waiting for SuiSakhi Admin review.',
          color: const Color(0xFFFF9800),
        );
      case PartnerApplicationStatus.underReview:
        return _LifecyclePresentation(
          icon: Icons.manage_search_rounded,
          title: 'Application status: Under Review',
          message:
              'SuiSakhi Admin is reviewing the $partnerLabel application. '
              'Editing is temporarily unavailable.',
          color: const Color(0xFF2196F3),
        );
      case PartnerApplicationStatus.changesRequested:
        final instructions = application.reviewNotes?.trim();
        return _LifecyclePresentation(
          icon: Icons.edit_note_rounded,
          title: 'Application status: Changes Requested',
          message: instructions == null || instructions.isEmpty
              ? 'SuiSakhi Admin needs additional information. Update the '
                    'application and resubmit it for review.'
              : 'Admin comment: $instructions',
          color: const Color(0xFFFF9800),
        );
      case PartnerApplicationStatus.approved:
        return _LifecyclePresentation(
          icon: Icons.verified_rounded,
          title: 'Application status: Approved',
          message:
              'The $partnerLabel application has been approved. The '
              'approved Partner Business Profile remains governed separately.',
          color: const Color(0xFF2E7D32),
        );
      case PartnerApplicationStatus.rejected:
        final reason = application.rejectionReason?.trim();
        return _LifecyclePresentation(
          icon: Icons.cancel_outlined,
          title: 'Application Not Approved',
          message: reason == null || reason.isEmpty
              ? 'SuiSakhi could not approve this application. Contact '
                    'SuiSakhi Helpdesk if clarification is required.'
              : 'Reason: $reason\n\nThe rejected application remains '
                    'unchanged for audit history. You may Apply Again.',
          color: AppColors.error,
        );
      case PartnerApplicationStatus.suspended:
        return _LifecyclePresentation(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Application status: Suspended',
          message:
              'This $partnerLabel application or Partner Business Profile '
              'is currently suspended. Review Admin instructions or contact '
              'SuiSakhi Helpdesk.',
          color: const Color(0xFFD84315),
        );
      case PartnerApplicationStatus.inactive:
        return _LifecyclePresentation(
          icon: Icons.block_outlined,
          title: 'Application status: Inactive',
          message:
              'This $partnerLabel application or Partner Business Profile '
              'is currently inactive.',
          color: const Color(0xFF757575),
        );
    }
  }
}

/// Common lifecycle-aware actions for every Partner application screen.
///
/// Each screen supplies callbacks so category-specific save and hydration logic
/// remains outside this reusable component.
class PartnerApplicationLifecycleActions extends StatelessWidget {
  const PartnerApplicationLifecycleActions({
    super.key,
    required this.application,
    required this.saving,
    required this.canSaveDraft,
    required this.canSubmit,
    required this.onSaveDraft,
    required this.onSubmitForReview,
    required this.onApplyAgain,
    required this.onContinueLater,
  });

  final PartnerApplication application;
  final bool saving;
  final bool canSaveDraft;
  final bool canSubmit;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmitForReview;
  final VoidCallback onApplyAgain;
  final VoidCallback onContinueLater;

  @override
  Widget build(BuildContext context) {
    final status = application.status;

    if (status == PartnerApplicationStatus.rejected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: saving ? null : onApplyAgain,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(saving ? 'Creating New Application...' : 'Apply Again'),
          ),
          const SizedBox(height: 10),
          _backButton(),
        ],
      );
    }

    if (status == PartnerApplicationStatus.submitted ||
        status == PartnerApplicationStatus.underReview ||
        status == PartnerApplicationStatus.approved ||
        status == PartnerApplicationStatus.suspended ||
        status == PartnerApplicationStatus.inactive) {
      return _backButton();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canSaveDraft && !saving ? onSaveDraft : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Saving Draft...' : 'Save Draft'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: canSubmit && !saving ? onSubmitForReview : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.send_rounded),
          label: Text(
            status == PartnerApplicationStatus.changesRequested
                ? 'Resubmit for Review'
                : 'Submit for Review',
          ),
        ),
        const SizedBox(height: 10),
        _backButton(label: 'Continue Later', icon: Icons.schedule_outlined),
      ],
    );
  }

  Widget _backButton({
    String label = 'Back to Partner Opportunities',
    IconData icon = Icons.arrow_back_rounded,
  }) {
    return OutlinedButton.icon(
      onPressed: saving ? null : onContinueLater,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _LifecyclePresentation {
  const _LifecyclePresentation({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
}
