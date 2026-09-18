# Changes Requested and Corrected Version Implementation Plan

## Scope of this package

This package freezes the implementation contract for the next code slice. Do not overwrite the currently working multi-view upload and display files until complete replacement files are generated and analyzer-tested.

## Required root Design fields

```text
reviewedVersionId: string?
latestReviewEventId: string?
changeRequestScope: entireDesign | metadata | commercial | views | mixed | null
affectedViewIds: string[]
applyAgainAllowed: bool
reviewNotes: string?
rejectionReason: string?
```

## Required Version fields

```text
sourceVersionId: string?
versionStatus: draft | submitted | underReview | changesRequested | approved | rejected | superseded
correctionReason: string?
primaryViewId: string?
viewCount: int
```

## Required View fields

```text
sourceVersionId: string?
sourceViewId: string?
inherited: bool
replacementReason: string?
```

## Required review-event structure

```text
designs/{designId}/review_events/{eventId}

action: requestChanges | reject | approve | override | resubmit
sourceLifecycle: string
targetLifecycle: string
reviewedVersionId: string
changeRequestScope: string?
affectedViewIds: string[]
notes: string?
reason: string?
actorUid: string
createdAt: timestamp
```

## Service operations

```text
requestChanges(...)
createCorrectedVersion(...)
inheritView(...)
replaceView(...)
removeDraftView(...)
updateDraftMetadata(...)
resubmitCorrectedVersion(...)
applyAgain(...)
```

## UI behavior

### Admin review

- Request Changes opens scope selection.
- Admin may select Entire Design, Metadata, Commercial, Specific Views, or Mixed.
- When Specific Views or Mixed is selected, Front/Back/Side/Detail checkboxes appear.
- Notes are mandatory.
- A review event is created atomically with root Design summary update.

### Contributor correction

- Changes Requested banner and Admin comments appear above the form.
- Form is pre-populated from the reviewed Version.
- Existing Views show Keep Existing, Replace, Remove, View Type, Primary View.
- Add Another View remains available, maximum 10.
- Saving creates or updates only a Draft correction Version.
- Submit validates 1 to 10 Views and exactly one valid Primary View.

### Approval freeze

- Approved Version and Views must become immutable to contributor.
- Later changes create a new governed Draft Version.
- Current approved Version remains active until replacement approval.

## Security requirements

- Admin may request changes, reject, approve, override with audit, and manage Admin-created Draft correction Versions.
- Designer may read own Design and edit only own Draft correction Version when root lifecycle is Draft or Changes Requested.
- Designer cannot change approved charge, Admin review fields, approved/publication status, ownership, agreement snapshot, or prior Versions.
- Submitted/reviewed/approved View originals remain immutable.

## Recommended implementation sequence

1. Extend model serialization with nullable defaults for backward compatibility.
2. Add immutable review event service.
3. Add corrected-Version cloning service.
4. Add pre-populated correction screen for Admin-created records.
5. Add resubmission transaction.
6. Add Firestore rules and emulator tests.
7. Add Designer dashboard and ownership authorization.
8. Add Apply Again.
