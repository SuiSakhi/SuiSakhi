import '../models/dress.dart';
import 'claude_haiku_client.dart';

/// Language for tailor-facing checklist copy (simple wording for workers).
enum TailorChecklistLanguage {
  english,
  hindi,
  marathi,
}

/// Extra “smart app” Claude features: styling, copy polish, tailor checklist.
class ClaudeSmartAssistantService {
  ClaudeSmartAssistantService._();

  static String _checklistLanguageBlock(TailorChecklistLanguage lang) {
    switch (lang) {
      case TailorChecklistLanguage.english:
        return 'Language: Write everything in simple, clear English. Short words. One idea per line.';
      case TailorChecklistLanguage.hindi:
        return 'Language: Write the ENTIRE response in simple Hindi using Devanagari script (हिंदी). '
            'Use very short, everyday words that a local tailor understands. No English except garment type names if needed.';
      case TailorChecklistLanguage.marathi:
        return 'Language: Write the ENTIRE response in simple Marathi using Devanagari script (मराठी). '
            'Use very short, everyday words that a local tailor understands. No English except garment type names if needed.';
    }
  }

  static Future<SmartAssistantResult> fabricAndStylingTips({
    required String dressType,
    required String occasionLabel,
    required String fit,
    String? fabricChoice,
    String? designTemplateTitle,
    String? accentColorHex,
  }) async {
    final fabricLine = fabricChoice != null && fabricChoice.isNotEmpty
        ? 'Fabric already chosen: $fabricChoice.'
        : 'No fabric chosen yet.';
    final designLine = designTemplateTitle != null &&
            designTemplateTitle.trim().isNotEmpty
        ? 'Design flat: $designTemplateTitle.'
        : 'No design flat selected.';
    final colorLine = accentColorHex != null && accentColorHex.isNotEmpty
        ? 'Accent colour: $accentColorHex.'
        : '';

    final prompt = '''You help customers planning Indian / fusion tailoring.

Context:
• Garment: $dressType
• Occasion / category: $occasionLabel
• Fit preference: $fit
• $fabricLine
• $designLine
${colorLine.isNotEmpty ? '• $colorLine' : ''}

Reply with 5–7 short lines, each starting with "•". Cover:
1) Fabric behaviour (drape, lining, opacity) if fabric unknown OR affirm choice if known
2) One styling detail for this occasion (neckline, sleeve, length) — practical only
3) Care / tailoring pitfall to avoid for this garment type

Under 130 words. No prices. No medical claims. Friendly and specific.''';

    final reply = await ClaudeHaikuClient.completeUser(prompt, maxTokens: 320);
    return _map(reply);
  }

  static Future<SmartAssistantResult> polishCustomerNotes({
    required String draft,
    required String dressType,
    required String fit,
  }) async {
    final trimmed = draft.trim();
    if (trimmed.isEmpty) {
      return SmartAssistantResult.error('Write a few words in Special instructions first.');
    }

    final prompt = '''Rewrite the customer's tailoring notes to be clear for a tailor. Keep ALL requests; do not add new design features they did not ask for.

Garment: $dressType. Fit: $fit.

Customer draft:
---
$trimmed
---

Output: one clean paragraph (or 2–3 short bullets with "•") in simple English. Start directly with the content — no preamble.''';

    final reply = await ClaudeHaikuClient.completeUser(prompt, maxTokens: 260);
    return _map(reply);
  }

  static Future<SmartAssistantResult> tailorStitchingChecklist(
    DressOrder o, {
    TailorChecklistLanguage language = TailorChecklistLanguage.english,
  }) {
    final meas = o.measurements;
    final measText = meas == null || meas.isEmpty
        ? '(no measurements on file)'
        : meas.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    final lang = _checklistLanguageBlock(language);

    final prompt = '''You are a senior tailor helping another tailor on the shop floor.

$lang

Order id: ${o.id}
Garment: ${o.dressType}
Status: ${o.status.label}
Fit: ${o.fit ?? '—'}
Client name: ${o.clientName ?? '—'}
Kids flow: ${o.kidsFlow}
Occasion key: ${o.occasionCategory ?? '—'}
Fabric / look: ${o.fabricDescription ?? '—'}
Measurements (cm as stored): $measText
Customer / shop notes:
---
${(o.notes ?? '').trim().isEmpty ? '(none)' : o.notes!.trim()}
---

FORMAT (important — the app will show this with large text):
• First line: a short title after "## " (markdown level-2 heading), e.g. ## Work steps
• Then 6–10 checklist lines; EACH line must start with "- " (markdown bullet) and ONE short sentence.
• Do NOT use **bold**, # besides the title line, numbered lists, or code. No tables.
• Topics: cutting order, main seams, fitting checkpoints using measurements, finishing, final QC.
• Assume Indian ethnic construction. No prices. Under 180 words total.''';

    return ClaudeHaikuClient.completeUser(prompt, maxTokens: 450)
        .then(_map);
  }

  static Future<SmartAssistantResult> deliveryHandoffBrief(DressOrder o) async {
    final prompt = '''You help a delivery partner picking up or dropping off stitched garments (India).

Order summary:
• Garment: ${o.dressType}
• Status: ${o.status.label}
• Order value (reference): ₹${o.price.toStringAsFixed(0)}
• Payment: ${o.paymentStatus.label}
• Address: ${o.deliveryAddress ?? '—'}
• Notes: ${(o.notes ?? '').trim().isEmpty ? '(none)' : o.notes!.trim()}
• Fabric / look: ${o.fabricDescription ?? '—'}

Reply with 5–7 lines starting with "•": handling (cover/garment bag), handover checks, fragile/heavy items, payment reminder if relevant. Under 90 words. Practical tone.''';

    final reply = await ClaudeHaikuClient.completeUser(prompt, maxTokens: 260);
    return _map(reply);
  }

  static Future<SmartAssistantResult> homeOutfitIdea({
    required String seasonHint,
    String? lastDressType,
  }) async {
    final extra = lastDressType != null && lastDressType.isNotEmpty
        ? 'They recently looked at / ordered: $lastDressType.'
        : '';

    final prompt = '''Give ONE concrete outfit idea for Indian women’s ethnic or fusion wear for $seasonHint. $extra

Reply in exactly 4 lines:
Line 1: Title (short)
Line 2: Garment combo (e.g. kurti + bottom + dupatta)
Line 3: Fabric + colour mood
Line 4: One sentence why it works

No bullet characters. Under 60 words total. No brands or shopping links.''';

    final reply = await ClaudeHaikuClient.completeUser(prompt, maxTokens: 200);
    return _map(reply);
  }

  static SmartAssistantResult _map(ClaudeHaikuReply reply) {
    if (!reply.success) {
      return SmartAssistantResult.error(reply.text);
    }
    return SmartAssistantResult.success(reply.text);
  }
}

class SmartAssistantResult {
  final bool success;
  final String text;

  const SmartAssistantResult.success(this.text) : success = true;
  const SmartAssistantResult.error(this.text) : success = false;
}
