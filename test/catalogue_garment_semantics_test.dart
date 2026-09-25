import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/catalogue_garment_semantics.dart';
import 'package:suisakhi/services/catalogue_fixture_semantics_registry.dart';
import 'package:suisakhi/services/catalogue_garment_semantics_comparator.dart';
import 'package:suisakhi/services/catalogue_garment_semantics_validator.dart';

void main() {
  group('Fixture-001 semantic ground truth', () {
    test('front identifies the garment as a shirt', () {
      expect(
        CatalogueFixtureSemanticsRegistry.fixture001Front().garmentType,
        CatalogueGarmentType.shirt,
      );
    });

    test('front captures shirt collar and full button placket', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001Front();
      expect(value.collarType, CatalogueCollarType.shirtCollar);
      expect(value.closureType, CatalogueClosureType.fullButtonPlacket);
      expect(
        value.constructionFeatures,
        contains(CatalogueConstructionFeature.frontPlacket),
      );
    });

    test('front captures bishop sleeves and button cuffs', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001Front();
      expect(value.sleeveType, CatalogueSleeveType.bishopSleeve);
      expect(value.cuffType, CatalogueCuffType.buttonCuff);
    });

    test('front captures curved hem and regular fit', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001Front();
      expect(value.hemType, CatalogueHemType.curvedHem);
      expect(value.silhouetteType, CatalogueSilhouetteType.regularFit);
    });

    test('expected Back records Back yoke as view-specific construction', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001ExpectedBack();
      expect(
        value.constructionFeatures,
        contains(CatalogueConstructionFeature.backYoke),
      );
      expect(value.closureType, CatalogueClosureType.none);
    });

    test('fixture semantics are approved ground truth', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001Front();
      expect(value.source, CatalogueSemanticSource.fixtureGroundTruth);
      expect(value.reviewStatus, CatalogueSemanticReviewStatus.approved);
    });
  });

  group('semantic governance', () {
    test('semantics contain no measurements or customer data', () {
      final value = CatalogueFixtureSemanticsRegistry.fixture001Front();
      expect(value.usesMeasurements, isFalse);
      expect(value.customerSpecific, isFalse);
      expect(value.providerSpecific, isFalse);
    });

    test('serialization uses stable enum names', () {
      final map = CatalogueFixtureSemanticsRegistry.fixture001Front().toMap();
      expect(map['garmentType'], 'shirt');
      expect(map['sleeveType'], 'bishopSleeve');
      expect(map['closureType'], 'fullButtonPlacket');
    });

    test('construction feature serialization is deterministic', () {
      final first = CatalogueFixtureSemanticsRegistry.fixture001Front().toMap();
      final second = CatalogueFixtureSemanticsRegistry.fixture001Front().toMap();
      expect(first['constructionFeatures'], second['constructionFeatures']);
    });

    test('construction features are immutable snapshots', () {
      final features = <CatalogueConstructionFeature>{
        CatalogueConstructionFeature.shoulderSeam,
      };
      final value = _semantics(constructionFeatures: features);
      features.add(CatalogueConstructionFeature.backYoke);
      expect(value.constructionFeatures, {
        CatalogueConstructionFeature.shoulderSeam,
      });
    });
  });

  group('semantic validation', () {
    test('Fixture-001 Front semantics are valid', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        CatalogueFixtureSemanticsRegistry.fixture001Front(),
      );
      expect(result.valid, isTrue);
      expect(result.codes, {CatalogueSemanticValidationCode.valid});
    });

    test('Fixture-001 expected Back semantics are valid', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        CatalogueFixtureSemanticsRegistry.fixture001ExpectedBack(),
      );
      expect(result.valid, isTrue);
    });

    test('profile version is required', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        _semantics(profileVersion: ''),
      );
      expect(
        result.codes,
        contains(CatalogueSemanticValidationCode.profileVersionRequired),
      );
    });

    test('unknown garment type is not valid ground truth', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        _semantics(garmentType: CatalogueGarmentType.unknown),
      );
      expect(
        result.codes,
        contains(CatalogueSemanticValidationCode.unknownGarmentType),
      );
    });

    test('sleeveless semantics cannot have a cuff', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        _semantics(
          sleeveType: CatalogueSleeveType.sleeveless,
          cuffType: CatalogueCuffType.buttonCuff,
        ),
      );
      expect(
        result.codes,
        contains(CatalogueSemanticValidationCode.cuffConflict),
      );
    });

    test('full button placket requires front-placket construction', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        _semantics(
          closureType: CatalogueClosureType.fullButtonPlacket,
          constructionFeatures: const {
            CatalogueConstructionFeature.shoulderSeam,
          },
        ),
      );
      expect(
        result.codes,
        contains(CatalogueSemanticValidationCode.closureConflict),
      );
    });

    test('front-placket construction cannot use no closure', () {
      final result = CatalogueGarmentSemanticsValidator.validate(
        _semantics(
          closureType: CatalogueClosureType.none,
          constructionFeatures: const {
            CatalogueConstructionFeature.frontPlacket,
          },
        ),
      );
      expect(
        result.codes,
        contains(CatalogueSemanticValidationCode.constructionConflict),
      );
    });
  });

  group('Front and Back semantic relationship', () {
    late CatalogueSemanticComparison comparison;

    setUp(() {
      comparison = CatalogueGarmentSemanticsComparator.compare(
        source: CatalogueFixtureSemanticsRegistry.fixture001Front(),
        target: CatalogueFixtureSemanticsRegistry.fixture001ExpectedBack(),
      );
    });

    test('garment type is preserved', () {
      expect(
        comparison.relationships['garmentType'],
        CatalogueSemanticRelationship.preserved,
      );
    });

    test('collar, sleeve, cuff, hem and silhouette are preserved', () {
      for (final key in [
        'collarType',
        'sleeveType',
        'cuffType',
        'hemType',
        'silhouetteType',
      ]) {
        expect(
          comparison.relationships[key],
          CatalogueSemanticRelationship.preserved,
        );
      }
    });

    test('closure is view-specific rather than forced equal', () {
      expect(
        comparison.relationships['closureType'],
        CatalogueSemanticRelationship.viewSpecific,
      );
    });

    test('construction features are view-specific', () {
      expect(
        comparison.relationships['constructionFeatures'],
        CatalogueSemanticRelationship.viewSpecific,
      );
    });

    test('known fixture pair has no preserved-field inconsistency', () {
      expect(comparison.hasInconsistency, isFalse);
    });
  });
}

CatalogueGarmentSemantics _semantics({
  String profileVersion = '1.0',
  CatalogueGarmentType garmentType = CatalogueGarmentType.shirt,
  CatalogueSleeveType sleeveType = CatalogueSleeveType.fullSleeve,
  CatalogueCuffType cuffType = CatalogueCuffType.none,
  CatalogueClosureType closureType = CatalogueClosureType.pullover,
  Set<CatalogueConstructionFeature> constructionFeatures = const {
    CatalogueConstructionFeature.shoulderSeam,
  },
}) {
  return CatalogueGarmentSemantics(
    semanticProfileVersion: profileVersion,
    garmentType: garmentType,
    collarType: CatalogueCollarType.shirtCollar,
    sleeveType: sleeveType,
    cuffType: cuffType,
    closureType: closureType,
    hemType: CatalogueHemType.curvedHem,
    silhouetteType: CatalogueSilhouetteType.regularFit,
    constructionFeatures: constructionFeatures,
    source: CatalogueSemanticSource.fixtureGroundTruth,
    reviewStatus: CatalogueSemanticReviewStatus.approved,
  );
}
