import 'package:flutter_test/flutter_test.dart';
import 'package:stitchsmart/models/measurement.dart';

void main() {
  group('BodyMeasurements', () {
    test('creates with all fields null except capturedAt', () {
      final m = BodyMeasurements(capturedAt: DateTime(2024, 1, 1));
      expect(m.chest, isNull);
      expect(m.waist, isNull);
      expect(m.hips, isNull);
      expect(m.shoulder, isNull);
      expect(m.armLength, isNull);
      expect(m.inseam, isNull);
      expect(m.height, isNull);
      expect(m.neck, isNull);
      expect(m.thigh, isNull);
    });

    test('stores explicit values correctly', () {
      final m = BodyMeasurements(
        chest: 86,
        waist: 68,
        hips: 92,
        shoulder: 38,
        armLength: 58,
        inseam: 74,
        height: 162,
        neck: 34,
        thigh: 54,
        capturedAt: DateTime(2024, 6, 15),
      );
      expect(m.chest, 86);
      expect(m.waist, 68);
      expect(m.hips, 92);
      expect(m.shoulder, 38);
      expect(m.armLength, 58);
      expect(m.inseam, 74);
      expect(m.height, 162);
      expect(m.neck, 34);
      expect(m.thigh, 54);
    });

    test('stores capturedAt correctly', () {
      final date = DateTime(2024, 3, 10, 14, 30);
      final m = BodyMeasurements(capturedAt: date);
      expect(m.capturedAt, date);
    });
  });

  group('BodyMeasurements.sampleFemale', () {
    late BodyMeasurements female;
    setUp(() => female = BodyMeasurements.sampleFemale);

    test('chest is 86', () => expect(female.chest, 86));
    test('waist is 68', () => expect(female.waist, 68));
    test('hips is 92', () => expect(female.hips, 92));
    test('shoulder is 38', () => expect(female.shoulder, 38));
    test('height is 162', () => expect(female.height, 162));
    test('neck is 34', () => expect(female.neck, 34));
    test('thigh is 54', () => expect(female.thigh, 54));

    test('all fields are non-null', () {
      expect(female.chest, isNotNull);
      expect(female.waist, isNotNull);
      expect(female.hips, isNotNull);
      expect(female.shoulder, isNotNull);
      expect(female.armLength, isNotNull);
      expect(female.height, isNotNull);
      expect(female.neck, isNotNull);
      expect(female.thigh, isNotNull);
      expect(female.inseam, isNotNull);
    });

    test('hips are larger than waist (hourglass check)', () {
      expect(female.hips!, greaterThan(female.waist!));
    });
  });

  group('BodyMeasurements.sampleMale', () {
    late BodyMeasurements male;
    setUp(() => male = BodyMeasurements.sampleMale);

    test('chest is 98', () => expect(male.chest, 98));
    test('waist is 82', () => expect(male.waist, 82));
    test('height is 175', () => expect(male.height, 175));

    test('male chest is larger than female chest', () {
      expect(male.chest!, greaterThan(BodyMeasurements.sampleFemale.chest!));
    });

    test('male height is greater than female height', () {
      expect(male.height!, greaterThan(BodyMeasurements.sampleFemale.height!));
    });

    test('male shoulder is wider than female shoulder', () {
      expect(male.shoulder!, greaterThan(BodyMeasurements.sampleFemale.shoulder!));
    });
  });

  group('DressMeasurement', () {
    test('creates with required fields', () {
      final dm = DressMeasurement(
        dressType: 'Kurti',
        measurements: {'chest': 86.0, 'waist': 68.0},
        createdAt: DateTime(2024, 1, 1),
      );
      expect(dm.dressType, 'Kurti');
      expect(dm.measurements['chest'], 86.0);
      expect(dm.measurements['waist'], 68.0);
      expect(dm.notes, isNull);
    });

    test('creates with optional notes', () {
      final dm = DressMeasurement(
        dressType: 'Saree Blouse',
        measurements: {'bust': 90.0},
        notes: 'Backless design',
        createdAt: DateTime(2024, 1, 1),
      );
      expect(dm.notes, 'Backless design');
    });

    test('measurements map can be empty', () {
      final dm = DressMeasurement(
        dressType: 'Unknown',
        measurements: {},
        createdAt: DateTime.now(),
      );
      expect(dm.measurements, isEmpty);
    });
  });
}
