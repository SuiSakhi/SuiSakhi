import '../models/design_metadata.dart';
import '../models/fabric_estimate.dart';
import '../models/fabric_metadata.dart';
import '../models/occasion_metadata.dart';
import '../models/price_estimate.dart';

class PriceEstimationService {
  PriceEstimationService._();

  static const String formulaVersion = 'v1';

  static PriceEstimate estimate({
    required String dressType,
    required FabricEstimate fabricEstimate,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
    FabricMetadata? fabricMetadata,
    double customizationAmount = 0,
  }) {
    final normalizedDressType = dressType.trim().toLowerCase();
    final baseAmount = _baseStitchingAmount(normalizedDressType);

    final designMultiplier = switch (designMetadata?.complexity) {
      DesignComplexity.low => 1.00,
      DesignComplexity.medium => 1.15,
      DesignComplexity.high => 1.35,
      null => 1.00,
    };

    final occasionMultiplier =
        occasionMetadata?.complexityMultiplier ?? 1.00;

    final fabricMultiplier =
        fabricMetadata?.complexityMultiplier ?? 1.00;

    final quantityAdjustment = _fabricQuantityAdjustment(
      fabricEstimate.estimatedMeters,
    );

    final adjustedAmount = baseAmount *
        designMultiplier *
        occasionMultiplier *
        fabricMultiplier;

    final estimatedMidpoint =
        adjustedAmount + quantityAdjustment + customizationAmount;

    final minimumAmount = _roundToNearestFifty(
      estimatedMidpoint * 0.90,
    );

    final maximumAmount = _roundToNearestFifty(
      estimatedMidpoint * 1.15,
    );

    return PriceEstimate(
      dressType: dressType,
      currencyCode: 'INR',
      minimumAmount: minimumAmount,
      maximumAmount: maximumAmount,
      baseStitchingAmount: baseAmount,
      customizationAmount: customizationAmount,
      formulaVersion: formulaVersion,
      confidence: 'Medium',
      notes: [
        'Estimate uses the Phase-1 stitching baseline for $dressType.',
        'Design, occasion and fabric-handling complexity were considered.',
        'Estimated fabric quantity: ${fabricEstimate.estimatedMeters.toStringAsFixed(1)} meters.',
        if (customizationAmount > 0)
          'Structured customization charges were included.',
        'Fabric purchase cost is not included unless explicitly added later.',
        'Final price will be confirmed after tailor review.',
      ],
    );
  }

  static double _baseStitchingAmount(String dressType) {
    if (dressType.contains('saree blouse') ||
        dressType == 'blouse' ||
        dressType.contains('blouse')) {
      return 700;
    }

    if (dressType.contains('shirt')) {
      return 750;
    }

    if (dressType.contains('top') || dressType.contains('tunic')) {
      return 650;
    }

    if (dressType.contains('anarkali')) {
      return 1500;
    }

    if (dressType.contains('salwar')) {
      return 1200;
    }

    if (dressType.contains('kurta set')) {
      return 1100;
    }

    if (dressType.contains('kurti') ||
        dressType.contains('kurta')) {
      return 750;
    }

    if (dressType.contains('lehenga')) {
      return 2200;
    }

    if (dressType.contains('gown')) {
      return 1800;
    }

    if (dressType.contains('palazzo') ||
        dressType.contains('pant')) {
      return 700;
    }

    if (dressType.contains('skirt')) {
      return 750;
    }

    return 900;
  }

  static double _fabricQuantityAdjustment(double estimatedMeters) {
    if (estimatedMeters >= 7) {
      return 350;
    }

    if (estimatedMeters >= 5) {
      return 250;
    }

    if (estimatedMeters >= 3) {
      return 150;
    }

    return 75;
  }

  static double _roundToNearestFifty(double amount) {
    return (amount / 50).round() * 50.0;
  }
}
