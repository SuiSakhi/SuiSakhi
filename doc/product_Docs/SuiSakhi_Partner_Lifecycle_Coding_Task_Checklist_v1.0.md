# SuiSakhi Partner Lifecycle Coding Task Checklist v1.0

**Status:** Approved development checklist after Partner Engagement Architecture v1.0 freeze  
**Date:** 1 September 2026  
**Branch:** `suisakhi-android-package-migration`  
**Known analyzer baseline:** 10 issues  
**Architecture source of truth:** `doc/product_Docs/SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL.md`

---

## 1. Development Principles

- [ ] Preserve the working Partner Application, KYC, Admin review and Workshop Details foundation.
- [ ] Use additive, backward-compatible changes rather than rebuilding the module.
- [ ] Keep existing `partnerType` while introducing `partnerCategoryCodes`.
- [ ] Keep existing Workshop data readable while introducing common Business and Operations data.
- [ ] Do not combine architecture-document commits with application-code commits.
- [ ] Complete each feature end to end before starting the next feature.
- [ ] Run formatting, analyzer, rules validation, functional testing, commit and push after every stable slice.
- [ ] Expected `flutter analyze lib` result remains 10 known issues unless intentionally improved.
- [ ] Update `doc/SuiSakhi_PROJECT_CONTEXT.md` after every major Partner milestone.

---

## 2. Architecture Freeze and Repository Preparation

### 2.1 Freeze documents

- [ ] Promote `SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL_FREEZE_CANDIDATE.md` to `SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL.md`.
- [ ] Verify that the FINAL document includes all approved updates from the final review.
- [ ] Move `SuiSakhi_Partner_Engagement_Architecture_v1.0_DRAFT.md` to an archive folder.
- [ ] Move `SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL_REVIEW.md` to the same archive folder.
- [ ] Keep only the FINAL document in the active `doc/product_Docs/` folder.
- [ ] Add a concise Partner Architecture reference to the Master Architecture.
- [ ] Commit documentation separately.

Recommended active file:

```text
doc/product_Docs/SuiSakhi_Partner_Engagement_Architecture_v1.0_FINAL.md
```

Recommended archive location:

```text
doc/product_Docs/archive/partner_engagement_v1.0/
```

### 2.2 Baseline validation

- [ ] Run `git status --short`.
- [ ] Run `git log -5 --oneline`.
- [ ] Run `flutter analyze lib`.
- [ ] Confirm 10 known issues.
- [ ] Run `git diff --check`.
- [ ] Confirm current branch is `suisakhi-android-package-migration`.
- [ ] Confirm current remote branch is pushed.

---

## 3. Checkpoint the Existing Workshop Foundation

Expected files from the current incomplete Partner slice:

```text
lib/models/partner_application.dart
lib/services/partner_service.dart
lib/screens/partner/tailor_application_screen.dart
firebase/firestore.rules
```

- [ ] Test current Tailor application loading.
- [ ] Test Workshop data loading.
- [ ] Test partial Workshop save as `inProgress`.
- [ ] Test complete Workshop save as `completed`.
- [ ] Test Firestore nesting under `onboardingData.extensions.tailor.workshopDetails`.
- [ ] Test Draft and Changes Requested permissions.
- [ ] Confirm Submitted and Under Review are read-only.
- [ ] Confirm Firestore rules reject unauthorized fields.
- [ ] Create and push a stable Workshop-foundation checkpoint before simplifying the UX.

---

## 4. Sprint 1: Simplify the Existing Tailor Application

### 4.1 Unified Save Draft

- [ ] Remove the visible `Save Workshop Details` button.
- [ ] Retain the internal Workshop save logic as a reusable service where helpful.
- [ ] Make `Save Draft` persist Basic Details and Business/Workshop data together.
- [ ] Make `Submit for Review` first persist the full draft, then submit.
- [ ] Ensure a failed save prevents submission.
- [ ] Show one clear success or error message.
- [ ] Preserve resume behavior after reopening the screen.

### 4.2 Common Business and Operations terminology

- [ ] Display `Business and Operations` as the common section name.
- [ ] Preserve legacy `workshopDetails` storage for backward compatibility.
- [ ] Add a compatibility reader between legacy Workshop data and common Business data.
- [ ] Do not perform destructive Firestore migration in this sprint.

### 4.3 Standardized location

- [ ] Replace State free text with metadata-driven State selection.
- [ ] Replace City free text with dependent City selection.
- [ ] Store State and City codes plus labels.
- [ ] Validate six-digit Indian pincode during the pilot.
- [ ] Add business-address normalization.
- [ ] Add map-location selection as a separate small implementation slice.
- [ ] Store `placeId`, `formattedAddress`, `latitude`, `longitude` and `geoHash` automatically.
- [ ] Never require the Partner to type coordinates.
- [ ] Protect exact home-based Partner addresses from public visibility.

### 4.4 Standardized operating hours

- [ ] Replace opening-time free text with a time picker.
- [ ] Replace closing-time free text with a time picker.
- [ ] Store normalized 24-hour values such as `09:00` and `21:00`.
- [ ] Add operating-day selection.
- [ ] Add weekly holiday or closure support.

### 4.5 Tailor skills and expertise

- [ ] Add multi-select checkboxes or chips.
- [ ] Include Blouse, Kurti/Suit, Dress, Lehenga, Bridal, Designer Wear, Alteration, Pico/Fall, Embroidery, Aari, Zardozi, Girls Wear, School Uniform, Wedding Orders and Urgent Orders.
- [ ] Add `Other Expertise` checkbox.
- [ ] Add Additional Expertise description.
- [ ] Store metadata codes, not labels.
- [ ] Keep experience years out of Partner registration and capture it during KYC.

### 4.6 Tailor measurement compatibility

- [ ] Capture acceptance of SuiSakhi Standard Measurement Sheet.
- [ ] Capture trained-measurer support.
- [ ] Capture old-garment reference support.
- [ ] Capture video-measurement support.
- [ ] Capture QC re-measurement support.
- [ ] Capture doorstep-measurement support.
- [ ] Capture final-measurement verification capability.

---

## 5. Sprint 2: Partner Agreement and Submission

### 5.1 Agreement model

- [ ] Add agreement version.
- [ ] Add accepted flag.
- [ ] Add accepted timestamp.
- [ ] Add accepting UID.
- [ ] Add message or agreement snapshot reference.
- [ ] Add commercial-terms version and risk-policy version where applicable.

### 5.2 Agreement UI

- [ ] Display common Partner clauses.
- [ ] Display Tailor-specific clauses.
- [ ] Require explicit Partner acceptance.
- [ ] Do not allow Admin to accept the agreement on the Partner's behalf.
- [ ] Disable submission until the current required agreement version is accepted.
- [ ] Replace `Submit for Review` with `Accept and Submit for Review` where appropriate.

### 5.3 Submission validation

- [ ] Validate minimum Partner-submitted information.
- [ ] Allow optional or Admin-completable fields to remain incomplete.
- [ ] Record a completeness snapshot at submission.
- [ ] Preserve submitted data for Admin comparison.

---

## 6. Sprint 3: Complete the Admin Review Loop

### 6.1 Admin screen visibility

- [ ] Show all Partner-submitted Basic Details.
- [ ] Show Business and Operations.
- [ ] Show normalized location and map coordinates.
- [ ] Show Tailor skills and expertise.
- [ ] Show measurement-compatibility capabilities.
- [ ] Show agreement version and acceptance.
- [ ] Show KYC status and verification history.
- [ ] Show application status and review history.
- [ ] Clearly mark legacy Verified sections that lack structured data.

### 6.2 Admin-assisted gap analysis

- [ ] Add a structured gap list.
- [ ] Classify gaps by section and field.
- [ ] Mark whether Partner action is required.
- [ ] Mark whether Admin may complete the field.
- [ ] Capture clarification source, reason code and notes.
- [ ] Allow Admin to update permitted minor fields.
- [ ] Require Partner confirmation for material changes.
- [ ] Preserve before and after values in audit history.

### 6.3 Review actions

- [ ] Request Changes with standardized reason codes and comments.
- [ ] Reject with reason code and Customer-visible explanation.
- [ ] Start or continue KYC.
- [ ] Approve according to delegated authority.
- [ ] Prevent approval when required readiness conditions fail.

---

## 7. Sprint 4: Roles, Authorization and Sensitive Data

### 7.1 Backend role foundation

- [ ] Add `superAdmin`.
- [ ] Add `admin`.
- [ ] Add `verificationKyc`.
- [ ] Add `commercial`.
- [ ] Add `partnerOperations`.
- [ ] Add `helpdesk`.
- [ ] Allow one test UID to hold multiple roles without merging permissions.
- [ ] Move authorization decisions into backend rules and reusable permission helpers.

### 7.2 Sensitive data separation

- [ ] Separate public Partner profile data.
- [ ] Separate private KYC data.
- [ ] Separate private finance and settlement data.
- [ ] Separate agreements.
- [ ] Separate capabilities and commercial profiles.
- [ ] Separate immutable audit events.
- [ ] Ensure Helpdesk cannot access KYC, Aadhaar, bank or settlement data.
- [ ] Ensure no sensitive information is placed in QR codes or notification payloads.

### 7.3 Negative permission testing

- [ ] Partner cannot verify KYC.
- [ ] Helpdesk cannot approve Partner.
- [ ] Helpdesk cannot modify rates.
- [ ] Admin cannot bypass Super Admin-only policy overrides.
- [ ] Customer cannot edit governed metadata.
- [ ] Partner cannot edit global standards.

---

## 8. Sprint 5: KYC, Certification and Operational Readiness

### 8.1 KYC workflow

- [ ] Identity verification.
- [ ] Address verification.
- [ ] Business verification.
- [ ] Document verification.
- [ ] Video verification where required.
- [ ] Background check where required.
- [ ] Duplicate or fraud check.
- [ ] Optional physical verification.
- [ ] Audited override with reason code where policy allows.

### 8.2 KYC-captured Tailor data

- [ ] Years of experience.
- [ ] Master Tailor count.
- [ ] Helpers.
- [ ] Finishers.
- [ ] Seasonal workforce.
- [ ] Verified normal and peak capacity.
- [ ] Bridal or premium capacity.
- [ ] Optional Workshop or business photographs.
- [ ] Certificates and business documents.

### 8.3 Certification

- [ ] Metadata-driven certification levels.
- [ ] Tailor Level 1, 2 and 3 foundation.
- [ ] Certification evidence.
- [ ] Effective and expiry dates.
- [ ] Certification history.
- [ ] Assignment eligibility by certification.

### 8.4 Operational readiness checklist

- [ ] Agreement accepted.
- [ ] KYC verified.
- [ ] Partner categories configured.
- [ ] Services and skills configured.
- [ ] Service area configured.
- [ ] Availability configured.
- [ ] Capacity configured.
- [ ] Commercial profile ready.
- [ ] Rate card ready.
- [ ] Settlement method ready.
- [ ] Notifications enabled.
- [ ] Category readiness completed.
- [ ] Partner understands assignment acceptance.

---

## 9. Sprint 6: Multi-Category Partner Foundation

- [ ] Add `partnerCategoryCodes` while retaining legacy `partnerType`.
- [ ] Add one canonical Partner Profile.
- [ ] Add category-level readiness.
- [ ] Add category-level availability.
- [ ] Add category-level capacity.
- [ ] Add category-level service areas where required.
- [ ] Add category-level commercials.
- [ ] Add category-level suspension without suspending unrelated categories.
- [ ] Add compatibility migration for existing Tailor applications.

---

## 10. Sprint 7: Remaining Phase-1 Partner Extensions

### 10.1 Measurement Partner

- [ ] Home-visit measurement.
- [ ] Video-assisted measurement.
- [ ] Standard manual measurement.
- [ ] Old-garment reference measurement.
- [ ] AI measurement validation support.
- [ ] Re-measurement and correction.
- [ ] Final measurement date and time.
- [ ] Measurement version and provenance.
- [ ] Prevent silent overwrite of Customer, Tailor or Final Confirmed versions.

### 10.2 Designer Partner

- [ ] Design capabilities.
- [ ] Upload/catalog eligibility.
- [ ] Ownership declaration.
- [ ] Expected design price.
- [ ] Designer share.
- [ ] SuiSakhi share.
- [ ] Royalty model.
- [ ] Commercial acceptance and versioning.

### 10.3 Doorstep / Quick-Fix

- [ ] Structured quick-fix services.
- [ ] Other Service checkbox.
- [ ] Other Service description.
- [ ] Visit charge.
- [ ] Service radius.
- [ ] Same-day and emergency eligibility.
- [ ] Before/after evidence.
- [ ] Customer OTP completion.

### 10.4 Boutique

- [ ] Keep Boutique separate from Tailor.
- [ ] Add customer relationship and order coordination.
- [ ] Add catalog and fashion-guidance capability.
- [ ] Add measurement coordination.
- [ ] Add trial coordination.
- [ ] Add alteration coordination.
- [ ] Add delivery coordination.
- [ ] Permit optional Designer or Tailor category on the same profile.

### 10.5 Laundry

- [ ] Wash, temperature, chemical and detergent capabilities.
- [ ] Stain and damage classification.
- [ ] Customer approval for high-risk treatment.
- [ ] Premium and bridal care.
- [ ] Pickup/delivery and express processing.

### 10.6 Pressing

- [ ] Hand, steam, roll, vacuum and dry press.
- [ ] Temperature and protective-cloth rules.
- [ ] Embellishment protection.
- [ ] Fabric-care compatibility.

### 10.7 Delivery Partner

- [ ] Pickup.
- [ ] Customer delivery.
- [ ] Inter-Partner transfer.
- [ ] Return pickup.
- [ ] Pickup, handover and delivery OTP.
- [ ] QR scanning.
- [ ] Photo, GPS and timestamp evidence.
- [ ] Fragile or sensitive garment handling.

### 10.8 Brand Partner

- [ ] Brand identity and ownership evidence.
- [ ] Ready-made and made-to-order products.
- [ ] Brand-owned designs.
- [ ] Campaigns and regional availability.
- [ ] Sponsored offers.
- [ ] Fulfillment and return policy.

---

## 11. Sprint 8: Commercial and Rate Management

- [ ] Partner expected rate.
- [ ] Negotiated Partner cost.
- [ ] Customer selling price.
- [ ] Platform fee.
- [ ] Tax.
- [ ] Discount and funding source.
- [ ] Incentive.
- [ ] Penalty.
- [ ] Settlement amount.
- [ ] Standard, Peak, Express, Emergency, Bulk and Package rates.
- [ ] Rate dimensions by service, garment, material, complexity, capability, location, quantity and season.
- [ ] Version and effective dates.
- [ ] Partner acceptance of negotiated rates.
- [ ] Order snapshot of applied rate and version.

---

## 12. Sprint 9: Design Catalog Management

- [ ] SuiSakhi-owned Free Catalog.
- [ ] SuiSakhi-owned Paid Catalog.
- [ ] Designer-owned Catalog.
- [ ] Boutique-owned Catalog.
- [ ] Commissioned and licensed Catalog.
- [ ] Single design upload.
- [ ] Bulk ZIP + Excel upload.
- [ ] Metadata review.
- [ ] Ownership and rights evidence.
- [ ] Free/Paid/Premium/Subscription/Royalty classification.
- [ ] Designer expected price and approved price.
- [ ] Designer and SuiSakhi shares.
- [ ] Approve, publish, unpublish and archive.
- [ ] Restrict Phase-1 fabric visualization to approved standardized catalog designs.

---

## 13. Sprint 10: Availability, Capacity and Assignment

### 13.1 Availability

- [ ] Available.
- [ ] Busy.
- [ ] Paused.
- [ ] Emergency Stop.
- [ ] Suspended.
- [ ] Inactive.
- [ ] Pause reason and resume date.
- [ ] Category-level availability.

### 13.2 Capacity

- [ ] Normal capacity.
- [ ] Peak capacity.
- [ ] Current load.
- [ ] Remaining capacity.
- [ ] Green, Yellow and Red thresholds.
- [ ] Capacity history and Admin override audit.

### 13.3 Assignment

- [ ] Eligibility engine.
- [ ] Skill, material, service area, certification and SLA matching.
- [ ] Sequential assignment by default.
- [ ] Controlled parallel offer for peak season.
- [ ] Atomic winning acceptance.
- [ ] Decline reason codes.
- [ ] Clarification workflow.
- [ ] Acceptance timeout.
- [ ] Admin intervention queue.

### 13.4 Acceptance before payment

- [ ] Customer order remains Pending Assignment.
- [ ] Partner must accept.
- [ ] Capacity reservation created after acceptance.
- [ ] Payment requested only after acceptance.
- [ ] Payment window and expiry.
- [ ] Capacity released on payment expiry.
- [ ] Order confirmed only after payment.

---

## 14. Sprint 11: SLA, Custody, Evidence and Recovery

### 14.1 SLA

- [ ] SLA code and version snapshot.
- [ ] Planned milestones.
- [ ] Delay-risk reporting.
- [ ] Customer communication before breach.
- [ ] Recovery decision.
- [ ] Revised commitment.
- [ ] Delay reason codes.

### 14.2 Custody

- [ ] Garment ID.
- [ ] Fabric or material bundle ID.
- [ ] Reference garment.
- [ ] Sample garment.
- [ ] Accessory bundle.
- [ ] QR and human-readable code.
- [ ] Handover events.
- [ ] Current custodian.

### 14.3 Loss and damage

- [ ] Incident creation.
- [ ] Evidence collection.
- [ ] Customer notification.
- [ ] Partner response.
- [ ] Responsibility decision.
- [ ] Recovery or compensation.
- [ ] Ledger adjustment.
- [ ] Performance impact.
- [ ] Evidence retention hold.

### 14.4 Rework and QC

- [ ] Defect classification.
- [ ] Applied standard and version.
- [ ] Responsibility attribution.
- [ ] Rework SLA.
- [ ] Customer communication.
- [ ] Commercial responsibility.

### 14.5 Partner DNA reports

- [ ] Tailor DNA.
- [ ] Laundry DNA.
- [ ] Pressing DNA.
- [ ] Applied standard and version.
- [ ] Methods, materials and parameters.
- [ ] QC result.
- [ ] Exceptions and evidence.

---

## 15. Sprint 12: Admin 360, Helpdesk and Governance

### 15.1 Partner dashboard

- [ ] Counts by Partner category.
- [ ] Counts by application status.
- [ ] Counts by KYC status.
- [ ] Counts by availability.
- [ ] Pending assignment and emergency metrics.

### 15.2 Partner 360

- [ ] Identity and business.
- [ ] Categories and capabilities.
- [ ] KYC and agreement.
- [ ] Commercials and settlement.
- [ ] Availability and capacity.
- [ ] Orders and assignments.
- [ ] Performance, incidents and support.
- [ ] Catalog and audit.

### 15.3 Customer 360

- [ ] Account and profiles.
- [ ] Family members and addresses.
- [ ] Measurements.
- [ ] Orders and Partner relationships.
- [ ] Designs, subscription and financial history.
- [ ] Tickets, incidents and communications.

### 15.4 Helpdesk and chatbot

- [ ] L0 Chatbot.
- [ ] L1 Helpdesk.
- [ ] L2 Partner Operations.
- [ ] L3 Admin.
- [ ] L4 Super Admin.
- [ ] Service/Order 360 only for Helpdesk.
- [ ] Mask sensitive Customer and Partner data.
- [ ] Ticket reason codes, SLA and escalation.
- [ ] No KYC, bank, settlement, role or metadata access for Helpdesk.

---

## 16. Sprint 13: Metadata Control Center

### P0

- [ ] Partner categories.
- [ ] Services and sub-services.
- [ ] Skills.
- [ ] Garments and materials.
- [ ] Capability levels.
- [ ] SLA and QC.
- [ ] Reason codes.
- [ ] Partner statuses and pause reasons.
- [ ] Basic rate cards and discounts.
- [ ] Notification templates.

### P1

- [ ] Stitching standards.
- [ ] Laundry standards.
- [ ] Pressing standards.
- [ ] Doorstep standards.
- [ ] Certification.
- [ ] Capacity units.
- [ ] Assignment rules.
- [ ] Packages.
- [ ] Partner-specific rate overrides.

### Controls

- [ ] Versioning.
- [ ] Effective dates.
- [ ] Approval.
- [ ] Impact analysis.
- [ ] Scheduled activation.
- [ ] Superseding or rollback version.
- [ ] Usage and audit history.

---

## 17. Standard Validation for Every Coding Slice

```bash
dart format <changed-files>
flutter analyze lib
git diff --check
```

- [ ] Analyzer returns the known 10-issue baseline.
- [ ] Firestore rules compile.
- [ ] Positive permission tests pass.
- [ ] Negative permission tests pass.
- [ ] Existing Tailor application loads.
- [ ] Draft resume works.
- [ ] Admin review works.
- [ ] Changes Requested works.
- [ ] No unrelated regression.
- [ ] Commit is focused.
- [ ] Push succeeds.

---

## 18. Definition of Done for Partner Lifecycle v1.0

- [ ] All nine Phase-1 categories are represented in metadata.
- [ ] Tailor flow works end to end.
- [ ] At least the pilot-required extensions work for all other categories.
- [ ] Partner Agreement is versioned and accepted.
- [ ] Admin-assisted gap analysis is functional and audited.
- [ ] KYC is role-controlled.
- [ ] Operational readiness gates activation.
- [ ] Partner and Customer 360 foundations are available.
- [ ] Helpdesk sees only Service/Order 360.
- [ ] Availability and capacity control assignment.
- [ ] Partner acceptance precedes Customer payment.
- [ ] Pending Assignment Admin intervention works.
- [ ] Reason codes and notifications are metadata-driven.
- [ ] SLA, custody, loss, damage, rework and dispute flows are auditable.
- [ ] Design Catalog supports SuiSakhi and Partner ownership.
- [ ] Commercial rates are accepted, versioned and snapshotted.
- [ ] Major decisions are recorded in `SuiSakhi_PROJECT_CONTEXT.md`.

---

**End of SuiSakhi Partner Lifecycle Coding Task Checklist v1.0**
