import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// In-app playback for a pending local recording or an already-uploaded draft.
class OrderInstructionMediaPreviewDialog extends StatefulWidget {
  const OrderInstructionMediaPreviewDialog({
    super.key,
    required this.kind,
    this.localFilePath,
    this.storagePath,
  }) : assert(localFilePath != null || storagePath != null);

  final String kind;
  final String? localFilePath;
  final String? storagePath;

  @override
  State<OrderInstructionMediaPreviewDialog> createState() =>
      _OrderInstructionMediaPreviewDialogState();
}

class _OrderInstructionMediaPreviewDialogState
    extends State<OrderInstructionMediaPreviewDialog> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _loading = true;
  bool _isPlaying = false;

  bool get _isVideo => widget.kind == 'video';

  @override
  void initState() {
    super.initState();
    _initializePlayback();
  }

  Future<void> _initializePlayback() async {
    try {
      late final VideoPlayerController controller;
      final localPath = widget.localFilePath?.trim() ?? '';
      if (localPath.isNotEmpty) {
        controller = VideoPlayerController.file(File(localPath));
      } else {
        final storagePath = widget.storagePath?.trim() ?? '';
        if (storagePath.isEmpty) {
          throw StateError('Recording location is missing.');
        }
        final url = await FirebaseStorage.instance
            .ref(storagePath)
            .getDownloadURL();
        if (!mounted) return;
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      _controller = controller;
      controller.addListener(_onPlaybackChanged);
      await controller.initialize();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onPlaybackChanged() {
    final playing = _controller?.value.isPlaying ?? false;
    if (playing == _isPlaying || !mounted) return;
    setState(() => _isPlaying = playing);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final screen = MediaQuery.sizeOf(context);
    final previewWidth = (screen.width * .78).clamp(220.0, 440.0).toDouble();
    final maxVideoHeight = screen.height * .42;
    return AlertDialog(
      title: Text(_isVideo ? 'Preview video note' : 'Listen to voice note'),
      content: SizedBox(
        width: previewWidth,
        child: _loading
            ? const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null || controller == null
            ? const Text(
                'This recording could not be opened. Check your connection and try again.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isVideo)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Builder(
                        builder: (context) {
                          final aspectRatio = controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : 16 / 9;
                          final width = math.min(
                            previewWidth,
                            maxVideoHeight * aspectRatio,
                          );
                          return SizedBox(
                            width: width,
                            height: width / aspectRatio,
                            child: VideoPlayer(controller),
                          );
                        },
                      ),
                    )
                  else
                    const SizedBox(
                      height: 136,
                      child: Center(
                        child: Icon(Icons.graphic_eq_rounded, size: 64),
                      ),
                    ),
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  IconButton.filledTonal(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
