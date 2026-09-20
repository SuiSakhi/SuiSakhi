import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_design.dart';
import '../../services/catalogue_design_service.dart';
import '../../widgets/catalogue/catalogue_upload_form.dart';
import '../../models/catalogue_design_view.dart';

class OwnerCatalogueUploadScreen extends StatefulWidget {
  const OwnerCatalogueUploadScreen({super.key});

  @override
  State<OwnerCatalogueUploadScreen> createState() =>
      _OwnerCatalogueUploadScreenState();
}

class _OwnerCatalogueUploadScreenState
    extends State<OwnerCatalogueUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  CatalogueUploadFormValue? _value;
  bool _saving = false;

  Future<void> _upload() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final value = _value;
    if (value == null || value.views.isEmpty) {
      _message('Add at least one valid Design View.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final designId = await CatalogueDesignService.createDraft(
        ownerType: CatalogueDesignOwnerType.suisakhi,
        title: value.title,
        description: value.description,
        garmentTypeCodes: value.garmentTypeCodes,
        occasionCodes: value.occasionCodes,
        commercial: CatalogueDesignCommercial(
          commercialType: value.commercialType,
          approvedDesignCharge: value.approvedDesignCharge,
        ),
      );
      final version = await CatalogueDesignService.createVersion(
        designId: designId,
      );

      final uploadedViews = <CatalogueDesignView>[];

      for (final view in value.views) {
        uploadedViews.add(
          await CatalogueDesignService.uploadView(
            designId: designId,
            versionId: version.versionId,
            file: view.file,
            viewType: view.viewType,
            displayOrder: view.displayOrder,
            isPrimary: view.isPrimary,
            title: view.title,
          ),
        );
      }

      await CatalogueDesignService.finalizeVersion(
        designId: designId,
        version: version,
        views: uploadedViews,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        'Original uploaded. Structured conversion is queued for processing.',
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to upload Catalogue design.\n$error', error: true);
    }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Catalogue Upload'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CatalogueUploadForm(
            formKey: _formKey,
            enabled: !_saving,
            designerMode: false,
            showApprovedDesignCharge: true,
            onChanged: (value) => _value = value,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _upload,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_saving ? 'Uploading...' : 'Upload Catalogue Design'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
