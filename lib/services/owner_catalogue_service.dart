import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalogue_design.dart';
import '../models/catalogue_design_version.dart';
import '../models/catalogue_design_view.dart';
import '../models/catalogue_contributor_summary.dart';
import 'catalogue_contributor_service.dart';

class OwnerCatalogueVersionBundle {
  const OwnerCatalogueVersionBundle({
    required this.version,
    required this.views,
    required this.contributor,
  });

  final CatalogueDesignVersion version;
  final List<CatalogueDesignView> views;
  final CatalogueContributorSummary contributor;

  CatalogueDesignView? get primaryView {
    if (views.isEmpty) return null;

    final primaryId = version.primaryViewId?.trim() ?? '';
    if (primaryId.isNotEmpty) {
      for (final view in views) {
        if (view.viewId == primaryId) return view;
      }
    }

    for (final view in views) {
      if (view.isPrimary) return view;
    }

    return views.first;
  }

  bool get isLegacy => version.isLegacySingleView;
}

class OwnerCatalogueService {
  OwnerCatalogueService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<List<CatalogueDesign>> watchAllDesigns() {
    return _db.collection('designs').snapshots().map((snapshot) {
      final designs = snapshot.docs.map(CatalogueDesign.fromDoc).toList();
      designs.sort((a, b) {
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return designs;
    });
  }

  static Future<CatalogueDesign> getDesign(String designId) async {
    final snapshot = await _db.collection('designs').doc(designId.trim()).get();
    if (!snapshot.exists) {
      throw StateError('Catalogue design not found.');
    }
    return CatalogueDesign.fromDoc(snapshot);
  }

  static Stream<CatalogueDesign?> watchDesign(String designId) {
    return _db
        .collection('designs')
        .doc(designId.trim())
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? CatalogueDesign.fromDoc(snapshot) : null,
        );
  }

  static Future<CatalogueDesignVersion?> getActiveVersion(
    CatalogueDesign design,
  ) async {
    final versionId = design.activeVersionId?.trim() ?? '';
    if (versionId.isEmpty) return null;
    final snapshot = await _db
        .collection('designs')
        .doc(design.designId)
        .collection('versions')
        .doc(versionId)
        .get();
    if (!snapshot.exists) return null;
    return CatalogueDesignVersion.fromMap(snapshot.data()!);
  }

  static Future<List<CatalogueDesignView>> getVersionViews({
    required String designId,
    required CatalogueDesignVersion version,
  }) async {
    final snapshot = await _db
        .collection('designs')
        .doc(designId.trim())
        .collection('versions')
        .doc(version.versionId)
        .collection('views')
        .orderBy('displayOrder')
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs
          .map((document) => CatalogueDesignView.fromMap(document.data()))
          .toList(growable: false);
    }

    final legacy = version.legacyView;
    return legacy == null
        ? const <CatalogueDesignView>[]
        : <CatalogueDesignView>[legacy];
  }

  static Future<OwnerCatalogueVersionBundle?> getActiveVersionBundle(
    CatalogueDesign design,
  ) async {
    final version = await getActiveVersion(design);
    if (version == null) return null;
    final views = await getVersionViews(
      designId: design.designId,
      version: version,
    );
    final contributor = await CatalogueContributorService.resolve(design);
    return OwnerCatalogueVersionBundle(
      version: version,
      views: views,
      contributor: contributor,
    );
  }
}
