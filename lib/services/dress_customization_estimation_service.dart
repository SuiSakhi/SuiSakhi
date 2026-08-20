import '../models/dress_customization_estimate.dart';

class DressCustomizationEstimationService {
  DressCustomizationEstimationService._();

  static DressCustomizationEstimate estimate({
    String? neckStyle,
    String? sleeveStyle,
    String? backDesign,
    String? alterationMargin,
    String? liningPreference,
  }) {
    double additionalFabricMeters = 0;
    double additionalStitchingAmount = 0;
    final notes = <String>[];

    final normalizedNeck = (neckStyle ?? '').trim().toLowerCase();
    final normalizedSleeve = (sleeveStyle ?? '').trim().toLowerCase();
    final normalizedBack = (backDesign ?? '').trim().toLowerCase();
    final normalizedMargin = (alterationMargin ?? '').trim().toLowerCase();
    final normalizedLining = (liningPreference ?? '').trim().toLowerCase();

    if (normalizedNeck.contains('keyhole') ||
        normalizedNeck.contains('princess') ||
        normalizedNeck.contains('pot') ||
        normalizedNeck.contains('collar')) {
      additionalStitchingAmount += 100;
      notes.add('Selected neck style adds stitching and finishing complexity.');
    } else if (normalizedNeck == 'other') {
      additionalStitchingAmount += 100;
      notes.add(
        'Custom neck style requires tailor review before final pricing.',
      );
    }

    if (normalizedSleeve.contains('full')) {
      additionalFabricMeters += 0.40;
      additionalStitchingAmount += 75;
      notes.add('Full sleeves add fabric and stitching allowance.');
    } else if (normalizedSleeve.contains('three quarter')) {
      additionalFabricMeters += 0.30;
      additionalStitchingAmount += 50;
      notes.add('Three quarter sleeves add fabric allowance.');
    } else if (normalizedSleeve.contains('elbow')) {
      additionalFabricMeters += 0.20;
      additionalStitchingAmount += 40;
      notes.add('Elbow sleeves add a small fabric allowance.');
    } else if (normalizedSleeve.contains('puff') ||
        normalizedSleeve.contains('bell')) {
      additionalFabricMeters += 0.50;
      additionalStitchingAmount += 150;
      notes.add(
        'Puff or bell sleeves require additional fabric and stitching effort.',
      );
    } else if (normalizedSleeve.contains('cap') ||
        normalizedSleeve.contains('short')) {
      additionalFabricMeters += 0.15;
      additionalStitchingAmount += 30;
      notes.add('Short sleeve styling adds a small material allowance.');
    } else if (normalizedSleeve == 'other') {
      additionalFabricMeters += 0.30;
      additionalStitchingAmount += 100;
      notes.add('Custom sleeve styling requires tailor review.');
    }

    if (normalizedBack.contains('button')) {
      additionalStitchingAmount += 125;
      notes.add('Button-back finishing increases stitching effort.');
    } else if (normalizedBack.contains('tie') ||
        normalizedBack.contains('dori')) {
      additionalStitchingAmount += 100;
      notes.add('Tie / Dori back adds finishing work.');
    } else if (normalizedBack.contains('deep')) {
      additionalStitchingAmount += 75;
      notes.add(
        'Deep back design requires additional finishing and tailor review.',
      );
    } else if (normalizedBack == 'other') {
      additionalStitchingAmount += 100;
      notes.add('Custom back design requires tailor review.');
    }

    if (normalizedMargin.contains('extra')) {
      additionalFabricMeters += 0.20;
      additionalStitchingAmount += 50;
      notes.add('Extra alteration margin adds a small fabric allowance.');
    } else if (normalizedMargin.contains('standard')) {
      additionalFabricMeters += 0.10;
      notes.add('Standard alteration margin was considered.');
    } else if (normalizedMargin.contains('tailor')) {
      additionalFabricMeters += 0.10;
      notes.add(
        'Tailor-recommended alteration margin will be confirmed before cutting.',
      );
    }

    if (normalizedLining == 'required') {
      additionalFabricMeters += 1.00;
      additionalStitchingAmount += 250;
      notes.add('Lining / Astar adds material and stitching effort.');
    } else if (normalizedLining.contains('recommended') ||
        normalizedLining.contains('tailor')) {
      additionalFabricMeters += 0.50;
      additionalStitchingAmount += 125;
      notes.add(
        'Provisional lining allowance was included pending tailor confirmation.',
      );
    }

    return DressCustomizationEstimate(
      additionalFabricMeters: double.parse(
        additionalFabricMeters.toStringAsFixed(2),
      ),
      additionalStitchingAmount: additionalStitchingAmount,
      notes: notes,
    );
  }
}
