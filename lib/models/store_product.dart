import 'package:cloud_firestore/cloud_firestore.dart';

class StoreProductCategory {
  const StoreProductCategory(this.code, this.label);

  final String code;
  final String label;

  static const readyToWear = StoreProductCategory(
    'ready_to_wear',
    'Ready-to-wear',
  );
  static const fabric = StoreProductCategory('fabric', 'Fabric');
  static const accessories = StoreProductCategory(
    'accessories',
    'Accessories',
  );
  static const kidsFashion = StoreProductCategory(
    'kids_fashion',
    'Kids fashion',
  );

  static const all = [readyToWear, fabric, accessories, kidsFashion];

  static StoreProductCategory byCode(String code) => all.firstWhere(
    (category) => category.code == code,
    orElse: () => readyToWear,
  );
}

class StoreProductImage {
  const StoreProductImage({required this.view, required this.url});

  final String view;
  final String url;

  Map<String, dynamic> toMap() => {'view': view, 'url': url};

  factory StoreProductImage.fromMap(Map<String, dynamic> data) =>
      StoreProductImage(
        view: (data['view'] ?? '').toString(),
        url: (data['url'] ?? '').toString(),
      );
}

class StoreProduct {
  const StoreProduct({
    required this.productId,
    required this.partnerAccountId,
    required this.partnerProfileId,
    required this.partnerType,
    required this.sellerName,
    required this.name,
    required this.description,
    required this.categoryCode,
    required this.subcategory,
    required this.priceInr,
    required this.stockQuantity,
    required this.status,
    this.discountPriceInr,
    this.brandName = '',
    this.unit = 'piece',
    this.fabricComposition = '',
    this.fabricWidth = '',
    this.minimumQuantity = 1,
    this.sizes = const [],
    this.colors = const [],
    this.images = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String productId;
  final String partnerAccountId;
  final String partnerProfileId;
  final String partnerType;
  final String sellerName;
  final String name;
  final String description;
  final String categoryCode;
  final String subcategory;
  final double priceInr;
  final double? discountPriceInr;
  final int stockQuantity;
  final String status;
  final String brandName;
  final String unit;
  final String fabricComposition;
  final String fabricWidth;
  final int minimumQuantity;
  final List<String> sizes;
  final List<String> colors;
  final List<StoreProductImage> images;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StoreProductCategory get category =>
      StoreProductCategory.byCode(categoryCode);

  double get displayPrice => discountPriceInr ?? priceInr;

  factory StoreProduct.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final rawImages = data['images'];
    return StoreProduct(
      productId: document.id,
      partnerAccountId: (data['partnerAccountId'] ?? '').toString(),
      partnerProfileId: (data['partnerProfileId'] ?? '').toString(),
      partnerType: (data['partnerType'] ?? '').toString(),
      sellerName: (data['sellerName'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      categoryCode: (data['categoryCode'] ?? '').toString(),
      subcategory: (data['subcategory'] ?? '').toString(),
      priceInr: _number(data['priceInr']),
      discountPriceInr: data['discountPriceInr'] == null
          ? null
          : _number(data['discountPriceInr']),
      stockQuantity: _integer(data['stockQuantity']),
      status: (data['status'] ?? 'draft').toString(),
      brandName: (data['brandName'] ?? '').toString(),
      unit: (data['unit'] ?? 'piece').toString(),
      fabricComposition: (data['fabricComposition'] ?? '').toString(),
      fabricWidth: (data['fabricWidth'] ?? '').toString(),
      minimumQuantity: _integer(data['minimumQuantity'], fallback: 1),
      sizes: _strings(data['sizes']),
      colors: _strings(data['colors']),
      images: rawImages is List
          ? rawImages
                .whereType<Map>()
                .map((image) => StoreProductImage.fromMap(
                  Map<String, dynamic>.from(image),
                ))
                .where((image) => image.url.trim().isNotEmpty)
                .toList(growable: false)
          : const [],
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFields() => {
    'partnerAccountId': partnerAccountId,
    'partnerProfileId': partnerProfileId,
    'partnerType': partnerType,
    'sellerName': sellerName,
    'name': name.trim(),
    'description': description.trim(),
    'categoryCode': categoryCode,
    'categoryLabel': category.label,
    'subcategory': subcategory.trim(),
    'priceInr': priceInr,
    'discountPriceInr': discountPriceInr,
    'stockQuantity': stockQuantity,
    'status': status,
    'brandName': brandName.trim(),
    'unit': unit,
    'fabricComposition': fabricComposition.trim(),
    'fabricWidth': fabricWidth.trim(),
    'minimumQuantity': minimumQuantity,
    'sizes': sizes,
    'colors': colors,
    'images': images.map((image) => image.toMap()).toList(growable: false),
  };

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _integer(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static List<String> _strings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  static DateTime? _date(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
}
