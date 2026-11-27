import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks SuiSakhi's answers with the device's installed text-to-speech voice.
class SpeechOutputService {
  SpeechOutputService._() {
    _tts.setCompletionHandler(_clearActiveSpeech);
    _tts.setCancelHandler(_clearActiveSpeech);
    _tts.setErrorHandler((_) => _clearActiveSpeech());
  }

  static final SpeechOutputService instance = SpeechOutputService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<Object?> activeUtterance = ValueNotifier<Object?>(null);
  Object? _activeKey;

  bool isSpeaking(Object key) => _activeKey == key;

  Future<void> speak(Object key, String text) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return;

    try {
      await _tts.stop();
      _activeKey = key;
      activeUtterance.value = key;
      final indianEnglishAvailable = await _tts.setLanguage('en-IN');
      if (indianEnglishAvailable != true && indianEnglishAvailable != 1) {
        await _tts.setLanguage('en-US');
      }
      await _tts.setSpeechRate(0.46);
      final result = await _tts.speak(normalizedText);
      if (result != 1 && _activeKey == key) _clearActiveSpeech();
    } catch (_) {
      if (_activeKey == key) _clearActiveSpeech();
      rethrow;
    }
  }

  Future<void> stop(Object key) async {
    if (_activeKey != key) return;
    await _tts.stop();
    _clearActiveSpeech();
  }

  void _clearActiveSpeech() {
    _activeKey = null;
    activeUtterance.value = null;
  }
}
