import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/constants/garment_care_colors.dart';
import '../../models/garment_care_domain.dart';
import '../../services/garment_care_service.dart';

class GarmentCareInspectionTemplatesScreen extends StatefulWidget {
  const GarmentCareInspectionTemplatesScreen({super.key});

  @override
  State<GarmentCareInspectionTemplatesScreen> createState() =>
      _GarmentCareInspectionTemplatesScreenState();
}

class _GarmentCareInspectionTemplatesScreenState
    extends State<GarmentCareInspectionTemplatesScreen> {
  final _allGood = TextEditingController();
  final _issueFound = TextEditingController();
  final Map<String, Map<String, String>> _templates = {};
  late final List<String> _serviceIds = GarmentCareServiceGroup.values
      .take(4)
      .expand(
        (group) => GarmentCareServiceCatalog.serviceIdsByGroup[group.code] ??
            const <String>[],
      )
      .toList(growable: false);
  String? _selectedServiceId;
  String _versionId = 'default_v1';
  int _version = 1;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _allGood.dispose();
    _issueFound.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GarmentCareService.inspectionTemplates();
      final raw = Map<String, dynamic>.from(result['templates'] as Map? ?? const {});
      _templates.clear();
      for (final serviceId in _serviceIds) {
        final pair = Map<String, dynamic>.from(raw[serviceId] as Map? ?? const {});
        _templates[serviceId] = {
          'allGood': pair['allGood']?.toString() ?? '',
          'issueFound': pair['issueFound']?.toString() ?? '',
        };
      }
      _versionId = result['versionId']?.toString() ?? 'default_v1';
      _version = (result['version'] as num?)?.toInt() ?? 1;
      _selectedServiceId ??= _serviceIds.first;
      _loadSelectedText();
    } on FirebaseFunctionsException catch (error) {
      _error = error.message ?? 'Could not load inspection messages.';
    } catch (_) {
      _error = 'Could not load inspection messages.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _saveSelectedText() {
    final serviceId = _selectedServiceId;
    if (serviceId == null) return;
    _templates[serviceId] = {
      'allGood': _allGood.text.trim(),
      'issueFound': _issueFound.text.trim(),
    };
  }

  void _loadSelectedText() {
    final pair = _templates[_selectedServiceId] ?? const <String, String>{};
    _allGood.text = pair['allGood'] ?? '';
    _issueFound.text = pair['issueFound'] ?? '';
  }

  Future<void> _publish() async {
    _saveSelectedText();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await GarmentCareService.publishInspectionTemplates(
        templates: _templates.map(
          (serviceId, messages) => MapEntry(serviceId, messages),
        ),
      );
      if (!mounted) return;
      setState(() {
        _version = (result['version'] as num?)?.toInt() ?? _version + 1;
        _versionId = result['versionId']?.toString() ?? _versionId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inspection message version $_version is active.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (mounted) setState(() => _error = error.message ?? 'Could not publish messages.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not publish messages.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => GarmentCareTheme(
    child: Scaffold(
      backgroundColor: GarmentCareColors.background,
      appBar: AppBar(title: const Text('Inspection messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Approved customer messages',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text('Partners select All Good or Issue Found. SuiSakhi fills in the service, finding and price impact automatically.'),
                const SizedBox(height: 8),
                Text('Active version $_version · ${_versionId == 'default_v1' ? 'built-in defaults' : 'published by Admin'}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedServiceId,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: [
                    for (final serviceId in _serviceIds)
                      DropdownMenuItem(
                        value: serviceId,
                        child: Text(GarmentCareServiceCatalog.labelFor(serviceId)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          _saveSelectedText();
                          setState(() {
                            _selectedServiceId = value;
                            _loadSelectedText();
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _allGood,
                  maxLines: 4,
                  maxLength: 700,
                  onChanged: (_) => _saveSelectedText(),
                  decoration: const InputDecoration(
                    labelText: 'All Good message',
                    hintText: 'Use {service} and {note} where values should be inserted.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _issueFound,
                  maxLines: 5,
                  maxLength: 1000,
                  onChanged: (_) => _saveSelectedText(),
                  decoration: const InputDecoration(
                    labelText: 'Issue Found message',
                    hintText: 'Use {service}, {condition}, {observations}, {action}, {priceImpact} and {note}.',
                  ),
                ),
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Supported placeholders', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('{service} · {condition} · {observations} · {action} · {priceImpact} · {note}'),
                        const SizedBox(height: 8),
                        Text(_allGood.text.replaceAll('{service}', GarmentCareServiceCatalog.labelFor(_selectedServiceId ?? '')).replaceAll('{note}', '').trim()),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _publish,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.publish_rounded),
                  label: Text(_saving ? 'Publishing…' : 'Publish new version'),
                ),
              ],
            ),
    ),
  );
}
