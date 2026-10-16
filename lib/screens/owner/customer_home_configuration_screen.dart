import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/customer_home_configuration.dart';

class CustomerHomeConfigurationScreen extends StatefulWidget {
  const CustomerHomeConfigurationScreen({super.key});

  @override
  State<CustomerHomeConfigurationScreen> createState() =>
      _CustomerHomeConfigurationScreenState();
}

class _CustomerHomeConfigurationScreenState
    extends State<CustomerHomeConfigurationScreen> {
  List<CustomerHomeGroup> _groups = CustomerHomeGroup.defaults;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('customer_home')
          .get();
      if (!mounted) return;
      setState(() {
        _groups = CustomerHomeGroup.fromDocument(doc.data());
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load home settings: $error';
        _loading = false;
      });
    }
  }

  void _replaceGroup(CustomerHomeGroup updated) {
    setState(() {
      _groups = _groups.map((group) => group.id == updated.id ? updated : group)
          .toList();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await CustomerHomeConfigurationService.save(_groups);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer home settings saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save settings: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Customer home groups')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Padding(
            padding: const EdgeInsets.all(24), child: Text(_error!)))
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              const Text(
                'Choose which of the five app-owned service groups customers see. '
                'You can change labels, order and items; each item keeps its existing app destination.',
              ),
              const SizedBox(height: 12),
              for (final group in _groups)
                _buildGroupCard(group),
            ],
          ),
    floatingActionButton: _loading || _error != null
        ? null
        : FloatingActionButton.extended(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving' : 'Save changes'),
          ),
  );

  Widget _buildGroupCard(CustomerHomeGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: group.label,
                decoration: const InputDecoration(labelText: 'Group label'),
                onChanged: (value) => _replaceGroup(group.copyWith(label: value)),
              )),
              const SizedBox(width: 12),
              SizedBox(width: 72, child: TextFormField(
                initialValue: '${group.order}',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order'),
                onChanged: (value) {
                  final order = int.tryParse(value);
                  if (order != null) _replaceGroup(group.copyWith(order: order));
                },
              )),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show this group'),
              value: group.enabled,
              onChanged: (value) => _replaceGroup(group.copyWith(enabled: value)),
            ),
            const Text('Items'),
            for (final item in CustomerHomeItemRegistry.items.values)
              Column(children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.label),
                  value: group.itemIds.contains(item.id),
                  onChanged: (selected) {
                    final ids = [...group.itemIds];
                    if (selected == true && !ids.contains(item.id)) ids.add(item.id);
                    if (selected != true) ids.remove(item.id);
                    _replaceGroup(group.copyWith(itemIds: ids));
                  },
                ),
                if (group.itemIds.contains(item.id))
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: TextFormField(
                      initialValue: group.itemLabels[item.id] ?? item.label,
                      decoration: const InputDecoration(labelText: 'Customer-facing item label'),
                      onChanged: (value) => _replaceGroup(group.copyWith(
                        itemLabels: {...group.itemLabels, item.id: value},
                      )),
                    ),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}
