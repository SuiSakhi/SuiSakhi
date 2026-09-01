# SuiSakhi Partner Engagement Architecture v1.0

## Simplified Onboarding, Admin 360-Degree Operations, KYC, Commercials, Catalog Governance, Availability, Assignment, and Partner Lifecycle

**Version:** 1.0 Draft for Review  
**Date:** 29 August 2026  
**Status:** Review Draft  
**Owner:** SuiSakhi  
**Related Architecture:** SuiSakhi Master Architecture v8.2 and v8.2.1 Operational Review Addendum  
**Pilot Target:** 14 October 2026

---

## 1. Document Purpose

This document is the single source of truth for the SuiSakhi Partner ecosystem.

It governs:

```text
Partner Categories
Partner Registration
Common and Category-Specific Onboarding
Admin-Assisted Completion
Partner Agreements
KYC and Background Verification
Commercial Negotiation and Rate Cards
Design Catalog Ownership and Governance
Partner Approval and Operational Readiness
Partner Availability and Capacity
Automatic Order Assignment
Partner Acceptance Before Payment
Peak-Season Admin Intervention
Emergency Handling and Order Transfer
Partner and Customer 360-Degree Views
Partner Performance, Support, and Lifecycle
```

The Master Architecture shall contain only a reference to this document for Partner engagement and operations.

---

## 2. Vision and Guiding Principles

### 2.1 Simple for the Partner

The Partner should experience:

```text
Fill Details
→ Save Draft
→ Accept Agreement
→ Submit for Review
```

The Partner should not be burdened with internal review stages, duplicated save buttons, or unnecessary rejection cycles.

### 2.2 Assisted, not rejection-driven

Minor missing information should be completed by Admin after speaking with the Partner. `Request Changes` should be reserved for issues that genuinely require the Partner to correct, upload, accept, or clarify something personally.

### 2.3 One reusable foundation

```text
Common Partner Foundation
+ Partner Category Extensions
+ Commercial Configuration
+ Agreement
+ Admin Review and KYC
```

### 2.4 One Partner, multiple categories

A single Partner profile may support multiple categories, for example:

```text
Tailor + Doorstep Services
Tailor + Measurement Capability
Designer + Boutique
Laundry + Pressing
Fabric Supplier + Delivery Capability
```

The Partner maintains one identity, KYC record, agreement history, audit history, and primary commercial relationship.

### 2.5 One Customer, multiple Partners

A Customer order or service journey may engage multiple Partners:

```text
Designer
→ Fabric Supplier
→ Measurement Capability
→ Tailor
→ Embroidery or Printing
→ Laundry or Pressing
→ Delivery Partner
```

### 2.6 Metadata over hardcoding

Categories, services, skills, locations, reason codes, agreements, commercial rules, rate types, KYC requirements, availability reasons, and assignment rules should be centrally configurable wherever practical.

### 2.7 Operational simplicity for the pilot

```text
QR before RFID
One Admin operations interface before complex role separation
Save Draft before section-level save actions
Admin-assisted completion before repeated rejection
Partner acceptance before Customer payment
```

---

## 3. Phase-1 Partner Categories

Priority Partner categories for the pilot:

```text
1. Tailor Partner
2. Designer Partner
3. Doorstep Services Partner
4. Boutique Partner
5. Pressing Partner
6. Laundry Partner
```

Foundation-ready but deferred categories:

```text
Fabric Supplier
Embroidery Partner
Printing Partner
Delivery Partner
Measurement Partner
Rental Partner
Accessories Partner
Brand Partner
Other Future Categories
```

---

## 4. Partner Application Lifecycle

```text
Draft
→ Submitted
→ Under Review
→ Changes Requested, Approved, or Rejected
```

Partner-facing statuses:

```text
Draft
Submitted
Under Review
Changes Requested
Approved
Rejected
```

Operational Partner profile statuses:

```text
Active
Busy
Paused
Emergency Stop
Suspended
Inactive
Archived
```

Application status and operational availability must remain separate.

---

## 5. Simplified Partner Onboarding Flow

### 5.1 Common flow

```text
1. Basic Details
2. Business and Operations
3. Partner-Specific Details
4. Commercial and Rate Card
5. Partner Agreement
6. Save Draft or Accept and Submit for Review
7. Admin Review and Assisted Completion
8. KYC
9. Approval
10. Operational Readiness
11. Active
```

### 5.2 Partner actions

Only two primary actions are exposed:

```text
Save Draft
Accept and Submit for Review
```

Section-level buttons such as `Save Workshop Details` shall be removed from the target experience.

### 5.3 Save Draft behavior

`Save Draft` persists all entered sections together:

```text
Basic Details
Business and Operations
Category-Specific Details
Commercial Information
Agreement Draft State
```

### 5.4 Submission behavior

Submission requires:

```text
Minimum Partner-submitted information
Agreement acceptance
Authenticated Partner identity
```

Not every optional or Admin-verified field must be complete before submission.

---

## 6. Common Section 1: Basic Details

Applicable to all Partner categories.

### 6.1 Fields

```text
Contact Name
Business Name
Authenticated Mobile Number
Alternate Mobile Number, optional
Email, optional
Preferred Language
Preferred Communication Channel
```

### 6.2 Preferred languages

```text
English
Hindi
Marathi
Gujarati
Kannada
Tamil
Telugu
Other
```

### 6.3 Communication channels

```text
In-App
Phone
WhatsApp
SMS
Email
```

### 6.4 Rules

- Authenticated mobile number remains read-only.
- Admin may correct minor business or communication details after confirming with the Partner.
- Material identity or ownership corrections require an audited change.

---

## 7. Common Section 2: Business and Operations

This replaces the Tailor-only concept of `Workshop Details` as the common cross-Partner section.

### 7.1 Business type

```text
Home-Based
Commercial Establishment
Boutique
Shared Workspace
Mobile or Doorstep-Only Operation
Warehouse
Office or Studio
Other
```

### 7.2 Standardized location

Partner-visible fields:

```text
State
City
Pincode
Business Address
Select or Confirm Location on Map
```

Stored fields:

```text
stateCode
stateName
cityCode
cityName
pincode
addressLine1
addressLine2
locality
formattedAddress
placeId
latitude
longitude
geoHash
locationVerifiedAt
```

The Partner shall never manually enter latitude or longitude.

### 7.3 Location flow

```text
Search Address or Use Current Location
→ Select Verified Result
→ Confirm Map Pin
→ Store Address, Place Reference, and Coordinates
```

### 7.4 Location privacy

For home-based Partners, the Customer sees only the approved operational information, such as locality, approximate distance, verified service area, and availability. Exact private addresses are revealed only when operationally required and authorized.

### 7.5 Operating schedule

```text
Operating Days
Opening Time
Closing Time
Weekly Holiday
Temporary Closure Dates
```

Times must be selected using a time picker and stored in normalized 24-hour format:

```text
09:00
21:00
```

### 7.6 Team and basic capacity

Partner-entered common fields:

```text
Team Size
Normal Daily Capacity, where applicable
Peak Daily Capacity, optional
```

Detailed role composition and verified capacity are captured during KYC.

### 7.7 Service coverage

```text
Within 5 km
Within 10 km
Within 20 km
Entire City
Selected Pincodes
Custom Coverage
```

Stored as normalized coverage metadata and, where relevant, service radius.

### 7.8 Common logistics capability

```text
Pickup Available
Delivery Available
```

Home visit is not a universal common field. It belongs to category-specific capabilities because the meaning differs by service.

### 7.9 Optional business notes

Free text is reserved for information not represented by existing metadata.

---

## 8. Partner-Specific Details

Partner-specific details are generated from selected Partner categories.

---

## 8.1 Tailor Partner Extension

### Skills and expertise

Use multi-select checkboxes or selectable chips:

```text
Blouse Stitching
Kurti and Suit
Dress Stitching
Lehenga
Bridal Wear
Party Wear
Designer Wear
Designer Replication
Alterations
Saree Pico and Fall
Embroidery
Aari Work
Zardozi Work
Old Saree or Old Dress Conversion
Girls Frocks
Girls Party Wear
School Uniforms
Wedding Orders
Wedding Family Packages
Event Orders
Urgent Orders
Premium Custom Stitching
Pattern Making
Boutique Finishing
```

### Other expertise

```text
Other Expertise checkbox
+ Additional Expertise free text
```

Structured skills drive search, qualification, assignment, certification, analytics, and future AI matching. Notes must not replace structured expertise.

### Measurement compatibility

```text
Accept SuiSakhi Standard Measurement Sheet
Accept Measurement by Trained Measurer
Accept Old Garment or Blouse Reference
Support Video Measurement
Allow QC Re-Measurement
Support Doorstep Measurement
Perform Final Measurement Verification
```

### Tailor-specific operational fields

```text
Supported Garment Categories
Supported Fabric Categories
Trial Available
Express Work Available
Wedding or Special-Order Team Available
Seasonal Workforce Available
Delivery Checklist Available
```

Experience years, detailed team composition, and certification are verified during KYC.

---

## 8.2 Designer Partner Extension

```text
Original Design Creation
Custom Design Creation
Design Modification
Fashion Consultation
Occasion Consultation
Fabric Consultation
Bridal Collection
Party and Occasion Collection
Daily-Wear Collection
Girls Collection
Premium Collection
Design Licensing
Digital Catalog Upload
```

Other capability text is available only when structured metadata is insufficient.

---

## 8.3 Doorstep Services Partner Extension

```text
Button Replacement
Hook and Eye Replacement
Zip or Chain Replacement
Elastic Replacement
Loose Stitch Repair
Minor Tear Repair
Simple Hemming
Side Adjustment
Sleeve Adjustment
Blouse Hook Adjustment
Saree Pico
Saree Fall Stitching
Saree Draping Assistance
Dupatta Edge Repair
School Uniform Quick Fix
Curtain Alteration
Cushion Cover Repair
Emergency Event-Wear Repair
```

Additional fields:

```text
Doorstep Service Radius
Minimum Visit Charge
Same-Day Support
Emergency Support
Average Service Duration
Tools Carried
Society Entry Requirements
Before and After Evidence Requirements
Customer OTP Completion
```

---

## 8.4 Boutique Partner Extension

```text
Custom Stitching
Ready-Made Sales
Tailoring Services
Designer Services
Trial Facility
Premium Services
Bridal Services
In-Store Pickup
Home Consultation
Inventory-Based Fulfillment
```

A Boutique may also hold Designer or Tailor categories on the same Partner profile.

---

## 8.5 Laundry Partner Extension

```text
Wash Method
Water Temperature Range
Detergent Type or Standard
Separate Wash Capability
Color Protection
Stain Classification
Stain Treatment
Drying Method
Premium Fabric Care
Bridal Garment Care
Express Processing
Pickup and Delivery
```

The Laundry Partner must record pre-existing stain or damage, notify the Customer when stain removal is uncertain, and obtain approval before high-risk treatment.

---

## 8.6 Pressing Partner Extension

```text
Hand Press
Steam Press
Roll Press
Vacuum Press
Dry Press
Low-Temperature Press
Protective-Cloth Press
Express Pressing
Pickup and Delivery
```

Fabric and care compatibility includes:

```text
Cotton
Linen
Silk
Rayon
Georgette
Chiffon
Net
Velvet
Synthetic Blends
Embroidery
Sequins
Prints and Transfers
One-Dot, Two-Dot, and Three-Dot Ironing Instructions
```

Laundry and Pressing remain separate service extensions even when provided by the same Partner.

---

## 8.7 Future Partner Extensions

The same model supports:

```text
Fabric Supplier
Embroidery
Printing
Delivery
Measurement
Rental
Accessories
Brand
```

Each extension uses the common foundation and introduces only category-relevant capability metadata.

---

## 9. Commercial and Rate Card Section

Commercials are separate from Business and Operations.

Applicable to Tailor, Doorstep Services, Laundry, Pressing, Designer, Boutique, Embroidery, Printing, Delivery, and other rate-based Partners.

### 9.1 Commercial data layers

```text
Partner Expected Rate
SuiSakhi Negotiated Partner Cost
Customer Selling Price
Platform Fee or Commission
Taxes
Discount Funding Source
Incentives
Penalties
Settlement Rule
```

These values must not be merged into one rate.

### 9.2 Rate types

```text
Standard Rate
Peak-Season Rate
Express Rate
Emergency Rate
Bulk Rate
Package Rate
Promotional Rate
Partner-Specific Negotiated Rate
```

### 9.3 Tailor rate card

Rate items may include:

```text
Blouse
Kurti
Suit
Dress
Lehenga
Bridal Wear
Alteration
Saree Pico and Fall
Embroidery
Aari or Zardozi
Designer Replication
Wedding Package
Family Package
Event Order
Doorstep Measurement
```

### 9.4 Laundry and pressing rates

```text
Per Piece
Per Kilogram
Fabric-Specific Rate
Premium Garment Rate
Bridal Garment Rate
Stain Treatment Rate
Express Rate
Pickup and Delivery Charge
Steam Press Rate
Roll Press Rate
Dry-Clean Rate
Chemical-Clean Rate
```

### 9.5 Doorstep rates

```text
Minimum Visit Charge
Service Item Rate
Travel Charge
Same-Day Premium
Emergency Premium
Additional Approved Work
```

### 9.6 Discounts and offers

```text
Regular Customer
Bulk Order
Wedding Package
Family Package
Referral
Festival Offer
Off-Season Offer
Campaign Offer
Other Approved Offer
```

### 9.7 Negotiation workflow

```text
Partner Submits Expected Rates
→ Admin Reviews and Negotiates
→ Agreed Commercial Profile Saved
→ Partner Accepts Commercial Terms
→ Effective Date Applied
```

Minor commercial information may be completed by Admin after a call. Any negotiated commitment must be auditable and accepted by the Partner.

---

## 10. Design Catalog and Ownership Framework

Design Catalog governance belongs to the Partner ecosystem because Designer and Boutique Partners may contribute designs, while SuiSakhi Admin manages SuiSakhi-owned designs.

### 10.1 Ownership types

```text
SuiSakhi-Owned
Designer-Owned
Boutique-Owned
Partner-Owned
Commissioned for SuiSakhi
Licensed Third-Party
Exclusive Licensed Design
```

### 10.2 SuiSakhi-owned designs

SuiSakhi may:

```text
Commission a Designer
Purchase a Design Once with Ownership Transfer
Acquire Exclusive Rights
Acquire Non-Exclusive Rights
Create Internal Free or Premium Collections
Include Designs in Subscriptions or Campaigns
```

### 10.3 Partner-owned designs

Approved Designer or Boutique Partners may submit designs under agreed ownership, pricing, royalty, license, and visibility rules.

### 10.4 Catalog types

```text
Free
Paid
Premium
Subscription
Royalty-Based
Private Partner Catalog
Regional Catalog
Campaign Catalog
```

### 10.5 Design metadata

```text
Design ID
Design Name
Category
Subtype
Occasion
Style
Compatible Fabrics
Customization Rules
Ownership Type
Owner Profile ID
Creator Profile ID
License Reference
Free or Paid
Customer Price
Royalty Rule
Approval Status
Publication Status
```

Internal SuiSakhi review adds:

```text
Stitching Complexity
Required Tailor Skills
Certification Level
Estimated Tailoring Time
Estimated Fabric Requirement
```

### 10.6 Fabric visualization scope

Phase-1 fabric visualization applies only to approved standardized SuiSakhi catalog designs with suitable line-art or layered assets.

Customer-uploaded designs remain reference-only during Phase 1 to control rendering cost, storage overhead, rights risk, and inconsistent quality.

### 10.7 Admin catalog functions

```text
Single Design Upload
Bulk ZIP and Excel Upload
Metadata Review
Request Contributor Changes
Approve
Publish
Unpublish
Archive
Ownership Management
Free or Paid Classification
Customer Price
Royalty Rule
License Evidence
```

---

## 11. Partner Agreement

Agreement acceptance is mandatory before submission.

### 11.1 Common clauses

```text
Accuracy of Submitted Information
SuiSakhi Terms and Conditions
Customer Data Privacy
Customer Property Handling
Quality Standards
Order Acceptance and Fulfillment
Rework Responsibilities
Delay Reporting
Loss and Damage Reporting
QR and Traceability Compliance
Commercial Terms
Settlement and Payout Rules
Dispute Resolution
Audit Cooperation
Suspension and Investigation Cooperation
```

### 11.2 Category-specific clauses

Tailor, Designer, Doorstep, Boutique, Laundry, Pressing, and future Partners receive additional clauses relevant to the selected categories.

### 11.3 Acceptance fields

```text
agreementAccepted
agreementVersion
riskPolicyVersion
commercialTermsVersion
acceptedAt
acceptedByUid
messageSnapshot
```

### 11.4 Submission control

```text
Agreement Not Accepted
→ Submission Disabled

Agreement Accepted
→ Accept and Submit for Review Enabled
```

---

## 12. Admin Review and Admin-Assisted Completion

### 12.1 Pilot Admin role

For Phase 1, a separate Super Admin interface is not required.

The configured Admin may perform:

```text
Application Review
Minor Data Completion after Partner Confirmation
Request Changes
Rejection
KYC
Commercial Negotiation
Agreement Review
Approval
Availability Intervention
Suspension and Reactivation
```

Logical permissions should remain separable in code for future scale.

### 12.2 Admin review screen

Admin must see all submitted information:

```text
Applicant Details
Business and Operations
Map Location and Coverage
Partner Category and Capabilities
Skills and Expertise
Commercial and Rate Card
Design Catalog Capabilities or Submissions
Agreement Acceptance
KYC
Review History
Audit History
```

### 12.3 Admin-assisted completion

For minor gaps:

```text
Admin Calls Partner
→ Confirms Information
→ Admin Updates Field with Audit
→ Review Continues
```

Examples:

```text
Operating Hours
Capacity
Coverage
Skills Clarification
Rate Clarification
Minor Address Clarification
```

### 12.4 Request Changes only when necessary

```text
Missing Mandatory Document
Partner Must Accept Revised Terms
Partner Must Correct Identity or Ownership Data
Invalid Address or Location
Major Operational Inconsistency
KYC Failure
Compliance Issue
Rights or License Evidence Missing
```

### 12.5 Admin update audit

```text
fieldPath
previousValue
newValue
updatedByUid
updatedAt
confirmationMethod
reasonCode
notes
```

---

## 13. KYC and Verification Framework

KYC is the primary verification gate.

### 13.1 KYC may include

```text
Identity Verification
Document Verification
Address Verification
Business Verification
Video Verification
Background Check
Duplicate or Fraud Check
Optional Physical Verification
```

Video verification belongs to KYC, not Business or Workshop Details.

### 13.2 KYC-captured data

Admin may capture or validate:

```text
Years of Experience
Detailed Team Composition
Master Tailor Count
Helpers
Finishers
Seasonal Workforce
Verified Normal Capacity
Verified Peak Capacity
Bridal Capacity
Workshop or Business Photos, optional
Certificates
Business Registration
GST or Tax Information, where applicable
Bank or Payout Details
```

### 13.3 KYC statuses

```text
Not Started
Pending Documents
Under Verification
Verified
Failed
Expired
```

### 13.4 KYC verified meaning

`Verified` means all checks required by the applicable Partner category, geography, risk level, and commercial plan have been completed or explicitly waived with an audited reason.

---

## 14. Approval and Operational Readiness

Approval requires:

```text
Agreement Accepted
KYC Verified
Mandatory Information Available
Partner-Specific Capability Information Available
Commercial Terms Completed
No Unresolved Critical Change Request
```

For the simplified pilot, Admin approval may create and activate the Partner profile when operational-readiness checks pass.

Operational readiness includes:

```text
Service Area Configured
Skills or Services Configured
Availability Control Enabled
Capacity Configured where applicable
Assignment Notifications Enabled
Commercial Profile Ready
Partner Understands Acceptance Workflow
```

---

## 15. Partner Certification and Tiering

Certification is Admin-controlled and based on KYC evidence, skills, performance, training, and quality.

Example Tailor tiers:

```text
Level 1: Basic Alterations and Pico
Level 2: Blouse, Kurti, and Suits
Level 3: Bridal, Designer, and Premium Work
```

Certification determines order eligibility and must not be self-declared by the Partner.

---

## 16. Admin Partner Operations Dashboard

### 16.1 Summary by category

```text
Tailors: 10
Designer Partners: 5
Doorstep Services: 4
Boutiques: 3
Laundry Partners: 3
Pressing Partners: 2
```

### 16.2 Summary by lifecycle and availability

```text
Draft Applications
Pending Review
Under Review
Changes Requested
KYC Pending
Approved
Active
Busy
Paused
Emergency Stop
Suspended
Inactive
Archived
```

### 16.3 Dashboard actions

```text
View Category List
Search Partner
Open Partner 360
Review Application
Perform KYC
Update Minor Information
Negotiate Commercials
Approve
Suspend
Reactivate
Review Pending Assignments
Review Emergency Orders
```

---

## 17. Partner 360-Degree View

Admin can open any Partner and view:

### Identity and business

```text
Basic Details
Partner Categories
Business Address
Map Location
Service Coverage
Operating Hours
Agreement History
KYC Status
```

### Capabilities

```text
Skills and Expertise
Services
Certification
Supported Fabrics
Special Capabilities
```

### Commercials

```text
Expected Rates
Negotiated Rates
Customer Rates
Discounts
Seasonal Rates
Express Rates
Commission
Settlement Rule
```

### Availability and capacity

```text
Current Availability
Pause Reason
Resume Date
Normal Capacity
Peak Capacity
Current Load
Remaining Capacity
Pending Acceptance Count
```

### Orders and performance

```text
Assigned Orders
Accepted Orders
Declined Orders
Completed Orders
Active Orders
Rework Rate
Cancellation Rate
SLA Performance
Ratings and Reviews
```

### Financials

```text
Earnings
Pending Settlement
Completed Settlement
Payout Holds
Penalties
Incentives
```

### Catalog and ownership

```text
Designs Uploaded
Approved Designs
Published Designs
Paid Designs
Design Revenue
Royalty
```

### Support and governance

```text
Open Tickets
Critical Tickets
Escalations
Incidents
Suspension History
Audit Trail
```

---

## 18. Customer 360-Degree View

Admin can search by Customer name, mobile, Account ID, or Profile ID and view:

```text
Account and Profiles
Family Members
Addresses
Measurements and History
Active Orders
Completed Orders
Cancelled and Archived Orders
Partner Assignments
Purchased Designs
Wishlist
Membership
Coupons
Payments
Refunds
Ratings
Disputes
Helpdesk Tickets
```

Customer and Partner 360-degree views support dispute resolution, service recovery, retention, and operational decision-making.

---

## 19. Partner Availability and Capacity Management

### 19.1 Availability states

```text
Available
Busy
Paused
Emergency Stop
Suspended
Inactive
```

### 19.2 Partner-controlled states

```text
Available
Busy
Paused
```

Partner may provide:

```text
Reason Code
Unavailable From
Expected Resume Date
Reduced Capacity
```

### 19.3 Emergency Stop

Used for:

```text
Medical Emergency
Family Emergency
Accident
Workshop Damage
Flood or Fire
Equipment Failure
Power Failure
Unexpected Closure
Severe Staff Shortage
```

Emergency Stop immediately prevents new assignments.

### 19.4 Admin-controlled states

```text
Suspended
Inactive
Reactivated
Archived
```

### 19.5 Assignment eligibility

A Partner receives new orders only if:

```text
Partner Approved and Active
Availability = Available
Category and Skill Match
Within Service Area
Within Capacity
No Assignment Hold
No Critical Compliance Block
```

### 19.6 Capacity thresholds

```text
Green: 0 to 80 percent utilization
Yellow: Above 80 to 95 percent
Red: Above 95 percent or capacity reached
```

Yellow Partners receive lower assignment priority. Red Partners receive no new assignment.

### 19.7 Existing orders after pause

Pausing new orders does not automatically cancel active orders. Admin and Partner decide whether existing work can continue.

---

## 20. Automatic Order Assignment and Partner Acceptance

### 20.1 Core payment gate

An order must not proceed to Customer payment until an eligible Partner has been assigned and has accepted the order.

```text
Customer Creates Order
→ Pending Assignment
→ Assignment Engine Selects Eligible Partner
→ Awaiting Partner Acceptance
→ Partner Accepts
→ Awaiting Customer Payment
→ Customer Pays
→ Order Confirmed
→ Next Operational Stage
```

### 20.2 Why acceptance precedes payment

```text
Avoid Payment for an Unfulfillable Order
Reduce Refunds
Reduce Partner Rejection after Payment
Protect Customer Confidence
Handle Peak-Season Capacity Honestly
```

### 20.3 Assignment inputs

```text
Partner Active Status
Availability
Capacity and Current Load
Category Match
Skill Match
Certification
Service Area and Distance
Fabric or Service Compatibility
SLA Performance
Quality Score
Partner Rating
Emergency or Assignment Hold
```

### 20.4 Partner actions

```text
Accept
Decline with Reason
Request Clarification
```

### 20.5 Partner acceptance timeout

Assignment metadata should define:

```text
acceptanceDueAt
reminderAt
escalationAt
expiryAt
```

If no acceptance occurs within the configured window, the system may try the next eligible Partner or move the order into Admin intervention.

### 20.6 Pilot policy

Partner acceptance is mandatory during the pilot. Automatic acceptance may be considered later for trusted Partners and clearly defined service types.

---

## 21. Pending Assignment and Admin Intervention

### 21.1 Pending states

```text
Pending Assignment
Auto Assignment Failed
Awaiting Partner Acceptance
Partner Clarification Requested
Manual Assignment Required
Capacity Blocked
Emergency Hold
Awaiting Customer Payment
```

### 21.2 Customer experience

Until Partner acceptance:

```text
Order Status = Finding a Suitable Partner
Payment Not Requested
```

The Customer should receive truthful status updates without exposing unnecessary internal details.

### 21.3 Admin pending queue

Admin must see:

```text
Order Age
Customer
Service Type
Required Skills
Location
Attempted Partners
Decline Reasons
Acceptance Due Time
Capacity Constraint
Peak-Season Flag
Emergency Flag
```

### 21.4 Admin actions

```text
Call Suggested Partner
Request Partner to Review Assignment
Manually Assign Eligible Partner
Extend Acceptance Window
Adjust Partner Capacity after Confirmation
Find Alternate Partner
Place Order on Hold
Communicate Revised Expectation to Customer
Cancel before Payment when No Fulfillment is Possible
```

### 21.5 Peak-season handling

During high demand, orders may remain Pending Assignment. Admin can coordinate with Partners in the background and invite a Partner to accept without taking payment prematurely.

### 21.6 Audit

Every assignment attempt records:

```text
orderId
partnerProfileId
assignmentMethod
assignedAt
acceptanceDueAt
response
responseReasonCode
respondedAt
adminIntervention
attemptNumber
```

---

## 22. Emergency Handling and Order Transfer

### 22.1 New orders

Busy, Paused, Emergency Stop, Suspended, inactive, or full-capacity Partners receive no new assignment.

### 22.2 Accepted but unpaid orders

If a Partner becomes unavailable before Customer payment:

```text
Withdraw Assignment
→ Reassign
→ Request Payment only after New Partner Acceptance
```

### 22.3 Paid or in-progress orders

Do not automatically cancel or transfer.

```text
Assess Garment or Material Custody
Assess Work Completed
Assess Transfer Feasibility
Notify Customer
Select Qualified Replacement Partner
Create Handover and Audit Events
Adjust Commercials and SLA
```

### 22.4 Admin options

```text
Allow Original Partner to Complete
Reduce New Assignment Capacity
Transfer Remaining Work
Arrange Material Pickup
Assign Emergency Partner
Revise Delivery Date with Customer Consent
Refund or Cancel according to Policy
```

---

## 23. Partner Performance and Assignment Score

Future assignment score may combine:

```text
Availability Score
Skill Match Score
Certification Score
Distance Score
Capacity Score
SLA Score
Quality Score
Rating Score
Acceptance Reliability
Rework Risk
```

The score assists routing but must respect hard eligibility blocks.

---

## 24. Risk, Evidence, and Partner Responsibilities

Critical controls include:

```text
QR Garment Identification
Chain of Custody
Pickup and Delivery Evidence
Customer OTP
Issue Reporting
Loss and Damage Reporting
Delay Reporting
Availability Accuracy
Capacity Accuracy
No Acceptance Beyond Capability
```

Operational photos follow the configurable retention policy defined in the Operational Review Addendum, with automatic deletion only after delivery, payment settlement, the retention period, and confirmation that no open dispute or legal hold exists.

---

## 25. Metadata Domains

```text
Partner Categories
Partner Subcategories
Business Types
States and Cities
Service Areas
Languages
Communication Channels
Skills and Expertise
Services
Fabric Capabilities
Measurement Capabilities
Rate Items
Rate Types
Discount Types
Commercial Plans
Agreement Templates
KYC Requirements
Document Types
Certification Levels
Availability Statuses
Pause and Emergency Reasons
Assignment Decline Reasons
Incident Types
Notification Templates
```

---

## 26. Phase-1 Implementation Priorities

### Priority A: Simplify current Tailor flow

```text
Remove Save Workshop Details
Save all data through Save Draft
Replace Workshop terminology with Business and Operations where common
Add State and dependent City dropdowns
Add standardized time pickers
Add Skills and Expertise checkboxes and Other
Add Partner Agreement acceptance
Show all submitted information to Admin
Reset reviewed section to Completed when Partner changes it
```

### Priority B: Complete Admin review loop

```text
Admin View of All Partner-Submitted Data
Admin-Assisted Minor Updates
KYC
Commercial Negotiation
Agreement Review
Approve, Request Changes, or Reject
```

### Priority C: Pilot Partner extensions

```text
Tailor
Designer
Doorstep Services
Boutique
Laundry
Pressing
```

### Priority D: Design Catalog Management

```text
SuiSakhi-Owned Free and Paid Designs
Designer and Boutique Design Contributions
Single Upload
Bulk ZIP and Excel Upload
Ownership, Price, Royalty, Review, and Publication
```

### Priority E: Operational Partner controls

```text
Available or Pause New Orders
Capacity and Current Load
Pending Acceptance
Admin Pending Assignment Queue
Partner Acceptance Before Payment
Emergency Stop and Controlled Transfer
```

---

## 27. Development Guardrails

Before each Partner-module change:

```text
Confirm Current Git Checkpoint
Make One Small Change
Run dart format
Run flutter analyze lib
Expected Baseline: 10 Known Issues
Run git diff --check
Test Draft, Review, Changes Requested, and Resume
Commit and Push
Update Project Context after Major Changes
```

Do not implement a new Partner section until the end-to-end loop is complete for the current section:

```text
Partner Entry
Save and Resume
Admin View
Admin-Assisted Update
KYC or Verification
Agreement or Commercial Impact
Rules and Audit
Regression Test
```

---

## 28. Master Architecture Reference

Add the following reference to the SuiSakhi Master Architecture:

```text
Partner onboarding, category extensions, KYC, agreements,
commercials, catalog governance, Admin 360-degree operations,
availability, capacity, assignment, acceptance, emergencies,
and Partner lifecycle are governed by:

SuiSakhi_Partner_Engagement_Architecture_v1.0.md
```

---

## 29. Review Checklist

Before freezing version 1.0, confirm:

```text
Common Basic Details accepted
Common Business and Operations accepted
Partner-specific extensions accepted
Commercial and Rate Card accepted
Agreement clauses accepted
Admin-assisted completion accepted
KYC as primary verification gate accepted
No separate Super Admin interface for Pilot accepted
Admin Partner and Customer 360 accepted
Availability and capacity rules accepted
Partner acceptance before payment accepted
Pending assignment Admin queue accepted
Peak-season intervention accepted
Emergency transfer flow accepted
Design catalog ownership accepted
Pilot implementation order accepted
```

---

## 30. Final Operating Principle

```text
SuiSakhi shall not transfer avoidable operational complexity
to Customers or Partners when the same complexity can be
handled through clear metadata, intelligent workflow,
Admin assistance, truthful status communication, and audit.
```

The objective is not merely to register Partners. The objective is to build a low-friction, trusted, measurable, commercially governed, and operationally resilient Partner ecosystem capable of fulfilling Customer orders successfully during normal and peak-season demand.

---

**End of SuiSakhi Partner Engagement Architecture v1.0 Draft**
