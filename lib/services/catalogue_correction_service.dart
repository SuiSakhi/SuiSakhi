import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:image_picker/image_picker.dart';

import '../models/catalogue_design.dart';
import '../models/catalogue_design_version.dart';
import '../models/catalogue_design_view.dart';
import '../models/catalogue_processing_status.dart';
import '../models/catalogue_review_event.dart';
import 'catalogue_design_service.dart';

class CatalogueCorrectionDraft {
  const CatalogueCorrectionDraft({
    required this.designId,
    required this.sourceVersionId,
    required this.draftVersion,
    required this.inheritedViews,
  });

  final String designId;
  final String sourceVersionId;
  final CatalogueDesignVersion draftVersion;
  final List<CatalogueDesignView> inheritedViews;
}

class CatalogueCorrectionService {
  CatalogueCorrectionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> requestChanges({
    required String designId,
    required String reviewedVersionId,
    required CatalogueChangeRequestScope scope,
    required List<String> affectedViewIds,
    required String notes,
  }) async {
    final uid = _requireUid();
    final normalizedNotes = notes.trim();
    if (normalizedNotes.length < 5) {
      throw StateError('Provide clear correction instructions.');
    }
    if ((scope == CatalogueChangeRequestScope.views ||
            scope == CatalogueChangeRequestScope.mixed) &&
        affectedViewIds.isEmpty) {
      throw StateError('Select at least one affected Design View.');
    }

    final designRef = _db.collection('designs').doc(designId.trim());
    final eventRef = designRef.collection('review_events').doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(designRef);
      if (!snapshot.exists) throw StateError('Catalogue design not found.');
      final design = CatalogueDesign.fromDoc(snapshot);

      final event = CatalogueReviewEvent(
        eventId: eventRef.id,
        designId: design.designId,
        action: CatalogueReviewAction.requestChanges,
        sourceLifecycle: design.lifecycleStatus.name,
        targetLifecycle: CatalogueDesignLifecycleStatus.changesRequested.name,
        reviewedVersionId: reviewedVersionId.trim(),
        changeRequestScope: scope,
        affectedViewIds: affectedViewIds,
        notes: normalizedNotes,
        actorUid: uid,
        createdAt: DateTime.now(),
      );

      transaction.set(
        eventRef,
        event.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );
      transaction.update(designRef, {
        'lifecycleStatus': CatalogueDesignLifecycleStatus.changesRequested.name,
        'reviewedVersionId': reviewedVersionId.trim(),
        'latestReviewEventId': eventRef.id,
        'changeRequestScope': scope.name,
        'affectedViewIds': affectedViewIds,
        'reviewNotes': normalizedNotes,
        'rejectionReason': null,
        'reviewedByUid': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<CatalogueCorrectionDraft> createCorrectedVersion({
    required String designId,
    required CatalogueDesignVersion sourceVersion,
    required List<CatalogueDesignView> sourceViews,
    String? correctionReason,
  }) async {
    final uid = _requireUid();
    if (sourceViews.isEmpty) {
      throw StateError('The reviewed version has no Design Views.');
    }

    final normalizedDesignId = designId.trim();
    final designRef = _db.collection('designs').doc(normalizedDesignId);
    final destinationRef = designRef.collection('versions').doc();
    final nextNumber = await _nextVersionNumber(designRef);

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=version-create-start '
      'designId=$normalizedDesignId '
      'draftVersionId=${destinationRef.id} '
      'sourceVersionId=${sourceVersion.versionId} '
      'sourceViews=${sourceViews.length}',
    );

    final draftVersion = CatalogueDesignVersion(
      versionId: destinationRef.id,
      designId: normalizedDesignId,
      versionNumber: nextNumber,
      primaryViewId: null,
      viewCount: sourceViews.length,
      processing: const CatalogueProcessingResult(
        status: CatalogueProcessingStatus.notRequested,
      ),
      submittedByUid: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await destinationRef.set(
        draftVersion.toMap()
          ..['sourceVersionId'] = sourceVersion.versionId
          ..['versionStatus'] = 'draft'
          ..['correctionReason'] = _text(correctionReason)
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['updatedAt'] = FieldValue.serverTimestamp(),
      );
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=version-create-success '
        'draftVersionId=${destinationRef.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=version-create-failed '
        'draftVersionId=${destinationRef.id} '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    final inheritedViews = <CatalogueDesignView>[];
    String? inheritedPrimaryId;

    for (final sourceView in sourceViews) {
      final destinationViewRef = destinationRef.collection('views').doc();
      final inherited = CatalogueDesignView(
        viewId: destinationViewRef.id,
        designId: normalizedDesignId,
        versionId: destinationRef.id,
        viewType: sourceView.viewType,
        displayOrder: sourceView.displayOrder,
        isPrimary: sourceView.isPrimary,
        title: sourceView.title,
        originalAsset: sourceView.originalAsset,
        normalizedPreviewAsset: sourceView.normalizedPreviewAsset,
        structuredSvgAsset: sourceView.structuredSvgAsset,
        thumbnailAsset: sourceView.thumbnailAsset,
        processing: sourceView.processing,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=view-create-start '
        'draftVersionId=${destinationRef.id} '
        'viewId=${destinationViewRef.id} '
        'sourceViewId=${sourceView.viewId}',
      );

      try {
        await destinationViewRef.set(
          inherited.toMap()
            ..['sourceVersionId'] = sourceVersion.versionId
            ..['sourceViewId'] = sourceView.viewId
            ..['inherited'] = true
            ..['replacementReason'] = null
            ..['createdAt'] = FieldValue.serverTimestamp()
            ..['updatedAt'] = FieldValue.serverTimestamp(),
        );
        debugPrint(
          'CATALOGUE_CORRECTION_DEBUG '
          'stage=view-create-success '
          'viewId=${destinationViewRef.id}',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'CATALOGUE_CORRECTION_DEBUG '
          'stage=view-create-failed '
          'viewId=${destinationViewRef.id} '
          'error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }

      if (inherited.isPrimary) {
        inheritedPrimaryId = inherited.viewId;
      }
      inheritedViews.add(inherited);
    }

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=version-finalize-start '
      'draftVersionId=${destinationRef.id} '
      'primaryViewId=$inheritedPrimaryId',
    );
    try {
      await destinationRef.update({
        'primaryViewId': inheritedPrimaryId,
        'viewCount': inheritedViews.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=version-finalize-success '
        'draftVersionId=${destinationRef.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=version-finalize-failed '
        'draftVersionId=${destinationRef.id} '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=root-pointer-start '
      'designId=$normalizedDesignId '
      'draftVersionId=${destinationRef.id}',
    );
    try {
      await designRef.update({
        'correctionDraftVersionId': destinationRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=root-pointer-success '
        'designId=$normalizedDesignId '
        'draftVersionId=${destinationRef.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_CORRECTION_DEBUG '
        'stage=root-pointer-failed '
        'designId=$normalizedDesignId '
        'draftVersionId=${destinationRef.id} '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=correction-draft-ready '
      'draftVersionId=${destinationRef.id} '
      'inheritedViews=${inheritedViews.length}',
    );

    return CatalogueCorrectionDraft(
      designId: normalizedDesignId,
      sourceVersionId: sourceVersion.versionId,
      draftVersion: CatalogueDesignVersion(
        versionId: draftVersion.versionId,
        designId: draftVersion.designId,
        versionNumber: draftVersion.versionNumber,
        primaryViewId: inheritedPrimaryId,
        viewCount: inheritedViews.length,
        processing: draftVersion.processing,
        submittedByUid: draftVersion.submittedByUid,
        createdAt: draftVersion.createdAt,
        updatedAt: draftVersion.updatedAt,
      ),
      inheritedViews: inheritedViews,
    );
  }

  static Future<CatalogueCorrectionDraft> ensureCorrectionDraft({
    required CatalogueDesign design,
    required CatalogueDesignVersion sourceVersion,
    required List<CatalogueDesignView> sourceViews,
  }) async {
    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=ensure-start '
      'designId=${design.designId} '
      'sourceVersionId=${sourceVersion.versionId} '
      'lifecycle=${design.lifecycleStatus.name} '
      'ownerType=${design.ownerType.name} '
      'ownerAccountId=${design.ownerAccountId} '
      'ownerProfileId=${design.ownerProfileId} '
      'submittedByUid=${design.submittedByUid} '
      'sourceViews=${sourceViews.length}',
    );
    final designRef = _db.collection('designs').doc(design.designId);
    final designSnapshot = await designRef.get();
    final existingId =
        designSnapshot.data()?['correctionDraftVersionId']?.toString() ?? '';

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=correction-pointer '
      'existingId=$existingId',
    );

    if (existingId.isNotEmpty) {
      final versionDoc = await designRef
          .collection('versions')
          .doc(existingId)
          .get();
      if (versionDoc.exists && versionDoc.data()?['versionStatus'] == 'draft') {
        final viewDocs = await versionDoc.reference
            .collection('views')
            .orderBy('displayOrder')
            .get();
        final views = viewDocs.docs
            .where((doc) => doc.data()['excludedFromVersion'] != true)
            .map((doc) => CatalogueDesignView.fromMap(doc.data()))
            .toList(growable: false);
        return CatalogueCorrectionDraft(
          designId: design.designId,
          sourceVersionId: sourceVersion.versionId,
          draftVersion: CatalogueDesignVersion.fromMap(versionDoc.data()!),
          inheritedViews: views,
        );
      }
    }

    debugPrint(
      'CATALOGUE_CORRECTION_DEBUG '
      'stage=create-new '
      'sourceViews=${sourceViews.length}',
    );

    return createCorrectedVersion(
      designId: design.designId,
      sourceVersion: sourceVersion,
      sourceViews: sourceViews,
      correctionReason: design.reviewNotes,
    );
  }

  static Future<CatalogueDesignView> replaceView({
    required String designId,
    required String draftVersionId,
    required CatalogueDesignView existingView,
    required XFile file,
  }) async {
    final replacement = await CatalogueDesignService.uploadView(
      designId: designId,
      versionId: draftVersionId,
      file: file,
      viewType: existingView.viewType,
      displayOrder: existingView.displayOrder,
      isPrimary: existingView.isPrimary,
      title: existingView.title,
    );

    final oldRef = _db
        .collection('designs')
        .doc(designId)
        .collection('versions')
        .doc(draftVersionId)
        .collection('views')
        .doc(existingView.viewId);
    await oldRef.update({
      'excludedFromVersion': true,
      'replacedByViewId': replacement.viewId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return replacement;
  }

  static Future<CatalogueDesignView> addView({
    required String designId,
    required String draftVersionId,
    required XFile file,
    required CatalogueDesignViewType viewType,
    required int displayOrder,
    required bool isPrimary,
  }) {
    return CatalogueDesignService.uploadView(
      designId: designId,
      versionId: draftVersionId,
      file: file,
      viewType: viewType,
      displayOrder: displayOrder,
      isPrimary: isPrimary,
    );
  }

  static Future<void> excludeView({
    required String designId,
    required String draftVersionId,
    required String viewId,
  }) {
    return _db
        .collection('designs')
        .doc(designId)
        .collection('versions')
        .doc(draftVersionId)
        .collection('views')
        .doc(viewId)
        .update({
          'excludedFromVersion': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> updateViewType({
    required String designId,
    required String draftVersionId,
    required String viewId,
    required CatalogueDesignViewType viewType,
  }) {
    return _db
        .collection('designs')
        .doc(designId)
        .collection('versions')
        .doc(draftVersionId)
        .collection('views')
        .doc(viewId)
        .update({
          'viewType': viewType.name,
          if (!viewType.canBePrimary) 'isPrimary': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  static Future<void> setPrimaryView({
    required String designId,
    required String draftVersionId,
    required List<CatalogueDesignView> views,
    required String primaryViewId,
  }) async {
    final selected = views
        .where((view) => view.viewId == primaryViewId)
        .toList();
    if (selected.length != 1 || !selected.single.viewType.canBePrimary) {
      throw StateError('Select a valid Primary View.');
    }
    final versionRef = _db
        .collection('designs')
        .doc(designId)
        .collection('versions')
        .doc(draftVersionId);
    final batch = _db.batch();
    for (final view in views) {
      batch.update(versionRef.collection('views').doc(view.viewId), {
        'isPrimary': view.viewId == primaryViewId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(versionRef, {
      'primaryViewId': primaryViewId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> resubmitDesignerCorrection({
    required String designId,
    required String draftVersionId,
    required String title,
    required String description,
    required String garmentTypeCode,
    String? occasionCode,
    required CatalogueCommercialType commercialType,
    double? designerExpectedPrice,
    required List<CatalogueDesignView> views,
  }) async {
    if (views.isEmpty || views.length > 10) {
      throw StateError('A corrected Version requires 1 to 10 Design Views.');
    }
    final primary = views.where((view) => view.isPrimary).toList();
    if (primary.length != 1 || !primary.single.viewType.canBePrimary) {
      throw StateError('Select exactly one valid Primary View.');
    }
    if (commercialType != CatalogueCommercialType.free &&
        (designerExpectedPrice == null || designerExpectedPrice < 0)) {
      throw StateError('Enter a valid Designer expected price.');
    }

    final uid = _requireUid();
    final normalizedDesignId = designId.trim();
    final normalizedVersionId = draftVersionId.trim();
    final designRef = _db.collection('designs').doc(normalizedDesignId);
    final versionRef = designRef
        .collection('versions')
        .doc(normalizedVersionId);
    final eventRef = designRef.collection('review_events').doc();

    debugPrint(
      'CATALOGUE_RESUBMIT_DEBUG '
      'stage=validate-start '
      'designId=$normalizedDesignId '
      'draftVersionId=$normalizedVersionId '
      'uid=$uid',
    );

    final designSnapshot = await designRef.get();
    if (!designSnapshot.exists) {
      throw StateError('Catalogue design not found.');
    }
    final design = CatalogueDesign.fromDoc(designSnapshot);
    if (design.ownerType != CatalogueDesignOwnerType.designer ||
        design.submittedByUid != uid) {
      throw StateError('Only the owning Designer can resubmit this Design.');
    }
    if (design.lifecycleStatus !=
        CatalogueDesignLifecycleStatus.changesRequested) {
      throw StateError('Only a Changes Requested design can be resubmitted.');
    }
    final activeCorrectionDraftVersionId =
        designSnapshot.data()?['correctionDraftVersionId']?.toString().trim() ??
        '';
    if (activeCorrectionDraftVersionId != normalizedVersionId) {
      throw StateError('The selected correction Draft is no longer active.');
    }

    final commercial = CatalogueDesignCommercial(
      commercialType: commercialType,
      currency: design.commercial.currency,
      designerExpectedPrice: commercialType == CatalogueCommercialType.free
          ? null
          : designerExpectedPrice,
      approvedDesignCharge: design.commercial.approvedDesignCharge,
      royaltyRuleId: design.commercial.royaltyRuleId,
      commercialVersion: design.commercial.commercialVersion,
    );
    final event = CatalogueReviewEvent(
      eventId: eventRef.id,
      designId: normalizedDesignId,
      action: CatalogueReviewAction.resubmit,
      sourceLifecycle: design.lifecycleStatus.name,
      targetLifecycle: CatalogueDesignLifecycleStatus.readyForReview.name,
      reviewedVersionId: normalizedVersionId,
      notes: 'Designer corrected Version resubmitted for review.',
      actorUid: uid,
      createdAt: DateTime.now(),
    );

    // Keep writes sequential. This avoids the multi-write rules access budget
    // while retaining a safe order: Version, audit event, then root lifecycle.
    debugPrint(
      'CATALOGUE_RESUBMIT_DEBUG stage=version-submit-start '
      'draftVersionId=$normalizedVersionId',
    );
    try {
      await versionRef.update({
        'primaryViewId': primary.single.viewId,
        'viewCount': views.length,
        'versionStatus': 'submitted',
        'processing': const CatalogueProcessingResult(
          status: CatalogueProcessingStatus.queued,
        ).toMap(),
        'submittedByUid': uid,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=version-submit-success '
        'draftVersionId=$normalizedVersionId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=version-submit-failed '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    debugPrint(
      'CATALOGUE_RESUBMIT_DEBUG stage=event-create-start '
      'eventId=${eventRef.id}',
    );
    try {
      await eventRef.set(
        event.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=event-create-success '
        'eventId=${eventRef.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=event-create-failed '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    debugPrint(
      'CATALOGUE_RESUBMIT_DEBUG stage=design-submit-start '
      'designId=$normalizedDesignId',
    );
    try {
      await designRef.update({
        'title': title.trim(),
        'description': _text(description),
        'garmentTypeCodes': [garmentTypeCode],
        'occasionCodes': occasionCode == null ? <String>[] : [occasionCode],
        'commercial': commercial.toMap(),
        'activeVersionId': normalizedVersionId,
        'lifecycleStatus': CatalogueDesignLifecycleStatus.readyForReview.name,
        'processingStatus': CatalogueProcessingStatus.queued.name,
        'reviewedVersionId': null,
        'latestReviewEventId': eventRef.id,
        'changeRequestScope': null,
        'affectedViewIds': <String>[],
        'reviewNotes': null,
        'rejectionReason': null,
        'correctionDraftVersionId': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=design-submit-success '
        'designId=$normalizedDesignId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CATALOGUE_RESUBMIT_DEBUG stage=design-submit-failed '
        'error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  static Future<void> resubmitCorrection({
    required String designId,
    required String draftVersionId,
    required String title,
    required String description,
    required String garmentTypeCode,
    String? occasionCode,
    required CatalogueCommercialType commercialType,
    double? approvedDesignCharge,
    required List<CatalogueDesignView> views,
  }) async {
    if (views.isEmpty || views.length > 10) {
      throw StateError('A corrected Version requires 1 to 10 Design Views.');
    }
    final primary = views.where((view) => view.isPrimary).toList();
    if (primary.length != 1 || !primary.single.viewType.canBePrimary) {
      throw StateError('Select exactly one valid Primary View.');
    }

    final uid = _requireUid();
    final designRef = _db.collection('designs').doc(designId);
    final versionRef = designRef.collection('versions').doc(draftVersionId);
    final eventRef = designRef.collection('review_events').doc();

    await _db.runTransaction((transaction) async {
      final designSnapshot = await transaction.get(designRef);
      if (!designSnapshot.exists) {
        throw StateError('Catalogue design not found.');
      }
      final design = CatalogueDesign.fromDoc(designSnapshot);
      if (design.lifecycleStatus !=
          CatalogueDesignLifecycleStatus.changesRequested) {
        throw StateError('Only a Changes Requested design can be resubmitted.');
      }

      final commercial = CatalogueDesignCommercial(
        commercialType: commercialType,
        currency: design.commercial.currency,
        designerExpectedPrice: design.commercial.designerExpectedPrice,
        approvedDesignCharge: commercialType == CatalogueCommercialType.free
            ? null
            : approvedDesignCharge,
        royaltyRuleId: design.commercial.royaltyRuleId,
        commercialVersion: design.commercial.commercialVersion,
      );

      final event = CatalogueReviewEvent(
        eventId: eventRef.id,
        designId: designId,
        action: CatalogueReviewAction.resubmit,
        sourceLifecycle: design.lifecycleStatus.name,
        targetLifecycle: CatalogueDesignLifecycleStatus.readyForReview.name,
        reviewedVersionId: draftVersionId,
        notes: 'Corrected Version resubmitted for review.',
        actorUid: uid,
        createdAt: DateTime.now(),
      );

      transaction.update(versionRef, {
        'primaryViewId': primary.single.viewId,
        'viewCount': views.length,
        'versionStatus': 'submitted',
        'processing': const CatalogueProcessingResult(
          status: CatalogueProcessingStatus.queued,
        ).toMap(),
        'submittedByUid': uid,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        eventRef,
        event.toMap()..['createdAt'] = FieldValue.serverTimestamp(),
      );
      transaction.update(designRef, {
        'title': title.trim(),
        'description': _text(description),
        'garmentTypeCodes': [garmentTypeCode],
        'occasionCodes': occasionCode == null ? <String>[] : [occasionCode],
        'commercial': commercial.toMap(),
        'activeVersionId': draftVersionId,
        'lifecycleStatus': CatalogueDesignLifecycleStatus.readyForReview.name,
        'processingStatus': CatalogueProcessingStatus.queued.name,
        'reviewedVersionId': null,
        'latestReviewEventId': eventRef.id,
        'changeRequestScope': null,
        'affectedViewIds': <String>[],
        'reviewNotes': null,
        'rejectionReason': null,
        'correctionDraftVersionId': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  static String? _text(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
