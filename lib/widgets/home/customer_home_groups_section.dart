import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/customer_home_configuration.dart';

class CustomerHomeGroupsSection extends StatelessWidget {
  const CustomerHomeGroupsSection({super.key});

  static const _cards = <_HomeServiceCardData>[
    _HomeServiceCardData(
      id: 'design_custom',
      imageAsset: 'assets/images/customer_home_poster_v4.png',
      sourceRect: Rect.fromLTWH(22, 389, 322, 294),
      surface: Color(0xFFFFE7EE),
      accent: Color(0xFF9D003B),
      description: 'Browse, preview, save or order',
    ),
    _HomeServiceCardData(
      id: 'shop',
      imageAsset: 'assets/images/customer_home_poster_v4.png',
      sourceRect: Rect.fromLTWH(358, 389, 317, 294),
      surface: Color(0xFFF7E8F8),
      accent: Color(0xFF8E087E),
      description: 'Ready-to-wear, fabrics and accessories',
    ),
    _HomeServiceCardData(
      id: 'custom_tailoring',
      imageAsset: 'assets/images/arti_smiling.png',
      sourceRect: Rect.fromLTWH(0, 0, 1302, 1208),
      surface: Color(0xFFF0F3E5),
      accent: Color(0xFF496A26),
      description: 'Get garments stitched to your style',
    ),
    _HomeServiceCardData(
      id: 'quick_fix',
      imageAsset: 'assets/images/quickcare_home_services.png',
      sourceRect: Rect.fromLTWH(0, 0, 340, 264),
      surface: Color(0xFFFFEFDF),
      accent: Color(0xFFC65314),
      description: 'Repairs, zips, buttons and steam press',
    ),
    _HomeServiceCardData(
      id: 'garment_care',
      imageAsset: 'assets/images/garment_care_card_source.png',
      sourceRect: Rect.fromLTWH(1, 1, 334, 348),
      surface: Color(0xFFE7F3FC),
      accent: Color(0xFF0756A0),
      description: 'Laundry, dry cleaning and fabric care',
    ),
    _HomeServiceCardData(
      id: 'rent_fabrics',
      imageAsset: 'assets/images/customer_home_poster_v4.png',
      sourceRect: Rect.fromLTWH(688, 880, 317, 294),
      surface: Color(0xFFFFE9EF),
      accent: Color(0xFFB90050),
      description: 'Outfits for weddings and special events',
    ),
    _HomeServiceCardData(
      id: 'bulk_orders',
      imageAsset: 'assets/images/bulk_order_wedding_collection.png',
      sourceRect: Rect.fromLTWH(0, 0, 1024, 1536),
      surface: Color(0xFFF8E9F0),
      accent: Color(0xFF7B2458),
      description: 'Group orders for weddings and events',
    ),
  ];

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CustomerHomeGroup>>(
    stream: CustomerHomeConfigurationService.watch(),
    builder: (context, snapshot) {
      final groups = snapshot.data ?? CustomerHomeGroup.defaults;
      final cardsById = {for (final card in _cards) card.id: card};
      final labelsById = <String, String>{};
      final orderedIds = <String>[];
      for (final group in groups) {
        if (!group.enabled) continue;
        for (final id in group.itemIds) {
          if (!cardsById.containsKey(id) || labelsById.containsKey(id)) {
            continue;
          }
          labelsById[id] = group.labelFor(id);
          orderedIds.add(id);
        }
      }

      final visibleCards = orderedIds
          .map((id) => cardsById[id]!)
          .toList(growable: false);
      if (visibleCards.isEmpty) return const SizedBox.shrink();

      final sections = <Widget>[];
      final gridCards = <_HomeServiceCardData>[];
      void addGap() {
        if (sections.isNotEmpty) sections.add(const SizedBox(height: 10));
      }

      void flushGrid() {
        if (gridCards.isEmpty) return;
        addGap();
        sections.add(
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.64,
            children: [
              for (final card in gridCards)
                _HomeServiceCard(data: card, title: labelsById[card.id]!),
            ],
          ),
        );
        gridCards.clear();
      }

      for (final card in visibleCards) {
        if (card.id == 'bulk_orders') {
          flushGrid();
          addGap();
          sections.add(_BulkOrderHomeCard(title: labelsById[card.id]!));
        } else {
          gridCards.add(card);
        }
      }
      flushGrid();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sections,
      );
    },
  );
}

class _BulkOrderHomeCard extends StatelessWidget {
  const _BulkOrderHomeCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final route = CustomerHomeItemRegistry.items['bulk_orders']!.route;
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(route),
          child: Image.asset(
            'assets/images/bulk_order_wedding_collection.png',
            width: double.infinity,
            fit: BoxFit.fitWidth,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => AspectRatio(
              aspectRatio: 0.67,
              child: ColoredBox(
                color: const Color(0xFFF8E9F0),
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF7B2458),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeServiceCardData {
  const _HomeServiceCardData({
    required this.id,
    required this.imageAsset,
    required this.sourceRect,
    required this.surface,
    required this.accent,
    required this.description,
  });

  final String id;
  final String imageAsset;
  final Rect sourceRect;
  final Color surface;
  final Color accent;
  final String description;
}

class _HomeServiceCard extends StatelessWidget {
  const _HomeServiceCard({required this.data, required this.title});

  final _HomeServiceCardData data;
  final String title;

  @override
  Widget build(BuildContext context) {
    final route = CustomerHomeItemRegistry.items[data.id]!.route;
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: data.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(route),
          child: Ink(
            decoration: BoxDecoration(
              color: data.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: data.sourceRect.width / data.sourceRect.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ArtworkCrop(
                        assetPath: data.imageAsset,
                        sourceRect: data.sourceRect,
                        placeholderColor: data.surface,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 7, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: data.accent,
                            fontFamily: 'serif',
                            fontSize: 12,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                data.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 8.5,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: data.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkCrop extends StatefulWidget {
  const _ArtworkCrop({
    required this.assetPath,
    required this.sourceRect,
    required this.placeholderColor,
  });

  final String assetPath;
  final Rect sourceRect;
  final Color placeholderColor;

  @override
  State<_ArtworkCrop> createState() => _ArtworkCropState();
}

class _ArtworkCropState extends State<_ArtworkCrop> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextStream = AssetImage(
      widget.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == nextStream.key) return;
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = nextStream;
    _listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
    nextStream.addListener(_listener!);
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
      painter: _ArtworkCropPainter(image, widget.sourceRect),
      child: const SizedBox.expand(),
    );
  }
}

class _ArtworkCropPainter extends CustomPainter {
  const _ArtworkCropPainter(this.image, this.sourceRect);

  final ui.Image image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      sourceRect,
      Offset.zero & size,
      Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ArtworkCropPainter oldDelegate) =>
      image != oldDelegate.image || sourceRect != oldDelegate.sourceRect;
}
