# SuiSakhi Catalogue Critical Project Context

**Status date:** 18 September 2026
**Working branch:** suisakhi-android-package-migration
**Last protected multi-view foundation commit:** c9add10

## 1. Frozen Catalogue architecture

- A Catalogue Design contains immutable, numbered Versions.
- A Version contains 1 to 10 independently classified Design Views.
- Supported view types: Front, Back, Side, Detail, Combined Front + Back, Single View.
- Exactly one Primary View is required. Valid Primary types are Front, Combined Front + Back, or Single View.
- Customer Reference uploads remain separate from governed Catalogue Designs.
- Original uploaded assets are immutable. Derived preview, thumbnail, and structured SVG assets are separate.
- Paid/Premium design charges are included in the order invoice. There is no separate normal-flow design-purchase transaction.

## 2. Implemented and tested

- Governed `designs/{designId}` collection.
- Version path: `designs/{designId}/versions/{versionId}`.
- Multi-view path: `designs/{designId}/versions/{versionId}/views/{viewId}`.
- Storage path: `catalogue_designs/{designId}/versions/{versionId}/views/{viewId}/original/source.ext`.
- Admin upload supports JPG/JPEG/PNG/WebP, 12 MB per view.
- Admin upload supports Free, Paid, Premium, governed garment and occasion metadata.
- Multi-view upload groups Front and Back under one design/version.
- Dashboard resolves Primary View and displays a view-count chip.
- Review screen displays a Front/Back/Side/Detail gallery with Primary/Supporting role and processing status.
- Legacy single-view records are supported in memory through a synthetic Single View fallback.
- Processing currently remains `queued`; real SVG/vectorization worker is not yet connected.
- Publish remains blocked until processing is `completed` or `approved`.

## 3. Current lifecycle decision

- Draft: editable.
- Uploaded / Processing / Ready for Review: read-only for contributor.
- Changes Requested: Admin comments visible; contributor may Edit and Resubmit.
- Rejected: final reason visible; Apply Again only when allowed.
- Approved: approved version frozen.
- Published: frozen and customer-visible when publication rules are satisfied.

Before approval, an authorized contributor may correct metadata, price proposal, views, view type, Primary View, and images. The UI presents this as **Edit and Resubmit**, but the application creates a new immutable Version. The previously submitted Version remains unchanged for audit.

After approval, direct editing is prohibited. Any later change creates a governed new Version while the approved Version remains active until the replacement Version is approved.

## 4. Correction/version rules

When Version 1 receives Changes Requested:

1. Create Version 2 as Draft.
2. Carry forward unchanged Views by reusing immutable asset references.
3. Record `sourceVersionId`, `sourceViewId`, and `inherited=true` for carried-forward Views.
4. Replacement Views receive new immutable assets and `inherited=false`.
5. Contributor may change metadata, commercial proposal, views, classifications, order, and Primary View before resubmission.
6. Resubmission activates Version 2 for review, not for customer publication.
7. Version 1 remains unchanged.

## 5. Current security status

- Firestore and Storage rules currently authorize configured Admin for governed Catalogue creation and multi-view upload.
- Designer-specific write authorization is not complete.
- The Designer upload UI exists, but production Designer upload must not be enabled until rules validate approved Designer profile ownership and lifecycle restrictions.
- Existing Storage originals are immutable (`update, delete: false`).

## 6. Current important files

- `lib/models/catalogue_design.dart`
- `lib/models/catalogue_design_version.dart`
- `lib/models/catalogue_design_view.dart`
- `lib/models/catalogue_design_asset.dart`
- `lib/models/catalogue_processing_status.dart`
- `lib/services/catalogue_design_service.dart`
- `lib/services/owner_catalogue_service.dart`
- `lib/widgets/catalogue/catalogue_upload_form.dart`
- `lib/widgets/catalogue/catalogue_view_upload_section.dart`
- `lib/screens/owner/owner_catalogue_screen.dart`
- `lib/screens/owner/owner_catalogue_review_screen.dart`
- `lib/screens/owner/owner_catalogue_upload_screen.dart`
- `lib/screens/partner/designer_catalogue_upload_screen.dart`
- `firebase/firestore.rules`
- `firebase/storage.rules`

## 7. Existing test-data notes

- Old legacy test records may have missing previews or separate Front/Back records. These may be manually archived later. Do not expend development effort migrating obsolete test data.
- Failed uploads may leave Draft designs or zero-view Versions. Add Resume/Archive Draft later; do not physically delete governed records during testing.

## 8. Immediate next milestones

1. Implement Changes Requested summary fields and immutable review events.
2. Implement Admin Edit and Resubmit correction screen.
3. Clone active Version into a new Draft Version with inherited Views.
4. Allow replace/remove/add/reclassify Views and change Primary View before approval.
5. Resubmit corrected Version.
6. Add Designer Catalogue dashboard and Designer-specific Firestore/Storage permissions.
7. Implement Rejected + Apply Again.
8. Inspect `firebase/functions/index.js` and implement per-view processing worker.
9. Publish approved designs and build customer-facing Catalogue.

## 9. Validation commands

```bash
flutter analyze lib
git diff --check
git status --short
```

Do not upgrade the discontinued package or the 74 constrained dependencies during Catalogue stabilization.

## 10. Recovery rule

Use this document together with `doc/SuiSakhi_PROJECT_CONTEXT.md` as the source of truth. After the correction workflow is completed, update both documents, commit only reviewed files, run analyzer, verify Firebase rules, and create a stable checkpoint.
