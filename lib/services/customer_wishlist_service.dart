import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'customer_fabric_asset_service.dart';

class CustomerWishlistService {
  CustomerWishlistService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _items() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('customer_wishlists').doc(uid).collection('items');
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchItems() {
    final items = _items();
    if (items == null) return const Stream.empty();
    return items.orderBy('savedAt', descending: true).snapshots();
  }

  static Future<void> saveDesign({
    required String designId,
    required String catalogueVersionId,
    CustomerFabricPreviewSelection? fabricPreviewSelection,
  }) async {
    final items = _items();
    if (items == null) throw StateError('Sign in to save a design.');
    final design = designId.trim();
    final version = catalogueVersionId.trim();
    if (design.isEmpty || version.isEmpty) {
      throw ArgumentError('A published design version is required.');
    }
    // Keep a plain saved design stable, but give every fabric trial its own
    // wishlist record so comparing fabrics never replaces an earlier preview.
    final item = fabricPreviewSelection == null
        ? items.doc(design)
        : items.doc();
    Map<String, dynamic>? assets;
    if (fabricPreviewSelection != null &&
        fabricPreviewSelection.designId == design &&
        fabricPreviewSelection.catalogueVersionId == version) {
      assets = await CustomerFabricAssetService.uploadSelection(
        customerUid: _uid!,
        scopeType: 'wishlists',
        scopeId: item.id,
        selection: fabricPreviewSelection,
      );
    }
    try {
      await item.set({
        'designId': design,
        'catalogueVersionId': version,
        if (assets != null) ...{
          'fabricPhotoStoragePath':
              (assets['fabricPhoto'] as Map)['storagePath'],
          'fabricPreviewStoragePath':
              (assets['selectedPreview'] as Map)['storagePath'],
          'fabricMetadata': {
            'designId': design,
            'catalogueVersionId': version,
            'viewType': (assets['selectedPreview'] as Map)['viewType'],
            'previews': (assets['previews'] as List)
                .map((preview) => Map<String, dynamic>.from(preview as Map))
                .toList(growable: false),
          },
        },
        'savedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      await CustomerFabricAssetService.deleteAssets(assets);
      rethrow;
    }
  }

  static Future<void> remove(
    String itemId, {
    String? fabricPhotoStoragePath,
    String? fabricPreviewStoragePath,
    List<Map<String, dynamic>> fabricPreviews = const [],
  }) async {
    final items = _items();
    if (items == null) return;
    await items.doc(itemId).delete();
    await CustomerFabricAssetService.deleteAssets({
      'fabricPhoto': {'storagePath': fabricPhotoStoragePath},
      'selectedPreview': {'storagePath': fabricPreviewStoragePath},
      'previews': fabricPreviews,
    });
  }
}
