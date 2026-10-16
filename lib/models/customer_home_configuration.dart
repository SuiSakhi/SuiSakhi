import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerHomeItemDefinition {
  const CustomerHomeItemDefinition({
    required this.id,
    required this.label,
    required this.route,
    required this.iconCodePoint,
  });

  final String id;
  final String label;
  final String route;
  final int iconCodePoint;
}

/// These IDs and routes are app-owned. Admin configuration can choose and
/// relabel them, but cannot change what an item does or route it elsewhere.
class CustomerHomeItemRegistry {
  static const Map<String, CustomerHomeItemDefinition> items = {
    'design_custom': CustomerHomeItemDefinition(
      id: 'design_custom',
      label: 'Design Your Dress',
      route: '/smart-style-ideas',
      iconCodePoint: 0xe3b0,
    ),
    'custom_tailoring': CustomerHomeItemDefinition(
      id: 'custom_tailoring',
      label: 'Custom Tailoring',
      route: '/designer?entry=order',
      iconCodePoint: 0xe3b0,
    ),
    'design_daily': CustomerHomeItemDefinition(
      id: 'design_daily',
      label: 'Daily wear',
      route: '/designer?occasion=dailyWear',
      iconCodePoint: 0xe8f0,
    ),
    'design_office': CustomerHomeItemDefinition(
      id: 'design_office',
      label: 'Office wear',
      route: '/designer?occasion=officeWear',
      iconCodePoint: 0xe8f9,
    ),
    'design_party': CustomerHomeItemDefinition(
      id: 'design_party',
      label: 'Party wear',
      route: '/designer?occasion=partyWear',
      iconCodePoint: 0xe87d,
    ),
    'design_wedding': CustomerHomeItemDefinition(
      id: 'design_wedding',
      label: 'Wedding',
      route: '/designer?occasion=bridalHeavyOccasion',
      iconCodePoint: 0xe87e,
    ),
    'design_festive': CustomerHomeItemDefinition(
      id: 'design_festive',
      label: 'Festive wear',
      route: '/designer?occasion=festiveWear',
      iconCodePoint: 0xe54b,
    ),
    'quick_design': CustomerHomeItemDefinition(
      id: 'quick_design',
      label: 'Quick design from measurements',
      route: '/designer',
      iconCodePoint: 0xe3b0,
    ),
    'kids_design': CustomerHomeItemDefinition(
      id: 'kids_design',
      label: 'Design for a child',
      route: '/designer?kids=1',
      iconCodePoint: 0xe7ef,
    ),
    'catalogue': CustomerHomeItemDefinition(
      id: 'catalogue',
      label: 'Browse designs',
      route: '/catalog',
      iconCodePoint: 0xe410,
    ),
    'shop': CustomerHomeItemDefinition(
      id: 'shop',
      label: 'Fashion Store',
      route: '/shop-explore',
      iconCodePoint: 0xe8cc,
    ),
    'accessories': CustomerHomeItemDefinition(
      id: 'accessories',
      label: 'Accessories',
      route: '/shop-explore?category=accessories',
      iconCodePoint: 0xe54b,
    ),
    'rent_fabrics': CustomerHomeItemDefinition(
      id: 'rent_fabrics',
      label: 'Dress Rental',
      route: '/shop-explore?category=rent',
      iconCodePoint: 0xe8cc,
    ),
    'wishlist': CustomerHomeItemDefinition(
      id: 'wishlist',
      label: 'My wishlist',
      route: '/wishlist',
      iconCodePoint: 0xe87e,
    ),
    'quick_fix': CustomerHomeItemDefinition(
      id: 'quick_fix',
      label: 'Quick Care & Home Services',
      route: '/quick-fix',
      iconCodePoint: 0xe8f4,
    ),
    'fabric_help': CustomerHomeItemDefinition(
      id: 'fabric_help',
      label: 'Fabric & design help',
      route: '/fabric-help',
      iconCodePoint: 0xe8b8,
    ),
    'garment_care': CustomerHomeItemDefinition(
      id: 'garment_care',
      label: 'Garment Care',
      route: '/shop-explore?category=garment_care',
      iconCodePoint: 0xe54b,
    ),
    'bulk_orders': CustomerHomeItemDefinition(
      id: 'bulk_orders',
      label: 'Bulk Order',
      route: '/bulk-orders',
      iconCodePoint: 0xe87d,
    ),
    'measurements': CustomerHomeItemDefinition(
      id: 'measurements',
      label: 'My measurements',
      route: '/measurements',
      iconCodePoint: 0xe55b,
    ),
    'orders': CustomerHomeItemDefinition(
      id: 'orders',
      label: 'My orders',
      route: '/orders',
      iconCodePoint: 0xe8f6,
    ),
    'addresses': CustomerHomeItemDefinition(
      id: 'addresses',
      label: 'Delivery addresses',
      route: '/customer-addresses',
      iconCodePoint: 0xe0c8,
    ),
    'offers': CustomerHomeItemDefinition(
      id: 'offers',
      label: 'Offers & membership',
      route: '/offers',
      iconCodePoint: 0xe8d1,
    ),
  };
}

class CustomerHomeGroup {
  const CustomerHomeGroup({
    required this.id,
    required this.label,
    required this.enabled,
    required this.order,
    required this.itemIds,
    this.itemLabels = const {},
  });

  final String id;
  final String label;
  final bool enabled;
  final int order;
  final List<String> itemIds;
  final Map<String, String> itemLabels;

  String labelFor(String itemId) =>
      itemLabels[itemId] ?? CustomerHomeItemRegistry.items[itemId]!.label;

  CustomerHomeGroup copyWith({
    String? label,
    bool? enabled,
    int? order,
    List<String>? itemIds,
    Map<String, String>? itemLabels,
  }) => CustomerHomeGroup(
    id: id,
    label: label ?? this.label,
    enabled: enabled ?? this.enabled,
    order: order ?? this.order,
    itemIds: itemIds ?? this.itemIds,
    itemLabels: itemLabels ?? this.itemLabels,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label.trim(),
    'enabled': enabled,
    'order': order,
    'itemIds': itemIds
        .where(CustomerHomeItemRegistry.items.containsKey)
        .toList(),
    'itemLabels': itemLabels,
  };

  factory CustomerHomeGroup.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final base = defaults.firstWhere(
      (group) => group.id == id,
      orElse: () => defaults.first,
    );
    final rawIds = map['itemIds'];
    final ids = rawIds is List
        ? rawIds
              .map((value) => value.toString())
              .where(CustomerHomeItemRegistry.items.containsKey)
              .toSet()
              .toList()
        : base.itemIds;
    final labels = <String, String>{};
    if (map['itemLabels'] is Map) {
      (map['itemLabels'] as Map).forEach((key, value) {
        final itemId = key.toString();
        final label = value?.toString().trim() ?? '';
        if (CustomerHomeItemRegistry.items.containsKey(itemId) &&
            label.isNotEmpty) {
          labels[itemId] = label;
        }
      });
    }
    return CustomerHomeGroup(
      id: id.isEmpty ? base.id : id,
      label: map['label']?.toString().trim().isNotEmpty == true
          ? map['label'].toString().trim()
          : base.label,
      enabled: map['enabled'] is bool ? map['enabled'] as bool : base.enabled,
      order: map['order'] is num ? (map['order'] as num).toInt() : base.order,
      itemIds: ids,
      itemLabels: labels,
    );
  }

  static const List<CustomerHomeGroup> defaults = [
    CustomerHomeGroup(
      id: 'create',
      label: 'Create',
      enabled: true,
      order: 1,
      itemIds: [
        'design_custom',
        'quick_design',
        'kids_design',
        'design_daily',
        'design_office',
        'design_party',
        'design_wedding',
        'design_festive',
      ],
    ),
    CustomerHomeGroup(
      id: 'explore',
      label: 'Explore',
      enabled: true,
      order: 2,
      itemIds: ['catalogue', 'shop', 'accessories', 'wishlist'],
    ),
    CustomerHomeGroup(
      id: 'services',
      label: 'Services',
      enabled: true,
      order: 3,
      itemIds: ['custom_tailoring', 'quick_fix', 'garment_care', 'fabric_help'],
    ),
    CustomerHomeGroup(
      id: 'manage',
      label: 'Manage',
      enabled: true,
      order: 4,
      itemIds: ['measurements', 'orders', 'addresses'],
    ),
    CustomerHomeGroup(
      id: 'special',
      label: 'Special',
      enabled: true,
      order: 5,
      itemIds: ['rent_fabrics', 'bulk_orders', 'offers'],
    ),
  ];

  static List<CustomerHomeGroup> fromDocument(Map<String, dynamic>? data) {
    final raw = data?['groups'];
    if (raw is! List) return defaults;
    final schemaVersion = data?['schemaVersion'] is num
        ? (data!['schemaVersion'] as num).toInt()
        : 0;
    final byId = <String, CustomerHomeGroup>{};
    for (final value in raw) {
      if (value is Map) {
        var group = CustomerHomeGroup.fromMap(Map<String, dynamic>.from(value));
        if (schemaVersion < 2) {
          final labels = {...group.itemLabels};
          const previousDefaults = {
            'design_custom': 'Create a design',
            'shop': 'Shop & explore',
            'rent_fabrics': 'Rent & fabrics',
            'quick_fix': 'Quick fix',
            'garment_care': 'Garment care',
          };
          for (final entry in previousDefaults.entries) {
            if (labels[entry.key] == entry.value) {
              labels[entry.key] =
                  CustomerHomeItemRegistry.items[entry.key]!.label;
            }
          }
          group = group.copyWith(itemLabels: labels);
        }
        if (defaults.any((item) => item.id == group.id)) byId[group.id] = group;
      }
    }
    if (schemaVersion < 2) {
      final create = byId['create'];
      final services = byId['services'];
      if (services != null &&
          services.itemIds.contains('quick_fix') &&
          !services.itemIds.contains('custom_tailoring')) {
        final quickFixIndex = services.itemIds.indexOf('quick_fix');
        final itemIds = [...services.itemIds]
          ..insert(quickFixIndex, 'custom_tailoring');
        byId['services'] = services.copyWith(itemIds: itemIds);
      } else if (create != null &&
          create.itemIds.contains('design_custom') &&
          !create.itemIds.contains('custom_tailoring')) {
        final designIndex = create.itemIds.indexOf('design_custom');
        final itemIds = [...create.itemIds]
          ..insert(designIndex + 1, 'custom_tailoring');
        byId['create'] = create.copyWith(itemIds: itemIds);
      }

      final explore = byId['explore'];
      final special = byId['special'];
      if (explore != null &&
          special != null &&
          explore.itemIds.contains('rent_fabrics')) {
        byId['explore'] = explore.copyWith(
          itemIds: explore.itemIds.where((id) => id != 'rent_fabrics').toList(),
        );
        if (!special.itemIds.contains('rent_fabrics')) {
          byId['special'] = special.copyWith(
            itemIds: ['rent_fabrics', ...special.itemIds],
          );
        }
      }
    }
    return defaults.map((item) => byId[item.id] ?? item).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}

class CustomerHomeConfigurationService {
  CustomerHomeConfigurationService._();
  static final _document = FirebaseFirestore.instance
      .collection('config')
      .doc('customer_home');

  static Stream<List<CustomerHomeGroup>> watch() => _document.snapshots().map(
    (doc) => CustomerHomeGroup.fromDocument(doc.data()),
  );

  static Future<void> save(List<CustomerHomeGroup> groups) => _document.set({
    'schemaVersion': 2,
    'groups': groups.map((group) => group.toMap()).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
