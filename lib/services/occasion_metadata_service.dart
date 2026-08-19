import '../models/occasion_metadata.dart';

class OccasionMetadataService {
  OccasionMetadataService._();

  static OccasionMetadata forOccasion({
    required String? occasionId,
    required String occasionLabel,
  }) {
    final id = (occasionId ?? '').trim();

    switch (id) {
      case 'dailyWear':
        return _dailyWear();

      case 'officeWear':
        return _officeWear();

      case 'casualOuting':
        return _casualOuting();

      case 'festiveWear':
        return _festiveWear();

      case 'partyWear':
        return _partyWear();

      case 'weddingGuest':
        return _weddingGuest();

      case 'bridalHeavyOccasion':
        return _bridalHeavyOccasion();

      case 'traditionalReligious':
        return _traditionalReligious();

      case 'maternityComfortWear':
        return _maternityComfortWear();

      case 'other':
      default:
        return _other(occasionLabel);
    }
  }

  static OccasionMetadata _dailyWear() {
    return const OccasionMetadata(
      occasionId: 'dailyWear',
      displayName: 'Daily Wear',
      easeMultiplier: 1.00,
      fabricAllowanceMultiplier: 1.00,
      complexityMultiplier: 1.00,
      liningRecommended: false,
      tailorReviewRecommended: false,
      notes: [
        'Daily wear uses standard comfort allowance.',
        'Breathable fabrics are usually preferred.',
      ],
    );
  }

  static OccasionMetadata _officeWear() {
    return const OccasionMetadata(
      occasionId: 'officeWear',
      displayName: 'Office Wear',
      easeMultiplier: 1.02,
      fabricAllowanceMultiplier: 1.02,
      complexityMultiplier: 1.05,
      liningRecommended: false,
      tailorReviewRecommended: false,
      notes: [
        'Office wear keeps a neat and comfortable fit.',
        'Wrinkle-resistant and breathable fabrics are recommended.',
      ],
    );
  }

  static OccasionMetadata _casualOuting() {
    return const OccasionMetadata(
      occasionId: 'casualOuting',
      displayName: 'Casual Outing',
      easeMultiplier: 1.03,
      fabricAllowanceMultiplier: 1.03,
      complexityMultiplier: 1.05,
      liningRecommended: false,
      tailorReviewRecommended: false,
      notes: [
        'Casual outing allows slightly relaxed comfort.',
        'Fabric and styling can be selected based on comfort and look.',
      ],
    );
  }

  static OccasionMetadata _festiveWear() {
    return const OccasionMetadata(
      occasionId: 'festiveWear',
      displayName: 'Festive Wear',
      easeMultiplier: 1.06,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.20,
      liningRecommended: true,
      tailorReviewRecommended: true,
      notes: [
        'Festive wear may need extra comfort allowance.',
        'Lining may be recommended depending on fabric and design.',
        'Tailor review is recommended for better fitting.',
      ],
    );
  }

  static OccasionMetadata _partyWear() {
    return const OccasionMetadata(
      occasionId: 'partyWear',
      displayName: 'Party Wear',
      easeMultiplier: 1.07,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.20,
      liningRecommended: true,
      tailorReviewRecommended: true,
      notes: [
        'Party wear may include fitted styling and heavier fabrics.',
        'Lining and tailor review are recommended for comfort and finish.',
      ],
    );
  }

  static OccasionMetadata _weddingGuest() {
    return const OccasionMetadata(
      occasionId: 'weddingGuest',
      displayName: 'Wedding Guest',
      easeMultiplier: 1.08,
      fabricAllowanceMultiplier: 1.15,
      complexityMultiplier: 1.35,
      liningRecommended: true,
      tailorReviewRecommended: true,
      notes: [
        'Wedding guest outfits may need extra ease and lining.',
        'Fabric allowance should consider fall, flare, embroidery and comfort.',
        'Tailor confirmation is recommended before final stitching.',
      ],
    );
  }

  static OccasionMetadata _bridalHeavyOccasion() {
    return const OccasionMetadata(
      occasionId: 'bridalHeavyOccasion',
      displayName: 'Bridal / Heavy Occasion',
      easeMultiplier: 1.15,
      fabricAllowanceMultiplier: 1.25,
      complexityMultiplier: 1.60,
      liningRecommended: true,
      tailorReviewRecommended: true,
      notes: [
        'Heavy occasion outfits usually require lining / astar.',
        'Extra allowance is recommended for comfort, embroidery and layering.',
        'Tailor verification is strongly recommended before production.',
      ],
    );
  }

  static OccasionMetadata _traditionalReligious() {
    return const OccasionMetadata(
      occasionId: 'traditionalReligious',
      displayName: 'Traditional / Religious',
      easeMultiplier: 1.05,
      fabricAllowanceMultiplier: 1.08,
      complexityMultiplier: 1.15,
      liningRecommended: true,
      tailorReviewRecommended: true,
      notes: [
        'Traditional outfits may need modest styling and comfortable movement.',
        'Lining may be recommended based on fabric transparency and finish.',
      ],
    );
  }

  static OccasionMetadata _maternityComfortWear() {
    return const OccasionMetadata(
      occasionId: 'maternityComfortWear',
      displayName: 'Maternity / Comfort Wear',
      easeMultiplier: 1.20,
      fabricAllowanceMultiplier: 1.10,
      complexityMultiplier: 1.15,
      liningRecommended: false,
      tailorReviewRecommended: true,
      notes: [
        'Comfort wear should prioritize ease, softness and adjustability.',
        'Tailor review is recommended for comfort-sensitive fitting.',
      ],
    );
  }

  static OccasionMetadata _other(String occasionLabel) {
    return OccasionMetadata(
      occasionId: 'other',
      displayName: occasionLabel.trim().isEmpty ? 'Other' : occasionLabel.trim(),
      easeMultiplier: 1.05,
      fabricAllowanceMultiplier: 1.05,
      complexityMultiplier: 1.10,
      liningRecommended: false,
      tailorReviewRecommended: true,
      notes: const [
        'Custom occasion selected. Tailor review is recommended.',
      ],
    );
  }
}
