import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/security_template.dart';
import '../../services/security_template_service.dart';

class OwnerSecurityTemplatesScreen extends StatefulWidget {
  const OwnerSecurityTemplatesScreen({super.key});

  @override
  State<OwnerSecurityTemplatesScreen> createState() =>
      _OwnerSecurityTemplatesScreenState();
}

class _OwnerSecurityTemplatesScreenState
    extends State<OwnerSecurityTemplatesScreen> {
  bool _saving = false;
  String _audienceFilter = 'all';

  Future<void> _showOperationError(
    String title,
    Object error,
    String action,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            SecurityTemplateService.adminOperationError(error, action: action),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit({SecurityTemplate? template}) async {
    final result = await showModalBottomSheet<SecurityTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SecurityTemplateEditor(template: template),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await SecurityTemplateService.save(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isPublished ? 'Template published' : 'Draft saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _showOperationError(
        'Could not save template',
        error,
        'save template',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addStarterDrafts() async {
    setState(() => _saving = true);
    try {
      for (final template in SecurityTemplateService.starterDrafts()) {
        await SecurityTemplateService.save(template);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Starter drafts added')));
      }
    } catch (error) {
      if (mounted) {
        await _showOperationError(
          'Could not add starter drafts',
          error,
          'add starter drafts',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importLegalPackDrafts() async {
    setState(() => _saving = true);
    try {
      final result = await SecurityTemplateService.importLegalPackDrafts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${result.added} drafts and filled '
            '${result.filledStarterDrafts} starter drafts; '
            '${result.alreadyPresent} were already imported. '
            'Review each item before publishing.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _showOperationError(
        'Could not import CA legal pack',
        error,
        'import the CA legal pack',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(SecurityTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('“${template.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SecurityTemplateService.delete(template.id);
    } catch (error) {
      if (mounted) {
        await _showOperationError(
          'Could not delete template',
          error,
          'delete template',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Privacy & legal templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add template'),
      ),
      body: StreamBuilder<List<SecurityTemplate>>(
        stream: SecurityTemplateService.watchAdminTemplates(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load templates. Check Admin access and the '
                  '`template_security` Firestore rules.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final templates = snapshot.data!;
          final visibleTemplates = templates
              .where(
                (template) =>
                    _audienceFilter == 'all' ||
                    template.audiences.contains(_audienceFilter),
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1D59A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gavel_outlined, color: Color(0xFF9A6B00)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'CA-approved text is loaded as hidden, editable '
                            'drafts. Open each item to review and edit it; it '
                            'stays private until you publish it. Resolve any '
                            'source placeholders and category-specific '
                            'conditions first. Customer entries are summaries, '
                            'and partner commercial terms remain '
                            'partner-specific.',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _importLegalPackDrafts,
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(
                        _saving
                            ? 'Importing…'
                            : 'Load CA text as editable drafts',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final option in const {
                      'all': 'All',
                      'customer': 'Customer',
                      'partner': 'Partner',
                    }.entries)
                      ChoiceChip(
                        label: Text(option.value),
                        selected: _audienceFilter == option.key,
                        onSelected: _saving
                            ? null
                            : (_) =>
                                  setState(() => _audienceFilter = option.key),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (visibleTemplates.isEmpty) ...[
                const SizedBox(height: 28),
                Icon(
                  Icons.policy_outlined,
                  size: 52,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  _audienceFilter == 'all'
                      ? 'No privacy or legal templates yet'
                      : 'No ${_audienceFilter == 'partner' ? 'partner' : 'customer'} templates yet',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a blank template or start with editable legal-review drafts.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addStarterDrafts,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(_saving ? 'Adding…' : 'Add starter drafts'),
                ),
              ] else ...[
                for (final section in SecurityTemplateService.sections.entries)
                  if (_templatesForSection(
                    visibleTemplates,
                    section.key,
                  ).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(
                        section.value.toUpperCase(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    for (final template in _templatesForSection(
                      visibleTemplates,
                      section.key,
                    ))
                      Card(
                        color: AppColors.surface,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: AppColors.divider),
                        ),
                        child: ListTile(
                          onTap: _saving
                              ? null
                              : () => _edit(template: template),
                          leading: CircleAvatar(
                            backgroundColor: template.isPublished
                                ? const Color(0xFFE6F4EA)
                                : const Color(0xFFFFF1D6),
                            child: Icon(
                              template.isPublished
                                  ? Icons.public_rounded
                                  : Icons.edit_note_rounded,
                              color: template.isPublished
                                  ? const Color(0xFF32834A)
                                  : const Color(0xFF9A6B00),
                            ),
                          ),
                          title: Text(
                            template.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${template.category} · '
                                  '${template.isPublished ? 'Published' : 'Draft'} · '
                                  '${_audienceLabel(template.audiences)}',
                                ),
                                if (template.partnerCategories.isNotEmpty)
                                  Text(
                                    template.partnerCategories
                                        .map(
                                          SecurityTemplateService
                                              .partnerCategoryLabel,
                                        )
                                        .join(' · '),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _edit(template: template);
                              if (value == 'delete') _delete(template);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
              ],
            ],
          );
        },
      ),
    );
  }

  List<SecurityTemplate> _templatesForSection(
    List<SecurityTemplate> templates,
    String section,
  ) => templates
      .where(
        (template) =>
            template.section == section &&
            (_audienceFilter == 'all' ||
                template.audiences.contains(_audienceFilter)),
      )
      .toList(growable: false);

  static String _audienceLabel(List<String> audiences) {
    if (audiences.contains('customer') && audiences.contains('partner')) {
      return 'Customer & Partner';
    }
    if (audiences.contains('partner')) return 'Partner';
    return 'Customer';
  }
}

class _SecurityTemplateEditor extends StatefulWidget {
  const _SecurityTemplateEditor({this.template});

  final SecurityTemplate? template;

  @override
  State<_SecurityTemplateEditor> createState() =>
      _SecurityTemplateEditorState();
}

class _SecurityTemplateEditorState extends State<_SecurityTemplateEditor> {
  static const _categories = [
    'Privacy & Data',
    'Terms & Conditions',
    'Account Security',
    'Intellectual Property',
    'Patents & Intellectual Property',
    'Partner Terms',
    'Partner Safety',
    'Customer Safety',
    'Partner Onboarding',
    'Partner Schedule · Stitching & Alterations',
    'Partner Schedule · Garment Care',
    'Partner Schedule · Measurement',
    'Partner Schedule · Wardrobe & Doorstep',
    'Partner Schedule · Bulk & Wedding',
    'Partner Schedule · Pickup & Delivery',
    'Partner Schedule · Brands & Accessories',
    'Partner Schedule · Dress Rental',
    'Home Visit & Personal Safety',
    'Measurement Safety & Consent',
    'Fabric, Garment Damage & Loss',
    'Payments, Cancellations & Refunds',
    'Pickup, Delivery & Handover',
    'Legal & Support',
    'Other',
  ];

  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _body;
  late final TextEditingController _links;
  late final TextEditingController _order;
  late String _category;
  late String _section;
  late Set<String> _audiences;
  late Set<String> _partnerCategories;
  late bool _published;
  late bool _legalReviewComplete;
  bool _attemptedSave = false;
  SecurityTemplate? _originalTemplate;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _originalTemplate = template;
    _title = TextEditingController(text: template?.title ?? '');
    _summary = TextEditingController(text: template?.summary ?? '');
    _body = TextEditingController(text: template?.body ?? '');
    _links = TextEditingController(text: template?.links.join('\n') ?? '');
    _order = TextEditingController(
      text: (template?.displayOrder ?? 100).toString(),
    );
    _category = _categories.contains(template?.category)
        ? template!.category
        : _categories.first;
    _section = SecurityTemplateService.sections.containsKey(template?.section)
        ? template!.section
        : 'general';
    _audiences = Set<String>.from(
      template?.audiences ?? const ['customer', 'partner'],
    );
    _partnerCategories = Set<String>.from(
      template?.partnerCategories ?? const [],
    );
    _published = template?.isPublished ?? false;
    _legalReviewComplete = template?.legalReviewComplete ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    _links.dispose();
    _order.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _attemptedSave = true);
    final title = _title.text.trim();
    final audiences = _audiences.toList();
    final links = _links.text
        .split('\n')
        .map((link) => link.trim())
        .where((link) => link.isNotEmpty)
        .toList();
    final validLinks =
        links.length <= 20 &&
        links.every((link) => link.length <= 2048 && _isLinkValid(link));
    final displayOrder = int.tryParse(_order.text.trim());
    final hasText = _body.text.trim().isNotEmpty;
    final hasPendingLegalPlaceholder = _body.text.toLowerCase().contains(
      'pending ca/legal review',
    );
    final hasUnresolvedPlaceholder = RegExp(
      r'\[[^\]]*(?:COMPLETE|CONFIRM|NOTICE|SELECT|PROVIDER|TO CONFIRM|VERIFY|CA-?VERIFY|X\s*(?:BUSINESS\s+)?(?:DAYS?|HRS?|HOURS?))[^\]]*\]',
      caseSensitive: false,
    ).hasMatch(_body.text);
    if (title.isEmpty ||
        audiences.isEmpty ||
        !validLinks ||
        displayOrder == null ||
        displayOrder < 0 ||
        displayOrder > 100000) {
      return;
    }
    if (_published && !_legalReviewComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm CA/legal review before publishing.'),
        ),
      );
      return;
    }
    if (_published && hasPendingLegalPlaceholder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Replace all starter draft wording with the CA/legal-approved '
            'content before publishing.',
          ),
        ),
      );
      return;
    }
    if (_published && hasUnresolvedPlaceholder) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Resolve bracketed placeholders in the document before publishing.',
          ),
        ),
      );
      return;
    }
    if (_published && !hasText && links.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add approved text or an official link before publishing.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      SecurityTemplate(
        id: widget.template?.id ?? '',
        title: title,
        category: _category,
        section: _section,
        summary: _summary.text.trim(),
        body: _body.text.trim(),
        links: links,
        audiences: audiences,
        partnerCategories: audiences.contains('partner')
            ? _partnerCategories.toList()
            : const [],
        displayOrder: displayOrder,
        isPublished: _published,
        legalReviewComplete: _legalReviewComplete,
        sourcePackId: widget.template?.sourcePackId,
      ),
    );
  }

  void _invalidateReviewIfContentChanged() {
    final original = _originalTemplate;
    if (original == null || !_legalReviewComplete) return;
    final changed =
        _title.text.trim() != original.title ||
        _category != original.category ||
        _section != original.section ||
        _summary.text.trim() != original.summary ||
        _body.text.trim() != original.body ||
        _links.text
                .split('\n')
                .map((link) => link.trim())
                .where((link) => link.isNotEmpty)
                .join('\n') !=
            original.links.join('\n') ||
        _audiences.length != original.audiences.length ||
        !original.audiences.every(_audiences.contains) ||
        _partnerCategories.length != original.partnerCategories.length ||
        !original.partnerCategories.every(_partnerCategories.contains);
    if (changed) {
      setState(() {
        _legalReviewComplete = false;
        _published = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.template == null
                  ? 'New legal template'
                  : 'Edit legal template',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    onChanged: (_) => _invalidateReviewIfContentChanged(),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      errorText: _attemptedSave && _title.text.trim().isEmpty
                          ? 'Enter a title'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final category in _categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                        _invalidateReviewIfContentChanged();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _section,
                    decoration: const InputDecoration(labelText: 'UI section'),
                    items: [
                      for (final section
                          in SecurityTemplateService.sections.entries)
                        DropdownMenuItem(
                          value: section.key,
                          child: Text(section.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _section = value);
                        _invalidateReviewIfContentChanged();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _summary,
                    onChanged: (_) => _invalidateReviewIfContentChanged(),
                    maxLength: 300,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short description',
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _body,
                    onChanged: (_) => _invalidateReviewIfContentChanged(),
                    minLines: 5,
                    maxLines: 12,
                    maxLength: 15000,
                    decoration: const InputDecoration(
                      labelText: 'Approved content / draft text',
                      alignLabelWithHint: true,
                      helperText:
                          'Replace starter wording with the exact CA/legal-approved content before publishing.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _links,
                    onChanged: (_) => _invalidateReviewIfContentChanged(),
                    keyboardType: TextInputType.url,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Official links (optional)',
                      hintText: 'One HTTPS link per line',
                      helperText:
                          'Use separate links for individual patent records.',
                      errorText: _attemptedSave && !_areLinksValid(_links.text)
                          ? 'Use up to 20 valid HTTPS links'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _order,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Display order',
                      helperText: 'Lower numbers appear first.',
                      errorText:
                          _attemptedSave && (!_isDisplayOrderValid(_order.text))
                          ? 'Enter a whole number from 0 to 100000'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Show to', style: AppTextStyles.titleMedium),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in const {
                        'customer': 'Customers',
                        'partner': 'Partners',
                      }.entries)
                        FilterChip(
                          label: Text(entry.value),
                          selected: _audiences.contains(entry.key),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _audiences.add(entry.key);
                              } else {
                                _audiences.remove(entry.key);
                                if (entry.key == 'partner') {
                                  _partnerCategories.clear();
                                }
                                if (_audiences.isEmpty) _published = false;
                              }
                            });
                            _invalidateReviewIfContentChanged();
                          },
                        ),
                    ],
                  ),
                  if (_attemptedSave && _audiences.isEmpty)
                    const Text(
                      'Choose at least one audience.',
                      style: TextStyle(color: Colors.red),
                    ),
                  if (_audiences.contains('partner')) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Partner service categories',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave all unselected for general partner documents.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final code
                            in SecurityTemplateService.partnerCategoryCodes)
                          FilterChip(
                            label: Text(
                              SecurityTemplateService.partnerCategoryLabel(
                                code,
                              ),
                            ),
                            selected: _partnerCategories.contains(code),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _partnerCategories.add(code);
                                } else {
                                  _partnerCategories.remove(code);
                                }
                              });
                              _invalidateReviewIfContentChanged();
                            },
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              value: _legalReviewComplete,
              onChanged: (value) => setState(() {
                _legalReviewComplete = value ?? false;
                if (!_legalReviewComplete) _published = false;
              }),
              title: const Text('CA/legal review is complete'),
              subtitle: const Text(
                'Required before publishing this wording and links.',
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SwitchListTile.adaptive(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              value: _published,
              onChanged: _legalReviewComplete
                  ? (value) => setState(() => _published = value)
                  : null,
              title: const Text('Publish to selected users'),
              subtitle: Text(
                _legalReviewComplete
                    ? 'Turn on to publish; turn off to keep as a draft.'
                    : 'Mark legal review complete to enable publishing.',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(
                      _published ? Icons.public_rounded : Icons.save_outlined,
                    ),
                    label: Text(_published ? 'Publish' : 'Save draft'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isLinkValid(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  bool _areLinksValid(String value) {
    final links = value
        .split('\n')
        .map((link) => link.trim())
        .where((link) => link.isNotEmpty)
        .toList();
    return links.length <= 20 &&
        links.every((link) => link.length <= 2048 && _isLinkValid(link));
  }

  bool _isDisplayOrderValid(String value) {
    final number = int.tryParse(value.trim());
    return number != null && number >= 0 && number <= 100000;
  }
}
