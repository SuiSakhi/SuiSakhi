# SuiSakhi Customer Catalogue Architecture v1.1 Addendum

**Status:** IMPLEMENTATION BASELINE, PENDING FULL REGRESSION
**Parent document:** `SuiSakhi_CUSTOMER_ORDER_CATALOGUE_ARCHITECTURE_v1.0_FINAL.md`
**Updated:** 18 September 2026
**Scope:** Multi-view Catalogue, governed review, correction versioning, approval freeze, Designer workflow, processing, and publication deltas.

---

## 1. Documentation Governance

The v1.0 FINAL architecture remains unchanged as the historical baseline.

This v1.1 Addendum records implementation-discovered architecture rules. After the complete Catalogue workflow is security-tested and regression-tested, v1.0 and this addendum will be consolidated into:

```text
doc/SuiSakhi_CUSTOMER_ORDER_CATALOGUE_ARCHITECTURE_v1.1_FINAL.md
```

---

## 2. ARCH-CAT-006: Multi-View Design Versions

A governed Catalogue Design Version supports one to ten independently classified Design Views.

Phase-1 view types:

```text
Front
Back
Side
Detail
Combined Front + Back
Single View
```

Rules:

```text
Minimum Views: 1
Maximum Views: 10
Exactly One Primary View
```

Valid Primary View types:

```text
Front
Combined Front + Back
Single View
```

Back, Side, and Detail are supporting Views and cannot become Primary.

SuiSakhi does not automatically duplicate, merge, split, or fabricate missing Views during Phase 1. AI may later recommend View classification, but an authorized contributor or Admin confirms the classification.

---

## 3. ARCH-CAT-007: Pre-Approval Edit and Resubmit

Before Admin approval, an authorized Catalogue contributor may correct all editable design information when the Design is:

```text
Draft
Changes Requested
Rejected with Apply Again permitted
```

Editable information includes:

```text
Design title
Description
Garment type
Occasion
Commercial classification
Contributor price proposal
Admin charge, for Admin-created designs
Design Views
Uploaded View images
View Type
Display order
Primary View
Additional supporting Views
```

The contributor-facing action is:

```text
Edit and Resubmit
```

Internally, SuiSakhi creates a new immutable Design Version. The previously submitted Version and original assets remain unchanged for audit.

Implemented transition:

```text
Changes Requested
        -> Edit and Resubmit
        -> Correction Draft Version
        -> Resubmit for Review
        -> Ready For Review
```

---

## 4. ARCH-CAT-008: Approval Freeze

Once Admin approves a Catalogue Version, that Version is frozen.

Direct editing of an approved Version is prohibited.

Any later proposed change must create a governed new Draft Version. The currently approved Version remains active until the replacement Version is reviewed and approved.

```text
Approved Version
        -> Frozen
        -> New Change Request, when needed
        -> New Draft Version
        -> Admin Review
        -> Replacement becomes active only after approval
```

This rule aligns Catalogue governance with approved Partner-profile change-review governance.

---

## 5. ARCH-CAT-009: View Inheritance and Replacement

A corrected Version may carry forward unchanged Views by reusing immutable asset references.

Inherited View metadata records:

```text
sourceVersionId
sourceViewId
inherited = true
```

A replaced View receives:

```text
New View ID
New immutable original asset
sourceVersionId
sourceViewId
inherited = false
```

A submitted Version is never overwritten.

---

## 6. ARCH-CAT-010: Immutable Review Events

Admin review actions create immutable events under:

```text
designs/{designId}/review_events/{eventId}
```

An event records:

```text
Action
Source lifecycle
Target lifecycle
Reviewed Version ID
Change-request scope
Affected View IDs
Admin comments or reason
Actor UID
Timestamp
```

Supported review actions include:

```text
Request Changes
Approve
Reject
Override Decision
Resubmit
Apply Again
```

---

## 7. ARCH-CAT-011: Changes Requested Behavior

When Admin requests changes:

```text
Lifecycle = Changes Requested
Admin comments remain visible
Edit and Resubmit becomes available
```

The correction screen is pre-populated from the reviewed Version.

The contributor may:

```text
Keep an existing View
Replace an inherited View
Remove a View
Add a View
Change View Type
Change Primary View
Edit metadata
Edit permitted commercial fields
Resubmit the corrected Version
```

The corrected Version must still satisfy:

```text
1 to 10 Views
Exactly one valid Primary View
```

---

## 8. ARCH-CAT-012: Resubmission Navigation and Status

After a successful correction resubmission:

```text
Corrected Version becomes activeVersionId
Version status becomes submitted
Design lifecycle becomes Ready For Review
Processing status becomes queued
Correction Draft linkage is cleared
Review comments are cleared from the active action summary
A Resubmit review event is created
```

Recommended navigation after successful resubmission:

```text
Return to Governed Catalogue
```

This avoids trapping the user inside a replaced Review route and provides a clear completion point.

---

## 9. ARCH-CAT-013: Admin and Designer Action Separation

Admin may:

```text
Approve
Request Changes
Reject
Correct Admin-created Draft or Changes Requested designs
Override a prior decision with an audit reason
Publish
Unpublish
```

Designer Partner may:

```text
Create own Draft
Edit own Draft
Submit own Design
View review and processing status
Edit and Resubmit own Changes Requested Design
Apply Again when permitted
```

Designer Partner must not:

```text
Approve
Reject
Publish
Unpublish
Set Admin-approved charge
Modify another contributor's Design
Modify approved or previously submitted Versions
Modify ownership or agreement snapshots
```

---

## 10. ARCH-CAT-014: Processing and Publication

Each Design View is processed independently.

```text
Front View -> Front processing result
Back View -> Back processing result
Detail View -> Detail processing result
```

Current processing status after upload or image replacement:

```text
queued
```

Publication remains blocked until required processing reaches:

```text
completed
or
approved
```

The real structured SVG worker remains a later backend milestone.

---

## 11. Implemented Code Baseline

Implemented and validated at the current milestone:

```text
Governed Catalogue Design model
Version model
Multi-view model
Admin multi-view upload
Primary View validation
Admin Catalogue dashboard
Primary View preview
Multi-view review gallery
Request Changes lifecycle
Admin comments
Edit and Resubmit route
Correction Draft Version
Inherited Views
Replace / remove / add View
Change View Type
Change Primary View
Metadata correction
Commercial correction
Resubmit to Ready For Review
Legacy single-view compatibility
```

Known limitation:

```text
Older obsolete test records may not preview correctly.
These may be manually archived and are not migration priorities.
```

---

## 12. Next Milestones

### Phase B: Designer Catalogue Operations

```text
Designer Catalogue Dashboard
Designer-owned Draft listing
Changes Requested banner and comments
Designer Edit and Resubmit
Rejected reason and Apply Again
Designer-specific Firestore rules
Designer-specific Storage authorization
Read-only Approved and Published states
```

### Phase C: Processing and Customer Publication

```text
Inspect existing Firebase Functions project
Per-view processing worker
Image normalization
Structured monochrome SVG generation
Quality score and warnings
Manual review state
Admin processing approval
Publish approved Designs
Customer Catalogue query
Customer multi-view gallery
Saved Designs
Order design snapshot
```

---

## 13. Regression Requirements

Before freezing v1.1 FINAL:

```text
Legacy Single View test
One-image Single View test
Combined Front + Back test
Separate Front and Back test
Three-plus View test
Request Changes test
Edit metadata test
Replace View test
Add / remove View test
Primary View change test
Resubmit test
Approval freeze test
Designer authorization test
Processing test
Publication test
Customer Catalogue test
Firestore security test
Storage security test
Analyzer clean
```

---

**End of v1.1 Addendum Update**
