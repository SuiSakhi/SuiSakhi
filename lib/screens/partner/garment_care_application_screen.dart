import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/garment_care_partner_capability_metadata.dart';
import '../../core/metadata/india_address_metadata.dart';
import '../../models/address_details.dart';
import '../../models/garment_care_partner_details.dart';
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

/// Garment Care Partner onboarding using the common Partner foundation.
///
/// Category-specific information is stored under:
/// onboardingData.extensions.garmentCare
class GarmentCareApplicationScreen extends StatefulWidget {
  const GarmentCareApplicationScreen({super.key});

  @override
  State<GarmentCareApplicationScreen> createState() =>
      _GarmentCareApplicationScreenState();
}

class _GarmentCareApplicationScreenState
    extends State<GarmentCareApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common Partner Basic Details.
  final _contactNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  // Common Partner business location and schedule.
  AddressDetails _businessAddress = const AddressDetails();
  OperatingSchedule _operatingSchedule = const OperatingSchedule();
  final _serviceAreaPincodesController = TextEditingController();

  // Garment Care-specific operations.
  final _experienceYearsController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _normalDailyCapacityController = TextEditingController();
  final _peakDailyCapacityController = TextEditingController();
  final _averageTurnaroundHoursController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  PartnerCapabilitySelection _capabilitySelection =
      const PartnerCapabilitySelection();

  bool _expressServiceAvailable = false;

  PartnerApplication? _application;
  String? _accountId;
  String? _customerProfileId;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isEditable => _application?.canEdit == true;

  // Phase-1 follows the simplified Partner onboarding rule.
  // Admin may request missing information during review.
  bool get _canSubmit => _isEditable && !_saving;

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
    _experienceYearsController.dispose();
    _teamSizeController.dispose();
    _normalDailyCapacityController.dispose();
    _peakDailyCapacityController.dispose();
    _averageTurnaroundHoursController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  Future<void> _initializeApplication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final phone = user?.phoneNumber?.trim();

      if (user == null || phone == null || phone.isEmpty) {
        throw StateError(
          'Please sign in again before starting a Garment Care Partner application.',
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
        if ((profile['role'] ?? '').toString() == 'customer') {
          customerProfile = profile;
          break;
        }
      }

      final customerProfileId =
          (customerProfile?['profileId'] ?? customerProfile?['docId'])
              ?.toString()
              .trim();

      if (customerProfileId == null || customerProfileId.isEmpty) {
        throw StateError('Your active Customer profile could not be resolved.');
      }

      final profileName =
          (customerProfile?['displayName'] ?? AppState.instance.displayName)
              .toString()
              .trim();
      final profileEmail = (customerProfile?['email'] ?? user.email ?? '')
          .toString()
          .trim();

      final application = await PartnerService.createDraft(
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.garmentCare,
        contactName: profileName.isEmpty ? null : profileName,
        mobileE164: phone,
        email: profileEmail.isEmpty ? null : profileEmail,
      );

      _accountId = accountId;
      _customerProfileId = customerProfileId;
      _application = application;

      _contactNameController.text =
          application.contactName ?? (profileName.isEmpty ? '' : profileName);
      _businessNameController.text = application.businessName ?? '';
      _mobileController.text = application.mobileE164 ?? phone;
      _emailController.text =
          application.email ?? (profileEmail.isEmpty ? '' : profileEmail);

      _hydrateCommonBusiness(application);
      _hydrateGarmentCareDetails(
        GarmentCarePartnerDetails.fromOnboardingData(
          application.onboardingData,
        ),
      );

      if (!mounted) {
        return;
      }

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

  void _hydrateCommonBusiness(PartnerApplication application) {
    final extensionsValue = application.onboardingData['extensions'];

    if (extensionsValue is! Map) {
      return;
    }

    final extensions = Map<String, dynamic>.from(extensionsValue);
    final categoryValue = extensions[PartnerType.garmentCare.name];

    if (categoryValue is! Map) {
      return;
    }

    final category = Map<String, dynamic>.from(categoryValue);
    final workshopValue = category['workshopDetails'];

    if (workshopValue is! Map) {
      return;
    }

    final details = PartnerWorkshopDetails.fromMap(
      Map<String, dynamic>.from(workshopValue),
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

    _serviceAreaPincodesController.text = details.serviceAreaPincodes.join(
      ', ',
    );
  }

  void _hydrateGarmentCareDetails(GarmentCarePartnerDetails details) {
    _capabilitySelection = details.capabilitySelection;
    _experienceYearsController.text = details.experienceYears?.toString() ?? '';
    _serviceAreaPincodesController.text =
        details.serviceArea ?? _serviceAreaPincodesController.text;
    _teamSizeController.text = details.teamSize?.toString() ?? '';
    _normalDailyCapacityController.text =
        details.normalDailyCapacity?.toString() ?? '';
    _peakDailyCapacityController.text =
        details.peakDailyCapacity?.toString() ?? '';
    _averageTurnaroundHoursController.text =
        details.averageTurnaroundHours?.toString() ?? '';
    _expressServiceAvailable = details.expressServiceAvailable;
    _additionalNotesController.text = details.additionalNotes ?? '';
  }

  GarmentCarePartnerDetails _buildGarmentCareDetails() {
    return GarmentCarePartnerDetails(
      capabilitySelection: _capabilitySelection,
      experienceYears: _intValue(_experienceYearsController),
      serviceArea: _serviceAreaPincodesController.text,
      teamSize: _intValue(_teamSizeController),
      normalDailyCapacity: _intValue(_normalDailyCapacityController),
      peakDailyCapacity: _intValue(_peakDailyCapacityController),
      averageTurnaroundHours: _intValue(_averageTurnaroundHoursController),
      expressServiceAvailable: _expressServiceAvailable,
      additionalNotes: _additionalNotesController.text,
    );
  }

  PartnerWorkshopDetails _buildBusinessDetails() {
    return PartnerWorkshopDetails(
      addressLine1: _businessAddress.addressLine1,
      addressLine2: _businessAddress.addressLine2,
      locality: _businessAddress.locality,
      city: _businessAddress.cityName,
      state: _businessAddress.stateName,
      pincode: _businessAddress.pincode,
      placeId: _businessAddress.placeId,
      latitude: _businessAddress.latitude,
      longitude: _businessAddress.longitude,
      serviceAreaPincodes: _commaSeparated(_serviceAreaPincodesController.text),
      operatingDays: _operatingSchedule.normalizedOperatingDays,
      openingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.openingTime,
      ),
      closingTime: OperatingSchedule.normalizedTimeOrNull(
        _operatingSchedule.closingTime,
      ),
      teamSize: _intValue(_teamSizeController),
      normalDailyCapacity: _intValue(_normalDailyCapacityController),
      peakDailyCapacity: _intValue(_peakDailyCapacityController),
      additionalNotes: _additionalNotesController.text.trim(),
    );
  }

  int? _intValue(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  List<String> _commaSeparated(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _save({required bool submit}) async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final application = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (application == null || accountId == null || customerProfileId == null) {
      _showMessage('Application context is unavailable.', isError: true);
      return;
    }

    setState(() {
      _saving = true;
    });

    var saveStage = 'Basic Details';

    try {
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      saveStage = 'business address and operating schedule';

      await PartnerService.updatePartnerBusinessDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.garmentCare,
        workshopDetails: _buildBusinessDetails(),
      );

      saveStage = 'Garment Care services and operations';

      await PartnerService.updateGarmentCareDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        garmentCareDetails: _buildGarmentCareDetails(),
      );

      if (submit) {
        saveStage = 'application submission';

        await PartnerService.submitApplication(
          applicationId: application.id,
          accountId: accountId,
          customerProfileId: customerProfileId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(
        submit
            ? 'Garment Care Partner application submitted for Admin review.'
            : 'Garment Care Partner draft saved successfully.',
      );

      if (submit) {
        context.pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage('Unable to save $saveStage.\n$error', isError: true);
    }
  }

  void _hydrateApplication(PartnerApplication application) {
    _application = application;
    _contactNameController.text = application.contactName ?? '';
    _businessNameController.text = application.businessName ?? '';
    _mobileController.text = application.mobileE164 ?? '';
    _emailController.text = application.email ?? '';
    _hydrateCommonBusiness(application);
    _hydrateGarmentCareDetails(
      GarmentCarePartnerDetails.fromOnboardingData(application.onboardingData),
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
      partnerLabel: 'Garment Care Partner',
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
      _showMessage(
        'A new Garment Care Partner Draft was created. Review the copied information before submitting.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(
        'Unable to create a new Garment Care Partner application.\n$error',
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
      canSaveDraft: _isEditable && !_saving,
      canSubmit: _canSubmit,
      onSaveDraft: () => _save(submit: false),
      onSubmitForReview: () => _save(submit: true),
      onApplyAgain: _applyAgain,
      onContinueLater: _continueLater,
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : const Color(0xFF2E7D32),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: !_isEditable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
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
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Garment Care Partner Application')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Garment Care Partner Application'),
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
              partnerLabel: 'Garment Care Partner',
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Basic Details',
              description: 'Common Partner identity and contact information.',
              children: [
                PartnerBasicDetailsSection(
                  contactNameController: _contactNameController,
                  businessNameController: _businessNameController,
                  mobileController: _mobileController,
                  emailController: _emailController,
                  editable: _isEditable,
                  description:
                      'Common Partner identity and contact information.',
                  businessNameLabel: 'Garment Care business name',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Business Location',
              description:
                  'Provide the primary Garment Care business address and service area.',
              children: [
                AddressFormSection(
                  key: ValueKey(
                    'garment-care-address-'
                    '${_businessAddress.stateCode ?? _businessAddress.stateName ?? 'none'}-'
                    '${_businessAddress.cityCode ?? _businessAddress.cityName ?? 'none'}',
                  ),
                  metadataProvider: IndiaAddressMetadata.instance,
                  initialValue: _businessAddress,
                  enabled: _isEditable,
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
                  onChanged: (address) {
                    _businessAddress = address;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  'Service-area pincodes',
                  _serviceAreaPincodesController,
                  hint: 'Example: 411001, 411002',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Operating Schedule',
              description:
                  'Tell customers and SuiSakhi when the Garment Care business is available.',
              children: [
                OperatingScheduleField(
                  key: ValueKey(
                    'garment-care-schedule-'
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
              ],
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Garment Care Capabilities',
              description:
                  'Select the services, materials and Pickup & Delivery capability offered by the business.',
              children: [
                CapabilityMultiSelector(
                  metadataProvider:
                      GarmentCarePartnerCapabilityMetadata.instance,
                  partnerCategoryCode:
                      GarmentCarePartnerCapabilityMetadata.categoryCode,
                  initialValue: _capabilitySelection,
                  enabled: _isEditable,
                  minimumSelectionCount: 0,
                  requireOtherExpertiseDescription: false,
                  sectionTitle: 'Garment Care capabilities',
                  onChanged: (selection) {
                    setState(() {
                      _capabilitySelection = selection;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Operations & Capacity',
              description:
                  'Provide experience, capacity, turnaround time and express-service information.',
              children: [
                _field(
                  'Experience (years)',
                  _experienceYearsController,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  'Team size',
                  _teamSizeController,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  'Normal daily capacity',
                  _normalDailyCapacityController,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  'Peak daily capacity',
                  _peakDailyCapacityController,
                  keyboardType: TextInputType.number,
                ),
                _field(
                  'Average turnaround time (hours)',
                  _averageTurnaroundHoursController,
                  hint: 'Example: 24, 48 or 72',
                  keyboardType: TextInputType.number,
                ),
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: _expressServiceAvailable,
                    onChanged: _isEditable
                        ? (value) {
                            setState(() {
                              _expressServiceAvailable = value ?? false;
                            });
                          }
                        : null,
                    title: const Text('Express service available'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _card(
              title: 'Additional Information',
              description:
                  'Add optional restrictions, special services or other operational notes.',
              children: [
                _field(
                  'Additional notes',
                  _additionalNotesController,
                  hint: 'Optional restrictions or service information',
                ),
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
