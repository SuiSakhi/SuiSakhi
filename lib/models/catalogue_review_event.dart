import 'package:cloud_firestore/cloud_firestore.dart';

enum CatalogueReviewAction {
  requestChanges,
  approve,
  reject,
  overrideDecision,
  resubmit,
  applyAgain,
}

enum CatalogueChangeRequestScope {
  entireDesign,
  metadata,
  commercial,
  views,
  mixed,
}

class CatalogueReviewEvent {
  const CatalogueReviewEvent({
    required this.eventId,
    required this.designId,
    required this.action,
    required this.sourceLifecycle,
    required this.targetLifecycle,
    required this.reviewedVersionId,
    required this.actorUid,
    required this.createdAt,
    this.changeRequestScope,
    this.affectedViewIds = const [],
    this.notes,
    this.reason,
  });

  final String eventId;
  final String designId;
  final CatalogueReviewAction action;
  final String sourceLifecycle;
  final String targetLifecycle;
  final String reviewedVersionId;
  final CatalogueChangeRequestScope? changeRequestScope;
  final List<String> affectedViewIds;
  final String? notes;
  final String? reason;
  final String actorUid;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'eventId': eventId.trim(),
    'designId': designId.trim(),
    'action': action.name,
    'sourceLifecycle': sourceLifecycle.trim(),
    'targetLifecycle': targetLifecycle.trim(),
    'reviewedVersionId': reviewedVersionId.trim(),
    'changeRequestScope': changeRequestScope?.name,
    'affectedViewIds': affectedViewIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false),
    'notes': _text(notes),
    'reason': _text(reason),
    'actorUid': actorUid.trim(),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory CatalogueReviewEvent.fromMap(Map<String, dynamic> data) {
    return CatalogueReviewEvent(
      eventId: data['eventId']?.toString().trim() ?? '',
      designId: data['designId']?.toString().trim() ?? '',
      action: CatalogueReviewAction.values.firstWhere(
        (value) => value.name == data['action']?.toString(),
        orElse: () => CatalogueReviewAction.requestChanges,
      ),
      sourceLifecycle: data['sourceLifecycle']?.toString().trim() ?? '',
      targetLifecycle: data['targetLifecycle']?.toString().trim() ?? '',
      reviewedVersionId: data['reviewedVersionId']?.toString().trim() ?? '',
      changeRequestScope: _scope(data['changeRequestScope']),
      affectedViewIds: _strings(data['affectedViewIds']),
      notes: _text(data['notes']?.toString()),
      reason: _text(data['reason']?.toString()),
      actorUid: data['actorUid']?.toString().trim() ?? '',
      createdAt:
          _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static CatalogueChangeRequestScope? _scope(Object? raw) {
    for (final value in CatalogueChangeRequestScope.values) {
      if (value.name == raw?.toString()) return value;
    }
    return null;
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static DateTime? _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  static String? _text(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty ? null : value;
  }
}
