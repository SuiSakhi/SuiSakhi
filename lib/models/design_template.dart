import 'package:cloud_firestore/cloud_firestore.dart';

/// Owner-uploaded dress flat / tech sketch for customer fabric & colour preview.
class DesignTemplate {
  const DesignTemplate({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String imageUrl;

  factory DesignTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final t = (data['title'] as String?)?.trim() ?? '';
    return DesignTemplate(
      id: doc.id,
      title: t.isEmpty ? 'Design' : t,
      imageUrl: (data['imageUrl'] as String?) ?? '',
    );
  }
}
