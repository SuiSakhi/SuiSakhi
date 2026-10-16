import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_contributor_summary.dart';
import '../../models/catalogue_design_view.dart';
import '../../models/catalogue_design_version.dart';
import '../../models/catalogue_processing_status.dart';
import '../../services/catalogue_design_service.dart';
import '../../services/owner_catalogue_service.dart';
import '../../widgets/catalogue/catalogue_view_candidates_panel.dart';

class OwnerCatalogueReviewScreen extends StatefulWidget {
  const OwnerCatalogueReviewScreen({super.key, required this.designId});

  final String designId;

  @override
  State<OwnerCatalogueReviewScreen> createState() =>
      _OwnerCatalogueReviewScreenState();
}

class _OwnerCatalogueReviewScreenState
    extends State<OwnerCatalogueReviewScreen> {
  bool _working = false;

  Future<void> _requestChanges() async {
    final value = await _textDialog(
      title: 'Request Changes',
      label: 'Instructions for contributor',
      minimumLength: 5,
    );
    if (value == null) return;
    await _run(
      () => CatalogueDesignService.markChangesRequested(
        designId: widget.designId,
        reviewNotes: value,
      ),
    );
  }

  Future<void> _reject() async {
    final value = await _textDialog(
      title: 'Reject Design',
      label: 'Clear rejection reason',
      minimumLength: 10,
    );
    if (value == null) return;
    await _run(
      () => CatalogueDesignService.reject(
        designId: widget.designId,
        reason: value,
      ),
    );
  }

  Future<void> _approve(
    CatalogueDesign design,
    CatalogueDesignVersion? version,
    List<CatalogueDesignView> views,
  ) async {
    if (!_hasRequiredViews(views)) {
      _message(
        'Select the generated Front/Back counterpart before approving this design.',
        error: true,
      );
      return;
    }
    double? charge =
        design.commercial.commercialType == CatalogueCommercialType.free
        ? null
        : design.commercial.approvedDesignCharge ??
              design.commercial.designerExpectedPrice;
    if (design.commercial.commercialType != CatalogueCommercialType.free) {
      final value = await _moneyDialog(initialValue: charge);
      if (value == null) return;
      charge = value;
    }
    await _run(() async {
      await CatalogueDesignService.approve(
        designId: widget.designId,
        approvedDesignCharge: charge,
        commercialVersion: '1.0',
      );
      final processingStatus = version?.processing.status;
      if (processingStatus == CatalogueProcessingStatus.completed ||
          processingStatus == CatalogueProcessingStatus.approved ||
          processingStatus == CatalogueProcessingStatus.manualReviewRequired) {
        if (_hasRequiredViews(views)) {
          await CatalogueDesignService.publish(widget.designId);
        }
      }
    });
  }

  Future<void> _editRate(CatalogueDesign design) async {
    final value = await _moneyDialog(
      title: 'Adjust Approved Design Rate',
      initialValue: design.commercial.approvedDesignCharge,
    );
    if (value == null) return;
    await _run(
      () => CatalogueDesignService.updateApprovedDesignCharge(
        designId: widget.designId,
        approvedDesignCharge: value,
      ),
    );
  }

  bool _hasRequiredViews(List<CatalogueDesignView> views) {
    final hasFront = views.any(
      (view) => view.viewType == CatalogueDesignViewType.front,
    );
    final hasBack = views.any(
      (view) => view.viewType == CatalogueDesignViewType.back,
    );
    final hasCombined = views.any(
      (view) => view.viewType == CatalogueDesignViewType.combinedFrontBack,
    );
    return hasCombined || (hasFront && hasBack);
  }

  Future<void> _publish(
    CatalogueDesignVersion? version,
    List<CatalogueDesignView> views,
  ) async {
    if (!_hasRequiredViews(views)) {
      _message(
        'Choose an AI-generated counterpart view before publishing this design.',
        error: true,
      );
      return;
    }
    final status = version?.processing.status;
    final ready =
        status == CatalogueProcessingStatus.completed ||
        status == CatalogueProcessingStatus.approved ||
        status == CatalogueProcessingStatus.manualReviewRequired;
    if (!ready) {
      _message(
        'Wait for image processing to finish before publishing.',
        error: true,
      );
      return;
    }
    await _run(() => CatalogueDesignService.publish(widget.designId));
  }

  Future<void> _unpublish() async {
    await _run(() => CatalogueDesignService.unpublish(widget.designId));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => _working = false);
      _message('Catalogue design updated successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _working = false);
      _message('Unable to update Catalogue design.\n$error', error: true);
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required int minimumLength,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= minimumLength) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<double?> _moneyDialog({
    String title = 'Approve Commercial Charge',
    double? initialValue,
  }) async {
    final controller = TextEditingController(
      text: initialValue?.toStringAsFixed(0) ?? '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Approved design charge',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Text(title.startsWith('Adjust') ? 'Save rate' : 'Approve'),
          ),
        ],
      ),
    );
    return result;
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CatalogueDesign?>(
      stream: OwnerCatalogueService.watchDesign(widget.designId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('${snapshot.error}')));
        }
        final design = snapshot.data;
        if (design == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<OwnerCatalogueVersionBundle?>(
          future: OwnerCatalogueService.getActiveVersionBundle(design),
          builder: (context, bundleSnapshot) {
            final bundle = bundleSnapshot.data;
            final version = bundle?.version;
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Catalogue Review'),
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (bundleSnapshot.hasError)
                    Text('Unable to load design views: ${bundleSnapshot.error}')
                  else if (!bundleSnapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _imageGallery(bundle?.views ?? const []),
                    if (bundle?.version.versionId.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      CatalogueViewCandidatesPanel(
                        designId: design.designId,
                        versionId: bundle!.version.versionId,
                        views: bundle.views,
                        allowGenerationRequest: true,
                        onSelected: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _contributorSection(bundle?.contributor),
                  ],
                  const SizedBox(height: 14),
                  _section('Design', [
                    _row('Title', design.title),
                    _row('Description', design.description ?? 'Not provided'),
                    _row('Owner', _label(design.ownerType.name)),
                    _row(
                      'Garment',
                      design.garmentTypeCodes.map(_label).join(', '),
                    ),
                    _row(
                      'Occasion',
                      design.occasionCodes.map(_label).join(', '),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Commercial', [
                    _row('Type', _label(design.commercial.commercialType.name)),
                    _row(
                      'Designer expected price',
                      _money(design.commercial.designerExpectedPrice),
                    ),
                    _row(
                      'Approved design charge',
                      _money(design.commercial.approvedDesignCharge),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Lifecycle', [
                    _row('Lifecycle', _label(design.lifecycleStatus.name)),
                    _row('Publication', _label(design.publicationStatus.name)),
                    _row(
                      'Processing',
                      _label(version?.processing.status.name ?? 'notRequested'),
                    ),
                    _row('Review notes', design.reviewNotes ?? 'None'),
                    _row('Rejection reason', design.rejectionReason ?? 'None'),
                  ]),
                  const SizedBox(height: 18),
                  _actions(design, version, bundle?.views ?? const []),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _imageGallery(List<CatalogueDesignView> views) {
    final hasCombined = views.any(
      (view) => view.viewType == CatalogueDesignViewType.combinedFrontBack,
    );
    final hasFront =
        hasCombined ||
        views.any((view) => view.viewType == CatalogueDesignViewType.front);
    final hasBack =
        hasCombined ||
        views.any((view) => view.viewType == CatalogueDesignViewType.back);
    final singleViewOnly =
        views.length == 1 &&
        views.single.viewType == CatalogueDesignViewType.singleView;
    if (views.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 5,
        child: ColoredBox(
          color: Color(0xFFF0EDF8),
          child: Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: views.length,
            itemBuilder: (context, index) {
              final view = views[index];
              final url = view.bestPreviewUrl;
              return Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: url == null || url.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFF0EDF8),
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 48,
                                ),
                              ),
                            )
                          : Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFF0EDF8),
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${view.viewType.label} view · ${index + 1}/${views.length}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasFront && hasBack
              ? 'Front/back views are available for review.'
              : singleViewOnly
              ? 'This image is marked Single View. Identify it as Front or Back below to generate the missing counterpart for review.'
              : hasFront
              ? 'Back view is missing. Generate candidates below for Admin review before approval.'
              : hasBack
              ? 'Front view is missing. Generate candidates below for Admin review before approval.'
              : 'A Front or Back source view is required to generate its counterpart.',
          style: AppTextStyles.bodySmall.copyWith(
            color: hasFront && hasBack
                ? AppColors.success
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _contributorSection(CatalogueContributorSummary? contributor) =>
      _section('Contributor', [
        _row('Partner', contributor?.displayName ?? 'Contributor unavailable'),
        _row('Source', contributor?.sourceLabel ?? 'Unknown'),
        if (contributor?.partnerType?.trim().isNotEmpty == true)
          _row('Partner type', _label(contributor!.partnerType!)),
        if (contributor?.accountId?.trim().isNotEmpty == true)
          _row('Account ID', contributor!.accountId!),
        if (contributor?.profileId?.trim().isNotEmpty == true)
          _row('Partner profile ID', contributor!.profileId!),
      ]);

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.headlineMedium),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? 'None' : value)),
      ],
    ),
  );

  Widget _actions(
    CatalogueDesign design,
    CatalogueDesignVersion? version,
    List<CatalogueDesignView> views,
  ) {
    final approved =
        design.lifecycleStatus == CatalogueDesignLifecycleStatus.approved;
    final published =
        design.publicationStatus == CataloguePublicationStatus.published;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!approved) ...[
          FilledButton.icon(
            onPressed: _working || !_hasRequiredViews(views)
                ? null
                : () => _approve(design, version, views),
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              _hasRequiredViews(views)
                  ? 'Approve Design'
                  : 'Select counterpart view before approval',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working ? null : _requestChanges,
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Request Changes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working ? null : _reject,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject Design'),
          ),
        ],
        if (approved && !published) ...[
          if (!_hasRequiredViews(views))
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Awaiting counterpart view selection'),
            )
          else if (version?.processing.status ==
                  CatalogueProcessingStatus.completed ||
              version?.processing.status ==
                  CatalogueProcessingStatus.approved ||
              version?.processing.status ==
                  CatalogueProcessingStatus.manualReviewRequired)
            FilledButton.icon(
              onPressed: _working ? null : () => _publish(version, views),
              icon: const Icon(Icons.publish_outlined),
              label: Text(
                version?.processing.status ==
                        CatalogueProcessingStatus.manualReviewRequired
                    ? 'Publish Reviewed Image'
                    : 'Publish Design',
              ),
            )
          else
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_top_rounded),
              label: const Text('Awaiting Structured Processing'),
            ),

          if (version?.processing.status !=
                  CatalogueProcessingStatus.completed &&
              version?.processing.status !=
                  CatalogueProcessingStatus.approved &&
              version?.processing.status !=
                  CatalogueProcessingStatus.manualReviewRequired) ...[
            const SizedBox(height: 8),
            Text(
              'Wait for image processing to finish before publishing.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
        if (approved &&
            (design.commercial.commercialType == CatalogueCommercialType.paid ||
                design.commercial.commercialType ==
                    CatalogueCommercialType.premium)) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _working ? null : () => _editRate(design),
            icon: const Icon(Icons.currency_rupee_rounded),
            label: const Text('Adjust Approved Rate'),
          ),
        ],
        if (published)
          OutlinedButton.icon(
            onPressed: _working ? null : _unpublish,
            icon: const Icon(Icons.visibility_off_outlined),
            label: const Text('Unpublish Design'),
          ),
        if (_working) ...[
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

String _money(double? value) =>
    value == null ? 'Not set' : '₹${value.toStringAsFixed(2)}';

String _label(String code) {
  final spaced = code.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  if (spaced.isEmpty) return spaced;
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
