# SuiSakhi Customer Catalogue Architecture v1.1 Addendum

**Status:** Draft for implementation review
**Parent:** `SuiSakhi_CUSTOMER_ORDER_CATALOGUE_ARCHITECTURE_v1.0_FINAL.md`
**Date:** 18 September 2026

## Scope

This addendum records post-v1.0 Catalogue decisions discovered during implementation. It does not rewrite the frozen v1.0 document. After implementation and regression testing, the addendum may be consolidated into a new v1.1 FINAL architecture document.

## ARCH-CAT-006: Multi-view Design Versions

A Catalogue Design Version supports one to ten independently classified Design Views. Supported Phase-1 types are Front, Back, Side, Detail, Combined Front + Back, and Single View. Exactly one Primary View is required. Front, Combined Front + Back, and Single View are valid Primary types.

SuiSakhi does not automatically duplicate, merge, split, or fabricate missing views in Phase 1. AI may later recommend classification, but an authorized contributor or Admin confirms it.

## ARCH-CAT-007: Pre-approval Correction

Before Admin approval, an authorized contributor may correct all editable metadata, commercial proposal fields, Design Views, View Types, display order, and Primary View when the design is Draft, Changes Requested, or eligible for Apply Again.

The contributor-facing action is **Edit and Resubmit**. Internally, SuiSakhi creates a new immutable Design Version. Previously submitted Versions and original assets remain unchanged for audit.

## ARCH-CAT-008: Approval Freeze

An approved Catalogue Version is immutable. Any later change creates a governed new Draft Version. The currently approved Version remains active until the replacement Version is reviewed and approved.

## ARCH-CAT-009: View Inheritance

A corrected Version may reuse immutable asset references for unchanged Views. Inherited View records preserve `sourceVersionId`, `sourceViewId`, and `inherited=true`. Replaced Views receive a new immutable original asset and `inherited=false`.

## ARCH-CAT-010: Review Events

Admin review actions create immutable events under:

```text
designs/{designId}/review_events/{eventId}
```

Events preserve action, source lifecycle, target lifecycle, reviewed Version, change scope, affected View IDs, notes/reason, actor UID, and timestamp.

## Documentation governance

- Keep the v1.0 FINAL document unchanged.
- Maintain this addendum during implementation.
- Update `SuiSakhi_PROJECT_CONTEXT.md` after each milestone.
- After correction, Designer permissions, processing, and customer publication are tested, consolidate v1.0 plus this addendum into `SuiSakhi_CUSTOMER_ORDER_CATALOGUE_ARCHITECTURE_v1.1_FINAL.md`.
