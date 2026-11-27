import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityTemplate {
  const SecurityTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.section,
    required this.summary,
    required this.body,
    required this.links,
    required this.audiences,
    required this.partnerCategories,
    required this.displayOrder,
    required this.isPublished,
    required this.legalReviewComplete,
    this.sourcePackId,
  });

  final String id;
  final String title;
  final String category;

  /// UI section used to group related documents for customers and partners.
  final String section;
  final String summary;
  final String body;
  final List<String> links;
  final List<String> audiences;

  /// Empty means a general partner document; otherwise these are category codes.
  final List<String> partnerCategories;
  final int displayOrder;
  final bool isPublished;
  final bool legalReviewComplete;

  /// Source document key when imported from the CA pack; retained on edits.
  final String? sourcePackId;

  factory SecurityTemplate.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SecurityTemplate(
      id: doc.id,
      title: _string(data['title']),
      category: _string(data['category']),
      section: _string(data['section']).isEmpty
          ? 'general'
          : _string(data['section']),
      summary: _string(data['summary']),
      body: _string(data['body']),
      links: (data['links'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      audiences: (data['audiences'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      partnerCategories:
          (data['partnerCategories'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      displayOrder: data['displayOrder'] is int
          ? data['displayOrder'] as int
          : 0,
      isPublished: data['isPublished'] == true,
      legalReviewComplete: data['legalReviewComplete'] == true,
      sourcePackId: _string(data['sourcePackId']).isEmpty
          ? null
          : _string(data['sourcePackId']),
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}
