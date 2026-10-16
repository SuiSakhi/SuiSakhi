import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

// ============================================================================
// COMMON PARTNER FOUNDATION: BASIC DETAILS
// ============================================================================
//
// Shared by all Partner application categories:
//
// - Tailor
// - Measurement Partner
// - Doorstep Services
// - Delivery Partner
// - Laundry
// - Pressing
// - Designer
// - Boutique
// - Rental
//
// RESPONSIBILITIES:
//
// - Display common Partner identity and contact inputs.
// - Apply common client-side validation.
// - Respect the application's editable or read-only state.
// - Notify the parent screen when editable values change.
//
// THIS WIDGET MUST NOT:
//
// - Create or update Firestore documents.
// - Call PartnerService.
// - Change KYC or application status.
// - Contain Tailor-specific or Measurement-specific logic.
// - Own or dispose the supplied controllers.
//
// The parent application screen owns the controllers and persistence.
// ============================================================================

class PartnerBasicDetailsSection extends StatelessWidget {
  const PartnerBasicDetailsSection({
    required this.contactNameController,
    required this.businessNameController,
    required this.mobileController,
    required this.additionalContactNumbersController,
    required this.emailController,
    required this.editable,
    required this.description,
    this.businessNameLabel = 'Business or service name',
    this.businessNameHint = 'Optional at draft stage',
    this.onChanged,
    super.key,
  });

  final TextEditingController contactNameController;
  final TextEditingController businessNameController;
  final TextEditingController mobileController;
  final TextEditingController additionalContactNumbersController;
  final TextEditingController emailController;

  /// Whether applicant-maintained fields can currently be edited.
  final bool editable;

  /// Partner-category-aware supporting text shown below the section title.
  final String description;

  /// Category-aware label without embedding category logic in this widget.
  final String businessNameLabel;

  final String businessNameHint;

  /// Notifies the parent that a common Basic Details value changed.
  ///
  /// The parent may use this to refresh button state or mark the section dirty.
  final VoidCallback? onChanged;

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
          Text('Basic Details', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: contactNameController,
            readOnly: !editable,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Contact name',
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged?.call(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact name is required';
              }

              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: businessNameController,
            readOnly: !editable,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: businessNameLabel,
              hintText: businessNameHint,
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged?.call(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: mobileController,
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
            controller: additionalContactNumbersController,
            readOnly: !editable,
            keyboardType: TextInputType.phone,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Additional contact numbers (optional)',
              hintText: '9876543210, +919876543210',
              prefixIcon: Icon(Icons.contact_phone_outlined),
              border: OutlineInputBorder(),
              helperText: 'Separate numbers with commas. These are for Partner operations contact.',
            ),
            onChanged: (_) => onChanged?.call(),
            validator: (value) {
              final entries = (value ?? '').split(RegExp(r'[,;\n]'));
              for (final entry in entries.where((item) => item.trim().isNotEmpty)) {
                final compact = entry.trim().replaceAll(RegExp(r'[\s().-]'), '');
                if (!RegExp(r'^(\d{10}|\+\d{8,15})$').hasMatch(compact)) {
                  return 'Enter a 10-digit Indian mobile or an international number starting with +';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: emailController,
            readOnly: !editable,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged?.call(),
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
}
