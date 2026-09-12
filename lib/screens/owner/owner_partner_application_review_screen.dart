import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/designer_partner_details.dart';
import '../../models/boutique_partner_details.dart';
import '../../models/brand_partner_details.dart';
import '../../models/measurement_partner_details.dart';
import '../../models/partner_application.dart';
import '../../services/partner_service.dart';
import '../../services/partner_profile_activation_service.dart';

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

        // ================================================================
        // CATEGORY-AWARE PARTNER OPERATIONS REVIEW
        // ================================================================
        //
        // Measurement Partner uses the Measurement Partner extension.
        // Tailor continues using the legacy Workshop Details adapter.
        // ================================================================
        _buildBusinessOperations(application),
        const SizedBox(height: 18),

        // ================================================================
        // LEGACY TAILOR ONBOARDING PROGRESS
        // ================================================================
        //
        // ARCH-PP-004:
        // Section progress does not control submission, KYC, approval,
        // activation, or authorization.
        //
        // Hide the legacy progress workflow for Measurement Partner.
        // Keep it temporarily for Tailor until consolidated cleanup.
        // ================================================================
        _buildKycCard(context, application),
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
              _partnerTypeIcon(application.partnerType),
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
          label: 'Business or service',
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

        if (application.status == PartnerApplicationStatus.rejected &&
            application.rejectionReason?.trim().isNotEmpty == true)
          _ReviewDetail(
            label: 'Rejection reason',
            value: application.rejectionReason!.trim(),
          ),

        if (application.rejectedAt != null)
          _ReviewDetail(
            label: 'Rejected',
            value: _formatDateTime(application.rejectedAt!),
          ),

        _ReviewDetail(label: 'Account ID', value: application.accountId),
        _ReviewDetail(
          label: 'Customer profile ID',
          value: application.customerProfileId,
        ),
      ],
    );
  }

  // ==========================================================================
  // MEASUREMENT PARTNER REVIEW: OPERATIONAL DETAILS
  // ==========================================================================
  //
  // Reads only:
  //
  // onboardingData.extensions.measurementPartner
  //
  // This method does not use Tailor Workshop Details and does not modify any
  // application data.
  // ==========================================================================
  Widget _buildMeasurementPartnerOperations(PartnerApplication application) {
    final details = MeasurementPartnerDetails.fromOnboardingData(
      application.onboardingData,
    );

    final schedule = details.operatingSchedule;
    final address = details.serviceAddress;

    return _ReviewSection(
      title: 'Measurement Services & Operations',
      icon: Icons.straighten_rounded,
      children: [
        _ReviewDetail(
          label: 'Service address',
          value: _displayValue(address.formattedAddress),
        ),

        _ReviewDetail(
          label: 'Service-area pincodes',
          value: _displayList(details.normalizedServiceAreaPincodes),
        ),

        _ReviewDetail(
          label: 'Maximum travel distance',
          value: details.maximumTravelDistanceKm == null
              ? 'Not provided'
              : '${details.maximumTravelDistanceKm} km',
        ),

        _ReviewDetail(
          label: 'Available days',
          value: schedule.operatingDaysDisplay,
        ),

        _ReviewDetail(
          label: 'Available from',
          value: _displayValue(schedule.openingTime),
        ),

        _ReviewDetail(
          label: 'Available until',
          value: _displayValue(schedule.closingTime),
        ),

        _ReviewDetail(
          label: 'Measurement services',
          value: _displayList(
            details.capabilitySelection.normalizedCapabilityCodes
                .map(_measurementCapabilityLabel)
                .toList(growable: false),
          ),
        ),

        if (details
            .capabilitySelection
            .normalizedAdditionalDescriptions
            .isNotEmpty)
          _ReviewDetail(
            label: 'Other services',
            value: _displayList(
              details.capabilitySelection.normalizedAdditionalDescriptions,
            ),
          ),

        _ReviewDetail(
          label: 'Measurements per day',
          value: _displayNonNegativeNumber(details.measurementsPerDay),
        ),

        _ReviewDetail(
          label: 'Home visits per day',
          value: _displayNonNegativeNumber(details.homeVisitsPerDay),
        ),

        _ReviewDetail(
          label: 'Video sessions per day',
          value: _displayNonNegativeNumber(details.videoSessionsPerDay),
        ),

        _ReviewDetail(
          label: 'Service notes',
          value: _displayValue(details.serviceNotes),
        ),

        const SizedBox(height: 8),

        Text(
          'Measurement information collected by this Partner remains '
          'subject to final confirmation through the assigned Tailor '
          'workflow before production begins.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // DESIGNER PARTNER REVIEW: PROFESSIONAL & DESIGN OPERATIONS
  // ==========================================================================
  //
  // Reads only:
  //
  // onboardingData.extensions.designer
  //
  // Designer-specific onboarding information is displayed here for Admin
  // review. Common application lifecycle, KYC, approval, and activation remain
  // handled by the existing Partner foundation.
  // ==========================================================================
  Widget _buildDesignerPartnerOperations(PartnerApplication application) {
    final details = DesignerPartnerDetails.fromOnboardingData(
      application.onboardingData,
    );

    final capabilities = details.capabilitySelection.normalizedCapabilityCodes;

    return _ReviewSection(
      title: 'Designer Services & Professional Details',
      icon: Icons.design_services_outlined,
      children: [
        _ReviewDetail(
          label: 'Professional type',
          value: _displayValue(details.professionalType),
        ),
        _ReviewDetail(
          label: 'Experience',
          value: details.experienceYears == null
              ? 'Not provided'
              : '${details.experienceYears} years',
        ),
        _ReviewDetail(
          label: 'Specialization',
          value: _displayValue(details.specialization),
        ),
        _ReviewDetail(
          label: 'Designer capabilities',
          value: _displayList(capabilities),
        ),
        _ReviewDetail(
          label: 'Accepts custom design',
          value: details.acceptsCustomDesign ? 'Yes' : 'No',
        ),
        _ReviewDetail(
          label: 'Accepts bulk orders',
          value: details.acceptsBulkOrders ? 'Yes' : 'No',
        ),
        _ReviewDetail(
          label: 'Accepts wedding orders',
          value: details.acceptsWeddingOrders ? 'Yes' : 'No',
        ),
        _ReviewDetail(
          label: 'Consultation available',
          value: details.consultationAvailable ? 'Yes' : 'No',
        ),
        _ReviewDetail(
          label: 'Portfolio summary',
          value: _displayValue(details.portfolioSummary),
        ),
        _ReviewDetail(
          label: 'Original work declaration',
          value: details.originalWorkDeclaration
              ? 'Confirmed'
              : 'Not confirmed',
        ),
        _ReviewDetail(
          label: 'Additional notes',
          value: _displayValue(details.additionalNotes),
        ),
      ],
    );
  }

  // ============================================================================
  // BOUTIQUE PARTNER REVIEW
  // ============================================================================
  Widget _buildBoutiquePartnerOperations(PartnerApplication application) {
    final details = BoutiquePartnerDetails.fromOnboardingData(application.onboardingData);
    return _ReviewSection(
      title: 'Boutique Business & Operations',
      icon: Icons.storefront_outlined,
      children: [
        _ReviewDetail(label: 'Specialization', value: _displayValue(details.specialization)),
        _ReviewDetail(label: 'Experience', value: details.experienceYears == null ? 'Not provided' : '${details.experienceYears} years'),
        _ReviewDetail(label: 'Capabilities', value: _displayList(details.capabilitySelection.normalizedCapabilityCodes)),
        _ReviewDetail(label: 'Service area', value: _displayValue(details.serviceArea)),
        _ReviewDetail(label: 'Team size', value: _displayNumber(details.teamSize)),
        _ReviewDetail(label: 'Normal daily capacity', value: _displayNumber(details.normalDailyCapacity)),
        _ReviewDetail(label: 'Peak daily capacity', value: _displayNumber(details.peakDailyCapacity)),
        _ReviewDetail(label: 'Home visit / consultation', value: details.homeVisitAvailable ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Pickup & Delivery', value: details.pickupAndDeliveryAvailable ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Ready-made inventory', value: details.readyMadeInventory ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Return / exchange', value: details.returnExchangeAvailable ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Portfolio', value: _displayValue(details.portfolioSummary)),
        _ReviewDetail(label: 'Additional notes', value: _displayValue(details.additionalNotes)),
      ],
    );
  }

  // ============================================================================
  // BRAND PARTNER REVIEW
  // ============================================================================
  Widget _buildBrandPartnerOperations(PartnerApplication application) {
    final details = BrandPartnerDetails.fromOnboardingData(application.onboardingData);
    return _ReviewSection(
      title: 'Brand Business & Operations',
      icon: Icons.local_mall_outlined,
      children: [
        _ReviewDetail(label: 'Brand specialization', value: _displayValue(details.brandSpecialization)),
        _ReviewDetail(label: 'Experience', value: details.experienceYears == null ? 'Not provided' : '${details.experienceYears} years'),
        _ReviewDetail(label: 'Product categories', value: _displayValue(details.productCategories)),
        _ReviewDetail(label: 'Target market', value: _displayValue(details.targetMarket)),
        _ReviewDetail(label: 'Capabilities', value: _displayList(details.capabilitySelection.normalizedCapabilityCodes)),
        _ReviewDetail(label: 'Catalogue ready', value: details.catalogueReady ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Inventory managed', value: details.inventoryManaged ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Ready stock', value: details.readyStock ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Pickup & Delivery', value: details.pickupAndDeliveryAvailable ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Return / exchange', value: details.returnExchangeAvailable ? 'Yes' : 'No'),
        _ReviewDetail(label: 'Service area', value: _displayValue(details.serviceArea)),
        _ReviewDetail(label: 'Team size', value: _displayNumber(details.teamSize)),
        _ReviewDetail(label: 'Normal daily capacity', value: _displayNumber(details.normalDailyCapacity)),
        _ReviewDetail(label: 'Peak daily capacity', value: _displayNumber(details.peakDailyCapacity)),
        _ReviewDetail(label: 'Additional notes', value: _displayValue(details.additionalNotes)),
      ],
    );
  }

  Widget _buildBusinessOperations(PartnerApplication application) {
    // =========================================================================
    // MEASUREMENT PARTNER REVIEW
    // =========================================================================
    if (application.partnerType == PartnerType.measurementPartner) {
      return _buildMeasurementPartnerOperations(application);
    }

    // =========================================================================
    // DESIGNER PARTNER REVIEW
    // =========================================================================
    if (application.partnerType == PartnerType.designer) {
      return _buildDesignerPartnerOperations(application);
    }

    // =========================================================================
    // BOUTIQUE PARTNER REVIEW
    // =========================================================================
    if (application.partnerType == PartnerType.boutique) {
      return _buildBoutiquePartnerOperations(application);
    }

    // =========================================================================
    // BRAND PARTNER REVIEW
    // =========================================================================
    if (application.partnerType == PartnerType.brand) {
      return _buildBrandPartnerOperations(application);
    }

    // =========================================================================
    // TAILOR-SPECIFIC REVIEW
    // =========================================================================
    //
    // Retain the existing Workshop Details renderer until the consolidated
    // Partner review foundation is completed.
    // =========================================================================
    final details = application.workshopDetails;

    if (details == null) {
      return _ReviewSection(
        title: 'Business & Operations',
        icon: Icons.storefront_outlined,
        children: [
          _ReviewDetail(label: 'Structured information', value: 'Not provided'),
          const SizedBox(height: 8),
          Text(
            'This application may have been reviewed before '
            'structured Business & Operations information was introduced. '
            'The required details must be completed before final approval.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return _ReviewSection(
      title: 'Business & Operations',
      icon: Icons.storefront_outlined,
      children: [
        _ReviewDetail(
          label: 'Business type',
          value: _workshopTypeLabel(details.workshopTypeCode),
        ),
        _ReviewDetail(
          label: 'Address',
          value: _formattedBusinessAddress(details),
        ),
        _ReviewDetail(
          label: 'Locality',
          value: _displayValue(details.locality),
        ),
        _ReviewDetail(label: 'City', value: _displayValue(details.city)),
        _ReviewDetail(label: 'State', value: _displayValue(details.state)),
        _ReviewDetail(label: 'Pincode', value: _displayValue(details.pincode)),
        _ReviewDetail(
          label: 'Service-area pincodes',
          value: _displayList(details.serviceAreaPincodes),
        ),
        _ReviewDetail(
          label: 'Operating days',
          value: _operatingDaysLabel(details.operatingDays),
        ),
        _ReviewDetail(
          label: 'Opening time',
          value: _displayValue(details.openingTime),
        ),
        _ReviewDetail(
          label: 'Closing time',
          value: _displayValue(details.closingTime),
        ),
        _ReviewDetail(
          label: 'Team size',
          value: _displayNumber(details.teamSize),
        ),
        _ReviewDetail(
          label: 'Normal daily capacity',
          value: _displayNumber(details.normalDailyCapacity),
        ),
        _ReviewDetail(
          label: 'Peak daily capacity',
          value: _displayNumber(details.peakDailyCapacity),
        ),
        _ReviewDetail(
          label: 'Machines and equipment',
          value: _displayList(details.machineCodes),
        ),
        _ReviewDetail(
          label: 'Pickup available',
          value: _yesNoLabel(details.pickupAvailable),
        ),
        _ReviewDetail(
          label: 'Delivery available',
          value: _yesNoLabel(details.deliveryAvailable),
        ),
        _ReviewDetail(
          label: 'Home visit available',
          value: _yesNoLabel(details.homeVisitAvailable),
        ),
        _ReviewDetail(
          label: 'Additional notes',
          value: _displayValue(details.additionalNotes),
        ),
        if (details.placeId?.trim().isNotEmpty == true)
          _ReviewDetail(
            label: 'Map place reference',
            value: details.placeId!.trim(),
          ),
        if (details.latitude != null && details.longitude != null)
          _ReviewDetail(
            label: 'Map coordinates',
            value: '${details.latitude}, ${details.longitude}',
          ),
      ],
    );
  }

  String _displayValue(String? value) {
    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return 'Not provided';
    }

    return normalizedValue;
  }

  String _displayNumber(int? value) {
    if (value == null || value <= 0) {
      return 'Not provided';
    }

    return value.toString();
  }

  // Measurement capacity may legitimately be zero.
  String _displayNonNegativeNumber(int? value) {
    if (value == null || value < 0) {
      return 'Not provided';
    }

    return value.toString();
  }

  String _displayList(List<String> values) {
    final normalizedValues = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (normalizedValues.isEmpty) {
      return 'Not provided';
    }

    return normalizedValues.join(', ');
  }

  // ==========================================================================
  // MEASUREMENT PARTNER REVIEW: CAPABILITY LABELS
  // ==========================================================================
  String _measurementCapabilityLabel(String code) {
    switch (code.trim()) {
      case 'measurement.measurementOnly':
        return 'Measurement Only';

      case 'measurement.homeVisit':
        return 'Home Measurement Visit';

      case 'measurement.videoAssisted':
        return 'Video-Assisted Measurement';

      case 'measurement.referenceGarment':
        return 'Reference Garment Measurement';

      case 'measurement.referenceGarmentPickup':
        return 'Reference Garment Pickup';

      case 'measurement.measurementAndPickup':
        return 'Measurement and Pickup';

      case 'measurement.pickupAndDrop':
        return 'Pickup and Drop';

      default:
        return code.trim().isEmpty ? 'Not provided' : code.trim();
    }
  }

  String _yesNoLabel(bool value) {
    return value ? 'Yes' : 'No';
  }

  String _formattedBusinessAddress(PartnerWorkshopDetails details) {
    final addressParts = [details.addressLine1, details.addressLine2]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    if (addressParts.isEmpty) {
      return 'Not provided';
    }

    return addressParts.join(', ');
  }

  String _workshopTypeLabel(String? code) {
    switch (code?.trim()) {
      case 'homeBased':
        return 'Home-based';

      case 'commercialWorkshop':
        return 'Commercial establishment';

      case 'boutique':
        return 'Boutique';

      case 'sharedWorkspace':
        return 'Shared workspace';

      case 'other':
        return 'Other';

      default:
        return 'Not provided';
    }
  }

  String _operatingDaysLabel(List<String> days) {
    if (days.isEmpty) {
      return 'Not provided';
    }

    const dayLabels = {
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
    };

    final labels = days
        .map((day) => dayLabels[day.trim()] ?? day.trim())
        .where((day) => day.isNotEmpty)
        .toList(growable: false);

    if (labels.isEmpty) {
      return 'Not provided';
    }

    return labels.join(', ');
  }

  Future<void> _updateWorkshopStatus(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final currentStatus = application.onboardingStatusFor(
      PartnerOnboardingSection.workshopDetails,
    );

    final targetStatus = _nextWorkshopStatus(currentStatus);

    if (targetStatus == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_workshopActionLabel(currentStatus)),
          content: Text(
            'Business & Operations will move from '
            '${_onboardingStatusLabel(currentStatus)} to '
            '${_onboardingStatusLabel(targetStatus)}.\n\n'
            'This action does not approve or activate the '
            'Partner profile.',
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
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await PartnerService.updateOnboardingSectionStatus(
        applicationId: application.id,
        section: PartnerOnboardingSection.workshopDetails,
        targetStatus: targetStatus,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Business & Operations marked as '
            '${_onboardingStatusLabel(targetStatus)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update Business & Operations.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @pragma('vm:entry-point')
  Widget _buildOnboardingProgress(
    BuildContext context,
    PartnerApplication application,
  ) {
    final completedCount = application.completedOnboardingSectionCount;

    final verifiedCount = application.verifiedOnboardingSectionCount;

    final totalCount = application.totalOnboardingSectionCount;

    final workshopStatus = application.onboardingStatusFor(
      PartnerOnboardingSection.workshopDetails,
    );

    final workshopDetails = application.workshopDetails;

    final canUpdateWorkshop =
        application.status == PartnerApplicationStatus.underReview &&
        workshopStatus != PartnerOnboardingSectionStatus.verified &&
        workshopDetails != null &&
        workshopDetails.hasMinimumRequiredData;

    return _ReviewSection(
      title: 'Onboarding Progress',
      icon: Icons.checklist_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _OnboardingSummaryValue(
                label: 'Completed',
                value: '$completedCount of $totalCount',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OnboardingSummaryValue(
                label: 'Verified',
                value: '$verifiedCount of $totalCount',
                color: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final section in PartnerOnboardingSection.values)
          _ProgressItem(
            label: _onboardingSectionLabel(section),
            status: application.onboardingStatusFor(section),
          ),
        if (application.workshopDetails == null ||
            !application.workshopDetails!.hasMinimumRequiredData) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF9800).withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              'Structured Business & Operations information is '
              'incomplete. This section cannot progress until the '
              'required business data is available.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFE65100),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canUpdateWorkshop
                ? () {
                    _updateWorkshopStatus(context, application);
                  }
                : null,
            icon: Icon(
              workshopStatus == PartnerOnboardingSectionStatus.verified
                  ? Icons.verified_rounded
                  : Icons.store_outlined,
            ),
            label: Text(_workshopActionLabel(workshopStatus)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Business & Operations is the first structured '
          'onboarding section. Additional Partner-specific '
          'sections will be enabled through the common '
          'Partner foundation.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildKycCard(BuildContext context, PartnerApplication application) {
    final canStartKyc =
        application.status == PartnerApplicationStatus.underReview &&
        application.kycStatus == PartnerKycStatus.notStarted;

    return _ReviewSection(
      title: 'KYC and Verification',
      icon: Icons.verified_user_outlined,
      children: [
        _ReviewDetail(
          label: 'KYC status',
          value: _kycStatusLabel(application.kycStatus),
        ),
        _ReviewDetail(
          label: 'Verified by',
          value: application.kycVerifiedByUid?.trim().isNotEmpty == true
              ? application.kycVerifiedByUid!.trim()
              : 'Not assigned',
        ),
        _ReviewDetail(
          label: 'Verification date',
          value: application.kycVerifiedAt == null
              ? 'Not available'
              : _formatDateTime(application.kycVerifiedAt!),
        ),
        if (application.kycUpdatedAt != null)
          _ReviewDetail(
            label: 'KYC updated',
            value: _formatDateTime(application.kycUpdatedAt!),
          ),
        if (application.kycFailureReason?.trim().isNotEmpty == true)
          _ReviewDetail(
            label: 'Failure reason',
            value: application.kycFailureReason!.trim(),
          ),
        const SizedBox(height: 8),

        if (application.kycStatus == PartnerKycStatus.underVerification) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                _markKycVerified(context, application);
              },
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Mark KYC Verified'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _markKycFailed(context, application);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              icon: const Icon(Icons.gpp_bad_outlined),
              label: const Text('Mark KYC Failed'),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStartKyc
                  ? () {
                      _startKycVerification(context, application);
                    }
                  : null,
              icon: const Icon(Icons.manage_search_outlined),
              label: Text(
                application.kycStatus == PartnerKycStatus.verified
                    ? 'KYC Verified'
                    : application.kycStatus == PartnerKycStatus.failed
                    ? 'KYC Failed'
                    : 'Start KYC Verification',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _startKycVerification(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start KYC Verification'),
          content: const Text(
            'KYC will move from Not Started to Under Verification.\n\n'
            'This action does not verify KYC, approve the application, '
            'or activate a Partner profile.',
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
              child: const Text('Start Verification'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await PartnerService.startKycVerification(applicationId: application.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC verification started'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start KYC verification.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markKycVerified(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark KYC Verified'),
          content: const Text(
            'Confirm that the required identity and business documents '
            'have been successfully verified.\n\n'
            'This action does not approve or activate the Partner profile.',
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
              child: const Text('Mark Verified'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await PartnerService.markKycVerified(applicationId: application.id);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC marked as verified'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to verify KYC.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markKycFailed(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark KYC Failed'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: reasonController,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Customer-visible failure reason',
                hintText:
                    'Explain which identity or business verification failed.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final reason = value?.trim() ?? '';

                if (reason.isEmpty) {
                  return 'KYC failure reason is required';
                }

                if (reason.length < 10) {
                  return 'Please provide a clear KYC failure reason';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(dialogContext, reasonController.text.trim());
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Mark KYC Failed'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
    });

    if (reason == null || reason.isEmpty || !context.mounted) {
      return;
    }

    try {
      await PartnerService.markKycFailed(
        applicationId: application.id,
        reason: reason,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC marked as failed'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to fail KYC.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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

  Future<void> _requestChanges(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final instructionsController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final instructions = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request Application Changes'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: instructionsController,
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Required corrections',
                hintText: 'Explain what information or documents are required.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Correction instructions are required';
                }

                if (value.trim().length < 10) {
                  return 'Please provide clear correction instructions';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  instructionsController.text.trim(),
                );
              },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      instructionsController.dispose();
    });

    if (instructions == null || instructions.isEmpty || !context.mounted) {
      return;
    }

    try {
      await PartnerService.requestChanges(
        applicationId: application.id,
        instructions: instructions,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correction request sent to the applicant'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to request changes.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectApplication(
    BuildContext context,
    PartnerApplication application,
  ) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Partner Application'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Rejection is a final decision for this application. '
                  'Use Request Changes when the applicant can correct '
                  'missing or incomplete information.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Customer-visible rejection reason',
                    hintText:
                        'Explain clearly why the application cannot be approved.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final reason = value?.trim() ?? '';

                    if (reason.isEmpty) {
                      return 'Rejection reason is required';
                    }

                    if (reason.length < 10) {
                      return 'Please provide a clear rejection reason';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.pop(dialogContext, reasonController.text.trim());
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reject Application'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
    });

    if (reason == null || reason.isEmpty || !context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Rejection'),
          content: const Text(
            'This application will be marked as Rejected and '
            'the applicant will see the rejection reason.\n\n'
            'No Partner profile will be created.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Confirm Rejection'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await PartnerService.rejectApplication(
        applicationId: application.id,
        reason: reason,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner application rejected'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to reject application.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _approveApplication(
    BuildContext context,
    PartnerApplication application,
  ) async {
    try {
      await PartnerProfileActivationService.approveAndActivate(
        applicationId: application.id,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner application approved and profile activated'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to approve application.\n$error'),
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
            onPressed:
                application.status == PartnerApplicationStatus.underReview
                ? () {
                    _requestChanges(context, application);
                  }
                : null,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Request Changes'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                application.status == PartnerApplicationStatus.underReview
                ? () {
                    _rejectApplication(context, application);
                  }
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject Application'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                application.status == PartnerApplicationStatus.underReview &&
                    application.kycStatus == PartnerKycStatus.verified
                ? () {
                    _approveApplication(context, application);
                  }
                : null,
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

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: CATEGORY ICON
  // ==========================================================================
  static IconData _partnerTypeIcon(PartnerType type) {
    switch (type) {
      case PartnerType.tailor:
        return Icons.content_cut_rounded;

      case PartnerType.measurementPartner:
        return Icons.straighten_rounded;

      case PartnerType.boutique:
        return Icons.storefront_outlined;

      case PartnerType.designer:
        return Icons.design_services_outlined;

      case PartnerType.fabricSupplier:
        return Icons.local_mall_outlined;

      case PartnerType.printing:
        return Icons.print_outlined;

      case PartnerType.embroidery:
        return Icons.auto_awesome_outlined;

      case PartnerType.rental:
        return Icons.checkroom_outlined;

      case PartnerType.accessories:
        return Icons.watch_outlined;

      case PartnerType.brand:
        return Icons.business_outlined;

      case PartnerType.deliveryPartner:
        return Icons.delivery_dining_outlined;

      case PartnerType.doorstepServices:
        return Icons.home_repair_service_outlined;

      case PartnerType.other:
        return Icons.handshake_outlined;
    }
  }

  static String _partnerTypeLabel(PartnerType type) {
    switch (type) {
      case PartnerType.tailor:
        return 'Tailor';

      // MEASUREMENT PARTNER EXTENSION
      // Keep an explicit case so newly added Partner types remain
      // protected by Dart's exhaustive-switch analyzer validation.
      case PartnerType.measurementPartner:
        return 'Measurement Partner';

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

  static PartnerOnboardingSectionStatus? _nextWorkshopStatus(
    PartnerOnboardingSectionStatus currentStatus,
  ) {
    switch (currentStatus) {
      case PartnerOnboardingSectionStatus.notStarted:
        return PartnerOnboardingSectionStatus.inProgress;

      case PartnerOnboardingSectionStatus.inProgress:
        return PartnerOnboardingSectionStatus.completed;

      case PartnerOnboardingSectionStatus.completed:
        return PartnerOnboardingSectionStatus.verified;

      case PartnerOnboardingSectionStatus.changesRequired:
        return PartnerOnboardingSectionStatus.inProgress;

      case PartnerOnboardingSectionStatus.verified:
        return null;
    }
  }

  static String _workshopActionLabel(
    PartnerOnboardingSectionStatus currentStatus,
  ) {
    switch (currentStatus) {
      case PartnerOnboardingSectionStatus.notStarted:
        return 'Start Workshop Details';

      case PartnerOnboardingSectionStatus.inProgress:
        return 'Mark Workshop Details Completed';

      case PartnerOnboardingSectionStatus.completed:
        return 'Verify Workshop Details';

      case PartnerOnboardingSectionStatus.changesRequired:
        return 'Resume Workshop Details';

      case PartnerOnboardingSectionStatus.verified:
        return 'Workshop Details Verified';
    }
  }

  static String _onboardingStatusLabel(PartnerOnboardingSectionStatus status) {
    switch (status) {
      case PartnerOnboardingSectionStatus.notStarted:
        return 'Not Started';

      case PartnerOnboardingSectionStatus.inProgress:
        return 'In Progress';

      case PartnerOnboardingSectionStatus.completed:
        return 'Completed';

      case PartnerOnboardingSectionStatus.verified:
        return 'Verified';

      case PartnerOnboardingSectionStatus.changesRequired:
        return 'Changes Required';
    }
  }

  static String _onboardingSectionLabel(PartnerOnboardingSection section) {
    switch (section) {
      case PartnerOnboardingSection.basicDetails:
        return 'Basic details';

      case PartnerOnboardingSection.workshopDetails:
        return 'Workshop details';

      case PartnerOnboardingSection.servicesAndSpecialization:
        return 'Services and specialization';

      case PartnerOnboardingSection.capacityAndAvailability:
        return 'Capacity and availability';

      case PartnerOnboardingSection.measurementPreferences:
        return 'Measurement preferences';

      case PartnerOnboardingSection.qualityAndRework:
        return 'Quality and rework';

      case PartnerOnboardingSection.expectedRates:
        return 'Expected rate information';

      case PartnerOnboardingSection.documentsAndDeclaration:
        return 'Documents and declaration';

      case PartnerOnboardingSection.commercialTerms:
        return 'Commercial terms';
    }
  }

  static String _kycStatusLabel(PartnerKycStatus status) {
    switch (status) {
      case PartnerKycStatus.notStarted:
        return 'Not Started';

      case PartnerKycStatus.pendingDocuments:
        return 'Pending Documents';

      case PartnerKycStatus.underVerification:
        return 'Under Verification';

      case PartnerKycStatus.verified:
        return 'Verified';

      case PartnerKycStatus.failed:
        return 'Failed';

      case PartnerKycStatus.expired:
        return 'Expired';
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

class _OnboardingSummaryValue extends StatelessWidget {
  const _OnboardingSummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
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
            value,
            style: AppTextStyles.titleLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
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

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({required this.label, required this.status});

  final String label;
  final PartnerOnboardingSectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: status == PartnerOnboardingSectionStatus.notStarted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontWeight: status == PartnerOnboardingSectionStatus.notStarted
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(status),
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(PartnerOnboardingSectionStatus status) {
    switch (status) {
      case PartnerOnboardingSectionStatus.notStarted:
        return 'Not Started';

      case PartnerOnboardingSectionStatus.inProgress:
        return 'In Progress';

      case PartnerOnboardingSectionStatus.completed:
        return 'Completed';

      case PartnerOnboardingSectionStatus.verified:
        return 'Verified';

      case PartnerOnboardingSectionStatus.changesRequired:
        return 'Changes Required';
    }
  }

  static IconData _statusIcon(PartnerOnboardingSectionStatus status) {
    switch (status) {
      case PartnerOnboardingSectionStatus.notStarted:
        return Icons.radio_button_unchecked_rounded;

      case PartnerOnboardingSectionStatus.inProgress:
        return Icons.timelapse_rounded;

      case PartnerOnboardingSectionStatus.completed:
        return Icons.check_circle_outline_rounded;

      case PartnerOnboardingSectionStatus.verified:
        return Icons.verified_rounded;

      case PartnerOnboardingSectionStatus.changesRequired:
        return Icons.edit_note_rounded;
    }
  }

  static Color _statusColor(PartnerOnboardingSectionStatus status) {
    switch (status) {
      case PartnerOnboardingSectionStatus.notStarted:
        return AppColors.textHint;

      case PartnerOnboardingSectionStatus.inProgress:
        return const Color(0xFFFF9800);

      case PartnerOnboardingSectionStatus.completed:
        return const Color(0xFF4CAF50);

      case PartnerOnboardingSectionStatus.verified:
        return const Color(0xFF2196F3);

      case PartnerOnboardingSectionStatus.changesRequired:
        return AppColors.error;
    }
  }
}
