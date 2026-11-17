import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/security_template.dart';

class SecurityTemplateService {
  SecurityTemplateService._();

  static final CollectionReference<Map<String, dynamic>> _templates =
      FirebaseFirestore.instance.collection('template_security');

  static Stream<List<SecurityTemplate>> watchAdminTemplates() {
    return _templates.snapshots().map((snapshot) {
      final templates = snapshot.docs.map(SecurityTemplate.fromDoc).toList();
      templates.sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder == 0 ? a.title.compareTo(b.title) : byOrder;
      });
      return templates;
    });
  }

  static Stream<List<SecurityTemplate>> watchPublishedTemplates(
    String audience,
  ) {
    return _templates.where('isPublished', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final templates = snapshot.docs
          .map(SecurityTemplate.fromDoc)
          .where((template) => template.audiences.contains(audience))
          .toList();
      templates.sort((a, b) {
        final byOrder = a.displayOrder.compareTo(b.displayOrder);
        return byOrder == 0 ? a.title.compareTo(b.title) : byOrder;
      });
      return templates;
    });
  }

  static Future<String> save(SecurityTemplate template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in as an Admin to save templates.');

    final ref = template.id.isEmpty
        ? _templates.doc()
        : _templates.doc(template.id);
    final now = FieldValue.serverTimestamp();
    await ref.set({
      'title': template.title.trim(),
      'category': template.category,
      'summary': template.summary.trim(),
      'body': template.body.trim(),
      'links': template.links,
      'audiences': template.audiences,
      'displayOrder': template.displayOrder,
      'isPublished': template.isPublished,
      'legalReviewComplete': template.legalReviewComplete,
      'legalReviewedAt': template.legalReviewComplete ? now : null,
      'legalReviewedByUid': template.legalReviewComplete ? uid : null,
      'updatedAt': now,
      'updatedByUid': uid,
    });
    return ref.id;
  }

  static Future<void> delete(String id) => _templates.doc(id).delete();

  static List<SecurityTemplate> starterDrafts() => [
    _starter(
      'Privacy Notice',
      'Privacy & Data',
      'Privacy information for customers and partners.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Replace this placeholder with the '
          'approved privacy notice, including the data collected, purposes, '
          'retention, sharing, user choices, and contact details.',
      const ['customer', 'partner'],
      10,
    ),
    _starter(
      'Terms of Use',
      'Terms & Conditions',
      'Terms governing use of SuiSakhi services.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add the approved terms of use and '
          'effective date before publishing.',
      const ['customer', 'partner'],
      20,
    ),
    _starter(
      'Account Security & Data Handling',
      'Account Security',
      'How account access and personal information are protected.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add approved information about account '
          'security, sign-in, data handling, and support contacts.',
      const ['customer', 'partner'],
      30,
    ),
    _starter(
      'Designs, Uploads & Intellectual Property',
      'Intellectual Property',
      'Approved terms for designs, customer uploads, and intellectual property.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Specify the verified ownership, '
          'permissions, licensing, and permitted use of catalogue designs and '
          'customer-uploaded material.',
      const ['customer', 'partner'],
      40,
    ),
    _starter(
      'Patent Portfolio',
      'Patents & Intellectual Property',
      'Verified details and official links for SuiSakhi patent filings.',
      'DRAFT — PENDING CA/LEGAL REVIEW. For each of the seven referenced '
          'patents, enter the exact title, patent or application number, '
          'jurisdiction, current status, rights holder, and official public '
          'record link. Publish only details verified by the legal team.',
      const ['customer', 'partner'],
      50,
    ),
    _starter(
      'Partner Terms & Confidentiality',
      'Partner Terms',
      'Approved legal terms that apply to SuiSakhi partners.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add the approved partner terms, '
          'confidentiality provisions, and any category-specific conditions.',
      const ['partner'],
      60,
    ),
    _starter(
      'Legal & Grievance Contact',
      'Legal & Support',
      'Official contact information for legal and grievance requests.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add the approved legal contact, '
          'grievance contact, response process, and applicable timelines.',
      const ['customer', 'partner'],
      70,
    ),
  ];

  static SecurityTemplate _starter(
    String title,
    String category,
    String summary,
    String body,
    List<String> audiences,
    int order,
  ) => SecurityTemplate(
    id: '',
    title: title,
    category: category,
    summary: summary,
    body: body,
    links: const [],
    audiences: audiences,
    displayOrder: order,
    isPublished: false,
    legalReviewComplete: false,
  );
}
