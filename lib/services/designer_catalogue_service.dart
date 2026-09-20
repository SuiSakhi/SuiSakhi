import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/catalogue_design.dart';
import '../models/catalogue_design_version.dart';
import '../models/catalogue_design_view.dart';

class DesignerCatalogueBundle {
  const DesignerCatalogueBundle({required this.version, required this.views});

  final CatalogueDesignVersion version;
  final List<CatalogueDesignView> views;

  CatalogueDesignView? get primaryView {
    if (views.isEmpty) return null;
    final primaryId = version.primaryViewId?.trim() ?? '';
    for (final view in views) {
      if (view.viewId == primaryId) return view;
    }
    for (final view in views) {
      if (view.isPrimary) return view;
    }
    return views.first;
  }
}

class DesignerCatalogueService {
  DesignerCatalogueService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Stream<List<CatalogueDesign>> watchOwnDesigns({
    required String accountId,
    required String profileId,
  }) {
    final normalizedAccountId = accountId.trim();
    final normalizedProfileId = profileId.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (normalizedAccountId.isEmpty ||
        normalizedProfileId.isEmpty ||
        uid.isEmpty) {
      return Stream.value(const <CatalogueDesign>[]);
    }

    return _db
        .collection('designs')
        .where('ownerAccountId', isEqualTo: normalizedAccountId)
        .where('ownerProfileId', isEqualTo: normalizedProfileId)
        .where('ownerType', isEqualTo: CatalogueDesignOwnerType.designer.name)
        .where('submittedByUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final designs = snapshot.docs.map(CatalogueDesign.fromDoc).toList();
          designs.sort((a, b) {
            final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return designs;
        });
  }

  static Future<DesignerCatalogueBundle?> getActiveBundle(
    CatalogueDesign design,
  ) async {
    final versionId = design.activeVersionId?.trim() ?? '';
    if (versionId.isEmpty) return null;

    final versionRef = _db
        .collection('designs')
        .doc(design.designId)
        .collection('versions')
        .doc(versionId);
    final versionDoc = await versionRef.get();
    if (!versionDoc.exists) return null;

    final version = CatalogueDesignVersion.fromMap(versionDoc.data()!);
    final viewDocs = await versionRef
        .collection('views')
        .orderBy('displayOrder')
        .get();
    final views = viewDocs.docs
        .where((doc) => doc.data()['excludedFromVersion'] != true)
        .map((doc) => CatalogueDesignView.fromMap(doc.data()))
        .toList(growable: false);

    if (views.isEmpty && version.legacyView != null) {
      return DesignerCatalogueBundle(
        version: version,
        views: <CatalogueDesignView>[version.legacyView!],
      );
    }
    return DesignerCatalogueBundle(version: version, views: views);
  }
}
