import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/partner_application.dart';
import '../models/security_template.dart';

/// Loads the Admin-published legal pack that applies at Partner submission.
class PartnerAgreementService {
  PartnerAgreementService._();

  static final _templates = FirebaseFirestore.instance.collection(
    'template_security',
  );

  static List<String> requiredPackIds(PartnerType partnerType) => [
    'partner_master',
    if (_requiresHomeVisitSafety(partnerType)) ...[
      'partner_safety',
      'individual_undertaking',
    ],
  ];

  static bool _requiresHomeVisitSafety(PartnerType partnerType) => const {
    PartnerType.measurementPartner,
    PartnerType.doorstepServices,
    PartnerType.deliveryPartner,
  }.contains(partnerType);

  static Future<List<SecurityTemplate>> loadRequiredDocuments(
    PartnerType partnerType,
  ) async {
    final snapshot = await _templates
        .where('isPublished', isEqualTo: true)
        .get();
    final published = snapshot.docs
        .map(SecurityTemplate.fromDoc)
        .where(
          (template) =>
              template.legalReviewComplete &&
              template.audiences.contains('partner') &&
              (template.partnerCategories.isEmpty ||
                  template.partnerCategories.contains(partnerType.name)),
        );
    final byPackId = <String, SecurityTemplate>{};
    for (final template in published) {
      final packId = template.sourcePackId;
      if (packId != null && packId.isNotEmpty) byPackId[packId] = template;
    }

    final required = requiredPackIds(partnerType);
    final missing = required.where((id) => !byPackId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'The required Partner agreement${missing.length == 1 ? '' : 's'} '
        'must be published by Admin before this application can be submitted.',
      );
    }
    return required.map((id) => byPackId[id]!).toList(growable: false);
  }

  static Map<String, dynamic> snapshotForAcceptance(SecurityTemplate template) {
    final source = RegExp(
      r'^Source:\s*(.+)$',
      multiLine: true,
    ).firstMatch(template.body)?.group(1)?.trim();
    return {
      'templateId': template.id,
      'sourcePackId': template.sourcePackId,
      'title': template.title,
      'category': template.category,
      'version': source ?? template.sourcePackId,
      'bodySnapshot': template.body,
      'accepted': true,
    };
  }
}
