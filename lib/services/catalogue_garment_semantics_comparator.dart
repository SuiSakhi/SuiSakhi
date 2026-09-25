import '../models/catalogue_garment_semantics.dart';

enum CatalogueSemanticRelationship {
  preserved,
  viewSpecific,
  inconsistent,
}

class CatalogueSemanticComparison {
  CatalogueSemanticComparison({
    required Map<String, CatalogueSemanticRelationship> relationships,
  }) : relationships = Map.unmodifiable(relationships);

  final Map<String, CatalogueSemanticRelationship> relationships;

  bool get hasInconsistency =>
      relationships.values.contains(CatalogueSemanticRelationship.inconsistent);
}

/// Compares Front and Back fixture semantics without assuming hidden truth.
class CatalogueGarmentSemanticsComparator {
  const CatalogueGarmentSemanticsComparator._();

  static CatalogueSemanticComparison compare({
    required CatalogueGarmentSemantics source,
    required CatalogueGarmentSemantics target,
  }) {
    return CatalogueSemanticComparison(relationships: {
      'garmentType': _same(source.garmentType, target.garmentType),
      'collarType': _same(source.collarType, target.collarType),
      'sleeveType': _same(source.sleeveType, target.sleeveType),
      'cuffType': _same(source.cuffType, target.cuffType),
      'hemType': _same(source.hemType, target.hemType),
      'silhouetteType': _same(source.silhouetteType, target.silhouetteType),
      'closureType': CatalogueSemanticRelationship.viewSpecific,
      'constructionFeatures': CatalogueSemanticRelationship.viewSpecific,
    });
  }

  static CatalogueSemanticRelationship _same(Object source, Object target) =>
      source == target
          ? CatalogueSemanticRelationship.preserved
          : CatalogueSemanticRelationship.inconsistent;
}
