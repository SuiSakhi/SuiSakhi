import 'dart:io' show File;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../models/catalogue_agreement.dart';
import '../models/catalogue_design.dart';
import '../models/catalogue_design_asset.dart';
import '../models/catalogue_design_version.dart';
import '../models/catalogue_processing_status.dart';
import 'catalogue_upload_policy.dart';
import 'firebase_storage_helpers.dart';

class CatalogueDesignService {
  CatalogueDesignService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    app: Firebase.app(),
  );

  static CollectionReference<Map<String, dynamic>> get _designs =>
      _db.collection('designs');

  static Stream<List<CatalogueDesign>> watchPublishedDesigns({
    String? garmentTypeCode,
    String? occasionCode,
  }) {
    Query<Map<String, dynamic>> query = _designs
        .where('lifecycleStatus', isEqualTo: 'approved')
        .where('publicationStatus', isEqualTo: 'published');

    final garment = garmentTypeCode?.trim() ?? '';
    if (garment.isNotEmpty) {
      query = query.where('garmentTypeCodes', arrayContains: garment);
    }

    return query.snapshots().map((snapshot) {
      final designs = snapshot.docs.map(CatalogueDesign.fromDoc).toList();
      final occasion = occasionCode?.trim() ?? '';
      if (occasion.isEmpty) return designs;
      return designs
          .where((design) => design.occasionCodes.contains(occasion))
          .toList();
    });
  }

  static Stream<List<CatalogueDesign>> watchMySubmissions() {
    final uid = _requireUid();
    return _designs
        .where('submittedByUid', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(CatalogueDesign.fromDoc).toList()..sort(
                (a, b) =>
                    (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                        .compareTo(
                          a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                        ),
              ),
        );
  }

  static Future<String> createDraft({
    required CatalogueDesignOwnerType ownerType,
    required String title,
    required CatalogueDesignCommercial commercial,
    String? ownerProfileId,
    String? description,
    List<String> garmentTypeCodes = const [],
    List<String> occasionCodes = const [],
    List<String> styleCodes = const [],
    List<String> fabricCompatibilityCodes = const [],
    CatalogueAgreementAcceptance? catalogueAgreement,
    CatalogueRightsDeclaration? rightsDeclaration,
  }) async {
    final uid = _requireUid();
    final doc = _designs.doc();
    final design = CatalogueDesign(
      designId: doc.id,
      ownerType: ownerType,
      submittedByUid: uid,
      ownerProfileId: ownerProfileId,
      title: title.trim().isEmpty ? 'Untitled Design' : title.trim(),
      description: description,
      garmentTypeCodes: garmentTypeCodes,
      occasionCodes: occasionCodes,
      styleCodes: styleCodes,
      fabricCompatibilityCodes: fabricCompatibilityCodes,
      commercial: commercial,
      catalogueAgreement: catalogueAgreement,
      rightsDeclaration: rightsDeclaration,
      lifecycleStatus: CatalogueDesignLifecycleStatus.draft,
      publicationStatus: CataloguePublicationStatus.unpublished,
    );

    final payload = design.toMap()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await doc.set(payload);
    return doc.id;
  }

  static Future<CatalogueDesignVersion> uploadOriginal({
    required String designId,
    required XFile file,
  }) async {
    final uid = _requireUid();
    final validation = await CatalogueUploadPolicy.validate(file);
    if (!validation.accepted) {
      throw StateError(validation.errorMessage ?? 'Catalogue upload rejected.');
    }

    final designRef = _designs.doc(designId.trim());
    final versionRef = designRef.collection('versions').doc();
    final versionId = versionRef.id;
    final extension = validation.extension!;
    final storagePath =
        'catalogue_designs/$designId/versions/$versionId/original/source.$extension';
    final storageRef = _storage.ref(storagePath);

    File? ioFile;
    if (!kIsWeb && file.path.isNotEmpty) {
      final candidate = File(file.path);
      if (await candidate.exists() && await candidate.length() > 0) {
        ioFile = candidate;
      }
    }

    Uint8List? bytes;
    if (ioFile == null) {
      bytes = Uint8List.fromList(await file.readAsBytes());
    }

    String? downloadUrl;
    try {
      downloadUrl = await FirebaseStorageHelpers.putImageGetDownloadUrl(
        ref: storageRef,
        file: ioFile,
        bytes: bytes,
        contentType: validation.contentType!,
      );
      if (downloadUrl == null) {
        throw StateError('The original Catalogue asset could not be uploaded.');
      }

      final version = CatalogueDesignVersion(
        versionId: versionId,
        designId: designId,
        versionNumber: await _nextVersionNumber(designRef),
        originalAsset: CatalogueDesignAsset(
          assetType: CatalogueAssetType.original,
          storagePath: storagePath,
          downloadUrl: downloadUrl,
          mimeType: validation.contentType!,
          byteSize: validation.byteSize!,
          createdAt: DateTime.now(),
        ),
        processing: const CatalogueProcessingResult(
          status: CatalogueProcessingStatus.queued,
          missingLayers: CatalogueSvgLayer.values,
        ),
        submittedByUid: uid,
        submittedAt: DateTime.now(),
      );

      final batch = _db.batch();
      batch.set(
        versionRef,
        version.toMap()
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['updatedAt'] = FieldValue.serverTimestamp(),
      );
      batch.update(designRef, {
        'activeVersionId': versionId,
        'lifecycleStatus': CatalogueDesignLifecycleStatus.uploaded.name,
        'processingStatus': CatalogueProcessingStatus.queued.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return version;
    } catch (_) {
      try {
        await storageRef.delete();
      } catch (_) {
        // Best-effort orphan cleanup. A backend audit job should also check.
      }
      rethrow;
    }
  }

  static Future<void> submitForReview(String designId) async {
    final uid = _requireUid();
    final ref = _designs.doc(designId.trim());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Catalogue design not found.');
      final design = CatalogueDesign.fromDoc(snapshot);
      if (design.submittedByUid != uid) {
        throw StateError('Only the submitting user can submit this design.');
      }
      if (design.activeVersionId == null) {
        throw StateError('Upload an original design asset before submission.');
      }
      if (design.ownerType == CatalogueDesignOwnerType.designer) {
        if (design.catalogueAgreement == null) {
          throw StateError('Accept the current Catalogue agreement first.');
        }
        if (design.rightsDeclaration?.isComplete != true) {
          throw StateError('Complete the per-design rights declaration first.');
        }
      }
      transaction.update(ref, {
        'lifecycleStatus': CatalogueDesignLifecycleStatus.readyForReview.name,
        'reviewNotes': null,
        'rejectionReason': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> markChangesRequested({
    required String designId,
    required String reviewNotes,
  }) async {
    final notes = reviewNotes.trim();
    if (notes.isEmpty) throw StateError('Review instructions are required.');
    await _designs.doc(designId.trim()).update({
      'lifecycleStatus': CatalogueDesignLifecycleStatus.changesRequested.name,
      'reviewNotes': notes,
      'rejectionReason': null,
      'reviewedByUid': _requireUid(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> approve({
    required String designId,
    double? approvedDesignCharge,
    String? commercialVersion,
  }) async {
    final ref = _designs.doc(designId.trim());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Catalogue design not found.');
      final design = CatalogueDesign.fromDoc(snapshot);
      final commercial = CatalogueDesignCommercial(
        commercialType: design.commercial.commercialType,
        currency: design.commercial.currency,
        designerExpectedPrice: design.commercial.designerExpectedPrice,
        approvedDesignCharge: approvedDesignCharge,
        royaltyRuleId: design.commercial.royaltyRuleId,
        commercialVersion: commercialVersion,
      );
      transaction.update(ref, {
        'commercial': commercial.toMap(),
        'lifecycleStatus': CatalogueDesignLifecycleStatus.approved.name,
        'reviewNotes': null,
        'rejectionReason': null,
        'reviewedByUid': _requireUid(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> reject({
    required String designId,
    required String reason,
  }) async {
    final normalized = reason.trim();
    if (normalized.length < 10) {
      throw StateError('Provide a clear rejection reason.');
    }
    await _designs.doc(designId.trim()).update({
      'lifecycleStatus': CatalogueDesignLifecycleStatus.rejected.name,
      'rejectionReason': normalized,
      'reviewNotes': null,
      'reviewedByUid': _requireUid(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> publish(String designId) async {
    final ref = _designs.doc(designId.trim());
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Catalogue design not found.');
      final design = CatalogueDesign.fromDoc(snapshot);
      if (design.lifecycleStatus != CatalogueDesignLifecycleStatus.approved) {
        throw StateError('Only an approved Catalogue design can be published.');
      }
      transaction.update(ref, {
        'publicationStatus': CataloguePublicationStatus.published.name,
        'publishedByUid': _requireUid(),
        'publishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> unpublish(String designId) async {
    await _designs.doc(designId.trim()).update({
      'publicationStatus': CataloguePublicationStatus.unpublished.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<int> _nextVersionNumber(
    DocumentReference<Map<String, dynamic>> designRef,
  ) async {
    final snapshot = await designRef
        .collection('versions')
        .orderBy('versionNumber', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return 1;
    final raw = snapshot.docs.first.data()['versionNumber'];
    final current = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    return current + 1;
  }

  static String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('A signed-in user is required.');
    }
    return uid;
  }
}
