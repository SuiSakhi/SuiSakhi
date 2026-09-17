import 'package:cloud_firestore/cloud_firestore.dart';

enum CatalogueAgreementActorType { admin, designerPartner }

class CatalogueAgreementAcceptance {
  const CatalogueAgreementAcceptance({
    required this.agreementCode,
    required this.agreementVersion,
    required this.acceptedByUid,
    required this.actorType,
    required this.acceptedAt,
    this.partnerProfileId,
    this.snapshotReference,
    this.snapshotHash,
  });

  final String agreementCode;
  final String agreementVersion;
  final String acceptedByUid;
  final CatalogueAgreementActorType actorType;
  final DateTime acceptedAt;
  final String? partnerProfileId;
  final String? snapshotReference;
  final String? snapshotHash;

  Map<String, dynamic> toMap() => {
    'agreementCode': agreementCode.trim(),
    'agreementVersion': agreementVersion.trim(),
    'acceptedByUid': acceptedByUid.trim(),
    'actorType': actorType.name,
    'acceptedAt': Timestamp.fromDate(acceptedAt),
    'partnerProfileId': _text(partnerProfileId),
    'snapshotReference': _text(snapshotReference),
    'snapshotHash': _text(snapshotHash),
  };

  factory CatalogueAgreementAcceptance.fromMap(Map<String, dynamic> data) {
    return CatalogueAgreementAcceptance(
      agreementCode: data['agreementCode']?.toString().trim() ?? '',
      agreementVersion: data['agreementVersion']?.toString().trim() ?? '',
      acceptedByUid: data['acceptedByUid']?.toString().trim() ?? '',
      actorType: CatalogueAgreementActorType.values.firstWhere(
        (item) => item.name == data['actorType']?.toString(),
        orElse: () => CatalogueAgreementActorType.designerPartner,
      ),
      acceptedAt:
          _date(data['acceptedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      partnerProfileId: _text(data['partnerProfileId']?.toString()),
      snapshotReference: _text(data['snapshotReference']?.toString()),
      snapshotHash: _text(data['snapshotHash']?.toString()),
    );
  }

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

class CatalogueRightsDeclaration {
  const CatalogueRightsDeclaration({
    required this.originalWorkDeclared,
    required this.rightsConfirmed,
    required this.acceptedByUid,
    required this.acceptedAt,
    this.thirdPartyContentDeclared = false,
    this.notes,
  });

  final bool originalWorkDeclared;
  final bool rightsConfirmed;
  final bool thirdPartyContentDeclared;
  final String acceptedByUid;
  final DateTime acceptedAt;
  final String? notes;

  bool get isComplete => originalWorkDeclared && rightsConfirmed;

  Map<String, dynamic> toMap() => {
    'originalWorkDeclared': originalWorkDeclared,
    'rightsConfirmed': rightsConfirmed,
    'thirdPartyContentDeclared': thirdPartyContentDeclared,
    'acceptedByUid': acceptedByUid.trim(),
    'acceptedAt': Timestamp.fromDate(acceptedAt),
    'notes': CatalogueAgreementAcceptance._text(notes),
  };

  factory CatalogueRightsDeclaration.fromMap(Map<String, dynamic> data) {
    return CatalogueRightsDeclaration(
      originalWorkDeclared: data['originalWorkDeclared'] == true,
      rightsConfirmed: data['rightsConfirmed'] == true,
      thirdPartyContentDeclared: data['thirdPartyContentDeclared'] == true,
      acceptedByUid: data['acceptedByUid']?.toString().trim() ?? '',
      acceptedAt:
          CatalogueAgreementAcceptance._date(data['acceptedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notes: CatalogueAgreementAcceptance._text(data['notes']?.toString()),
    );
  }
}
