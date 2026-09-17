import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/catalogue_design.dart';
import '../../models/catalogue_design_version.dart';
import '../../services/owner_catalogue_service.dart';

class OwnerCatalogueScreen extends StatefulWidget {
  const OwnerCatalogueScreen({super.key});

  @override
  State<OwnerCatalogueScreen> createState() => _OwnerCatalogueScreenState();
}

class _OwnerCatalogueScreenState extends State<OwnerCatalogueScreen> {
  CatalogueDesignLifecycleStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Governed Catalogue'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Upload Catalogue Design',
            onPressed: () => context.push('/owner/catalogue/upload'),
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<CatalogueDesign>>(
        stream: OwnerCatalogueService.watchAllDesigns(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message('Unable to load Catalogue.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final designs = _statusFilter == null
              ? all
              : all
                    .where((item) => item.lifecycleStatus == _statusFilter)
                    .toList();
          return Column(
            children: [
              _filters(all),
              Expanded(
                child: designs.isEmpty
                    ? _message(
                        _statusFilter == null
                            ? 'No governed Catalogue designs yet.'
                            : 'No designs match this status.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: designs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _DesignCard(design: designs[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner/catalogue/upload'),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Upload Design'),
      ),
    );
  }

  Widget _filters(List<CatalogueDesign> all) {
    final counts = <CatalogueDesignLifecycleStatus, int>{};
    for (final item in all) {
      counts[item.lifecycleStatus] = (counts[item.lifecycleStatus] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All (${all.length})'),
            selected: _statusFilter == null,
            onSelected: (_) => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: 8),
          ...CatalogueDesignLifecycleStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${_label(status.name)} (${counts[status] ?? 0})'),
                selected: _statusFilter == status,
                onSelected: (_) => setState(() => _statusFilter = status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({required this.design});

  final CatalogueDesign design;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogueDesignVersion?>(
      future: OwnerCatalogueService.getActiveVersion(design),
      builder: (context, snapshot) {
        final version = snapshot.data;
        final imageUrl = version?.originalAsset?.downloadUrl;
        final processing = version?.processing.status.name ?? 'notRequested';
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              context.push('/owner/catalogue/${design.designId}/review'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 104,
                    height: 122,
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
                      if (design.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          design.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(_label(design.commercial.commercialType.name)),
                          _chip(_label(design.lifecycleStatus.name)),
                          _chip(_label(processing)),
                          _chip(_label(design.publicationStatus.name)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        design.garmentTypeCodes.isEmpty
                            ? 'Garment type not classified'
                            : design.garmentTypeCodes.map(_label).join(', '),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
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
}

String _label(String code) {
  final spaced = code.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  if (spaced.isEmpty) return spaced;
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
