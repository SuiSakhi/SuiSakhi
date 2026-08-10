import 'package:flutter/material.dart';

/// PRD-aligned taxonomy (scope_Tailoring0.2): occasions, modules, quick-fix SKUs.

enum OrderModuleType {
  coreTailoring,
  quickFix,
  bulkOrder,
  marketplace,
}

OrderModuleType orderModuleTypeFromFirestore(String? raw) {
  if (raw == null || raw.isEmpty) return OrderModuleType.coreTailoring;
  for (final v in OrderModuleType.values) {
    if (v.name == raw) return v;
  }
  return OrderModuleType.coreTailoring;
}

extension OrderModuleTypeLabel on OrderModuleType {
  String get label {
    switch (this) {
      case OrderModuleType.coreTailoring:
        return 'Tailoring';
      case OrderModuleType.quickFix:
        return 'Quick Fix';
      case OrderModuleType.bulkOrder:
        return 'Bulk';
      case OrderModuleType.marketplace:
        return 'Marketplace';
    }
  }
}

/// Ladies & Kids occasion rows from PRD Section 1 (core flow).
enum OccasionCategory {
  dailyWear,
  officeWear,
  partyWear,
  weddingBridal,
  festiveWear,
}

extension OccasionCategoryApi on OccasionCategory {
  String get id => name;

  String get displayName {
    switch (this) {
      case OccasionCategory.dailyWear:
        return 'Daily Wear';
      case OccasionCategory.officeWear:
        return 'Office Wear';
      case OccasionCategory.partyWear:
        return 'Party Wear';
      case OccasionCategory.weddingBridal:
        return 'Wedding / Bridal';
      case OccasionCategory.festiveWear:
        return 'Festive Wear';
    }
  }
}

/// PRD Step 2 — Ladies row.
const List<OccasionCategory> kLadiesOccasions = [
  OccasionCategory.dailyWear,
  OccasionCategory.officeWear,
  OccasionCategory.partyWear,
  OccasionCategory.weddingBridal,
  OccasionCategory.festiveWear,
];

/// PRD Step 2 — Kids row.
const List<OccasionCategory> kKidsOccasions = [
  OccasionCategory.dailyWear,
  //OccasionCategory.schoolWear,
  OccasionCategory.partyWear,
  OccasionCategory.weddingBridal,
  OccasionCategory.festiveWear,
];

/// PRD Quick Fix & Essentials — price ranges in INR (estimate band).
class QuickFixService {
  const QuickFixService({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.minInr,
    required this.maxInr,
  });

  final String id;
  final String title;
  final String subtitle;
  final int minInr;
  final int maxInr;

  double get midEstimate => (minInr + maxInr) / 2;

  static const List<QuickFixService> catalog = [
    QuickFixService(
      id: 'pico_fall',
      title: 'Saree Pico / Fall',
      subtitle: 'Finish saree ends',
      minInr: 80,
      maxInr: 150,
    ),
    QuickFixService(
      id: 'rafu',
      title: 'Rafu (tear repair)',
      subtitle: 'Small fabric tears',
      minInr: 100,
      maxInr: 250,
    ),
    QuickFixService(
      id: 'zip',
      title: 'Zip repair',
      subtitle: 'Replace or fix zips',
      minInr: 100,
      maxInr: 200,
    ),
    QuickFixService(
      id: 'button',
      title: 'Button fixing',
      subtitle: 'Buttons & hooks',
      minInr: 20,
      maxInr: 50,
    ),
    QuickFixService(
      id: 'minor_alt',
      title: 'Minor alterations',
      subtitle: 'Hem, taper, simple tweaks',
      minInr: 150,
      maxInr: 400,
    ),
    QuickFixService(
      id: 'express_stitch',
      title: 'Express stitching',
      subtitle: 'Faster turnaround',
      minInr: 200,
      maxInr: 500,
    ),
  ];

  static QuickFixService? byId(String id) {
    for (final s in catalog) {
      if (s.id == id) return s;
    }
    return null;
  }
}

enum BulkOrderKind { weddingPackage, eventPackage }

extension BulkOrderKindLabel on BulkOrderKind {
  String get displayName {
    switch (this) {
      case BulkOrderKind.weddingPackage:
        return 'Wedding package';
      case BulkOrderKind.eventPackage:
        return 'Event package';
    }
  }
}

/// Shop & Explore tiles (PRD Section 4) — phase-1 manual / partner handoff.
class ShopExploreCategory {
  const ShopExploreCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  static const List<ShopExploreCategory> items = [
    ShopExploreCategory(
      id: 'rent',
      title: 'Rent outfits',
      subtitle: 'Fancy dress, dance, occasions',
      icon: Icons.dry_cleaning_outlined,
    ),
    ShopExploreCategory(
      id: 'fabric',
      title: 'Buy fabrics',
      subtitle: 'Silk, cotton, net & more',
      icon: Icons.texture_rounded,
    ),
    ShopExploreCategory(
      id: 'accessories',
      title: 'Accessories',
      subtitle: 'Jewellery & add-ons',
      icon: Icons.diamond_outlined,
    ),
    ShopExploreCategory(
      id: 'kids_fashion',
      title: 'Kids fashion',
      subtitle: 'Curated kids wear',
      icon: Icons.child_care_outlined,
    ),
    ShopExploreCategory(
      id: 'festival',
      title: 'Festival collections',
      subtitle: 'Navratri, Rakhi & more',
      icon: Icons.celebration_outlined,
    ),
    ShopExploreCategory(
      id: 'tshirt_print',
      title: 'T-shirt printing',
      subtitle: 'Custom prints',
      icon: Icons.print_outlined,
    ),
  ];
}
