import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityTemplate {
  const SecurityTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.body,
    required this.links,
    required this.audiences,
    required this.displayOrder,
    required this.isPublished,
    required this.legalReviewComplete,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final String body;
  final List<String> links;
  final List<String> audiences;
  final int displayOrder;
  final bool isPublished;
  final bool legalReviewComplete;

  factory SecurityTemplate.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return SecurityTemplate(
      id: doc.id,
      title: _string(data['title']),
      category: _string(data['category']),
      summary: _string(data['summary']),
      body: _string(data['body']),
      links: (data['links'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      audiences: (data['audiences'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      displayOrder: data['displayOrder'] is int
          ? data['displayOrder'] as int
          : 0,
      isPublished: data['isPublished'] == true,
      legalReviewComplete: data['legalReviewComplete'] == true,
    );
  }

  static String _string(Object? value) => value is String ? value : '';
}
