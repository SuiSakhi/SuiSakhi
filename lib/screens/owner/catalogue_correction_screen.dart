import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/catalogue_correction_service.dart';
import '../../services/owner_catalogue_service.dart';

class CatalogueCorrectionScreen extends StatefulWidget {
  const CatalogueCorrectionScreen({super.key, required this.designId});
  final String designId;

  @override
  State<CatalogueCorrectionScreen> createState() =>
      _CatalogueCorrectionScreenState();
}

class _CatalogueCorrectionScreenState extends State<CatalogueCorrectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  CatalogueDesign? _design;
  CatalogueCorrectionDraft? _draft;
  List<CatalogueDesignView> _views = const [];
  CatalogueCommercialType _commercialType = CatalogueCommercialType.free;
  String? _garmentCode;
  String? _occasionCode;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _garments = <String, String>{
    'kurti': 'Kurti',
    'kurtaSet': 'Kurta Set',
    'salwarSuit': 'Salwar Suit',
    'anarkali': 'Anarkali',
    'lehengaCholi': 'Lehenga Choli',
    'gown': 'Gown',
    'blouse': 'Blouse',
    'sareeBlouse': 'Saree Blouse',
    'topTunic': 'Top / Tunic',
    'shirt': 'Shirt',
    'palazzoPant': 'Palazzo / Pant',
    'skirt': 'Skirt',
    'dress': 'Dress / One Piece',
    'other': 'Other',
  };
  static const _occasions = <String, String>{
    'dailyWear': 'Daily Wear',
    'officeWear': 'Office Wear',
    'casualOuting': 'Casual Outing',
    'partyWear': 'Party Wear',
    'festiveWear': 'Festive Wear',
    'traditionalWear': 'Traditional Wear',
    'weddingGuest': 'Wedding Guest',
    'bridalHeavyOccasion': 'Bridal / Heavy Occasion',
    'maternityWear': 'Maternity Wear',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final design = await OwnerCatalogueService.getDesign(widget.designId);
      if (design.lifecycleStatus !=
          CatalogueDesignLifecycleStatus.changesRequested) {
        throw StateError('Only a Changes Requested design can be corrected.');
      }
      final bundle = await OwnerCatalogueService.getActiveVersionBundle(design);
      if (bundle == null) {
        throw StateError('Active Catalogue version not found.');
      }
      final draft = await CatalogueCorrectionService.ensureCorrectionDraft(
        design: design,
        sourceVersion: bundle.version,
        sourceViews: bundle.views,
      );
      if (!mounted) return;
      _title.text = design.title;
      _description.text = design.description ?? '';
      _commercialType = design.commercial.commercialType;
      _price.text = design.commercial.approvedDesignCharge?.toString() ?? '';
      _garmentCode = design.garmentTypeCodes.isEmpty
          ? null
          : design.garmentTypeCodes.first;
      _occasionCode = design.occasionCodes.isEmpty
          ? null
          : design.occasionCodes.first;
      setState(() {
        _design = design;
        _draft = draft;
        _views = draft.inheritedViews;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  CatalogueDesignView _copy(
    CatalogueDesignView view, {
    CatalogueDesignViewType? type,
    bool? primary,
  }) => CatalogueDesignView(
    viewId: view.viewId,
    designId: view.designId,
    versionId: view.versionId,
    viewType: type ?? view.viewType,
    displayOrder: view.displayOrder,
    isPrimary: primary ?? view.isPrimary,
    title: view.title,
    originalAsset: view.originalAsset,
    normalizedPreviewAsset: view.normalizedPreviewAsset,
    structuredSvgAsset: view.structuredSvgAsset,
    thumbnailAsset: view.thumbnailAsset,
    processing: view.processing,
    createdAt: view.createdAt,
    updatedAt: view.updatedAt,
  );

  Future<void> _replace(CatalogueDesignView view) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 92,
    );
    if (file == null || _draft == null) return;
    await _perform(() async {
      final replacement = await CatalogueCorrectionService.replaceView(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        existingView: view,
        file: file,
      );
      setState(
        () => _views = [
          for (final item in _views)
            if (item.viewId == view.viewId) replacement else item,
        ],
      );
    });
  }

  Future<void> _addView() async {
    if (_views.length >= 10 || _draft == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 92,
    );
    if (file == null || !mounted) return;
    CatalogueDesignViewType selected = CatalogueDesignViewType.detail;
    final type = await showDialog<CatalogueDesignViewType>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select View Type'),
        content: StatefulBuilder(
          builder: (context, setLocal) =>
              DropdownButtonFormField<CatalogueDesignViewType>(
                initialValue: selected,
                items: CatalogueDesignViewType.values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setLocal(
                  () => selected = value ?? CatalogueDesignViewType.detail,
                ),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (type == null) return;
    await _perform(() async {
      final added = await CatalogueCorrectionService.addView(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        file: file,
        viewType: type,
        displayOrder: _views.length + 1,
        isPrimary: false,
      );
      setState(() => _views = [..._views, added]);
    });
  }

  Future<void> _remove(CatalogueDesignView view) async {
    if (_views.length <= 1) {
      _message('At least one Design View is required.', error: true);
      return;
    }
    await _perform(() async {
      await CatalogueCorrectionService.excludeView(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        viewId: view.viewId,
      );
      setState(
        () => _views = _views
            .where((item) => item.viewId != view.viewId)
            .toList(),
      );
    });
  }

  Future<void> _changeType(
    CatalogueDesignView view,
    CatalogueDesignViewType type,
  ) async {
    await _perform(() async {
      await CatalogueCorrectionService.updateViewType(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        viewId: view.viewId,
        viewType: type,
      );
      setState(
        () => _views = [
          for (final item in _views)
            if (item.viewId == view.viewId)
              _copy(
                item,
                type: type,
                primary: type.canBePrimary ? item.isPrimary : false,
              )
            else
              item,
        ],
      );
    });
  }

  Future<void> _setPrimary(CatalogueDesignView view) async {
    if (!view.viewType.canBePrimary || _draft == null) return;
    await _perform(() async {
      await CatalogueCorrectionService.setPrimaryView(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        views: _views,
        primaryViewId: view.viewId,
      );
      setState(
        () => _views = [
          for (final item in _views)
            _copy(item, primary: item.viewId == view.viewId),
        ],
      );
    });
  }

  Future<void> _resubmit() async {
    if (_saving || !_formKey.currentState!.validate() || _draft == null) return;
    await _perform(() async {
      await CatalogueCorrectionService.resubmitCorrection(
        designId: widget.designId,
        draftVersionId: _draft!.draftVersion.versionId,
        title: _title.text,
        description: _description.text,
        garmentTypeCode: _garmentCode!,
        occasionCode: _occasionCode,
        commercialType: _commercialType,
        approvedDesignCharge: double.tryParse(_price.text.trim()),
        views: _views,
      );
      if (mounted) context.go('/owner/catalogue');
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) setState(() => _saving = false);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(error.toString(), error: true);
      }
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.error : AppColors.success,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _design == null || _draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit and Resubmit')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'Correction Draft unavailable.'),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit and Resubmit')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(),
            const SizedBox(height: 14),
            _viewsCard(),
            const SizedBox(height: 14),
            _metadataCard(),
            const SizedBox(height: 14),
            _commercialCard(),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _resubmit,
              icon: const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Saving...' : 'Resubmit for Review'),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _banner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Changes Requested',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 6),
        Text(_design!.reviewNotes ?? 'Review and resubmit.'),
        const SizedBox(height: 6),
        Text('Correction Version ${_draft!.draftVersion.versionNumber}'),
      ],
    ),
  );

  Widget _viewsCard() => _card('Design Views', [
    for (final view in _views)
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            if (view.bestPreviewUrl != null)
              SizedBox(
                height: 180,
                child: Image.network(
                  view.bestPreviewUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            const SizedBox(height: 8),
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
                  .toList(),
              onChanged: _saving
                  ? null
                  : (type) {
                      if (type != null) _changeType(view, type);
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: view.isPrimary,
              onChanged: _saving || !view.viewType.canBePrimary
                  ? null
                  : (value) {
                      if (value == true) _setPrimary(view);
                    },
              title: const Text('Primary View'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _replace(view),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _remove(view),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    OutlinedButton.icon(
      onPressed: _saving || _views.length >= 10 ? null : _addView,
      icon: const Icon(Icons.add),
      label: Text('Add Another View (${_views.length}/10)'),
    ),
  ]);

  Widget _metadataCard() => _card('Catalogue Metadata', [
    TextFormField(
      controller: _title,
      decoration: const InputDecoration(
        labelText: 'Design title',
        border: OutlineInputBorder(),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Enter a title' : null,
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _description,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _garmentCode,
      decoration: const InputDecoration(
        labelText: 'Garment type',
        border: OutlineInputBorder(),
      ),
      items: _garments.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (value) => setState(() => _garmentCode = value),
      validator: (value) => value == null ? 'Select a garment type' : null,
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      initialValue: _occasionCode,
      decoration: const InputDecoration(
        labelText: 'Occasion',
        border: OutlineInputBorder(),
      ),
      items: _occasions.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (value) => setState(() => _occasionCode = value),
    ),
  ]);

  Widget _commercialCard() => _card('Commercial', [
    DropdownButtonFormField<CatalogueCommercialType>(
      initialValue: _commercialType,
      decoration: const InputDecoration(
        labelText: 'Commercial type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: CatalogueCommercialType.free,
          child: Text('Free'),
        ),
        DropdownMenuItem(
          value: CatalogueCommercialType.paid,
          child: Text('Paid'),
        ),
        DropdownMenuItem(
          value: CatalogueCommercialType.premium,
          child: Text('Premium'),
        ),
      ],
      onChanged: (value) => setState(
        () => _commercialType = value ?? CatalogueCommercialType.free,
      ),
    ),
    if (_commercialType != CatalogueCommercialType.free) ...[
      const SizedBox(height: 12),
      TextFormField(
        controller: _price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Approved design charge',
          prefixText: '₹ ',
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          final amount = double.tryParse(value?.trim() ?? '');
          return amount == null || amount < 0 ? 'Enter a valid charge' : null;
        },
      ),
    ],
  ]);

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}
