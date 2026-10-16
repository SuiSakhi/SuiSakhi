import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_version.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/customer_fabric_asset_service.dart';
import '../../services/customer_wishlist_service.dart';

class CustomerWishlistScreen extends StatelessWidget {
  const CustomerWishlistScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('My wishlist')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Saved designs stay here until you remove them.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: CustomerWishlistService.watchItems(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load your saved designs.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Designs you save will appear here.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final fabricMetadata = data['fabricMetadata'];
                  final rawPreviews = fabricMetadata is Map
                      ? fabricMetadata['previews']
                      : null;
                  final fabricPreviewAssets = rawPreviews is Iterable
                      ? rawPreviews
                            .whereType<Map>()
                            .map(
                              (preview) => Map<String, dynamic>.from(preview),
                            )
                            .toList(growable: false)
                      : const <Map<String, dynamic>>[];
                  return _WishlistDesignTile(
                    itemId: doc.id,
                    designId: data['designId']?.toString() ?? doc.id,
                    versionId: data['catalogueVersionId']?.toString() ?? '',
                    fabricPhotoPath: data['fabricPhotoStoragePath']?.toString(),
                    fabricPreviewPath: data['fabricPreviewStoragePath']
                        ?.toString(),
                    fabricPreviewAssets: fabricPreviewAssets,
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _WishlistDesignTile extends StatelessWidget {
  const _WishlistDesignTile({
    required this.itemId,
    required this.designId,
    required this.versionId,
    this.fabricPhotoPath,
    this.fabricPreviewPath,
    this.fabricPreviewAssets = const [],
  });

  final String itemId;
  final String designId;
  final String versionId;
  final String? fabricPhotoPath;
  final String? fabricPreviewPath;
  final List<Map<String, dynamic>> fabricPreviewAssets;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _loadDesign(),
    builder: (context, snapshot) {
      final data = snapshot.data ?? const <String, dynamic>{};
      final title = data['title']?.toString() ?? 'Saved design';
      final published = data['published'] == true;
      final preview = data['fabricPreview']?.toString() ?? '';
      final fabricPreviews =
          (data['fabricPreviews'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((preview) => Map<String, dynamic>.from(preview))
              .toList(growable: false);
      final catalogueImage = data['catalogueImage']?.toString() ?? '';
      final fabricPhoto = data['fabricPhoto']?.toString() ?? '';
      final thumbnail = preview.isNotEmpty ? preview : catalogueImage;
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: thumbnail.isEmpty
              ? const Icon(Icons.checkroom_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnail,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
          title: Text(title),
          subtitle: Text(
            snapshot.connectionState == ConnectionState.waiting
                ? 'Loading saved design…'
                : fabricPreviews.length > 1
                ? 'Front and back fabric previews saved · Tap to view'
                : preview.isNotEmpty
                ? 'Fabric preview saved · Tap to view'
                : published
                ? 'Saved design'
                : 'Saved reference; catalogue design is no longer available.',
          ),
          trailing: IconButton(
            tooltip: 'Remove from wishlist',
            onPressed: () => CustomerWishlistService.remove(
              itemId,
              fabricPhotoStoragePath: fabricPhotoPath,
              fabricPreviewStoragePath: fabricPreviewPath,
              fabricPreviews: fabricPreviewAssets,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          onTap: preview.isNotEmpty || fabricPhoto.isNotEmpty
              ? () => _showFabricReference(
                  context,
                  title: title,
                  previewUrl: preview,
                  previewViews: fabricPreviews,
                  fabricUrl: fabricPhoto,
                  versionId: versionId,
                )
              : published
              ? () => context.push('/smart-style-ideas')
              : null,
        ),
      );
    },
  );

  Future<Map<String, dynamic>> _loadDesign() async {
    final document = await FirebaseFirestore.instance
        .collection('designs')
        .doc(designId)
        .get();
    var catalogueImage = '';
    var title = 'Saved design';
    var published = false;
    if (document.exists) {
      final design = CatalogueDesign.fromDoc(document);
      title = design.title;
      published = design.isPublished;
      if (design.isPublished && versionId.isNotEmpty) {
        final versionRef = FirebaseFirestore.instance
            .collection('designs')
            .doc(designId)
            .collection('versions')
            .doc(versionId);
        final versionSnapshot = await versionRef.get();
        if (versionSnapshot.exists) {
          final version = CatalogueDesignVersion.fromMap({
            ...versionSnapshot.data()!,
            'designId': designId,
            'versionId': versionId,
          });
          final viewSnapshot = await versionRef
              .collection('views')
              .orderBy('displayOrder')
              .get();
          final views = viewSnapshot.docs
              .where((view) => view.data()['excludedFromVersion'] != true)
              .map((view) => CatalogueDesignView.fromMap(view.data()))
              .toList();
          if (views.isNotEmpty) {
            final primary = views.where(
              (view) => view.viewId == version.primaryViewId || view.isPrimary,
            );
            catalogueImage =
                (primary.isEmpty ? views.first : primary.first)
                    .bestPreviewUrl ??
                '';
          } else {
            catalogueImage = version.legacyView?.bestPreviewUrl ?? '';
          }
        }
      }
    }
    final previewAssets = fabricPreviewAssets.isNotEmpty
        ? fabricPreviewAssets
        : fabricPreviewPath == null
        ? const <Map<String, dynamic>>[]
        : [
            {'storagePath': fabricPreviewPath, 'viewType': 'front'},
          ];
    final downloadedPreviews = <Map<String, dynamic>>[];
    for (final asset in previewAssets) {
      final url = await _download(asset['storagePath']?.toString());
      if (url.isNotEmpty) {
        downloadedPreviews.add({
          'url': url,
          'viewType': asset['viewType']?.toString() ?? 'garment',
        });
      }
    }
    return {
      'title': title,
      'published': published,
      'catalogueImage': catalogueImage,
      'fabricPreviews': downloadedPreviews,
      'fabricPreview': downloadedPreviews.isEmpty
          ? ''
          : downloadedPreviews.first['url'] ?? '',
      'fabricPhoto': await _download(fabricPhotoPath),
    };
  }

  Future<String> _download(String? path) async {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return '';
    try {
      return await CustomerFabricAssetService.downloadUrl(value);
    } catch (_) {
      return '';
    }
  }

  void _showFabricReference(
    BuildContext context, {
    required String title,
    required String previewUrl,
    required List<Map<String, dynamic>> previewViews,
    required String fabricUrl,
    required String versionId,
  }) {
    final references = <({String label, String url})>[
      for (final preview in previewViews)
        if (preview['url']?.toString().isNotEmpty == true)
          (
            label:
                'Design in your fabric · ${_viewLabel(preview['viewType']?.toString())}',
            url: preview['url'].toString(),
          ),
      if (previewViews.isEmpty && previewUrl.isNotEmpty)
        (label: 'Design in your fabric · AI preview', url: previewUrl),
      if (fabricUrl.isNotEmpty) (label: 'Your fabric photo', url: fabricUrl),
    ];
    if (references.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text('Saved catalogue version $versionId'),
                  const SizedBox(height: 4),
                  const Text(
                    'Your saved fabric comparison is available here as a design reference.',
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                itemCount: references.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      Text(references[index].label),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Image.network(
                          references[index].url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 44),
                          ),
                        ),
                      ),
                      if (references.length > 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Swipe to compare front, back and fabric photo',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _viewLabel(String? viewType) {
    final normalized = (viewType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'AI preview';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)} view';
  }
}
