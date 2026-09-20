import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PartnerProfileLandingScreen extends StatelessWidget {
  const PartnerProfileLandingScreen({
    super.key,
    this.accountId,
    this.partnerProfileId,
    this.partnerCategoryCode,
  });

  final String? accountId;
  final String? partnerProfileId;
  final String? partnerCategoryCode;

  bool get _isDesigner {
    return partnerCategoryCode?.trim().toLowerCase() == 'designer';
  }

  bool get _hasDesignerIdentity {
    return accountId?.trim().isNotEmpty == true &&
        partnerProfileId?.trim().isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Partner Profile'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0x1A00897B),
                  child: Icon(
                    Icons.handshake_outlined,
                    size: 34,
                    color: Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Partner Profile Active',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The Partner Business Profile is approved, '
                  'KYC verified and active.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The category-specific operational dashboard will be '
                  'connected during the Partner UI implementation phase.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_isDesigner) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _hasDesignerIdentity
                          ? () {
                              context.push(
                                '/partner/designer/catalogue'
                                '?accountId=${Uri.encodeQueryComponent(accountId!.trim())}'
                                '&profileId=${Uri.encodeQueryComponent(partnerProfileId!.trim())}',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.design_services_outlined),
                      label: const Text('My Catalogue Designs'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/profile-selection');
                    },
                    icon: const Icon(Icons.switch_account_outlined),
                    label: const Text('Change Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
