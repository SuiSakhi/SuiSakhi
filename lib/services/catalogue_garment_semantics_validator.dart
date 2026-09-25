import '../models/catalogue_garment_semantics.dart';

enum CatalogueSemanticValidationCode {
  valid,
  profileVersionRequired,
  unknownGarmentType,
  collarConflict,
  cuffConflict,
  closureConflict,
  constructionConflict,
}

class CatalogueSemanticValidationResult {
  CatalogueSemanticValidationResult({
    required this.valid,
    required Set<CatalogueSemanticValidationCode> codes,
  }) : codes = Set.unmodifiable(codes);

  final bool valid;
  final Set<CatalogueSemanticValidationCode> codes;
}

/// Validates visual-semantic consistency without physical measurements.
class CatalogueGarmentSemanticsValidator {
  const CatalogueGarmentSemanticsValidator._();

  static CatalogueSemanticValidationResult validate(
    CatalogueGarmentSemantics semantics,
  ) {
    final codes = <CatalogueSemanticValidationCode>{};
    if (semantics.semanticProfileVersion.trim().isEmpty) {
      codes.add(CatalogueSemanticValidationCode.profileVersionRequired);
    }
    if (semantics.garmentType == CatalogueGarmentType.unknown) {
      codes.add(CatalogueSemanticValidationCode.unknownGarmentType);
    }
    if (semantics.collarType == CatalogueCollarType.none &&
        semantics.constructionFeatures.contains(
          CatalogueConstructionFeature.backYoke,
        ) &&
        semantics.garmentType == CatalogueGarmentType.shirt) {
      codes.add(CatalogueSemanticValidationCode.collarConflict);
    }
    if (semantics.sleeveType == CatalogueSleeveType.sleeveless &&
        semantics.cuffType != CatalogueCuffType.none) {
      codes.add(CatalogueSemanticValidationCode.cuffConflict);
    }
    if (semantics.closureType == CatalogueClosureType.fullButtonPlacket &&
        !semantics.constructionFeatures.contains(
          CatalogueConstructionFeature.frontPlacket,
        )) {
      codes.add(CatalogueSemanticValidationCode.closureConflict);
    }
    if (semantics.constructionFeatures.contains(
          CatalogueConstructionFeature.frontPlacket,
        ) &&
        semantics.closureType == CatalogueClosureType.none) {
      codes.add(CatalogueSemanticValidationCode.constructionConflict);
    }
    if (codes.isEmpty) {
      codes.add(CatalogueSemanticValidationCode.valid);
    }
    return CatalogueSemanticValidationResult(
      valid: codes.length == 1 &&
          codes.contains(CatalogueSemanticValidationCode.valid),
      codes: codes,
    );
  }
}
