/*
===============================================================================
SuiSakhi Designer Partner Application Screen

Purpose:
Handles Designer Partner onboarding using the common Partner application
foundation and Designer-specific onboarding information.

The screen reuses the common Partner lifecycle and stores Designer-specific
information under:

onboardingData.extensions.designer

This screen does not perform KYC, approval, Partner activation, or Designer
catalogue publishing.
===============================================================================
*/

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/metadata/designer_partner_capability_metadata.dart';
import '../../models/designer_partner_details.dart';
import '../../models/partner_application.dart';
import '../../models/partner_capability_selection.dart';
import '../../services/partner_service.dart';
import '../../widgets/capability/capability_multi_selector.dart';
import '../../widgets/partner/partner_basic_details_section.dart';

// ============================================================================
// DESIGNER PARTNER APPLICATION
// ============================================================================

class DesignerApplicationScreen extends StatefulWidget {
  const DesignerApplicationScreen({super.key});

  @override
  State<DesignerApplicationScreen> createState() =>
      _DesignerApplicationScreenState();
}

class _DesignerApplicationScreenState extends State<DesignerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ==========================================================================
  // COMMON PARTNER FOUNDATION: BASIC DETAILS
  // ==========================================================================

  final _contactNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  // ==========================================================================
  // DESIGNER PARTNER EXTENSION
  // ==========================================================================

  final _professionalTypeController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _specializationController = TextEditingController();
  final _portfolioSummaryController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  PartnerCapabilitySelection _capabilitySelection =
      const PartnerCapabilitySelection();

  bool _acceptsCustomDesign = false;
  bool _acceptsBulkOrders = false;
  bool _acceptsWeddingOrders = false;
  bool _consultationAvailable = false;
  bool _originalWorkDeclaration = false;

  // ==========================================================================
  // COMMON PARTNER APPLICATION FOUNDATION
  // ==========================================================================

  PartnerApplication? _application;

  String? _accountId;
  String? _customerProfileId;

  bool _loading = true;
  bool _saving = false;

  String? _loadError;

  // ==========================================================================
  // APPLICATION STATE HELPERS
  // ==========================================================================

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
        _mobileController.text.trim().isNotEmpty &&
        _professionalTypeController.text.trim().isNotEmpty &&
        _originalWorkDeclaration;
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
            'Please review the instructions, update your details, '
            'and submit the application again.';

      case PartnerApplicationStatus.submitted:
        return 'Your Designer Partner application has been submitted '
            'and is waiting for SuiSakhi Admin review.';

      case PartnerApplicationStatus.underReview:
        return 'Your Designer Partner application is currently being '
            'reviewed by SuiSakhi Admin. Editing is temporarily unavailable.';

      case PartnerApplicationStatus.approved:
        return 'Your Designer Partner application has been approved. '
            'Partner profile activation will follow.';

      case PartnerApplicationStatus.rejected:
        return 'This application was not approved. Review the reason '
            'provided by SuiSakhi Admin.';

      case PartnerApplicationStatus.draft:
      case PartnerApplicationStatus.suspended:
      case PartnerApplicationStatus.inactive:
      case null:
        return 'Complete your Designer Partner information and save your '
            'application as a draft. Submission will send it for Admin review.';
    }
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

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

    _professionalTypeController.dispose();
    _experienceYearsController.dispose();
    _specializationController.dispose();
    _portfolioSummaryController.dispose();
    _additionalNotesController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // APPLICATION INITIALIZATION
  // ==========================================================================

  Future<void> _initializeApplication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw StateError(
          'Please sign in again before starting a Designer Partner application.',
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

      // ACCOUNT-LEVEL FOUNDATION
      _contactNameController.text = profileName;
      _mobileController.text = phone;
      _emailController.text = profileEmail;

      // DESIGNER PARTNER DRAFT CREATION / RESUME
      final application = await PartnerService.createDraft(
        accountId: accountId,
        customerProfileId: customerProfileId,
        partnerType: PartnerType.designer,
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

      // EXISTING APPLICATION VALUES ALWAYS TAKE PRIORITY
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

      // DESIGNER EXTENSION
      final details = DesignerPartnerDetails.fromOnboardingData(
        application.onboardingData,
      );

      _hydrateDesignerDetails(details);

      if (!mounted) {
        return;
      }

      setState(() {
        _accountId = accountId;
        _customerProfileId = customerProfileId;
        _application = application;
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

  // ==========================================================================
  // DESIGNER EXTENSION: HYDRATION
  // ==========================================================================

  void _hydrateDesignerDetails(DesignerPartnerDetails details) {
    _professionalTypeController.text = details.professionalType ?? '';
    _experienceYearsController.text = details.experienceYears?.toString() ?? '';
    _specializationController.text = details.specialization ?? '';
    _portfolioSummaryController.text = details.portfolioSummary ?? '';
    _additionalNotesController.text = details.additionalNotes ?? '';

    _capabilitySelection = details.capabilitySelection;

    _acceptsCustomDesign = details.acceptsCustomDesign;
    _acceptsBulkOrders = details.acceptsBulkOrders;
    _acceptsWeddingOrders = details.acceptsWeddingOrders;
    _consultationAvailable = details.consultationAvailable;
    _originalWorkDeclaration = details.originalWorkDeclaration;
  }

  // ==========================================================================
  // DESIGNER EXTENSION: BUILD MODEL
  // ==========================================================================

  DesignerPartnerDetails _buildDesignerDetails() {
    int? experienceYears;

    final experienceText = _experienceYearsController.text.trim();

    if (experienceText.isNotEmpty) {
      experienceYears = int.tryParse(experienceText);
    }

    return DesignerPartnerDetails(
      professionalType: _professionalTypeController.text.trim().isEmpty
          ? null
          : _professionalTypeController.text.trim(),
      experienceYears: experienceYears,
      specialization: _specializationController.text.trim().isEmpty
          ? null
          : _specializationController.text.trim(),
      capabilitySelection: _capabilitySelection,
      portfolioSummary: _portfolioSummaryController.text.trim().isEmpty
          ? null
          : _portfolioSummaryController.text.trim(),
      acceptsCustomDesign: _acceptsCustomDesign,
      acceptsBulkOrders: _acceptsBulkOrders,
      acceptsWeddingOrders: _acceptsWeddingOrders,
      consultationAvailable: _consultationAvailable,
      originalWorkDeclaration: _originalWorkDeclaration,
      additionalNotes: _additionalNotesController.text.trim().isEmpty
          ? null
          : _additionalNotesController.text.trim(),
    );
  }

  // ==========================================================================
  // SAVE DRAFT
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
      _showError('Application context is unavailable. Please reopen the form.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // COMMON PARTNER FOUNDATION
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      // DESIGNER PARTNER EXTENSION
      await PartnerService.updateDesignerDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        designerDetails: _buildDesignerDetails(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showSuccess('Designer Partner draft saved successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError('Unable to save Designer Partner draft.\n$error');
    }
  }

  // ==========================================================================
  // SUBMIT FOR ADMIN REVIEW
  // ==========================================================================

  Future<void> _submitForReview() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_originalWorkDeclaration) {
      _showError(
        'Please confirm the original-work and rights declaration '
        'before submitting.',
      );
      return;
    }

    final application = _application;
    final accountId = _accountId;
    final customerProfileId = _customerProfileId;

    if (application == null || accountId == null || customerProfileId == null) {
      _showError('Application context is unavailable. Please reopen the form.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // STEP 1: SAVE COMMON BASIC DETAILS
      await PartnerService.updateDraft(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        contactName: _contactNameController.text,
        businessName: _businessNameController.text,
        mobileE164: _mobileController.text,
        email: _emailController.text,
      );

      // STEP 2: SAVE DESIGNER EXTENSION
      await PartnerService.updateDesignerDetails(
        applicationId: application.id,
        accountId: accountId,
        customerProfileId: customerProfileId,
        designerDetails: _buildDesignerDetails(),
      );

      // STEP 3: COMMON PARTNER LIFECYCLE
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

      _showSuccess(
        'Designer Partner application submitted for Admin and KYC review.',
      );

      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showError('Unable to submit Designer Partner application.\n$error');
    }
  }

  // ==========================================================================
  // APPLICATION HEADER
  // ==========================================================================

  Widget _buildApplicationHeader() {
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
              const Icon(Icons.design_services_outlined, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Designer Partner Application',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _applicationHeaderMessage,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Chip(label: Text(_applicationStatusLabel)),
        ],
      ),
    );
  }

  // ==========================================================================
  // DESIGNER PROFESSIONAL DETAILS
  // ==========================================================================

  Widget _buildProfessionalDetailsCard() {
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
          Text('Professional Details', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Tell SuiSakhi about your design background and professional '
            'specialization.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // DESIGNER PROFESSIONAL TYPE
          TextFormField(
            controller: _professionalTypeController,
            readOnly: !_isEditable,
            decoration: const InputDecoration(
              labelText: 'Professional type',
              hintText: 'Example: Fashion Designer',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (_isEditable && (value == null || value.trim().isEmpty)) {
                return 'Enter your professional type';
              }

              return null;
            },
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 14),

          // EXPERIENCE
          TextFormField(
            controller: _experienceYearsController,
            readOnly: !_isEditable,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Experience',
              hintText: 'Optional',
              suffixText: 'years',
              prefixIcon: Icon(Icons.timeline_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';

              if (text.isEmpty) {
                return null;
              }

              final years = int.tryParse(text);

              if (years == null || years < 0) {
                return 'Enter a valid number of years';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),

          // SPECIALIZATION
          TextFormField(
            controller: _specializationController,
            readOnly: !_isEditable,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Design specialization',
              hintText: 'Example: Bridal, Contemporary, Traditional, Couture',
              prefixIcon: Icon(Icons.auto_awesome_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DESIGNER CAPABILITIES
  // ==========================================================================

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
          Text('Designer Capabilities', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Select the types of design work you currently offer.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // DESIGNER CAPABILITY METADATA
          CapabilityMultiSelector(
            key: ValueKey(
              'designer-capabilities-'
              '${_capabilitySelection.normalizedCapabilityCodes.join('-')}-'
              '${_capabilitySelection.normalizedAdditionalDescriptions.join('-')}',
            ),
            metadataProvider: DesignerPartnerCapabilityMetadata.instance,
            partnerCategoryCode: DesignerPartnerCapabilityMetadata.categoryCode,
            initialValue: _capabilitySelection,
            enabled: _isEditable,
            minimumSelectionCount: 0,
            sectionTitle: 'Available Design Services',
            sectionDescription:
                'Some capabilities may require additional Admin '
                'verification before assignment.',
            showOtherExpertise: true,
            requireOtherExpertiseDescription: false,
            otherExpertiseLabel: 'Other Design Service',
            otherExpertiseHint: 'Describe another design capability',
            onChanged: (selection) {
              _capabilitySelection = selection;
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SERVICE PREFERENCES
  // ==========================================================================

  Widget _buildServicePreferencesCard() {
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
          Text('Service Preferences', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Tell SuiSakhi which types of Designer work you are willing '
            'to accept.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptsCustomDesign,
            enabled: _isEditable,
            title: const Text('Accept custom design requests'),
            subtitle: const Text(
              'Special or personalized design requirements.',
            ),
            onChanged: (value) {
              setState(() {
                _acceptsCustomDesign = value ?? false;
              });
            },
          ),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptsBulkOrders,
            enabled: _isEditable,
            title: const Text('Accept bulk orders'),
            subtitle: const Text(
              'Bulk, corporate, school or event requirements.',
            ),
            onChanged: (value) {
              setState(() {
                _acceptsBulkOrders = value ?? false;
              });
            },
          ),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptsWeddingOrders,
            enabled: _isEditable,
            title: const Text('Accept wedding / bridal orders'),
            subtitle: const Text(
              'Wedding, bridal and occasion-specific design work.',
            ),
            onChanged: (value) {
              setState(() {
                _acceptsWeddingOrders = value ?? false;
              });
            },
          ),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consultationAvailable,
            enabled: _isEditable,
            title: const Text('Designer consultation available'),
            subtitle: const Text('Available for Customer design consultation.'),
            onChanged: (value) {
              setState(() {
                _consultationAvailable = value ?? false;
              });
            },
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PORTFOLIO
  // ==========================================================================

  Widget _buildPortfolioCard() {
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
            'Portfolio & Additional Information',
            style: AppTextStyles.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'A short summary helps Admin understand your design experience. '
            'Portfolio upload can be added through the existing document '
            'architecture later.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _portfolioSummaryController,
            readOnly: !_isEditable,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Portfolio summary',
              hintText:
                  'Describe your design background, notable work and style.',
              prefixIcon: Icon(Icons.collections_outlined),
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: _additionalNotesController,
            readOnly: !_isEditable,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Additional notes',
              hintText: 'Optional',
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
  // RIGHTS / ORIGINAL WORK DECLARATION
  // ==========================================================================

  Widget _buildRightsDeclarationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _originalWorkDeclaration,
        enabled: _isEditable,
        title: const Text('Original work / rights declaration'),
        subtitle: const Text(
          'I confirm that designs I submit to SuiSakhi are my original '
          'work or that I have the required rights or permission to use '
          'them.',
        ),
        onChanged: (value) {
          setState(() {
            _originalWorkDeclaration = value ?? false;
          });
        },
      ),
    );
  }

  // ==========================================================================
  // ACTIONS
  // ==========================================================================

  Widget _buildActions() {
    if (!_isEditable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isUnderAdminReview)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'Editing is temporarily unavailable while Admin reviews '
                'this application.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _canSaveDraft ? _saveDraft : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save Draft'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _canSubmit ? _submitForReview : null,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit for Admin Review'),
        ),
      ],
    );
  }

  // ==========================================================================
  // FEEDBACK HELPERS
  // ==========================================================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Designer Partner Application'),
          centerTitle: true,
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Designer Partner Application'),
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
                  'Unable to load Designer Partner information.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
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
                      _loading = true;
                      _loadError = null;
                    });

                    _initializeApplication();
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
        title: const Text('Designer Partner Application'),
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

            // COMMON PARTNER FOUNDATION: BASIC DETAILS
            PartnerBasicDetailsSection(
              contactNameController: _contactNameController,
              businessNameController: _businessNameController,
              mobileController: _mobileController,
              emailController: _emailController,
              editable: _isEditable,
              description:
                  'These details will be used for your Designer Partner '
                  'application.',
              businessNameLabel: 'Business or Designer name',
              businessNameHint: 'Enter your professional or business name',
              onChanged: () {
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),

            _buildProfessionalDetailsCard(),
            const SizedBox(height: 16),

            _buildCapabilitiesCard(),
            const SizedBox(height: 16),

            _buildServicePreferencesCard(),
            const SizedBox(height: 16),

            _buildPortfolioCard(),
            const SizedBox(height: 16),

            _buildRightsDeclarationCard(),
            const SizedBox(height: 16),

            _buildActions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
