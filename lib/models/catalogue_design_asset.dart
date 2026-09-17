import 'package:cloud_firestore/cloud_firestore.dart';

enum CatalogueAssetType {
  original,
  normalizedPreview,
  structuredSvg,
  thumbnail,
}

class CatalogueDesignAsset {
  const CatalogueDesignAsset({
    required this.assetType,
    required this.storagePath,
    required this.mimeType,
    required this.byteSize,
    this.downloadUrl,
    this.width,
    this.height,
    this.sha256,
    this.createdAt,
  });

  final CatalogueAssetType assetType;
  final String storagePath;
  final String mimeType;
  final int byteSize;
  final String? downloadUrl;
  final int? width;
  final int? height;
  final String? sha256;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
    'assetType': assetType.name,
    'storagePath': storagePath.trim(),
    'mimeType': mimeType.trim().toLowerCase(),
    'byteSize': byteSize < 0 ? 0 : byteSize,
    'downloadUrl': _text(downloadUrl),
    'width': _nonNegative(width),
    'height': _nonNegative(height),
    'sha256': _text(sha256),
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
  };

  factory CatalogueDesignAsset.fromMap(Map<String, dynamic> data) {
    return CatalogueDesignAsset(
      assetType: CatalogueAssetType.values.firstWhere(
        (value) => value.name == data['assetType']?.toString(),
        orElse: () => CatalogueAssetType.original,
      ),
      storagePath: data['storagePath']?.toString().trim() ?? '',
      mimeType: data['mimeType']?.toString().trim().toLowerCase() ?? '',
      byteSize: _int(data['byteSize']) ?? 0,
      downloadUrl: _text(data['downloadUrl']?.toString()),
      width: _int(data['width']),
      height: _int(data['height']),
      sha256: _text(data['sha256']?.toString()),
      createdAt: _date(data['createdAt']),
    );
  }

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  static int? _nonNegative(int? value) =>
      value == null || value < 0 ? null : value;

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
