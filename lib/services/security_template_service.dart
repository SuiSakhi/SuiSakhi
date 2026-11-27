import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../models/security_template.dart';

class SecurityTemplateService {
  SecurityTemplateService._();

  static const _partnerTermsStarterBody =
      'DRAFT — PENDING CA/LEGAL REVIEW. Add the approved partner terms, '
      'confidentiality provisions, and any category-specific conditions.';

  static const legalPackAsset =
      'assets/legal/suisakhi_legal_template_drafts.json';

  static const sections = <String, String>{
    'account_privacy': 'Your account & privacy',
    'service_safety': 'Service policies & customer safety',
    'partner_terms': 'Partner onboarding & agreements',
    'ip_support': 'Intellectual property & support',
    'general': 'Other information',
  };

  static const partnerCategoryCodes = <String>[
    'tailor',
    'garmentCare',
    'measurementPartner',
    'doorstepServices',
    'bulkWedding',
    'deliveryPartner',
    'brand',
    'accessories',
    'rental',
    'boutique',
    'designer',
    'fabricSupplier',
    'printing',
    'embroidery',
    'other',
  ];

  static String sectionLabel(String key) => sections[key] ?? key;

  static String partnerCategoryLabel(String code) {
    switch (code) {
      case 'tailor':
        return 'Stitching & alterations';
      case 'garmentCare':
        return 'Garment care';
      case 'measurementPartner':
        return 'Measurement';
      case 'doorstepServices':
        return 'Wardrobe & doorstep';
      case 'bulkWedding':
        return 'Bulk & wedding';
      case 'deliveryPartner':
        return 'Pickup & delivery';
      case 'brand':
        return 'Fashion brands';
      case 'accessories':
        return 'Accessories';
      case 'rental':
        return 'Dress rental';
      case 'boutique':
        return 'Boutique';
      case 'designer':
        return 'Designer';
      case 'fabricSupplier':
        return 'Fabric supplier';
      case 'printing':
        return 'Printing';
      case 'embroidery':
        return 'Embroidery';
      case 'other':
        return 'Other services';
      default:
        return code;
    }
  }

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
    await ref.set(_templateData(template, uid));
    return ref.id;
  }

  static String adminOperationError(Object error, {required String action}) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied this request. This app stores legal-template '
          'fields named section, partnerCategories, and sourcePackId. Run '
          'firebase deploy --only firestore:rules --project suisakhitest, and '
          'then confirm your signed-in UID is listed in '
          'config/admin.adminUids. Retry after both checks.';
    }
    return 'Could not $action: $error';
  }

  /// Adds the provided legal pack to Admin templates as hidden drafts.
  /// Existing imported documents are left untouched so repeated imports do not
  /// overwrite Admin edits. Partner-specific commercial terms are excluded.
  static Future<LegalPackImportResult> importLegalPackDrafts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in as an Admin to import templates.');
    }

    final decoded = jsonDecode(await rootBundle.loadString(legalPackAsset));
    if (decoded is! List) {
      throw const FormatException('Legal template asset must contain a list.');
    }

    final existing = await _templates.get();
    final existingIds = existing.docs.map((doc) => doc.id).toSet();
    final importedPackIds = existing.docs
        .map((doc) => doc.data()['sourcePackId']?.toString())
        .whereType<String>()
        .toSet();
    final batch = FirebaseFirestore.instance.batch();
    var added = 0;
    var filledStarterDrafts = 0;
    var alreadyPresent = 0;
    final claimedStarterIds = <String>{};

    for (final raw in decoded) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final packId = item['id']?.toString().trim() ?? '';
      if (packId.isEmpty) continue;
      final id = 'ca_pack_$packId';
      if (existingIds.contains(id) || importedPackIds.contains(packId)) {
        alreadyPresent++;
        continue;
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? starterDraft;
      for (final doc in existing.docs) {
        if (claimedStarterIds.contains(doc.id)) continue;
        final data = doc.data();
        if (data['title'] == item['title'] &&
            data['body'] == _partnerTermsStarterBody &&
            data['category'] == 'Partner Terms' &&
            data['summary'] ==
                'Approved legal terms that apply to SuiSakhi partners.' &&
            data['displayOrder'] == 60 &&
            data['isPublished'] != true &&
            data['legalReviewComplete'] != true) {
          starterDraft = doc;
          break;
        }
      }
      final targetId = starterDraft?.id ?? id;
      if (starterDraft != null) claimedStarterIds.add(starterDraft.id);

      final template = SecurityTemplate(
        id: targetId,
        title: item['title']?.toString() ?? '',
        category: item['category']?.toString() ?? 'Other',
        section: item['section']?.toString() ?? 'general',
        summary: item['summary']?.toString() ?? '',
        body: item['body']?.toString() ?? '',
        links: const [],
        audiences: _stringList(item['audiences']),
        partnerCategories: _stringList(item['partnerCategories']),
        displayOrder: item['displayOrder'] is int
            ? item['displayOrder'] as int
            : 500,
        isPublished: false,
        legalReviewComplete: false,
        sourcePackId: packId,
      );
      batch.set(_templates.doc(targetId), _templateData(template, uid));
      if (starterDraft == null) {
        added++;
      } else {
        filledStarterDrafts++;
      }
    }

    if (added + filledStarterDrafts > 0) await batch.commit();
    return LegalPackImportResult(
      added: added,
      filledStarterDrafts: filledStarterDrafts,
      alreadyPresent: alreadyPresent,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _templateData(
    SecurityTemplate template,
    String uid,
  ) {
    final now = FieldValue.serverTimestamp();
    return {
      'title': template.title.trim(),
      'category': template.category,
      'section': template.section,
      'summary': template.summary.trim(),
      'body': template.body.trim(),
      'links': template.links,
      'audiences': template.audiences,
      'partnerCategories': template.partnerCategories,
      'displayOrder': template.displayOrder,
      'isPublished': template.isPublished,
      'legalReviewComplete': template.legalReviewComplete,
      'sourcePackId': template.sourcePackId,
      'legalReviewedAt': template.legalReviewComplete ? now : null,
      'legalReviewedByUid': template.legalReviewComplete ? uid : null,
      'updatedAt': now,
      'updatedByUid': uid,
    };
  }

  static Future<void> delete(String id) => _templates.doc(id).delete();

  static List<SecurityTemplate> starterDrafts() => [
    _starter(
      'Privacy Notice',
      'Privacy & Data',
      'account_privacy',
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
      'account_privacy',
      'Terms governing use of SuiSakhi services.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add the approved terms of use and '
          'effective date before publishing.',
      const ['customer', 'partner'],
      20,
    ),
    _starter(
      'Account Security & Data Handling',
      'Account Security',
      'account_privacy',
      'How account access and personal information are protected.',
      'DRAFT — PENDING CA/LEGAL REVIEW. Add approved information about account '
          'security, sign-in, data handling, and support contacts.',
      const ['customer', 'partner'],
      30,
    ),
    _starter(
      'Designs, Uploads & Intellectual Property',
      'Intellectual Property',
      'ip_support',
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
      'ip_support',
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
      'partner_terms',
      'Approved legal terms that apply to SuiSakhi partners.',
      _partnerTermsStarterBody,
      const ['partner'],
      60,
    ),
    _starter(
      'Legal & Grievance Contact',
      'Legal & Support',
      'ip_support',
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
    String section,
    String summary,
    String body,
    List<String> audiences,
    int order,
  ) => SecurityTemplate(
    id: '',
    title: title,
    category: category,
    section: section,
    summary: summary,
    body: body,
    links: const [],
    audiences: audiences,
    partnerCategories: const [],
    displayOrder: order,
    isPublished: false,
    legalReviewComplete: false,
  );
}

class LegalPackImportResult {
  const LegalPackImportResult({
    required this.added,
    required this.filledStarterDrafts,
    required this.alreadyPresent,
  });

  final int added;
  final int filledStarterDrafts;
  final int alreadyPresent;
}
