import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogue_agreement.dart';
import '../../models/catalogue_design.dart';
import '../../services/catalogue_agreement_policy.dart';
import '../../services/catalogue_design_service.dart';
import '../../widgets/catalogue/catalogue_upload_form.dart';
import '../../models/catalogue_design_view.dart';
import '../../services/designer_catalogue_access_service.dart';

class DesignerCatalogueUploadScreen extends StatefulWidget {
  const DesignerCatalogueUploadScreen({
    super.key,
    required this.accountId,
    required this.designerProfileId,
  });
  final String accountId;
  final String designerProfileId;

  @override
  State<DesignerCatalogueUploadScreen> createState() =>
      _DesignerCatalogueUploadScreenState();
}

class _DesignerCatalogueUploadScreenState
    extends State<DesignerCatalogueUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  CatalogueUploadFormValue? _value;
  bool _agreementAccepted = false;
  bool _originalWorkDeclared = false;
  bool _rightsConfirmed = false;
  bool _saving = false;

  Future<void> _uploadAndSubmit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final value = _value;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _message('Please sign in again.', error: true);
      return;
    }
    if (widget.designerProfileId.trim().isEmpty) {
      _message('An approved Designer profile is required.', error: true);
      return;
    }
    if (!_agreementAccepted) {
      _message('Accept the current Catalogue agreement.', error: true);
      return;
    }
    if (!_originalWorkDeclared || !_rightsConfirmed) {
      _message('Complete the per-design rights declaration.', error: true);
      return;
    }
    if (value == null || value.views.isEmpty) {
      _message('Add at least one valid Design View.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final access =
          await DesignerCatalogueAccessService.requireApprovedDesigner(
            accountId: widget.accountId,
            profileId: widget.designerProfileId,
          );

      final now = DateTime.now();
      final designId = await CatalogueDesignService.createDraft(
        ownerType: CatalogueDesignOwnerType.designer,
        ownerAccountId: access.accountId,
        ownerProfileId: access.profileId,
        title: value.title,
        description: value.description,
        garmentTypeCodes: value.garmentTypeCodes,
        occasionCodes: value.occasionCodes,
        commercial: CatalogueDesignCommercial(
          commercialType: value.commercialType,
          designerExpectedPrice: value.expectedPrice,
        ),
        catalogueAgreement: CatalogueAgreementAcceptance(
          agreementCode: CatalogueAgreementPolicy.agreementCode,
          agreementVersion: CatalogueAgreementPolicy.currentVersion,
          acceptedByUid: uid,
          actorType: CatalogueAgreementActorType.designerPartner,
          acceptedAt: now,
          partnerProfileId: access.profileId,
          snapshotReference: CatalogueAgreementPolicy.snapshotReference,
        ),
        rightsDeclaration: CatalogueRightsDeclaration(
          originalWorkDeclared: _originalWorkDeclared,
          rightsConfirmed: _rightsConfirmed,
          acceptedByUid: uid,
          acceptedAt: now,
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
      await CatalogueDesignService.submitForReview(designId);
      if (!mounted) return;
      setState(() => _saving = false);
      _message(
        'Design submitted for Admin review. Structured conversion is queued.',
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to submit Catalogue design.\n$error', error: true);
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
        title: const Text('Designer Catalogue Upload'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Designer Catalogue Agreement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(CatalogueAgreementPolicy.summary),
                const SizedBox(height: 8),
                Text(
                  'Version ${CatalogueAgreementPolicy.currentVersion}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreementAccepted,
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _agreementAccepted = value ?? false),
                  title: const Text('I accept the current Catalogue agreement'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CatalogueUploadForm(
            formKey: _formKey,
            enabled: !_saving,
            designerMode: true,
            onChanged: (value) => _value = value,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _originalWorkDeclared,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _originalWorkDeclared = value ?? false,
                        ),
                  title: const Text('This design is my original work'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rightsConfirmed,
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _rightsConfirmed = value ?? false),
                  title: const Text(
                    'I hold the required rights to submit this design',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _uploadAndSubmit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_saving ? 'Submitting...' : 'Upload and Submit'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
