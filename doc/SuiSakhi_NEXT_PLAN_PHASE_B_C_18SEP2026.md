# SuiSakhi Catalogue Next Plan: Phase B and Phase C

## Immediate Navigation Fix

After successful Edit and Resubmit, navigate to:

```dart
context.go('/owner/catalogue');
```

Recommended success message before navigation:

```text
Corrected design resubmitted for review.
```

This replaces navigation back to the same Review route and prevents a confusing route stack.

## Phase B: Designer Catalogue Operations

1. Build Designer Catalogue dashboard.
2. List only Designs owned/submitted by the active approved Designer profile.
3. Show Draft, Processing, Ready For Review, Changes Requested, Approved, Published, and Rejected filters.
4. Connect Designer upload from the dashboard.
5. Show Admin comments and final rejection reason.
6. Reuse Version correction service for Designer Edit and Resubmit.
7. Add Apply Again where permitted.
8. Enforce read-only Approved and Published states.
9. Add Firestore rules for own Draft and Changes Requested only.
10. Add Storage authorization for own correction Draft Views only.
11. Run security-negative tests using Customer and another Designer account.

## Phase C: Processing and Customer Publication

1. Review `firebase/functions/index.js` and `package.json`.
2. Define per-view processing job contract.
3. Trigger processing for queued View originals.
4. Produce normalized preview and thumbnail first.
5. Add structured SVG generation as a separate controlled stage.
6. Store processing engine/version, quality score, warnings, present layers, and missing layers.
7. Add Admin manual-review and processing-approval action.
8. Permit publication only when required Views are completed/approved.
9. Build Customer Catalogue using only Approved + Published Designs.
10. Add multi-view Customer gallery, Saved Designs, and immutable Order snapshot.

## Checkpoints

```text
Checkpoint B1: Designer dashboard and own-design read rules
Checkpoint B2: Designer upload and Changes Requested correction
Checkpoint B3: Apply Again and security regression
Checkpoint C1: Normalized preview and thumbnail worker
Checkpoint C2: Structured SVG worker and quality review
Checkpoint C3: Publishing and Customer Catalogue
```
