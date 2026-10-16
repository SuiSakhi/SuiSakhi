import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/catalogue_design_service.dart';
import '../../services/customer_fabric_asset_service.dart';
import '../../services/customer_wishlist_service.dart';
import '../../widgets/catalogue/catalogue_fabric_preview_button.dart';

class SmartStyleIdeasScreen extends StatefulWidget {
  const SmartStyleIdeasScreen({super.key});

  @override
  State<SmartStyleIdeasScreen> createState() => _SmartStyleIdeasScreenState();
}

class _SmartStyleIdeasScreenState extends State<SmartStyleIdeasScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Smart Style Ideas'),
        actions: [
          Tooltip(
            message: 'My wishlist',
            child: TextButton.icon(
              onPressed: () => context.push('/wishlist'),
              icon: const Icon(Icons.favorite_border_rounded, size: 19),
              label: const Text('Wishlist'),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse, preview and save your favourites.',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Try your fabric on an approved design. Browsing is free; a paid design charge applies only when you place a stitching order.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search designs',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('all', 'All designs'),
                    _filterChip('free', 'Free'),
                    _filterChip('paid', 'Paid'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CatalogueDesign>>(
              stream: CatalogueDesignService.watchPublishedDesigns(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load the design catalogue.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final designs =
                    snapshot.data!
                        .where(_matchesFilter)
                        .where(_matchesSearch)
                        .toList()
                      ..sort((a, b) => a.title.compareTo(b.title));
                if (designs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _query.isEmpty
                            ? 'No approved designs are available yet.'
                            : 'No designs match your search.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: designs.length,
                  itemBuilder: (context, index) => _SmartStyleDesignCard(
                    design: designs[index],
                    onTap: () => _openDesign(designs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  bool _matchesFilter(CatalogueDesign design) {
    final type = design.commercial.commercialType;
    return switch (_filter) {
      'free' => type == CatalogueCommercialType.free,
      'paid' =>
        type == CatalogueCommercialType.paid ||
            type == CatalogueCommercialType.premium,
      _ => true,
    };
  }

  bool _matchesSearch(CatalogueDesign design) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      design.title,
      design.description ?? '',
      ...design.garmentTypeCodes,
      ...design.occasionCodes,
      ...design.styleCodes,
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }

  Future<void> _openDesign(CatalogueDesign design) async {
    final bundle = await CatalogueDesignService.getPublishedBundle(design);
    final designCharge = design.commercial.approvedDesignCharge;
    if (!mounted) return;
    if (bundle == null || bundle.views.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This design has no published previews.')),
      );
      return;
    }

    final fabricSelections = <CustomerFabricPreviewSelection>[];
    var saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to designs'),
                  ),
                ),
                Text(design.title, style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  design.commercial.commercialType ==
                          CatalogueCommercialType.free
                      ? 'FREE design · Browse and save at no charge.'
                      : designCharge == null
                      ? 'PAID design · Charge applies only when you place a stitching order.'
                      : 'PAID design · ₹${designCharge.toStringAsFixed(0)} · charged only with a stitching order.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    itemCount: bundle.views.length,
                    itemBuilder: (context, index) =>
                        _CatalogueViewPage(view: bundle.views[index]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Swipe to view the published front and back. The original catalogue design stays unchanged as the Tailor reference.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 16),
                CatalogueFabricPreviewButton(
                  designId: design.designId,
                  versionId: bundle.version.versionId,
                  onSelectionChanged: (selection) =>
                      setSheetState(() => fabricSelections.add(selection)),
                ),
                if (fabricSelections.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Fabric comparisons (${fabricSelections.length})',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < fabricSelections.length; index++)
                    _FabricComparisonCard(
                      number: index + 1,
                      selection: fabricSelections[index],
                      onRemove: () =>
                          setSheetState(() => fabricSelections.removeAt(index)),
                    ),
                ],
                if (fabricSelections.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'AI visual approximations. Each saved comparison keeps its own fabric photo and preview.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheetState(() => saving = true);
                          try {
                            if (fabricSelections.isEmpty) {
                              await CustomerWishlistService.saveDesign(
                                designId: design.designId,
                                catalogueVersionId: bundle.version.versionId,
                              );
                            } else {
                              for (final selection in fabricSelections) {
                                await CustomerWishlistService.saveDesign(
                                  designId: design.designId,
                                  catalogueVersionId: bundle.version.versionId,
                                  fabricPreviewSelection: selection,
                                );
                              }
                            }
                            if (!mounted || !sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  fabricSelections.isEmpty
                                      ? 'Saved to My Wishlist.'
                                      : 'Saved ${fabricSelections.length} fabric comparison${fabricSelections.length == 1 ? '' : 's'} to My Wishlist.',
                                ),
                              ),
                            );
                          } on FirebaseException catch (error) {
                            if (!mounted || !sheetContext.mounted) return;
                            final permissionDenied =
                                error.code == 'permission-denied' ||
                                error.code == 'unauthorized';
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  permissionDenied
                                      ? 'Firebase blocked this wishlist save. Deploy the latest Firestore and Storage rules, then retry.'
                                      : 'Could not save design: ${error.message ?? error.code}',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!mounted || !sheetContext.mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text('Could not save design: $error'),
                              ),
                            );
                          } finally {
                            if (sheetContext.mounted) {
                              setSheetState(() => saving = false);
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_border_rounded),
                  label: Text(
                    saving
                        ? 'Saving…'
                        : fabricSelections.isEmpty
                        ? 'Save design to Wishlist'
                        : 'Save ${fabricSelections.length} comparison${fabricSelections.length == 1 ? '' : 's'}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FabricComparisonCard extends StatelessWidget {
  const _FabricComparisonCard({
    required this.number,
    required this.selection,
    required this.onRemove,
  });

  final int number;
  final CustomerFabricPreviewSelection selection;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fabric option $number · ${selection.previews.length} view${selection.previews.length == 1 ? '' : 's'}',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove this comparison',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          SizedBox(
            height: 230,
            child: PageView.builder(
              itemCount: selection.previews.length,
              itemBuilder: (context, index) {
                final preview = selection.previews[index];
                return Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          preview.bytes,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${preview.viewType} view'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _SmartStyleDesignCard extends StatefulWidget {
  const _SmartStyleDesignCard({required this.design, required this.onTap});

  final CatalogueDesign design;
  final VoidCallback onTap;

  @override
  State<_SmartStyleDesignCard> createState() => _SmartStyleDesignCardState();
}

class _SmartStyleDesignCardState extends State<_SmartStyleDesignCard> {
  late Future<PublishedCatalogueBundle?> _bundle;

  @override
  void initState() {
    super.initState();
    _bundle = CatalogueDesignService.getPublishedBundle(widget.design);
  }

  @override
  void didUpdateWidget(covariant _SmartStyleDesignCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design.designId != widget.design.designId ||
        oldWidget.design.activeVersionId != widget.design.activeVersionId) {
      _bundle = CatalogueDesignService.getPublishedBundle(widget.design);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<PublishedCatalogueBundle?>(
    future: _bundle,
    builder: (context, snapshot) {
      final view = snapshot.data?.primaryView;
      final imageUrl = view?.bestPreviewUrl?.trim() ?? '';
      final isFree =
          widget.design.commercial.commercialType ==
          CatalogueCommercialType.free;
      final designCharge = widget.design.commercial.approvedDesignCharge;
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: snapshot.hasData ? widget.onTap : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: AppColors.surfaceVariant,
                        child: Center(
                          child:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.image_outlined, size: 42),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.surfaceVariant,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined, size: 42),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.design.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFree
                          ? 'FREE'
                          : designCharge == null
                          ? 'PAID'
                          : 'PAID · ₹${designCharge.toStringAsFixed(0)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isFree ? AppColors.primary : AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preview and save',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CatalogueViewPage extends StatelessWidget {
  const _CatalogueViewPage({required this.view});

  final CatalogueDesignView view;

  @override
  Widget build(BuildContext context) {
    final imageUrl = view.bestPreviewUrl?.trim() ?? '';
    return Column(
      children: [
        Expanded(
          child: imageUrl.isEmpty
              ? const Center(child: Icon(Icons.image_not_supported_outlined))
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 42),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(view.viewType.label, style: AppTextStyles.titleMedium),
      ],
    );
  }
}
