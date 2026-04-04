import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stitching_rate.dart';

/// Calls Claude API to suggest a price range **anchored to the shop's rate card**.
/// The API key is read only from Firestore (set in **Firebase Console → Firestore**):
/// collection `config`, document `api`, string field `claudeKey` (optional alias `anthropic_api_key`).
class ClaudePricingService {
  static const _firestoreHelp =
      'Firebase Console → Firestore → config → api → field claudeKey (string, your sk-ant-… key from console.anthropic.com). '
      'No spaces or quotes; redeploy rules so authenticated clients may read config/api if needed.';

  /// Trim + strip zero-width chars (common when pasting from docs/chat).
  static String? _sanitizeApiKey(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    if (t.isEmpty) return null;
    return t;
  }

  static String? _keyFromDocData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final a = data['claudeKey'];
    final b = data['anthropic_api_key'];
    final s = a is String ? a : (a?.toString());
    final s2 = b is String ? b : (b?.toString());
    return _sanitizeApiKey(s) ?? _sanitizeApiKey(s2);
  }

  /// Shared loader for other Claude features (fit tips, etc.).
  static Future<String?> loadConfiguredApiKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('api')
          .get();
      return _keyFromDocData(doc.data());
    } catch (_) {
      return null;
    }
  }

  static String? _anthropicErrorMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is! Map<String, dynamic>) return null;
      final err = m['error'];
      if (err is Map && err['message'] != null) {
        return err['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  static Future<PriceEstimate> estimate({
    required String dressType,
    required String fit,
    required Map<String, String> measurements,
    String? notes,
    required List<StitchingRate> shopRates,
  }) async {
    if (shopRates.isEmpty) {
      return PriceEstimate.error(
        'No rate card loaded. The owner should add stitching rates in the Owner dashboard '
        'before AI can estimate from your shop prices.',
      );
    }

    final apiKey = await loadConfiguredApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      return PriceEstimate.error(
        'Anthropic api-key is missing.\n\n$_firestoreHelp',
      );
    }

    final measurementsText = measurements.isEmpty
        ? '(not filled yet)'
        : measurements.entries.map((e) => '${e.key}: ${e.value} cm').join(', ');

    final ratesBlock = shopRates.map((r) {
      final n = (r.notes != null && r.notes!.trim().isNotEmpty)
          ? ' — note: ${r.notes!.trim()}'
          : '';
      return '• ${r.dressType}: base ₹${r.basePrice.toStringAsFixed(0)} INR$n';
    }).join('\n');

    final notesLine = notes != null && notes.trim().isNotEmpty
        ? '\nExtra detail from customer/tailor notes: ${notes.trim()}'
        : '';

    final prompt = '''You help a tailor shop quote a job. The shop has defined its OWN base prices below.

SHOP RATE CARD (official base stitching prices — use ONLY these as your anchor, not generic market or web prices):
$ratesBlock

ORDER CONTEXT:
• Dress type requested: $dressType
• Fit: $fit
• Measurements: $measurementsText$notesLine

RULES:
1) Find the matching line on the rate card for this dress type (or the closest name if wording differs slightly).
2) Start from that base ₹ amount. Adjust the range ONLY for fit, measurements complexity, and notes — keep the final range sensible relative to that base (typically within roughly ±35% unless notes justify more).
3) Do NOT cite outside “market rates” or invent unrelated price levels. Your reasoning must mention the shop’s base rate you used.
4) If no reasonable match exists on the card, pick the nearest listed type, state that clearly, and still anchor to that base.

Reply in this exact format:
PRICE: ₹X – ₹Y
REASON: One sentence that names the shop base rate used and what you adjusted for.''';

    try {
      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': 180,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List).first['text'] as String;
        return PriceEstimate.success(text.trim());
      } else if (response.statusCode == 401) {
        final detail = _anthropicErrorMessage(response.body);
        return PriceEstimate.error(
          'Anthropic rejected the api-key (HTTP 401). '
          '${detail != null ? '$detail\n\n' : ''}'
          '$_firestoreHelp',
        );
      } else {
        final detail = _anthropicErrorMessage(response.body);
        return PriceEstimate.error(
          detail != null
              ? 'Claude API (${response.statusCode}): $detail'
              : 'Claude API error (${response.statusCode}).',
        );
      }
    } catch (e) {
      return PriceEstimate.error('Network error. Check your connection.');
    }
  }
}

class PriceEstimate {
  final bool success;
  final String text;

  const PriceEstimate.success(this.text) : success = true;
  const PriceEstimate.error(this.text) : success = false;
}
