import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/models/stitching_rate.dart';

void main() {
  group('StitchingRate', () {
    test('creates with required fields', () {
      final rate = StitchingRate(dressType: 'Kurti', basePrice: 350.0);
      expect(rate.dressType, 'Kurti');
      expect(rate.basePrice, 350.0);
      expect(rate.notes, isNull);
    });

    test('creates with optional notes', () {
      final rate = StitchingRate(
        dressType: 'Lehenga',
        basePrice: 1200.0,
        notes: 'Heavy embroidery adds extra cost',
      );
      expect(rate.notes, 'Heavy embroidery adds extra cost');
    });

    test('basePrice is mutable', () {
      final rate = StitchingRate(dressType: 'Blouse', basePrice: 200.0);
      rate.basePrice = 250.0;
      expect(rate.basePrice, 250.0);
    });

    test('notes is mutable', () {
      final rate = StitchingRate(dressType: 'Shirt', basePrice: 300.0);
      expect(rate.notes, isNull);
      rate.notes = 'Cotton only';
      expect(rate.notes, 'Cotton only');
    });

    test('default dress types have reasonable prices', () {
      final defaults = [
        StitchingRate(dressType: 'Kurti', basePrice: 350),
        StitchingRate(dressType: 'Blouse', basePrice: 200),
        StitchingRate(dressType: 'Salwar Suit', basePrice: 600),
        StitchingRate(dressType: 'Lehenga', basePrice: 1200),
        StitchingRate(dressType: 'Gown', basePrice: 1500),
        StitchingRate(dressType: 'Sherwani', basePrice: 2000),
      ];
      for (final rate in defaults) {
        expect(rate.basePrice, greaterThan(0));
        expect(rate.dressType, isNotEmpty);
      }
    });

    test('Sherwani costs more than Blouse', () {
      final sherwani = StitchingRate(dressType: 'Sherwani', basePrice: 2000);
      final blouse = StitchingRate(dressType: 'Blouse', basePrice: 200);
      expect(sherwani.basePrice, greaterThan(blouse.basePrice));
    });
  });
}
