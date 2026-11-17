import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suisakhi/models/measurement.dart';
import 'package:suisakhi/services/local_fit_advice_service.dart';
import 'package:suisakhi/services/smart_assist_client.dart';

void main() {
  test(
    'client sends the feature request and parses structured suggestions',
    () async {
      Map<String, dynamic>? sentRequest;
      final client = SmartAssistClient(
        invoker: (request) async {
          sentRequest = request;
          return {
            'feature': 'suggestFabricStyling',
            'requestId': 'request-123',
            'suggestions': [
              {
                'title': 'Fabric',
                'content': 'Try a breathable cotton blend.',
                'explanation': 'It suits a warm daytime event.',
              },
            ],
            'explanations': ['This is guidance only.'],
            'warnings': ['Confirm fabric availability.'],
            'clarificationQuestions': ['Is the event outdoors?'],
          };
        },
      );

      final result = await client.request(
        feature: 'suggestFabricStyling',
        input: {'garmentType': 'Kurti'},
      );

      expect(result.success, isTrue);
      expect(result.requestId, 'request-123');
      expect(result.suggestions.single.title, 'Fabric');
      expect(result.approvedContent, 'Fabric: Try a breathable cotton blend.');
      expect(result.text, contains('Confirm fabric availability'));
      expect(sentRequest, {
        'feature': 'suggestFabricStyling',
        'input': {'garmentType': 'Kurti'},
      });
    },
  );

  test('callable permission failures are mapped to safe messages', () async {
    final client = SmartAssistClient(
      invoker: (_) async => throw FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'sensitive backend detail',
      ),
    );

    final result = await client.request(
      feature: 'improveTailorInstructions',
      input: {'customerNotes': 'Keep hooks secure.'},
    );

    expect(result.success, isFalse);
    expect(result.text, contains('permission'));
    expect(result.text, isNot(contains('sensitive backend detail')));
  });

  test('unexpected provider errors stay non-blocking and sanitized', () async {
    final client = SmartAssistClient(
      invoker: (_) async => throw StateError('provider secret detail'),
    );

    final result = await client.request(
      feature: 'suggestFabricStyling',
      input: {'garmentType': 'Kurti'},
    );

    expect(result.success, isFalse);
    expect(result.text, contains('temporarily unavailable'));
    expect(result.text, contains('order details were not changed'));
    expect(result.text, isNot(contains('provider secret detail')));
  });

  test(
    'customer note sanitizer removes private lines and retains original for review',
    () {
      const original =
          'Keep the sleeves comfortable.\nWaist is 28 inches.\nCall me at 9876543210.';
      final sanitized =
          SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(original);

      expect(sanitized.value, 'Keep the sleeves comfortable.');
      expect(sanitized.hadRedactions, isTrue);
      final applied = approvedTailorNotes(
        approved: true,
        suggestedContent: 'Keep sleeves comfortable and add secure hooks.',
        original: sanitized,
      );
      expect(applied, contains('Waist is 28 inches.'));
      expect(applied, contains('Call me at 9876543210.'));
    },
  );

  test('rejecting a rewrite leaves the existing notes untouched', () {
    const original = 'Keep the original neckline and add hooks.';
    final sanitized = SmartAssistInputSanitizer.sanitizeCustomerNotesWithStatus(
      original,
    );

    final applied = approvedTailorNotes(
      approved: false,
      suggestedContent: 'Change the neckline and add a zipper.',
      original: sanitized,
    );

    expect(applied, isNull);
    expect(original, 'Keep the original neckline and add hooks.');
  });

  test(
    'measurement fit guidance is deterministic and flags suspicious ratios locally',
    () {
      final measurements = BodyMeasurements(
        height: 163,
        chest: 77.8,
        waist: 128.6,
        hips: 47.2,
        armLength: 49.3,
        capturedAt: DateTime(2026, 11, 6),
      );

      final first = LocalFitAdviceService.localGuidance(measurements);
      final second = LocalFitAdviceService.localGuidance(measurements);

      expect(first, second);
      expect(first.join(' '), contains('waist estimate differs noticeably'));
    },
  );
}
