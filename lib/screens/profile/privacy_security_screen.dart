import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/security_template.dart';
import '../../services/security_template_service.dart';

class PrivacySecurityScreen extends StatelessWidget {
  const PrivacySecurityScreen({super.key, required this.audience});

  final String audience;

  @override
  Widget build(BuildContext context) {
    final isPartner = audience == 'partner';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: StreamBuilder<List<SecurityTemplate>>(
        stream: SecurityTemplateService.watchPublishedTemplates(audience),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint(
              'Privacy & Security failed to load for $audience: '
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
              for (final template in templates)
                _SecurityDocumentCard(template: template),
            ],
          );
        },
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
