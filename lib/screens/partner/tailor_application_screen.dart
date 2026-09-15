import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/metadata/partner_capability_metadata.dart';
import '../../models/address_details.dart';
import '../../models/operating_schedule.dart';
import '../../models/partner_application.dart';
import '../../models/partner_capability_selection.dart';
import '../../services/partner_service.dart';
import '../../widgets/address/address_form_section.dart';
import '../../widgets/capability/capability_multi_selector.dart';
import '../../widgets/partner/partner_basic_details_section.dart';
import '../../widgets/partner/partner_application_lifecycle_section.dart';
import '../../widgets/partner/partner_reapply_dialog.dart';
import '../../widgets/schedule/operating_schedule_field.dart';

class TailorApplicationScreen extends StatefulWidget {
  const TailorApplicationScreen({super.key});

  @override
  State<TailorApplicationScreen> createState() =>
      _TailorApplicationScreenState();
}

class _TailorApplicationScreenState extends State<TailorApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _contactNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _serviceAreaPincodesController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _normalDailyCapacityController = TextEditingController();
  final _peakDailyCapacityController = TextEditingController();
  final _machineCodesController = TextEditingController();
  final _workshopNotesController = TextEditingController();

  String? _workshopTypeCode;

  AddressDetails _businessAddress = const AddressDetails();

  OperatingSchedule _operatingSchedule = const OperatingSchedule();
  PartnerCapabilitySelection _capabilitySelection =
      const PartnerCapabilitySelection();

  bool _pickupAvailable = false;
  bool _deliveryAvailable = false;
  bool _homeVisitAvailable = false;
  bool get _pickupAndDeliveryAvailable {
    return _pickupAvailable && _deliveryAvailable;
  }

  PartnerApplication? _application;

  String? _accountId;
  String? _customerProfileId;

  bool _loading = true;
  bool _saving = false;

  String? _loadError;
  static const Map<String, String> _workshopTypes = {
    'homeBased': 'Home-based workshop',
    'commercialWorkshop': 'Commercial workshop',
    'boutique': 'Boutique',
    'sharedWorkspace': 'Shared workspace',
    'other': 'Other',
  };

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

  bool get _canSubmit {
    return _isEditable && !_saving;
  }

  @override
  void initState() {
    super.initState();
    _initializeApplication();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _businessNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _serviceAreaPincodesController.dispose();
    _teamSizeController.dispose();
    _normalDailyCapacityController.dispose();
    _peakDailyCapacityController.dispose();
    _machineCodesController.dispose();
    _workshopNotesController.dispose();

    super.dispose();
  }

  Future<void> _initializeApplication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError(
          'Please sign in again before starting a partner application.',
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

      final application = await PartnerService.createDraft(
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.tailor,
        contactName: profileName.isEmpty ? null : profileName,
        mobileE164: phone,
        email: profileEmail.isEmpty ? null : profileEmail,
      );

      if (!mounted) {
        return;
      }

      _accountId = accountId;
      _customerProfileId = customerProfileId;
      _application = application;

      _contactNameController.text =
          application.contactName ?? (profileName.isEmpty ? '' : profileName);

      _businessNameController.text = application.businessName ?? '';

      _mobileController.text = application.mobileE164 ?? phone;

      _emailController.text =
          application.email ?? (profileEmail.isEmpty ? '' : profileEmail);

      _loadWorkshopDetails(application.workshopDetails);

      _capabilitySelection = application.effectiveTailorCapabilitySelection;

      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  void _loadWorkshopDetails(PartnerWorkshopDetails? details) {
    _workshopTypeCode = details?.workshopTypeCode;

    _businessAddress = AddressDetails(
      addressLine1: details?.addressLine1,
      addressLine2: details?.addressLine2,
      locality: details?.locality,
      cityName: details?.city,
      stateName: details?.state,
      pincode: details?.pincode,
      countryCode: 'IN',
      placeId: details?.placeId,
      latitude: details?.latitude,
      longitude: details?.longitude,
    );

    _operatingSchedule = OperatingSchedule(
      operatingDays: details?.operatingDays ?? const <String>[],
      openingTime: details?.openingTime,
      closingTime: details?.closingTime,
    );

    _serviceAreaPincodesController.text =
        details?.serviceAreaPincodes.join(', ') ?? '';

    _teamSizeController.text = details?.teamSize?.toString() ?? '';

    _normalDailyCapacityController.text =
        details?.normalDailyCapacity?.toString() ?? '';

    _peakDailyCapacityController.text =
        details?.peakDailyCapacity?.toString() ?? '';

    _machineCodesController.text = details?.machineCodes.join(', ') ?? '';

    _workshopNotesController.text = details?.additionalNotes ?? '';

    _pickupAvailable = details?.pickupAvailable ?? false;

    _deliveryAvailable = details?.deliveryAvailable ?? false;

    _homeVisitAvailable = details?.homeVisitAvailable ?? false;
  }

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
            'Application context is unavailable. '
            'Please reopen the form.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    var saveStage = 'basic details';

    try {
      saveStage = 'basic details';
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      saveStage = 'business and operations';

      final workshopDetails = _buildWorkshopDetails();

      await PartnerService.updateWorkshopDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        workshopDetails: workshopDetails,
      );

      saveStage = 'services and specialization';

      await PartnerService.updateTailorCapabilities(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        selection: _capabilitySelection,
      );

      saveStage = 'completed';

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner application draft saved successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[TailorSave] failedStage=$saveStage');
      debugPrint('[TailorSave] error=$error');
      debugPrintStack(label: '[TailorSave] stackTrace', stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save $saveStage.\n$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<String> _commaSeparatedValues(String rawValue) {
    final uniqueValues = <String>{};

    for (final value in rawValue.split(',')) {
      final normalizedValue = value.trim();

      if (normalizedValue.isNotEmpty) {
        uniqueValues.add(normalizedValue);
      }
    }

    return uniqueValues.toList(growable: false);
  }

  int? _positiveIntOrNull(String rawValue) {
    final value = int.tryParse(rawValue.trim());

    if (value == null || value <= 0) {
      return null;
    }

    return value;
  }

  PartnerWorkshopDetails _buildWorkshopDetails() {
    final existingDetails = _application?.workshopDetails;

    return PartnerWorkshopDetails(
      workshopTypeCode: _workshopTypeCode,
      addressLine1: _businessAddress.addressLine1,
      addressLine2: _businessAddress.addressLine2,
      locality: _businessAddress.locality,
      city: _businessAddress.cityName,
      state: _businessAddress.stateName,
      pincode: _businessAddress.pincode,

      // Preserve shared map-derived values until the map picker is added.
      placeId: _businessAddress.placeId ?? existingDetails?.placeId,
      latitude: _businessAddress.latitude ?? existingDetails?.latitude,
      longitude: _businessAddress.longitude ?? existingDetails?.longitude,

      serviceAreaPincodes: _commaSeparatedValues(
        _serviceAreaPincodesController.text,
      ),
      operatingDays: _operatingSchedule.normalizedOperatingDays,
      openingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.openingTime,
      ),
      closingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.closingTime,
      ),
      teamSize: _positiveIntOrNull(_teamSizeController.text),
      normalDailyCapacity: _positiveIntOrNull(
        _normalDailyCapacityController.text,
      ),
      peakDailyCapacity: _positiveIntOrNull(_peakDailyCapacityController.text),
      machineCodes: _commaSeparatedValues(_machineCodesController.text),
      pickupAvailable: _pickupAvailable,
      deliveryAvailable: _deliveryAvailable,
      homeVisitAvailable: _homeVisitAvailable,
      additionalNotes: _workshopNotesController.text.trim(),
    );
  }

  void _continueLater() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tailor Application'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _buildErrorState();
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildApplicationHeader(),
          const SizedBox(height: 20),
          PartnerApplicationStatusNotice(
            application: _application!,
            partnerLabel: 'Tailor Partner',
          ),
          const SizedBox(height: 20),
          _buildBasicDetailsCard(),
          const SizedBox(height: 20),
          _buildWorkshopDetailsCard(),
          const SizedBox(height: 20),
          _buildCapabilitiesCard(),
          const SizedBox(height: 20),
          _buildNextStepsCard(),
          const SizedBox(height: 20),

          _buildActions(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
              'Unable to start application',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'Unknown error',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _loadError = null;
                });

                _initializeApplication();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x194CAF50),
            child: Icon(Icons.content_cut_rounded, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Tailor Partner',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: BASIC DETAILS
  // ==========================================================================
  //
  // Controller ownership and persistence remain in this screen.
  // The reusable widget contains presentation and common validation only.
  // ==========================================================================
  Widget _buildBasicDetailsCard() {
    return PartnerBasicDetailsSection(
      contactNameController: _contactNameController,
      businessNameController: _businessNameController,
      mobileController: _mobileController,
      emailController: _emailController,
      editable: _isEditable,
      description: 'These details will be used for the Tailor application.',
      businessNameLabel: 'Business or workshop name',
      businessNameHint: 'Optional at draft stage',
      onChanged: () {
        if (!mounted) {
          return;
        }

        setState(() {});
      },
    );
  }

  Widget _buildWorkshopDetailsCard() {
    final workshopStatus =
        _application?.onboardingStatusFor(
          PartnerOnboardingSection.workshopDetails,
        ) ??
        PartnerOnboardingSectionStatus.notStarted;

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
              Expanded(
                child: Text(
                  'Business & Operations',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _workshopStatusLabel(workshopStatus),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Provide the business location, operating schedule, '
            'capacity and service-support information. Business '
            'photographs are optional during Phase 1.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            initialValue: _workshopTypeCode,
            decoration: const InputDecoration(
              labelText: 'Workshop type',
              prefixIcon: Icon(Icons.store_outlined),
              border: OutlineInputBorder(),
            ),
            items: _workshopTypes.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: _isEditable
                ? (value) {
                    setState(() {
                      _workshopTypeCode = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 14),

          AddressFormSection(
            key: ValueKey(
              'partner-business-address-'
              '${_businessAddress.stateCode ?? _businessAddress.stateName ?? 'none'}-'
              '${_businessAddress.cityCode ?? _businessAddress.cityName ?? 'none'}',
            ),
            metadataProvider: IndiaAddressMetadata.instance,
            initialValue: _businessAddress,
            enabled: _isEditable,
            sectionTitle: 'Business Location',
            addressLine1Label: 'Business address',
            addressLine2Label: 'Address line 2',
            localityLabel: 'Locality or area',
            stateLabel: 'State',
            cityLabel: 'City',
            pincodeLabel: 'Pincode',
            addressLine1Required: true,
            addressLine2Required: false,
            localityRequired: false,
            landmarkRequired: false,
            stateRequired: true,
            cityRequired: true,
            pincodeRequired: true,
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
          const SizedBox(height: 18),

          OperatingScheduleField(
            key: ValueKey(
              'partner-operating-schedule-'
              '${_operatingSchedule.normalizedOperatingDays.join('-')}-'
              '${_operatingSchedule.openingTime ?? 'none'}-'
              '${_operatingSchedule.closingTime ?? 'none'}',
            ),
            initialValue: _operatingSchedule,
            enabled: _isEditable,
            operatingDaysRequired: true,
            openingTimeRequired: true,
            closingTimeRequired: true,
            requireClosingAfterOpening: true,
            sectionTitle: 'Operating Schedule',
            operatingDaysLabel: 'Operating days',
            openingTimeLabel: 'Opening time',
            closingTimeLabel: 'Closing time',
            onChanged: (schedule) {
              _operatingSchedule = schedule;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _teamSizeController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Team size',
              hintText: 'Total number of people',
              prefixIcon: Icon(Icons.groups_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _normalDailyCapacityController,
                  readOnly: !_isEditable,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Normal daily capacity',
                    hintText: 'Garments per day',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _peakDailyCapacityController,
                  readOnly: !_isEditable,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Peak daily capacity',
                    hintText: 'Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _machineCodesController,
            readOnly: !_isEditable,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Machines and equipment',
              hintText: 'Example: Sewing machine, overlock machine',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
              border: OutlineInputBorder(),
              helperText: 'Optional. Separate multiple items with commas.',
            ),
          ),
          const SizedBox(height: 10),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pickup & Delivery Available'),
            subtitle: const Text(
              'The Tailor can handle pickup and delivery for their own products or services.',
            ),
            value: _pickupAndDeliveryAvailable,
            onChanged: _isEditable
                ? (value) {
                    setState(() {
                      _pickupAvailable = value;
                      _deliveryAvailable = value;
                    });
                  }
                : null,
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Home visit available'),
            subtitle: const Text('Workshop can support selected home visits.'),
            value: _homeVisitAvailable,
            onChanged: _isEditable
                ? (value) {
                    setState(() {
                      _homeVisitAvailable = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _workshopNotesController,
            readOnly: !_isEditable,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Additional workshop notes',
              hintText: 'Optional operating or workshop information',
              prefixIcon: Icon(Icons.notes_outlined),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          if (!_isEditable) ...[
            const SizedBox(height: 10),
            Text(
              _isUnderAdminReview
                  ? 'Business & Operations is read-only while '
                        'the application is under Admin review.'
                  : 'Business & Operations is not editable in '
                        'the current application status.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    final capabilityStatus =
        _application?.onboardingStatusFor(
          PartnerOnboardingSection.servicesAndSpecialization,
        ) ??
        PartnerOnboardingSectionStatus.notStarted;

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
              Expanded(
                child: Text(
                  'Services & Specialization',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _workshopStatusLabel(capabilityStatus),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select the services and specialized work that '
            'the Tailor can currently provide. Some premium '
            'capabilities require Admin verification or '
            'certification before assignment.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          CapabilityMultiSelector(
            key: ValueKey(
              'tailor-capabilities-'
              '${_capabilitySelection.normalizedCapabilityCodes.join('-')}-'
              '${_capabilitySelection.normalizedAdditionalDescriptions.join('-')}',
            ),
            metadataProvider: PartnerCapabilityMetadata.instance,
            partnerCategoryCode: PartnerCapabilityMetadata.tailorCategoryCode,
            initialValue: _capabilitySelection,
            enabled: _isEditable,
            // RULE-ID: TAILOR-CAPABILITY-DRAFT-PARTIAL-ALLOWED
            // Save Draft must allow Other Expertise to remain temporarily blank.
            // Submit for Review performs the final completeness validation.
            minimumSelectionCount: 0,
            sectionTitle: 'Skills & Expertise',
            sectionDescription:
                'Select all applicable capabilities. '
                'Verification indicators do not mean that '
                'the capability is already approved.',
            showOtherExpertise: true,
            requireOtherExpertiseDescription: false,
            otherExpertiseLabel: 'Other Expertise',
            otherExpertiseHint: 'Example: custom tassel work, hand finishing',
            onChanged: (selection) {
              _capabilitySelection = selection;
            },
          ),
          if (!_isEditable) ...[
            const SizedBox(height: 14),
            Text(
              _isUnderAdminReview
                  ? 'Services & Specialization is read-only '
                        'while the application is under Admin review.'
                  : 'Services & Specialization is not editable '
                        'in the current application status.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextStepsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application sections coming next',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _buildNextStep(Icons.speed_rounded, 'Capacity and availability'),
          _buildNextStep(Icons.straighten_rounded, 'Measurement preferences'),
          _buildNextStep(Icons.verified_outlined, 'Quality and verification'),
          _buildNextStep(
            Icons.currency_rupee_rounded,
            'Expected rate information',
          ),
          _buildNextStep(Icons.description_outlined, 'Documents and review'),
        ],
      ),
    );
  }

  String _workshopStatusLabel(PartnerOnboardingSectionStatus status) {
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

  Widget _buildNextStep(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          const Icon(
            Icons.schedule_outlined,
            color: AppColors.textHint,
            size: 18,
          ),
        ],
      ),
    );
  }

  Future<void> _submitForReview() async {
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
      // Persist the latest form values before changing application status.
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      final workshopDetails = _buildWorkshopDetails();

      await PartnerService.updateWorkshopDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        workshopDetails: workshopDetails,
      );

      await PartnerService.updateTailorCapabilities(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        selection: _capabilitySelection,
      );

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
          content: Text('Application submitted for Admin review'),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit application.\n$error'),
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

    final shouldCreate = await showPartnerReapplyDialog(
      context: context,
      partnerLabel: 'Tailor Partner',
    );
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

      _loadWorkshopDetails(newApplication.workshopDetails);

      _capabilitySelection = newApplication.effectiveTailorCapabilitySelection;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A new Tailor application has been created. '
            'Previous information was copied. Please review it '
            'before submitting.',
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

  Widget _buildActions() {
    final application = _application;

    if (application == null) {
      return const SizedBox.shrink();
    }

    return PartnerApplicationLifecycleActions(
      application: application,
      saving: _saving,
      canSaveDraft: _isEditable && !_saving,
      canSubmit: _canSubmit,
      onSaveDraft: _saveDraft,
      onSubmitForReview: _submitForReview,
      onApplyAgain: _applyAgain,
      onContinueLater: _continueLater,
    );
  }
}
