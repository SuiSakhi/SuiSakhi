import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CustomerFabricPreviewSelection {
  const CustomerFabricPreviewSelection({
    required this.fabricPhoto,
    required this.previewBytes,
    required this.previewMimeType,
    required this.previewViewType,
    required this.designId,
    required this.catalogueVersionId,
    this.additionalPreviews = const [],
  });

  final XFile fabricPhoto;
  final Uint8List previewBytes;
  final String previewMimeType;
  final String previewViewType;
  final String designId;
  final String catalogueVersionId;
  final List<CustomerFabricViewPreview> additionalPreviews;

  List<CustomerFabricViewPreview> get previews => [
    CustomerFabricViewPreview(
      bytes: previewBytes,
      mimeType: previewMimeType,
      viewType: previewViewType,
    ),
    ...additionalPreviews,
  ];
}

class CustomerFabricViewPreview {
  const CustomerFabricViewPreview({
    required this.bytes,
    required this.mimeType,
    required this.viewType,
  });

  final Uint8List bytes;
  final String mimeType;
  final String viewType;
}

class CustomerFabricAssetService {
  CustomerFabricAssetService._();

  static Future<Map<String, dynamic>> uploadSelection({
    required String customerUid,
    required String scopeType,
    required String scopeId,
    required CustomerFabricPreviewSelection selection,
  }) async {
    if (!['orders', 'drafts', 'wishlists'].contains(scopeType)) {
      throw ArgumentError.value(scopeType, 'scopeType');
    }
    final originalBytes = await selection.fabricPhoto.readAsBytes();
    final previews = selection.previews;
    if (originalBytes.isEmpty ||
        previews.any((preview) => preview.bytes.isEmpty)) {
      throw StateError('The fabric photo and selected preview are required.');
    }
    final assetId = DateTime.now().microsecondsSinceEpoch.toString();
    final root = FirebaseStorage.instance.ref().child(
      'customer_fabrics/$customerUid/$scopeType/$scopeId/$assetId',
    );
    final photoType = selection.fabricPhoto.mimeType ?? 'image/jpeg';
    final photoExt = photoType == 'image/png' ? 'png' : 'jpg';
    final photoRef = root.child('fabric_photo.$photoExt');

    await photoRef.putData(
      originalBytes,
      SettableMetadata(
        contentType: photoType,
        customMetadata: {
          'assetRole': 'customerFabricPhoto',
          'designId': selection.designId,
          'catalogueVersionId': selection.catalogueVersionId,
        },
      ),
    );
    final previewAssets = <Map<String, dynamic>>[];
    try {
      for (var index = 0; index < previews.length; index++) {
        final preview = previews[index];
        final extension = preview.mimeType == 'image/jpeg' ? 'jpg' : 'png';
        final view = _safeViewName(preview.viewType, index);
        final previewRef = root.child('selected_preview_$view.$extension');
        await previewRef.putData(
          preview.bytes,
          SettableMetadata(
            contentType: preview.mimeType,
            customMetadata: {
              'assetRole': 'selectedFabricPreview',
              'designId': selection.designId,
              'catalogueVersionId': selection.catalogueVersionId,
              'viewType': preview.viewType,
            },
          ),
        );
        previewAssets.add({
          'storagePath': previewRef.fullPath,
          'contentType': preview.mimeType,
          'byteSize': preview.bytes.length,
          'viewType': preview.viewType,
        });
      }
    } catch (_) {
      await deleteAssets({
        'fabricPhoto': {'storagePath': photoRef.fullPath},
        'previews': previewAssets,
      });
      rethrow;
    }
    final firstPreview = previewAssets.first;
    return {
      'fabricPhoto': {
        'storagePath': photoRef.fullPath,
        'contentType': photoType,
        'byteSize': originalBytes.length,
      },
      'selectedPreview': firstPreview,
      'previews': previewAssets,
      'designId': selection.designId,
      'catalogueVersionId': selection.catalogueVersionId,
      'assetId': assetId,
    };
  }

  /// Copies a customer's saved Wishlist reference into this order's private
  /// Storage scope so an assigned Tailor can read it through order access.
  /// Firestore receives only Storage paths and image metadata.
  static Future<Map<String, dynamic>> copySavedSelectionToOrder({
    required String customerUid,
    required String orderId,
    required Map<String, dynamic> savedAssets,
  }) async {
    final rawPhoto = savedAssets['fabricPhoto'];
    final photo = rawPhoto is Map
        ? Map<String, dynamic>.from(rawPhoto)
        : const <String, dynamic>{};
    final rawPreviews = savedAssets['previews'];
    final previews = rawPreviews is Iterable
        ? rawPreviews
              .whereType<Map>()
              .map((asset) => Map<String, dynamic>.from(asset))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final photoPath = photo['storagePath']?.toString().trim() ?? '';
    if (photoPath.isEmpty && previews.isEmpty) {
      throw StateError('The saved Wishlist item has no fabric references.');
    }
    final wishlistItemId = savedAssets['wishlistItemId']?.toString().trim() ?? '';
    final expectedPrefix =
        'customer_fabrics/$customerUid/wishlists/$wishlistItemId/';
    final sourcePaths = [
      if (photoPath.isNotEmpty) photoPath,
      ...previews.map((asset) => asset['storagePath']?.toString() ?? ''),
    ];
    if (wishlistItemId.isEmpty ||
        sourcePaths.any(
          (path) => path.isEmpty || !path.startsWith(expectedPrefix),
        )) {
      throw StateError('The saved Wishlist references are invalid.');
    }

    final assetId = DateTime.now().microsecondsSinceEpoch.toString();
    final root = FirebaseStorage.instance.ref().child(
      'customer_fabrics/$customerUid/orders/$orderId/$assetId',
    );
    final uploadedPaths = <String>[];
    Map<String, dynamic>? copiedPhoto;
    final copiedPreviews = <Map<String, dynamic>>[];
    try {
      if (photoPath.isNotEmpty) {
        final source = FirebaseStorage.instance.ref(photoPath);
        final bytes = await source.getData(10 * 1024 * 1024);
        if (bytes == null || bytes.isEmpty) {
          throw StateError('The saved fabric photo could not be read.');
        }
        String contentType = photo['contentType']?.toString() ?? '';
        if (contentType.isEmpty) {
          contentType = (await source.getMetadata()).contentType ?? 'image/jpeg';
        }
        final extension = contentType == 'image/png' ? 'png' : 'jpg';
        final target = root.child('fabric_photo.$extension');
        await target.putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'assetRole': 'customerFabricPhoto',
              'sourceWishlistItemId':
                  savedAssets['wishlistItemId']?.toString() ?? '',
            },
          ),
        );
        uploadedPaths.add(target.fullPath);
        copiedPhoto = {
          'storagePath': target.fullPath,
          'contentType': contentType,
          'byteSize': bytes.length,
        };
      }

      for (var index = 0; index < previews.length; index++) {
        final preview = previews[index];
        final path = preview['storagePath']?.toString().trim() ?? '';
        if (path.isEmpty) continue;
        final source = FirebaseStorage.instance.ref(path);
        final bytes = await source.getData(10 * 1024 * 1024);
        if (bytes == null || bytes.isEmpty) {
          throw StateError('A saved fabric preview could not be read.');
        }
        final contentType = preview['contentType']?.toString() ??
            (await source.getMetadata()).contentType ??
            'image/png';
        final extension = contentType == 'image/jpeg' ? 'jpg' : 'png';
        final viewType = preview['viewType']?.toString() ?? 'view_${index + 1}';
        final target = root.child(
          'selected_preview_${_safeViewName(viewType, index)}.$extension',
        );
        await target.putData(
          bytes,
          SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'assetRole': 'selectedFabricPreview',
              'designId': savedAssets['designId']?.toString() ?? '',
              'catalogueVersionId':
                  savedAssets['catalogueVersionId']?.toString() ?? '',
              'viewType': viewType,
              'sourceWishlistItemId':
                  savedAssets['wishlistItemId']?.toString() ?? '',
            },
          ),
        );
        uploadedPaths.add(target.fullPath);
        copiedPreviews.add({
          'storagePath': target.fullPath,
          'contentType': contentType,
          'byteSize': bytes.length,
          'viewType': viewType,
        });
      }
    } catch (_) {
      for (final path in uploadedPaths) {
        await FirebaseStorage.instance.ref(path).delete().catchError((_) {});
      }
      rethrow;
    }

    final selectedPreview = copiedPreviews.isEmpty
        ? null
        : copiedPreviews.first;
    return {
      'designId': savedAssets['designId'],
      'catalogueVersionId': savedAssets['catalogueVersionId'],
      'source': 'customerWishlist',
      'sourceWishlistItemId': savedAssets['wishlistItemId'],
      'fabricPhoto': ?copiedPhoto,
      'selectedPreview': ?selectedPreview,
      if (copiedPreviews.isNotEmpty) 'previews': copiedPreviews,
      'assetId': assetId,
    };
  }

  static Future<void> deleteAssets(Map<String, dynamic>? assets) async {
    if (assets == null) return;
    final paths = <String>{};
    for (final key in ['fabricPhoto', 'selectedPreview']) {
      final item = assets[key];
      if (item is Map && item['storagePath'] is String) {
        paths.add(item['storagePath'].toString());
      }
    }
    final previews = assets['previews'];
    if (previews is Iterable) {
      for (final item in previews) {
        if (item is Map && item['storagePath'] is String) {
          paths.add(item['storagePath'].toString());
        }
      }
    }
    for (final path in paths) {
      await FirebaseStorage.instance.ref(path).delete().catchError((_) {});
    }
  }

  static Future<String> downloadUrl(String storagePath) =>
      FirebaseStorage.instance.ref(storagePath).getDownloadURL();

  static String _safeViewName(String viewType, int index) {
    final normalized = viewType.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    return normalized.isEmpty ? 'view_${index + 1}' : normalized;
  }
}
