import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/partner_workspace_profile.dart';
import '../../services/partner_workspace_data_formatter.dart';
import '../../services/partner_workspace_registry.dart';
import '../../services/partner_workspace_service.dart';

class PartnerBusinessDetailsScreen extends StatelessWidget {
  const PartnerBusinessDetailsScreen({
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
          return _MessageScaffold(
            title: 'Business Details',
            message: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data!;
        final approvedFields = PartnerWorkspaceDataFormatter.flatten(
          profile.partnerData,
          includeAddressFields: false,
        );
        final grouped = <String, List<PartnerWorkspaceDataField>>{};
        for (final field in approvedFields) {
          grouped.putIfAbsent(field.section, () => []).add(field);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Business Details'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Business Summary',
                fields: [
                  ('Business Name', profile.businessDisplayName),
                  (
                    'Partner Category',
                    PartnerWorkspaceRegistry.categoryLabel(profile.partnerType),
                  ),
                  ('Contact Name', profile.contactName ?? 'Not available'),
                  ('Mobile Number', profile.mobileE164 ?? 'Not available'),
                  ('Email Address', profile.email ?? 'Not available'),
                ],
              ),
              if (grouped.isEmpty)
                const _InformationBanner(
                  text:
                      'No additional approved category-specific business details are available in this profile snapshot.',
                )
              else
                for (final entry in grouped.entries)
                  _SectionCard(
                    title: entry.key,
                    fields: [
                      for (final field in entry.value)
                        (field.label, field.value),
                    ],
                  ),
              const _InformationBanner(
                text:
                    'These values are the active Admin-approved Partner profile snapshot. Profile-change requests will be introduced through a governed review flow in a future phase.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.fields});

  final String title;
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < fields.length; index++) ...[
            _DetailRow(label: fields[index].$1, value: fields[index].$2),
            if (index < fields.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _InformationBanner extends StatelessWidget {
  const _InformationBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
