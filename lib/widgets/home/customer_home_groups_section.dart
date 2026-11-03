import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/customer_home_configuration.dart';
import 'home_reference_artwork.dart';

class CustomerHomeGroupsSection extends StatelessWidget {
  const CustomerHomeGroupsSection({super.key});

  static const _cards = <_HomeServiceCardData>[
    _HomeServiceCardData(
      id: 'design_custom',
      number: '01',
      title: 'Design Your Dress',
      description: 'Explore designs, customise and save favourites',
      artworkRect: Rect.fromLTWH(52, 808, 374, 182),
      surface: Color(0xFFFFE9F1),
      accent: Color(0xFFE30068),
      icon: Icons.design_services_rounded,
    ),
    _HomeServiceCardData(
      id: 'custom_tailoring',
      number: '02',
      title: 'Stitching Order',
      description: 'Get your clothes stitched to your measurements',
      artworkRect: Rect.fromLTWH(52, 1102, 374, 166),
      surface: Color(0xFFFFEFEE),
      accent: Color(0xFFB51C2B),
      icon: Icons.content_cut_rounded,
    ),
    _HomeServiceCardData(
      id: 'shop',
      number: '03',
      title: 'Fashion Store',
      description: 'Shop ready-to-wear outfits, fabrics',
      artworkRect: Rect.fromLTWH(449, 808, 374, 182),
      surface: Color(0xFFF1ECFF),
      accent: Color(0xFF293C70),
      icon: Icons.shopping_bag_outlined,
    ),
    _HomeServiceCardData(
      id: 'garment_care',
      number: '04',
      title: 'Garment Care',
      description: 'Laundry, dry cleaning, ironing and fabric care',
      artworkRect: Rect.fromLTWH(52, 1390, 374, 136),
      surface: Color(0xFFE9F4FF),
      accent: Color(0xFF0871B5),
      icon: Icons.local_laundry_service_outlined,
    ),
    _HomeServiceCardData(
      id: 'quick_fix',
      number: '05',
      title: 'Quick Care & Home Services',
      description: 'Repairs, alterations and wardrobe management',
      artworkRect: Rect.fromLTWH(449, 1102, 374, 166),
      surface: Color(0xFFFFF0E4),
      accent: Color(0xFFD7600C),
      icon: Icons.handyman_outlined,
    ),
    _HomeServiceCardData(
      id: 'rent_fabrics',
      number: '06',
      title: 'Dress Rental',
      description: 'Rent outfits for shows, celebrations and events',
      artworkRect: Rect.fromLTWH(449, 1390, 374, 136),
      surface: Color(0xFFF1EBFF),
      accent: Color(0xFF6A35D1),
      icon: Icons.checkroom_outlined,
    ),
    _HomeServiceCardData(
      id: 'bulk_orders',
      number: '07',
      title: 'Weddings & Event Orders',
      description: 'Coordinated outfits for weddings, groups and functions',
      artworkRect: Rect.fromLTWH(480, 1625, 343, 108),
      surface: Color(0xFFFFEAF1),
      accent: Color(0xFFB2164E),
      icon: Icons.celebration_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CustomerHomeGroup>>(
    stream: CustomerHomeConfigurationService.watch(),
    builder: (context, snapshot) {
      final groups = snapshot.data ?? CustomerHomeGroup.defaults;
      final enabledIds = <String>{};
      for (final group in groups) {
        if (!group.enabled) continue;
        enabledIds.addAll(group.itemIds);
      }

      // Keep this fixed sequence even if an older Firestore home config has a
      // different group order. The owner config can still enable or hide items.
      final visibleCards = _cards
          .where((card) => enabledIds.contains(card.id))
          .toList(growable: false);
      if (visibleCards.isEmpty) return const SizedBox.shrink();

      final gridCards = visibleCards
          .where((card) => card.id != 'bulk_orders')
          .toList(growable: false);
      final weddingCard = visibleCards.where(
        (card) => card.id == 'bulk_orders',
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Our Services',
                  style: AppTextStyles.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () => _showAllServices(context, visibleCards),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all'),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final card in gridCards) _HomeServiceCard(data: card),
            ],
          ),
          for (final card in weddingCard) ...[
            const SizedBox(height: 10),
            _BulkOrderHomeCard(data: card),
          ],
        ],
      );
    },
  );

  static void _showAllServices(
    BuildContext context,
    List<_HomeServiceCardData> visibleCards,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        children: [
          for (final card in visibleCards)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: card.surface,
                child: Icon(card.icon, color: card.accent),
              ),
              title: Text(card.title),
              subtitle: Text(card.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(CustomerHomeItemRegistry.items[card.id]!.route);
              },
            ),
        ],
      ),
    );
  }
}

class _BulkOrderHomeCard extends StatelessWidget {
  const _BulkOrderHomeCard({required this.data});

  final _HomeServiceCardData data;

  @override
  Widget build(BuildContext context) {
    final route = CustomerHomeItemRegistry.items[data.id]!.route;
    return Semantics(
      button: true,
      label: '${data.title}. ${data.description}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(route),
          child: SizedBox(
            height: 108,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HomeReferenceArtwork(
                  sourceRect: data.artworkRect,
                  placeholderColor: data.surface,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFEAF1).withValues(alpha: 0.98),
                        const Color(0xFFFFEAF1).withValues(alpha: 0.88),
                        const Color(0x00FFEAF1),
                      ],
                      stops: const [0, 0.62, 1],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: data.accent,
                                fontFamily: 'serif',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              data.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF29344F),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: data.accent,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
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

class _HomeServiceCardData {
  const _HomeServiceCardData({
    required this.id,
    required this.number,
    required this.title,
    required this.artworkRect,
    required this.surface,
    required this.accent,
    required this.icon,
    required this.description,
  });

  final String id;
  final String number;
  final String title;
  final Rect artworkRect;
  final Color surface;
  final Color accent;
  final IconData icon;
  final String description;
}

class _HomeServiceCard extends StatelessWidget {
  const _HomeServiceCard({required this.data});

  final _HomeServiceCardData data;

  @override
  Widget build(BuildContext context) {
    final route = CustomerHomeItemRegistry.items[data.id]!.route;
    return Semantics(
      button: true,
      label: '${data.number}. ${data.title}. ${data.description}',
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
                Expanded(
                  flex: 5,
                  child: HomeReferenceArtwork(
                    sourceRect: data.artworkRect,
                    placeholderColor: data.surface,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: data.accent,
                            fontFamily: 'serif',
                            fontSize: 13,
                            height: 1.08,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                data.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 10,
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
