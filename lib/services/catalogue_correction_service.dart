import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/catalogue_design.dart';
import '../models/catalogue_design_version.dart';
import '../models/catalogue_design_view.dart';
import '../models/catalogue_processing_status.dart';
import '../models/catalogue_review_event.dart';

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

    final designRef = _db.collection('designs').doc(designId.trim());
    final destinationRef = designRef.collection('versions').doc();
    final nextNumber = await _nextVersionNumber(designRef);

    final draftVersion = CatalogueDesignVersion(
      versionId: destinationRef.id,
      designId: designId.trim(),
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

    final inheritedViews = <CatalogueDesignView>[];
    final batch = _db.batch();

    batch.set(
      destinationRef,
      draftVersion.toMap()
        ..['sourceVersionId'] = sourceVersion.versionId
        ..['versionStatus'] = 'draft'
        ..['correctionReason'] = _text(correctionReason)
        ..['createdAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp(),
    );

    String? inheritedPrimaryId;
    for (final sourceView in sourceViews) {
      final destinationViewRef = destinationRef.collection('views').doc();
      final inherited = CatalogueDesignView(
        viewId: destinationViewRef.id,
        designId: designId.trim(),
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
      if (inherited.isPrimary) inheritedPrimaryId = inherited.viewId;
      inheritedViews.add(inherited);
      batch.set(
        destinationViewRef,
        inherited.toMap()
          ..['sourceVersionId'] = sourceVersion.versionId
          ..['sourceViewId'] = sourceView.viewId
          ..['inherited'] = true
          ..['replacementReason'] = null
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['updatedAt'] = FieldValue.serverTimestamp(),
      );
    }

    batch.update(destinationRef, {
      'primaryViewId': inheritedPrimaryId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(designRef, {
      'correctionDraftVersionId': destinationRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return CatalogueCorrectionDraft(
      designId: designId.trim(),
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
