class BodyMeasurements {
  final double? chest;
  final double? waist;
  final double? hips;
  final double? shoulder;
  final double? armLength;
  final double? inseam;
  final double? height;
  final double? neck;
  final double? thigh;
  final DateTime capturedAt;

  const BodyMeasurements({
    this.chest,
    this.waist,
    this.hips,
    this.shoulder,
    this.armLength,
    this.inseam,
    this.height,
    this.neck,
    this.thigh,
    required this.capturedAt,
  });

  /// Returns AI values that map directly to the universal 22-point chart.
  /// The camera does not estimate the other chart points, so they stay empty
  /// until the customer or tailor measures them.
  double? universalChartValueCm(int number) => switch (number) {
    1 => neck,
    3 => chest,
    5 => waist,
    6 => hips,
    7 => height,
    10 => armLength,
    19 => shoulder,
    _ => null,
  };

  static BodyMeasurements get sampleFemale => BodyMeasurements(
    chest: 86,
    waist: 68,
    hips: 92,
    shoulder: 38,
    armLength: 58,
    inseam: 74,
    height: 162,
    neck: 34,
    thigh: 54,
    capturedAt: DateTime.now(),
  );

  static BodyMeasurements get sampleMale => BodyMeasurements(
    chest: 98,
    waist: 82,
    hips: 96,
    shoulder: 46,
    armLength: 64,
    inseam: 80,
    height: 175,
    neck: 40,
    thigh: 58,
    capturedAt: DateTime.now(),
  );
}

class DressMeasurement {
  final String dressType;
  final Map<String, double> measurements;
  final String? notes;
  final DateTime createdAt;

  const DressMeasurement({
    required this.dressType,
    required this.measurements,
    this.notes,
    required this.createdAt,
  });
}
