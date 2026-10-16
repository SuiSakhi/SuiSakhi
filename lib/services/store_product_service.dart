import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../models/store_product.dart';
import 'firebase_storage_helpers.dart';

class StoreProductService {
  StoreProductService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    app: Firebase.app(),
  );

  static CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('store_products');

  static Stream<List<StoreProduct>> watchPartnerProducts({
    required String accountId,
    required String profileId,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.error(StateError('Sign in to view store listings.'));
    }
    return _products
        .where('partnerAccountId', isEqualTo: accountId)
        .where('partnerProfileId', isEqualTo: profileId)
        .where('createdByUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs.map(StoreProduct.fromDoc).toList();
          products.sort((a, b) {
            final aTime = a.updatedAt ?? a.createdAt;
            final bTime = b.updatedAt ?? b.createdAt;
            return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              aTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            );
          });
          return products;
        });
  }

  static Stream<List<StoreProduct>> watchPublishedProducts({
    String? categoryCode,
  }) {
    Query<Map<String, dynamic>> query = _products.where(
      'status',
      isEqualTo: 'published',
    );
    final category = categoryCode?.trim();
    if (category != null && category.isNotEmpty) {
      query = query.where('categoryCode', isEqualTo: category);
    }
    return query.limit(100).snapshots().map((snapshot) {
      final products = snapshot.docs.map(StoreProduct.fromDoc).toList();
      products.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          aTime ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
      return products;
    });
  }

  static Future<String> saveProduct({
    required StoreProduct product,
    required String accountId,
    required String profileId,
    required Map<String, XFile> newImagesByView,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in to manage store listings.');
    }
    final ref = product.productId.isEmpty
        ? _products.doc()
        : _products.doc(product.productId);
    final imagesByView = <String, StoreProductImage>{
      for (final image in product.images) image.view: image,
    };

    for (final entry in newImagesByView.entries) {
      final file = entry.value;
      final ext = FirebaseStorageHelpers.imageFileExt(
        file.path.isNotEmpty ? file.path : '${entry.key}.jpg',
      );
      final fileName = '${entry.key}_${DateTime.now().microsecondsSinceEpoch}.$ext';
      final storageRef = _storage.ref(
        'fashion_store_products/$accountId/$profileId/${ref.id}/$fileName',
      );
      File? ioFile;
      if (!kIsWeb && file.path.isNotEmpty) {
        final candidate = File(file.path);
        if (await candidate.exists() && await candidate.length() > 0) {
          ioFile = candidate;
        }
      }
      final url = await FirebaseStorageHelpers.putImageGetDownloadUrl(
        ref: storageRef,
        file: ioFile,
        bytes: ioFile == null ? await file.readAsBytes() : null,
        contentType: FirebaseStorageHelpers.imageContentType(
          mimeType: file.mimeType,
          path: file.path,
        ),
        customMetadata: {'ownerUid': user.uid},
      );
      if (url == null || url.isEmpty) {
        throw StateError('Could not upload the ${entry.key} product photo.');
      }
      imagesByView[entry.key] = StoreProductImage(view: entry.key, url: url);
    }

    final savedProduct = StoreProduct(
      productId: ref.id,
      partnerAccountId: accountId,
      partnerProfileId: profileId,
      partnerType: product.partnerType,
      sellerName: product.sellerName,
      name: product.name,
      description: product.description,
      categoryCode: product.categoryCode,
      subcategory: product.subcategory,
      priceInr: product.priceInr,
      discountPriceInr: product.discountPriceInr,
      stockQuantity: product.stockQuantity,
      status: product.status,
      brandName: product.brandName,
      unit: product.unit,
      fabricComposition: product.fabricComposition,
      fabricWidth: product.fabricWidth,
      minimumQuantity: product.minimumQuantity,
      sizes: product.sizes,
      colors: product.colors,
      images: imagesByView.values.toList(growable: false),
    );
    final exists = product.productId.isNotEmpty;
    await ref.set({
      ...savedProduct.toFields(),
      'createdByUid': user.uid,
      'createdAt': exists && product.createdAt != null
          ? Timestamp.fromDate(product.createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> updateStatus({
    required String productId,
    required String status,
  }) async {
    if (!const {'draft', 'published', 'paused'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await _products.doc(productId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
