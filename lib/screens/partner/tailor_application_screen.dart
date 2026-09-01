import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_application.dart';
import '../../services/partner_service.dart';

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
  final _workshopAddressLine1Controller = TextEditingController();

  final _workshopAddressLine2Controller = TextEditingController();

  final _workshopLocalityController = TextEditingController();

  final _workshopCityController = TextEditingController();

  final _workshopStateController = TextEditingController();

  final _workshopPincodeController = TextEditingController();

  final _serviceAreaPincodesController = TextEditingController();

  final _openingTimeController = TextEditingController();

  final _closingTimeController = TextEditingController();

  final _teamSizeController = TextEditingController();

  final _normalDailyCapacityController = TextEditingController();

  final _peakDailyCapacityController = TextEditingController();

  final _machineCodesController = TextEditingController();

  final _workshopNotesController = TextEditingController();

  String? _workshopTypeCode;

  final Set<String> _selectedOperatingDays = {};

  bool _pickupAvailable = false;
  bool _deliveryAvailable = false;
  bool _homeVisitAvailable = false;

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

  static const Map<String, String> _operatingDayLabels = {
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
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
        return 'Requires Attention';

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
      case PartnerApplicationStatus.changesRequested:
        return 'SuiSakhi Admin has requested additional information. '
            'Review the instructions below, update the required details, '
            'and submit the application again.';

      case PartnerApplicationStatus.submitted:
        return 'Your application has been submitted and is waiting '
            'for SuiSakhi Admin review.';

      case PartnerApplicationStatus.underReview:
        return 'Your application is currently being reviewed by '
            'SuiSakhi Admin. Editing is temporarily unavailable.';

      case PartnerApplicationStatus.approved:
        return 'Your Partner application has been approved. '
            'Partner profile activation will follow.';

      case PartnerApplicationStatus.rejected:
        return 'This application was not approved. Review the reason '
            'provided by SuiSakhi Admin.';

      case PartnerApplicationStatus.draft:
      case PartnerApplicationStatus.suspended:
      case PartnerApplicationStatus.inactive:
      case null:
        return 'Saving this form does not activate a Tailor profile. '
            'The application will be submitted for Admin review only '
            'after the required information is completed.';
    }
  }

  bool get _canSubmit {
    return _isEditable &&
        _contactNameController.text.trim().isNotEmpty &&
        _businessNameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().isNotEmpty;
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

    _workshopAddressLine1Controller.dispose();
    _workshopAddressLine2Controller.dispose();
    _workshopLocalityController.dispose();
    _workshopCityController.dispose();
    _workshopStateController.dispose();
    _workshopPincodeController.dispose();
    _serviceAreaPincodesController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
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

    _workshopAddressLine1Controller.text = details?.addressLine1 ?? '';

    _workshopAddressLine2Controller.text = details?.addressLine2 ?? '';

    _workshopLocalityController.text = details?.locality ?? '';

    _workshopCityController.text = details?.city ?? '';

    _workshopStateController.text = details?.state ?? '';

    _workshopPincodeController.text = details?.pincode ?? '';

    _serviceAreaPincodesController.text =
        details?.serviceAreaPincodes.join(', ') ?? '';

    _openingTimeController.text = details?.openingTime ?? '';

    _closingTimeController.text = details?.closingTime ?? '';

    _teamSizeController.text = details?.teamSize?.toString() ?? '';

    _normalDailyCapacityController.text =
        details?.normalDailyCapacity?.toString() ?? '';

    _peakDailyCapacityController.text =
        details?.peakDailyCapacity?.toString() ?? '';

    _machineCodesController.text = details?.machineCodes.join(', ') ?? '';

    _workshopNotesController.text = details?.additionalNotes ?? '';

    _selectedOperatingDays
      ..clear()
      ..addAll(details?.operatingDays ?? const []);

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
            'Application context is unavailable. Please reopen the form.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

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

      final workshopDetails = _buildWorkshopDetails();

      await PartnerService.updateWorkshopDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        workshopDetails: workshopDetails,
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
            'Partner application draft saved successfully',
          ),
          backgroundColor: AppColors.success,
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
        SnackBar(
          content: Text('Unable to save the application.\n$error'),
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
      addressLine1: _workshopAddressLine1Controller.text.trim(),
      addressLine2: _workshopAddressLine2Controller.text.trim(),
      locality: _workshopLocalityController.text.trim(),
      city: _workshopCityController.text.trim(),
      state: _workshopStateController.text.trim(),
      pincode: _workshopPincodeController.text.trim(),

      // Map-derived values remain unchanged until the map picker is added.
      placeId: existingDetails?.placeId,
      latitude: existingDetails?.latitude,
      longitude: existingDetails?.longitude,

      serviceAreaPincodes: _commaSeparatedValues(
        _serviceAreaPincodesController.text,
      ),
      operatingDays: _selectedOperatingDays.toList(
        growable: false,
      ),
      openingTime: _openingTimeController.text.trim(),
      closingTime: _closingTimeController.text.trim(),
      teamSize: _positiveIntOrNull(
        _teamSizeController.text,
      ),
      normalDailyCapacity: _positiveIntOrNull(
        _normalDailyCapacityController.text,
      ),
      peakDailyCapacity: _positiveIntOrNull(
        _peakDailyCapacityController.text,
      ),
      machineCodes: _commaSeparatedValues(
        _machineCodesController.text,
      ),
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
          _buildBasicDetailsCard(),
          const SizedBox(height: 20),
          _buildWorkshopDetailsCard(),
          const SizedBox(height: 20),
          _buildNextStepsCard(),
          const SizedBox(height: 20),

          if (_application?.status != PartnerApplicationStatus.draft) ...[
            _buildApplicationStatusMessage(),
            const SizedBox(height: 20),
          ],

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0x194CAF50),
            child: Icon(Icons.content_cut_rounded, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tailor Partner',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Application status: $_applicationStatusLabel',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF2E7D32),
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

  Widget _buildBasicDetailsCard() {
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
          Text('Basic Details', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'These details will be used for the Tailor application.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _contactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Contact name',
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact name is required';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _businessNameController,
            onChanged: (_) {
              setState(() {});
            },
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Business or workshop name',
              hintText: 'Optional at draft stage',
              prefixIcon: Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _mobileController,
            readOnly: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Authenticated mobile number',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
              filled: true,
              helperText:
                  'This mobile number is linked to your SuiSakhi account.',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return null;
              }

              if (!email.contains('@') || email.length < 5) {
                return 'Enter a valid email or leave blank';
              }

              return null;
            },
          ),
        ],
      ),
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

          TextFormField(
            controller: _workshopAddressLine1Controller,
            readOnly: !_isEditable,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Workshop address',
              hintText: 'House, building, road or landmark',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _workshopAddressLine2Controller,
            readOnly: !_isEditable,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Address line 2',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.location_city_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _workshopLocalityController,
            readOnly: !_isEditable,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Locality or area',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.map_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _workshopCityController,
                  readOnly: !_isEditable,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _workshopStateController,
                  readOnly: !_isEditable,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _workshopPincodeController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Pincode',
              hintText: 'Six-digit pincode',
              prefixIcon: Icon(Icons.pin_drop_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
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

          Text(
            'Operating days',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _operatingDayLabels.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _selectedOperatingDays.contains(entry.key),
                  onSelected: _isEditable
                      ? (selected) {
                          setState(() {
                            if (selected) {
                              _selectedOperatingDays.add(entry.key);
                            } else {
                              _selectedOperatingDays.remove(entry.key);
                            }
                          });
                        }
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _openingTimeController,
                  readOnly: !_isEditable,
                  decoration: const InputDecoration(
                    labelText: 'Opening time',
                    hintText: '10:00',
                    prefixIcon: Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _closingTimeController,
                  readOnly: !_isEditable,
                  decoration: const InputDecoration(
                    labelText: 'Closing time',
                    hintText: '20:00',
                    prefixIcon: Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
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
            title: const Text('Pickup available'),
            subtitle: const Text(
              'Workshop can support garment or material pickup.',
            ),
            value: _pickupAvailable,
            onChanged: _isEditable
                ? (value) {
                    setState(() {
                      _pickupAvailable = value;
                    });
                  }
                : null,
          ),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delivery available'),
            subtitle: const Text(
              'Workshop can support completed-order delivery.',
            ),
            value: _deliveryAvailable,
            onChanged: _isEditable
                ? (value) {
                    setState(() {
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
                  ? 'Workshop Details are read-only while '
                        'the application is under Admin review.'
                  : 'Workshop Details are not editable in '
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
          _buildNextStep(
            Icons.checklist_rounded,
            'Services and specialization',
          ),
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

  Widget _buildApplicationStatusMessage() {
    final status = _application?.status;

    if (status == PartnerApplicationStatus.submitted) {
      return _buildStatusNotice(
        icon: Icons.schedule_send_outlined,
        title: 'Application Submitted',
        message:
            'Your Tailor Partner application has been submitted to '
            'SuiSakhi Admin. Review has not started yet.',
        color: const Color(0xFFFF9800),
      );
    }

    if (status == PartnerApplicationStatus.underReview) {
      return _buildStatusNotice(
        icon: Icons.manage_search_rounded,
        title: 'Application Under Review',
        message:
            'SuiSakhi Admin is reviewing your Tailor Partner application. '
            'You cannot edit or resubmit it during the review. We will '
            'notify you if any additional information or corrections are required.',
        color: const Color(0xFF2196F3),
      );
    }

    if (status == PartnerApplicationStatus.changesRequested) {
      final instructions = _application?.reviewNotes?.trim();

      return _buildStatusNotice(
        icon: Icons.edit_note_rounded,
        title: 'Changes Requested',
        message: instructions == null || instructions.isEmpty
            ? 'SuiSakhi Admin needs additional information. '
                  'Please update the application and submit it again.'
            : 'Admin instructions: $instructions',
        color: const Color(0xFFFF9800),
      );
    }

    if (status == PartnerApplicationStatus.approved) {
      return _buildStatusNotice(
        icon: Icons.verified_rounded,
        title: 'Application Approved',
        message:
            'Your Tailor Partner application has been approved. '
            'Partner profile activation details will appear here.',
        color: const Color(0xFF4CAF50),
      );
    }

    if (status == PartnerApplicationStatus.rejected) {
      final reason = _application?.rejectionReason?.trim();

      return _buildStatusNotice(
        icon: Icons.cancel_outlined,
        title: 'Application Not Approved',
        message: reason == null || reason.isEmpty
            ? 'SuiSakhi could not approve this Partner application. '
                  'Please contact SuiSakhi Helpdesk for clarification.'
            : 'Reason: $reason\n\n'
                  'Please contact SuiSakhi Helpdesk if clarification is required.',
        color: AppColors.error,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusNotice({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
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

  Widget _buildActions() {
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

    if (_application?.status == PartnerApplicationStatus.approved) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _continueLater,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Back to Partner Opportunities'),
        ),
      );
    }

    if (_application?.status == PartnerApplicationStatus.rejected) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _continueLater,
          icon: const Icon(Icons.support_agent_outlined),
          label: const Text('Back to Partner Opportunities'),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving || !_isEditable ? null : _saveDraft,
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
            onPressed: _canSubmit && !_saving ? _submitForReview : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Submit For Review'),
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
}
