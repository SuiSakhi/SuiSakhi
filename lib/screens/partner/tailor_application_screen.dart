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

  PartnerApplication? _application;

  String? _accountId;
  String? _customerProfileId;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
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

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tailor application draft saved'),
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
          _buildNextStep(Icons.store_outlined, 'Workshop details'),
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
