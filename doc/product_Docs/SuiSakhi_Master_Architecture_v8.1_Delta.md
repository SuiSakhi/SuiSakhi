# SuiSakhi Master Architecture v8.1 Delta

**Document Type:** Architecture Delta and Business Rules Addendum  
**Baseline:** SuiSakhi Master Architecture v8.0  
**Version:** 8.1 Draft  
**Date:** 21 August 2026  
**Status:** Review Draft  
**Scope:** Partner Management, Professional Admin Operations, Standardized Metadata, Governance, Notifications, and Helpdesk

---

## 1. Purpose

This document captures the architecture decisions, business rules, workflow refinements, data-model changes, and Admin-operating principles identified after the SuiSakhi v8.0 review.

The v8.1 delta establishes a reusable Partner Management foundation for all current and future Partner types. The Tailor Partner is the first implementation, but the same application, verification, approval, profile-creation, audit, notification, commercial, and lifecycle foundations must support every Partner category.

The implementation must continue to follow SuiSakhi's safe-development discipline:

```text
Small change
→ Format
→ Analyze
→ Test
→ Commit
→ Push
```

---

## 2. Core Architecture Direction

The permanent Partner lifecycle is:

```text
Customer Account
→ Partner Application
→ Admin Review
→ Information and Document Verification
→ KYC Verification
→ Capability Verification
→ Commercial Agreement
→ Admin Approval or Rejection
→ Partner Profile Creation
→ Partner Profile Activation
→ Profile Selection
→ Partner Portal
```

Saving or submitting an application must never directly activate a Partner profile.

```text
Application saved
≠ Partner approved
≠ Partner profile created
≠ Partner portal enabled
```

Only a completed Admin approval process may create and activate a Partner profile.

---

## 3. Partner Application Lifecycle

### 3.1 Supported statuses

```text
draft
submitted
underReview
changesRequested
approved
rejected
suspended
inactive
```

### 3.2 Primary lifecycle

```text
Draft
→ Submitted
→ Under Review
→ Approved
```

### 3.3 Correction lifecycle

```text
Under Review
→ Changes Requested
→ Applicant Updates Application
→ Submitted
→ Under Review
```

### 3.4 Final rejection lifecycle

```text
Under Review
→ Rejected
```

A rejected application remains available for audit, Helpdesk review, reporting, and future policy-controlled reapplication. It must not be physically deleted.

### 3.5 Suspension and inactivity

Suspension and inactivity apply to approved Partner relationships or profiles and must remain separate from application rejection.

```text
Approved Partner
→ Suspended
→ Reactivated or Inactive
```

---

## 4. Canonical Partner Application Rule

There must be only one current Partner application for each unique combination:

```text
accountId + customerProfileId + partnerType
```

The same application document must continue through the entire lifecycle:

```text
draft
→ submitted
→ underReview
→ changesRequested
→ submitted
→ approved or rejected
```

A change request or resubmission must not create a new Partner Application document.

Future reapplication after final rejection may use:

```text
attemptNumber
previousApplicationId
applicationVersion
reapplicationAllowedAt
```

Historical test or migration duplicates must be identified using account ID, Customer profile ID, Partner type, timestamps, status, and application content. Duplicate cleanup must never rely only on the mobile number.

---

## 5. Customer-Created Partner Applications

A Customer may initiate a Partner application from:

```text
My Account
→ Partner Opportunities
→ Become a Partner
→ Select Partner Type
```

The initial application may collect a small set of identifying information:

- Partner type
- Contact name
- Business or workshop name
- Authenticated mobile number
- Optional email address

Admin may request additional operational, capability, quality, KYC, document, service-area, and commercial information during review.

A Customer-created application requires Admin review and approval before a Partner profile can be created or activated.

---

## 6. Admin-Created Partners

Admin may initiate Partner onboarding directly through an **Add Partner** function.

An Admin-created Partner is treated as Admin-sponsored, but must use the same foundation as a Customer-created Partner:

- Partner Application model
- KYC verification
- Capability assessment
- Service-area assessment
- Commercial agreement
- Audit history
- Profile-creation service
- Suspension and reactivation process
- Notification framework

Admin-created Partners must not bypass the permanent profile architecture by writing only to legacy phone or email allow-lists.

Admin-sponsored onboarding must record:

```text
createdByUid
createdByType: admin
adminSponsored: true
approvedByUid
approvedAt
approvalReasonCode
verificationEvidence
```

---

## 7. Tailor Partner Onboarding

The Tailor Partner is the first implementation of the common Partner foundation.

### 7.1 Required onboarding areas

- Basic identity and contact information
- Workshop details
- Workshop address and operating hours
- Service-area pincodes
- Services and specialization
- Garment and fabric experience
- Machinery and equipment
- Team size and capacity
- Normal and seasonal capacity
- Measurement preferences
- Trial support
- Quality-control process
- Rework policy
- Expected Partner rates
- KYC documents
- Workshop photographs
- Declarations and agreements

### 7.2 Tailor certification levels

Suggested initial certification levels:

```text
Level 1: Rafu, repair, alterations, pico-fall
Level 2: Blouse, kurti, suit and girls wear
Level 3: Designer garments, lehenga and bridal
Level 4: Master tailor, premium boutique or wedding specialist
```

Certification must be metadata-driven and versioned.

---

## 8. Admin Review Process

### 8.1 Start Review

Only an application with status `submitted` may move to `underReview`.

The system must record:

```text
reviewedByUid
reviewedAt
updatedAt
```

Starting review does not approve the application and does not create a Partner profile.

### 8.2 Request Changes

Use Request Changes when the application can be corrected.

Examples:

- Missing workshop address
- Missing workshop photographs
- Incomplete service information
- Missing capacity details
- Missing service area
- Missing KYC document
- Missing expected rates
- Incorrect business name

The Admin must provide Customer-visible correction instructions.

```text
underReview
→ changesRequested
→ applicant updates
→ submitted
```

The applicant must be able to view the instructions, edit permitted fields, save the same application, and resubmit it.

### 8.3 Reject Application

Use Rejection for a final negative decision.

Examples:

- KYC failure
- Invalid or fraudulent documentation
- Duplicate or impersonated business
- Unsupported service category
- Compliance or safety concern
- Service location outside supported coverage
- Repeated refusal to provide mandatory information
- Permanent eligibility failure

Rejection must capture:

```text
rejectionReasonCode
rejectionReasonSnapshot
internalAdminNotes
rejectedByUid
rejectedAt
reapplicationAllowed
reapplicationAllowedAt
```

The applicant must see the Customer-visible reason. Internal Admin notes must remain private.

### 8.4 Approve Application

Approve must remain disabled until all mandatory approval conditions are satisfied:

```text
Application status = underReview
KYC status = verified
Mandatory onboarding sections = complete
Capabilities = verified
Commercial terms = accepted
Declaration = accepted
No unresolved change request
No final rejection
```

Approval must run as one controlled transaction.

---

## 9. Approval Transaction

The approval transaction must:

1. Validate Admin authorization.
2. Revalidate current application status.
3. Validate KYC and mandatory sections.
4. Validate commercial acceptance and declarations.
5. Create the Partner profile under the existing account.
6. Set the Partner profile status to `active`.
7. Set `approvalStatus` to `approved`.
8. Link the originating Partner Application.
9. Save `approvedPartnerProfileId` on the application.
10. Set application status to `approved`.
11. Record `approvedByUid` and `approvedAt`.
12. Recalculate or update the account profile count.
13. Create an approval audit event.
14. Create an in-app notification.
15. Queue external notification jobs.

After approval, the same account must show:

```text
Customer Profile
Tailor Profile
```

Selecting the Tailor profile must route to the existing Tailor Portal.

---

## 10. KYC and Verification

Application review and KYC status are separate controls.

### 10.1 KYC statuses

```text
notStarted
pendingDocuments
underVerification
verified
failed
expired
```

### 10.2 KYC process

Admin actions should support:

```text
Request Documents
Start Verification
Mark Verified
Mark Failed with Reason
Mark Expired
Request Updated Documents
```

### 10.3 KYC record

Suggested KYC fields:

```text
kycStatus
requiredDocumentCodes
receivedDocumentCodes
verificationNotes
verifiedByUid
verifiedAt
failureReasonCode
failureReasonSnapshot
expiryAt
lastUpdatedAt
```

KYC documents must follow secured storage, access-control, retention, and audit policies.

---

## 11. Onboarding Section Completion

Each onboarding section should have a real status instead of a static UI indicator.

```text
notStarted
inProgress
completed
verified
changesRequired
```

Suggested sections:

```text
basicDetails
workshopDetails
servicesAndSpecialization
capacityAndAvailability
measurementPreferences
qualityAndRework
expectedRates
documentsAndDeclaration
commercialTerms
```

Approval eligibility must be calculated from these section statuses and KYC status.

---

## 12. Standardized Central Metadata

All reusable messages, reason codes, status labels, notification templates, Admin prompts, and Customer-visible explanations should be centrally managed wherever practical.

Standardization provides:

- Consistent communication
- Reduced repeated free text
- Easier localization
- Cleaner analytics
- Faster Admin operations
- Lower risk of wording inconsistencies
- Easier policy updates
- Better audit reporting
- Reduced database-storage duplication

### 12.1 Central reason domains

- Partner rejection reasons
- Partner change-request reasons
- KYC failure reasons
- Partner suspension reasons
- Partner reactivation reasons
- Order cancellation reasons
- Order rework reasons
- QC failure reasons
- Payout hold reasons
- Refund reasons
- Helpdesk ticket categories
- Ticket priority reasons
- Escalation reasons

### 12.2 Suggested reason metadata

```text
reasonCode
reasonDomain
displayLabel
customerMessageTemplate
partnerMessageTemplate
adminGuidance
severity
customerVisible
partnerVisible
requiresFreeText
active
sortOrder
version
effectiveFrom
effectiveTo
```

### 12.3 Snapshot rule

Operational records should store both:

```text
reasonCode
reasonMessageSnapshot
```

The code enables standardization and analytics. The snapshot preserves the exact wording used at the time of the decision, even if centralized metadata changes later.

---

## 13. Standard Partner Rejection Reasons

Suggested initial reason codes:

```text
identity_verification_failed
workshop_verification_failed
service_area_not_supported
documents_invalid
duplicate_business
impersonation_suspected
unsupported_service_category
mandatory_information_missing
kyc_failed
safety_compliance_issue
commercial_terms_not_accepted
capacity_not_suitable
other
```

Admin should be able to:

```text
Select a standard reason
→ receive suggested Customer-visible text
→ keep the text
→ edit the text
→ replace it with an Other reason
```

Example:

```text
Reason Code:
workshop_verification_failed

Suggested Message:
The submitted workshop information could not be verified. Please contact
SuiSakhi Helpdesk if clarification is required.
```

---

## 14. Standard Change-Request Reasons

Suggested initial reason codes:

```text
workshop_address_required
workshop_photos_required
service_area_required
capacity_details_required
specialization_details_required
measurement_method_required
quality_policy_required
rework_policy_required
expected_rates_required
kyc_documents_required
business_name_correction_required
contact_details_correction_required
other
```

The selected reason should populate an editable Customer-visible instruction template.

---

## 15. Notification Policy

### 15.1 Channel policy

```text
Normal lifecycle update:
In-app

Action required:
In-app and WhatsApp

Formal approval or rejection:
In-app, WhatsApp and Email

Critical security, suspension or payout failure:
In-app, WhatsApp, Email and optional SMS
```

### 15.2 Notification reliability

The business transaction must complete before external notifications are attempted.

```text
Complete decision transaction
→ Create in-app notification
→ Queue WhatsApp job
→ Queue email job
→ Optionally queue SMS job
→ Retry failed deliveries
```

An external delivery failure must never reverse or roll back:

- Partner approval
- Partner rejection
- Suspension
- Reactivation
- Payout decision
- Order status decision

### 15.3 Notification record

Suggested fields:

```text
notificationId
accountId
profileId
recipientUid
category
templateCode
titleSnapshot
messageSnapshot
applicationId
partnerType
actionRoute
createdAt
readAt
channelsRequested
channelsDelivered
channelDeliveryStatus
retryCount
lastDeliveryAttemptAt
```

### 15.4 Example approval notification

```text
Title:
Tailor Partner Application Approved

Message:
Your SuiSakhi Tailor Partner application has been approved. Your Tailor
profile is now available in Profile Selection.

Action:
Open Profile Selection
```

### 15.5 Example rejection notification

```text
Title:
Partner Application Not Approved

Message:
SuiSakhi could not approve your Partner application. Open the application
to view the reason and Helpdesk options.

Action:
Open Partner Application
```

---

## 16. Professional Admin Design

The Admin platform must be organized by operational responsibility rather than as one large dashboard.

### 16.1 Partner Operations

```text
Partner Applications
Add Partner
Active Partners
Suspended Partners
Partner KYC
Capabilities
Capacity
Service Areas
Partner Performance
Certification
Partner Agreements
Partner Audit History
```

### 16.2 Order Operations

```text
All Orders
Assignment Queue
Production Tracking
Measurement Exceptions
Material Exceptions
QC Queue
Delivery Exceptions
Rework and Returns
Cancelled Orders
Archived Orders
SLA Monitoring
```

### 16.3 Catalog and Metadata

```text
Design Catalog
Garment Master
Fabric Master
Occasion Metadata
Measurement Standards
Service Catalog
Rate Metadata
Rejection Reasons
Change-Request Reasons
Notification Templates
Peak Seasons
Service Pause Rules
Commercial Metadata
KYC Document Types
```

### 16.4 Commercial and Financial

```text
Customer Pricing
Partner Expected Rates
Agreed Partner Rates
Commission Rules
Partner Ledger
Settlements
Payouts
Refunds
Taxes
Commercial Agreements
Incentives
Penalties
Payout Holds
```

### 16.5 Governance

```text
Super Admin
Admin Users
Permission Matrix
Approval Policies
Audit Trail
Reason Codes
Configuration Versions
Data Retention
Suspension and Reactivation
Security Controls
Admin Action History
```

### 16.6 Helpdesk

```text
Open Tickets
Critical Tickets
Assigned Tickets
Unassigned Tickets
Escalated Tickets
Pending Customer Response
Pending Partner Response
SLA Breaches
Resolved Tickets
Closed Tickets
Reopened Tickets
```

Suggested priorities:

```text
Critical
High
Medium
Low
```

Suggested lifecycle:

```text
Open
→ Assigned
→ In Progress
→ Waiting for Customer
→ Waiting for Partner
→ Escalated
→ Resolved
→ Closed
→ Reopened
```

---

## 17. Admin Authorization

The controlled pilot currently authorizes Admin access using Firebase Authentication UIDs stored in:

```text
config/admin.adminUids
```

This is safer than relying on authenticated email for phone-OTP Admin accounts.

Future production authorization should move to:

```text
admin_users/{uid}
```

or Firebase custom claims with a permission matrix.

Suggested permission domains:

```text
partnerOperations
orderOperations
catalogMetadata
commercialFinancial
governance
helpdesk
```

No rule should permit all authenticated users to perform Admin writes.

---

## 18. Audit Requirements

Every material Partner lifecycle action must create an immutable audit event.

Events include:

```text
application_created
application_updated
application_submitted
review_started
changes_requested
application_resubmitted
application_rejected
kyc_requested
kyc_verification_started
kyc_verified
kyc_failed
commercial_terms_accepted
application_approved
partner_profile_created
partner_profile_activated
partner_suspended
partner_reactivated
partner_inactivated
```

Suggested audit fields:

```text
eventId
entityType
entityId
accountId
profileId
actionCode
previousStatus
newStatus
reasonCode
reasonMessageSnapshot
actorUid
actorType
createdAt
source
metadata
```

---

## 19. Legacy Migration

The legacy Tailor access mechanism currently uses fields such as:

```text
config/admin.tailorProfiles
config/admin.tailorEmails
config/admin.tailorPhones
partner_users
```

These mechanisms may remain temporarily for compatibility during migration, but they must not become the permanent Partner onboarding architecture.

The legacy allow-list mechanism should be retired after:

- Partner Application workflow is stable
- Admin-sponsored onboarding is implemented
- Approval transaction is implemented
- Partner profile creation is stable
- Profile Selection supports approved Partner profiles
- Tailor Portal uses approved profile identity
- Firestore rules use profile ownership and authorization

---

## 20. Order-Tracking Architecture

Customer-visible tracking and operational production tracking should be separated.

### 20.1 Customer-visible stages

```text
Order Confirmed
Partner Assigned
Pickup Scheduled
Material Picked Up
Received by Tailor
Work in Progress
Quality Check
Out for Delivery
Delivered
```

### 20.2 Tailor operational stages

```text
Order Accepted
Material Received
Measurement Verified
Fabric Verified
Pattern Prepared
Cutting Started
Stitching Started
Trial Required
Trial Completed
Finishing
QC Submitted
QC Passed
Ready for Dispatch
```

Detailed operational stages should map to simplified Customer stages.

The SuiSakhi measuring-tape visual may be used as the branded Customer order-progress experience.

---

## 21. Partner Order Access

A Tailor must never query or view every active order.

Orders must be filtered by approved and assigned Partner identity, such as:

```text
assignedPartnerProfileId
assignedTailorProfileId
```

Order status changes must record:

```text
currentOperationalStatus
currentCustomerStatus
statusUpdatedAt
actorProfileId
actorType
source
previousStatus
notes
evidenceUrls
```

Status history should preferably use an order subcollection for scalability and auditability.

---

## 22. Commercial Separation

The following values must remain separate:

```text
Partner expected rate
Agreed Partner cost
SuiSakhi Customer price
Platform fee
Commission or margin
Taxes
Incentives
Penalties
```

The Tailor Portal should eventually show agreed earnings rather than necessarily showing the Customer selling price.

Partner settlement and payout records must use dedicated ledger and settlement structures rather than relying only on order snapshots.

---

## 23. Business Rules Added in v8.1

### BR-8.1-001
Customer-created Partner applications require Admin review and approval.

### BR-8.1-002
Admin may initiate Partner onboarding directly.

### BR-8.1-003
Customer-created and Admin-created Partners use the same application, KYC, capability, commercial, audit, and profile-creation foundation.

### BR-8.1-004
Admin-created applications are recorded as Admin-sponsored and retain creator, approver, timestamp, and verification evidence.

### BR-8.1-005
Application review status and KYC status are maintained separately.

### BR-8.1-006
Request Changes and Rejection are separate business outcomes.

### BR-8.1-007
Request Changes requires Customer-visible correction instructions.

### BR-8.1-008
Rejection requires a standardized reason code, Customer-visible reason snapshot, Admin identity, and timestamp.

### BR-8.1-009
Rejected applications remain preserved for audit and Helpdesk review.

### BR-8.1-010
Only an approved application may create an active Partner profile.

### BR-8.1-011
Only active approved Partner profiles appear in Profile Selection and receive Partner Portal access.

### BR-8.1-012
One current Partner Application exists per account, Customer profile, and Partner type.

### BR-8.1-013
Change requests and resubmissions reuse the same application document.

### BR-8.1-014
Approval requires verified KYC, completed mandatory sections, accepted declarations, and accepted commercial terms.

### BR-8.1-015
Approval and rejection business decisions must not depend on successful external notification delivery.

### BR-8.1-016
In-app notification is mandatory for Partner lifecycle decisions.

### BR-8.1-017
Action-required events use in-app and WhatsApp notifications.

### BR-8.1-018
Formal approval and rejection use in-app, WhatsApp, and email notifications when available.

### BR-8.1-019
SMS is reserved for critical events or fallback communication.

### BR-8.1-020
Reason codes, messages, and notification templates are centrally managed and versioned.

### BR-8.1-021
Operational records store both a standardized code and a message snapshot.

### BR-8.1-022
Customer-visible messages and internal Admin notes are stored separately.

### BR-8.1-023
Tailor order access is limited to orders assigned to the approved Tailor profile.

### BR-8.1-024
Customer order tracking and Partner operational tracking use separate mapped status layers.

### BR-8.1-025
The legacy Tailor allow-list is retired after the approved Partner-profile workflow is operational.

---

## 24. Architecture Decisions Added in v8.1

### AD-8.1-001: Unified Partner Foundation
All Partner categories use one common application, verification, approval, profile, audit, commercial, and notification foundation.

### AD-8.1-002: Application and Profile Separation
A Partner Application is not an active Partner Profile.

### AD-8.1-003: Admin UID Authorization
The controlled pilot uses Firebase Authentication UIDs for Admin authorization.

### AD-8.1-004: Canonical Application Identity
One current application exists per account, Customer profile, and Partner type.

### AD-8.1-005: Separate Review and KYC Lifecycles
Application review and KYC verification are independent but jointly required for approval.

### AD-8.1-006: Central Metadata for Reasons and Messages
Reason codes, notification templates, and reusable operational messages are centrally managed and versioned.

### AD-8.1-007: Code and Snapshot Storage
Operational decisions store both metadata code and message snapshot.

### AD-8.1-008: Asynchronous External Notifications
External messaging is queued after the business transaction and cannot roll back the decision.

### AD-8.1-009: Professional Admin Domain Design
Admin functionality is organized into Partner Operations, Order Operations, Catalog and Metadata, Commercial and Financial, Governance, and Helpdesk.

### AD-8.1-010: Order Tracking Layer Separation
Detailed operational statuses map to simplified Customer-visible statuses.

### AD-8.1-011: Approved Profile-Based Portal Access
Partner Portal access is granted through an active approved Partner profile, not through a legacy phone or email allow-list.

---

## 25. Next Development Sequence

```text
1. KYC status model
2. KYC document checklist
3. Manual Admin verification
4. Onboarding section-completion model
5. Commercial-term acceptance
6. Approval eligibility calculation
7. Approve and create Tailor profile
8. Customer + Tailor Profile Selection
9. Existing Tailor Portal activation
10. In-app notification foundation
11. WhatsApp and email notification jobs
12. Admin-sponsored Add Partner migration
13. Legacy Tailor allow-list retirement
14. Assigned-order filtering
15. Customer measuring-tape order tracker
```

---

## 26. Deferred Items

The following are intentionally deferred until the foundation is stable:

- Automated external KYC integration
- Automated Partner allocation
- Production WhatsApp delivery
- Production email delivery
- SMS gateway integration
- Full payout engine migration
- Franchise and area-manager workflows
- Advanced Partner analytics
- Automated certification scoring
- Cross-region Partner expansion

---

## 27. Current Stable Implementation Checkpoints

Key implementation checkpoints completed during this delta include:

```text
Partner Opportunities entry
Partner Application lifecycle model
Customer-owned Partner Application service
Firestore security foundation
Tailor application draft
Submit for Review
Admin Partner Applications queue
UID-based Admin authorization
Admin application review screen
Start Review
Applicant under-review status messaging
Changes Requested lifecycle
Canonical application resume and duplicate protection
Final rejection with Customer-visible reason
```

Expected analyzer baseline remains:

```text
flutter analyze lib
10 known issues
```

---

## 28. Documentation and Recovery Rule

After major Partner, Admin, metadata, catalog, KYC, approval, or profile-activation changes, update:

```text
doc/SuiSakhi_PROJECT_CONTEXT.md
```

and the applicable session-recovery documentation.

The v8.1 delta must remain synchronized with implementation, Firestore schema, Firestore rules, Admin flows, and business rules.

---

## 29. Review Status

### Confirmed

- Unified Partner Management direction
- Customer-created versus Admin-sponsored onboarding
- Canonical Partner Application rule
- Review and Changes Requested lifecycle
- Final rejection with reason
- UID-based Admin authorization for pilot
- Central reason and message metadata
- Professional Admin domain design
- Notification channel policy
- Profile-based Partner activation

### Next Review

- KYC field-level schema
- Required document types by Partner type
- Onboarding-completion calculation
- Commercial-agreement schema
- Approval transaction fields
- Notification collection and job schema
- Admin permission matrix
- Helpdesk SLA metadata

---

**End of SuiSakhi Master Architecture v8.1 Delta**
