import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/security_template.dart';
import '../../services/security_template_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, required this.audience});

  final String audience;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String? _partnerCategoryFilter;

  @override
  Widget build(BuildContext context) {
    final isPartner = widget.audience == 'partner';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy & Legal'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<List<SecurityTemplate>>(
        stream: SecurityTemplateService.watchPublishedTemplates(
          widget.audience,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint(
              'Privacy & Security failed to load for ${widget.audience}: '
              '${snapshot.error}\n${snapshot.stackTrace}',
            );
            return const _Message(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy information is unavailable',
              message: 'Please try again later or contact SuiSakhi support.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return _Message(
              icon: Icons.verified_user_outlined,
              title: 'Information is being prepared',
              message: isPartner
                  ? 'Approved partner privacy, security and legal information will appear here.'
                  : 'Approved privacy, security and legal information will appear here.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                isPartner
                    ? 'Privacy, security and legal information for your SuiSakhi partner account.'
                    : 'Privacy, security and legal information for your SuiSakhi account.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (isPartner) ...[
                Text(
                  'Find the documents for a partner service category.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _PartnerCategoryFilters(
                  templates: templates,
                  selected: _partnerCategoryFilter,
                  onSelected: (value) =>
                      setState(() => _partnerCategoryFilter = value),
                ),
                const SizedBox(height: 12),
              ],
              ..._groupedDocuments(templates, isPartner),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _groupedDocuments(
    List<SecurityTemplate> templates,
    bool isPartner,
  ) {
    final filtered = templates.where((template) {
      final selected = _partnerCategoryFilter;
      if (!isPartner ||
          selected == null ||
          template.partnerCategories.isEmpty) {
        return true;
      }
      return template.partnerCategories.contains(selected);
    }).toList();
    final sectionOrder = isPartner
        ? const [
            'account_privacy',
            'service_safety',
            'partner_terms',
            'ip_support',
            'general',
          ]
        : const ['account_privacy', 'service_safety', 'ip_support', 'general'];
    final result = <Widget>[];
    for (final section in sectionOrder) {
      final documents = filtered
          .where((template) => template.section == section)
          .toList();
      if (documents.isEmpty) continue;
      result
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              SecurityTemplateService.sectionLabel(section).toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        )
        ..addAll(
          documents.map(
            (template) => _SecurityDocumentCard(template: template),
          ),
        );
    }
    final unknownSections = filtered
        .map((template) => template.section)
        .where((section) => !sectionOrder.contains(section))
        .toSet();
    for (final section in unknownSections) {
      final documents = filtered
          .where((template) => template.section == section)
          .toList();
      result
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Text(
              SecurityTemplateService.sectionLabel(section).toUpperCase(),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        )
        ..addAll(
          documents.map(
            (template) => _SecurityDocumentCard(template: template),
          ),
        );
    }
    return result;
  }
}

class _PartnerCategoryFilters extends StatelessWidget {
  const _PartnerCategoryFilters({
    required this.templates,
    required this.selected,
    required this.onSelected,
  });

  final List<SecurityTemplate> templates;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final available = SecurityTemplateService.partnerCategoryCodes
        .where(
          (code) => templates.any(
            (template) => template.partnerCategories.contains(code),
          ),
        )
        .toList(growable: false);
    if (available.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          for (final code in available) ...[
            ChoiceChip(
              label: Text(SecurityTemplateService.partnerCategoryLabel(code)),
              selected: selected == code,
              onSelected: (_) => onSelected(code),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SecurityDocumentCard extends StatelessWidget {
  const _SecurityDocumentCard({required this.template});

  final SecurityTemplate template;

  Future<void> _openLink(BuildContext context, String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This link is not available.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.divider),
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFBE7EF),
          child: Icon(Icons.shield_outlined, color: Color(0xFFB20B68)),
        ),
        title: Text(
          template.title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${template.category} · ${template.summary}'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (template.body.trim().isNotEmpty)
            SelectableText(
              template.body,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
            ),
          if (template.links.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var index = 0; index < template.links.length; index++)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _openLink(context, template.links[index]),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    _linkLabel(
                      template.links[index],
                      index,
                      template.links.length,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _linkLabel(String link, int index, int count) {
    final host = Uri.tryParse(link)?.host ?? '';
    if (count <= 1) return host.isEmpty ? 'Open official link' : 'Open $host';
    final source = host.isEmpty ? 'official source' : host;
    return 'Open source ${index + 1} · $source';
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
