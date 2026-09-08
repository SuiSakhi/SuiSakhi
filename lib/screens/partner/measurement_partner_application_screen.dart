import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/metadata/measurement_partner_capability_metadata.dart';
import '../../models/address_details.dart';
import '../../models/measurement_partner_details.dart';
import '../../models/operating_schedule.dart';
import '../../models/partner_application.dart';
import '../../models/partner_capability_selection.dart';
import '../../services/measurement_partner_application_service.dart';
import '../../services/partner_service.dart';
import '../../widgets/address/address_form_section.dart';
import '../../widgets/capability/capability_multi_selector.dart';
import '../../widgets/partner/partner_basic_details_section.dart';
import '../../widgets/schedule/operating_schedule_field.dart';

// ============================================================================
// MEASUREMENT PARTNER APPLICATION
// ============================================================================
//
// This screen demonstrates the reusable Partner application foundation.
//
// COMMON PARTNER FOUNDATION:
//
// - Basic Details
// - Address and service coverage
// - Operating Schedule
// - Capability selection
// - Form validation
//
// MEASUREMENT PARTNER EXTENSION:
//
// - Measurement service capabilities
// - Measurements per day
// - Home visits per day
// - Video sessions per day
// - Maximum travel distance
// - Measurement service notes
//
// IMPORTANT:
//
// This milestone creates or resumes a Measurement Partner draft and saves
// common Basic Details.
//
// Measurement-specific Address, Schedule, Capabilities, Capacity, and Notes
// remain UI-only until extension persistence is connected.
//
// It does not:
// - Submit a Partner application.
// - Change KYC.
// - Activate a Partner profile.
// - Change the working Tailor workflow.
//
// MEASUREMENT AUTHORITY:
//
// A Measurement Partner may collect and record measurement inputs.
// Only the assigned Tailor confirms the final measurement before stitching.
// ============================================================================

class MeasurementPartnerApplicationScreen extends StatefulWidget {
  const MeasurementPartnerApplicationScreen({super.key});

  @override
  State<MeasurementPartnerApplicationScreen> createState() {
    return _MeasurementPartnerApplicationScreenState();
  }
}

class _MeasurementPartnerApplicationScreenState
    extends State<MeasurementPartnerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: BASIC DETAILS
  // ==========================================================================

  final _contactNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION: CAPACITY AND NOTES
  // ==========================================================================

  final _measurementsPerDayController = TextEditingController();
  final _homeVisitsPerDayController = TextEditingController();
  final _videoSessionsPerDayController = TextEditingController();
  final _maximumTravelDistanceController = TextEditingController();
  final _serviceAreaPincodesController = TextEditingController();
  final _serviceNotesController = TextEditingController();

  AddressDetails _businessAddress = const AddressDetails();
  OperatingSchedule _operatingSchedule = const OperatingSchedule();

  PartnerCapabilitySelection _capabilitySelection =
      const PartnerCapabilitySelection();

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: APPLICATION LIFECYCLE
  // ==========================================================================

  PartnerApplication? _application;

  String? _accountId;
  String? _customerProfileId;

  bool _loadingFoundation = true;
  bool _saving = false;

  String? _foundationLoadError;
  String? _reusedPartnerCategoryLabel;

  bool get _isEditable {
    final status = _application?.status;

    return status == PartnerApplicationStatus.draft ||
        status == PartnerApplicationStatus.changesRequested;
  }

  bool get _isUnderAdminReview {
    final status = _application?.status;

    return status == PartnerApplicationStatus.submitted ||
        status == PartnerApplicationStatus.underReview;
  }

  bool get _canSaveDraft {
    return _isEditable &&
        !_saving &&
        _contactNameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().isNotEmpty;
  }

  bool get _canSubmit {
    return _isEditable &&
        !_saving &&
        _contactNameController.text.trim().isNotEmpty &&
        _businessNameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().isNotEmpty;
  }
  // ==========================================================================
  // COMMON PARTNER FOUNDATION: STATUS PRESENTATION
  // ==========================================================================

  String get _applicationStatusLabel {
    switch (_application?.status) {
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
        return 'Not Approved';
      case PartnerApplicationStatus.suspended:
        return 'Suspended';
      case PartnerApplicationStatus.inactive:
        return 'Inactive';
      case null:
        return 'Loading';
    }
  }

  String get _applicationHeaderMessage {
    switch (_application?.status) {
      case PartnerApplicationStatus.submitted:
        return 'The Measurement Partner application has been submitted '
            'and is waiting for SuiSakhi Admin review.';

      case PartnerApplicationStatus.underReview:
        return 'SuiSakhi Admin is reviewing the application. Editing is '
            'temporarily unavailable during review.';

      case PartnerApplicationStatus.changesRequested:
        final instructions = _application?.reviewNotes?.trim();

        if (instructions != null && instructions.isNotEmpty) {
          return 'Admin instructions: $instructions';
        }

        return 'SuiSakhi Admin has requested additional information. '
            'Update the application, save it, and submit it again.';

      case PartnerApplicationStatus.approved:
        return 'The Measurement Partner application is approved. '
            'Partner-profile activation is managed independently from '
            'other Partner businesses under this account.';

      case PartnerApplicationStatus.rejected:
        final reason = _application?.rejectionReason?.trim();

        if (reason != null && reason.isNotEmpty) {
          return 'Reason: $reason';
        }

        return 'This Measurement Partner application was not approved. '
            'Contact SuiSakhi Helpdesk if clarification is required.';

      case PartnerApplicationStatus.suspended:
        return 'This Measurement Partner application is currently suspended.';

      case PartnerApplicationStatus.inactive:
        return 'This Measurement Partner application is currently inactive.';

      case PartnerApplicationStatus.draft:
      case null:
        return 'Save the application as a draft or submit it for independent '
            'Admin and KYC review when the information is ready.';
    }
  }

  @override
  void initState() {
    super.initState();

    // COMMON PARTNER FOUNDATION:
    // Load authenticated account and reusable Partner information.
    _initializeCommonPartnerFoundation();
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: ACCOUNT AND PROFILE HYDRATION
  // ==========================================================================
  //
  // Source priority for this UI milestone:
  //
  // 1. Firebase authenticated mobile
  // 2. Active Customer profile
  // 3. Most recently updated existing Partner application
  //
  // Reused business, address, and schedule values remain editable.
  // Authenticated mobile always remains read-only.
  //
  // This method does not create or update a Measurement Partner application.
  // ==========================================================================
  Future<void> _initializeCommonPartnerFoundation() async {
    var loadStage = 'authenticated account';
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError(
          'Please sign in again before starting a Partner application.',
        );
      }

      final phone = user.phoneNumber?.trim();

      if (phone == null || phone.isEmpty) {
        throw StateError(
          'Your authenticated mobile number could not be found.',
        );
      }

      final accountId = await AppState.instance.fetchAccountIdForMobile(phone);

      if (accountId == null || accountId.trim().isEmpty) {
        throw StateError('Your SuiSakhi account could not be resolved.');
      }

      final profiles = await AppState.instance.fetchActiveProfilesForAccount(
        accountId,
      );

      Map<String, dynamic>? customerProfile;

      for (final profile in profiles) {
        final role = (profile['role'] ?? '').toString();

        if (role == 'customer') {
          customerProfile = profile;
          break;
        }
      }

      final customerProfileId =
          customerProfile?['profileId']?.toString().trim() ??
          customerProfile?['docId']?.toString().trim();

      if (customerProfileId == null || customerProfileId.isEmpty) {
        throw StateError('Your active Customer profile could not be resolved.');
      }

      final profileName =
          (customerProfile?['displayName'] ??
                  customerProfile?['name'] ??
                  AppState.instance.displayName)
              .toString()
              .trim();

      final profileEmail = (customerProfile?['email'] ?? user.email ?? '')
          .toString()
          .trim();

      // ACCOUNT-LEVEL FOUNDATION:
      // These values belong to the signed-in SuiSakhi account.
      _contactNameController.text = profileName;
      _mobileController.text = phone;
      _emailController.text = profileEmail;

      // CROSS-PARTNER FOUNDATION REUSE:
      // Reuse common information from another application under the same
      // account. No Firestore write occurs during this hydration.
      loadStage = 'existing Partner applications';
      final existingApplications = await PartnerService.watchMyApplications(
        accountId: accountId,
        customerProfileId: customerProfileId,
      ).first;

      final reusableApplication = _latestReusableApplication(
        existingApplications,
      );

      if (reusableApplication != null) {
        _hydrateFromExistingApplication(reusableApplication);
      }

      // ======================================================================
      // MEASUREMENT PARTNER DRAFT CREATION OR RESUME
      // ======================================================================
      //
      // PartnerService.createDraft() returns the latest existing Measurement
      // Partner application for the same account/profile when one already
      // exists. Otherwise, it creates a new draft.
      //
      // Reused Tailor or other Partner information acts only as initial data.
      // Existing Measurement Partner values always take priority.
      // ======================================================================
      loadStage = 'Measurement Partner draft creation';
      final application = await PartnerService.createDraft(
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.measurementPartner,
        contactName: _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text,
        businessName: _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text,
        mobileE164: phone,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text,
      );

      // Existing Measurement Partner draft values must override reusable
      // values from Tailor or another Partner category.
      _contactNameController.text =
          application.contactName ??
          (_contactNameController.text.trim().isEmpty
              ? profileName
              : _contactNameController.text);

      _businessNameController.text =
          application.businessName ?? _businessNameController.text;

      _mobileController.text = application.mobileE164 ?? phone;

      _emailController.text =
          application.email ??
          (_emailController.text.trim().isEmpty
              ? profileEmail
              : _emailController.text);

      // MEASUREMENT PARTNER EXTENSION:
      // Load the complete saved extension after common cross-category reuse.
      // Saved Measurement Partner values override reusable Tailor values.
      final measurementPartnerDetails =
          MeasurementPartnerDetails.fromOnboardingData(
            application.onboardingData,
          );

      _hydrateMeasurementPartnerDetails(measurementPartnerDetails);

      if (!mounted) {
        return;
      }

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;
        _application = application;
        _loadingFoundation = false;
        _foundationLoadError = null;
      });
    } catch (error) {
      debugPrint('[MeasurementPartnerLoad] failedStage=$loadStage');

      debugPrint('[MeasurementPartnerLoad] error=$error');

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFoundation = false;
        _foundationLoadError = 'Unable to complete $loadStage.\n$error';
      });
    }
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: REUSE SOURCE SELECTION
  // ==========================================================================
  PartnerApplication? _latestReusableApplication(
    List<PartnerApplication> applications,
  ) {
    final reusableApplications = applications
        .where(
          (application) =>
              application.partnerType != PartnerType.measurementPartner,
        )
        .toList();

    if (reusableApplications.isEmpty) {
      return null;
    }

    reusableApplications.sort(
      (first, second) => second.updatedAt.compareTo(first.updatedAt),
    );

    return reusableApplications.first;
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: CROSS-CATEGORY HYDRATION
  // ==========================================================================
  void _hydrateFromExistingApplication(PartnerApplication application) {
    final existingContactName = application.contactName?.trim() ?? '';
    final existingBusinessName = application.businessName?.trim() ?? '';
    final existingEmail = application.email?.trim() ?? '';

    if (_contactNameController.text.trim().isEmpty &&
        existingContactName.isNotEmpty) {
      _contactNameController.text = existingContactName;
    }

    if (existingBusinessName.isNotEmpty) {
      _businessNameController.text = existingBusinessName;
    }

    if (_emailController.text.trim().isEmpty && existingEmail.isNotEmpty) {
      _emailController.text = existingEmail;
    }

    // TAILOR-SPECIFIC SOURCE ADAPTER:
    //
    // Tailor Workshop Details currently hold address and schedule values that
    // can seed another Partner-category application. This is reuse only.
    // The existing Tailor application is not changed.
    final workshopDetails = application.workshopDetails;

    if (workshopDetails != null) {
      _businessAddress = AddressDetails(
        addressLine1: workshopDetails.addressLine1,
        addressLine2: workshopDetails.addressLine2,
        locality: workshopDetails.locality,
        cityName: workshopDetails.city,
        stateName: workshopDetails.state,
        pincode: workshopDetails.pincode,
        countryCode: 'IN',
        placeId: workshopDetails.placeId,
        latitude: workshopDetails.latitude,
        longitude: workshopDetails.longitude,
      );

      _operatingSchedule = OperatingSchedule(
        operatingDays: workshopDetails.operatingDays,
        openingTime: workshopDetails.openingTime,
        closingTime: workshopDetails.closingTime,
      );

      _serviceAreaPincodesController.text = workshopDetails.serviceAreaPincodes
          .join(', ');
    }

    _reusedPartnerCategoryLabel = _partnerTypeLabel(application.partnerType);
  }

  String _partnerTypeLabel(PartnerType partnerType) {
    switch (partnerType) {
      case PartnerType.tailor:
        return 'Tailor';
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

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION: LOAD SAVED OPERATIONAL DETAILS
  // ==========================================================================
  //
  // Existing Measurement Partner values take priority over common information
  // reused from Tailor or another Partner application.
  // ==========================================================================
  void _hydrateMeasurementPartnerDetails(MeasurementPartnerDetails details) {
    if (!details.hasOperationalInformation) {
      return;
    }

    _businessAddress = details.serviceAddress;
    _operatingSchedule = details.operatingSchedule;
    _capabilitySelection = details.capabilitySelection;

    _serviceAreaPincodesController.text = details.normalizedServiceAreaPincodes
        .join(', ');

    _maximumTravelDistanceController.text =
        details.maximumTravelDistanceKm?.toString() ?? '';

    _measurementsPerDayController.text =
        details.measurementsPerDay?.toString() ?? '';

    _homeVisitsPerDayController.text =
        details.homeVisitsPerDay?.toString() ?? '';

    _videoSessionsPerDayController.text =
        details.videoSessionsPerDay?.toString() ?? '';

    _serviceNotesController.text = details.serviceNotes ?? '';
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _businessNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();

    _measurementsPerDayController.dispose();
    _homeVisitsPerDayController.dispose();
    _videoSessionsPerDayController.dispose();
    _maximumTravelDistanceController.dispose();
    _serviceAreaPincodesController.dispose();
    _serviceNotesController.dispose();

    super.dispose();
  }

  String? _optionalNonNegativeIntegerValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return null;
    }

    final parsedValue = int.tryParse(normalizedValue);

    if (parsedValue == null || parsedValue < 0) {
      return 'Enter zero or a positive whole number';
    }

    return null;
  }

  String? _optionalPositiveNumberValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';

    if (normalizedValue.isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(normalizedValue);

    if (parsedValue == null || parsedValue <= 0) {
      return 'Enter a positive number or leave blank';
    }

    return null;
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: APPLICATION STATUS HEADER
  // ==========================================================================

  Widget _buildApplicationHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF00897B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x1A00897B),
            child: Icon(Icons.straighten_rounded, color: Color(0xFF00897B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Measurement Partner',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Application status: $_applicationStatusLabel',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF00695C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _applicationHeaderMessage,
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

  Widget _buildIntroductionCard() {
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
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x1A00897B),
            child: Icon(Icons.straighten_rounded, color: Color(0xFF00897B)),
          ),
          const SizedBox(height: 14),
          Text('Measurement Partner', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Provide measurement-only, home measurement, '
            'video-assisted measurement, reference-garment support, '
            'or measurement with pickup services.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Measurement collection does not replace the assigned '
                    'Tailor final confirmation. Cutting or stitching can '
                    'begin only after the assigned Tailor confirms the final '
                    'measurement.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceLocationCard() {
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
          Text(
            'Service Location & Availability',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Add the primary operating location, coverage area and '
            'availability for measurement-service assignments.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // COMMON PARTNER FOUNDATION: ADDRESS
          AddressFormSection(
            key: ValueKey(
              'measurement-partner-address-'
              '${_businessAddress.stateCode ?? _businessAddress.stateName ?? 'none'}-'
              '${_businessAddress.cityCode ?? _businessAddress.cityName ?? 'none'}',
            ),
            metadataProvider: IndiaAddressMetadata.instance,
            initialValue: _businessAddress,
            enabled: _isEditable,
            sectionTitle: 'Primary Service Location',
            addressLine1Label: 'Primary service address',
            addressLine2Label: 'Address line 2',
            localityLabel: 'Locality or area',
            stateLabel: 'State',
            cityLabel: 'City',
            pincodeLabel: 'Pincode',
            addressLine1Required: false,
            addressLine2Required: false,
            localityRequired: false,
            landmarkRequired: false,
            stateRequired: false,
            cityRequired: false,
            pincodeRequired: false,
            showAddressLine2: true,
            showLocality: true,
            showLandmark: false,
            onChanged: (address) {
              _businessAddress = address;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _serviceAreaPincodesController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Service-area pincodes',
              hintText: 'Example: 411001, 411002',
              prefixIcon: Icon(Icons.route_outlined),
              border: OutlineInputBorder(),
              helperText: 'Optional. Separate multiple pincodes with commas.',
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _maximumTravelDistanceController,
            readOnly: !_isEditable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Maximum travel distance',
              hintText: 'Optional',
              suffixText: 'km',
              prefixIcon: Icon(Icons.social_distance_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _optionalPositiveNumberValidator,
          ),
          const SizedBox(height: 18),

          // COMMON PARTNER FOUNDATION: OPERATING SCHEDULE
          OperatingScheduleField(
            key: ValueKey(
              'measurement-partner-schedule-'
              '${_operatingSchedule.normalizedOperatingDays.join('-')}-'
              '${_operatingSchedule.openingTime ?? 'none'}-'
              '${_operatingSchedule.closingTime ?? 'none'}',
            ),
            initialValue: _operatingSchedule,
            enabled: _isEditable,
            operatingDaysRequired: false,
            openingTimeRequired: false,
            closingTimeRequired: false,
            requireClosingAfterOpening: true,
            sectionTitle: 'Operating Schedule',
            operatingDaysLabel: 'Available days',
            openingTimeLabel: 'Available from',
            closingTimeLabel: 'Available until',
            onChanged: (schedule) {
              _operatingSchedule = schedule;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
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
          Text('Measurement Services', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Select the measurement and pickup services currently offered. '
            'All selections are optional during Phase 1.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // MEASUREMENT PARTNER EXTENSION: CAPABILITIES
          CapabilityMultiSelector(
            key: ValueKey(
              'measurement-partner-capabilities-'
              '${_capabilitySelection.normalizedCapabilityCodes.join('-')}-'
              '${_capabilitySelection.normalizedAdditionalDescriptions.join('-')}',
            ),
            metadataProvider: MeasurementPartnerCapabilityMetadata.instance,
            partnerCategoryCode:
                MeasurementPartnerCapabilityMetadata.categoryCode,
            initialValue: _capabilitySelection,
            enabled: _isEditable,
            minimumSelectionCount: 0,
            sectionTitle: 'Available Services',
            sectionDescription:
                'Verification indicators mean that Admin review may be '
                'required before assignment.',
            showOtherExpertise: true,

            // PHASE-1 DRAFT SIMPLIFICATION:
            // Other service description is optional while saving a draft.
            requireOtherExpertiseDescription: false,

            otherExpertiseLabel: 'Other Measurement Service',
            otherExpertiseHint: 'Describe another measurement-related service',
            onChanged: (selection) {
              _capabilitySelection = selection;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityCard() {
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
          Text('Capacity & Service Notes', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Capacity values are optional and may be updated later. '
            'Admin may use these values for service assignment planning.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _measurementsPerDayController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Measurements per day',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.straighten_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _optionalNonNegativeIntegerValidator,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _homeVisitsPerDayController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Home visits per day',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.home_work_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _optionalNonNegativeIntegerValidator,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _videoSessionsPerDayController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Video sessions per day',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.video_call_outlined),
              border: OutlineInputBorder(),
            ),
            validator: _optionalNonNegativeIntegerValidator,
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _serviceNotesController,
            readOnly: !_isEditable,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Additional service notes',
              hintText:
                  'Optional operating instructions, limitations or support',
              prefixIcon: Icon(Icons.notes_outlined),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // MEASUREMENT PARTNER EXTENSION: BUILD SAVE PAYLOAD
  // ==========================================================================

  MeasurementPartnerDetails _buildMeasurementPartnerDetails() {
    return MeasurementPartnerDetails(
      serviceAddress: _businessAddress,
      serviceAreaPincodes: _commaSeparatedValues(
        _serviceAreaPincodesController.text,
      ),
      maximumTravelDistanceKm: _positiveDoubleOrNull(
        _maximumTravelDistanceController.text,
      ),
      operatingSchedule: _operatingSchedule,
      capabilitySelection: _capabilitySelection,
      measurementsPerDay: _nonNegativeIntOrNull(
        _measurementsPerDayController.text,
      ),
      homeVisitsPerDay: _nonNegativeIntOrNull(_homeVisitsPerDayController.text),
      videoSessionsPerDay: _nonNegativeIntOrNull(
        _videoSessionsPerDayController.text,
      ),
      serviceNotes: _normalizedOptionalText(_serviceNotesController.text),
    );
  }

  List<String> _commaSeparatedValues(String rawValue) {
    final values = <String>{};

    for (final rawItem in rawValue.split(',')) {
      final normalizedValue = rawItem.trim();

      if (normalizedValue.isNotEmpty) {
        values.add(normalizedValue);
      }
    }

    return values.toList(growable: false);
  }

  int? _nonNegativeIntOrNull(String rawValue) {
    final normalizedValue = rawValue.trim();

    if (normalizedValue.isEmpty) {
      return null;
    }

    final parsedValue = int.tryParse(normalizedValue);

    if (parsedValue == null || parsedValue < 0) {
      return null;
    }

    return parsedValue;
  }

  double? _positiveDoubleOrNull(String rawValue) {
    final normalizedValue = rawValue.trim();

    if (normalizedValue.isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(normalizedValue);

    if (parsedValue == null || parsedValue <= 0) {
      return null;
    }

    return parsedValue;
  }

  String? _normalizedOptionalText(String rawValue) {
    final normalizedValue = rawValue.trim();

    return normalizedValue.isEmpty ? null : normalizedValue;
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: SAVE DRAFT
  // ==========================================================================
  // Saves common Basic Details and the complete Measurement Partner extension.
  //
  // This method does not submit the application, modify KYC, or activate a
  // Partner profile.
  // ==========================================================================
  Future<void> _saveDraft() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final application = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (application == null || accountId == null || customerProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application context is unavailable. Please reopen the form.',
          ),
          backgroundColor: AppColors.error,
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // COMMON PARTNER FOUNDATION: BASIC DETAILS
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      // MEASUREMENT PARTNER EXTENSION:
      // Save every visible operational section under
      // onboardingData.extensions.measurementPartner.
      final measurementPartnerDetails = _buildMeasurementPartnerDetails();

      await MeasurementPartnerApplicationService.saveDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        details: measurementPartnerDetails,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Measurement Partner draft saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[MeasurementPartnerSave] error=$error');

      debugPrintStack(
        label: '[MeasurementPartnerSave] stackTrace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save Measurement Partner draft.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: SUBMIT FOR REVIEW
  // ==========================================================================
  //
  // Safe order:
  //
  // 1. Save common Basic Details.
  // 2. Save complete Measurement Partner operational details.
  // 3. Submit the application for independent Admin and KYC review.
  //
  // Submission does not verify KYC or activate a Partner profile.
  // ==========================================================================
  Future<void> _submitForReview() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_businessNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the business or service name before submitting.',
          ),
          backgroundColor: AppColors.error,
        ),
      );

      return;
    }

    final application = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (application == null || accountId == null || customerProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application context is unavailable. Please reopen the form.',
          ),
          backgroundColor: AppColors.error,
        ),
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    var submitStage = 'Basic Details';

    try {
      // COMMON PARTNER FOUNDATION
      submitStage = 'Basic Details';

      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      // MEASUREMENT PARTNER EXTENSION
      submitStage = 'Measurement Partner operational details';

      await MeasurementPartnerApplicationService.saveDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        details: _buildMeasurementPartnerDetails(),
      );

      // COMMON PARTNER LIFECYCLE
      submitStage = 'application submission';

      await PartnerService.submitApplication(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Measurement Partner application submitted for Admin and KYC review',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (error, stackTrace) {
      debugPrint('[MeasurementPartnerSubmit] failedStage=$submitStage');
      debugPrint('[MeasurementPartnerSubmit] error=$error');
      debugPrintStack(
        label: '[MeasurementPartnerSubmit] stackTrace',
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to complete $submitStage.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _applyAgain() async {
    final rejectedApplication = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (rejectedApplication == null ||
        rejectedApplication.status != PartnerApplicationStatus.rejected) {
      return;
    }

    if (accountId == null ||
        accountId.trim().isEmpty ||
        customerProfileId == null ||
        customerProfileId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The account or Customer profile could not be resolved.',
          ),
        ),
      );

      return;
    }

    final shouldCreate =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Apply Again?'),
              content: const Text(
                'A new Measurement Partner application will be '
                'created using the information from the rejected '
                'application.\n\n'
                'You can review and modify the copied information, '
                'save the application as a draft, or submit it for '
                'Admin review.\n\n'
                'The rejected application will remain unchanged '
                'for audit history.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Create New Application'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldCreate || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final newApplication = await PartnerService.reapplyFromRejected(
        rejectedApplicationId: rejectedApplication.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );

      if (!mounted) {
        return;
      }

      _application = newApplication;

      _contactNameController.text = newApplication.contactName ?? '';
      _businessNameController.text = newApplication.businessName ?? '';
      _mobileController.text = newApplication.mobileE164 ?? '';
      _emailController.text = newApplication.email ?? '';

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A new Measurement Partner application has been '
            'created. Previous information was copied. Please '
            'review it before submitting.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create a new application: $error')),
      );
    }
  }

  void _continueLater() {
    context.pop();
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: APPLICATION ACTIONS
  // ==========================================================================
  Widget _buildActions() {
    final status = _application?.status;

    if (status == PartnerApplicationStatus.rejected) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _applyAgain,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(
                _saving ? 'Creating New Application...' : 'Apply Again',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _continueLater,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Partner Opportunities'),
            ),
          ),
        ],
      );
    }

    if (status == PartnerApplicationStatus.approved ||
        status == PartnerApplicationStatus.suspended ||
        status == PartnerApplicationStatus.inactive) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : _continueLater,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Partner Opportunities'),
        ),
      );
    }

    if (_isUnderAdminReview) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : _continueLater,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back to Partner Opportunities'),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _canSaveDraft ? _saveDraft : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving Draft...' : 'Save Draft'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submitForReview : null,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              status == PartnerApplicationStatus.changesRequested
                  ? 'Resubmit For Review'
                  : 'Submit For Review',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _continueLater,
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Continue Later'),
          ),
        ),
      ],
    );
  }

  Widget _buildReusedDataNotice() {
    final sourceLabel = _reusedPartnerCategoryLabel;

    if (sourceLabel == null || sourceLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00897B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.content_copy_outlined,
            color: Color(0xFF00897B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Common details were reused from the existing '
              '$sourceLabel application. Keep these values or update the '
              'business name, address and availability for a new firm.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFoundation) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Measurement Partner Application'),
          centerTitle: true,
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_foundationLoadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Measurement Partner Application'),
          centerTitle: true,
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 14),
                Text(
                  'Unable to load your Partner information.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _foundationLoadError!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingFoundation = true;
                      _foundationLoadError = null;
                    });

                    _initializeCommonPartnerFoundation();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Measurement Partner Application'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildApplicationHeader(),
            const SizedBox(height: 16),

            _buildIntroductionCard(),
            const SizedBox(height: 16),

            _buildReusedDataNotice(),
            if (_reusedPartnerCategoryLabel != null) const SizedBox(height: 16),

            // COMMON PARTNER FOUNDATION: BASIC DETAILS
            PartnerBasicDetailsSection(
              contactNameController: _contactNameController,
              businessNameController: _businessNameController,
              mobileController: _mobileController,
              emailController: _emailController,
              editable: _isEditable,
              description:
                  'These details will be used for the Measurement Partner '
                  'application.',
              businessNameLabel: 'Business or service name',
              businessNameHint: 'Optional at draft stage',
              onChanged: () {
                if (!mounted) {
                  return;
                }

                setState(() {});
              },
            ),
            const SizedBox(height: 16),

            _buildServiceLocationCard(),
            const SizedBox(height: 16),

            _buildCapabilitiesCard(),
            const SizedBox(height: 16),

            _buildCapacityCard(),
            const SizedBox(height: 16),

            _buildActions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
