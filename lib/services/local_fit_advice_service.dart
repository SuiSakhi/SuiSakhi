import '../models/measurement.dart';

/// Local, deterministic measurement checks. This service does not make a
/// network request and never sends measurements to an external provider.
class LocalFitAdviceService {
  static Future<FitAdviceResult> getTailoringTips(BodyMeasurements m) async {
    final tips = localGuidance(m);
    return FitAdviceResult.success(tips.map((tip) => '• $tip').join('\n'));
  }

  static List<String> localGuidance(BodyMeasurements m) {
    final tips = <String>[];
    final core = <String, double?>{
      'chest': m.chest,
      'waist': m.waist,
      'hips': m.hips,
    };
    final missing = core.entries
        .where((entry) => entry.value == null || entry.value! <= 0)
        .map((entry) => entry.key)
        .toList(growable: false);

    if (missing.isNotEmpty) {
      tips.add(
        'Some key circumferences are not captured (${missing.join(', ')}); confirm them with a tape before tailoring.',
      );
    }

    final waist = m.waist;
    final hips = m.hips;
    final chest = m.chest;
    final proportionsLookUnusual =
        (waist != null && hips != null && hips > 0 && waist > hips * 1.35) ||
        (waist != null && chest != null && chest > 0 && waist > chest * 1.35);
    if (proportionsLookUnusual) {
      tips.add(
        'The waist estimate differs noticeably from the other circumferences; recheck the waist, chest and hip tape positions.',
      );
    }

    final height = m.height;
    final armLength = m.armLength;
    if (height != null &&
        height > 0 &&
        armLength != null &&
        armLength > height * 0.4) {
      tips.add(
        'Arm length looks unusually large relative to height; confirm the shoulder-to-wrist points with a tape.',
      );
    }

    tips.add(
      'Keep the tape level for chest, waist and hip circumferences; measure lengths vertically.',
    );
    tips.add(
      'Camera values are estimates. A tailor should confirm the fit and movement before cutting fabric.',
    );
    return tips;
  }
}

class FitAdviceResult {
  final bool success;
  final String text;

  const FitAdviceResult.success(this.text) : success = true;
  const FitAdviceResult.error(this.text) : success = false;
}
