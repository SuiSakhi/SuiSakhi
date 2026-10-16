import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/catalogue_design_service.dart';
import '../../services/customer_fabric_asset_service.dart';

class CatalogueFabricPreviewButton extends StatefulWidget {
  const CatalogueFabricPreviewButton({
    super.key,
    required this.designId,
    required this.versionId,
    this.onSelectionChanged,
  });

  final String designId;
  final String versionId;
  final ValueChanged<CustomerFabricPreviewSelection>? onSelectionChanged;

  @override
  State<CatalogueFabricPreviewButton> createState() =>
      _CatalogueFabricPreviewButtonState();
}

class _CatalogueFabricPreviewButtonState
    extends State<CatalogueFabricPreviewButton> {
  bool _working = false;
  bool _hasSelection = false;

  Future<void> _createPreview() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a fabric photo',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a new photo or choose one from your gallery.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _working = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final previews = await CatalogueDesignService.generateFabricPreviews(
        designId: widget.designId,
        versionId: widget.versionId,
        fabricImageBase64: base64Encode(bytes),
        fabricMimeType: file.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      if (previews.isEmpty) {
        throw StateError('The preview service returned no images.');
      }
      final selectedPreviews = await showDialog<List<CustomerFabricViewPreview>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Fabric visualization'),
            content: SizedBox(
              width: 380,
              height: 450,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      itemCount: previews.length,
                      itemBuilder: (context, index) {
                        final preview = previews[index];
                        return Column(
                          children: [
                            Expanded(
                              child: Image.memory(
                                base64Decode(preview['imageBase64'] ?? ''),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  size: 42,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${preview['viewType'] ?? 'Garment'} view'),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    previews.length > 1
                        ? 'Swipe through all views. Front and Back will both be saved with your fabric comparison.'
                        : 'AI visual approximation only. The original monochrome design remains the tailoring reference.',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  previews
                      .map(
                        (preview) => CustomerFabricViewPreview(
                          bytes: Uint8List.fromList(
                            base64Decode(preview['imageBase64'] ?? ''),
                          ),
                          mimeType: preview['mimeType'] ?? 'image/png',
                          viewType: preview['viewType'] ?? 'front',
                        ),
                      )
                      .toList(growable: false),
                ),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  previews.length > 1 ? 'Use Front & Back' : 'Use this preview',
                ),
              ),
            ],
          );
        },
      );
      if (selectedPreviews != null && selectedPreviews.isNotEmpty) {
        final firstPreview = selectedPreviews.first;
        final selection = CustomerFabricPreviewSelection(
          fabricPhoto: file,
          previewBytes: firstPreview.bytes,
          previewMimeType: firstPreview.mimeType,
          previewViewType: firstPreview.viewType,
          designId: widget.designId,
          catalogueVersionId: widget.versionId,
          additionalPreviews: selectedPreviews.skip(1).toList(growable: false),
        );
        widget.onSelectionChanged?.call(selection);
        if (mounted) setState(() => _hasSelection = true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create fabric preview: $error')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _working ? null : _createPreview,
      icon: _working
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.texture_outlined),
      label: Text(
        _working
            ? 'Creating Preview...'
            : _hasSelection
            ? 'Try another fabric'
            : 'Preview My Fabric',
      ),
    ),
  );
}
