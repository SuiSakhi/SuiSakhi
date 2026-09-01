# SuiSakhi Master Architecture v8.2 Delta

## Metadata-Driven Multi-Partner Foundation, Governance, Approval, Activation, Super Admin, and Commercial Architecture

**Version:** 8.2 Consolidated Review Draft  
**Baseline:** SuiSakhi Master Architecture v8.1 Delta  
**Date:** 27 August 2026  
**Status:** Architecture Review Draft  
**Primary Scope:** Metadata, multi-partner onboarding, Super Admin governance, approval and activation separation, commercial readiness, and scalable Partner operations

---

## 1. Purpose

This document consolidates all SuiSakhi v8.2 architecture decisions and extends the v8.1 Partner Management foundation.

The v8.2 delta establishes:

- Metadata as a first-class platform capability
- A common Core Partner Foundation applicable to all Partner categories
- Partner-type extensions for Tailor, Measurement, Designer, Fabric, Delivery, Boutique, Printing, Embroidery, Rental, Laundry, and future Partners
- Support for one Partner profile containing multiple Partner categories
- Support for one Customer engaging with multiple Partner types during a single service journey
- Standardized reason codes, messages, templates, rates, policies, and operational metadata
- Separate Super Admin, Admin, verification, commercial, Partner Operations, and Helpdesk permissions
- A governed Super Admin direct-registration path
- Separation of Partner approval from Partner activation
- Metadata-driven Partner plans, tiers, joining fees, deposits, commissions, subscriptions, and settlement rules
- A pilot policy of zero Partner joining fee
- A future refundable Partner security-deposit framework

The architecture must remain reusable across all current and future Partner services.

---

## 2. Guiding Principles

### 2.1 One common Partner foundation

All Partner types must use one common foundation for:

```text
Identity
Business Profile
Service Area
Capacity
Quality
Commercial Setup
Documents
Compliance
KYC
Audit
Approval
Activation
Notifications
Suspension and Reactivation
```

### 2.2 Partner-type extensions

Partner-specific requirements must be added as extensions to the common foundation, not as separate disconnected onboarding systems.

### 2.3 Metadata over hardcoding

Reusable sections, fields, categories, reason codes, notification templates, pricing rules, discounts, commissions, compliance rules, and workflow definitions should be centrally managed through metadata wherever practical.

### 2.4 Application, approval, profile, and activation are separate

```text
Application saved
!= Application approved
!= Partner profile created
!= Partner activated
!= Partner eligible for orders
```

### 2.5 Code plus snapshot

Operational transactions should store both:

```text
standardizedCode
messageSnapshot
```

The code supports reporting, analytics, localization, and policy management. The snapshot preserves the exact wording used at the time of the decision.

---

## 3. SuiSakhi Marketplace Relationship Model

### 3.1 One Customer can engage multiple Partners

A Customer journey may involve multiple Partner relationships:

```text
Customer
  -> Measurement Partner
  -> Designer Partner
  -> Fabric Partner
  -> Tailor Partner
  -> Embroidery or Printing Partner
  -> Delivery Partner
```

Partner engagement must be order-, service-, assignment-, and profile-aware.

### 3.2 One Partner can provide multiple Partner categories

A single Partner profile may support more than one Partner category.

Examples:

```text
Tailor + Measurement Partner
Tailor + Boutique
Designer + Tailor
Designer + Boutique
Fabric Partner + Delivery Partner
Tailor + Embroidery Partner
```

The system should maintain:

```text
One Partner Profile
One Compliance Record
One Commercial Relationship
One Audit History
Multiple Partner Categories
Multiple Capabilities
```

---

## 4. Core Partner Foundation

Every Partner must complete the following common foundation.

```text
1. Basic Verification
2. Business Profile
3. Service Area
4. Operational Capacity
5. Quality Standards
6. Commercial Setup
7. Declaration
8. Documents
9. Compliance
```

These sections apply to all Partner types, subject to metadata-driven applicability rules.

---

## 5. Basic Verification

Suggested common fields:

```text
Partner Category
Partner Subcategory
Full Name
Business or Shop Name
Authenticated Mobile Number
Alternate Mobile Number
Email Address
Primary Contact Person
Emergency Contact
Preferred Language
Identity Verification Status
Account ID
Customer Profile ID
```

Requirements should be configurable by Partner category and onboarding method.

---

## 6. Business Profile

Suggested common fields:

```text
Business Type
Year Established
Years of Experience
Business Registration Number
GST Number, where applicable
PAN, where applicable
Website
Social Media Links
Google Map Location
Home-Based or Commercial Operation
Operating Days
Opening Time
Closing Time
Weekly Holidays
```

Supported business types should be centrally managed:

```text
Individual
Proprietorship
Partnership
LLP
Private Limited
Cooperative
Self-Help Group
Other
```

---

## 7. Service Area

Service coverage is a first-class Partner capability.

Suggested fields:

```text
Primary City
Primary Pincode
Coverage Cities
Coverage Pincodes
Maximum Travel Radius
Maximum Pickup Radius
Maximum Delivery Radius
Pickup Available
Delivery Available
Doorstep Service Available
Home Visit Available
Video Consultation Available
Remote Service Available
Service Pause Dates
Peak-Season Constraints
```

Service-area metadata should support hierarchy:

```text
Country
State
District
City
Locality
Pincode
Geo Coordinates
Service Radius
```

A Partner must receive only orders compatible with approved service areas and capabilities.

---

## 8. Operational Capacity

Suggested common fields:

```text
Team Size
Role-Wise Team Composition
Normal Daily Capacity
Normal Weekly Capacity
Peak Daily Capacity
Peak Weekly Capacity
Maximum Simultaneous Orders
Current Backlog
Average SLA
Seasonal Workforce Available
Seasonal Capacity Increase Percentage
Specialized Team Available
Emergency or Express Capacity
Service Pause Capability
```

Capacity must support load balancing and assignment decisions.

---

## 9. Quality Standards

Suggested common fields:

```text
Quality Checklist Available
Inspection Process
Quality Inspector Available
Final Review Process
Trial Policy
Rework Policy
Defect Escalation Process
Customer Complaint Resolution Process
Damage Handling Policy
Loss Handling Agreement
Delivery Checklist
Evidence Requirements
Quality Certification
```

Quality controls should become metadata-driven and applicable by Partner category and service type.

---

## 10. Commercial Setup

Suggested common fields:

```text
Rate Card
Normal Rates
Peak Rates
Express Rates
Partner Expected Rates
Agreed Partner Rates
Platform Commission
Discount Participation
Coupon Participation
Settlement Frequency
Minimum Payout Threshold
Preferred Payment Mode
Bank Details
UPI Details
GST Applicability
TDS Applicability
Invoice Availability
Penalty Rules
Incentive Rules
Rework Cost Rules
```

The following values must remain separate:

```text
Partner Expected Rate
Agreed Partner Cost
Customer Selling Price
Platform Fee
Platform Margin or Commission
Taxes
Incentives
Penalties
Discount Funding Source
```

---

## 11. Declaration

Suggested declarations:

```text
Platform Terms Accepted
Privacy Policy Accepted
Quality Policy Accepted
Customer Commitment Accepted
SLA Accepted
Rework Policy Accepted
Loss and Damage Policy Accepted
Commercial Terms Accepted
Data Processing Consent Accepted
Truthfulness Declaration Accepted
```

Each declaration should record:

```text
version
acceptedByUid
acceptedAt
source
messageSnapshot
```

---

## 12. Documents

Suggested document domains:

```text
Identity Documents
Address Proof
Business Registration Documents
GST Documents
PAN Documents
Bank Documents
Cancelled Cheque
Workshop or Business Photographs
Certifications
Rate Cards
Insurance Documents
Vehicle Documents
Service-Specific Evidence
```

Document requirements must be metadata-driven by Partner category, business type, geography, plan, and risk level.

---

## 13. Compliance

Suggested compliance controls:

```text
KYC Compliance
Identity Compliance
Business Compliance
Tax Compliance
Platform Compliance
Data Privacy Compliance
Service-Specific Compliance
Commercial Compliance
Safety Compliance
Periodic Renewal Compliance
```

Compliance status should not be inferred only from uploaded documents. Verification decisions must be explicit and audited.

---

## 14. Partner-Type Extensions

Partner-specific onboarding requirements are extensions to the Core Partner Foundation.

### 14.1 Tailor Extension

```text
Workshop Details
Measurement Standards
Garment Categories
Women and Girls Specialization
Bridal Capability
Wedding and Family Packages
Machine Capability
Fabric Expertise
Designer Replication Capability
Old Saree or Old Dress Conversion
Trial Support
Production Capacity
Seasonal Capacity
Delivery Checklist
Tailor Certification Tier
```

### 14.2 Measurement Partner Extension

```text
Body Measurement Expertise
Home Visit Capability
Video Measurement Capability
Old Dress Reference Capability
Measurement Devices Used
Measurement Certification
Photo Consent Process
Measurement Verification Process
Re-Measurement Support
Coverage Radius
Travel Availability
```

### 14.3 Designer Extension

```text
Original Design Creation
Custom Design Creation
Occasion Consultation
Fabric Consultation
Design Licensing
Design Ownership Declaration
AI-Assisted Design Support
Portfolio Evidence
Premium or Bridal Design Capability
```

### 14.4 Fabric Partner Extension

```text
Fabric Categories
Inventory Availability
Minimum Order Quantity
Sample Swatches
Fabric Certification
Fabric Width and GSM Information
Return Policy
Delivery SLA
Logistics Support
Seasonal Inventory
```

### 14.5 Delivery Partner Extension

```text
Vehicle Types
Coverage Area
Pickup Capacity
Delivery Capacity
Order Tracking
Customer OTP Delivery
Reverse Pickup
COD Support
Insurance
Delivery SLA
Proof of Delivery
```

### 14.6 Boutique Extension

```text
Ready-Made Categories
Custom Stitching
Designer Services
Trial Facility
Inventory
Premium Services
In-Store Pickup
Home Consultation
```

### 14.7 Printing and Embroidery Extensions

```text
Supported Techniques
Machine Capability
Minimum Quantity
Sample Approval Process
Material Restrictions
Turnaround Time
Quality Evidence
Design File Requirements
```

### 14.8 Rental and Laundry Extensions

Future extensions may include:

```text
Inventory or Garment Condition
Deposit Rules
Cleaning Standards
Hygiene Standards
Damage Rules
Return SLA
Pickup and Delivery
Inspection Evidence
```

---

## 15. Tailor Checklist Mapping

The existing Tailor checklist maps into the Partner architecture as follows.

### Basic Verification

```text
Full name or shop name
Mobile and alternate number
Address
Area and location
Workshop photographs
Years of experience
GST, where applicable
Number of staff
Shop hours
Shop holidays
```

### Operational Capacity

```text
Daily pieces capacity
Weekly bridal-order capacity
Master Tailors
Helpers
Finishers
Additional seasonal Tailors
Separate wedding or special-order team
```

### Measurement Standards

```text
Trained measurer accepted
Standardized measurement sheet accepted
Sample measurement sheet
Video verification accepted
QC re-measurement accepted
Old dress or blouse measurement accepted
Final Tailor verification
Post-completion variation handling
Doorstep measurement available
Pre-delivery checklist
```

### Services and Specialization

```text
Blouse Stitching
Saree Pico and Fall
Alterations
Old Saree Conversion
Kurti and Suit
Lehenga
Bridal Wear
Aari and Zardozi
Embroidery
Designer Replication
Wedding Orders
Wedding Family Packages
Event Orders
Girls Frocks
Girls Party Wear
School Uniforms
Fabric Specialization
```

### Quality and Risk

```text
SLA Miss Handling
Rework at Partner Cost
SuiSakhi Error Handling
Loss or Damage Handling
Trial Before Delivery
Delivery Commitment
Delay Handling
```

### Commercial Setup

```text
Normal Rates
Peak Rates
Express Rates
Fabric Overheads
Doorstep Measurement Charges
Regular Customer Discounts
Bulk Order Discounts
Special Order Pricing
Off-Season Offers
```

---

## 16. Metadata-Driven Partner Architecture

Partner Foundation and Partner Extension definitions must be metadata-driven and centrally managed.

Metadata should define:

```text
Section Code
Section Label
Description
Partner Categories
Mandatory Flag
Verification Required
Display Order
Field Definitions
Validation Rules
Required Evidence
Reason Codes
Applicable Plans
Effective Dates
Version
Active Flag
```

Suggested metadata collections:

```text
metadata_partner_categories
metadata_partner_subcategories
metadata_partner_business_types
metadata_partner_onboarding_sections
metadata_partner_fields
metadata_partner_capabilities
metadata_partner_service_areas
metadata_partner_compliance_rules
metadata_partner_certifications
metadata_partner_document_types
metadata_partner_plans
```

---

## 17. Standardized Reason and Message Metadata

Reusable reasons and messages must be centrally managed.

Domains include:

```text
Partner Rejection
Partner Change Request
KYC Failure
Partner Suspension
Partner Reactivation
Onboarding Changes Required
Order Cancellation
Order Rework
QC Failure
Payout Hold
Refund
Helpdesk Category
Helpdesk Priority
Escalation
Resolution
Closure
```

Operational records should store:

```text
reasonCode
messageSnapshot
internalAdminNotes
```

Customer-visible messages and internal notes must remain separate.

---

## 18. Notification Template Metadata

Suggested template codes:

```text
partner_application_submitted
partner_review_started
partner_changes_requested
partner_rejected
partner_approved
partner_activated
kyc_under_verification
kyc_verified
kyc_failed
partner_suspended
partner_reactivated
commercial_action_required
```

Each template may define:

```text
templateCode
channel
title
messageBody
severity
actionRoute
localizations
version
active
```

### Channel policy

```text
Normal Lifecycle Update:
In-App

Action Required:
In-App and WhatsApp

Formal Approval or Rejection:
In-App, WhatsApp, and Email

Critical Security, Suspension, or Payout Failure:
In-App, WhatsApp, Email, and Optional SMS
```

External notification failure must never roll back a business decision.

---

## 19. Partner Application Lifecycle

```text
Draft
Submitted
Under Review
Changes Requested
Rejected
Approved
```

Operational Partner Profile statuses are separate:

```text
Pending Activation
Active
Suspended
Inactive
Archived
```

Application status and Partner profile status must not be mixed.

---

## 20. Approval Versus Activation

### Approved

Approval means:

```text
Application approved
KYC verified
Mandatory onboarding verified
Commercial setup completed
Declarations accepted
Partner profile created
```

Approval alone does not make the Partner operational.

### Active

Activation means:

```text
Partner is operational
Partner is visible or selectable where applicable
Partner may receive orders or assignments
Partner may receive payouts
Partner may participate in campaigns
```

Only an Active Partner may receive customer orders, bookings, or assignments.

---

## 21. Enhanced Partner Lifecycle

```text
Application Draft
→ Submitted
→ Under Review
→ Changes Requested or Rejected
→ Approved
→ Partner Profile Created
→ Pending Activation
→ Active
→ Suspended or Inactive
→ Reactivated or Archived
```

Suspension, inactivity, and archival are not application statuses. They are Partner profile lifecycle states.

---

## 22. Partner Onboarding Methods

```text
customerApplication
adminSponsored
superAdminDirect
```

### 22.1 Customer Application

```text
Customer Applies
→ Admin Review
→ KYC
→ Onboarding Verification
→ Commercial Setup
→ Approval
→ Activation
```

### 22.2 Admin-Sponsored Onboarding

```text
Admin Adds or Invites Partner
→ Review Required
→ KYC Required
→ Super Admin or Authorized Approval
→ Activation
```

Admin sponsorship does not bypass governance.

### 22.3 Super Admin Direct Registration

```text
Super Admin Direct Registration
→ Required Minimum Data
→ Audit and Commercial Record
→ Partner Profile Creation
→ Optional Immediate Activation
```

Super Admin direct registration may bypass the normal application workflow, but must not bypass the common final Partner profile, audit, compliance, and commercial architecture.

---

## 23. Super Admin and Admin Architecture

### User types

```text
Super Admin
Admin
Partner Operations User
Verification User
Commercial User
Helpdesk User
Metadata Manager
```

### Super Admin privileges

Only Super Admin may:

```text
Directly Register a Partner
Bypass the Application Workflow
Force Approval with Audit Reason
Activate Partner Profile
Suspend or Reactivate Partner
Override Operational Restrictions
Manage Admin Users
Manage Super Admin Configuration
Manage Platform-Wide Metadata
```

### Admin privileges

Admin may:

```text
Review Applications
Start Review
Request Changes
Reject Applications
Perform KYC Verification
Review Onboarding Sections
Verify Permitted Sections
Manage Partner Operations
```

Admin may not:

```text
Bypass Partner Approval
Directly Activate Partner Profile
Create Super Admins
Override Super Admin Policies
```

Current pilot login may use the same person for Admin and Super Admin, but permissions and architecture must remain logically separate.

---

## 24. Super Admin Direct Registration Governance

Direct onboarding must record:

```text
onboardingMethod: superAdminDirect
createdByUid
createdByRole
approvedByUid
approvedAt
activationByUid
activatedAt
approvalReasonCode
auditEventId
partnerSource
commercialPlanCode
kycStatus
complianceStatus
```

Directly registered Partners must use the same:

```text
Partner Profile Schema
Commercial Schema
Compliance Schema
Audit Schema
Suspension and Reactivation Process
Order Assignment Rules
Notification Foundation
```

---

## 25. Partner Source Tracking

Suggested values:

```text
customerReferral
partnerReferral
knownPartner
pilotParticipant
fieldVisit
advertisement
campaign
organic
adminAcquired
strategicPartner
agencyOnboarded
```

Partner source supports acquisition analytics, quality analysis, and commercial policy evaluation.

---

## 26. Approval Eligibility Framework

Approve remains disabled until all required conditions are true.

```text
Application Status = Under Review
KYC Status = Verified
Mandatory Core Sections = Verified
Required Partner Extensions = Verified
Commercial Terms = Accepted
Declarations = Accepted
Required Documents = Verified
No Unresolved Change Request
No Final Rejection
```

Approval eligibility should be calculated by a rule engine or metadata-driven evaluator, not by manual UI assumptions.

---

## 27. Activation Eligibility Framework

Activation requires:

```text
Application Approved
Partner Profile Created
Commercial Profile Ready
Required Deposit or Fee Status Satisfied
Operational Service Areas Approved
Order Capacity Configured
Payout Details Verified
No Compliance Block
Activation Decision Audited
```

During the pilot, fee and deposit requirements may evaluate to zero or not required.

---

## 28. Partner Commercial Architecture

Commercial controls must be metadata-driven.

Future configurable items:

```text
Joining Fee
Security Deposit
Subscription Fee
Partner Membership Plan
Commission Rules
Platform Fee
Penalty Rules
Incentive Rules
Settlement Rules
Payout Rules
Discount Participation
Campaign Eligibility
```

---

## 29. Pilot and Early Growth Policy

During pilot and early market growth:

```text
Partner Joining Fee = INR 0
```

Objectives:

```text
Remove Onboarding Barriers
Acquire Quality Partners
Build Supply Network
Validate Product-Market Fit
Generate Initial Order Volume
Learn Operational Patterns
```

The zero-fee pilot policy must be metadata-driven and effective-date controlled so it can change without code deployment.

---

## 30. Future Refundable Security Deposit

SuiSakhi may support refundable Partner security deposits after market traction.

Illustrative values only:

```text
Basic Tailor: INR 500
Premium Tailor: INR 2,000
Designer Partner: INR 5,000
Fabric Partner: INR 3,000
```

Refund conditions may include:

```text
No Open Disputes
No Outstanding Liability
No Pending Customer Refund
No Unreturned Material
No Fraud Investigation
Approved Partner Closure
```

Security-deposit amounts and rules must be metadata-driven.

---

## 31. Partner Membership Plans and Tiers

Illustrative tiers:

```text
Basic
Verified
Premium
Professional
Enterprise
```

Plan metadata may define:

```text
Joining Fee
Security Deposit
Monthly Fee
Commission Percentage
Visibility Priority
Campaign Eligibility
Lead Allocation Priority
Settlement Frequency
Premium Features
Support Level
Service Limits
```

Suggested collection:

```text
metadata_partner_plans
```

Example:

```json
{
  "planCode": "tailor_basic",
  "joiningFee": 0,
  "securityDeposit": 500,
  "monthlyFee": 0,
  "platformCommission": 8,
  "active": true
}
```

---

## 32. Partner Commercial Fields

Future Partner profile or commercial-profile fields:

```text
partnerPlanCode
partnerTier
membershipStatus
joiningFeeAmount
joiningFeeStatus
securityDepositAmount
securityDepositStatus
securityDepositPaidAt
securityDepositRefundedAt
commercialProfileStatus
commissionRuleCode
settlementRuleCode
```

One multi-category Partner should normally maintain a single Partner-level commercial relationship, with category- or service-level rate extensions where required.

---

## 33. Professional Admin Domains

### Partner Operations

```text
Partner Applications
Add Partner
Direct Registration for Super Admin
Active Partners
Pending Activation
Suspended Partners
Inactive Partners
Archived Partners
KYC and Verification
Capabilities
Capacity
Service Areas
Performance
Certification
Agreements
Audit History
```

### Order Operations

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

### Catalog and Metadata

```text
Partner Categories
Partner Extensions
Onboarding Sections
Capabilities
Service Areas
Reason Codes
Notification Templates
Rate Rules
Commission Rules
Discount Rules
Certification Levels
Compliance Rules
Helpdesk Metadata
```

### Commercial and Financial

```text
Partner Plans
Joining Fees
Security Deposits
Customer Pricing
Partner Rates
Commission Rules
Partner Ledger
Settlements
Payouts
Refunds
Taxes
Incentives
Penalties
Payout Holds
```

### Governance

```text
Super Admin
Admin Users
Permission Matrix
Approval Policies
Activation Policies
Audit Trail
Metadata Versions
Data Retention
Suspension and Reactivation
Security Controls
```

### Helpdesk

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

---

## 34. Helpdesk Priority and Lifecycle

Priority:

```text
Critical
High
Medium
Low
```

Lifecycle:

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

Helpdesk reasons, categories, priorities, resolution codes, and closure codes must be metadata-driven.

---

## 35. Audit Enhancements

Every material Partner action must record:

```text
eventCode
entityType
entityId
accountId
partnerProfileId
applicationId
previousStatus
newStatus
reasonCode
messageSnapshot
internalNotes
actorUid
actorRole
source
createdAt
metadataVersion
```

Major events include:

```text
application_created
application_submitted
review_started
changes_requested
application_resubmitted
application_rejected
kyc_started
kyc_verified
kyc_failed
onboarding_section_started
onboarding_section_completed
onboarding_section_verified
application_approved
partner_profile_created
partner_activated
partner_suspended
partner_reactivated
partner_inactivated
partner_archived
commercial_plan_changed
security_deposit_received
security_deposit_refunded
```

---

## 36. Business Rules Added in v8.2

### BR-8.2-001
Only Super Admin may bypass the Partner Application workflow.

### BR-8.2-002
Admin users cannot bypass Partner approval or directly activate Partner profiles.

### BR-8.2-003
Directly registered and normally approved Partners use the same final Partner profile schema.

### BR-8.2-004
Every Partner onboarding path must be recorded.

### BR-8.2-005
Reason codes and Customer-visible messages must be standardized wherever practical.

### BR-8.2-006
Notification templates must be metadata-driven.

### BR-8.2-007
Operational records store both standardized code and message snapshot.

### BR-8.2-008
Metadata must support localization, versioning, active dates, and auditability.

### BR-8.2-009
Approval eligibility is rule-driven.

### BR-8.2-010
Partner source must be tracked.

### BR-8.2-011
A Partner profile may belong to one or more Partner categories.

### BR-8.2-012
Partner onboarding structures, capabilities, compliance requirements, and service areas should be metadata-driven.

### BR-8.2-013
Only Active Partners may receive customer orders, assignments, or bookings.

### BR-8.2-014
Partner joining fee is INR 0 during pilot and early market growth.

### BR-8.2-015
SuiSakhi may introduce refundable Partner security deposits in future phases.

### BR-8.2-016
One multi-category Partner maintains one common Partner profile, compliance record, commercial relationship, and audit history.

### BR-8.2-017
One Customer may engage multiple Partner types during one order or service journey.

### BR-8.2-018
Approval and activation are separate business decisions.

### BR-8.2-019
Approved but inactive Partners cannot receive orders or customer assignments.

### BR-8.2-020
Direct Super Admin registration must create full audit, commercial, compliance, and activation records.

### BR-8.2-021
Joining fees, deposits, membership plans, and commission rules must be centrally configurable.

### BR-8.2-022
Customer-visible messages and internal Admin notes must remain separate.

### BR-8.2-023
Partner capabilities and service areas must be verified before order assignment.

### BR-8.2-024
Category-specific extensions are added to, and do not replace, the Core Partner Foundation.

---

## 37. Architecture Decisions Added in v8.2

### AD-8.2-001: Metadata as a Platform Capability
Metadata becomes a first-class capability across Partner, pricing, discount, notification, order, KYC, commercial, governance, and Helpdesk domains.

### AD-8.2-002: Centralized Reusable Rules
Reusable reasons, fields, templates, rates, commissions, discounts, policies, and workflow definitions are centrally managed.

### AD-8.2-003: Super Admin Direct Registration
Super Admin may bypass the standard application workflow under governed conditions.

### AD-8.2-004: Admin Cannot Bypass Approval
Normal Admin roles cannot bypass Partner approval or activation controls.

### AD-8.2-005: Common Final Partner Schema
All Partner onboarding methods produce the same final Partner profile structure.

### AD-8.2-006: Code and Snapshot Storage
Operational decisions store both a standardized code and message snapshot.

### AD-8.2-007: Metadata-Driven Partner Foundation
Core Partner Foundation and Partner Extensions are metadata-driven.

### AD-8.2-008: Approval and Activation Separation
Partner approval and Partner activation are separate auditable events.

### AD-8.2-009: Metadata-Driven Commercial Plans
Partner fees, deposits, plans, tiers, commissions, incentives, penalties, and settlements are metadata-driven.

### AD-8.2-010: Multi-Category Partner Profile
One Partner profile may support multiple Partner categories and capabilities.

### AD-8.2-011: Multi-Partner Customer Journey
One Customer order or service journey may involve multiple assigned Partner profiles.

### AD-8.2-012: Zero-Fee Pilot Policy
Partner joining fee remains INR 0 during pilot and early market growth.

---

## 38. Suggested Implementation Sequence

```text
1. Freeze and Review v8.2
2. Define Partner Foundation Metadata
3. Define Partner Category and Extension Metadata
4. Add Generic onboardingData Foundation
5. Map Existing Tailor Checklist to Metadata
6. Build Workshop Details Data Model
7. Build Applicant Workshop Details Form
8. Display Workshop Data in Admin Review
9. Verify Real Workshop Evidence
10. Generalize Section Lifecycle Across Core Sections
11. Implement Service Area Data and Validation
12. Implement Operational Capacity Data
13. Implement Quality Standards Data
14. Implement Commercial Setup
15. Implement Documents and Declaration
16. Implement Compliance Completion
17. Build Approval Eligibility Evaluator
18. Implement Partner Approval
19. Create Partner Profile
20. Implement Pending Activation
21. Implement Super Admin Activation
22. Enable Active Partner Order Eligibility
23. Add In-App Notifications
24. Queue WhatsApp and Email Notifications
25. Implement Super Admin Direct Registration
26. Introduce Commercial Plan Metadata
```

---

## 39. Deferred Items

The following remain deferred until core onboarding, approval, and activation are stable:

```text
Production External KYC Integration
Advanced Partner Scoring
Automated Partner Allocation
Production WhatsApp Delivery
Production Email Delivery
SMS Gateway
Security Deposit Collection
Subscription Billing
Franchise Operations
Regional Admin Framework
Agency Admin Framework
Automated Certification
Advanced Revenue Analytics
```

---

## 40. Review and Freeze Criteria

v8.2 may be treated as frozen for implementation after confirming:

```text
Core Partner Foundation approved
Partner Extension model approved
Multi-category Partner rule approved
Super Admin direct registration approved
Approval versus Activation separation approved
Zero-fee pilot policy approved
Future security-deposit principle approved
Metadata domains approved
Business rules and architecture decisions reviewed
```

---

## 41. Current Stable Implementation Baseline

The current implemented foundation includes:

```text
Partner Application lifecycle
Canonical Partner Application identity
Admin Partner Applications queue
UID-based Admin authorization
Start Review
Request Changes and Resubmission
Final Rejection
KYC Start, Verified, and Failed Outcomes
Onboarding Section Model
Model-Driven Onboarding Progress
Workshop Details Section Status Lifecycle
```

Current Workshop Details workflow:

```text
Not Started
→ In Progress
→ Completed
→ Verified
```

The next implementation should add real data behind the section status rather than continuing with status-only verification.

---

## 42. Documentation and Recovery Rule

After major changes to Partner metadata, onboarding, approval, activation, Super Admin controls, commercial rules, or Partner profile creation, update:

```text
doc/SuiSakhi_PROJECT_CONTEXT.md
```

and the appropriate session-recovery documentation.

The v8.2 delta must remain synchronized with:

```text
Business Rules
Architecture Decisions
Firestore Schema
Firestore Rules
Admin Permissions
Partner Onboarding UI
Approval and Activation Workflows
Metadata Definitions
Commercial Policies
```

---

## 43. Final Strategic Principle

SuiSakhi must support:

```text
One Customer
→ Multiple Partner Relationships

One Partner
→ Multiple Partner Categories
```

while maintaining:

```text
One Governed Partner Identity
One Reusable Partner Foundation
One Compliance Record
One Commercial Relationship
One Audit History
Metadata-Driven Extensions
```

This architecture allows SuiSakhi to grow from a Tailor platform into a scalable multi-Partner fashion, tailoring, measurement, fabric, delivery, laundry, rental, and lifestyle-services ecosystem without rebuilding onboarding for every new Partner type.

---

**End of SuiSakhi Master Architecture v8.2 Consolidated Delta**
