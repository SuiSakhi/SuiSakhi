import 'package:image_picker/image_picker.dart';

class CatalogueUploadValidation {
  const CatalogueUploadValidation._({
    required this.accepted,
    this.errorMessage,
    this.extension,
    this.contentType,
    this.byteSize,
  });

  const CatalogueUploadValidation.accepted({
    required String extension,
    required String contentType,
    required int byteSize,
  }) : this._(
         accepted: true,
         extension: extension,
         contentType: contentType,
         byteSize: byteSize,
       );

  const CatalogueUploadValidation.rejected(String message)
    : this._(accepted: false, errorMessage: message);

  final bool accepted;
  final String? errorMessage;
  final String? extension;
  final String? contentType;
  final int? byteSize;
}

class CatalogueUploadPolicy {
  CatalogueUploadPolicy._();

  static const int maxOriginalBytes = 12 * 1024 * 1024;
  static const Set<String> acceptedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const Set<String> acceptedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static Future<CatalogueUploadValidation> validate(XFile file) async {
    final extension = extensionFor(file.path);
    if (!acceptedExtensions.contains(extension)) {
      return const CatalogueUploadValidation.rejected(
        'Phase-1 Catalogue uploads support JPG, JPEG, PNG and WebP only.',
      );
    }

    final contentType = normalizedContentType(
      mimeType: file.mimeType,
      extension: extension,
    );
    if (!acceptedContentTypes.contains(contentType)) {
      return const CatalogueUploadValidation.rejected(
        'The selected file is not an accepted Catalogue image.',
      );
    }

    final size = await file.length();
    if (size <= 0) {
      return const CatalogueUploadValidation.rejected(
        'The selected file is empty.',
      );
    }
    if (size > maxOriginalBytes) {
      return const CatalogueUploadValidation.rejected(
        'The selected file is larger than the 12 MB Phase-1 limit.',
      );
    }

    return CatalogueUploadValidation.accepted(
      extension: extension,
      contentType: contentType,
      byteSize: size,
    );
  }

  static String extensionFor(String path) {
    final normalized = path.trim().toLowerCase();
    final dot = normalized.lastIndexOf('.');
    return dot < 0 ? '' : normalized.substring(dot + 1);
  }

  static String normalizedContentType({
    required String extension,
    String? mimeType,
  }) {
    final mime = mimeType?.trim().toLowerCase() ?? '';
    if (acceptedContentTypes.contains(mime)) return mime;
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
