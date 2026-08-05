import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/design_template.dart';
import '../../services/design_template_service.dart';

/// Owner uploads dress flats / tech sketches; customers pick them in Dress designer.
class OwnerDesignTemplatesScreen extends StatefulWidget {
  const OwnerDesignTemplatesScreen({super.key});

  @override
  State<OwnerDesignTemplatesScreen> createState() =>
      _OwnerDesignTemplatesScreenState();
}

class _OwnerDesignTemplatesScreenState extends State<OwnerDesignTemplatesScreen> {
  bool _uploading = false;

  Future<void> _addTemplate() async {
    final titleController = TextEditingController(text: 'Dress flat');
    try {
    final picked = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New design image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Halter two-piece',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Choose photo'),
          ),
        ],
      ),
    );
    if (picked != true || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    final id = await DesignTemplateService.createTemplate(
      title: titleController.text,
      file: file,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload — check sign-in & Storage rules')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design added')),
      );
    }
    } finally {
      titleController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dress design images'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _addTemplate,
        icon: _uploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(_uploading ? 'Uploading…' : 'Add design'),
      ),
      body: StreamBuilder<List<DesignTemplate>>(
        stream: DesignTemplateService.watchTemplates(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load designs.\n'
                  'Add a Firestore collection `designTemplates` and Storage rules if needed.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checkroom_outlined,
                        size: 56, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'No design flats yet',
                      style: AppTextStyles.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload front/back sketches or flats. Customers will pick fabric and colour on these in Dress designer.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final t = list[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.imageUrl.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 1.2,
                        child: Image.network(
                          t.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(t.title, style: AppTextStyles.titleMedium),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
