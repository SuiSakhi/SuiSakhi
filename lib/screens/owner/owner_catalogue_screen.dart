import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import '../../services/owner_catalogue_service.dart';

class OwnerCatalogueScreen extends StatefulWidget {
  const OwnerCatalogueScreen({super.key});

  @override
  State<OwnerCatalogueScreen> createState() => _OwnerCatalogueScreenState();
}

class _OwnerCatalogueScreenState extends State<OwnerCatalogueScreen> {
  String? _categoryFilter;
  bool? _paidFilter;
  CatalogueDesignLifecycleStatus? _statusFilter;
  CataloguePublicationStatus? _publicationFilter;

  static const _knownCategories = <_CatalogueCategory>[
    _CatalogueCategory('blouse', 'Blouse', {'blouse', 'sareeblouse'}),
    _CatalogueCategory('kurti', 'Kurti', {'kurti'}),
    _CatalogueCategory('kurtaSet', 'Kurta Set', {'kurataset'}),
    _CatalogueCategory('salwarSuit', 'Salwar Suit', {'salwarsuit'}),
    _CatalogueCategory('anarkali', 'Anarkali', {'anarkali'}),
    _CatalogueCategory('lehengaCholi', 'Lehenga Choli', {'lehengacholi'}),
    _CatalogueCategory('gown', 'Gown', {'gown'}),
    _CatalogueCategory('topTunic', 'Top / Tunic', {'toptunic'}),
    _CatalogueCategory('shirt', 'Shirt', {'shirt'}),
    _CatalogueCategory('palazzoPant', 'Palazzo / Pant', {'palazzopant'}),
    _CatalogueCategory('skirt', 'Skirt', {'skirt'}),
    _CatalogueCategory('dress', 'Dress / One Piece', {'dress'}),
    _CatalogueCategory('other', 'Other', {'other'}),
  ];

  static const _unclassifiedCategory = _CatalogueCategory(
    '__unclassified__',
    'Unclassified',
    {},
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Governed Catalogue'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Upload Catalogue Design',
            onPressed: () => context.push('/owner/catalogue/upload'),
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogueDesign>>(
        stream: OwnerCatalogueService.watchAllDesigns(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message('Unable to load Catalogue.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final categories = _categoriesFor(all);
          final selectedCategory = _categoryFilter == null
              ? null
              : _findCategory(categories, _categoryFilter!);
          final designs = _matchingDesigns(
            all,
            category: selectedCategory,
            paid: _paidFilter,
            lifecycle: _statusFilter,
            publication: _publicationFilter,
          );
          return Column(
            children: [
              _filters(all, categories, selectedCategory),
              Expanded(
                child: designs.isEmpty
                    ? _message(
                        _categoryFilter == null &&
                                _paidFilter == null &&
                                _statusFilter == null &&
                                _publicationFilter == null
                            ? 'No governed Catalogue designs yet.'
                            : 'No designs match the selected filters.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: designs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _DesignCard(design: designs[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner/catalogue/upload'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Upload Design'),
      ),
    );
  }

  List<_CatalogueCategory> _categoriesFor(List<CatalogueDesign> designs) {
    final categories = [..._knownCategories];
    final knownCodes = _knownCategories
        .expand((category) => category.codes)
        .toSet();
    final extraCodes =
        designs
            .expand(_garmentCodesFor)
            .where((code) => !knownCodes.contains(code))
            .toSet()
            .toList()
          ..sort();
    categories.addAll(
      extraCodes.map((code) => _CatalogueCategory(code, _label(code), {code})),
    );
    if (designs.any((design) => _garmentCodesFor(design).isEmpty)) {
      categories.add(_unclassifiedCategory);
    }
    return categories;
  }

  _CatalogueCategory? _findCategory(
    List<_CatalogueCategory> categories,
    String code,
  ) {
    for (final category in categories) {
      if (category.code == code) return category;
    }
    return null;
  }

  Set<String> _garmentCodesFor(CatalogueDesign design) {
    final codes = design.garmentTypeCodes
        .map(_normalizeCode)
        .where((code) => code.isNotEmpty)
        .toSet();
    if (codes.isNotEmpty) return codes;
    final fallback = _normalizeCode(
      design.constructionMetadata?.dressType ?? '',
    );
    return fallback.isEmpty ? <String>{} : <String>{fallback};
  }

  String _normalizeCode(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _matchesCategory(CatalogueDesign design, _CatalogueCategory? category) {
    if (category == null) return true;
    final codes = _garmentCodesFor(design);
    if (category.code == _unclassifiedCategory.code) return codes.isEmpty;
    return codes.any(category.codes.contains);
  }

  List<CatalogueDesign> _matchingDesigns(
    List<CatalogueDesign> designs, {
    required _CatalogueCategory? category,
    required bool? paid,
    required CatalogueDesignLifecycleStatus? lifecycle,
    required CataloguePublicationStatus? publication,
  }) {
    return designs.where((design) {
      final isPaid =
          design.commercial.commercialType != CatalogueCommercialType.free;
      return _matchesCategory(design, category) &&
          (paid == null || isPaid == paid) &&
          (lifecycle == null || design.lifecycleStatus == lifecycle) &&
          (publication == null || design.publicationStatus == publication);
    }).toList();
  }

  Widget _filters(
    List<CatalogueDesign> all,
    List<_CatalogueCategory> categories,
    _CatalogueCategory? selectedCategory,
  ) {
    int activeCategoryDesigns(bool? paid) => _matchingDesigns(
      all,
      category: selectedCategory,
      paid: paid,
      lifecycle: _statusFilter,
      publication: _publicationFilter,
    ).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterLabel('Garment category'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  label:
                      'All categories (${_matchingDesigns(all, category: null, paid: _paidFilter, lifecycle: _statusFilter, publication: _publicationFilter).length})',
                  selected: _categoryFilter == null,
                  onSelected: () => setState(() => _categoryFilter = null),
                ),
                for (final category in categories)
                  _filterChip(
                    label:
                        '${category.label} (${_matchingDesigns(all, category: category, paid: _paidFilter, lifecycle: _statusFilter, publication: _publicationFilter).length})',
                    selected: _categoryFilter == category.code,
                    onSelected: () =>
                        setState(() => _categoryFilter = category.code),
                  ),
              ],
            ),
          ),
          _filterLabel('Commercial'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  label: 'All (${activeCategoryDesigns(null)})',
                  selected: _paidFilter == null,
                  onSelected: () => setState(() => _paidFilter = null),
                ),
                _filterChip(
                  label: 'Free (${activeCategoryDesigns(false)})',
                  selected: _paidFilter == false,
                  onSelected: () => setState(() => _paidFilter = false),
                ),
                _filterChip(
                  label: 'Paid (${activeCategoryDesigns(true)})',
                  selected: _paidFilter == true,
                  onSelected: () => setState(() => _paidFilter = true),
                ),
              ],
            ),
          ),
          _filterLabel('Workflow'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  label:
                      'All (${_matchingDesigns(all, category: selectedCategory, paid: _paidFilter, lifecycle: null, publication: _publicationFilter).length})',
                  selected: _statusFilter == null,
                  onSelected: () => setState(() => _statusFilter = null),
                ),
                for (final status in CatalogueDesignLifecycleStatus.values)
                  _filterChip(
                    label:
                        '${_label(status.name)} (${_matchingDesigns(all, category: selectedCategory, paid: _paidFilter, lifecycle: status, publication: _publicationFilter).length})',
                    selected: _statusFilter == status,
                    onSelected: () => setState(() => _statusFilter = status),
                  ),
              ],
            ),
          ),
          _filterLabel('Publication'),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  label:
                      'All (${_matchingDesigns(all, category: selectedCategory, paid: _paidFilter, lifecycle: _statusFilter, publication: null).length})',
                  selected: _publicationFilter == null,
                  onSelected: () => setState(() => _publicationFilter = null),
                ),
                for (final status in CataloguePublicationStatus.values)
                  _filterChip(
                    label:
                        '${_label(status.name)} (${_matchingDesigns(all, category: selectedCategory, paid: _paidFilter, lifecycle: _statusFilter, publication: status).length})',
                    selected: _publicationFilter == status,
                    onSelected: () =>
                        setState(() => _publicationFilter = status),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(String value) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      value,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _CatalogueCategory {
  const _CatalogueCategory(this.code, this.label, this.codes);

  final String code;
  final String label;
  final Set<String> codes;
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.design});

  final CatalogueDesign design;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OwnerCatalogueVersionBundle?>(
      future: OwnerCatalogueService.getActiveVersionBundle(design),
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        final version = bundle?.version;
        final imageUrl = bundle?.primaryView?.bestPreviewUrl;
        final processing = version?.processing.status.name ?? 'notRequested';
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              context.push('/owner/catalogue/${design.designId}/review'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 104,
                    height: 122,
                    child: imageUrl == null || imageUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFFCEAF1),
                            child: Icon(Icons.image_not_supported_outlined),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFFCEAF1),
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(design.title, style: AppTextStyles.titleMedium),
                      if (design.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          design.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(
                            bundle?.contributor.displayName ??
                                _label(design.ownerType.name),
                          ),
                          _chip(_label(design.commercial.commercialType.name)),
                          _chip(_label(design.lifecycleStatus.name)),
                          _chip(_label(processing)),
                          _chip(_label(design.publicationStatus.name)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        design.garmentTypeCodes.isEmpty
                            ? 'Garment type not classified'
                            : design.garmentTypeCodes.map(_label).join(', '),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFCEAF1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: AppTextStyles.bodySmall),
  );
}

String _label(String code) {
  final spaced = code.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  if (spaced.isEmpty) return spaced;
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
