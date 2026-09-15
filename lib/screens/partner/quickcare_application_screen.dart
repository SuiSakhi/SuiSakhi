import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../core/metadata/quickcare_partner_capability_metadata.dart';
import '../../models/address_details.dart';
import '../../models/operating_schedule.dart';
import '../../models/partner_application.dart';
import '../../models/partner_capability_selection.dart';
import '../../models/quickcare_partner_details.dart';
import '../../services/partner_service.dart';
import '../../widgets/address/address_form_section.dart';
import '../../widgets/capability/capability_multi_selector.dart';
import '../../widgets/partner/partner_application_lifecycle_section.dart';
import '../../widgets/partner/partner_basic_details_section.dart';
import '../../widgets/partner/partner_reapply_dialog.dart';
import '../../widgets/schedule/operating_schedule_field.dart';

class QuickCareApplicationScreen extends StatefulWidget {
  const QuickCareApplicationScreen({super.key});

  @override
  State<QuickCareApplicationScreen> createState() =>
      _QuickCareApplicationScreenState();
}

class _QuickCareApplicationScreenState
    extends State<QuickCareApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _contact = TextEditingController();
  final _business = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _serviceArea = TextEditingController();
  final _experience = TextEditingController();
  final _experienceSummary = TextEditingController();
  final _serviceRadiusKm = TextEditingController();
  final _teamSize = TextEditingController();
  final _normalCapacity = TextEditingController();
  final _peakCapacity = TextEditingController();
  final _notes = TextEditingController();

  AddressDetails _businessAddress = const AddressDetails();
  OperatingSchedule _schedule = const OperatingSchedule();
  PartnerCapabilitySelection _capabilities = const PartnerCapabilitySelection();

  String? _providerTypeCode;
  String? _skillLevelCode;
  String? _durationCode;
  String? _responseTimeCode;
  String? _transportModeCode;
  bool _willingToTravel = false;
  bool _sameDay = false;
  bool _emergency = false;
  bool _customerCoordination = false;

  PartnerApplication? _application;
  String? _accountId;
  String? _customerProfileId;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _editable => _application?.canEdit == true;
  bool get _canSubmit => _editable && !_saving;

  static const _providerTypes = {
    'self': 'Self',
    'tailoringSchool': 'Tailoring School',
    'trainingOrganisation': 'Training Organisation',
  };

  static const _skillLevels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'experienced': 'Experienced',
    'expert': 'Expert',
  };

  static const _durations = {
    'upTo30Minutes': 'Up to 30 minutes',
    'minutes30To60': '30 to 60 minutes',
    'hours1To2': '1 to 2 hours',
    'hours2To4': '2 to 4 hours',
    'moreThan4Hours': 'More than 4 hours',
    'dependsOnService': 'Depends on service',
  };

  static const _responseTimes = {
    'within1Hour': 'Within 1 hour',
    'within2Hours': 'Within 2 hours',
    'within4Hours': 'Within 4 hours',
    'sameDay': 'Same day',
    'nextDay': 'Next day',
    'dependsOnAvailability': 'Depends on availability',
  };

  static const _transportModes = {
    'walking': 'Walking',
    'bicycle': 'Bicycle',
    'twoWheeler': 'Two Wheeler',
    'car': 'Car',
    'publicTransport': 'Public Transport',
    'multipleModes': 'Multiple Modes',
  };

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
      _experience,
      _experienceSummary,
      _serviceRadiusKm,
      _teamSize,
      _normalCapacity,
      _peakCapacity,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber?.trim();
      if (user == null || phone == null || phone.isEmpty) {
        throw StateError(
          'Please sign in again before starting a QuickCare Partner application.',
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
        partnerType: PartnerType.doorstepServices,
        contactName:
            customer?['displayName']?.toString() ??
            AppState.instance.displayName,
        mobileE164: phone,
        email: (customer?['email'] ?? user.email)?.toString(),
      );

      _accountId = accountId;
      _customerProfileId = customerProfileId;
      _hydrateApplication(application);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
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
      QuickCarePartnerDetails.fromOnboardingData(application.onboardingData),
    );
  }

  void _hydrateCommonBusiness(PartnerApplication application) {
    final extensions = application.onboardingData['extensions'];
    if (extensions is! Map) return;
    final category = extensions['doorstepServices'];
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
    _schedule = OperatingSchedule(
      operatingDays: details.operatingDays,
      openingTime: details.openingTime,
      closingTime: details.closingTime,
    );
    _serviceArea.text = details.serviceAreaPincodes.join(', ');
  }

  void _hydrate(QuickCarePartnerDetails details) {
    _capabilities = details.capabilitySelection;
    _providerTypeCode = details.providerTypeCode;
    _skillLevelCode = details.skillLevelCode;
    _experience.text = details.experienceYears?.toString() ?? '';
    _experienceSummary.text = details.experienceSummary ?? '';
    _serviceArea.text = details.serviceArea ?? _serviceArea.text;
    _serviceRadiusKm.text = details.serviceRadiusKm?.toString() ?? '';
    _willingToTravel = details.willingToTravelForUrgentSpecial;
    _teamSize.text = details.teamSize?.toString() ?? '';
    _normalCapacity.text = details.normalDailyCapacity?.toString() ?? '';
    _peakCapacity.text = details.peakDailyCapacity?.toString() ?? '';
    _durationCode = details.typicalServiceDurationCode;
    _responseTimeCode = details.typicalResponseTimeCode;
    _sameDay = details.sameDayServiceAvailable;
    _emergency = details.emergencyServiceAvailable;
    _transportModeCode = details.transportModeCode;
    _customerCoordination = details.customerCoordinationComfortable;
    _notes.text = details.additionalNotes ?? '';
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  List<String> _commaSeparated(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  QuickCarePartnerDetails _details() => QuickCarePartnerDetails(
    capabilitySelection: _capabilities,
    providerTypeCode: _providerTypeCode,
    skillLevelCode: _skillLevelCode,
    experienceYears: _int(_experience),
    experienceSummary: _experienceSummary.text,
    serviceArea: _serviceArea.text,
    serviceRadiusKm: _int(_serviceRadiusKm),
    willingToTravelForUrgentSpecial: _willingToTravel,
    teamSize: _int(_teamSize),
    normalDailyCapacity: _int(_normalCapacity),
    peakDailyCapacity: _int(_peakCapacity),
    typicalServiceDurationCode: _durationCode,
    typicalResponseTimeCode: _responseTimeCode,
    sameDayServiceAvailable: _sameDay,
    emergencyServiceAvailable: _emergency,
    transportModeCode: _transportModeCode,
    customerCoordinationComfortable: _customerCoordination,
    additionalNotes: _notes.text,
  );

  PartnerWorkshopDetails _businessDetails() => PartnerWorkshopDetails(
    addressLine1: _businessAddress.addressLine1,
    addressLine2: _businessAddress.addressLine2,
    locality: _businessAddress.locality,
    city: _businessAddress.cityName,
    state: _businessAddress.stateName,
    pincode: _businessAddress.pincode,
    placeId: _businessAddress.placeId,
    latitude: _businessAddress.latitude,
    longitude: _businessAddress.longitude,
    serviceAreaPincodes: _commaSeparated(_serviceArea.text),
    operatingDays: _schedule.normalizedOperatingDays,
    openingTime: OperatingSchedule.normalizedTimeOrNull(_schedule.openingTime),
    closingTime: OperatingSchedule.normalizedTimeOrNull(_schedule.closingTime),
    teamSize: _int(_teamSize),
    normalDailyCapacity: _int(_normalCapacity),
    peakDailyCapacity: _int(_peakCapacity),
    additionalNotes: _notes.text.trim(),
  );

  Future<void> _save({required bool submit}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final app = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;
    if (app == null || accountId == null || customerProfileId == null) {
      _message('Application context is unavailable.', isError: true);
      return;
    }

    setState(() => _saving = true);
    var stage = 'basic details';
    try {
      await PartnerService.updateDraft(
        applicationId: app.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contact.text,
        businessName: _business.text,
        mobileE164: _mobile.text,
        email: _email.text,
      );

      stage = 'address and operating schedule';
      await PartnerService.updatePartnerBusinessDetails(
        applicationId: app.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.doorstepServices,
        workshopDetails: _businessDetails(),
      );

      stage = 'QuickCare capability and operations';
      await PartnerService.updateQuickCareDetails(
        applicationId: app.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        quickCareDetails: _details(),
      );

      if (submit) {
        stage = 'application submission';
        await PartnerService.submitApplication(
          applicationId: app.id,
          accountId: accountId,
          customerProfileId: customerProfileId,
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        submit
            ? 'QuickCare Partner application submitted for Admin review.'
            : 'QuickCare Partner draft saved successfully.',
      );
      if (submit) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to save $stage.\n$error', isError: true);
    }
  }

  Future<void> _applyAgain() async {
    final rejected = _application;
    final accountId = _accountId;
    final profileId = _customerProfileId;
    if (rejected == null ||
        rejected.status != PartnerApplicationStatus.rejected ||
        accountId == null ||
        profileId == null) {
      return;
    }

    final confirmed = await showPartnerReapplyDialog(
      context: context,
      partnerLabel: 'QuickCare Partner',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final newApplication = await PartnerService.reapplyFromRejected(
        rejectedApplicationId: rejected.id,
        accountId: accountId,
        customerProfileId: profileId,
      );
      if (!mounted) return;
      _hydrateApplication(newApplication);
      setState(() => _saving = false);
      _message(
        'A new QuickCare Partner Draft was created. Review the copied information before submitting.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to create a new application.\n$error', isError: true);
    }
  }

  void _message(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : const Color(0xFF2E7D32),
      ),
    );
  }

  void _continueLater() => context.pop();

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: !_editable,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _dropdown(
    String label,
    String? value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: _editable ? onChanged : null,
    ),
  );

  Widget _card(String title, String description, List<Widget> children) =>
      Container(
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
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget _actions() {
    final app = _application;
    if (app == null) return const SizedBox.shrink();
    return PartnerApplicationLifecycleActions(
      application: app,
      saving: _saving,
      canSaveDraft: _editable && !_saving,
      canSubmit: _canSubmit,
      onSaveDraft: () => _save(submit: false),
      onSubmitForReview: () => _save(submit: true),
      onApplyAgain: _applyAgain,
      onContinueLater: _continueLater,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('QuickCare Partner Application')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('QuickCare Partner Application'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PartnerApplicationStatusNotice(
              application: _application!,
              partnerLabel: 'QuickCare Partner',
            ),
            const SizedBox(height: 14),
            _card(
              'Common Partner Details',
              'Identity and contact information for the QuickCare application.',
              [
                PartnerBasicDetailsSection(
                  contactNameController: _contact,
                  businessNameController: _business,
                  mobileController: _mobile,
                  emailController: _email,
                  editable: _editable,
                  description:
                      'Common Partner identity and contact information.',
                  businessNameLabel: 'Service / professional name',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Business / Service Address',
              'Provide the base address and areas where QuickCare service is available.',
              [
                AddressFormSection(
                  key: ValueKey(
                    'quickcare-address-${_businessAddress.stateCode ?? _businessAddress.stateName ?? 'none'}-${_businessAddress.cityCode ?? _businessAddress.cityName ?? 'none'}',
                  ),
                  metadataProvider: IndiaAddressMetadata.instance,
                  initialValue: _businessAddress,
                  enabled: _editable,
                  sectionTitle: 'Service Address',
                  addressLine1Label: 'Address',
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
                  onChanged: (value) => _businessAddress = value,
                ),
                const SizedBox(height: 14),
                _field(
                  'Service-area pincodes',
                  _serviceArea,
                  hint: 'Example: 411001, 411002',
                ),
                _field(
                  'Approximate service radius (km)',
                  _serviceRadiusKm,
                  hint: 'Example: 5 or 8',
                  type: TextInputType.number,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _willingToTravel,
                  onChanged: _editable
                      ? (value) => setState(() => _willingToTravel = value)
                      : null,
                  title: const Text(
                    'Willing to travel for urgent / special assignments',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Operating Schedule',
              'Select available days and normal operating times.',
              [
                OperatingScheduleField(
                  key: ValueKey(
                    'quickcare-schedule-${_schedule.normalizedOperatingDays.join('-')}-${_schedule.openingTime ?? 'none'}-${_schedule.closingTime ?? 'none'}',
                  ),
                  initialValue: _schedule,
                  enabled: _editable,
                  operatingDaysRequired: true,
                  openingTimeRequired: true,
                  closingTimeRequired: true,
                  requireClosingAfterOpening: true,
                  sectionTitle: 'Operating Schedule',
                  operatingDaysLabel: 'Available days',
                  openingTimeLabel: 'Opening time',
                  closingTimeLabel: 'Closing time',
                  onChanged: (value) => _schedule = value,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'QuickCare Capability Profile',
              'Select only the services the Partner is qualified and willing to provide.',
              [
                CapabilityMultiSelector(
                  metadataProvider: QuickCarePartnerCapabilityMetadata.instance,
                  partnerCategoryCode:
                      QuickCarePartnerCapabilityMetadata.categoryCode,
                  initialValue: _capabilities,
                  enabled: _editable,
                  minimumSelectionCount: 0,
                  requireOtherExpertiseDescription: false,
                  sectionTitle: 'QuickCare capabilities',
                  onChanged: (value) => setState(() => _capabilities = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Experience & Skill Profile',
              'Describe who provides the service and the declared experience level.',
              [
                _dropdown(
                  'Provider type',
                  _providerTypeCode,
                  _providerTypes,
                  (value) => setState(() => _providerTypeCode = value),
                ),
                _dropdown(
                  'Skill level',
                  _skillLevelCode,
                  _skillLevels,
                  (value) => setState(() => _skillLevelCode = value),
                ),
                _field(
                  'Experience (years)',
                  _experience,
                  type: TextInputType.number,
                ),
                _field(
                  'Experience / qualification summary',
                  _experienceSummary,
                  hint: 'Training, practical experience or previous services',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Operations & Capacity',
              'Provide capacity, service duration and expected response time.',
              [
                _field('Team size', _teamSize, type: TextInputType.number),
                _field(
                  'Normal daily capacity',
                  _normalCapacity,
                  type: TextInputType.number,
                ),
                _field(
                  'Peak daily capacity',
                  _peakCapacity,
                  type: TextInputType.number,
                ),
                _dropdown(
                  'Typical service duration',
                  _durationCode,
                  _durations,
                  (value) => setState(() => _durationCode = value),
                ),
                _dropdown(
                  'Typical response time',
                  _responseTimeCode,
                  _responseTimes,
                  (value) => setState(() => _responseTimeCode = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Availability, Mobility & Customer Interaction',
              'Capture urgent availability, transport mode and customer coordination comfort.',
              [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _sameDay,
                  onChanged: _editable
                      ? (value) => setState(() => _sameDay = value)
                      : null,
                  title: const Text('Same-day service available'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _emergency,
                  onChanged: _editable
                      ? (value) => setState(() => _emergency = value)
                      : null,
                  title: const Text('Emergency service available'),
                ),
                _dropdown(
                  'Transport mode',
                  _transportModeCode,
                  _transportModes,
                  (value) => setState(() => _transportModeCode = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _customerCoordination,
                  onChanged: _editable
                      ? (value) => setState(() => _customerCoordination = value)
                      : null,
                  title: const Text(
                    'Comfortable coordinating directly with Customer',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              'Additional Information',
              'Add restrictions, special conditions or useful service information.',
              [
                _field(
                  'Additional notes',
                  _notes,
                  hint:
                      'Example: Weekend only or emergency subject to confirmation',
                  maxLines: 4,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _actions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
