import '../models/dress.dart';
import 'smart_assist_client.dart';

export 'smart_assist_client.dart'
    show
        SmartAssistantResult,
        SmartAssistInputSanitizer,
        SanitizedCustomerNotes,
        approvedTailorNotes;

/// Language for tailor-facing checklist copy (simple wording for workers).
enum TailorChecklistLanguage { english, hindi, marathi }

/// Optional Smart Assist calls routed through the authenticated Firebase backend.
class SmartAssistService {
  SmartAssistService._();

  static Future<SmartAssistantResult> answerCustomerHelpQuestion({
    required String question,
    String topic = 'fabric_guidance',
  }) {
    final sanitized = SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(
      question,
    );
    if (sanitized.value.isEmpty) {
      return Future.value(
        const SmartAssistantResult.error(
          'Please ask a SuiSakhi help question without personal details or body measurements.',
        ),
      );
    }
    return SmartAssistClient.instance.request(
      feature: 'answerCustomerHelpQuestion',
      input: {'question': sanitized.value, 'topic': topic},
    );
  }

  static Future<SmartAssistantResult> fabricAndStylingTips({
    required String dressType,
    required String occasionLabel,
    required String fit,
    String? fabricChoice,
    String? designTemplateTitle,
    String? accentColorHex,
    String? budget,
  }) {
    return SmartAssistClient.instance.request(
      feature: 'suggestFabricStyling',
      input: {
        'garmentType': dressType,
        'occasion': occasionLabel,
        'fit': fit,
        'fabricChoice': ?fabricChoice,
        'designTitle': ?designTemplateTitle,
        'accentColor': ?accentColorHex,
        'budget': ?budget,
      },
    );
  }

  static Future<SmartAssistantResult> polishCustomerNotes({
    required String draft,
    required String dressType,
    required String fit,
  }) async {
    final sanitized = SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(
      draft,
    );
    if (sanitized.value.isEmpty) {
      return const SmartAssistantResult.error(
        'Please add garment instructions without contact details or body measurements.',
      );
    }
    final result = await SmartAssistClient.instance.request(
      feature: 'improveTailorInstructions',
      input: {
        'garmentType': dressType,
        'fit': fit,
        'customerNotes': sanitized.value,
        'customerNotesRedacted': sanitized.hadRedactions,
      },
    );
    return result;
  }

  static Future<SmartAssistantResult> tailorStitchingChecklist(
    DressOrder order, {
    TailorChecklistLanguage language = TailorChecklistLanguage.english,
  }) {
    final sanitized = SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(
      order.notes ?? '',
    );
    return SmartAssistClient.instance.request(
      feature: 'tailorChecklist',
      input: {
        'garmentType': order.dressType,
        'status': order.status.label,
        'fit': order.fit ?? '',
        'occasion': order.occasionCategory ?? '',
        'fabric': order.fabricChoice ?? order.fabricDescription ?? '',
        'language': language.name,
        'customerNotes': sanitized.value,
        'customerNotesRedacted': sanitized.hadRedactions,
      },
    );
  }

  static Future<SmartAssistantResult> deliveryHandoffBrief(DressOrder order) {
    // Keep delivery context generic: no order ID, customer identity, address,
    // phone, notes, payment or order value is sent to the provider.
    return SmartAssistClient.instance.request(
      feature: 'deliveryBrief',
      input: {
        'garmentType': order.dressType,
        'status': order.status.label,
        'fabric': order.fabricChoice ?? order.fabricDescription ?? '',
      },
    );
  }

  static Future<SmartAssistantResult> homeOutfitIdea({
    required String seasonHint,
    String? lastDressType,
  }) {
    return SmartAssistClient.instance.request(
      feature: 'outfitIdea',
      input: {'season': seasonHint, 'lastGarmentType': ?lastDressType},
    );
  }
}
