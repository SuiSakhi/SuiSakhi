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

  static Set<int> recommendedNumbers(String dressType) {
    final type = dressType.toLowerCase();
    if (type.contains('blouse') || type.contains('choli')) {
      return {1, 2, 3, 4, 5, 11, 12, 13, 14, 15, 16};
    }
    if (type.contains('kurti') || type.contains('kameez')) {
      return {1, 2, 3, 4, 5, 6, 10, 11, 12, 16, 17, 18};
    }
    if (type.contains('salwar') ||
        type.contains('churidar') ||
        type.contains('palazzo') ||
        type.contains('pant')) {
      return {5, 6, 9, 10, 13, 14, 15};
    }
    if (type.contains('lehenga')) return {5, 6, 17, 18, 20, 22};
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
