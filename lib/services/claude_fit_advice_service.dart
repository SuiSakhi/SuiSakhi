import '../models/measurement.dart';
import 'claude_haiku_client.dart';

/// Short tailoring / fit tips from Claude using the same Firestore API key as pricing.
class ClaudeFitAdviceService {
  static String _line(String label, double? cm) {
    if (cm == null) return '$label: (not captured)';
    final inch = cm / 2.54;
    return '$label: ${cm.toStringAsFixed(1)} cm (${inch.toStringAsFixed(1)} in)';
  }

  static Future<FitAdviceResult> getTailoringTips(BodyMeasurements m) async {
    final summary = [
      _line('Height', m.height),
      _line('Chest', m.chest),
      _line('Waist', m.waist),
      _line('Hips', m.hips),
      _line('Shoulder', m.shoulder),
      _line('Arm length', m.armLength),
      _line('Neck', m.neck),
      _line('Thigh', m.thigh),
      _line('Inseam', m.inseam),
    ].join('\n');

    final prompt = '''You are an experienced tailor assistant. The customer has these body measurements (from a phone camera scan; approximate ±3–5%):

$summary

Give 4–6 short bullet points (use "•" prefix each line) on:
- fit checks for kurti/blouse/suit (ease, darting, sleeve length sanity)
- anything that looks unusual vs typical proportions (only if clearly off; otherwise say nothing alarming)
- one reminder to confirm critical circumferences with a tape before cutting expensive fabric

Keep total under 120 words. No medical claims. Plain practical tailoring tone.''';

    final reply = await ClaudeHaikuClient.completeUser(prompt, maxTokens: 280);
    if (!reply.success) {
      return FitAdviceResult.error(reply.text);
    }
    return FitAdviceResult.success(reply.text);
  }
}

class FitAdviceResult {
  final bool success;
  final String text;

  const FitAdviceResult.success(this.text) : success = true;
  const FitAdviceResult.error(this.text) : success = false;
}
