import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;

typedef SmartAssistInvoker =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

class SmartAssistSuggestion {
  final String title;
  final String content;
  final String explanation;

  const SmartAssistSuggestion({
    required this.title,
    required this.content,
    required this.explanation,
  });

  factory SmartAssistSuggestion.fromMap(Map<String, dynamic> value) {
    return SmartAssistSuggestion(
      title: value['title']?.toString() ?? '',
      content: value['content']?.toString() ?? '',
      explanation: value['explanation']?.toString() ?? '',
    );
  }
}

class SmartAssistantResult {
  final bool success;
  final String text;
  final String? feature;
  final String? requestId;
  final List<SmartAssistSuggestion> suggestions;
  final List<String> explanations;
  final List<String> warnings;
  final List<String> clarificationQuestions;

  const SmartAssistantResult.success({
    required this.text,
    required this.feature,
    required this.requestId,
    required this.suggestions,
    required this.explanations,
    required this.warnings,
    required this.clarificationQuestions,
  }) : success = true;

  const SmartAssistantResult.error(this.text)
    : success = false,
      feature = null,
      requestId = null,
      suggestions = const [],
      explanations = const [],
      warnings = const [],
      clarificationQuestions = const [];

  /// Text that can be applied after the customer explicitly approves it.
  /// Explanations, warnings and questions are kept out of saved tailoring notes.
  String get approvedContent => suggestions
      .map((suggestion) {
        final content = suggestion.content.trim();
        if (feature == 'suggestFabricStyling' && suggestion.title.isNotEmpty) {
          return '${suggestion.title}: $content';
        }
        return content;
      })
      .where((content) => content.isNotEmpty)
      .join('\n');

  factory SmartAssistantResult.fromMap(Map<String, dynamic> data) {
    if (data['suggestions'] is! List ||
        data['explanations'] is! List ||
        data['warnings'] is! List ||
        data['clarificationQuestions'] is! List) {
      throw const FormatException('Malformed Smart Assist response.');
    }
    final feature = data['feature']?.toString() ?? '';
    final suggestions =
        (data['suggestions'] is List ? data['suggestions'] as List : const [])
            .whereType<Map>()
            .map(
              (item) => SmartAssistSuggestion.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((item) => item.title.isNotEmpty && item.content.isNotEmpty)
            .toList(growable: false);
    final explanations = _stringList(data['explanations']);
    final warnings = _stringList(data['warnings']);
    final questions = _stringList(data['clarificationQuestions']);
    final requestId = data['requestId']?.toString();
    if (feature.isEmpty || requestId?.isNotEmpty != true) {
      throw const FormatException('Incomplete Smart Assist response.');
    }

    final sections = <String>[];
    if (suggestions.isNotEmpty) {
      if (feature == 'tailorChecklist') {
        sections.add('## ${suggestions.first.title}');
        sections.addAll(
          suggestions.map((item) {
            final content = item.content.trim();
            return content.startsWith('- ') ? content : '- $content';
          }),
        );
      } else {
        sections.addAll(
          suggestions.map((item) {
            final explanation = item.explanation.trim();
            return '• ${item.title}: ${item.content}'
                '${explanation.isEmpty ? '' : '\n  Why: $explanation'}';
          }),
        );
      }
    }
    if (explanations.isNotEmpty) {
      sections.addAll(explanations.map((item) => 'Why: $item'));
    }
    if (warnings.isNotEmpty) {
      sections.addAll(warnings.map((item) => 'Note: $item'));
    }
    if (questions.isNotEmpty) {
      sections.addAll(questions.map((item) => 'Please clarify: $item'));
    }

    return SmartAssistantResult.success(
      text: sections.isEmpty
          ? 'No suggestions are available yet. Add more details and try again.'
          : sections.join('\n'),
      feature: feature,
      requestId: requestId,
      suggestions: suggestions,
      explanations: explanations,
      warnings: warnings,
      clarificationQuestions: questions,
    );
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];
}

class SmartAssistInputSanitizer {
  SmartAssistInputSanitizer._();

  static final RegExp _sensitiveLine = RegExp(
    r'\b(?:email|phone(?:\s+number)?|mobile(?:\s+number)?|address|street|road|pin\s*code|postcode|zip\s*code|house\s*(?:no|number))\b|\b(chest|bust|waist|hips?|shoulder|neck|thigh|inseam|arm(?:\s+length)?|height|weight)\b[^\d\n]{0,24}\d+(?:\.\d+)?\b|\bmeasurements?\b[^\d\n]{0,24}\d|(?:[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}|https?://\S+|\b(?:\+?91[\s-]?)?[6-9]\d{9}\b|\b\d{6}\b)',
    caseSensitive: false,
  );

  static String sanitizeCustomerNotes(String raw) =>
      sanitizeCustomerNotesWithStatus(raw).value;

  static SanitizedCustomerNotes sanitizeCustomerNotesWithStatus(String raw) {
    final lines = raw.split(RegExp(r'\r?\n')).map((line) => line.trim());
    final safeLines = <String>[];
    final redactedLines = <String>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      if (_sensitiveLine.hasMatch(line)) {
        redactedLines.add(line);
        continue;
      }
      if (safeLines.length < 12) {
        safeLines.add(line.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' '));
      }
    }
    final safeText = safeLines.join('\n').trim();
    return SanitizedCustomerNotes(
      value: safeText.length > 1200 ? safeText.substring(0, 1200) : safeText,
      redactedLines: redactedLines,
    );
  }
}

class SanitizedCustomerNotes {
  final String value;
  final List<String> redactedLines;

  const SanitizedCustomerNotes({
    required this.value,
    required this.redactedLines,
  });

  bool get hadRedactions => redactedLines.isNotEmpty;

  String preserveRedactedLines(String approvedContent) {
    final approved = approvedContent.trim();
    if (redactedLines.isEmpty) return approved;
    final unchanged = redactedLines.join('\n');
    if (approved.isEmpty) return unchanged;
    return '$approved\n\nOriginal details kept unchanged:\n$unchanged';
  }
}

String? approvedTailorNotes({
  required bool approved,
  required String suggestedContent,
  required SanitizedCustomerNotes original,
}) {
  if (!approved || suggestedContent.trim().isEmpty) return null;
  return original.preserveRedactedLines(suggestedContent);
}

class SmartAssistClient {
  SmartAssistClient({SmartAssistInvoker? invoker})
    : _invoker = invoker ?? _invokeFirebase;

  static final SmartAssistClient instance = SmartAssistClient();
  final SmartAssistInvoker _invoker;

  Future<SmartAssistantResult> request({
    required String feature,
    required Map<String, dynamic> input,
  }) async {
    try {
      final data = await _invoker({
        'feature': feature,
        'input': input,
      }).timeout(const Duration(seconds: 35));
      final response = SmartAssistantResult.fromMap(data);
      if (response.feature != feature) {
        throw const FormatException('Mismatched Smart Assist response.');
      }
      return response;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        '[SmartAssist] $feature callable failed: '
        'code=${error.code}; message=${error.message ?? '(none)'}',
      );
      return SmartAssistantResult.error(_safeMessage(error.code));
    } on TimeoutException {
      debugPrint('[SmartAssist] $feature callable timed out.');
      return const SmartAssistantResult.error(
        'Smart Assist timed out. Your order details were not changed.',
      );
    } catch (error) {
      debugPrint('[SmartAssist] $feature failed with ${error.runtimeType}.');
      return const SmartAssistantResult.error(
        'Smart Assist is temporarily unavailable. Your order details were not changed.',
      );
    }
  }

  static Future<Map<String, dynamic>> _invokeFirebase(
    Map<String, dynamic> request,
  ) async {
    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
          'smartAssistV2',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 35)),
        );
    final result = await callable.call<Map<String, dynamic>>(request);
    return result.data;
  }

  static String _safeMessage(String code) => switch (code) {
    'unauthenticated' =>
      'SuiSakhi could not verify this request. Please try again.',
    'failed-precondition' =>
      'Smart Assist app verification is unavailable. Please try again later.',
    'permission-denied' => 'You do not have permission to use Smart Assist.',
    'invalid-argument' => 'Please review the details and try again.',
    'resource-exhausted' =>
      'Smart Assist is temporarily rate limited. Please try again later.',
    'deadline-exceeded' =>
      'Smart Assist timed out. Your order details were not changed.',
    _ =>
      'Smart Assist is temporarily unavailable. Your order details were not changed.',
  };
}
