# SuiSakhi C1.4B-1 Designer Source View Foundation Tracker

**Status:** Package prepared for local installation and validation
**Architecture:** ARCH-CAT-007 v1.3 FINAL
**Start tag:** `catalogue-source-view-c1.4b1-start-23sep2026`

## Scope

C1.4B-1 adds a pure-Dart source-view inventory and missing-view planning
foundation above the existing persisted `CatalogueDesignView` contract.

## Included

- Canonical Front, Back, Left Side and Right Side planning concepts
- Source origin and evidence metadata
- Generic Side safety handling
- Combined Front/Back extraction readiness
- Single View classification readiness
- Detail-view supporting evidence
- Missing-view proposal planning
- Primary and duplicate warnings
- Focused Flutter unit tests

## Explicitly excluded

- Firebase writes
- Storage uploads
- AI reconstruction
- Generated Firestore View documents
- Changes to `CatalogueDesignViewType`
- Changes to upload/correction screens
- Masks
- SVG generation
- Material preview
- Measurements
- Customer Reference Design conversion

## Files

```text
lib/models/catalogue_source_view.dart
lib/services/catalogue_source_view_registry.dart
test/catalogue_source_view_registry_test.dart
```

## Installation

Copy the three implementation files into the matching repository paths.
Do not overwrite any existing file unless Git confirms the destination is new.

## Validation

```bash
dart format \
lib/models/catalogue_source_view.dart \
lib/services/catalogue_source_view_registry.dart \
test/catalogue_source_view_registry_test.dart
```

```bash
flutter analyze lib
```

```bash
flutter test \
test/catalogue_source_view_registry_test.dart
```

```bash
git diff --check
```

```bash
git status --short -- \
lib/models/catalogue_source_view.dart \
lib/services/catalogue_source_view_registry.dart \
test/catalogue_source_view_registry_test.dart
```

## Success criteria

- Analyzer baseline remains clean
- Focused tests pass
- Existing Catalogue models are unchanged
- No Firebase or rule changes
- No generated view is persisted
- Proposed missing views remain planning metadata only
