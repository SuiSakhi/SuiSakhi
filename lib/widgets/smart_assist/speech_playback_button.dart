import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/speech_output_service.dart';

class SpeechPlaybackButton extends StatefulWidget {
  const SpeechPlaybackButton({
    required this.text,
    this.compact = false,
    super.key,
  });

  final String text;
  final bool compact;

  @override
  State<SpeechPlaybackButton> createState() => _SpeechPlaybackButtonState();
}

class _SpeechPlaybackButtonState extends State<SpeechPlaybackButton> {
  final Object _utteranceKey = Object();

  @override
  void dispose() {
    if (SpeechOutputService.instance.isSpeaking(_utteranceKey)) {
      unawaited(SpeechOutputService.instance.stop(_utteranceKey));
    }
    super.dispose();
  }

  Future<void> _toggle(bool isSpeaking) async {
    final speech = SpeechOutputService.instance;
    try {
      if (isSpeaking) {
        await speech.stop(_utteranceKey);
      } else {
        await speech.speak(_utteranceKey, widget.text);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio playback is unavailable. Check your device’s text-to-speech settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = SpeechOutputService.instance;
    return ValueListenableBuilder<Object?>(
      valueListenable: speech.activeUtterance,
      builder: (context, activeKey, _) {
        final isSpeaking = activeKey == _utteranceKey;
        final icon = isSpeaking
            ? Icons.stop_circle_outlined
            : Icons.volume_up_outlined;
        final label = isSpeaking ? 'Stop' : 'Listen';

        if (widget.compact) {
          return IconButton(
            onPressed: () => _toggle(isSpeaking),
            tooltip: isSpeaking ? 'Stop reading answer' : 'Listen to answer',
            visualDensity: VisualDensity.compact,
            icon: Icon(icon),
          );
        }

        return TextButton.icon(
          onPressed: () => _toggle(isSpeaking),
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        );
      },
    );
  }
}
