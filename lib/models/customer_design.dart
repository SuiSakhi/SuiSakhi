import 'package:cloud_firestore/cloud_firestore.dart';

enum CustomerDesignStatus { active, archived }

class CustomerDesign {
  const CustomerDesign({
    required this.id,
    required this.accountId,
    required this.profileId,
    required this.title,
    required this.imageUrl,
    required this.dressType,
    required this.status,
    required this.createdAt,
    this.thumbnailUrl,
    this.occasionId,
    this.notes,
    this.updatedAt,
  });

  final String id;

  /// Generated SuiSakhi account identifier.
  final String accountId;

  /// Profile that owns this uploaded design.
  ///
  /// Customer-uploaded designs are profile-owned by default.
  final String profileId;

  /// Customer-friendly design title.
  final String title;

  /// Full-resolution design reference image.
  final String imageUrl;

  /// Optional smaller image for catalog and picker views.
  final String? thumbnailUrl;

  /// Dress type selected when the design was uploaded.
  ///
  /// Examples:
  /// Kurti
  /// Gown
  /// Lehenga Choli
  final String dressType;

  /// OccasionCategory.name value.
  ///
  /// Examples:
  /// dailyWear
  /// partyWear
  /// weddingGuest
  final String? occasionId;

  /// Optional customer explanation for the tailor.
  final String? notes;

  /// Active designs appear in My Uploads.
  /// Archived designs remain available for historical orders.
  final CustomerDesignStatus status;

  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == CustomerDesignStatus.active;

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'profileId': profileId,
      'title': title,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'dressType': dressType,
      'occasionId': occasionId,
      'notes': notes,
      'source': 'customerUpload',
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory CustomerDesign.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    final createdAtValue = data['createdAt'];
    final updatedAtValue = data['updatedAt'];

    final rawStatus = (data['status'] ?? 'active').toString();

    return CustomerDesign(
      id: document.id,
      accountId: (data['accountId'] ?? '').toString(),
      profileId: (data['profileId'] ?? '').toString(),
      title: (data['title'] ?? 'My Design').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      dressType: (data['dressType'] ?? 'Other').toString(),
      occasionId: data['occasionId']?.toString(),
      notes: data['notes']?.toString(),
      status: rawStatus == CustomerDesignStatus.archived.name
          ? CustomerDesignStatus.archived
          : CustomerDesignStatus.active,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : DateTime.now(),
      updatedAt: updatedAtValue is Timestamp ? updatedAtValue.toDate() : null,
    );
  }
}
