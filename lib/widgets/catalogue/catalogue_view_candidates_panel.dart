import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_view_candidate.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/catalogue_design_service.dart';

class CatalogueViewCandidatesPanel extends StatefulWidget {
  const CatalogueViewCandidatesPanel({
    super.key,
    required this.designId,
    required this.versionId,
    this.views = const [],
    this.allowGenerationRequest = false,
    this.onSelected,
  });

  final String designId;
  final String versionId;
  final List<CatalogueDesignView> views;
  final bool allowGenerationRequest;
  final VoidCallback? onSelected;

  @override
  State<CatalogueViewCandidatesPanel> createState() =>
      _CatalogueViewCandidatesPanelState();
}

class _CatalogueViewCandidatesPanelState
    extends State<CatalogueViewCandidatesPanel> {
  String? _selectingId;
  bool _retrying = false;

  Future<void> _select(CatalogueViewCandidate candidate) async {
    setState(() => _selectingId = candidate.candidateId);
    try {
      await CatalogueDesignService.selectViewCandidate(candidate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Candidate added. Admin will review it before customers see it.',
          ),
        ),
      );
      widget.onSelected?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select candidate: $error')),
      );
    } finally {
      if (mounted) setState(() => _selectingId = null);
    }
  }

  Future<void> _retry({String? sourceViewType}) async {
    setState(() => _retrying = true);
    try {
      await CatalogueDesignService.retryViewReconstruction(
        designId: widget.designId,
        versionId: widget.versionId,
        sourceViewType: sourceViewType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'View generation requested. Candidates will appear here.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start view generation: $error')),
      );
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatalogueViewReconstructionRun>>(
      stream: CatalogueDesignService.watchViewReconstructionRuns(
        designId: widget.designId,
        versionId: widget.versionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _message('Could not load view-generation status.');
        }
        final runs = snapshot.data ?? const <CatalogueViewReconstructionRun>[];
        CatalogueViewReconstructionRun? activeRun;
        for (final run in runs) {
          if (run.status != 'notRequired') {
            activeRun = run;
            break;
          }
        }
        return StreamBuilder<List<CatalogueViewCandidate>>(
          stream: CatalogueDesignService.watchViewCandidates(
            designId: widget.designId,
            versionId: widget.versionId,
          ),
          builder: (context, candidateSnapshot) {
            if (candidateSnapshot.hasError) {
              return _message('Could not load AI view candidates.');
            }
            final candidates = candidateSnapshot.data ?? const [];
            if (activeRun == null && candidates.isEmpty) {
              if (!widget.allowGenerationRequest) {
                return const SizedBox.shrink();
              }
              final targetType = _missingCounterpartType(widget.views);
              if (targetType != null) {
                return _requestMissingView(targetType);
              }
              final singleViews = widget.views
                  .where(
                    (view) =>
                        view.viewType == CatalogueDesignViewType.singleView,
                  )
                  .toList(growable: false);
              if (singleViews.length == 1 && widget.views.length == 1) {
                return _requestFromSingleView();
              }
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeRun != null) _runStatus(activeRun),
                if (candidates.isNotEmpty) ...[
                  Text(
                    'Choose a ${candidates.first.viewType.label.toLowerCase()} view',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'AI-generated options are candidates only. Check the garment details carefully; customers will see the selected view only after Admin approval.',
                  ),
                  const SizedBox(height: 12),
                  ...candidates.map(_candidateCard),
                ],
              ],
            );
          },
        );
      },
    );
  }

  CatalogueDesignViewType? _missingCounterpartType(
    List<CatalogueDesignView> views,
  ) {
    final hasFront = views.any(
      (view) => view.viewType == CatalogueDesignViewType.front,
    );
    final hasBack = views.any(
      (view) => view.viewType == CatalogueDesignViewType.back,
    );
    final hasCombined = views.any(
      (view) => view.viewType == CatalogueDesignViewType.combinedFrontBack,
    );
    if (hasCombined) return null;
    if (hasFront && !hasBack) return CatalogueDesignViewType.back;
    if (hasBack && !hasFront) return CatalogueDesignViewType.front;
    return null;
  }

  Widget _requestMissingView(CatalogueDesignViewType targetType) => Card(
    color: const Color(0xFFF0EDF8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${targetType.label} view candidates have not been generated yet.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate three options for Admin review. The design will remain unpublished until Admin approves it.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retrying ? null : () => _retry(),
            icon: _retrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _retrying
                  ? 'Starting generation…'
                  : 'Generate ${targetType.label.toLowerCase()} candidates',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _requestFromSingleView() => Card(
    color: const Color(0xFFF0EDF8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Identify the uploaded view',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'This design is marked Single View, so the system cannot tell which counterpart to generate. Choose what the uploaded image shows.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retrying ? null : () => _retry(sourceViewType: 'front'),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _retrying
                  ? 'Starting generation…'
                  : 'It is Front → Generate Back',
            ),
          ),
          OutlinedButton.icon(
            onPressed: _retrying ? null : () => _retry(sourceViewType: 'back'),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
              _retrying
                  ? 'Starting generation…'
                  : 'It is Back → Generate Front',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _runStatus(CatalogueViewReconstructionRun run) {
    final target = run.targetViewType?.label.toLowerCase() ?? 'counterpart';
    final message = switch (run.status) {
      'processing' => 'Generating three $target view candidates…',
      'needsSelection' => 'Three $target candidates are ready for review.',
      'selectedForReview' =>
        'A $target candidate is selected and awaiting Admin review.',
      'adminSelected' =>
        'Admin selected the $target candidate. Complete the catalogue review before publishing.',
      'failed' =>
        'Could not generate the $target view. ${run.failureMessage ?? ''}',
      _ => '',
    };
    if (message.isEmpty) return const SizedBox.shrink();
    return Card(
      color: run.status == 'failed'
          ? const Color(0xFFFFF0EF)
          : const Color(0xFFF0EDF8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (run.status == 'failed') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retrying ? 'Retrying…' : 'Retry generation'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _candidateCard(CatalogueViewCandidate candidate) {
    final busy = _selectingId == candidate.candidateId;
    final url = candidate.asset.downloadUrl;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              candidate.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 0.8,
              child: url == null || url.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF0EDF8),
                      child: Icon(Icons.image_not_supported_outlined),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF0EDF8),
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _selectingId == null ? () => _select(candidate) : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(busy ? 'Adding...' : 'Select ${candidate.label}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
  );
}
