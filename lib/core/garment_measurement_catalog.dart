import 'package:flutter/material.dart';

class GarmentMeasurementSpec {
  const GarmentMeasurementSpec(this.number, this.label, this.color);

  final int number;
  final String label;
  final Color color;

  String get key => '${number.toString().padLeft(2, '0')} · $label';
}

/// The 22 numbered fields in the SuiSakhi Universal Women's Measurement Chart.
/// Category sets identify chart-recommended fields; all fields remain optional.
class GarmentMeasurementCatalog {
  GarmentMeasurementCatalog._();

  static const List<GarmentMeasurementSpec> all = [
    GarmentMeasurementSpec(1, 'Neck (circumference)', Color(0xFFC90049)),
    GarmentMeasurementSpec(2, 'Over Bust (upper bust)', Color(0xFFE60069)),
    GarmentMeasurementSpec(3, 'Bust (full bust)', Color(0xFFC90049)),
    GarmentMeasurementSpec(4, 'Under Bust', Color(0xFFE07000)),
    GarmentMeasurementSpec(5, 'Waist', Color(0xFF14834A)),
    GarmentMeasurementSpec(6, 'Hips', Color(0xFF6817A8)),
    GarmentMeasurementSpec(7, 'Neck to Heel (total height)', Color(0xFFE51B32)),
    GarmentMeasurementSpec(8, 'Neck to Above Knee (front)', Color(0xFF6817A8)),
    GarmentMeasurementSpec(9, 'Above Knee to Ankle', Color(0xFF1455C0)),
    GarmentMeasurementSpec(
      10,
      'Arm Length (shoulder to wrist)',
      Color(0xFFE07000),
    ),
    GarmentMeasurementSpec(
      11,
      'Shoulder Seam (neck to shoulder point)',
      Color(0xFF6817A8),
    ),
    GarmentMeasurementSpec(
      12,
      'Arm Hole (armpit circumference)',
      Color(0xFF1455C0),
    ),
    GarmentMeasurementSpec(13, 'Bicep (upper arm)', Color(0xFFE07000)),
    GarmentMeasurementSpec(14, 'Forearm', Color(0xFF1682B4)),
    GarmentMeasurementSpec(15, 'Wrist', Color(0xFFE51B78)),
    GarmentMeasurementSpec(
      16,
      'V Neck Cut (front neck depth)',
      Color(0xFF6817A8),
    ),
    GarmentMeasurementSpec(17, 'Shoulder to Waist (front)', Color(0xFF6817A8)),
    GarmentMeasurementSpec(
      18,
      'Waist to Above Knee (kurti/top length)',
      Color(0xFFE51B78),
    ),
    GarmentMeasurementSpec(
      19,
      'Shoulder Width (left to right)',
      Color(0xFF14834A),
    ),
    GarmentMeasurementSpec(20, 'Upper Back', Color(0xFFE51B78)),
    GarmentMeasurementSpec(21, 'Mid Back (under bust line)', Color(0xFF1455C0)),
    GarmentMeasurementSpec(22, 'Waist Back', Color(0xFFE07000)),
  ];

  static List<String> get keys =>
      all.map((spec) => spec.key).toList(growable: false);

  static GarmentMeasurementSpec? forKey(String key) {
    for (final spec in all) {
      if (spec.key == key) return spec;
    }
    final number = int.tryParse(
      RegExp(r'^\s*(\d+)').firstMatch(key)?.group(1) ?? '',
    );
    if (number == null || number < 1 || number > all.length) return null;
    return all[number - 1];
  }

  /// Resolves a stored measurement label to the universal chart field.
  /// Older records use short labels such as `chest`, `height`, or `inseam`,
  /// while current customer references use the numbered catalog key.
  static GarmentMeasurementSpec? forAnyKey(String key) {
    final direct = forKey(key);
    if (direct != null) return direct;

    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalized.isEmpty) return null;

    if (normalized.contains('necktoheel') ||
        normalized == 'height' ||
        normalized == 'totalheight') {
      return all[6];
    }
    if (normalized.contains('necktoaboveknee')) return all[7];
    if (normalized.contains('abovekneetoankle') ||
        normalized == 'inseam' ||
        normalized == 'insideleg') {
      return all[8];
    }
    if (normalized.contains('armlength') || normalized == 'sleevelength') {
      return all[9];
    }
    if (normalized.contains('shoulderseam')) return all[10];
    if (normalized.contains('armhole') || normalized.contains('armscye')) {
      return all[11];
    }
    if (normalized.contains('bicep') || normalized.contains('upperarm')) {
      return all[12];
    }
    if (normalized.contains('forearm')) return all[13];
    if (normalized.contains('wrist')) return all[14];
    if (normalized.contains('vneck') || normalized.contains('neckdepth')) {
      return all[15];
    }
    if (normalized.contains('shouldertowaist')) return all[16];
    if (normalized.contains('waisttoaboveknee') ||
        normalized.contains('kurtitoplength') ||
        normalized == 'length' ||
        normalized == 'garmentlength') {
      return all[17];
    }
    if (normalized.contains('shoulderwidth') || normalized == 'shoulder') {
      return all[18];
    }
    if (normalized.contains('upperback')) return all[19];
    if (normalized.contains('midback')) return all[20];
    if (normalized.contains('waistback')) return all[21];
    if (normalized.contains('underbust')) return all[3];
    if (normalized.contains('overbust') || normalized.contains('upperbust')) {
      return all[1];
    }
    if (normalized.contains('bust') || normalized == 'chest') return all[2];
    if (normalized.contains('hip')) return all[5];
    if (normalized.contains('waist')) return all[4];
    if (normalized == 'neck' || normalized.contains('neckcircumference')) {
      return all[0];
    }
    return null;
  }

  static Set<int> recommendedNumbers(String dressType) {
    final type = dressType.toLowerCase();
    if (type.contains('blouse') || type.contains('choli')) {
      return {1, 2, 3, 4, 5, 11, 12, 13, 14, 15, 16};
    }
    if (type.contains('anarkali')) {
      return {1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 16, 17, 18};
    }
    if (type.contains('kurti') ||
        type.contains('kurta') ||
        type.contains('kameez') ||
        type.contains('tunic') ||
        type.contains('top')) {
      return {1, 2, 3, 4, 5, 6, 10, 11, 12, 16, 17, 18};
    }
    if (type.contains('salwar') || type.contains('churidar')) {
      return {1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18};
    }
    if (type.contains('palazzo') || type.contains('pant')) {
      return {5, 6, 9};
    }
    if (type.contains('lehenga')) {
      return {1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22};
    }
    if (type.contains('skirt')) return {5, 6, 8, 9, 20, 22};
    if (type.contains('gown') || type.contains('dress')) {
      return {1, 2, 3, 5, 6, 7, 17, 18};
    }
    if (type.contains('shirt') ||
        type.contains('jacket') ||
        type.contains('western')) {
      return {1, 3, 5, 10, 11, 14, 15, 16};
    }
    return const {};
  }
}
