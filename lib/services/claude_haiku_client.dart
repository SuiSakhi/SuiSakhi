import 'dart:convert';

import 'package:http/http.dart' as http;

import 'claude_pricing_service.dart';

/// Single place for Haiku text completions (same API key as pricing / fit tips).
class ClaudeHaikuClient {
  ClaudeHaikuClient._();

  static Future<ClaudeHaikuReply> completeUser(
    String prompt, {
    int maxTokens = 400,
  }) async {
    final apiKey = await ClaudePricingService.loadConfiguredApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return ClaudeHaikuReply.error(
        'Anthropic API key missing. Firestore → config/api → claudeKey.',
      );
    }

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
              'max_tokens': maxTokens,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List).first['text'] as String;
        return ClaudeHaikuReply.ok(text.trim());
      }
      return ClaudeHaikuReply.error(
        'Claude API error (${response.statusCode}).',
      );
    } catch (_) {
      return ClaudeHaikuReply.error('Network error. Try again.');
    }
  }
}

class ClaudeHaikuReply {
  final bool success;
  final String text;

  const ClaudeHaikuReply.ok(this.text) : success = true;
  const ClaudeHaikuReply.error(this.text) : success = false;
}
