/*
 * =============================================================================
 * SuiSakhi Boutique Partner Application Screen
 *
 * Purpose:
 * Handles Boutique Partner onboarding using the common Partner foundation.
 * Common Partner information (Basic Details, Business Address and Operating
 * Schedule) reuses the same proven widgets used by the Tailor application.
 * Boutique-specific information remains under onboardingData.extensions.boutique.
 * =============================================================================
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/boutique_partner_capability_metadata.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../models/address_details.dart';
import '../../models/boutique_partner_details.dart';
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

// =============================================================================
// BOUTIQUE PARTNER APPLICATION
// =============================================================================

class BoutiqueApplicationScreen extends StatefulWidget {
  const BoutiqueApplicationScreen({super.key});

  @override
  State<BoutiqueApplicationScreen> createState() =>
      _BoutiqueApplicationScreenState();
}

class _BoutiqueApplicationScreenState extends State<BoutiqueApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // COMMON PARTNER FOUNDATION: BASIC DETAILS
  // ---------------------------------------------------------------------------
  final _contact = TextEditingController();
  final _business = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  // ---------------------------------------------------------------------------
  // COMMON PARTNER FOUNDATION: BUSINESS LOCATION / SCHEDULE
  // ---------------------------------------------------------------------------
  AddressDetails _businessAddress = const AddressDetails();
  OperatingSchedule _operatingSchedule = const OperatingSchedule();
  final _serviceArea = TextEditingController();

  // ---------------------------------------------------------------------------
  // BOUTIQUE-SPECIFIC INFORMATION
  // ---------------------------------------------------------------------------
  final _specialization = TextEditingController();
  final _experience = TextEditingController();
  final _teamSize = TextEditingController();
  final _dailyCapacity = TextEditingController();
  final _peakCapacity = TextEditingController();
  final _portfolio = TextEditingController();
  final _notes = TextEditingController();

  PartnerCapabilitySelection _capabilities = const PartnerCapabilitySelection();

  bool _homeVisit = false;
  bool _pickupAndDelivery = false;
  bool _readyMade = false;
  bool _returns = false;

  PartnerApplication? _application;
  String? _accountId;
  String? _customerProfileId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editable => _application?.canEdit == true;

  // Phase-1 onboarding does not require any applicant-entered field.
  // Admin may request missing information after submission.
  bool get _canSubmit => _editable && !_saving;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    for (final controller in [
      _contact,
      _business,
      _mobile,
      _email,
      _serviceArea,
      _specialization,
      _experience,
      _teamSize,
      _dailyCapacity,
      _peakCapacity,
      _portfolio,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD / RESUME APPLICATION
  // ---------------------------------------------------------------------------
  Future<void> _initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber?.trim();

      if (user == null || phone == null || phone.isEmpty) {
        throw StateError(
          'Please sign in again before starting a Boutique Partner application.',
        );
      }

      final accountId = await AppState.instance.fetchAccountIdForMobile(phone);

      if (accountId == null || accountId.trim().isEmpty) {
        throw StateError('Your SuiSakhi account could not be resolved.');
      }

      final profiles = await AppState.instance.fetchActiveProfilesForAccount(
        accountId,
      );

      Map<String, dynamic>? customer;

      for (final profile in profiles) {
        if ((profile['role'] ?? '').toString() == 'customer') {
          customer = profile;
          break;
        }
      }

      final customerProfileId = (customer?['profileId'] ?? customer?['docId'])
          ?.toString()
          .trim();

      if (customerProfileId == null || customerProfileId.isEmpty) {
        throw StateError('Your active Customer profile could not be resolved.');
      }

      final application = await PartnerService.createDraft(
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.boutique,
        contactName:
            customer?['displayName']?.toString() ??
            AppState.instance.displayName,
        mobileE164: phone,
        email: (customer?['email'] ?? user.email)?.toString(),
      );

      _contact.text =
          application.contactName ??
          customer?['displayName']?.toString() ??
          AppState.instance.displayName;
      _business.text = application.businessName ?? '';
      _mobile.text = application.mobileE164 ?? phone;
      _email.text =
          application.email ??
          (customer?['email'] ?? user.email)?.toString() ??
          '';

      _hydrateCommonBusiness(application);
      _hydrate(
        BoutiquePartnerDetails.fromOnboardingData(application.onboardingData),
      );

      if (!mounted) return;

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;
        _application = application;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // HYDRATE COMMON BUSINESS DETAILS
  // ---------------------------------------------------------------------------
  void _hydrateCommonBusiness(PartnerApplication application) {
    final extensions = application.onboardingData['extensions'];

    if (extensions is! Map) return;

    final category = extensions['boutique'];

    if (category is! Map) return;

    final workshop = category['workshopDetails'];

    if (workshop is! Map) return;

    final details = PartnerWorkshopDetails.fromMap(
      Map<String, dynamic>.from(workshop),
    );

    _businessAddress = AddressDetails(
      addressLine1: details.addressLine1,
      addressLine2: details.addressLine2,
      locality: details.locality,
      cityName: details.city,
      stateName: details.state,
      pincode: details.pincode,
      countryCode: 'IN',
      placeId: details.placeId,
      latitude: details.latitude,
      longitude: details.longitude,
    );

    _operatingSchedule = OperatingSchedule(
      operatingDays: details.operatingDays,
      openingTime: details.openingTime,
      closingTime: details.closingTime,
    );

    _serviceArea.text = details.serviceAreaPincodes.join(', ');
  }

  // ---------------------------------------------------------------------------
  // HYDRATE BOUTIQUE-SPECIFIC DETAILS
  // ---------------------------------------------------------------------------
  void _hydrate(BoutiquePartnerDetails details) {
    _capabilities = details.capabilitySelection;
    _specialization.text = details.specialization ?? '';
    _experience.text = details.experienceYears?.toString() ?? '';
    _teamSize.text = details.teamSize?.toString() ?? '';
    _dailyCapacity.text = details.normalDailyCapacity?.toString() ?? '';
    _peakCapacity.text = details.peakDailyCapacity?.toString() ?? '';
    _portfolio.text = details.portfolioSummary ?? '';
    _notes.text = details.additionalNotes ?? '';
    _homeVisit = details.homeVisitAvailable;
    _pickupAndDelivery = details.pickupAndDeliveryAvailable;
    _readyMade = details.readyMadeInventory;
    _returns = details.returnExchangeAvailable;
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  // ---------------------------------------------------------------------------
  // BUILD CATEGORY DETAILS
  // ---------------------------------------------------------------------------
  BoutiquePartnerDetails _details() {
    return BoutiquePartnerDetails(
      capabilitySelection: _capabilities,
      specialization: _specialization.text,
      experienceYears: _int(_experience),
      serviceArea: _serviceArea.text,
      teamSize: _int(_teamSize),
      normalDailyCapacity: _int(_dailyCapacity),
      peakDailyCapacity: _int(_peakCapacity),
      homeVisitAvailable: _homeVisit,
      pickupAndDeliveryAvailable: _pickupAndDelivery,
      readyMadeInventory: _readyMade,
      returnExchangeAvailable: _returns,
      portfolioSummary: _portfolio.text,
      additionalNotes: _notes.text,
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD COMMON BUSINESS DETAILS
  // ---------------------------------------------------------------------------
  PartnerWorkshopDetails _businessDetails() {
    final existing = _application?.onboardingData['extensions'];
    Map<String, dynamic>? existingWorkshop;

    if (existing is Map && existing['boutique'] is Map) {
      final boutique = Map<String, dynamic>.from(existing['boutique']);
      if (boutique['workshopDetails'] is Map) {
        existingWorkshop = Map<String, dynamic>.from(
          boutique['workshopDetails'],
        );
      }
    }

    return PartnerWorkshopDetails(
      workshopTypeCode: existingWorkshop?['workshopTypeCode']?.toString(),
      addressLine1: _businessAddress.addressLine1,
      addressLine2: _businessAddress.addressLine2,
      locality: _businessAddress.locality,
      city: _businessAddress.cityName,
      state: _businessAddress.stateName,
      pincode: _businessAddress.pincode,
      placeId:
          _businessAddress.placeId ?? existingWorkshop?['placeId']?.toString(),
      latitude:
          _businessAddress.latitude ??
          (existingWorkshop?['latitude'] is num
              ? (existingWorkshop!['latitude'] as num).toDouble()
              : null),
      longitude:
          _businessAddress.longitude ??
          (existingWorkshop?['longitude'] is num
              ? (existingWorkshop!['longitude'] as num).toDouble()
              : null),
      serviceAreaPincodes: _commaSeparated(_serviceArea.text),
      operatingDays: _operatingSchedule.normalizedOperatingDays,
      openingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.openingTime,
      ),
      closingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.closingTime,
      ),
      teamSize: _int(_teamSize),
      normalDailyCapacity: _int(_dailyCapacity),
      peakDailyCapacity: _int(_peakCapacity),
      additionalNotes: _notes.text.trim(),
    );
  }

  List<String> _commaSeparated(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // SAVE / SUBMIT
  // ---------------------------------------------------------------------------
  Future<void> _save({required bool submit}) async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final application = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (application == null || accountId == null || customerProfileId == null) {
      _message('Application context is unavailable.');
      return;
    }

    setState(() => _saving = true);

    var saveStage = 'basic details';

    try {
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contact.text,
        businessName: _business.text,
        mobileE164: _mobile.text,
        email: _email.text,
      );

      saveStage = 'business address and operating schedule';
      await PartnerService.updatePartnerBusinessDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.boutique,
        workshopDetails: _businessDetails(),
      );

      saveStage = 'Boutique services and specialization';
      await PartnerService.updateBoutiqueDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        boutiqueDetails: _details(),
      );

      if (submit) {
        saveStage = 'application submission';
        await PartnerService.submitApplication(
          applicationId: application.id,
          accountId: accountId,
          customerProfileId: customerProfileId,
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        submit
            ? 'Boutique Partner application submitted for Admin review.'
            : 'Boutique Partner draft saved successfully.',
      );

      if (submit) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to save $saveStage.\n$error', isError: true);
    }
  }

  void _hydrateApplication(PartnerApplication application) {
    _application = application;
    _contact.text = application.contactName ?? '';
    _business.text = application.businessName ?? '';
    _mobile.text = application.mobileE164 ?? '';
    _email.text = application.email ?? '';
    _hydrateCommonBusiness(application);
    _hydrate(
      BoutiquePartnerDetails.fromOnboardingData(application.onboardingData),
    );
  }

  void _continueLater() {
    context.pop();
  }

  Future<void> _applyAgain() async {
    final rejectedApplication = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;
    if (rejectedApplication == null ||
        rejectedApplication.status != PartnerApplicationStatus.rejected ||
        accountId == null ||
        customerProfileId == null) {
      return;
    }
    final confirmed = await showPartnerReapplyDialog(
      context: context,
      partnerLabel: 'Boutique Partner',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final newApplication = await PartnerService.reapplyFromRejected(
        rejectedApplicationId: rejectedApplication.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
      );
      if (!mounted) return;
      _hydrateApplication(newApplication);
      setState(() => _saving = false);
      _message(
        'A new Boutique Partner Draft was created. Review the copied information before submitting.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        'Unable to create a new Boutique Partner application.\n$error',
        isError: true,
      );
    }
  }

  Widget _buildLifecycleActions() {
    final application = _application;
    if (application == null) return const SizedBox.shrink();
    return PartnerApplicationLifecycleActions(
      application: application,
      saving: _saving,
      canSaveDraft: _editable && !_saving,
      canSubmit: _canSubmit,
      onSaveDraft: () => _save(submit: false),
      onSubmitForReview: () => _save(submit: true),
      onApplyAgain: _applyAgain,
      onContinueLater: _continueLater,
    );
  }

  // ---------------------------------------------------------------------------
  // SMALL UI HELPERS
  // ---------------------------------------------------------------------------
  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : Colors.green,
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? type,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: !_editable,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required && (controller.text.trim().isEmpty)
            ? (_) => '$label is required'
            : null,
      ),
    );
  }

  Widget _card(String title, String description, List<Widget> children) {
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
          Text(title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SCREEN
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boutique Partner Application')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Boutique Partner Application'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PartnerApplicationStatusNotice(
              application: _application!,
              partnerLabel: 'Boutique Partner',
            ),
            const SizedBox(height: 14),
            _card(
              'Basic Details',
              'Common Partner identity and contact information.',
              [
                PartnerBasicDetailsSection(
                  contactNameController: _contact,
                  businessNameController: _business,
                  mobileController: _mobile,
                  emailController: _email,
                  editable: _editable,
                  description:
                      'Common Partner identity and contact information.',
                  businessNameLabel: 'Boutique name',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // =================================================================
            // COMMON PARTNER FOUNDATION: BUSINESS ADDRESS
            // =================================================================
            _card(
              'Business Location',
              'Provide the primary Boutique business address.',
              [
                AddressFormSection(
                  key: ValueKey(
                    'boutique-address-${_businessAddress.stateCode ?? _businessAddress.stateName ?? 'none'}-${_businessAddress.cityCode ?? _businessAddress.cityName ?? 'none'}',
                  ),
                  metadataProvider: IndiaAddressMetadata.instance,
                  initialValue: _businessAddress,
                  enabled: _editable,
                  sectionTitle: 'Business Address',
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
                  onChanged: (address) => _businessAddress = address,
                ),
                const SizedBox(height: 14),
                _field(
                  'Service-area pincodes',
                  _serviceArea,
                  hint: 'Example: 411001, 411002',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // =================================================================
            // COMMON PARTNER FOUNDATION: OPERATING SCHEDULE
            // =================================================================
            _card(
              'Operating Schedule',
              'Tell customers and SuiSakhi when the Boutique is available.',
              [
                OperatingScheduleField(
                  key: ValueKey(
                    'boutique-schedule-${_operatingSchedule.normalizedOperatingDays.join('-')}-${_operatingSchedule.openingTime ?? 'none'}-${_operatingSchedule.closingTime ?? 'none'}',
                  ),
                  initialValue: _operatingSchedule,
                  enabled: _editable,
                  operatingDaysRequired: true,
                  openingTimeRequired: true,
                  closingTimeRequired: true,
                  requireClosingAfterOpening: true,
                  sectionTitle: 'Operating Schedule',
                  operatingDaysLabel: 'Operating days',
                  openingTimeLabel: 'Opening time',
                  closingTimeLabel: 'Closing time',
                  onChanged: (schedule) => _operatingSchedule = schedule,
                ),
              ],
            ),
            const SizedBox(height: 14),

            _card(
              'Boutique Details',
              'Capture the Boutique specialization and capabilities.',
              [
                _field(
                  'Specialization',
                  _specialization,
                  hint: 'Ethnic, premium, bridal, party wear, etc.',
                ),
                _field(
                  'Experience (years)',
                  _experience,
                  type: TextInputType.number,
                ),
                CapabilityMultiSelector(
                  metadataProvider: BoutiquePartnerCapabilityMetadata.instance,
                  partnerCategoryCode:
                      BoutiquePartnerCapabilityMetadata.categoryCode,
                  initialValue: _capabilities,
                  enabled: _editable,
                  minimumSelectionCount: 0,
                  requireOtherExpertiseDescription: false,
                  onChanged: (value) => setState(() => _capabilities = value),
                  sectionTitle: 'Boutique capabilities',
                ),
              ],
            ),
            const SizedBox(height: 14),

            _card(
              'Operations & Capacity',
              'Provide the current team size and order-handling capacity.',
              [
                _field('Team size', _teamSize, type: TextInputType.number),
                _field(
                  'Normal daily capacity',
                  _dailyCapacity,
                  type: TextInputType.number,
                ),
                _field(
                  'Peak daily capacity',
                  _peakCapacity,
                  type: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 14),

            _card(
              'Portfolio & Additional Information',
              'Optional information useful for future SuiSakhi matching and AI.',
              [
                _field(
                  'Portfolio summary',
                  _portfolio,
                  hint: 'Describe your work, collections or customer profile',
                ),
                _field('Additional notes', _notes),
              ],
            ),
            const SizedBox(height: 18),
            _buildLifecycleActions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
