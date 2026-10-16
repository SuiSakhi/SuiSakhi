import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/customer_fabric_asset_service.dart';

/// Shows the customer's saved fabric previews alongside the unchanged
/// monochrome catalogue image used as the tailor's construction reference.
class OrderDesignReferences extends StatefulWidget {
  const OrderDesignReferences({
    super.key,
    required this.customerPreviews,
    this.originalCatalogueImageUrl,
  });

  final List<Map<String, dynamic>> customerPreviews;
  final String? originalCatalogueImageUrl;

  @override
  State<OrderDesignReferences> createState() => _OrderDesignReferencesState();
}

class _OrderDesignReferencesState extends State<OrderDesignReferences> {
  late Future<List<_ResolvedCustomerPreview>> _resolvedPreviews;
  late String _sourceKey;

  String get _currentSourceKey => [
    widget.originalCatalogueImageUrl ?? '',
    for (final preview in widget.customerPreviews)
      '${preview['storagePath'] ?? ''}:${preview['viewType'] ?? ''}',
  ].join('|');

  @override
  void initState() {
    super.initState();
    _sourceKey = _currentSourceKey;
    _resolvedPreviews = _resolvePreviews();
  }

  @override
  void didUpdateWidget(covariant OrderDesignReferences oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextKey = _currentSourceKey;
    if (nextKey != _sourceKey) {
      _sourceKey = nextKey;
      _resolvedPreviews = _resolvePreviews();
    }
  }

  Future<List<_ResolvedCustomerPreview>> _resolvePreviews() async {
    final resolved = <_ResolvedCustomerPreview>[];
    for (final preview in widget.customerPreviews) {
      final path = preview['storagePath']?.toString().trim() ?? '';
      if (path.isEmpty) continue;
      try {
        resolved.add(
          _ResolvedCustomerPreview(
            url: await CustomerFabricAssetService.downloadUrl(path),
            viewType: preview['viewType']?.toString() ?? 'view',
          ),
        );
      } catch (_) {
        resolved.add(
          _ResolvedCustomerPreview(
            url: null,
            viewType: preview['viewType']?.toString() ?? 'view',
          ),
        );
      }
    }
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    final originalUrl = widget.originalCatalogueImageUrl?.trim() ?? '';
    if (widget.customerPreviews.isEmpty && originalUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<_ResolvedCustomerPreview>>(
      future: _resolvedPreviews,
      builder: (context, snapshot) {
        final previews = snapshot.data ?? const <_ResolvedCustomerPreview>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previews.isNotEmpty) ...[
              Text(
                'Customer-selected design',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: AppColors.background,
                  child: PageView.builder(
                    itemCount: previews.length,
                    itemBuilder: (context, index) {
                      final preview = previews[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (preview.url != null)
                            Image.network(
                              preview.url!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Text(
                                      'Saved customer preview unavailable',
                                    ),
                                  ),
                            )
                          else
                            const Center(
                              child: Text(
                                'Saved customer preview unavailable',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              color: Colors.white.withValues(alpha: 0.88),
                              child: Text(
                                _viewLabel(preview.viewType),
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (previews.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Swipe to view front and back',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ),
            ] else if (widget.customerPreviews.isNotEmpty &&
                snapshot.connectionState != ConnectionState.done) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 8),
            ],
            if (originalUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      originalUrl,
                      width: 54,
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Original monochrome catalogue design · tailor construction reference',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  String _viewLabel(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Design preview';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _ResolvedCustomerPreview {
  const _ResolvedCustomerPreview({required this.url, required this.viewType});

  final String? url;
  final String viewType;
}
