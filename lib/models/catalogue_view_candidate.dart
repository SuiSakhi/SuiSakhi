import 'package:cloud_firestore/cloud_firestore.dart';

import 'catalogue_design_asset.dart';
import 'catalogue_design_view.dart';

class CatalogueViewCandidate {
  const CatalogueViewCandidate({
    required this.candidateId,
    required this.designId,
    required this.versionId,
    required this.reconstructionRunId,
    required this.viewType,
    required this.candidateIndex,
    required this.label,
    required this.status,
    required this.asset,
    this.generatedNote,
  });

  final String candidateId;
  final String designId;
  final String versionId;
  final String reconstructionRunId;
  final CatalogueDesignViewType viewType;
  final int candidateIndex;
  final String label;
  final String status;
  final CatalogueDesignAsset asset;
  final String? generatedNote;

  factory CatalogueViewCandidate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CatalogueViewCandidate(
      candidateId: doc.id,
      designId: data['designId']?.toString() ?? '',
      versionId: data['versionId']?.toString() ?? '',
      reconstructionRunId: data['reconstructionRunId']?.toString() ?? '',
      viewType: CatalogueDesignViewType.values.firstWhere(
        (type) => type.name == data['viewType']?.toString(),
        orElse: () => CatalogueDesignViewType.singleView,
      ),
      candidateIndex: data['candidateIndex'] is num
          ? (data['candidateIndex'] as num).toInt()
          : int.tryParse(data['candidateIndex']?.toString() ?? '') ?? 0,
      label: data['label']?.toString() ?? 'AI candidate',
      status: data['status']?.toString() ?? 'unknown',
      asset: CatalogueDesignAsset.fromMap(
        data['asset'] is Map
            ? Map<String, dynamic>.from(data['asset'] as Map)
            : const <String, dynamic>{},
      ),
      generatedNote: data['generatedNote']?.toString(),
    );
  }
}

class CatalogueViewReconstructionRun {
  const CatalogueViewReconstructionRun({
    required this.runId,
    required this.status,
    this.targetViewType,
    this.failureMessage,
    this.candidateCount = 0,
  });

  final String runId;
  final String status;
  final CatalogueDesignViewType? targetViewType;
  final String? failureMessage;
  final int candidateCount;

  factory CatalogueViewReconstructionRun.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CatalogueViewReconstructionRun(
      runId: doc.id,
      status: data['status']?.toString() ?? 'unknown',
      targetViewType: _viewType(data['targetViewType']?.toString()),
      failureMessage: data['failureMessage']?.toString(),
      candidateCount: data['candidateCount'] is num
          ? (data['candidateCount'] as num).toInt()
          : int.tryParse(data['candidateCount']?.toString() ?? '') ?? 0,
    );
  }

  static CatalogueDesignViewType? _viewType(String? name) {
    for (final type in CatalogueDesignViewType.values) {
      if (type.name == name) return type;
    }
    return null;
  }
}
