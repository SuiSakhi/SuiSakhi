import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/catalogue_upload_policy.dart';

class CatalogueUploadViewValue {
  const CatalogueUploadViewValue({
    required this.localId,
    required this.file,
    required this.viewType,
    required this.displayOrder,
    required this.isPrimary,
    this.title,
  });

  final String localId;
  final XFile file;
  final CatalogueDesignViewType viewType;
  final int displayOrder;
  final bool isPrimary;
  final String? title;
}

class CatalogueViewUploadSection extends StatefulWidget {
  const CatalogueViewUploadSection({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<List<CatalogueUploadViewValue>> onChanged;

  @override
  State<CatalogueViewUploadSection> createState() =>
      _CatalogueViewUploadSectionState();
}

class _DraftView {
  _DraftView({required this.localId, required this.displayOrder});

  final String localId;
  final int displayOrder;
  XFile? file;
  CatalogueDesignViewType viewType = CatalogueDesignViewType.singleView;
  bool isPrimary = false;
  String? error;
}

class _CatalogueViewUploadSectionState
    extends State<CatalogueViewUploadSection> {
  final List<_DraftView> _views = [];

  @override
  void initState() {
    super.initState();
    _addView(initial: true);
  }

  void _addView({bool initial = false}) {
    if (_views.length >= 10) return;
    final item = _DraftView(
      localId: DateTime.now().microsecondsSinceEpoch.toString(),
      displayOrder: _views.length + 1,
    );
    if (_views.isEmpty) item.isPrimary = true;
    if (initial) {
      _views.add(item);
    } else {
      setState(() => _views.add(item));
    }
    _notify();
  }

  Future<void> _pick(_DraftView view) async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 92,
    );
    if (selected == null || !mounted) return;
    final validation = await CatalogueUploadPolicy.validate(selected);
    if (!mounted) return;
    setState(() {
      if (validation.accepted) {
        view.file = selected;
        view.error = null;
      } else {
        view.file = null;
        view.error = validation.errorMessage;
      }
    });
    _notify();
  }

  void _setPrimary(_DraftView selected) {
    if (!selected.viewType.canBePrimary) return;
    setState(() {
      for (final view in _views) {
        view.isPrimary = identical(view, selected);
      }
    });
    _notify();
  }

  void _remove(_DraftView view) {
    if (_views.length == 1) return;
    final wasPrimary = view.isPrimary;
    setState(() {
      _views.remove(view);
      if (wasPrimary) {
        final candidate = _views.where((item) => item.viewType.canBePrimary);
        if (candidate.isNotEmpty) candidate.first.isPrimary = true;
      }
    });
    _notify();
  }

  void _notify() {
    final values = <CatalogueUploadViewValue>[];
    for (var index = 0; index < _views.length; index++) {
      final view = _views[index];
      if (view.file == null) continue;
      values.add(
        CatalogueUploadViewValue(
          localId: view.localId,
          file: view.file!,
          viewType: view.viewType,
          displayOrder: index + 1,
          isPrimary: view.isPrimary,
        ),
      );
    }
    widget.onChanged(values);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<CatalogueUploadViewValue>>(
      initialValue: const [],
      validator: (_) {
        final completed = _views.where((item) => item.file != null).toList();
        if (completed.isEmpty) return 'Add at least one design image';
        final primary = completed.where((item) => item.isPrimary).toList();
        if (primary.length != 1) return 'Select exactly one Primary View';
        if (!primary.single.viewType.canBePrimary) {
          return 'Primary View must be Front, Combined Front + Back, or Single View';
        }
        return null;
      },
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < _views.length; index++) ...[
            _viewCard(_views[index], index),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: widget.enabled && _views.length < 10
                ? () => _addView()
                : null,
            icon: const Icon(Icons.add_rounded),
            label: Text('Add Another View (${_views.length}/10)'),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 8),
            Text(field.errorText!, style: TextStyle(color: AppColors.error)),
          ],
        ],
      ),
    );
  }

  Widget _viewCard(_DraftView view, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Design View ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_views.length > 1)
                IconButton(
                  tooltip: 'Remove View',
                  onPressed: widget.enabled ? () => _remove(view) : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: widget.enabled ? () => _pick(view) : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(view.file == null ? 'Select Image' : view.file!.name),
          ),
          if (view.error != null) ...[
            const SizedBox(height: 6),
            Text(view.error!, style: TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<CatalogueDesignViewType>(
            initialValue: view.viewType,
            decoration: const InputDecoration(
              labelText: 'View Type',
              border: OutlineInputBorder(),
            ),
            items: CatalogueDesignViewType.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: widget.enabled
                ? (value) {
                    setState(() {
                      view.viewType =
                          value ?? CatalogueDesignViewType.singleView;
                      if (view.isPrimary && !view.viewType.canBePrimary) {
                        view.isPrimary = false;
                      }
                    });
                    _notify();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: view.isPrimary,
            onChanged:
                widget.enabled &&
                    view.viewType.canBePrimary
                ? (selected) {
                    if (selected == true) {
                      _setPrimary(view);
                    }
                  }
                : null,
            title: const Text('Primary View'),
            subtitle: Text(
              view.viewType.canBePrimary
                  ? 'Used as the default Catalogue preview'
                  : 'Back, Side and Detail are supporting views',
            ),
          ),
        ],
      ),
    );
  }
}
