# SuiSakhi C1.4B-2 Source View Classification Metadata Tracker

**Status:** Package prepared for local installation and validation
**Architecture:** ARCH-CAT-007 v1.3 FINAL
**Parent checkpoint:** `catalogue-source-view-c1.4b1-15-tests-23sep2026`

## Purpose

C1.4B-2 adds optional, backward-compatible metadata above the persisted
C1.3 `CatalogueDesignViewType` values.

## Classification support

### Side

- Generic Side
- Left Side
- Right Side

### Detail

- Generic Detail
- Neck Detail
- Sleeve Detail
- Border Detail
- Embellishment Detail
- Closure Detail
- Construction Detail

### Combined

- Front/Back Composite
- Multi-View Composite

### Single View

- Unclassified Single View
- Likely Front
- Likely Back

## Safety boundaries

- Existing Firestore enum values remain unchanged
- Existing upload and correction screens remain unchanged
- No Firebase access
- No persistence
- No generated images
- No source-view reconstruction
- No masks or SVG
- No deployment

## Files

```text
lib/models/catalogue_source_view_classification.dart
lib/services/catalogue_source_view_classifier.dart
test/catalogue_source_view_classifier_test.dart
```

## Validation

```bash
dart format \
lib/models/catalogue_source_view_classification.dart \
lib/services/catalogue_source_view_classifier.dart \
test/catalogue_source_view_classifier_test.dart
```

```bash
flutter test test/catalogue_source_view_classifier_test.dart
```

```bash
flutter test \
test/catalogue_source_view_registry_test.dart \
test/catalogue_source_view_classifier_test.dart
```

```bash
flutter analyze lib
```

```bash
git diff --check
```

## Success criteria

- New classifier tests pass
- Existing B-1 registry tests still pass
- Analyzer remains clean
- No existing C1.3 model files change
- Directional side metadata improves canonical planning safely
