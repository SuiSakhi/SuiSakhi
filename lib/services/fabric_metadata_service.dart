import '../models/fabric_metadata.dart';

class FabricMetadataService {
  FabricMetadataService._();

  static FabricMetadata forFabric(String? fabricName) {
    final normalized = (fabricName ?? '').trim().toLowerCase();

    if (normalized.contains('cotton')) {
      return _cotton();
    }

    if (normalized.contains('silk')) {
      return _silk();
    }

    if (normalized.contains('georgette')) {
      return _georgette();
    }

    if (normalized.contains('chiffon')) {
      return _chiffon();
    }

    if (normalized.contains('linen')) {
      return _linen();
    }

    if (normalized.contains('velvet')) {
      return _velvet();
    }

    if (normalized.contains('organza')) {
      return _organza();
    }

    if (normalized.contains('rayon') || normalized.contains('viscose')) {
      return _rayonViscose();
    }

    if (normalized.contains('crepe')) {
      return _crepe();
    }

    if (normalized.contains('satin')) {
      return _satin();
    }

    if (normalized.contains('net') || normalized.contains('tulle')) {
      return _netTulle();
    }

    if (normalized.contains('brocade')) {
      return _brocade();
    }

    if (normalized.contains('denim')) {
      return _denim();
    }

    if (normalized.contains('polyester')) {
      return _polyesterBlend();
    }

    if (normalized.contains('wool')) {
      return _woolBlend();
    }

    return _other(fabricName);
  }

  static FabricMetadata _cotton() {
    return const FabricMetadata(
      fabricName: 'Cotton',
      behavior: FabricBehavior.breathable,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.medium,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: true,
      easeMultiplier: 1.03,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.00,
      notes: [
        'Cotton may shrink after washing, so pre-wash is recommended before cutting.',
        'Cotton is usually comfortable for daily wear and office wear.',
        'Extra margin may be useful for long-term comfort and alterations.',
      ],
    );
  }

  static FabricMetadata _silk() {
    return const FabricMetadata(
      fabricName: 'Silk',
      behavior: FabricBehavior.delicate,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.08,
      complexityMultiplier: 1.20,
      notes: [
        'Silk has good fall and is suitable for festive, wedding and premium garments.',
        'Lining / astar is often recommended for comfort, finish and durability.',
        'Tailor review is recommended before cutting expensive silk fabric.',
      ],
    );
  }

  static FabricMetadata _georgette() {
    return const FabricMetadata(
      fabricName: 'Georgette',
      behavior: FabricBehavior.flowy,
      weight: FabricWeight.light,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.15,
      notes: [
        'Georgette is flowy and commonly used for festive, party and occasion wear.',
        'Lining is usually recommended because the fabric can be slightly sheer.',
        'Fabric estimation should consider fall, flare and lining requirement.',
      ],
    );
  }

  static FabricMetadata _chiffon() {
    return const FabricMetadata(
      fabricName: 'Chiffon',
      behavior: FabricBehavior.flowy,
      weight: FabricWeight.light,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.15,
      notes: [
        'Chiffon is lightweight and flowy, suitable for party and festive wear.',
        'Lining / astar is usually recommended due to transparency.',
        'Tailor review is recommended for accurate fall and finishing.',
      ],
    );
  }

  static FabricMetadata _linen() {
    return const FabricMetadata(
      fabricName: 'Linen',
      behavior: FabricBehavior.breathable,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.medium,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: true,
      easeMultiplier: 1.04,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.05,
      notes: [
        'Linen is breathable and comfortable but may shrink or wrinkle.',
        'Pre-wash is recommended before cutting.',
        'Slight extra ease can improve comfort and movement.',
      ],
    );
  }

  static FabricMetadata _velvet() {
    return const FabricMetadata(
      fabricName: 'Velvet',
      behavior: FabricBehavior.heavy,
      weight: FabricWeight.heavy,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.05,
      fabricAllowanceMultiplier: 1.12,
      complexityMultiplier: 1.35,
      notes: [
        'Velvet is heavy and suitable for festive, wedding and premium garments.',
        'Lining is recommended for comfort and finishing.',
        'Extra ease and tailor review are recommended due to fabric thickness.',
      ],
    );
  }

  static FabricMetadata _organza() {
    return const FabricMetadata(
      fabricName: 'Organza',
      behavior: FabricBehavior.structured,
      weight: FabricWeight.light,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.12,
      complexityMultiplier: 1.25,
      notes: [
        'Organza has a structured look and is commonly used for occasion wear.',
        'Lining is recommended for comfort and modest finish.',
        'Fabric estimation should consider layers, flare and design volume.',
      ],
    );
  }

  static FabricMetadata _rayonViscose() {
    return const FabricMetadata(
      fabricName: 'Rayon / Viscose',
      behavior: FabricBehavior.flowy,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.medium,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: true,
      easeMultiplier: 1.03,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.05,
      notes: [
        'Rayon / Viscose has good fall and is commonly used for kurtis and casual wear.',
        'Pre-wash is recommended because shrinkage may occur.',
        'Slight ease allowance improves comfort after washing.',
      ],
    );
  }

  static FabricMetadata _crepe() {
    return const FabricMetadata(
      fabricName: 'Crepe',
      behavior: FabricBehavior.flowy,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.10,
      notes: [
        'Crepe has a smooth fall and is suitable for tops, kurtis and occasion wear.',
        'Lining may be optional depending on opacity and design.',
        'Tailor review is useful for fitted or premium designs.',
      ],
    );
  }

  static FabricMetadata _satin() {
    return const FabricMetadata(
      fabricName: 'Satin',
      behavior: FabricBehavior.delicate,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.08,
      complexityMultiplier: 1.20,
      notes: [
        'Satin has a smooth shiny finish and is suitable for gowns and party wear.',
        'Lining is recommended for better structure and comfort.',
        'Cutting and stitching should be handled carefully to avoid slipping.',
      ],
    );
  }

  static FabricMetadata _netTulle() {
    return const FabricMetadata(
      fabricName: 'Net / Tulle',
      behavior: FabricBehavior.sheer,
      weight: FabricWeight.light,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.20,
      complexityMultiplier: 1.35,
      notes: [
        'Net / Tulle is sheer and usually requires lining or layering.',
        'Used often for gowns, lehenga overlays and occasion wear.',
        'Fabric estimation should consider multiple layers and flare.',
      ],
    );
  }

  static FabricMetadata _brocade() {
    return const FabricMetadata(
      fabricName: 'Brocade',
      behavior: FabricBehavior.structured,
      weight: FabricWeight.heavy,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.04,
      fabricAllowanceMultiplier: 1.12,
      complexityMultiplier: 1.35,
      notes: [
        'Brocade is structured and often used for festive and wedding garments.',
        'Lining is recommended for comfort and finishing.',
        'Extra margin and tailor review are recommended due to fabric thickness.',
      ],
    );
  }

  static FabricMetadata _denim() {
    return const FabricMetadata(
      fabricName: 'Denim',
      behavior: FabricBehavior.structured,
      weight: FabricWeight.heavy,
      shrinkageRisk: ShrinkageRisk.medium,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: true,
      easeMultiplier: 1.04,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.15,
      notes: [
        'Denim may shrink and soften after washing.',
        'Pre-wash is recommended before stitching.',
        'Slight extra ease improves movement and long-term comfort.',
      ],
    );
  }

  static FabricMetadata _polyesterBlend() {
    return const FabricMetadata(
      fabricName: 'Polyester Blend',
      behavior: FabricBehavior.structured,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: false,
      easeMultiplier: 1.01,
      fabricAllowanceMultiplier: 1.03,
      complexityMultiplier: 1.05,
      notes: [
        'Polyester blend usually has low shrinkage and is easy to maintain.',
        'Lining depends on fabric thickness, transparency and design.',
        'Good for practical wear when comfort and durability are needed.',
      ],
    );
  }

  static FabricMetadata _woolBlend() {
    return const FabricMetadata(
      fabricName: 'Wool Blend',
      behavior: FabricBehavior.heavy,
      weight: FabricWeight.heavy,
      shrinkageRisk: ShrinkageRisk.medium,
      stretchable: false,
      liningRecommended: true,
      preWashRecommended: false,
      easeMultiplier: 1.05,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.25,
      notes: [
        'Wool blend is heavier and usually needs lining for comfort.',
        'Extra ease is recommended for movement and layering.',
        'Tailor review is recommended before cutting heavy fabric.',
      ],
    );
  }

  static FabricMetadata _other(String? fabricName) {
    final name = (fabricName ?? '').trim();

    return FabricMetadata(
      fabricName: name.isEmpty ? 'Other' : name,
      behavior: FabricBehavior.other,
      weight: FabricWeight.medium,
      shrinkageRisk: ShrinkageRisk.low,
      stretchable: false,
      liningRecommended: false,
      preWashRecommended: false,
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.10,
      notes: const [
        'Custom fabric selected. Tailor review is recommended for accurate fitting and fabric handling.',
      ],
    );
  }
}
