import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../models/garment_care_completion_template.dart';
import '../../models/garment_care_domain.dart';
import '../../services/garment_care_service.dart';

/// Shared template editor. Admins publish the shop-wide library; Partners keep
/// their own reusable copies scoped to their Garment Care profile.
class GarmentCareCompletionTemplatesScreen extends StatefulWidget {
  const GarmentCareCompletionTemplatesScreen({
    super.key,
    required this.isAdmin,
    this.accountId = '',
    this.profileId = '',
  });

  final bool isAdmin;
  final String accountId;
  final String profileId;

  @override
  State<GarmentCareCompletionTemplatesScreen> createState() =>
      _GarmentCareCompletionTemplatesScreenState();
}

class _GarmentCareCompletionTemplatesScreenState
    extends State<GarmentCareCompletionTemplatesScreen> {
  List<GarmentCareCompletionTemplate> _templates = [];
  List<GarmentCareCompletionTemplate> _sharedTemplates = [];
  List<GarmentCareCompletionTemplate> _starterTemplates =
      garmentCareStarterCompletionTemplates;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _version = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GarmentCareService.completionTemplates(
        isAdmin: widget.isAdmin,
        accountId: widget.accountId,
        profileId: widget.profileId,
      );
      final raw = (widget.isAdmin
              ? result['templates']
              : result['partnerTemplates']) as List<dynamic>? ??
          const [];
      final starters = result['starterTemplates'] as List<dynamic>? ?? const [];
      final shared = result['templates'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _templates = raw
            .whereType<Map>()
            .map(
              (item) => GarmentCareCompletionTemplate.fromMap(
                Map<String, dynamic>.from(item),
                versionId: result['versionId']?.toString() ?? '',
              ),
            )
            .toList();
        _sharedTemplates = shared
            .whereType<Map>()
            .map(
              (item) => GarmentCareCompletionTemplate.fromMap(
                Map<String, dynamic>.from(item),
                versionId: result['versionId']?.toString() ?? '',
              ),
            )
            .toList();
        _starterTemplates = starters.isEmpty
            ? garmentCareStarterCompletionTemplates
            : starters
                  .whereType<Map>()
                  .map(
                    (item) => GarmentCareCompletionTemplate.fromMap(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList();
        _version = (result['version'] as num?)?.toInt() ?? 1;
      });
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message ?? 'Could not load completion templates.';
          _templates = widget.isAdmin
              ? garmentCareStarterCompletionTemplates
              : const [];
          _sharedTemplates = garmentCareStarterCompletionTemplates;
          _starterTemplates = garmentCareStarterCompletionTemplates;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load completion templates.';
          _templates = widget.isAdmin
              ? garmentCareStarterCompletionTemplates
              : const [];
          _sharedTemplates = garmentCareStarterCompletionTemplates;
          _starterTemplates = garmentCareStarterCompletionTemplates;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([
    GarmentCareCompletionTemplate? existing,
    bool asCopy = false,
  ]) async {
    final edited = await showDialog<GarmentCareCompletionTemplate>(
      context: context,
      builder: (_) => _CompletionTemplateEditorDialog(
        initial: existing,
        availableServiceIds: _allServiceIds,
      ),
    );
    if (edited == null || !mounted) return;
    final template = GarmentCareCompletionTemplate(
      id: asCopy || edited.id.isEmpty
          ? 'completion_${DateTime.now().microsecondsSinceEpoch}'
          : edited.id,
      name: edited.name,
      serviceIds: edited.serviceIds,
      materialKeywords: edited.materialKeywords,
      methodUsed: edited.methodUsed,
      processDetails: edited.processDetails,
      finishingDetails: edited.finishingDetails,
      qualityNotes: edited.qualityNotes,
    );
    await _persist(template);
  }

  Future<void> _persist(GarmentCareCompletionTemplate template) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.isAdmin) {
        final updated = [..._templates];
        final index = updated.indexWhere((item) => item.id == template.id);
        if (index < 0) {
          updated.add(template);
        } else {
          updated[index] = template;
        }
        final result = await GarmentCareService.publishCompletionTemplates(
          templates: updated.map((item) => item.toMap()).toList(),
        );
        if (!mounted) return;
        setState(() {
          _templates = updated;
          _version = (result['version'] as num?)?.toInt() ?? _version + 1;
        });
        _message('Published template library version $_version.');
      } else {
        await GarmentCareService.savePartnerCompletionTemplate(
          accountId: widget.accountId,
          profileId: widget.profileId,
          template: template.toMap(),
        );
        await _load();
        if (mounted) _message('Partner template saved.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'Could not save template.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save template.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(GarmentCareCompletionTemplate template) async {
    if (widget.isAdmin) {
      final updated = _templates.where((item) => item.id != template.id).toList();
      setState(() => _saving = true);
      try {
        final result = await GarmentCareService.publishCompletionTemplates(
          templates: updated.map((item) => item.toMap()).toList(),
        );
        if (!mounted) return;
        setState(() {
          _templates = updated;
          _version = (result['version'] as num?)?.toInt() ?? _version + 1;
        });
        _message('Template removed from the published library.');
      } on FirebaseFunctionsException catch (error) {
        if (mounted) setState(() => _error = error.message ?? 'Could not remove template.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await GarmentCareService.deletePartnerCompletionTemplate(
        accountId: widget.accountId,
        profileId: widget.profileId,
        templateId: template.id,
      );
      await _load();
      if (mounted) _message('Partner template deleted.');
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'Could not delete template.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get _allServiceIds => GarmentCareServiceCatalog.serviceIdsByGroup
      .values
      .expand((items) => items)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Completion templates' : 'My care templates'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _createOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create template'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Text(
                  widget.isAdmin ? 'Shared Partner library' : 'Reusable care notes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isAdmin
                      ? 'Create and publish standard process notes. Partners can select these and edit the record for the garment they actually handled.'
                      : 'Copy a starter or create your own. Templates fill the completion form; you can still edit every field before saving the order.',
                ),
                if (widget.isAdmin) ...[
                  const SizedBox(height: 8),
                  Text('Published library version $_version'),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (widget.isAdmin) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Published templates'),
                  if (_templates.isEmpty) const _EmptyTemplatesNote(),
                  for (final template in _templates)
                    _TemplateCard(
                      template: template,
                      busy: _saving,
                      canEdit: true,
                      onEdit: () => _createOrEdit(template),
                      onDelete: () => _delete(template),
                    ),
                ] else ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Your templates'),
                  if (_templates.isEmpty) const _EmptyTemplatesNote(),
                  for (final template in _templates)
                    _TemplateCard(
                      template: template,
                      busy: _saving,
                      canEdit: true,
                      onEdit: () => _createOrEdit(template),
                      onDelete: () => _delete(template),
                    ),
                  const SizedBox(height: 16),
                  _sectionTitle(
                    _sharedTemplates.isEmpty
                        ? 'Starter templates'
                        : 'Shared Admin templates',
                  ),
                  for (final template in _sharedTemplates.isEmpty
                      ? _starterTemplates
                      : _sharedTemplates)
                    _TemplateCard(
                      template: template,
                      busy: _saving,
                      canEdit: false,
                      copyLabel: 'Copy and edit',
                      onCopy: () => _createOrEdit(template, true),
                    ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Always follow the garment care label, the inspection and the service the Customer approved. Use a template only when it matches the process actually performed.',
                ),
              ],
            ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.busy,
    required this.canEdit,
    this.copyLabel,
    this.onEdit,
    this.onDelete,
    this.onCopy,
  });

  final GarmentCareCompletionTemplate template;
  final bool busy;
  final bool canEdit;
  final String? copyLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(template.methodUsed),
          if (template.serviceIds.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Services: ${template.serviceIds.map(GarmentCareServiceCatalog.labelFor).join(', ')}'),
          ],
          if (template.materialKeywords.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Materials: ${template.materialKeywords.join(', ')}'),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                if (onCopy != null)
                  TextButton(onPressed: busy ? null : onCopy, child: Text(copyLabel ?? 'Copy')),
                if (canEdit && onEdit != null)
                  TextButton(onPressed: busy ? null : onEdit, child: const Text('Edit')),
                if (canEdit && onDelete != null)
                  IconButton(
                    tooltip: 'Delete template',
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyTemplatesNote extends StatelessWidget {
  const _EmptyTemplatesNote();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Text('No templates yet. Create one or copy a starter template.'),
  );
}

class _CompletionTemplateEditorDialog extends StatefulWidget {
  const _CompletionTemplateEditorDialog({
    required this.availableServiceIds,
    this.initial,
  });

  final List<String> availableServiceIds;
  final GarmentCareCompletionTemplate? initial;

  @override
  State<_CompletionTemplateEditorDialog> createState() =>
      _CompletionTemplateEditorDialogState();
}

class _CompletionTemplateEditorDialogState
    extends State<_CompletionTemplateEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _materials;
  late final TextEditingController _method;
  late final TextEditingController _process;
  late final TextEditingController _finishing;
  late final TextEditingController _quality;
  late final Set<String> _selectedServices;

  @override
  void initState() {
    super.initState();
    final template = widget.initial;
    _name = TextEditingController(text: template?.name ?? '');
    _materials = TextEditingController(text: template?.materialKeywords.join(', ') ?? '');
    _method = TextEditingController(text: template?.methodUsed ?? '');
    _process = TextEditingController(text: template?.processDetails ?? '');
    _finishing = TextEditingController(text: template?.finishingDetails ?? '');
    _quality = TextEditingController(text: template?.qualityNotes ?? '');
    _selectedServices = {...?template?.serviceIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _materials.dispose();
    _method.dispose();
    _process.dispose();
    _finishing.dispose();
    _quality.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      GarmentCareCompletionTemplate(
        id: widget.initial?.id ?? '',
        name: _name.text.trim(),
        serviceIds: _selectedServices.toList(growable: false),
        materialKeywords: _materials.text
            .split(',')
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList(growable: false),
        methodUsed: _method.text.trim(),
        processDetails: _process.text.trim(),
        finishingDetails: _finishing.text.trim(),
        qualityNotes: _quality.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Create care template' : 'Edit care template'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leave services unselected to make this template available for every service.'),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Template name *'),
            ),
            TextField(
              controller: _materials,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: 'Material keywords (optional)',
                hintText: 'e.g. cotton, silk, wool, blended',
                helperText: 'Comma separated; leave blank for all materials.',
              ),
            ),
            const SizedBox(height: 4),
            const Text('Services (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 4,
              children: [
                for (final serviceId in widget.availableServiceIds)
                  FilterChip(
                    label: Text(GarmentCareServiceCatalog.labelFor(serviceId)),
                    selected: _selectedServices.contains(serviceId),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedServices.add(serviceId);
                      } else {
                        _selectedServices.remove(serviceId);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _method,
              maxLength: 240,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Care method used *'),
            ),
            TextField(controller: _process, maxLines: 3, maxLength: 800, decoration: const InputDecoration(labelText: 'Process details')),
            TextField(controller: _finishing, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Finishing details')),
            TextField(controller: _quality, maxLines: 3, maxLength: 500, decoration: const InputDecoration(labelText: 'Quality check notes')),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(
        onPressed: _name.text.trim().isNotEmpty && _method.text.trim().isNotEmpty ? _submit : null,
        child: const Text('Save template'),
      ),
    ],
  );
}
