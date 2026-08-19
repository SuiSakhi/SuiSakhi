import '../models/design_metadata.dart';

class DesignMetadataService {
  DesignMetadataService._();

  static DesignMetadata defaultForDressType(String dressType) {
    final normalized = dressType.trim().toLowerCase();

    if (normalized.contains('anarkali')) {
      return _anarkaliSuit();
    }

    if (normalized.contains('lehenga')) {
      return _lehengaCholi();
    }

    if (normalized.contains('gown')) {
      return _gown();
    }

    if (normalized.contains('saree blouse')) {
      return _sareeBlouse();
    }

    if (normalized == 'blouse' || normalized.contains('blouse')) {
      return _blouse();
    }

    if (normalized.contains('salwar')) {
      return _salwarSuit();
    }

    if (normalized.contains('kurta set')) {
      return _kurtaSet();
    }

    if (normalized.contains('kurti') || normalized.contains('kurta')) {
      return _kurti();
    }

    if (normalized.contains('top') || normalized.contains('tunic')) {
      return _topTunic();
    }

    if (normalized.contains('shirt')) {
      return _shirt();
    }

    if (normalized.contains('palazzo') || normalized.contains('pant')) {
      return _palazzoPant();
    }

    if (normalized.contains('skirt')) {
      return _skirt();
    }

    return _other(dressType);
  }

  static List<String> recommendedFabricsForDressType(String dressType) {
    return defaultForDressType(dressType).recommendedFabrics;
  }

  static bool liningRecommendedForDressType(String dressType) {
    return defaultForDressType(dressType).liningRequired;
  }

  static DesignComplexity complexityForDressType(String dressType) {
    return defaultForDressType(dressType).complexity;
  }

  static DesignMetadata _kurti() {
    return const DesignMetadata(
      dressType: 'Kurti',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.kneeLength,
      sleeveType: DesignSleeveType.threeQuarter,
      neckType: DesignNeckType.round,
      liningRequired: false,
      complexity: DesignComplexity.low,
      recommendedFabrics: [
        'Cotton',
        'Rayon / Viscose',
        'Linen',
        'Crepe',
      ],
    );
  }

  static DesignMetadata _kurtaSet() {
    return const DesignMetadata(
      dressType: 'Kurta Set',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.kneeLength,
      sleeveType: DesignSleeveType.threeQuarter,
      neckType: DesignNeckType.round,
      liningRequired: false,
      complexity: DesignComplexity.medium,
      recommendedFabrics: [
        'Cotton',
        'Rayon / Viscose',
        'Crepe',
        'Silk',
      ],
    );
  }

  static DesignMetadata _salwarSuit() {
    return const DesignMetadata(
      dressType: 'Salwar Suit',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.kneeLength,
      sleeveType: DesignSleeveType.threeQuarter,
      neckType: DesignNeckType.round,
      liningRequired: false,
      complexity: DesignComplexity.medium,
      recommendedFabrics: [
        'Cotton',
        'Rayon / Viscose',
        'Georgette',
        'Silk',
      ],
    );
  }

  static DesignMetadata _anarkaliSuit() {
    return const DesignMetadata(
      dressType: 'Anarkali Suit',
      silhouette: DesignSilhouette.anarkali,
      lengthType: DesignLengthType.floorLength,
      sleeveType: DesignSleeveType.full,
      neckType: DesignNeckType.round,
      liningRequired: true,
      complexity: DesignComplexity.high,
      recommendedFabrics: [
        'Georgette',
        'Chiffon',
        'Silk',
        'Net / Tulle',
      ],
    );
  }

  static DesignMetadata _lehengaCholi() {
    return const DesignMetadata(
      dressType: 'Lehenga Choli',
      silhouette: DesignSilhouette.umbrella,
      lengthType: DesignLengthType.floorLength,
      sleeveType: DesignSleeveType.half,
      neckType: DesignNeckType.round,
      liningRequired: true,
      complexity: DesignComplexity.high,
      recommendedFabrics: [
        'Silk',
        'Brocade',
        'Velvet',
        'Net / Tulle',
      ],
    );
  }

  static DesignMetadata _gown() {
    return const DesignMetadata(
      dressType: 'Gown',
      silhouette: DesignSilhouette.fitAndFlare,
      lengthType: DesignLengthType.floorLength,
      sleeveType: DesignSleeveType.full,
      neckType: DesignNeckType.vNeck,
      liningRequired: true,
      complexity: DesignComplexity.high,
      recommendedFabrics: [
        'Satin',
        'Georgette',
        'Chiffon',
        'Velvet',
      ],
    );
  }

  static DesignMetadata _blouse() {
    return const DesignMetadata(
      dressType: 'Blouse',
      silhouette: DesignSilhouette.princessCut,
      lengthType: DesignLengthType.short,
      sleeveType: DesignSleeveType.half,
      neckType: DesignNeckType.round,
      liningRequired: true,
      complexity: DesignComplexity.medium,
      recommendedFabrics: [
        'Cotton',
        'Silk',
        'Brocade',
        'Satin',
      ],
    );
  }

  static DesignMetadata _sareeBlouse() {
    return const DesignMetadata(
      dressType: 'Saree Blouse',
      silhouette: DesignSilhouette.princessCut,
      lengthType: DesignLengthType.short,
      sleeveType: DesignSleeveType.half,
      neckType: DesignNeckType.round,
      liningRequired: true,
      complexity: DesignComplexity.medium,
      recommendedFabrics: [
        'Silk',
        'Brocade',
        'Cotton',
        'Satin',
      ],
    );
  }

  static DesignMetadata _topTunic() {
    return const DesignMetadata(
      dressType: 'Top / Tunic',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.short,
      sleeveType: DesignSleeveType.threeQuarter,
      neckType: DesignNeckType.round,
      liningRequired: false,
      complexity: DesignComplexity.low,
      recommendedFabrics: [
        'Cotton',
        'Rayon / Viscose',
        'Crepe',
        'Linen',
      ],
    );
  }

  static DesignMetadata _shirt() {
    return const DesignMetadata(
      dressType: 'Shirt',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.short,
      sleeveType: DesignSleeveType.full,
      neckType: DesignNeckType.collar,
      liningRequired: false,
      complexity: DesignComplexity.low,
      recommendedFabrics: [
        'Cotton',
        'Linen',
        'Denim',
        'Polyester Blend',
      ],
    );
  }

  static DesignMetadata _palazzoPant() {
    return const DesignMetadata(
      dressType: 'Palazzo / Pant',
      silhouette: DesignSilhouette.straight,
      lengthType: DesignLengthType.ankleLength,
      sleeveType: DesignSleeveType.other,
      neckType: DesignNeckType.other,
      liningRequired: false,
      complexity: DesignComplexity.low,
      recommendedFabrics: [
        'Cotton',
        'Rayon / Viscose',
        'Crepe',
        'Polyester Blend',
      ],
    );
  }

  static DesignMetadata _skirt() {
    return const DesignMetadata(
      dressType: 'Skirt',
      silhouette: DesignSilhouette.gathered,
      lengthType: DesignLengthType.ankleLength,
      sleeveType: DesignSleeveType.other,
      neckType: DesignNeckType.other,
      liningRequired: true,
      complexity: DesignComplexity.medium,
      recommendedFabrics: [
        'Cotton',
        'Silk',
        'Georgette',
        'Net / Tulle',
      ],
    );
  }

  static DesignMetadata _other(String dressType) {
    return DesignMetadata(
      dressType: dressType.trim().isEmpty ? 'Other' : dressType.trim(),
      silhouette: DesignSilhouette.other,
      lengthType: DesignLengthType.other,
      sleeveType: DesignSleeveType.other,
      neckType: DesignNeckType.other,
      liningRequired: false,
      complexity: DesignComplexity.medium,
      recommendedFabrics: const [
        'Cotton',
        'Rayon / Viscose',
        'Crepe',
        'Other',
      ],
    );
  }
}
