import '../models/design_metadata.dart';
import '../models/dress_customization_estimate.dart';
import '../models/fabric_estimate.dart';
import '../models/fabric_metadata.dart';
import '../models/occasion_metadata.dart';
import '../models/measurement.dart';

class FabricEstimationService {
  FabricEstimationService._();

  static const String formulaVersion = 'v1';

  static FabricEstimate estimate({
    required String dressType,
    required BodyMeasurements body,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
    FabricMetadata? fabricMetadata,
    DressCustomizationEstimate? customizationEstimate,
  }) {
    final normalizedDressType = dressType.trim().toLowerCase();

    double meters;

    if (normalizedDressType.contains('blouse')) {
      meters = 1.0;
    } else if (normalizedDressType.contains('shirt')) {
      meters = 2.2;
    } else if (normalizedDressType.contains('top') ||
        normalizedDressType.contains('tunic')) {
      meters = 2.0;
    } else if (normalizedDressType.contains('kurti') ||
        normalizedDressType.contains('kurta')) {
      meters = 2.8;
    } else if (normalizedDressType.contains('salwar')) {
      meters = 5.0;
    } else if (normalizedDressType.contains('anarkali')) {
      meters = 4.8;
    } else if (normalizedDressType.contains('gown')) {
      meters = 5.5;
    } else if (normalizedDressType.contains('lehenga')) {
      meters = 6.5;
    } else if (normalizedDressType.contains('palazzo') ||
        normalizedDressType.contains('pant')) {
      meters = 2.5;
    } else if (normalizedDressType.contains('skirt')) {
      meters = 3.0;
    } else {
      meters = 3.0;
    }
    
    double heightFactor = 1.0;

    if (body.height != null && body.height! > 0) {
      if (body.height! < 150) {
        heightFactor = 0.95;
      } else if (body.height! > 170) {
        heightFactor = 1.08;
      }
    }

    meters *= heightFactor;

    if (designMetadata?.liningRequired == true) {
      meters += 0.50;
    }

    switch (designMetadata?.complexity) {
      case DesignComplexity.high:
        meters += 0.50;
        break;

      case DesignComplexity.medium:
        meters += 0.25;
        break;

      case DesignComplexity.low:
      case null:
        break;
    }

    if (occasionMetadata?.liningRecommended == true) {
      meters += 0.25;
    }

    meters += customizationEstimate?.additionalFabricMeters ?? 0;

    meters *= fabricMetadata?.fabricAllowanceMultiplier ?? 1.0;

    return FabricEstimate(
      dressType: dressType,
      fabricName: fabricMetadata?.fabricName ?? 'Unknown',
      estimatedMeters: double.parse(meters.toStringAsFixed(1)),
      formulaVersion: formulaVersion,
      confidence: 'Medium',
      notes: [
        'Fabric estimate uses dress type baseline formula.',
        if (body.height != null && body.height! > 0)
          'Customer height was considered in fabric estimate.',
        if (designMetadata?.liningRequired == true)
          'Additional fabric considered for lining / astar.',
        if (occasionMetadata?.liningRecommended == true)
          'Occasion recommendation increases fabric requirement.',
        if (fabricMetadata != null)
          'Fabric behavior and allowance multipliers were considered.',
        if ((customizationEstimate?.additionalFabricMeters ?? 0) > 0)
          'Dress customization added '
              '${customizationEstimate!.additionalFabricMeters.toStringAsFixed(2)} '
              'meters to the fabric allowance.',
        if (customizationEstimate != null)
          ...customizationEstimate.notes,
      ],
    );
  }
}