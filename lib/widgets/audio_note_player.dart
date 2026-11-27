import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Compact playback control for short audio-only instruction recordings.
/// Audio is streamed through the already bundled platform media player.
class AudioNotePlayer extends StatefulWidget {
  const AudioNotePlayer({
    super.key,
    required this.resolveUrl,
    this.label = 'Play voice note',
    this.compact = false,
  });

  final Future<String?> Function() resolveUrl;
  final String label;
  final bool compact;

  @override
  State<AudioNotePlayer> createState() => _AudioNotePlayerState();
}

class _AudioNotePlayerState extends State<AudioNotePlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var controller = _controller;
      if (controller == null) {
        final url = (await widget.resolveUrl())?.trim() ?? '';
        if (url.isEmpty) throw StateError('Voice note is unavailable.');
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _controller = controller;
        controller.addListener(_onPlayerChanged);
        await controller.initialize();
        if (!mounted) {
          await controller.dispose();
          return;
        }
      }
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        if (controller.value.duration > Duration.zero &&
            controller.value.position >= controller.value.duration) {
          await controller.seekTo(Duration.zero);
        }
        await controller.play();
      }
    } catch (_) {
      final failedController = _controller;
      if (failedController != null &&
          !failedController.value.isInitialized) {
        failedController.removeListener(_onPlayerChanged);
        _controller = null;
        await failedController.dispose();
      }
      if (mounted) setState(() => _error = 'Could not play this voice note.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final playing = _controller?.value.isPlaying == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          style: widget.compact
              ? OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 38),
                )
              : null,
          onPressed: _loading ? null : _toggle,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(playing ? 'Pause voice note' : widget.label),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
