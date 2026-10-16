import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/store_product.dart';
import '../../services/store_product_service.dart';

class StoreProductManagementScreen extends StatefulWidget {
  const StoreProductManagementScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    required this.partnerType,
    required this.sellerName,
  });

  final String accountId;
  final String profileId;
  final String partnerType;
  final String sellerName;

  @override
  State<StoreProductManagementScreen> createState() =>
      _StoreProductManagementScreenState();
}

class _StoreProductManagementScreenState
    extends State<StoreProductManagementScreen> {
  String _statusFilter = 'all';

  Future<void> _openEditor([StoreProduct? product]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StoreProductEditorScreen(
          accountId: widget.accountId,
          profileId: widget.profileId,
          partnerType: widget.partnerType,
          sellerName: widget.sellerName,
          product: product,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store listing saved.')),
      );
    }
  }

  Future<void> _setStatus(StoreProduct product, String status) async {
    try {
      await StoreProductService.updateStatus(
        productId: product.productId,
        status: status,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update listing: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Listings'),
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_rounded),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Partner profile and account',
            onPressed: () => context.push(
              '/partner/account'
              '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
              '&profileId=${Uri.encodeQueryComponent(widget.profileId)}'
              '&category=${Uri.encodeQueryComponent(widget.partnerType)}',
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      body: StreamBuilder<List<StoreProduct>>(
        stream: StoreProductService.watchPartnerProducts(
          accountId: widget.accountId,
          profileId: widget.profileId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load store listings',
              message: 'Check your connection and try again.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!;
          final counts = {
            'all': products.length,
            'published': products.where((p) => p.status == 'published').length,
            'draft': products.where((p) => p.status == 'draft').length,
            'paused': products.where((p) => p.status == 'paused').length,
          };
          final visible = _statusFilter == 'all'
              ? products
              : products.where((product) => product.status == _statusFilter);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
            children: [
              Text(
                'Manage your products',
                style: AppTextStyles.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Add garments, fabrics and accessories to your SuiSakhi store. '
                'Published listings can be shown to customers.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: counts['all']!,
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                    _FilterChip(
                      label: 'Published',
                      count: counts['published']!,
                      selected: _statusFilter == 'published',
                      onTap: () => setState(() => _statusFilter = 'published'),
                    ),
                    _FilterChip(
                      label: 'Drafts',
                      count: counts['draft']!,
                      selected: _statusFilter == 'draft',
                      onTap: () => setState(() => _statusFilter = 'draft'),
                    ),
                    _FilterChip(
                      label: 'Paused',
                      count: counts['paused']!,
                      selected: _statusFilter == 'paused',
                      onTap: () => setState(() => _statusFilter = 'paused'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (products.isEmpty)
                _MessageState(
                  icon: Icons.storefront_outlined,
                  title: 'Your store is ready for its first product',
                  message:
                      'Add a clear front photo, choose a category and enter '
                      'your price and available stock.',
                  action: FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add your first product'),
                  ),
                )
              else if (visible.isEmpty)
                _MessageState(
                  icon: Icons.inventory_2_outlined,
                  title: _statusFilter == 'draft'
                      ? 'No drafts'
                      : 'No $_statusFilter listings',
                  message: 'Choose another status to view your products.',
                )
              else
                for (final product in visible)
                  _StoreProductCard(
                    product: product,
                    onEdit: () => _openEditor(product),
                    onStatusChanged: (status) =>
                        _setStatus(product, status),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  const _StoreProductCard({
    required this.product,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final StoreProduct product;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final frontImages = product.images.where((image) => image.view == 'front');
    final imageUrl = frontImages.isEmpty ? null : frontImages.first.url;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 82,
                height: 100,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: const Icon(
                          Icons.checkroom_outlined,
                          color: AppColors.primary,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Listing actions',
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'pause') onStatusChanged('paused');
                          if (value == 'publish') {
                            onStatusChanged('published');
                          }
                          if (value == 'draft') onStatusChanged('draft');
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit listing'),
                          ),
                          if (product.status == 'published')
                            const PopupMenuItem(
                              value: 'pause',
                              child: Text('Pause listing'),
                            )
                          else
                            const PopupMenuItem(
                              value: 'publish',
                              child: Text('Publish listing'),
                            ),
                          if (product.status != 'draft')
                            const PopupMenuItem(
                              value: 'draft',
                              child: Text('Move to draft'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${product.category.label} · ${product.subcategory}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _priceLabel(product),
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Stock: ${product.stockQuantity} ${product.unit == 'metre' ? 'm' : 'units'}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 7),
                  _StatusBadge(status: product.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(StoreProduct product) {
    final unit = product.unit == 'metre' ? ' / metre' : ' / piece';
    final formatted = '₹${product.displayPrice.toStringAsFixed(0)}$unit';
    if (product.discountPriceInr == null) return formatted;
    return '$formatted (MRP ₹${product.priceInr.toStringAsFixed(0)})';
  }
}

class StoreProductEditorScreen extends StatefulWidget {
  const StoreProductEditorScreen({
    super.key,
    required this.accountId,
    required this.profileId,
    required this.partnerType,
    required this.sellerName,
    this.product,
  });

  final String accountId;
  final String profileId;
  final String partnerType;
  final String sellerName;
  final StoreProduct? product;

  @override
  State<StoreProductEditorScreen> createState() =>
      _StoreProductEditorScreenState();
}

class _StoreProductEditorScreenState extends State<StoreProductEditorScreen> {
  List<(String, String)> get _photoViews {
    if (_isFabric) {
      return const [
        ('front', 'Fabric face'),
        ('back', 'Reverse side'),
        ('left', 'Drape / scale'),
        ('right', 'Texture'),
        ('detail', 'Border / close-up'),
      ];
    }
    if (_categoryCode == StoreProductCategory.accessories.code) {
      return const [
        ('front', 'Main view'),
        ('back', 'Back view'),
        ('left', 'Left side'),
        ('right', 'Right side'),
        ('detail', 'Detail'),
      ];
    }
    return const [
      ('front', 'Front'),
      ('back', 'Back'),
      ('left', 'Left side'),
      ('right', 'Right side'),
      ('detail', 'Detail'),
    ];
  }

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _subcategory = TextEditingController();
  final _brandName = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _discountPrice = TextEditingController();
  final _stock = TextEditingController();
  final _sizes = TextEditingController();
  final _colors = TextEditingController();
  final _composition = TextEditingController();
  final _width = TextEditingController();
  final _minimumQuantity = TextEditingController(text: '1');
  final Map<String, XFile> _newImages = {};
  late String _categoryCode;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _categoryCode = product?.categoryCode ??
        StoreProductCategory.readyToWear.code;
    _status = product?.status ?? 'draft';
    _name.text = product?.name ?? '';
    _subcategory.text = product?.subcategory ?? '';
    _brandName.text = product?.brandName ?? '';
    _description.text = product?.description ?? '';
    _price.text = product?.priceInr.toStringAsFixed(0) ?? '';
    _discountPrice.text = product?.discountPriceInr?.toStringAsFixed(0) ?? '';
    _stock.text = product?.stockQuantity.toString() ?? '';
    _sizes.text = product?.sizes.join(', ') ?? '';
    _colors.text = product?.colors.join(', ') ?? '';
    _composition.text = product?.fabricComposition ?? '';
    _width.text = product?.fabricWidth ?? '';
    _minimumQuantity.text = product?.minimumQuantity.toString() ?? '1';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _subcategory,
      _brandName,
      _description,
      _price,
      _discountPrice,
      _stock,
      _sizes,
      _colors,
      _composition,
      _width,
      _minimumQuantity,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isFabric => _categoryCode == StoreProductCategory.fabric.code;

  Future<void> _pickPhoto(String view) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
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
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (file != null && mounted) {
        setState(() => _newImages[view] = file);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final currentImages = widget.product?.images ?? const <StoreProductImage>[];
    final hasFront = _newImages.containsKey('front') ||
        currentImages.any((image) => image.view == 'front');
    if (_status == 'published' && !hasFront) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a front product photo before publishing.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final price = double.parse(_price.text.trim());
    final discountText = _discountPrice.text.trim();
    final product = StoreProduct(
      productId: widget.product?.productId ?? '',
      partnerAccountId: widget.accountId,
      partnerProfileId: widget.profileId,
      partnerType: widget.partnerType,
      sellerName: widget.sellerName,
      name: _name.text,
      description: _description.text,
      categoryCode: _categoryCode,
      subcategory: _subcategory.text,
      priceInr: price,
      discountPriceInr:
          discountText.isEmpty ? null : double.parse(discountText),
      stockQuantity: int.parse(_stock.text.trim()),
      status: _status,
      brandName: _brandName.text,
      unit: _isFabric ? 'metre' : 'piece',
      fabricComposition: _composition.text,
      fabricWidth: _width.text,
      minimumQuantity: int.tryParse(_minimumQuantity.text.trim()) ?? 1,
      sizes: _splitValues(_sizes.text),
      colors: _splitValues(_colors.text),
      images: currentImages,
      createdAt: widget.product?.createdAt,
    );

    try {
      await StoreProductService.saveProduct(
        product: product,
        accountId: widget.accountId,
        profileId: widget.profileId,
        newImagesByView: _newImages,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save listing: $error')),
      );
    }
  }

  List<String> _splitValues(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _positiveNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? 'Enter an amount above zero' : null;
  }

  String? _validDiscount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final discount = double.tryParse(value.trim());
    final price = double.tryParse(_price.text.trim());
    if (discount == null || discount <= 0) return 'Enter a valid price';
    if (price != null && discount >= price) {
      return 'Sale price must be lower than MRP';
    }
    return null;
  }

  String? _validStock(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');
    return quantity == null || quantity < 0 ? 'Enter 0 or more' : null;
  }

  String? _validMinimumQuantity(String? value) {
    final quantity = int.tryParse(value?.trim() ?? '');
    return quantity == null || quantity <= 0 ? 'Enter at least 1 metre' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving listing…' : 'Save listing'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Text(
              'Listing details',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryCode,
              decoration: const InputDecoration(labelText: 'Store category'),
              items: [
                for (final category in StoreProductCategory.all)
                  DropdownMenuItem(
                    value: category.code,
                    child: Text(category.label),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _categoryCode = value;
                        if (_isFabric) {
                          _minimumQuantity.text =
                              _minimumQuantity.text.trim().isEmpty ? '1' : _minimumQuantity.text;
                        }
                      });
                    },
            ),
            const SizedBox(height: 12),
            _field(_name, 'Product name', validator: _requiredText),
            const SizedBox(height: 12),
            _field(
              _subcategory,
              _isFabric ? 'Fabric type / subcategory' : 'Subcategory',
              hint: _isFabric ? 'For example, Banarasi silk' : 'For example, Kurti',
              validator: _requiredText,
            ),
            const SizedBox(height: 12),
            _field(
              _brandName,
              'Brand or collection name',
              hint: 'Optional if this is your boutique label',
            ),
            const SizedBox(height: 12),
            _field(
              _description,
              'Description',
              maxLines: 4,
              validator: _requiredText,
            ),
            const SizedBox(height: 20),
            Text('Price and availability', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _price,
                    _isFabric ? 'MRP per metre (₹)' : 'MRP per piece (₹)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _discountPrice,
                    'Sale price (₹)',
                    hint: 'Optional',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validDiscount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _stock,
                    _isFabric ? 'Available metres' : 'Stock quantity',
                    keyboardType: TextInputType.number,
                    validator: _validStock,
                  ),
                ),
                if (_isFabric) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _minimumQuantity,
                      'Minimum metres',
                      keyboardType: TextInputType.number,
                      validator: _validMinimumQuantity,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_isFabric) ...[
              _field(_composition, 'Fabric composition'),
              const SizedBox(height: 12),
              _field(_width, 'Fabric width', hint: 'For example, 112 cm'),
              const SizedBox(height: 12),
            ] else ...[
              _field(_sizes, 'Sizes', hint: 'Comma separated, e.g. S, M, L'),
              const SizedBox(height: 12),
            ],
            _field(_colors, 'Colours', hint: 'Comma separated'),
            const SizedBox(height: 20),
            Text('Product photos', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              _isFabric
                  ? 'Add clear fabric photos, including the reverse, texture '
                      'and border where available. These views can support a '
                      'future 360° product experience.'
                  : 'Add clear product photos from the front, back and sides. '
                      'These views can support a future 360° product experience.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _photoViews.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.22,
              ),
              itemBuilder: (context, index) {
                final (view, label) = _photoViews[index];
                return _PhotoSlot(
                  label: label,
                  requiredPhoto: view == 'front',
                  selectedFile: _newImages[view],
                  existingUrl: _existingPhotoUrl(view),
                  onTap: () => _pickPhoto(view),
                );
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Listing status'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(
                  value: 'published',
                  child: Text('Published in my store'),
                ),
                DropdownMenuItem(value: 'paused', child: Text('Paused')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value ?? 'draft'),
            ),
            const SizedBox(height: 8),
            Text(
              'You can edit, publish or pause this listing from Store Listings.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  String? _existingPhotoUrl(String view) {
    for (final image in widget.product?.images ?? const <StoreProductImage>[]) {
      if (image.view == view) return image.url;
    }
    return null;
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.requiredPhoto,
    required this.selectedFile,
    required this.existingUrl,
    required this.onTap,
  });

  final String label;
  final bool requiredPhoto;
  final XFile? selectedFile;
  final String? existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = selectedFile != null || (existingUrl?.isNotEmpty ?? false);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (selectedFile != null)
                Image.file(File(selectedFile!.path), fit: BoxFit.cover)
              else if (existingUrl?.isNotEmpty == true)
                Image.network(
                  existingUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _placeholder(),
                )
              else
                _placeholder(),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.58),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$label${requiredPhoto ? ' · required' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        hasPhoto ? Icons.edit_outlined : Icons.add_a_photo_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.primary.withValues(alpha: 0.07),
    child: const Center(
      child: Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'published' => ('Published', const Color(0xFF21815B)),
      'paused' => ('Paused', const Color(0xFFB66C1A)),
      _ => ('Draft', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.titleMedium),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}
