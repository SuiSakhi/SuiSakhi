import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import 'catalogue_view_upload_section.dart';

class CatalogueUploadFormValue {
  const CatalogueUploadFormValue({
    required this.views,
    required this.title,
    required this.description,
    required this.garmentTypeCodes,
    required this.occasionCodes,
    required this.commercialType,
    this.expectedPrice,
    this.approvedDesignCharge,
  });

  final List<CatalogueUploadViewValue> views;
  final String title;
  final String? description;
  final List<String> garmentTypeCodes;
  final List<String> occasionCodes;
  final CatalogueCommercialType commercialType;
  final double? expectedPrice;
  final double? approvedDesignCharge;
}

class CatalogueUploadForm extends StatefulWidget {
  const CatalogueUploadForm({
    super.key,
    required this.formKey,
    required this.enabled,
    required this.designerMode,
    required this.onChanged,
    this.showApprovedDesignCharge = false,
  });

  final GlobalKey<FormState> formKey;
  final bool enabled;
  final bool designerMode;
  final bool showApprovedDesignCharge;
  final ValueChanged<CatalogueUploadFormValue?> onChanged;

  @override
  State<CatalogueUploadForm> createState() => _CatalogueUploadFormState();
}

class _CatalogueUploadFormState extends State<CatalogueUploadForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _expectedPriceController = TextEditingController();
  final _approvedChargeController = TextEditingController();

  CatalogueCommercialType _commercialType = CatalogueCommercialType.free;
  List<CatalogueUploadViewValue> _views = const <CatalogueUploadViewValue>[];
  final Set<String> _selectedGarmentTypeCodes = <String>{};
  final Set<String> _selectedOccasionCodes = <String>{};

  static const Map<String, String> _garmentTypeOptions = {
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

  static const Map<String, String> _occasionOptions = {
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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _expectedPriceController.dispose();
    _approvedChargeController.dispose();
    super.dispose();
  }

  double? _money(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _notify() {
    widget.onChanged(
      CatalogueUploadFormValue(
        views: List<CatalogueUploadViewValue>.unmodifiable(_views),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        garmentTypeCodes: _selectedGarmentTypeCodes.toList(growable: false),
        occasionCodes: _selectedOccasionCodes.toList(growable: false),
        commercialType: _commercialType,
        expectedPrice: _money(_expectedPriceController),
        approvedDesignCharge: _money(_approvedChargeController),
      ),
    );
  }

  bool get _priceRequired =>
      _commercialType == CatalogueCommercialType.paid ||
      _commercialType == CatalogueCommercialType.premium;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      onChanged: _notify,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            title: 'Design Views',
            description:
                'Add 1 to 10 images. Select exactly one Primary View. '
                'Front, Combined Front + Back, and Single View can be Primary.',
            children: [
              CatalogueViewUploadSection(
                enabled: widget.enabled,
                onChanged: (views) {
                  _views = views;
                  _notify();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Catalogue Metadata',
            description:
                'Select governed garment and occasion metadata for catalogue filtering.',
            children: [
              TextFormField(
                controller: _titleController,
                enabled: widget.enabled,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Design title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a design title'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                enabled: widget.enabled,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Garment type',
                  border: OutlineInputBorder(),
                ),
                items: _garmentTypeOptions.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _selectedGarmentTypeCodes
                            ..clear()
                            ..addAll(
                              value == null
                                  ? const <String>[]
                                  : <String>[value],
                            );
                        });
                        _notify();
                      }
                    : null,
                validator: (_) => _selectedGarmentTypeCodes.isEmpty
                    ? 'Select a garment type'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Primary occasion',
                  border: OutlineInputBorder(),
                ),
                items: _occasionOptions.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _selectedOccasionCodes
                            ..clear()
                            ..addAll(
                              value == null
                                  ? const <String>[]
                                  : <String>[value],
                            );
                        });
                        _notify();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            title: 'Commercial Classification',
            description: widget.designerMode
                ? 'Expected price is a Designer proposal, not the final Customer charge.'
                : 'Admin may record the approved design charge for Paid/Premium designs.',
            children: [
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
                onChanged: widget.enabled
                    ? (value) {
                        setState(() {
                          _commercialType =
                              value ?? CatalogueCommercialType.free;
                        });
                        _notify();
                      }
                    : null,
              ),
              if (widget.designerMode && _priceRequired) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expectedPriceController,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Designer expected price',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_priceRequired) return null;
                    final price = double.tryParse(value?.trim() ?? '');
                    return price == null || price < 0
                        ? 'Enter a valid expected price'
                        : null;
                  },
                ),
              ],
              if (widget.showApprovedDesignCharge && _priceRequired) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _approvedChargeController,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Approved design charge',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_priceRequired) return null;
                    final price = double.tryParse(value?.trim() ?? '');
                    return price == null || price < 0
                        ? 'Enter a valid approved design charge'
                        : null;
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
