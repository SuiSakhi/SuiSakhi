import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import '../../services/designer_catalogue_access_service.dart';
import '../../services/designer_catalogue_service.dart';

class DesignerCatalogueScreen extends StatefulWidget {
  const DesignerCatalogueScreen({
    super.key,
    required this.accountId,
    required this.designerProfileId,
  });

  final String accountId;
  final String designerProfileId;

  @override
  State<DesignerCatalogueScreen> createState() =>
      _DesignerCatalogueScreenState();
}

class _DesignerCatalogueScreenState extends State<DesignerCatalogueScreen> {
  CatalogueDesignLifecycleStatus? _filter;
  late final Future<DesignerCatalogueAccessContext> _access;

  @override
  void initState() {
    super.initState();
    _access = DesignerCatalogueAccessService.requireApprovedDesigner(
      accountId: widget.accountId,
      profileId: widget.designerProfileId,
    );
  }

  String get _query =>
      '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
      '&profileId=${Uri.encodeQueryComponent(widget.designerProfileId)}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DesignerCatalogueAccessContext>(
      future: _access,
      builder: (context, accessSnapshot) {
        if (accessSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Catalogue Designs')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${accessSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!accessSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _dashboard(accessSnapshot.data!);
      },
    );
  }

  Widget _dashboard(DesignerCatalogueAccessContext access) {
    return Scaffold(
      backgroundColor: AppColors.background,
          appBar: AppBar(
          leading: IconButton(
          tooltip: 'Back to Partner Profile',
          onPressed: () {
            context.go(
              '/partner/landing'
              '?accountId=${Uri.encodeQueryComponent(widget.accountId)}'
              '&profileId=${Uri.encodeQueryComponent(widget.designerProfileId)}'
              '&category=designer',
            );
          },
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
          ),
        ),
        title: const Text('My Catalogue Designs'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Upload Design',
            onPressed: () =>
                context.push('/partner/designer/catalogue/upload$_query'),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogueDesign>>(
        stream: DesignerCatalogueService.watchOwnDesigns(
          accountId: access.accountId,
          profileId: access.profileId,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message('Unable to load Designs.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final visible = _filter == null
              ? all
              : all
                    .where((design) => design.lifecycleStatus == _filter)
                    .toList(growable: false);
          return Column(
            children: [
              _filters(all),
              Expanded(
                child: visible.isEmpty
                    ? _empty(all.isEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _DesignerDesignCard(
                          design: visible[index],
                          accountId: access.accountId,
                          profileId: access.profileId,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/partner/designer/catalogue/upload$_query'),
        icon: const Icon(Icons.add),
        label: const Text('Upload Design'),
      ),
    );
  }

  Widget _filters(List<CatalogueDesign> designs) {
    final counts = <CatalogueDesignLifecycleStatus, int>{};
    for (final design in designs) {
      counts[design.lifecycleStatus] =
          (counts[design.lifecycleStatus] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All (${designs.length})'),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          const SizedBox(width: 8),
          ...CatalogueDesignLifecycleStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_label(status.name)} (${counts[status] ?? 0})'),
                selected: _filter == status,
                onSelected: (_) => setState(() => _filter = status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool noDesigns) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.design_services_outlined, size: 54),
          const SizedBox(height: 12),
          Text(
            noDesigns
                ? 'No Catalogue Designs yet.'
                : 'No Designs match this status.',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium,
          ),
          if (noDesigns) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/partner/designer/catalogue/upload$_query'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Upload First Design'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _DesignerDesignCard extends StatelessWidget {
  const _DesignerDesignCard({
    required this.design,
    required this.accountId,
    required this.profileId,
  });

  final CatalogueDesign design;
  final String accountId;
  final String profileId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DesignerCatalogueBundle?>(
      future: DesignerCatalogueService.getActiveBundle(design),
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        final imageUrl = bundle?.primaryView?.bestPreviewUrl;
        final processing =
            bundle?.primaryView?.processing.status.name ??
            bundle?.version.processing.status.name ??
            'notRequested';
        final lifecycle = design.lifecycleStatus;
        final changesRequested =
            lifecycle == CatalogueDesignLifecycleStatus.changesRequested;
        final rejected = lifecycle == CatalogueDesignLifecycleStatus.rejected;
        final editable =
            lifecycle == CatalogueDesignLifecycleStatus.draft ||
            changesRequested;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 96,
                      height: 116,
                      child: imageUrl == null || imageUrl.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFF0EDF8),
                              child: Icon(Icons.image_not_supported_outlined),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const ColoredBox(
                                color: Color(0xFFF0EDF8),
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(design.title, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _chip(
                              _label(design.commercial.commercialType.name),
                            ),
                            _chip(_label(lifecycle.name)),
                            _chip(_label(processing)),
                            if ((bundle?.views.length ?? 0) > 1)
                              _chip('${bundle!.views.length} Views'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Expected: ${_money(design.commercial.designerExpectedPrice)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        Text(
                          'Approved: ${_money(design.commercial.approvedDesignCharge)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (changesRequested && design.reviewNotes != null) ...[
                const SizedBox(height: 12),
                _notice('Admin comments', design.reviewNotes!),
              ],
              if (rejected && design.rejectionReason != null) ...[
                const SizedBox(height: 12),
                _notice('Rejection reason', design.rejectionReason!),
              ],
              const SizedBox(height: 12),
              if (editable)
                FilledButton.icon(
                  onPressed: changesRequested
                      ? () => context.push(
                          '/partner/designer/catalogue/${design.designId}/correct'
                          '?accountId=${Uri.encodeQueryComponent(accountId)}'
                          '&profileId=${Uri.encodeQueryComponent(profileId)}',
                        )
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    changesRequested
                        ? 'Edit and Resubmit'
                        : 'Draft Editing Soon',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/partner/designer/catalogue/${design.designId}'
                    '?accountId=${Uri.encodeQueryComponent(accountId)}'
                    '&profileId=${Uri.encodeQueryComponent(profileId)}',
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View Details'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EDF8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: AppTextStyles.bodySmall),
  );

  Widget _notice(String title, String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
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
