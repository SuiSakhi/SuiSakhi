# SuiSakhi Partner Master Architecture

**Version:** 2.0 Draft for Review  
**Date:** 15 September 2026  
**Status:** Consolidation draft, not yet frozen  
**Purpose:** Single authoritative document for all SuiSakhi Partner architecture, onboarding, lifecycle, capabilities, governance, commercials, allocation, operational controls, and development continuity.

> After approval and freeze, this document should become the primary Partner source of truth. Older Partner documents should remain in the archive for traceability, but day-to-day design and development should refer to this document first.

---

## 1. Purpose and Scope

SuiSakhi is a Partner and service orchestration ecosystem. Partner category identifies the Partner's primary business identity; governed capabilities determine which services the Partner may perform.

This document governs:

- Partner categories and Partner profiles
- Common onboarding and category extensions
- Partner applications, KYC, Admin review, approval, rejection, and activation
- Changes Requested, Apply Again, and post-approval change governance
- Capabilities, verification, service eligibility, allocation, availability, and capacity
- Common address, location, schedule, and fulfillment foundations
- Commercial models, rates, platform fees, taxes, settlement, and versioning
- Event, wedding, occasion, and group-service orchestration
- Measurement authority and pre-stitch controls
- Admin, Helpdesk, security, audit, custody, evidence, SLA, and recovery
- Partner UI development standards and implementation checkpoints

---

## 2. Source-of-Truth Rule

### 2.1 Primary document

After approval, this file becomes the primary Partner reference:

```text
doc/SuiSakhi_PARTNER_MASTER_ARCHITECTURE_v2.0_FINAL.md
```

### 2.2 Supporting operational documents

Only these supporting files should remain active:

```text
doc/SuiSakhi_PROJECT_CONTEXT.md
    Current branch, commit, tag, module status, test status and next task.

doc/SuiSakhi_PARTNER_DEVELOPER_FUNCTIONAL_FILE_MAP.md
    File-level implementation and dependency map.
```

### 2.3 Archive rule

Previous Partner architecture, deltas, checklists, and freeze candidates remain under an archive folder for historical traceability. They are not the first reference for new development after this master document is frozen.

### 2.4 Conflict precedence

When older documents conflict, use this precedence:

1. Latest frozen decision recorded in this Partner Master Architecture
2. Latest frozen formal addendum
3. Project Context implementation checkpoint
4. Older Partner architecture and archived deltas

---

## 3. Core Operating Principles

### 3.1 Trust promise

If something goes wrong, SuiSakhi must be able to identify what happened, protect the Customer, communicate truthfully, recover the work where possible, treat the Partner fairly, and preserve an auditable record.

### 3.2 Common foundation, category extensions

Every Partner category reuses the common foundation. A new Partner category must not require redesign of:

```text
Partner application identity
Account and profile ownership
Basic Details
Address and location
Operating Schedule
Capability selector
Save Draft
Submit / Resubmit
Status banner
Admin comments
Changes Requested
Rejection reason
Apply Again
KYC and Admin governance
Approval and activation
Audit
```

Category-specific onboarding is stored as an extension and contains only fields unique to that Partner category.

### 3.3 Capability-driven service eligibility

Service allocation is capability-driven, not category-only.

```text
Partner category
    Primary business identity

Approved capability profile
    What the Partner is qualified, willing and authorized to perform
```

A service may be fulfilled by more than one Partner category when the required capability is approved.

Example:

```text
Customer requests Measurement Visit

Eligible:
- Measurement Partner with Measurement Visit
- QuickCare Partner with Measurement Visit
```

### 3.4 Metadata-driven architecture

Partner categories, capabilities, services, standards, rates, durations, response times, reason codes, templates, and eligibility attributes are governed metadata. Stable codes, not display labels, are stored in production records.

### 3.5 Simplicity first

Do not expose avoidable operational complexity to Customers or Partners. Use a simple UI, centralized metadata, Admin governance, notes for exceptions, and controlled later-phase expansion.

---

## 4. Partner Identity and Multi-Profile Model

### 4.1 Account foundation

```text
One Account
    -> Customer Profile created by default
    -> One or more independently governed Partner Profiles
```

A single account holder may separately register as:

```text
Customer
Tailor Partner
Measurement Partner
QuickCare Partner
Designer Partner
Boutique Partner
Brand Partner
Garment Care Partner
Fabric Supplier
Rental Partner
Printing Partner
Delivery Partner
```

Each Partner application and Partner profile has an independent lifecycle, approval, category extension, readiness, and audit history.

### 4.2 Separate profiles versus multiple capabilities

A Partner category represents primary business identity. Capabilities define services within that identity.

A person may hold both Measurement Partner and QuickCare Partner profiles. Measurement Partner remains the specialized measurement category; QuickCare remains the broader service ecosystem.

### 4.3 Required identifiers

```text
accountId
customerProfileId
partnerApplicationId
partnerProfileId
partnerType / partnerCategoryCode
capabilityCodes
serviceCodes
locationIds
commercialProfileIds
```

---

## 5. Partner Categories and Current Status

### 5.1 Implemented onboarding

```text
Tailor Partner
Measurement Partner
Designer Partner
Boutique Partner
Brand Partner
Garment Care Partner
```

### 5.2 Planned onboarding

```text
QuickCare / Doorstep Services
Fabric Supplier
Rental Partner
Printing Partner
Delivery Partner
```

### 5.3 Stable internal and display names

```text
Internal category: doorstepServices
Customer display: SuiSakhi QuickCare
Admin display: QuickCare / Doorstep Services

Internal category: garmentCare
Display: Garment Care (Laundry / Press / Stain)
```

Separate Laundry and Pressing Partner categories must not be introduced for new production records. Laundry, pressing, stain treatment, dry cleaning, and related care are Garment Care capabilities.

---

## 6. Common Partner Onboarding Catalogue

Every applicable Partner onboarding screen follows this catalogue:

```text
Common Partner Details
Business / Service Address
Operating Schedule
Category Capability Profile
Category-Specific Information
Operations & Capacity
Additional Information
Common Application Lifecycle
```

### 6.1 Common Partner Details

```text
Contact Name
Business / Professional Name
Authenticated Mobile
Email
Optional alternate contact and communication preferences later
```

### 6.2 Common address and service-area foundation

```text
Address Line 1
Address Line 2
Locality
State
City
Pincode
Service-area pincodes
Map placeId, latitude, longitude and geoHash when map selection is introduced
```

Rules:

- State and City are metadata-driven.
- City selection depends on State.
- Pilot pincode validation uses six-digit Indian pincodes.
- Partners never manually enter coordinates.
- Home-based Partner exact addresses are not publicly exposed unless operationally required and authorized.

### 6.3 Common operating schedule

```text
Operating Days
Opening Time
Closing Time
Weekly holiday / closure support later
```

Time values are normalized in 24-hour `HH:mm` format.

### 6.4 Common lifecycle module

All Partner application screens reuse the common lifecycle foundation:

```text
Draft
Submitted
Under Review
Changes Requested
Approved
Rejected
Suspended
Inactive

Status Banner
Admin Comment
Final Rejection Reason
Save Draft
Submit / Resubmit for Review
Apply Again
Continue Later
Back to Partner Opportunities
```

### 6.5 Phase-1 optionality

- Save Draft permits partial or blank operational information.
- Section status does not block Save Draft.
- Capability selection may be empty in a Draft.
- Submit should remain actionable and explain missing information through validation rather than silently remaining disabled.
- Admin may request missing information through Changes Requested.

---

## 7. Partner Application Lifecycle and Governance

### 7.1 Status flow

```text
Draft
 -> Submitted
 -> Under Review
 -> Changes Requested -> Resubmitted
 -> Approved
 or Rejected

Approved profile may later become Suspended or Inactive.
```

### 7.2 Applicant editability

Applicant edits are allowed when:

```text
Draft
Changes Requested
```

Submitted and Under Review are read-only. Rejected applications are immutable.

### 7.3 Admin comments and corrections

For Changes Requested:

- `reviewNotes` contains Customer-visible correction instructions.
- The form becomes editable.
- Save Draft remains available.
- Submit action becomes `Resubmit for Review`.

### 7.4 Rejection and Apply Again

Rejected applications remain immutable for audit.

Apply Again:

- creates a new application ID and Draft;
- copies permitted applicant-entered information;
- does not copy review, rejection, approval, KYC, ownership, profile-linkage, or activation fields;
- preserves the rejected application unchanged.

### 7.5 Approval authority

**Latest governing decision:** Admin approval is required for Partner activation. KYC verification is a mandatory readiness gate but does not independently bypass Admin approval.

```text
KYC verified
+ Admin approval
+ Partner profile creation / linkage
+ Operational readiness
= Active Partner profile
```

Admin-created Partners are Admin-sponsored but use the same onboarding, KYC, commercial, audit, and profile-creation foundation.

### 7.6 Protected fields

Partners cannot directly change:

```text
applicationId
createdByUid
accountId
customerProfileId
partnerType / primary category
approvedPartnerProfileId
KYC fields
Admin review fields
Approval and activation fields
Ownership and linkage fields
Immutable audit fields
```

---

## 8. Post-Approval Partner Changes

Approved Partners may propose changes to permitted operational information, including after KYC completion:

```text
Business details
Address and service area
Operating schedule
Capabilities
Availability
Capacity
Fulfillment
Portfolio and operational notes
Other permitted category-specific information
```

Approved production data must not be silently overwritten.

```text
Approved profile version
    -> Partner proposes changes
    -> Pending controlled change request / version
    -> Admin notification and review
    -> Approve, Reject, or Request Corrections
    -> Approved version changes only after approval
```

The current approved profile remains active while a proposed change is pending or rejected. KYC-sensitive identity, bank, payout, ownership, approval, and linkage changes require additional controlled verification.

Minimum future change-request fields:

```text
changeRequestId
partnerProfileId
sourceApplicationId
baseApprovedVersion
proposedData
changedFields
status
submittedByUid
submittedAt
reviewedByUid
reviewedAt
adminComment
rejectionReason
createdAt
updatedAt
```

---

## 9. Fulfillment Architecture

### ARCH-FUL-001: Pickup & Delivery Available

`Pickup & Delivery Available` is one simple common Partner fulfillment capability for applicable Partner categories.

```text
Enabled
    -> SuiSakhi prioritizes Partner self-fulfillment

Not enabled
    -> SuiSakhi may assign a Delivery Partner
```

Restrictions and exceptions are captured through Additional Notes and Admin governance.

Do not introduce separate onboarding matrices for pickup-only, delivery-only, return pickup, exchange pickup, or logistics variants without a validated future business requirement.

Home Visit remains separate because Home Visit represents service execution at a Customer location, while Pickup & Delivery represents movement of garments, materials, or products.

### 9.1 Delivery Partner distinction

```text
Delivery Partner
    Logistics is the primary business.

Tailor / QuickCare / Boutique / Brand / Garment Care
    Pickup & Delivery supports the Partner's own service or product.
```

---

## 10. Core Operational Pillars

SuiSakhi's three core operational pillars are:

```text
Tailoring
QuickCare
Garment Care
```

Designer, Boutique, Brand, Fabric Supplier, Rental, Printing, Measurement, and Delivery support, feed, or extend these pillars.

---

## 11. Category Capability Architecture

### 11.1 Tailor Partner

Capability domains include:

```text
Blouse
Kurti / Suit
Dress
Lehenga
Bridal
Designer Wear
Alteration
Pico / Fall
Embroidery
Aari
Zardozi
Girls Wear
School Uniform
Wedding / Family Packages
Bulk / Event Orders
Urgent Orders
Pattern Making
Premium Finishing
Other Expertise
Measurement support
Pickup & Delivery Available
Home Visit Available
```

Tailor remains the final measurement authority for an assigned stitching order.

### 11.2 Measurement Partner

Measurement Partner is the specialized measurement category.

```text
Home-Visit Measurement
Video-Assisted Measurement
Standard Manual Measurement
Old-Garment Reference Measurement
AI Measurement Validation Support
Re-Measurement and Correction
Girls Measurement
Special-Fit Measurement
Pickup & Delivery Available
```

Measurement Partner creates a new or proposed measurement version and never silently overwrites Customer, Tailor, or Final Confirmed versions.

### 11.3 Designer Partner

```text
Fashion Design
Concept Design
Custom and Personalized Design
Special Design Orders
Wedding and Bridal Design
Party Wear Design
Bulk and Event Design
Corporate / Institutional Design
Original-work / rights declaration
```

### 11.4 Boutique Partner

```text
Ready-Made Sales
Inventory-Based Fulfillment
Custom Stitching
Tailoring Services
Designer Services
Trial Facility
Home Consultation
Party Wear Specialist
Bridal Specialist
Premium Fashion
Pickup & Delivery Available
```

### 11.5 Brand Partner

```text
Catalogue and Collection Management
Product Variants
Inventory Management
Ready Stock
Customer Support
Partner Fulfillment
Pickup & Delivery Available
Return / Exchange Handling
```

### 11.6 Garment Care Partner

Display name:

```text
Garment Care (Laundry / Press / Stain)
```

Capability groups:

```text
Garment Care Services
Garment & Material Specialization
Collection & Delivery
```

Services:

```text
Laundry
Dry Cleaning
Pressing / Ironing
Steam Pressing
Roll Press
Stain Removal
Fabric Care Treatment
Saree Care
Special Garment Care
Pickup & Delivery Available
```

Special Garment Care covers bridal, occasion, designer, premium, heavy, embellished, and other garments requiring specialized handling.

Quality and handling evidence, such as before/after photos, damage reporting, garment identification, and loss prevention, belongs to the Customer order and service-execution workflow, not Partner onboarding.

---

## 12. QuickCare / Doorstep Services Architecture

### ARCH-QC-001: Category identity

```text
Internal category code: doorstepServices
Customer display: SuiSakhi QuickCare
Admin display: QuickCare / Doorstep Services
```

QuickCare is a flexible service ecosystem. It supports capable students, homemakers, retired skilled professionals, fashion students, tailoring students, tailoring schools, measurement-trained providers, individuals, and small service businesses.

A QuickCare Partner declares only capabilities the Partner is qualified and willing to provide. Allocation uses the approved capability profile.

### 12.1 QuickCare onboarding structure

```text
Common Partner Details
Business / Service Address
Operating Schedule
QuickCare Capability Profile
Experience & Skill Profile
Operations & Capacity
Urgent Service Availability
Additional Information
Common Application Lifecycle
```

### 12.2 Garment Repair

```text
Pico & Fall
Button Replacement
Hook Repair
Zip Repair
Elastic Replacement
Minor Stitch Repair
Minor Tear Repair
Raffu
Minor Alteration
Blouse Fitting
Embroidery Repair
Traditional Stitch Repair
Emergency Stitch Repair
```

### 12.3 Garment Assistance

```text
Saree Draping
Saree Pre-Pleating
Saree Folding
Wardrobe Assistance
Wardrobe Reorganization
Occasion Dressing Assistance
Event Readiness Services
Styling / Dress Coordination
Design Assistance
```

### 12.4 Field Services

```text
Measurement Visit
Home Visit Available
Pickup & Delivery Available
```

### 12.5 Provider type

```text
Individual Service Provider
Homemaker
Student
Fashion Student
Retired Skilled Professional
Tailoring Student
Tailoring School / Training Centre
Measurement-Trained Provider
Small Service Business
Other
```

### 12.6 Skill profile

```text
Experience in Years
Declared Skill Level
Skill / Qualification Summary
```

Skill levels:

```text
Beginner
Intermediate
Experienced
Expert
Training Organisation
```

Self-declared skill is not certification. Admin verification and capability certification remain governed separately.

### 12.7 Operations and availability

```text
Service-area pincodes
Team Size
Normal Daily Capacity
Peak Daily Capacity
Typical Service Duration
Typical Response Time
Same-Day Service Available
Emergency Service Available
Additional Notes
```

Suggested response-time metadata:

```text
Within 1 hour
Within 2 hours
Within 4 hours
Same day
Next day
Depends on availability
```

### 12.8 QuickCare allocation rule

```text
Requested capability
+ Approved capability profile
+ Service area
+ Operating schedule
+ Home Visit requirement
+ Pickup & Delivery requirement
+ Same-day / emergency eligibility
+ Capacity
+ Partner acceptance
= Eligible QuickCare allocation
```

Partner category alone never authorizes all QuickCare services.

### 12.9 Measurement overlap

Measurement Partner remains the specialist category. QuickCare may also include Measurement Visit.

The same account holder may independently register as both Measurement Partner and QuickCare Partner.

---

## 13. Fabric Supplier Onboarding

### Capability groups

```text
Fabric Categories
Supply Services
Collection & Delivery
```

Fabric categories:

```text
Cotton
Silk
Linen
Denim
Synthetic / Blended
Designer Fabrics
Bridal Fabrics
Uniform Fabrics
Children's Fabrics
Other governed categories
```

Supply services:

```text
Retail Sales
Wholesale Supply
Custom Fabric Sourcing
Fabric Recommendations
Sample / Swatch Supply
Pickup & Delivery Available
```

Operations:

```text
Service Area
Inventory Available
Catalogue Available
Team Size
Normal Daily Capacity
Peak Daily Capacity
Additional Notes
```

Pricing is primarily Partner-controlled, with SuiSakhi platform fees and taxes applied through governed commercial metadata.

---

## 14. Rental Partner Onboarding

### 14.1 Rental capability groups

```text
Kids Event Rentals
Ladies Event Rentals
Wedding / Occasion Wear
Jewellery & Accessories
Props & Event Accessories
Collection & Delivery
```

### 14.2 Kids Event Rentals

```text
Fancy Dress
Dance Costumes
Drama Costumes
School Event Costumes
Character Costumes
Props and Accessories
```

### 14.3 Ladies Event Rentals

```text
Fancy Dress
Dance Costumes
Drama Costumes
Party Wear
Traditional Wear
Designer Wear
```

### 14.4 Wedding / Occasion Wear

```text
Bridal Wear
Wedding Guest Wear
Engagement Wear
Reception Wear
Festival Wear
Other Occasion Wear
```

### 14.5 Jewellery and accessories

```text
Bridal Jewellery
Artificial Jewellery
Occasion Jewellery
Fashion Jewellery
Hair Accessories
Clutches / Bags
Other Fashion Accessories
```

### 14.6 Props and event accessories

```text
Stage Props
Theme Props
Dance Props
Drama Props
Event Accessories
Other Rental Category
```

### 14.7 Operations

```text
Service Area
Inventory Size
Trial Facility
Home Trial Available
Pickup & Delivery Available
Team Size
Normal Booking Capacity
Peak Booking Capacity
Security Deposit Required
Rental Duration / Terms Summary
Cleaning / Readiness Process
Damage / Late Return Policy Reference
Additional Notes
```

Detailed item condition, custody, deposit, return, damage, cleaning, and evidence belong to the rental booking and execution workflow, not basic onboarding.

Pricing is Partner-controlled, with platform fees, taxes, deposit, damage, and late-return rules governed separately.

---

## 15. Printing Partner Onboarding

### Capability groups

```text
Printing Services
Material Compatibility
Order Type
Collection & Delivery
```

Printing services:

```text
Digital Printing
Screen Printing
DTF Printing
Sublimation
Vinyl / Heat Transfer
Custom Logo Printing
Name / Number Printing
Uniform Printing
Other Governed Printing Service
```

Material compatibility:

```text
Cotton
Polyester
Silk
Synthetic / Blended
Other governed materials
```

Operations:

```text
Service Area
Minimum Order Quantity
Normal Daily Capacity
Peak Daily Capacity
Average Turnaround Time
Express Orders Available
Pickup & Delivery Available
Additional Notes
```

Printing commercials may combine Partner-controlled quotation with standardized SuiSakhi fees and taxes.

---

## 16. Delivery Partner Onboarding

Delivery Partner is a full Partner profile whose primary business is logistics.

### Capability groups

```text
Pickup and Delivery Services
Coverage
Handling Capability
```

Services:

```text
Customer Pickup
Customer Delivery
Inter-Partner Transfer
Same-Day Delivery
Express Delivery
Return Pickup
```

Operations:

```text
Service-area pincodes
Coverage Type: Local / City / District / Intercity
Vehicle Type
Team / Rider Count
Normal Daily Capacity
Peak Daily Capacity
Average Delivery Time
Operating Schedule
Additional Notes
```

Vehicle metadata:

```text
Bicycle
Two Wheeler
Car
Van
Other Approved Vehicle
```

Delivery execution later requires QR scanning, OTP, custody handover, photo, GPS, timestamp, and sensitive-garment handling controls.

---

## 17. Event, Wedding, Occasion and Group-Service Layer

### ARCH-EVT-001

Event, wedding, occasion, and group-order support is a cross-category capability layer. Do not create a separate Event Partner category.

Event-related capabilities are captured inside existing Partner categories and can later be aggregated into a temporary SuiSakhi Event Team.

Examples:

```text
Tailor
- Wedding Orders
- Bulk Orders
- Event Orders
- Bridal / Designer Wear

Designer
- Wedding Design
- Bridal Design
- Event Design
- Bulk / Special Design Orders

QuickCare
- Event Readiness Services
- Occasion Dressing Assistance
- Saree Draping
- Styling / Dress Coordination

Boutique
- Bridal Specialist
- Party Wear Specialist
- Premium Fashion

Rental
- Wedding Wear
- Fancy Dress
- Dance / Drama Costumes
- Jewellery
- Props

Garment Care
- Special Garment Care

Delivery
- Event logistics and transfers
```

Future orchestration:

```text
Customer Event Request
    -> Resolve requested event services
    -> Find approved event-capable Partners
    -> Build Designer + Tailor + QuickCare + Rental + Garment Care + Delivery team
    -> Coordinate schedule, custody, service milestones, rates and accountability
```

Event capability tags should be internal metadata attributes on service and capability definitions, not separate hardcoded UI logic.

---

## 18. Measurement Architecture and Final Authority

Measurement may come from:

```text
AI / camera estimate
Customer-provided values
Measurement Partner visit
QuickCare Measurement Visit
Video-assisted measurement
Tailor physical measurement
Old dress / reference garment
Historical measurement version
```

AI measurement is an estimate only.

The assigned Tailor is the final measurement authority for a stitching order. No cutting or stitching begins until the assigned Tailor confirms the final measurement version.

Measurement versions are preserved:

```text
Customer version
Measurement Partner version
QuickCare / provider version where applicable
Tailor-adjusted version
Final confirmed version
```

Recommended final confirmation fields:

```text
finalMeasurementVersionId
finalMeasurementConfirmedByUid
finalMeasurementConfirmedAt
finalMeasurementMethod
measurementConfirmationNotes
```

---

## 19. Capability Verification and Certification

Separate:

```text
Declared Capability
Approved Capability
Verified Capability
Certified Capability
```

Partners declare capability during onboarding. Admin may approve, verify, request evidence, restrict, suspend, or certify capabilities according to metadata and policy.

Capability definitions may include:

```text
requiresVerification
requiresCertification
service tags
event tags
homeVisitAllowed
pickupDeliveryAllowed
emergencyAllowed
standard duration
required tools
material compatibility
```

---

## 20. Availability, Capacity and Assignment

### 20.1 Availability states

```text
Available
Busy
Paused
Emergency Stop
Suspended
Inactive
```

### 20.2 Capacity

```text
Normal Capacity
Peak Capacity
Current Load
Remaining Capacity
```

Suggested utilization bands:

```text
Green: 0-80%
Yellow: above 80-95%
Red: above 95% or full
```

### 20.3 Eligibility

A Partner is eligible only when:

```text
Approved and Active
Required capability approved
Within service area
Operating / available
Within capacity
Material and garment compatible
SLA and certification eligible
Commercially ready
Not assignment-blocked
```

### 20.4 Assignment and payment

```text
Customer Request
 -> Eligibility Check
 -> Assignment Offer
 -> Partner Acceptance
 -> Capacity Reservation
 -> Customer Payment
 -> Confirmed Work
```

Payment is requested only after a valid Partner accepts.

---

## 21. Service Catalogue and Commercial Architecture

### 21.1 Service catalogue versus capability profile

```text
Service Catalogue
    What SuiSakhi sells

Partner Capability Profile
    What an approved Partner may perform
```

One service may map to multiple eligible Partner categories.

### 21.2 Centrally governed standard pricing

Applicable primarily to:

```text
Tailoring
QuickCare
Garment Care
Measurement Services
Standard Pickup & Delivery
```

Formula:

```text
Partner settlement rate
+ SuiSakhi share / platform component
+ Applicable taxes
= Customer price
```

Tailor rates may be negotiated internally, while Customer-facing rates remain as standardized as practical. Normal and peak rates, SuiSakhi share, Tailor settlement, and total Customer price are versioned metadata per stitching/service type.

### 21.3 Partner-controlled pricing

Applicable primarily to:

```text
Designer
Boutique
Brand
Fabric Supplier
Rental
Selected Printing quotations
```

Formula:

```text
Partner price
+ Platform fee
+ Applicable taxes
= Customer price
```

### 21.4 Rate metadata

```text
rateCode
serviceCode
version
effectiveFrom
effectiveTo
currency
unit
partnerSettlement
platformFee
customerPrice
taxRule
normal / peak / express / emergency dimension
approvalStatus
Partner acceptance
```

Orders snapshot the applied rate and version.

---

## 22. Admin, KYC and Operational Readiness

### 22.1 Admin

Admin may:

```text
View all Partner applications and profiles
Review Drafts where policy permits
Assist with permitted fields
Request Changes
Reject with standardized reason and explanation
Start and review KYC
Approve Partner applications
Activate or link approved Partner profiles
Govern capabilities and readiness within authority
Maintain Admin notes and audit
```

Admin cannot accept Partner-owned legal declarations or consent on behalf of the Partner.

### 22.2 KYC

KYC may include:

```text
Identity verification
Address verification
Business verification
Document verification
Video verification
Duplicate / fraud checks
Capability evidence
Optional physical verification
Bank / payout readiness where applicable
```

### 22.3 Operational readiness

```text
Agreement accepted
KYC verified
Admin approval completed
Partner profile linked
Capabilities configured
Service area configured
Availability configured
Capacity configured
Commercial profile ready
Rate card ready
Settlement method ready
Notifications enabled
Category readiness completed
```

---

## 23. Audit, Reason Codes and Notifications

Minimum audit data:

```text
Actor UID
Actor role / source
Timestamp
Action or event code
Changed area
Before / after values or revision reference where material
Reason code and notes where applicable
```

Recommended event examples:

```text
partner.application.created
partner.application.operational.updated
partner.application.submitted
partner.application.changes.requested
partner.application.rejected
partner.application.reapplied
partner.kyc.started
partner.kyc.verified
partner.kyc.failed
partner.application.approved
partner.profile.activated
partner.profile.change.submitted
partner.profile.change.approved
partner.profile.change.rejected
partner.capability.updated
partner.availability.updated
partner.capacity.updated
```

Important events always create an in-app system record even if SMS or WhatsApp delivery fails.

---

## 24. Custody, Evidence, SLA and Recovery

Trackable items may include:

```text
Customer garment
Reference garment
Fabric bundle
Sample garment
Rental item
Accessory bundle
```

Execution workflows may require:

```text
QR / human-readable ID
Current custodian
Handover history
Condition evidence
Before and after photos
OTP completion
GPS and timestamps where applicable
Return requirement and due date
```

Loss, damage, delay, rework, dispute, and evidence corrections are never silently deleted. Corrections use auditable events.

---

## 25. Security and Role Boundaries

Backend authorization is the source of truth. UI visibility never grants permission.

Roles may include:

```text
Super Admin
Admin
Verification / KYC
Commercial
Partner Operations
Helpdesk
Chatbot
Partner
Customer
```

Sensitive data is logically separated:

```text
Public Partner Profile
Private KYC
Private Finance and Settlement
Agreements
Capabilities
Commercials
Audit
```

Helpdesk receives only the Service / Order 360 information required for support and cannot approve Partners, perform KYC, change rates, view bank details, or modify governed metadata.

---

## 26. Common UI and Development Standards

### 26.1 Reusable UI modules

```text
PartnerBasicDetailsSection
AddressFormSection
OperatingScheduleField
CapabilityMultiSelector
PartnerApplicationStatusNotice
PartnerApplicationLifecycleActions
PartnerReapplyDialog
```

### 26.2 Screen responsibility

Common module owns repeated presentation and navigation behavior. Category screen owns:

```text
Category-specific controllers
Validation
Model construction
Category persistence
Draft hydration
Apply Again hydration
```

### 26.3 No god screen

Do not create one oversized configurable Partner screen with dozens of flags. Reuse common modules and keep category-specific screens focused.

### 26.4 Standard implementation slice

Every Partner category implementation covers:

```text
Metadata
Category details model
Application screen
Common Basic Details
Address and schedule
Capabilities
Operations and capacity
Save Draft and resume
Submit / Resubmit
Common lifecycle module
Admin list and review
Rejection and Apply Again
KYC and approval
Profile activation / temporary landing
Security rules
Analyzer and regression testing
Documentation and checkpoint
```

---

## 27. Current Development Status and Next Plan

### Completed onboarding

```text
Tailor
Measurement Partner
Designer
Boutique
Brand
Garment Care
```

### Current next implementation

```text
QuickCare / Doorstep Services
```

### Then

```text
Fabric Supplier
Rental Partner
Printing Partner
Delivery Partner
```

### Later dedicated operational program

After onboarding stabilization, allocate focused development time to the high-impact operational flow:

```text
Customer
 -> Tailor
 -> Measurement Partner / QuickCare Measurement
 -> Delivery Partner
 -> Payment, custody, execution, QC and completion
```

Temporary Partner landing pages are acceptable until category operational dashboards are implemented.

---

## 28. Architecture Decision Register

```text
ARCH-PP-001   Common Partner Foundation Reuse
ARCH-PP-010   Rejected Applications Are Immutable
ARCH-PP-011   Apply Again Creates a New Draft
ARCH-PP-021   Controlled Post-Approval Partner Changes
ARCH-PP-022   One Account May Hold Multiple Partner Profiles
ARCH-FUL-001  One Simple Pickup & Delivery Available Capability
ARCH-GC-001   Garment Care Consolidates Laundry / Press / Stain
ARCH-QC-001   QuickCare Is a Capability-Driven Service Ecosystem
ARCH-CAP-001  Allocation Is Capability-Driven, Not Category-Only
ARCH-EVT-001  Event / Wedding / Occasion Is Cross-Category
ARCH-PRC-001  Standardized and Partner-Controlled Pricing Models
ARCH-PILLAR-001 Tailoring, QuickCare and Garment Care Are Core Pillars
ARCH-MEA-001  Assigned Tailor Is Final Measurement Authority
```

---

## 29. Decisions Requiring Explicit Review Before Freeze

The following consolidation decisions should be reviewed before renaming this document FINAL:

1. Confirm Admin approval plus KYC verification as the governing activation model, replacing older wording that treated KYC verification alone as approval.
2. Confirm separate Partner profiles per category under one account versus the older canonical single multi-category Partner Profile direction. Current implementation and recent frozen decisions use separate Partner applications/profiles.
3. Confirm capability selection remains optional for Phase-1 submission or is only required for selected categories such as QuickCare. Save Draft remains optional in all cases.
4. Confirm Tailor legacy pickup and delivery fields remain backward-compatible storage while the UI shows one `Pickup & Delivery Available` control.
5. Confirm older Laundry and Pressing references are archived and all new work uses Garment Care.
6. Confirm QuickCare provider type and skill level are onboarding analytics and declarations, not certification or automatic eligibility.
7. Confirm commercial classification for Printing where some work may be standardized and some may require Partner quotation.

---

## 30. Change Control

After freeze, any change to this Partner Master Architecture requires:

```text
Documented business reason
Architecture impact review
Data-model impact review
Firestore security review
UI and lifecycle review
Commercial and audit review where applicable
Regression-test update
Versioned addendum or new master version
Project Context update
Focused Git commit and tag where appropriate
```

---

## 31. End-of-Day Partner Documentation Rule

At the end of every major Partner development session:

1. Update `doc/SuiSakhi_PROJECT_CONTEXT.md` with the current branch, commit, tag, completed work, tests, known issues, and exact next task.
2. Update this master document only when architecture or frozen Partner rules change.
3. Update the Partner Developer Functional File Map when files, dependencies, or responsibilities change.
4. Run formatting, analyzer, focused regression tests, and `git diff --check`.
5. Commit only intentional files and push the branch.
6. Create an annotated stable tag after a major milestone.

---

**End of SuiSakhi Partner Master Architecture v2.0 Draft for Review**
