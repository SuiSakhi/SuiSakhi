import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/store_product.dart';
import '../../services/order_service.dart';
import '../../services/store_product_service.dart';

class FashionStoreScreen extends StatefulWidget {
  const FashionStoreScreen({
    super.key,
    this.initialCategoryCode,
    this.initialSearchQuery,
  });

  final String? initialCategoryCode;
  final String? initialSearchQuery;

  @override
  State<FashionStoreScreen> createState() => _FashionStoreScreenState();
}

class _FashionStoreScreenState extends State<FashionStoreScreen> {
  final _searchController = TextEditingController();
  String? _categoryCode;
  String? _selectedBrand;
  String? _selectedSubcategory;
  String? _selectedSize;
  String? _selectedColor;
  bool _sortLowToHigh = true;
  late Stream<List<StoreProduct>> _productsStream;

  @override
  void initState() {
    super.initState();
    _categoryCode =
        widget.initialCategoryCode ?? StoreProductCategory.readyToWear.code;
    _searchController.text = widget.initialSearchQuery?.trim() ?? '';
    _productsStream = StoreProductService.watchPublishedProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCategory(String? categoryCode) {
    setState(() {
      _categoryCode = categoryCode;
      _selectedSubcategory = null;
      _selectedBrand = null;
      _selectedSize = null;
      _selectedColor = null;
    });
  }

  Future<void> _openProduct(StoreProduct product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FashionProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<StoreProduct>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            final allProducts = snapshot.data ?? const <StoreProduct>[];
            final matchingCategory = allProducts
                .where((product) {
                  return _categoryCode == null ||
                      product.categoryCode == _categoryCode;
                })
                .toList(growable: false);
            final brands =
                matchingCategory
                    .map(_brandFor)
                    .where((brand) => brand.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            final categoryLabels =
                matchingCategory
                    .map(_categoryFor)
                    .where((category) => category.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            final term = _searchController.text.trim().toLowerCase();
            final productSectionTitle = _categoryCode == null
                ? 'Shop products'
                : _categoryCode == StoreProductCategory.readyToWear.code
                ? 'Shop readymade outfits'
                : 'Shop ${StoreProductCategory.byCode(_categoryCode!).label}';
            final products = matchingCategory.where((product) {
              final brand = _brandFor(product);
              if (_selectedBrand != null && brand != _selectedBrand) {
                return false;
              }
              if (_selectedSubcategory != null &&
                  _categoryFor(product) != _selectedSubcategory) {
                return false;
              }
              if (_selectedSize != null &&
                  !product.sizes.contains(_selectedSize)) {
                return false;
              }
              if (_selectedColor != null &&
                  !product.colors.contains(_selectedColor)) {
                return false;
              }
              if (term.isEmpty) return true;
              return <String>[
                product.name,
                product.subcategory,
                product.brandName,
                product.sellerName,
                product.description,
                product.category.label,
              ].any((value) => value.toLowerCase().contains(term));
            }).toList();
            products.sort(
              (a, b) => _sortLowToHigh
                  ? a.displayPrice.compareTo(b.displayPrice)
                  : b.displayPrice.compareTo(a.displayPrice),
            );

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _productsStream =
                      StoreProductService.watchPublishedProducts();
                });
                await Future<void>.delayed(const Duration(milliseconds: 250));
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _headerArtwork(context)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _searchField(),
                          const SizedBox(height: 18),
                          _sectionTitle('Shop by Brand'),
                          const SizedBox(height: 10),
                          if (brands.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Partner brands will appear here as ready-to-wear '
                                'outfits are published.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 92,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _BrandTile(
                                    label: 'All Brands',
                                    selected: _selectedBrand == null,
                                    onTap: () =>
                                        setState(() => _selectedBrand = null),
                                  ),
                                  for (final brand in brands)
                                    _BrandTile(
                                      label: brand,
                                      selected: _selectedBrand == brand,
                                      onTap: () => setState(
                                        () => _selectedBrand =
                                            _selectedBrand == brand
                                            ? null
                                            : brand,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          _sectionTitle('Shop by Category'),
                          const SizedBox(height: 10),
                          if (categoryLabels.isNotEmpty)
                            SizedBox(
                              height: 132,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final category in categoryLabels)
                                    _StoreCategoryTile(
                                      label: category,
                                      imageUrl: _imageForCategory(
                                        matchingCategory,
                                        category,
                                      ),
                                      selected:
                                          _selectedSubcategory == category,
                                      onTap: () => setState(
                                        () => _selectedSubcategory =
                                            _selectedSubcategory == category
                                            ? null
                                            : category,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            const SizedBox(height: 4),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _PriceFilter(
                                  lowToHigh: _sortLowToHigh,
                                  onTap: () => setState(
                                    () => _sortLowToHigh = !_sortLowToHigh,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StoreMenuFilter(
                                  label: 'Size',
                                  options: _filterOptions(
                                    matchingCategory,
                                    (product) => product.sizes,
                                  ),
                                  selected: _selectedSize,
                                  onSelected: (value) =>
                                      setState(() => _selectedSize = value),
                                ),
                                const SizedBox(width: 8),
                                _StoreMenuFilter(
                                  label: 'Color',
                                  options: _filterOptions(
                                    matchingCategory,
                                    (product) => product.colors,
                                  ),
                                  selected: _selectedColor,
                                  onSelected: (value) =>
                                      setState(() => _selectedColor = value),
                                ),
                                const SizedBox(width: 8),
                                _StoreMenuFilter(
                                  label: 'Category',
                                  options: StoreProductCategory.all
                                      .where(
                                        (category) => allProducts.any(
                                          (product) =>
                                              product.categoryCode ==
                                              category.code,
                                        ),
                                      )
                                      .map((category) => category.label)
                                      .toList(growable: false),
                                  selected: _categoryCode == null
                                      ? null
                                      : StoreProductCategory.byCode(
                                          _categoryCode!,
                                        ).label,
                                  onSelected: (value) {
                                    final categories = StoreProductCategory.all
                                        .where(
                                          (category) => category.label == value,
                                        )
                                        .toList(growable: false);
                                    _selectCategory(
                                      categories.isEmpty
                                          ? null
                                          : categories.first.code,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (snapshot.hasError)
                            const _StoreMessage(
                              icon: Icons.cloud_off_outlined,
                              title: 'Store listings are unavailable',
                              message:
                                  'Please check your connection and try again shortly.',
                            )
                          else if (products.isEmpty)
                            _StoreMessage(
                              icon: Icons.storefront_outlined,
                              title: term.isEmpty
                                  ? _categoryCode ==
                                            StoreProductCategory
                                                .readyToWear
                                                .code
                                        ? 'No ready-to-wear outfits yet'
                                        : 'No products in this category yet'
                                  : 'No matching outfits found',
                              message: term.isEmpty
                                  ? 'Published partner outfits will appear here.'
                                  : 'Try another search or clear a filter.',
                            )
                          else
                            _sectionTitle(productSectionTitle),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (products.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      sliver: SliverGrid.builder(
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.64,
                            ),
                        itemBuilder: (context, index) => _ProductCard(
                          product: products[index],
                          onTap: () => _openProduct(products[index]),
                          onTryOn: _supportsTryOn(products[index])
                              ? () => _openTryOn(products[index])
                              : null,
                        ),
                      ),
                    ),
                  if (products.any(_supportsTryOn))
                    SliverToBoxAdapter(
                      child: _tryOnBanner(
                        context,
                        products.firstWhere(_supportsTryOn),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerArtwork(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * 410 / 870;
        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/fashion_store_header.png',
                fit: BoxFit.fill,
              ),
              Positioned(
                left: 0,
                top: 0,
                width: width * 0.085,
                height: height * 0.18,
                child: _HeaderHitTarget(
                  label: 'Back',
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
              Positioned(
                left: width * 0.80,
                top: 0,
                width: width * 0.09,
                height: height * 0.18,
                child: _HeaderHitTarget(
                  label: 'My orders',
                  onTap: () => context.push('/orders'),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: width * 0.085,
                height: height * 0.18,
                child: _HeaderHitTarget(
                  label: 'Wishlist',
                  onTap: () => context.push('/wishlist'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _searchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search products, brands, outfits, fabrics, boutiques...',
          hintStyle: AppTextStyles.bodySmall.copyWith(fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) => Text(
    label,
    style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _tryOnBanner(BuildContext context, StoreProduct product) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openTryOn(product),
          child: SizedBox(
            height: 106,
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  height: 106,
                  child: _productImage(product, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Virtual Try-On',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        'Preview ${product.name} on your photo',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.chevron_right, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTryOn(StoreProduct product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FashionTryOnPreviewScreen(product: product),
      ),
    );
  }

  bool _supportsTryOn(StoreProduct product) =>
      product.categoryCode == StoreProductCategory.readyToWear.code ||
      product.categoryCode == StoreProductCategory.kidsFashion.code;

  String _brandFor(StoreProduct product) => product.brandName.trim().isNotEmpty
      ? product.brandName.trim()
      : product.sellerName.trim();

  String _categoryFor(StoreProduct product) =>
      product.subcategory.trim().isNotEmpty
      ? product.subcategory.trim()
      : product.category.label;

  String? _imageForCategory(List<StoreProduct> products, String category) {
    for (final product in products) {
      if (_categoryFor(product) != category) continue;
      for (final image in product.images) {
        if (image.view == 'front') return image.url;
      }
      if (product.images.isNotEmpty) return product.images.first.url;
    }
    return null;
  }

  List<String> _filterOptions(
    List<StoreProduct> products,
    List<String> Function(StoreProduct) getValues,
  ) =>
      products
          .expand(getValues)
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

class _HeaderHitTarget extends StatelessWidget {
  const _HeaderHitTarget({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap),
    ),
  );
}

class _BrandTile extends StatelessWidget {
  const _BrandTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allBrands = label == 'All Brands';
    return SizedBox(
      width: 72,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceVariant : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  allBrands
                      ? Icons.grid_view_rounded
                      : Icons.storefront_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 9,
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

class _StoreCategoryTile extends StatelessWidget {
  const _StoreCategoryTile({
    required this.label,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 1.4,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      child: imageUrl == null
                          ? const _ProductImagePlaceholder()
                          : Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const _ProductImagePlaceholder(),
                            ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceFilter extends StatelessWidget {
  const _PriceFilter({required this.lowToHigh, required this.onTap});

  final bool lowToHigh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _FilterPill(
    label: 'Price: ${lowToHigh ? 'Low to High' : 'High to Low'}',
    icon: Icons.keyboard_arrow_down_rounded,
    onTap: onTap,
  );
}

class _StoreMenuFilter extends StatelessWidget {
  const _StoreMenuFilter({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) => onSelected(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text('All $label')),
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
      ],
      child: _FilterPill(
        label: selected ?? label,
        icon: Icons.keyboard_arrow_down_rounded,
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 17, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    this.onTryOn,
  });

  final StoreProduct product;
  final VoidCallback onTap;
  final VoidCallback? onTryOn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _productImage(product, fit: BoxFit.cover),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.subcategory.trim().isEmpty
                            ? product.category.label
                            : product.subcategory,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  if (onTryOn != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onTryOn,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.face_retouching_natural_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Virtual Try-On',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (product.images.length > 1)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.threesixty_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.brandName.trim().isEmpty
                        ? product.sellerName
                        : product.brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _priceLabel(product),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FashionProductDetailScreen extends StatefulWidget {
  const FashionProductDetailScreen({super.key, required this.product});

  final StoreProduct product;

  @override
  State<FashionProductDetailScreen> createState() =>
      _FashionProductDetailScreenState();
}

class _FashionProductDetailScreenState
    extends State<FashionProductDetailScreen> {
  static const _viewOrder = ['front', 'left', 'back', 'right', 'detail'];
  late final List<StoreProductImage> _images = _orderedImages();
  int _activeImage = 0;

  List<StoreProductImage> _orderedImages() {
    final images = [...widget.product.images];
    images.sort((a, b) {
      final aIndex = _viewOrder.indexOf(a.view);
      final bIndex = _viewOrder.indexOf(b.view);
      return (aIndex < 0 ? _viewOrder.length : aIndex).compareTo(
        bIndex < 0 ? _viewOrder.length : bIndex,
      );
    });
    return images;
  }

  String _viewLabel(String view) {
    if (widget.product.categoryCode == StoreProductCategory.fabric.code) {
      return switch (view) {
        'front' => 'Fabric face',
        'back' => 'Reverse side',
        'left' => 'Drape / scale',
        'right' => 'Texture',
        'detail' => 'Border / close-up',
        _ => 'Fabric view',
      };
    }
    if (widget.product.categoryCode == StoreProductCategory.accessories.code) {
      return switch (view) {
        'front' => 'Main view',
        'back' => 'Back view',
        'left' => 'Left side',
        'right' => 'Right side',
        'detail' => 'Detail view',
        _ => 'Product view',
      };
    }
    return switch (view) {
      'front' => 'Front view',
      'back' => 'Back view',
      'left' => 'Left side',
      'right' => 'Right side',
      'detail' => 'Detail view',
      _ => 'Product view',
    };
  }

  bool get _canTryOn =>
      widget.product.categoryCode == StoreProductCategory.readyToWear.code ||
      widget.product.categoryCode == StoreProductCategory.kidsFashion.code;

  Future<void> _askPartner() async {
    final product = widget.product;
    try {
      final orderId = await OrderService.createMarketplaceInterest(
        shopCategoryId: product.categoryCode,
        title: product.name,
        notes:
            'Customer enquiry for ${product.name} '
            '(listing ${product.productId}) from ${product.sellerName}.',
      );
      if (!mounted) return;
      if (orderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to send this enquiry.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enquiry recorded. SuiSakhi will coordinate with the partner.',
          ),
        ),
      );
      context.push('/orders');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send the enquiry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final unit = product.unit == 'metre' ? ' / metre' : ' / piece';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(product.category.label)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (_canTryOn) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FashionTryOnPreviewScreen(product: product),
                    ),
                  ),
                  icon: const Icon(Icons.face_retouching_natural_outlined),
                  label: const Text('Try it on me'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _askPartner,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Send enquiry'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ProductGallery(
            images: _images,
            activeIndex: _activeImage,
            onPageChanged: (index) => setState(() => _activeImage = index),
            viewLabel: _images.isEmpty
                ? ''
                : _viewLabel(_images[_activeImage].view),
          ),
          const SizedBox(height: 18),
          Text(product.name, style: AppTextStyles.headlineMedium),
          if (product.subcategory.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.subcategory,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '₹${product.displayPrice.toStringAsFixed(0)}$unit',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (product.discountPriceInr != null) ...[
                const SizedBox(width: 8),
                Text(
                  '₹${product.priceInr.toStringAsFixed(0)}$unit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _InfoCard(
            icon: Icons.storefront_outlined,
            title: product.brandName.trim().isEmpty
                ? product.sellerName
                : product.brandName,
            subtitle: 'SuiSakhi boutique partner',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.inventory_2_outlined,
            title: product.stockQuantity > 0
                ? 'Available from partner'
                : 'Currently out of stock',
            subtitle: product.unit == 'metre'
                ? 'Minimum order: ${product.minimumQuantity} metre(s)'
                : product.sizes.isEmpty
                ? 'Contact the partner to confirm size availability'
                : 'Sizes: ${product.sizes.join(', ')}',
          ),
          if (product.colors.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.palette_outlined,
              title: 'Available colours',
              subtitle: product.colors.join(', '),
            ),
          ],
          if (product.fabricComposition.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.texture_outlined,
              title: product.fabricComposition,
              subtitle: product.fabricWidth.trim().isEmpty
                  ? 'Fabric composition'
                  : 'Width ${product.fabricWidth}',
            ),
          ],
          const SizedBox(height: 16),
          Text('About this product', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text(product.description, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Text(
            'Multi-angle views show the photos supplied by this partner. '
            'The try-on preview is a visual guide and does not predict fit.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _ProductGallery extends StatelessWidget {
  const _ProductGallery({
    required this.images,
    required this.activeIndex,
    required this.onPageChanged,
    required this.viewLabel,
  });

  final List<StoreProductImage> images;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              const _ProductImagePlaceholder()
            else
              PageView.builder(
                itemCount: images.length,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) => ColoredBox(
                  color: Colors.white,
                  child: Image.network(
                    images[index].url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _ProductImagePlaceholder(),
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.threesixty_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Swipe through views',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (images.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.64),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          viewLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${activeIndex + 1} / ${images.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FashionTryOnPreviewScreen extends StatefulWidget {
  const FashionTryOnPreviewScreen({super.key, required this.product});

  final StoreProduct product;

  @override
  State<FashionTryOnPreviewScreen> createState() =>
      _FashionTryOnPreviewScreenState();
}

class _FashionTryOnPreviewScreenState extends State<FashionTryOnPreviewScreen> {
  Uint8List? _customerPhoto;
  Offset _garmentOffset = Offset.zero;
  double _garmentScale = 0.85;
  double _opacity = 0.72;
  bool _picking = false;

  String? get _garmentImage {
    for (final image in widget.product.images) {
      if (image.view == 'front') return image.url;
    }
    return widget.product.images.isEmpty
        ? null
        : widget.product.images.first.url;
  }

  Future<void> _pickCustomerPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _customerPhoto = bytes;
            _garmentOffset = Offset.zero;
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open that photo: $error')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final garmentImage = _garmentImage;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Try it on me')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Preview the style on your photo',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            'Choose a full-length photo. Drag the garment image to position it, '
            'then adjust its size and transparency.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          if (_customerPhoto == null)
            Container(
              height: 420,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.primary,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    const Text('Add your photo to begin'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _picking ? null : _pickCustomerPhoto,
                      icon: _picking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose camera or gallery'),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 500,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.memory(_customerPhoto!, fit: BoxFit.cover),
                  ),
                  if (garmentImage != null)
                    Transform.translate(
                      offset: _garmentOffset,
                      child: GestureDetector(
                        onPanUpdate: (details) => setState(() {
                          _garmentOffset += details.delta;
                        }),
                        child: Transform.scale(
                          scale: _garmentScale,
                          child: Opacity(
                            opacity: _opacity,
                            child: Image.network(
                              garmentImage,
                              width: 220,
                              height: 300,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                size: 60,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: IconButton.filledTonal(
                      tooltip: 'Choose another photo',
                      onPressed: _pickCustomerPhoto,
                      icon: const Icon(Icons.photo_camera_back_outlined),
                    ),
                  ),
                ],
              ),
            ),
          if (_customerPhoto != null) ...[
            const SizedBox(height: 14),
            _PreviewSlider(
              label: 'Garment size',
              value: _garmentScale,
              min: 0.45,
              max: 1.35,
              onChanged: (value) => setState(() => _garmentScale = value),
            ),
            _PreviewSlider(
              label: 'Transparency',
              value: _opacity,
              min: 0.3,
              max: 1,
              onChanged: (value) => setState(() => _opacity = value),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _garmentOffset = Offset.zero;
                _garmentScale = 0.85;
                _opacity = 0.72;
              }),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset preview'),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'This is a manual visual approximation using your selected '
              'photo and the partner product image. It is not an AI-generated '
              'try-on and does not predict fit. Your photo stays on this device.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSlider extends StatelessWidget {
  const _PreviewSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 98, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _StoreMessage extends StatelessWidget {
  const _StoreMessage({
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _priceLabel(StoreProduct product) {
  final unit = product.unit == 'metre' ? ' / metre' : ' / piece';
  return '₹${product.displayPrice.toStringAsFixed(0)}$unit';
}

Widget _productImage(StoreProduct product, {required BoxFit fit}) {
  StoreProductImage? image;
  for (final candidate in product.images) {
    if (candidate.view == 'front') {
      image = candidate;
      break;
    }
  }
  image ??= product.images.isEmpty ? null : product.images.first;
  if (image == null) return const _ProductImagePlaceholder();
  return Image.network(
    image.url,
    fit: fit,
    errorBuilder: (_, _, _) => const _ProductImagePlaceholder(),
  );
}
