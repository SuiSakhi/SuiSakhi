import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays one illustration cropped from the approved customer home artwork.
class HomeReferenceArtwork extends StatefulWidget {
  const HomeReferenceArtwork({
    super.key,
    required this.sourceRect,
    required this.placeholderColor,
    this.fit = BoxFit.cover,
  });

  static const assetPath = 'assets/images/customer_home_art_reference.png';

  final Rect sourceRect;
  final Color placeholderColor;
  final BoxFit fit;

  @override
  State<HomeReferenceArtwork> createState() => _HomeReferenceArtworkState();
}

class _HomeReferenceArtworkState extends State<HomeReferenceArtwork> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = AssetImage(
      HomeReferenceArtwork.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return ColoredBox(color: widget.placeholderColor);
    return CustomPaint(
      painter: _ReferenceArtworkPainter(
        image: image,
        sourceRect: widget.sourceRect,
        fit: widget.fit,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ReferenceArtworkPainter extends CustomPainter {
  const _ReferenceArtworkPainter({
    required this.image,
    required this.sourceRect,
    required this.fit,
  });

  final ui.Image image;
  final Rect sourceRect;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(fit, sourceRect.size, size);
    final source = Alignment.center.inscribe(fitted.source, sourceRect);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ReferenceArtworkPainter oldDelegate) =>
      image != oldDelegate.image ||
      sourceRect != oldDelegate.sourceRect ||
      fit != oldDelegate.fit;
}
