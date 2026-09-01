# SuiSakhi Partner Engagement Architecture v1.0

## Final Freeze Candidate

**Version:** 1.0  
**Status:** Final review before freeze  
**Date:** 31 August 2026  
**Pilot target:** 14 October 2026  
**Governing scope:** Partner engagement, onboarding, governance, operations, assignment, standards, support, risk, recovery, settlement, performance, and audit

---

## 1. Purpose

This document is the authoritative Partner architecture for SuiSakhi. The Master Architecture shall reference this document rather than duplicate detailed Partner rules.

This document governs:

```text
Partner categories and profiles
Partner onboarding and agreements
Super Admin, Admin, Verification/KYC, Commercial, Partner Operations, Helpdesk and Chatbot roles
Admin-assisted Partner gap analysis
Customer 360, Partner 360 and Service/Order 360
Partner KYC and operational readiness
Partner capabilities, standards and certifications
Rates, discounts, campaigns, packages and subscriptions
Design catalog ownership and governance
Availability, capacity and assignment
Partner acceptance before Customer payment
QR identity, custody, evidence and QC
SLA, delay, loss, damage, rework and dispute handling
Settlement, performance and fair Partner governance
Metadata versioning, security and audit
```

---

## 2. SuiSakhi Trust Promise

SuiSakhi shall design every Partner and order workflow around the following promise:

> If something goes wrong, SuiSakhi can identify what happened, protect the Customer, communicate truthfully, recover the work where possible, treat the Partner fairly, and preserve an auditable record.

This promise applies to:

```text
Assignment
Partner acceptance
Customer payment
Measurement
Material and garment custody
Work execution
Quality control
Delivery
Loss and damage
Delay and SLA breach
Rework
Complaints and disputes
Financial adjustment
Partner performance and governance
```

Trust must work in both directions. Customer protection and Partner fairness are equally necessary for a sustainable ecosystem.

---

## 3. Phase-1 Partner Categories

Priority Partner categories for the pilot:

```text
1. Tailor Partner
2. Designer Partner
3. Measurement Partner
4. Doorstep / Quick-Fix Partner
5. Boutique Partner
6. Pressing Partner
7. Laundry Partner
8. Brand Partner
```

Foundation-ready categories:

```text
Fabric Supplier
Embroidery Partner
Printing Partner
Delivery Partner
Alteration Partner
Rental Partner
Accessories Partner
Garment Supplier Partner
Other or Future Partner Categories
```

Partner categories are controlled metadata. A new category must not require redesign of the common Partner foundation.

---

## 4. Canonical Partner Identity and Multi-Category Model

```text
One Account
→ Customer Profile created by default
→ At most one active Partner Profile per business identity
→ One or more Partner Categories
→ Multiple services, capabilities, locations and rate cards
```

A single Partner Profile may support multiple categories, for example:

```text
Tailor + Measurement + Doorstep Services
Designer + Boutique
Laundry + Pressing
Brand + Designer + Boutique
```

Common identity, KYC, agreement, audit and settlement ownership remain at Partner Profile level. Category readiness, capability, availability, capacity, rate cards and suspension may be managed independently.

Required identifiers:

```text
accountId
partnerApplicationId
partnerProfileId
partnerCategoryCodes
serviceCodes
capabilityCodes
locationIds
commercialProfileIds
```

---

## 5. Role and Permission Architecture

Backend authorization is the source of truth. UI visibility never grants permission.

### 5.1 Super Admin

Super Admin exists from Day 1 and has full Customer 360 and Partner 360 visibility, subject to security, privacy and audit controls.

Primary responsibilities:

```text
System and business governance
Global metadata governance
Role and permission governance
Global configuration
Exceptional operational intervention
Final or exception approval where policy requires
Audit oversight
Commercial policy governance
Subscription and promotion governance
Standardization governance
Security and policy oversight
```

Super Admin may govern:

```text
Services and service categories
Skills
Garments and materials
Capability levels and certifications
SLAs and QC standards
Stitching, laundry, pressing and doorstep standards
Rate cards, discounts, promotions and packages
Subscriptions
Notification templates and reason codes
Assignment rules
KYC rules
Agreement versions
Geographic rules
Other centrally governed metadata
```

### 5.2 Admin

Admin has broad operational Customer 360 and Partner 360 visibility and is the primary Partner relationship owner.

Admin may:

```text
View Partner applications, including Draft applications
Assist Partners in completing Draft applications
Perform Partner gap analysis
Contact Partners for missing or unclear information
Review capabilities, experience and operational readiness
Perform delegated KYC and verification
Negotiate or manage Partner commercial information according to policy
Approve and activate within delegated authority
Manage Partner availability, capacity and operational status
Configure capabilities and service readiness within delegated scope
Manage delegated rate cards, discounts, packages and subscriptions
Manage order, assignment, QC, incident and relationship exceptions
View Customer 360 and Partner 360
```

Admin must not bypass backend controls.

### 5.3 Verification / KYC

Verification/KYC is a delegated function that may be performed by an authorized Admin or dedicated Verification user.

Permitted scope:

```text
Identity verification
Address verification
Business verification
Document verification
Video verification
Background check
Capability evidence
Verification notes and outcomes
```

KYC users cannot modify unrelated commercials, global metadata, system roles or settlements.

### 5.4 Commercial

Commercial users may perform delegated commercial work:

```text
Rate negotiation
Rate-card preparation
Discount and package preparation
Commercial acceptance tracking
Settlement-rule configuration within authority
Commercial exception submission
```

Commercial users cannot approve KYC or change global security policy.

### 5.5 Partner Operations

Partner Operations manages:

```text
Partner relationship
Availability and capacity
Assignment intervention
Order recovery
Operational readiness
SLA monitoring
Incident coordination
Category and capability readiness within authority
```

### 5.6 Helpdesk and Chatbot

Helpdesk is a service-relationship and order-support role. Chatbot is the L0 self-service and ticket-intake layer.

Escalation levels:

```text
L0 Chatbot
L1 Helpdesk
L2 Partner Operations
L3 Admin
L4 Super Admin or Policy Owner
```

Helpdesk may:

```text
Search Customer and Partner records required to support an order
View order-related Customer information
View order-related Partner information
Track order status
Track Partner assignment and acceptance
View applicable SLA and status information
View pickup, handover and delivery status
View QC and rework status required to explain an issue
Communicate with Customer
Communicate with Partner about an active service or order issue
Create and update support tickets or incidents within permitted scope
Escalate onboarding, KYC, commercial or governance issues to Admin
```

Helpdesk must not:

```text
Approve or activate a Partner
Perform or change KYC
Change certification or Partner capability
Change commercial rates
View Partner settlement, bank or payment information
View Customer payment instruments or sensitive payment information
View Aadhaar or unmasked identity documentation
Change governed metadata or system policy
Change security permissions
Override assignment, QC or financial controls
```

Chatbot may:

```text
Answer approved FAQs
Show permitted order and assignment status
Show pickup and delivery status
Create or update a ticket
Collect initial issue details
Escalate to Helpdesk
```

Chatbot cannot approve compensation, expose private data, alter commercials, approve or suspend Partners, or make legal or final dispute decisions.

---

## 6. Visibility Model

### 6.1 Customer 360 for Super Admin and Admin

```text
Identity and profiles
Addresses and family/customer profiles
Preferences
Measurements and measurement history
Garments and services
Orders and Partner relationships
Communications
Complaints and incidents
Loyalty and subscription status
Permitted commercial history
Payments, refunds and adjustments according to role
Audit history according to role
```

### 6.2 Partner 360 for Super Admin and Admin

```text
Identity and business
Locations and staff
Categories, services and capabilities
Certifications
Garment and material compatibility
SLA and QC
Capacity and availability
KYC and documents
Agreements
Commercials, ledger and settlement
Assignments and orders
Performance and incidents
Communications
Catalog and design ownership
Audit
```

### 6.3 Service/Order 360 for Helpdesk

Helpdesk receives only the information required to resolve the service or order issue.

```text
Masked Customer and Partner contact
Order and service information
Assignment and acceptance status
Pickup, custody, QC, rework and delivery timeline
Customer-safe communications
Ticket and incident history
Permitted payment status, not payment instruments
```

Sensitive KYC, bank, settlement, internal fraud, role, permission and unrelated profile data remain hidden.

---

## 7. Simplified Partner Engagement Flow

```text
1. Basic Details
2. Business, Location and Service Area
3. Services and Capability Declaration
4. Category-Specific Inputs
5. Capability Evidence / Certification Readiness
6. Documents and KYC Preparation
7. Commercials, Rate Card and Agreement
8. Submit for Review
9. Review, Gap Analysis and Verification
10. Approval or Rejection
11. Partner Profile Creation
12. Operational Readiness
13. Activation
```

Primary Partner actions:

```text
Save Draft
Accept and Submit for Review
```

Section-level save buttons are avoided in the target flow.

---

## 8. Admin-Assisted Partner Gap Analysis

Admin assistance is a first-class Partner Engagement capability.

```text
Partner Draft
→ Admin Opens Draft
→ Profile Gap Analysis
→ Admin Contacts Partner
→ Partner Clarification or Evidence
→ Admin Completes Permitted Fields
→ Partner Confirmation Where Required
→ Ready for Submission or Verification
```

Gap types:

```text
Basic information
Capability information
Service information
Experience information
Document information
Commercial information
Operational information
Agreement or consent information
```

Field ownership classes:

```text
Partner-Controlled
Admin-Assisted
Admin-Verified
System-Derived
```

Admin cannot accept agreements, identity declarations, bank ownership declarations, design-rights declarations or sensitive consent on behalf of the Partner.

Material Admin-assisted changes require a Partner-visible summary and confirmation where policy requires.

---

## 9. Common Input Modules

### 9.1 Basic Details

```text
Contact Name
Business Name
Authenticated Mobile
Alternate Mobile, optional
Email, optional
Preferred Language
Preferred Communication Channel
```

### 9.2 Business, Location and Service Area

```text
Business Type
State
City
Pincode
Address
Map Location
Operating Days
Opening and Closing Time
Team Size
Service Radius or Coverage Pincodes
Pickup Capability
Delivery Capability
```

State and City are metadata-driven dropdowns. Time uses a time picker and normalized 24-hour storage.

Map selection automatically stores:

```text
placeId
formattedAddress
latitude
longitude
geoHash
locationVerifiedAt
```

Partners do not enter coordinates manually.

### 9.3 Common geographic privacy

A home-based Partner's exact address is not displayed publicly unless operationally required and authorized.

---

## 10. Category-Specific Capability Modules

### 10.1 Tailor

Structured multi-select expertise:

```text
Blouse
Kurti and Suit
Dress
Lehenga
Bridal
Designer Wear
Alteration
Saree Pico and Fall
Embroidery
Aari
Zardozi
Designer Replication
Old Garment Conversion
Girls Wear
School Uniform
Wedding and Family Packages
Event Orders
Urgent Orders
Pattern Making
Premium Finishing
Other Expertise + Description
```

Measurement compatibility:

```text
Standard Measurement Sheet
Trained Measurer
Old Garment Reference
Video Measurement
QC Re-Measurement
Doorstep Measurement
Final Measurement Verification
```

### 10.2 Designer

```text
Original Design
Custom Design
Design Modification
Fashion or Occasion Consultation
Fabric Consultation
Bridal Collection
Daily, Party and Girls Collections
Premium Collection
Design Licensing
Digital Catalog Upload
```

### 10.3 Measurement Partner

```text
Home-Visit Measurement
Video-Assisted Measurement
Standard Manual Measurement
Old Garment Reference Measurement
AI Measurement Validation Support
Re-Measurement and Correction
Girls Measurement
Special-Fit Measurement
```

Measurement Partner creates a new version or proposed measurement and must not silently overwrite Customer, Tailor or Final Confirmed versions.

### 10.4 Doorstep / Quick-Fix

```text
Button, Hook/Eye, Zip and Elastic Replacement
Loose Stitch and Minor Tear Repair
Hemming and Minor Adjustment
Saree Pico and Fall
Saree Draping
Uniform Quick Fix
Curtain and Cushion Repair
Emergency Event-Wear Repair
```

### 10.5 Boutique

```text
Custom Stitching
Ready-Made Sales
Tailoring and Designer Services
Trial Facility
Bridal and Premium Services
In-Store Pickup
Home Consultation
Inventory Fulfillment
```

### 10.6 Laundry

```text
Wash Methods
Detergent and Chemical Standards
Water Temperature
Separate Wash
Color Protection
Stain Treatment
Drying Method
Premium and Bridal Care
Express Processing
```

### 10.7 Pressing

```text
Hand Press
Steam Press
Roll Press
Vacuum Press
Dry Press
Low-Temperature Press
Protective-Cloth Press
Fabric and Embellishment Compatibility
```

### 10.8 Brand Partner

```text
Brand Catalog
Ready-Made Products
Made-to-Order Products
Brand-Owned Designs
Campaign Participation
Regional Availability
Brand-Sponsored Offers
Bulk or Corporate Orders
```

Brand Partner, Designer and Boutique are separate categories, although one Partner Profile may hold multiple categories.

---

## 11. Operational Standardization

Exact values are Product Owner-approved, versioned metadata and are not hardcoded inside application logic.

### 11.1 Stitching Standardization

```text
Machine Type and Class
Needle Type and Size
Thread Type and Size
Stitch Type and Density
Seam Allowance
Lining and Interlining
Finishing and Edge Finishing
Embroidery and Embellishment Handling
Pressing Requirement
QC Checklist
```

The applied Stitching Standard and version are attached to the order or work package.

### 11.2 Laundry Standardization

```text
Wash Method
Water Temperature Range
Detergent Standard or Type
Chemical Restriction
Pre-Treatment
Stain Treatment
Separate-Wash Requirement
Color Protection
Drying Method and Temperature
Fabric Protection
Finishing
QC
```

### 11.3 Pressing Standardization

```text
Pressing Method
Temperature Band
Steam Requirement
Pressure Level
Protective Cloth
Garment Orientation
Embellishment Protection
Finishing Method
QC
```

### 11.4 Doorstep / Quick-Fix Standardization

```text
Service Type
Typical Duration
Tools Required
Visit Requirement
Minimum Visit Charge
Service Radius
Same-Day Eligibility
Emergency Eligibility
Before and After Evidence
Customer OTP Completion
```

### 11.5 Standard-resolution precedence

```text
Legal or Safety Restriction
→ Material-Specific Standard
→ Garment-Specific Standard
→ Service-Specific Standard
→ Capability-Level Standard
→ Approved Partner Exception
→ Default Standard
```

Every order snapshots the resolved standard code and version.

---

## 12. Commercial, Rate, Campaign and Subscription Architecture

### 12.1 Commercial layers

```text
Partner Expected Rate
Negotiated Partner Cost
Customer Price
Platform Fee
Tax
Discount and Funding Source
Incentive
Penalty
Settlement Amount
```

### 12.2 Standard service rates

Admin or Super Admin may configure governed rates for:

```text
Stitching
Alteration
Pico/Fall
Embroidery
Aari
Zardozi
Designer Replication
Bridal Work
Wedding Packages
Doorstep Quick Fix
Button Replacement
Zip Repair
Hook/Eye Replacement
Elastic Replacement
Minor Tear Repair
Laundry
Dry Cleaning
Steam, Hand and Roll Pressing
Pickup and Delivery
Doorstep Visit
Measurement Service
```

### 12.3 Rate dimensions

```text
Service
Garment
Material
Complexity
Partner Capability Level
Location
Normal, Express or Emergency
Quantity and Bulk Threshold
Wedding or Package Type
Season
Customer Segment
Subscription Entitlement
```

### 12.4 Rate versioning

Every rate requires:

```text
rateCode
version
effectiveFrom
effectiveTo
currency
taxRule
unit
price
status
owner
approvalStatus
audit
```

Orders snapshot the applied rate and version.

### 12.5 Commercial acceptance

```text
Partner Expected Rate
→ Admin Negotiation
→ Proposed Agreed Rate
→ Partner Acceptance
→ Commercial Approval
→ Effective Version
```

### 12.6 Discounts and promotions

Support:

```text
Percentage and Fixed Discounts
Service or Category Discount
Customer Segment
First Order and Referral
Wedding and Family Package
Bulk, Festival and Off-Season
Subscription Discount
Partner-Funded, SuiSakhi-Funded or Shared-Funding
```

Controls:

```text
Start and End Date
Eligibility
Minimum Order Value
Maximum Discount
Usage Limits
Applicable Service or Category
Stackability
Funding Source
Approval Status
Priority
```

Discount application is deterministic and auditable.

### 12.7 Packages

```text
Wedding
Bridal
Family
Festival
New Customer
Alteration
Laundry + Pressing
Doorstep Quick-Fix
Premium Custom Stitching
```

### 12.8 Subscriptions

```text
Monthly, Quarterly and Annual
Family and Premium
Partner or Boutique Service
Laundry
Pressing
Doorstep
```

Subscription entitlements are centralized metadata rules, not screen-specific logic.

---

## 13. Design Catalog Governance

Ownership types:

```text
SuiSakhi-Owned
Designer-Owned
Boutique-Owned
Partner-Owned
Commissioned for SuiSakhi
Licensed Third-Party
Exclusive Licensed
```

Support:

```text
Free
Paid
Premium
Subscription
Royalty
Private or Regional Catalog
```

Admin and Super Admin functions:

```text
Single Upload
Bulk ZIP + Excel Upload
Metadata Review
Contributor Change Request
Approval
Publication
Unpublication
Archival
Ownership, Price, Royalty and License Governance
```

Phase-1 fabric visualization is limited to approved standardized catalog designs. Customer-uploaded designs remain reference-only.

---

## 14. Metadata Governance

### 14.1 Hierarchy

```text
Super Admin
→ Global Metadata Policy
→ Standard Masters
→ Versions and Effective Dates
→ Delegated Admin Configuration
→ Operational Partner, Customer and Order Usage
```

### 14.2 Conceptual metadata domains

```text
partner_categories
services and sub_services
skills and certifications
garments and materials
stitching, laundry, pressing and doorstep standards
qc_standards and slas
rate_cards, discounts, promotions and packages
subscriptions
reason_codes and notification_templates
agreement_versions
assignment_rules and kyc_rules
geographic_rules
```

### 14.3 Effective-date principle

Never overwrite history. Rates, discounts, standards, SLAs, QC, agreements, subscriptions and assignment rules are versioned with effective dates.

Historical orders retain the exact version used.

### 14.4 Security

```text
Customer cannot change governed metadata
Partner cannot change global standards
Helpdesk cannot change metadata
Admin changes only delegated metadata
Super Admin governs global metadata
Critical changes may require elevated approval
All changes are audited
Historical snapshots are immutable
```

### 14.5 Metadata Control Center

Phase-1 functions:

```text
Search Metadata
View Active and Future Versions
Create New Version
Edit Permitted Fields
Set Effective Date
Activate or Deactivate
Compare Versions
View Usage and Audit
Submit Critical Change for Approval
```

---

## 15. Partner Agreement and Direction

### 15.1 Partner Agreement

Before submission, the Partner accepts versioned clauses covering:

```text
Accuracy
Privacy and Customer Data
Customer Property
Quality and QC
Order Acceptance
Availability and Capacity Accuracy
Rework
Delay, Loss and Damage Reporting
Commercials and Settlement
QR and Custody Compliance
Disputes
Audit and Investigation
```

### 15.2 Partner direction and fairness

Partners should receive:

```text
Clear assignment requirements
Clear expected SLA
Clear commercial terms
Clear QC standards
Fair decline reason classification
Fair rework attribution
Transparent ledger entries
Controlled dispute process
Ability to report capacity problems
Ability to pause services
Ability to challenge incorrect operational data
Ability to respond to complaints and evidence
Ability to provide a Garment DNA / stitching report or post-laundry report
```

The Garment DNA or service report may include:

```text
Applied standard and version
Materials and methods used
Stitching, washing or pressing parameters
QC results
Exceptions and changes
Evidence references
Partner notes
Completion timestamp
```

This report is a major SuiSakhi differentiation and supports traceability, rework, care guidance and dispute resolution.

---

## 16. KYC, Certification and Activation

KYC is the primary verification gate and may include:

```text
Identity, Address, Business and Document Verification
Video Verification
Background Check
Duplicate or Fraud Check
Capability Evidence
Optional Physical Verification
```

KYC may record:

```text
Years of Experience
Team Composition
Verified Capacity
Certificates
Business Photos
GST or Tax Information
Bank and Payout Readiness
```

Certification is Admin-controlled and cannot be self-declared.

Approval and activation authority is policy-driven:

```text
Normal Risk: Admin within delegated authority
High Risk or Exception: Super Admin
Temporary Suspension: Admin within policy
Permanent Block or Policy Override: Super Admin
```

---

## 17. Availability, Capacity and Fair Assignment

Availability states:

```text
Available
Busy
Paused
Emergency Stop
Suspended
Inactive
```

Orders route only to a Partner who is:

```text
Approved and Active
Available
Within Service Area
Within Capacity
Skill and Material Compatible
SLA and Certification Eligible
Not Assignment-Blocked
```

Capacity thresholds:

```text
Green: 0–80%
Yellow: >80–95%
Red: >95% or full
```

Partner may pause services or report reduced capacity. Category-level availability is supported for multi-category Partners.

An Available Partner is reasonably expected to consider suitable assignments matching declared capability, area, capacity, SLA and commercials.

Declines require a reason code so the system can distinguish:

```text
Valid System Mismatch
Valid Partner Constraint
Partner-Controlled Capacity Issue
Customer or Order Clarification
Emergency
Potential Reliability Concern
```

No Partner is penalized for a genuine system mismatch.

---

## 18. Order Assignment, Acceptance, Payment and Capacity Reservation

```text
Customer Creates Request
→ Eligibility Check
→ Auto Assignment
→ Assignment Sent
→ Partner Acceptance
→ Capacity Reserved
→ Customer Payment
→ QR Generated
→ Work Execution
```

Customer payment is requested only after a valid Partner accepts.

Pilot assignment modes:

```text
Sequential Assignment by default
Controlled Parallel Offer during peak season
Admin-Invite Assignment for intervention
```

Only one acceptance may win. Acceptance is atomic and all competing offers expire.

After acceptance:

```text
Capacity Reservation Created
→ Payment Window Starts
→ Payment Success converts reservation to confirmed load
→ Payment Expiry releases reservation
```

Admin sees Pending Assignment, Awaiting Acceptance, Capacity Block, Emergency Hold and Awaiting Payment queues.

---

## 19. SLA and Delay Management

### 19.1 SLA model

Every assignment or work package snapshots:

```text
slaCode
slaVersion
acceptedAt
plannedStartAt
milestoneDueAt
promisedCompletionAt
deliveryDueAt
riskStatus
breachStatus
```

### 19.2 Delay / SLA breach flow

```text
Partner Identifies Risk
→ Partner Reports Delay Reason
→ System or Admin Evaluates SLA Risk
→ Low Risk: Notify and Continue
→ High Risk: Admin Escalation and Customer Communication
→ Decide Original Partner Continue or Transfer Remaining Work
→ Revised Commitment
→ Audit Record
```

Never hide a delay until the promised date has passed.

### 19.3 Delay reason codes

```text
Capacity
Machine or Equipment
Material
Measurement Clarification
Customer Change
Staff Shortage
Partner Emergency
Logistics
Weather or Local Disruption
Admin Intervention
Other Approved Reason
```

### 19.4 SLA recovery

```text
Replan
Reassign Remaining Work
Add Support Partner
Change Delivery Mode
Revise Commitment with Customer Communication
Commercial Adjustment according to policy
```

---

## 20. Garment, Material and Sample Custody

Trackable item types:

```text
Customer Garment
Reference Garment
Fabric Bundle
Sample Garment from Garment or Fabric Supplier
Fabric Swatch
Rental Item
Accessory Bundle
```

Every item may carry:

```text
itemId
itemType
ownerType and ownerId
orderId
QR or Human-Readable Code
currentCustodian
condition
handoverHistory
returnRequired
returnDueAt
```

No Partner accepts unidentified Customer or Partner property.

---

## 21. Loss and Damage

### 21.1 Detection and response

```text
Immediate Incident Creation
→ Evidence Capture
→ Garment, Material or Order Identification
→ Customer Notification
→ Partner Response
→ Admin Assessment
→ Responsibility Decision
→ Resolution Decision
→ Compensation, Refund or Replacement according to approved policy
→ Ledger Adjustment if applicable
→ Incident Closure
→ Partner Performance Update
```

### 21.2 Responsibility outcomes

```text
Customer Responsible
Partner Responsible
SuiSakhi Responsible
Shared Responsibility
No-Fault Operational Event
Unknown Pending Investigation
```

### 21.3 Recovery options

```text
Locate and Recover
Repair or Rework
Replacement
Service Credit
Partial or Full Refund
Partner Deduction according to accepted policy
Insurance Claim
Goodwill Compensation
No Financial Adjustment
```

### 21.4 Evidence integrity

No silent deletion, alteration or replacement of evidence.

Corrections use:

```text
Original Record
→ Correction Event
→ Reason
→ Actor
→ Timestamp
```

Evidence stays on retention hold until dispute, claim, audit or legal review closes.

---

## 22. Customer Complaint and Dispute Flow

```text
Customer Raises Issue through Chatbot or Helpdesk
→ Ticket / Incident Created
→ Order or Work Package Identified
→ Evidence Collected
→ Partner Response
→ Admin Review
→ Resolution and Action
→ Customer Acknowledgement
→ Financial Adjustment if applicable
→ Closure
→ Performance Update
```

Complaint records retain:

```text
reasonCode
messageSnapshot
evidence
internalNotes
PartnerResponse
resolution
timestamps
actor and role
audit history
```

Helpdesk collects and communicates. Admin or delegated policy owner makes controlled operational or financial decisions.

---

## 23. Rework and QC Attribution

Rework decisions must determine:

```text
Defect Type
Severity
Evidence
Applied Standard and Version
Responsible Party
Customer Change versus Partner Error
Rework SLA
Commercial Responsibility
Customer Communication
```

Fair rework attribution protects both Customer and Partner.

---

## 24. Ratings, Reliability and Fair Governance

A single low rating, decline or incident does not automatically ban a Partner.

Governance evaluates:

```text
Verified Order Volume
Trend
Severity
Service Type
Complaint and Incident History
Partner Response
Evidence
SLA and QC
Acceptance Reliability
Capacity Utilization
Admin Decision
```

Reviews support:

```text
Verified Orders Only
Partner Response
Moderation
Appeal
Evidence Link
Conflict Flag
```

---

## 25. Reason Codes

Centrally governed reason-code domains include:

```text
Cancellation
Delay
Decline
Rework
Damage
Loss
Customer Change
Partner Error
Capacity
Machine or Equipment
Material
Admin Intervention
Emergency
Assignment Expiry
Payment Expiry
KYC Outcome
Suspension
Financial Adjustment
```

Reason codes drive analytics, notifications, escalation, audit and fair Partner governance.

---

## 26. Settlement and Ledger

```text
Order Financials
→ Partner Ledger Entry
→ Settlement Run
→ Payout or Bank Transfer
→ Ledger and Reports
```

The ledger can include:

```text
Partner Cost
Platform Fee
GST or Tax
Discount and Funding Source
Incentive
Penalty
Adjustment
Settlement Amount
```

Every adjustment links to a reason code, actor, policy and audit record.

---

## 27. Notification and Communication Audit

Important events always create an in-app system record even if WhatsApp, email or SMS fails.

```text
Application Submitted
Information Requested
Agreement Updated
KYC Action Required
Partner Approved
Assignment Offered
Acceptance Reminder or Expiry
Payment Requested or Expired
SLA Risk
Emergency Hold
Order Reassigned
Incident Opened
Resolution Issued
```

Store:

```text
templateCode
templateVersion
recipient
channel
messageSnapshot
deliveryStatus
sentAt
retryCount
```

---

## 28. Security and Sensitive Data Separation

Logical separation:

```text
Partner Profile
Private KYC
Private Finance
Agreements
Capabilities
Commercials
Audit
```

Principles:

```text
Least Privilege
Purpose Limitation
Field Masking
Consent
Retention
Access Audit
No Sensitive Data in QR
No Sensitive Data in Notification Payload
```

Critical records are not silently deleted.

---

## 29. Phase-1 Metadata Priorities

### P0 before core operational coding

```text
Partner Categories
Services and Sub-Services
Skills
Garments and Materials
Capability Levels
SLA and QC
Reason Codes
Partner Statuses and Pause Reasons
Basic Rate Cards and Discounts
Notification Templates
Role and Permission Mapping
```

### P1 during operational rollout

```text
Stitching, Laundry, Pressing and Doorstep Standards
Certification
Capacity Units
Assignment Rules
Packages
Partner-Specific Rate Overrides
```

### After stabilization

```text
Subscription Engine
Advanced Promotions
Complex Pricing
Advanced Loyalty
AI Metadata Recommendations
Automated Optimization
```

---

## 30. Phase-1 Scope and Guardrails

Phase 1 must include:

```text
Eight priority Partner categories
Super Admin, Admin, KYC, Commercial, Partner Operations, Helpdesk and Chatbot authorization
Common onboarding and category extensions
Agreement acceptance
Admin gap analysis
KYC and activation
Partner and Customer 360 foundations
Basic commercials and governed metadata
Availability, capacity, assignment and acceptance before payment
Pending Assignment Admin queue
SLA, reason codes, evidence, incident and audit
Loss, damage, rework and dispute workflows
```

Controlled manual operations are acceptable during the pilot when audited.

Deferred:

```text
Full Subscription Engine
Advanced Promotion Stacking
Automated Compensation
AI Partner Scoring
RFID and NFC
Advanced Multi-City Hierarchy
Complex Workflow Designer
```

---

## 31. Development Direction

Every implementation slice must cover the complete loop:

```text
Partner Entry
Save and Resume
Admin View
Admin-Assisted Update
Backend Authorization
KYC or Verification Impact
Agreement and Commercial Impact
Reason Codes and Audit
Partner and Customer Communication
Regression Test
```

Development discipline:

```text
Confirm Git checkpoint
Make one small change
Format
Analyze against known baseline
Check diff
Test lifecycle and negative permissions
Commit and push
Update SuiSakhi_PROJECT_CONTEXT.md after major changes
```

---

## 32. Freeze Checklist

Before freezing v1.0 confirm approval of:

```text
Eight Phase-1 Partner categories
Role and visibility model
Common and category-specific onboarding
Admin-assisted completion
KYC and activation authority
Operational standards
Commercial and metadata governance
Design Catalog governance
Availability and capacity
Assignment acceptance before payment
SLA and delay recovery
Custody, loss and damage
Helpdesk and Chatbot boundaries
Complaint, dispute and rework
Partner direction and fairness
Settlement and audit
Phase-1 scope
```

---

## 33. Final Operating Principle

SuiSakhi shall not transfer avoidable operational complexity to Customers or Partners when that complexity can be handled through standardized metadata, intelligent workflow, Admin assistance, truthful communication, fair governance and auditable recovery.

The Partner ecosystem succeeds only when SuiSakhi can fulfill orders reliably, support Customers transparently, protect physical property, treat capable Partners fairly, and learn from every incident without losing history.

---

**End of SuiSakhi Partner Engagement Architecture v1.0 Final Freeze Candidate**
