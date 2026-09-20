# SuiSakhi Catalogue Processing C1.1 Tracker

**Status:** Architecture review package generated
**Date:** 20 September 2026

## Confirmed Existing Foundation

- [x] Multi-view immutable original path exists.
- [x] View model supports original, normalized, thumbnail and structured assets.
- [x] Per-View and Version processing result models exist.
- [x] Admin review screen displays selected View processing status.
- [x] Publication is currently gated by Version processing status.
- [x] Storage rules deny client derivative writes.
- [x] Firebase Functions codebase exists under `firebase/functions`.
- [x] Functions runtime is Node.js 20.
- [x] Existing WhatsApp callable must be preserved.

## Gaps Identified

- [ ] No Storage-triggered Catalogue processor exists.
- [ ] No image-processing dependency exists in Functions package.
- [ ] No processing-event worker contract is implemented.
- [ ] Version status is not aggregated from all active Views.
- [ ] Publication readiness does not yet verify every active View asset.
- [ ] Admin UI does not display derivative assets, warnings, engine or version.
- [ ] No Admin retry or processing-approval action exists.
- [ ] Legacy and multi-view migration policy is not implemented.

## C1.1 Freeze Checklist

- [ ] Review storage paths.
- [ ] Review normalization dimensions and quality.
- [ ] Review thumbnail dimensions and fit mode.
- [ ] Review use of `manualReviewRequired` for completed-with-warnings.
- [ ] Review quality warning codes.
- [ ] Review publication-readiness rules.
- [ ] Confirm Functions region and Storage bucket location.
- [ ] Freeze architecture before C1.2 coding.
