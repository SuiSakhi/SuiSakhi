import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/dress.dart';

final ladiesDresses = [
  DressType(
    id: 'kurti',
    name: 'Kurti',
    description: 'Casual to formal everyday wear',
    category: DressCategory.ladies,
    icon: Icons.person_outline_rounded,
    color: Color(0xFFFF6B9D),
    measurements: ['Chest', 'Waist', 'Hip', 'Shoulder', 'Kurti Length', 'Sleeve Length'],
  ),
  DressType(
    id: 'blouse',
    name: 'Blouse',
    description: 'Saree & lehenga companion',
    category: DressCategory.ladies,
    icon: Icons.checkroom_rounded,
    color: Color(0xFF9C27B0),
    measurements: ['Chest', 'Waist', 'Back Length', 'Shoulder', 'Sleeve Length', 'Neck'],
  ),
  DressType(
    id: 'salwar-suit',
    name: 'Salwar Suit',
    description: 'Kameez with salwar or churidar',
    category: DressCategory.ladies,
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFFFF5722),
    measurements: ['Chest', 'Waist', 'Hip', 'Shoulder', 'Kameez Length', 'Sleeve', 'Salwar Length'],
  ),
  DressType(
    id: 'lehenga',
    name: 'Lehenga',
    description: 'Festive & bridal wear',
    category: DressCategory.ladies,
    icon: Icons.local_florist_rounded,
    color: Color(0xFFE91E63),
    measurements: ['Waist', 'Hip', 'Lehenga Length', 'Blouse Chest', 'Blouse Back'],
  ),
  DressType(
    id: 'gown',
    name: 'Gown / Anarkali',
    description: 'Floor-length elegant dress',
    category: DressCategory.ladies,
    icon: Icons.star_border_rounded,
    color: Color(0xFF673AB7),
    measurements: ['Chest', 'Waist', 'Hip', 'Shoulder', 'Length', 'Sleeve'],
  ),
  DressType(
    id: 'saree-blouse',
    name: 'Saree Blouse',
    description: 'Perfect fit for every saree',
    category: DressCategory.ladies,
    icon: Icons.brightness_5_rounded,
    color: Color(0xFFF5A623),
    measurements: ['Chest', 'Waist', 'Back Neck to Waist', 'Shoulder', 'Sleeve'],
  ),
];


class DressCatalogScreen extends StatefulWidget {
  const DressCatalogScreen({super.key});

  @override
  State<DressCatalogScreen> createState() => _DressCatalogScreenState();
}

class _DressCatalogScreenState extends State<DressCatalogScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ladies Dress Catalog'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search dresses...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _DressGrid(
              dresses: ladiesDresses
                  .where((d) => d.name.toLowerCase().contains(_searchQuery))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DressGrid extends StatelessWidget {
  final List<DressType> dresses;
  const _DressGrid({required this.dresses});

  @override
  Widget build(BuildContext context) {
    if (dresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 60, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No dresses found', style: AppTextStyles.headlineMedium),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        // Taller than wide: fixed aspect was too short for icon + 2-line title + desc + chip.
        childAspectRatio: 0.72,
      ),
      itemCount: dresses.length,
      itemBuilder: (ctx, i) => _DressCard(dress: dresses[i]),
    );
  }
}

class _DressCard extends StatelessWidget {
  final DressType dress;
  const _DressCard({required this.dress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/catalog/${dress.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: dress.color.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Center(
                child: Icon(dress.icon, color: dress.color, size: 48),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dress.name,
                      style: AppTextStyles.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        dress.description,
                        style: AppTextStyles.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: dress.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${dress.measurements.length} measures',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: dress.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
