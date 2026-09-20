import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/designer_catalogue_access_service.dart';
import '../../services/designer_catalogue_service.dart';

class DesignerCatalogueDetailsScreen extends StatefulWidget {
  const DesignerCatalogueDetailsScreen({
    super.key,
    required this.accountId,
    required this.designerProfileId,
    required this.designId,
  });

  final String accountId;
  final String designerProfileId;
  final String designId;

  @override
  State<DesignerCatalogueDetailsScreen> createState() =>
      _DesignerCatalogueDetailsScreenState();
}

class _DesignerCatalogueDetailsScreenState
    extends State<DesignerCatalogueDetailsScreen> {
  CatalogueDesignView? _selected;

  Future<CatalogueDesign> _load() async {
    await DesignerCatalogueAccessService.requireApprovedDesigner(
      accountId: widget.accountId,
      profileId: widget.designerProfileId,
    );
    final doc = await FirebaseFirestore.instance
        .collection('designs')
        .doc(widget.designId)
        .get();
    if (!doc.exists) throw StateError('Catalogue Design not found.');
    final design = CatalogueDesign.fromDoc(doc);
    if (design.ownerAccountId != widget.accountId ||
        design.ownerProfileId != widget.designerProfileId ||
        design.ownerType != CatalogueDesignOwnerType.designer) {
      throw StateError('This Catalogue Design is not owned by this profile.');
    }
    return design;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogueDesign>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Design Details')),
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final design = snapshot.data!;
        return FutureBuilder<DesignerCatalogueBundle?>(
          future: DesignerCatalogueService.getActiveBundle(design),
          builder: (context, bundleSnapshot) {
            final bundle = bundleSnapshot.data;
            final views = bundle?.views ?? const <CatalogueDesignView>[];
            final selected = _selected ?? bundle?.primaryView;
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Design Details'),
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: selected?.bestPreviewUrl == null
                          ? const ColoredBox(
                              color: Color(0xFFF0EDF8),
                              child: Icon(Icons.image_not_supported_outlined),
                            )
                          : Image.network(
                              selected!.bestPreviewUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                  ),
                  if (views.length > 1) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: views
                          .map(
                            (view) => ChoiceChip(
                              selected: selected?.viewId == view.viewId,
                              onSelected: (_) =>
                                  setState(() => _selected = view),
                              label: Text(
                                '${view.viewType.label}${view.isPrimary ? ' • Primary' : ''}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _card('Design', [
                    _row('Title', design.title),
                    _row('Description', design.description ?? 'Not provided'),
                    _row('Lifecycle', _label(design.lifecycleStatus.name)),
                    _row('Publication', _label(design.publicationStatus.name)),
                    _row('Views', '${views.length}'),
                  ]),
                  const SizedBox(height: 14),
                  _card('Commercial', [
                    _row('Type', _label(design.commercial.commercialType.name)),
                    _row(
                      'Expected price',
                      _money(design.commercial.designerExpectedPrice),
                    ),
                    _row(
                      'Approved charge',
                      _money(design.commercial.approvedDesignCharge),
                    ),
                  ]),
                  if (design.reviewNotes != null) ...[
                    const SizedBox(height: 14),
                    _notice('Admin comments', design.reviewNotes!),
                  ],
                  if (design.rejectionReason != null) ...[
                    const SizedBox(height: 14),
                    _notice('Rejection reason', design.rejectionReason!),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
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
        SizedBox(width: 135, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _notice(String title, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(text),
      ],
    ),
  );
}

String _money(double? value) =>
    value == null ? 'Not set' : '₹${value.toStringAsFixed(2)}';

String _label(String code) {
  final spaced = code.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced.isEmpty
      ? spaced
      : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
