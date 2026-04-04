/// Display preference for body measurements. Values in [BodyMeasurements] stay in **cm**.
enum MeasurementUnit {
  cm,
  inch,
}

extension MeasurementUnitStorage on MeasurementUnit {
  String get storageName => name;

  String get abbrev => switch (this) {
        MeasurementUnit.cm => 'cm',
        MeasurementUnit.inch => 'in',
      };

  /// Convert a stored centimetre value to this display unit.
  double fromCm(double cm) => switch (this) {
        MeasurementUnit.cm => cm,
        MeasurementUnit.inch => cm / 2.54,
      };

  /// Convert a display-unit value to centimetres for storage / orders.
  double toCm(double display) => switch (this) {
        MeasurementUnit.cm => display,
        MeasurementUnit.inch => display * 2.54,
      };
}

MeasurementUnit? measurementUnitFromStorage(Object? raw) {
  if (raw is! String) return null;
  switch (raw.toLowerCase().trim()) {
    case 'inch':
    case 'in':
      return MeasurementUnit.inch;
    case 'cm':
    case 'centimeter':
    case 'centimetre':
      return MeasurementUnit.cm;
    default:
      return null;
  }
}

/// Formatting helpers (body data is always cm in the model).
class MeasurementFormat {
  MeasurementFormat._();

  static String formatValue(double? cm, MeasurementUnit unit,
      {int fractionDigits = 1}) {
    if (cm == null) return '—';
    final v = unit.fromCm(cm);
    return v.toStringAsFixed(fractionDigits);
  }

  static String formatWithUnit(double? cm, MeasurementUnit unit,
      {int fractionDigits = 1}) {
    if (cm == null) return '—';
    return '${formatValue(cm, unit, fractionDigits: fractionDigits)} ${unit.abbrev}';
  }

  /// Primary unit large, alternate in parentheses.
  static String formatDual(double? cm, MeasurementUnit primary,
      {int fractionDigits = 1}) {
    if (cm == null) return '—';
    final other =
        primary == MeasurementUnit.cm ? MeasurementUnit.inch : MeasurementUnit.cm;
    final a = formatValue(cm, primary, fractionDigits: fractionDigits);
    final b = formatValue(cm, other, fractionDigits: fractionDigits);
    return '$a ${primary.abbrev} ($b ${other.abbrev})';
  }

  static double stepDisplay(MeasurementUnit unit) =>
      unit == MeasurementUnit.cm ? 0.5 : 0.25;

  static double parseToCm(String text, MeasurementUnit unit) {
    final v = double.tryParse(text.trim()) ?? 0;
    return unit.toCm(v);
  }

  /// Rounds cm for display in current unit then back for stable text fields.
  static String cmToDisplayText(double cm, MeasurementUnit unit,
      {int fractionDigits = 1}) {
    return unit.fromCm(cm).toStringAsFixed(fractionDigits);
  }
}
