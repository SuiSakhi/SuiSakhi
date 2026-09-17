import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue_design_asset.dart';
import 'catalogue_processing_status.dart';

class CatalogueDesignVersion {
  const CatalogueDesignVersion({
    required this.versionId,
    required this.designId,
    required this.versionNumber,
    required this.originalAsset,
    this.normalizedPreviewAsset,
    this.structuredSvgAsset,
    this.thumbnailAsset,
    this.processing = const CatalogueProcessingResult(),
    this.submittedByUid,
    this.submittedAt,
    this.reviewedByUid,
    this.reviewedAt,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String versionId;
  final String designId;
  final int versionNumber;
  final CatalogueDesignAsset originalAsset;
  final CatalogueDesignAsset? normalizedPreviewAsset;
  final CatalogueDesignAsset? structuredSvgAsset;
  final CatalogueDesignAsset? thumbnailAsset;
  final CatalogueProcessingResult processing;
  final String? submittedByUid;
  final DateTime? submittedAt;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
    'versionId': versionId.trim(),
    'designId': designId.trim(),
    'versionNumber': versionNumber < 1 ? 1 : versionNumber,
    'originalAsset': originalAsset.toMap(),
    'normalizedPreviewAsset': normalizedPreviewAsset?.toMap(),
    'structuredSvgAsset': structuredSvgAsset?.toMap(),
    'thumbnailAsset': thumbnailAsset?.toMap(),
    'processing': processing.toMap(),
    'submittedByUid': _text(submittedByUid),
    'submittedAt': _timestamp(submittedAt),
    'reviewedByUid': _text(reviewedByUid),
    'reviewedAt': _timestamp(reviewedAt),
    'publishedAt': _timestamp(publishedAt),
    'createdAt': _timestamp(createdAt),
    'updatedAt': _timestamp(updatedAt),
  };

  factory CatalogueDesignVersion.fromMap(Map<String, dynamic> data) {
    final original = _map(data['originalAsset']);
    return CatalogueDesignVersion(
      versionId: data['versionId']?.toString().trim() ?? '',
      designId: data['designId']?.toString().trim() ?? '',
      versionNumber: _int(data['versionNumber']) ?? 1,
      originalAsset: CatalogueDesignAsset.fromMap(original),
      normalizedPreviewAsset: _asset(data['normalizedPreviewAsset']),
      structuredSvgAsset: _asset(data['structuredSvgAsset']),
      thumbnailAsset: _asset(data['thumbnailAsset']),
      processing: CatalogueProcessingResult.fromMap(_map(data['processing'])),
      submittedByUid: _text(data['submittedByUid']?.toString()),
      submittedAt: _date(data['submittedAt']),
      reviewedByUid: _text(data['reviewedByUid']?.toString()),
      reviewedAt: _date(data['reviewedAt']),
      publishedAt: _date(data['publishedAt']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static CatalogueDesignAsset? _asset(Object? value) {
    final map = _map(value);
    return map.isEmpty ? null : CatalogueDesignAsset.fromMap(map);
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);

  static DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String? _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
