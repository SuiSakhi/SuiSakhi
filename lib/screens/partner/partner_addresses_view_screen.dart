import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_workspace_profile.dart';
import '../../services/partner_workspace_data_formatter.dart';
import '../../services/partner_workspace_service.dart';

class PartnerAddressesViewScreen extends StatelessWidget {
  const PartnerAddressesViewScreen({
    super.key,
    required this.accountId,
    required this.profileId,
  });

  final String accountId;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PartnerWorkspaceProfile>(
      future: PartnerWorkspaceService.requirePartnerProfile(
        accountId: accountId,
        profileId: profileId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Approved Addresses')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}', textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;
        final fields = PartnerWorkspaceDataFormatter.addressFields(
          profile.partnerData,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Approved Addresses'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AddressHeader(profileName: profile.businessDisplayName),
              const SizedBox(height: 16),
              if (fields.isEmpty)
                const _EmptyAddressState()
              else
                _AddressDetailsCard(fields: fields),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'This page displays the active Admin-approved Partner business address, service area, pickup, and workshop location information. Customer delivery addresses are managed separately.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader({required this.profileName});

  final String profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.10),
            child: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approved Business Location',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profileName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressDetailsCard extends StatelessWidget {
  const _AddressDetailsCard({required this.fields});

  final List<PartnerWorkspaceDataField> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            Text(
              fields[index].label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fields[index].value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (index < fields.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _EmptyAddressState extends StatelessWidget {
  const _EmptyAddressState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 46,
            color: AppColors.textHint,
          ),
          SizedBox(height: 14),
          Text(
            'No approved business address is available in the active Partner profile snapshot.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
