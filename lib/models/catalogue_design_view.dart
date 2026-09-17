import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue_design_asset.dart';
import 'catalogue_processing_status.dart';

enum CatalogueDesignViewType {
  front,
  back,
  side,
  detail,
  combinedFrontBack,
  singleView,
}

extension CatalogueDesignViewTypeX on CatalogueDesignViewType {
  bool get canBePrimary =>
      this == CatalogueDesignViewType.front ||
      this == CatalogueDesignViewType.combinedFrontBack ||
      this == CatalogueDesignViewType.singleView;

  String get label {
    switch (this) {
      case CatalogueDesignViewType.front:
        return 'Front';
      case CatalogueDesignViewType.back:
        return 'Back';
      case CatalogueDesignViewType.side:
        return 'Side';
      case CatalogueDesignViewType.detail:
        return 'Detail';
      case CatalogueDesignViewType.combinedFrontBack:
        return 'Combined Front + Back';
      case CatalogueDesignViewType.singleView:
        return 'Single View';
    }
  }
}

class CatalogueDesignView {
  const CatalogueDesignView({
    required this.viewId,
    required this.designId,
    required this.versionId,
    required this.viewType,
    required this.displayOrder,
    required this.isPrimary,
    required this.originalAsset,
    this.title,
    this.normalizedPreviewAsset,
    this.structuredSvgAsset,
    this.thumbnailAsset,
    this.processing = const CatalogueProcessingResult(),
    this.createdAt,
    this.updatedAt,
  });

  final String viewId;
  final String designId;
  final String versionId;
  final CatalogueDesignViewType viewType;
  final int displayOrder;
  final bool isPrimary;
  final String? title;
  final CatalogueDesignAsset originalAsset;
  final CatalogueDesignAsset? normalizedPreviewAsset;
  final CatalogueDesignAsset? structuredSvgAsset;
  final CatalogueDesignAsset? thumbnailAsset;
  final CatalogueProcessingResult processing;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get bestPreviewUrl =>
      thumbnailAsset?.downloadUrl ??
      normalizedPreviewAsset?.downloadUrl ??
      structuredSvgAsset?.downloadUrl ??
      originalAsset.downloadUrl;

  Map<String, dynamic> toMap() => {
    'viewId': viewId.trim(),
    'designId': designId.trim(),
    'versionId': versionId.trim(),
    'viewType': viewType.name,
    'displayOrder': displayOrder < 1 ? 1 : displayOrder,
    'isPrimary': isPrimary,
    'title': _text(title),
    'originalAsset': originalAsset.toMap(),
    'normalizedPreviewAsset': normalizedPreviewAsset?.toMap(),
    'structuredSvgAsset': structuredSvgAsset?.toMap(),
    'thumbnailAsset': thumbnailAsset?.toMap(),
    'processing': processing.toMap(),
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };

  factory CatalogueDesignView.fromMap(Map<String, dynamic> data) {
    return CatalogueDesignView(
      viewId: data['viewId']?.toString().trim() ?? '',
      designId: data['designId']?.toString().trim() ?? '',
      versionId: data['versionId']?.toString().trim() ?? '',
      viewType: CatalogueDesignViewType.values.firstWhere(
        (item) => item.name == data['viewType']?.toString(),
        orElse: () => CatalogueDesignViewType.singleView,
      ),
      displayOrder: _int(data['displayOrder']) ?? 1,
      isPrimary: data['isPrimary'] == true,
      title: _text(data['title']?.toString()),
      originalAsset: CatalogueDesignAsset.fromMap(_map(data['originalAsset'])),
      normalizedPreviewAsset: _asset(data['normalizedPreviewAsset']),
      structuredSvgAsset: _asset(data['structuredSvgAsset']),
      thumbnailAsset: _asset(data['thumbnailAsset']),
      processing: CatalogueProcessingResult.fromMap(_map(data['processing'])),
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
