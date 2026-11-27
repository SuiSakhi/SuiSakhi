class StitchingRate {
  final String dressType;
  double basePrice;
  double? customerPrice;
  bool customerPriceOverride;
  String? notes;

  StitchingRate({
    required this.dressType,
    required this.basePrice,
    this.customerPrice,
    this.customerPriceOverride = false,
    this.notes,
  });
}
