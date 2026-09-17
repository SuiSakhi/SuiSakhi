enum CatalogueProcessingStatus {
  notRequested,
  queued,
  processing,
  completed,
  manualReviewRequired,
  failed,
  approved,
  rejected,
  superseded,
}

enum CatalogueSvgLayer {
  outline,
  bodyFill,
  sleevesFill,
  borderFill,
  motifFill,
  stitchGuides,
}

class CatalogueProcessingResult {
  const CatalogueProcessingResult({
    this.status = CatalogueProcessingStatus.notRequested,
    this.profileCode = 'suisakhiStructuredSvgV1',
    this.presentLayers = const [],
    this.missingLayers = const [],
    this.qualityWarnings = const [],
    this.qualityScore,
    this.pathCount,
    this.svgByteSize,
    this.processingEngine,
    this.processingVersion,
    this.processedAt,
    this.failureCode,
    this.failureMessage,
  });

  final CatalogueProcessingStatus status;
  final String profileCode;
  final List<CatalogueSvgLayer> presentLayers;
  final List<CatalogueSvgLayer> missingLayers;
  final List<String> qualityWarnings;
  final double? qualityScore;
  final int? pathCount;
  final int? svgByteSize;
  final String? processingEngine;
  final String? processingVersion;
  final DateTime? processedAt;
  final String? failureCode;
  final String? failureMessage;

  bool get manualReviewRequired =>
      status == CatalogueProcessingStatus.manualReviewRequired;

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'profileCode': profileCode.trim(),
    'presentLayers': presentLayers.map((item) => item.name).toList(),
    'missingLayers': missingLayers.map((item) => item.name).toList(),
    'qualityWarnings': qualityWarnings
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(),
    'qualityScore': qualityScore,
    'pathCount': pathCount,
    'svgByteSize': svgByteSize,
    'processingEngine': _text(processingEngine),
    'processingVersion': _text(processingVersion),
    'processedAt': processedAt?.toIso8601String(),
    'failureCode': _text(failureCode),
    'failureMessage': _text(failureMessage),
  };

  factory CatalogueProcessingResult.fromMap(Map<String, dynamic> data) {
    return CatalogueProcessingResult(
      status: CatalogueProcessingStatus.values.firstWhere(
        (item) => item.name == data['status']?.toString(),
        orElse: () => CatalogueProcessingStatus.notRequested,
      ),
      profileCode:
          _text(data['profileCode']?.toString()) ?? 'suisakhiStructuredSvgV1',
      presentLayers: _layers(data['presentLayers']),
      missingLayers: _layers(data['missingLayers']),
      qualityWarnings: _strings(data['qualityWarnings']),
      qualityScore: _double(data['qualityScore']),
      pathCount: _int(data['pathCount']),
      svgByteSize: _int(data['svgByteSize']),
      processingEngine: _text(data['processingEngine']?.toString()),
      processingVersion: _text(data['processingVersion']?.toString()),
      processedAt: DateTime.tryParse(data['processedAt']?.toString() ?? ''),
      failureCode: _text(data['failureCode']?.toString()),
      failureMessage: _text(data['failureMessage']?.toString()),
    );
  }

  static List<CatalogueSvgLayer> _layers(Object? value) {
    if (value is! List) return const [];
    return value
        .map(
          (raw) => CatalogueSvgLayer.values.where(
            (item) => item.name == raw.toString(),
          ),
        )
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .toSet()
        .toList();
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static double? _double(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
