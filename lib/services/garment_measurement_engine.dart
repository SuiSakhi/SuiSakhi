import '../models/design_metadata.dart';
import '../models/measurement.dart';
import '../models/occasion_metadata.dart';

class GarmentMeasurementEstimate {
  final String dressType;
  final String fitPreference;
  final String formulaVersion;
  final Map<String, double> valuesCm;
  final List<String> notes;

  const GarmentMeasurementEstimate({
    required this.dressType,
    required this.fitPreference,
    required this.formulaVersion,
    required this.valuesCm,
    required this.notes,
  });
}

class GarmentMeasurementEngine {
  GarmentMeasurementEngine._();

  static const String formulaVersion = 'v1';

  static GarmentMeasurementEstimate estimate({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final normalizedDressType = dressType.trim().toLowerCase();

    if (normalizedDressType.contains('shirt')) {
      return _estimateShirt(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }
    
    if (normalizedDressType.contains('anarkali')) {
      return _estimateAnarkaliSuit(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }


    if (normalizedDressType.contains('kurti') ||
        normalizedDressType.contains('kurta')) {
      return _estimateKurti(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('saree blouse') ||
        normalizedDressType == 'blouse' ||
        normalizedDressType.contains('blouse')) {
      return _estimateBlouse(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('lehenga')) {
      return _estimateLehengaCholi(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }


    if (normalizedDressType.contains('gown')) {
      return _estimateGown(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('palazzo') ||
        normalizedDressType.contains('pant')) {
      return _estimatePalazzoPant(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('top') ||
        normalizedDressType.contains('tunic')) {
      return _estimateTopTunic(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('skirt')) {
      return _estimateSkirt(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }

    if (normalizedDressType.contains('salwar')) {
      return _estimateSalwarSuit(
        body: body,
        dressType: dressType,
        fitPreference: fitPreference,
        occasionCategory: occasionCategory,
        designTitle: designTitle,
        designMetadata: designMetadata,
        occasionMetadata: occasionMetadata,
      );
    }


    return _estimateGeneric(
      body: body,
      dressType: dressType,
      fitPreference: fitPreference,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
      designMetadata: designMetadata,
      occasionMetadata: occasionMetadata,
    );
  }

  static GarmentMeasurementEstimate _estimateShirt({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;
    final values = <String, double>{};

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.95));

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(
      values,
      'Length',
      _ratioValue(body.height, 0.42 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Shirt length is estimated from body height using formula v1.',
        'Final garment length should be customer or tailor confirmed.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateAnarkaliSuit({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
        occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.95));
    _putIfPositive(
      values,
      'Anarkali Length',
      _ratioValue(body.height, 0.72 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Anarkali Suit uses a longer length and flare-aware formula.',
        'Flare, lining / astar and embroidery complexity should be reviewed during fabric estimation.',
        'Final Anarkali length should be confirmed by customer or tailor.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateKurti({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
        final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );
    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;
    final values = <String, double>{};

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.95));
       final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(
      values,
      'Length',
      _ratioValue(body.height, 0.52 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Kurti length is estimated from body height using formula v1.',
        'Kurti length varies by customer preference and should be confirmed.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }
  
    static GarmentMeasurementEstimate _estimateLehengaCholi({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );
    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;
    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.80));
    _putIfPositive(values, 'Blouse Length', _ratioValue(body.height, 0.22));
    _putIfPositive(
      values,
      'Lehenga Length',
      _ratioValue(body.height, 0.58 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Lehenga Choli uses separate blouse and lehenga length estimates.',
        'Lehenga flare, lining and embroidery complexity should be reviewed during fabric estimation.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateBlouse({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    // Blouse usually needs closer fit than kurti/gown.
    final ease = (_easeCm(fitPreference) * 0.55) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.55));
    _putIfPositive(values, 'Blouse Length', _ratioValue(body.height, 0.22));

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Blouse measurements use a closer-fit formula and should be tailor confirmed.',
        'Neck depth, back design, padding, lining and margin should be captured in Dress Customization.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateGown({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
        final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );
    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;
    final values = <String, double>{};

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.95));
    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(
      values,
      'Length',
      _ratioValue(body.height, 0.90 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Gown length is estimated from body height using formula v1.',
        'Gown flare, lining and design complexity must be handled by fabric estimation.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimatePalazzoPant({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
        occasionMetadata?.easeMultiplier ?? 1.0;

    // Bottom wear usually needs comfortable waist/hip ease.
    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Thigh', _addEase(body.thigh, ease * 0.60));
    _putIfPositive(values, 'Inseam', body.inseam);

    // Prefer inseam if available. Otherwise estimate pant length from height.
    if (body.inseam != null && body.inseam! > 0) {
      _putIfPositive(values, 'Pant Length', body.inseam);
    } else {
      _putIfPositive(
        values,
        'Pant Length',
        _ratioValue(body.height, 0.55 * lengthMultiplier),
      );
    }

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Palazzo / Pant measurements use bottom-wear waist, hip and length guidance.',
        'Thigh and inseam should be customer or tailor confirmed for accurate fitting.',
        'Pant length may vary by footwear, heel height and customer preference.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateTopTunic({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
        occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease * 0.80));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.85));
    _putIfPositive(
      values,
      'Top Length',
      _ratioValue(body.height, 0.38 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Top / Tunic uses upper-body measurements with shorter garment length guidance.',
        'Final top length should be customer or tailor confirmed.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateSkirt({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
        occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(
      values,
      'Skirt Length',
      _ratioValue(body.height, 0.55 * lengthMultiplier),
    );

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Skirt measurements use waist, hip and skirt length guidance.',
        'Skirt length depends on design, footwear, lining and customer preference.',
        'Flare and lining should be reviewed during fabric estimation.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

    static GarmentMeasurementEstimate _estimateSalwarSuit({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
    final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    final occasionEaseMultiplier =
        occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;

    final values = <String, double>{};

    final lengthMultiplier = _lengthMultiplierForContext(
      dressType: dressType,
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', _ratioValue(body.armLength, 0.95));
    _putIfPositive(
      values,
      'Kameez Length',
      _ratioValue(body.height, 0.52 * lengthMultiplier),
    );
    _putIfPositive(values, 'Bottom Inseam', body.inseam);

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Salwar Suit uses kameez and bottom-wear measurement guidance.',
        'Bottom inseam and salwar style should be customer or tailor confirmed.',
        'Dupatta, lining and fabric allowance should be reviewed during estimation.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static GarmentMeasurementEstimate _estimateGeneric({
    required BodyMeasurements body,
    required String dressType,
    required String fitPreference,
    String? occasionCategory,
    String? designTitle,
    DesignMetadata? designMetadata,
    OccasionMetadata? occasionMetadata,
  }) {
        final contextEaseMultiplier = _easeMultiplierForContext(
      occasionCategory: occasionCategory,
      designTitle: designTitle,
    );
    final occasionEaseMultiplier =
      occasionMetadata?.easeMultiplier ?? 1.0;

    final ease = _easeCm(fitPreference) *
        contextEaseMultiplier *
        occasionEaseMultiplier;
    final values = <String, double>{};

    _putIfPositive(values, 'Chest', _addEase(body.chest, ease));
    _putIfPositive(values, 'Waist', _addEase(body.waist, ease));
    _putIfPositive(values, 'Hip', _addEase(body.hips, ease));
    _putIfPositive(values, 'Shoulder', body.shoulder);
    _putIfPositive(values, 'Sleeve Length', body.armLength);

    return GarmentMeasurementEstimate(
      dressType: dressType,
      fitPreference: fitPreference,
      formulaVersion: formulaVersion,
      valuesCm: values,
      notes: [
        'Generic estimate does not derive garment length.',
        'Dress-specific formula should be added for accurate length and fabric estimation.',
        ..._heightGuidanceNotes(body),
        ..._contextNotes(
          occasionCategory: occasionCategory,
          designTitle: designTitle,
        ),
        ..._designMetadataNotes(designMetadata),
        ..._occasionMetadataNotes(occasionMetadata),
      ],
    );
  }

  static double _easeMultiplierForContext({
    String? occasionCategory,
    String? designTitle,
  }) {
    final occasion = (occasionCategory ?? '').trim().toLowerCase();
    final design = (designTitle ?? '').trim().toLowerCase();

    double multiplier = 1.0;

    if (occasion.contains('daily')) {
      multiplier += 0.00;
    } else if (occasion.contains('office')) {
      multiplier += 0.02;
    } else if (occasion.contains('party')) {
      multiplier += 0.04;
    } else if (occasion.contains('festive')) {
      multiplier += 0.05;
    } else if (occasion.contains('wedding') || occasion.contains('bridal')) {
      multiplier += 0.07;
    }

    if (design.isNotEmpty) {
      multiplier += 0.02;
    }

    if (design.contains('anarkali') ||
        design.contains('flare') ||
        design.contains('gown') ||
        design.contains('heavy') ||
        design.contains('bridal')) {
      multiplier += 0.04;
    }

    if (design.contains('slim') ||
        design.contains('straight') ||
        design.contains('short') ||
        design.contains('crop')) {
      multiplier -= 0.02;
    }

    return multiplier.clamp(0.90, 1.15);
  }

  static double _lengthMultiplierForContext({
    required String dressType,
    String? occasionCategory,
    String? designTitle,
  }) {
    final dress = dressType.trim().toLowerCase();
    final occasion = (occasionCategory ?? '').trim().toLowerCase();
    final design = (designTitle ?? '').trim().toLowerCase();

    double multiplier = 1.0;

    if (occasion.contains('daily')) {
      multiplier += 0.00;
    } else if (occasion.contains('office')) {
      multiplier += 0.02;
    } else if (occasion.contains('party')) {
      multiplier += 0.05;
    } else if (occasion.contains('festive')) {
      multiplier += 0.06;
    } else if (occasion.contains('wedding') || occasion.contains('bridal')) {
      multiplier += 0.10;
    }

    if (design.isNotEmpty) {
      multiplier += 0.03;
    }

    if (design.contains('long') ||
        design.contains('anarkali') ||
        design.contains('gown') ||
        design.contains('floor') ||
        design.contains('flare') ||
        design.contains('bridal')) {
      multiplier += 0.08;
    }

    if (design.contains('short') || design.contains('crop')) {
      multiplier -= 0.08;
    }

    if (dress.contains('gown')) {
      multiplier += 0.04;
    }

    return multiplier.clamp(0.85, 1.20);
  }
  
    static List<String> _heightGuidanceNotes(BodyMeasurements body) {
    if (body.height != null && body.height! > 0) {
      return const [];
    }

    return const [
      'Height is missing. Please update profile height for better length estimation.',
    ];
  }

  static List<String> _designMetadataNotes(DesignMetadata? metadata) {
    if (metadata == null) {
      return const [];
    }

    final silhouetteText = _silhouetteLabel(metadata.silhouette);

    final complexityText = switch (metadata.complexity) {
      DesignComplexity.low => 'low complexity',
      DesignComplexity.medium => 'medium complexity',
      DesignComplexity.high => 'high complexity',
    };

    final liningText = metadata.liningRequired
        ? 'lining recommended'
        : 'lining usually not required';

    return [
      'Design details considered: $silhouetteText, $complexityText, $liningText.',
    ];
  }

    static List<String> _occasionMetadataNotes(OccasionMetadata? metadata) {
    if (metadata == null) {
      return const [];
    }

    final notes = <String>[];

    if (metadata.liningRecommended) {
      notes.add('Occasion guidance: lining / astar may be recommended.');
    }

    if (metadata.tailorReviewRecommended) {
      notes.add(
        'Occasion guidance: tailor review is recommended before stitching.',
      );
    }

    notes.addAll(metadata.notes);

    return notes;
  }
  
  static String _silhouetteLabel(DesignSilhouette silhouette) {
    switch (silhouette) {
      case DesignSilhouette.straight:
        return 'Straight silhouette';
      case DesignSilhouette.aLine:
        return 'A-line silhouette';
      case DesignSilhouette.anarkali:
        return 'Anarkali silhouette';
      case DesignSilhouette.fitAndFlare:
        return 'Fit & flare silhouette';
      case DesignSilhouette.gathered:
        return 'Gathered silhouette';
      case DesignSilhouette.layered:
        return 'Layered silhouette';
      case DesignSilhouette.umbrella:
        return 'Umbrella silhouette';
      case DesignSilhouette.princessCut:
        return 'Princess cut';
      case DesignSilhouette.other:
        return 'Custom silhouette';
    }
  }

  static List<String> _contextNotes({
    String? occasionCategory,
    String? designTitle,
  }) {
    final notes = <String>[];

    if (occasionCategory != null && occasionCategory.trim().isNotEmpty) {
      notes.add(
        'Occasion/category considered in ease and length formula: ${occasionCategory.trim()}.',
      );
    }

    if (designTitle != null && designTitle.trim().isNotEmpty) {
      notes.add(
        'Selected design considered in ease and length formula: ${designTitle.trim()}.',
      );
    }

    return notes;
  }

  static double _easeCm(String fitPreference) {
    switch (fitPreference.trim().toLowerCase()) {
      case 'slim':
        return 4;
      case 'loose':
        return 8;
      case 'regular':
      default:
        return 6;
    }
  }

  static double? _addEase(double? value, double ease) {
    if (value == null || value <= 0) return null;
    return value + ease;
  }

  static double? _ratioValue(double? value, double ratio) {
    if (value == null || value <= 0) return null;
    return value * ratio;
  }

  static void _putIfPositive(
    Map<String, double> values,
    String key,
    double? value,
  ) {
    if (value == null || value <= 0) return;
    values[key] = double.parse(value.toStringAsFixed(1));
  }
}
