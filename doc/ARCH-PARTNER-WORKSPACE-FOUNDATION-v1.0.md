# SuiSakhi Common Partner Workspace Foundation

**Document Version:** v1.0
**Status:** FROZEN FOR IMPLEMENTATION
**Date:** 19 September 2026
**Recommended Repository Path:** `doc/ARCH-PARTNER-WORKSPACE-FOUNDATION-v1.0.md`

---

## 1. Purpose

This document defines one reusable Partner Workspace architecture for all approved SuiSakhi Partner categories.

The Partner Workspace consists of:

```text
1. Common Partner Account
2. Category-Specific Partner Operations
```

This foundation shall be reused by:

```text
Designer
Tailor
Measurement Partner
Garment Care
QuickCare / Doorstep Services
Delivery Partner
Boutique
Brand
Rental
Printing
Fabric Supplier
Future Partner Categories
```

The objective is to give every Partner a simple, consistent, transparent, and actionable experience while preserving category-specific operational workflows.

---

## 2. Core Architecture

```text
Partner Workspace
│
├── Partner Account
│   ├── Profile
│   ├── Business & Finance
│   ├── Performance
│   ├── Communication & Support
│   └── Account
│
└── Partner Operations
    └── Category-Specific Operational Modules
```

The Partner Account area remains common across all Partner categories.

The Partner Operations area varies according to Partner category, approved capabilities, operational status, permissions, and available features.

---

# ARCH-PARTNER-031: Common Partner Workspace

Every approved Partner profile shall use one common Partner Workspace.

The workspace shall contain:

```text
Partner Workspace
├── Common Partner Account
└── Category-Specific Partner Operations
```

All current and future Partner categories shall reuse this foundation rather than building independent profile, account, finance, performance, support, and navigation experiences.

---

## 3. Partner Workspace Structure

```text
Partner Workspace
│
├── Profile
│   ├── My Profile
│   ├── Business Details
│   ├── Addresses
│   ├── Team Members
│   └── Operational Preferences
│
├── Business & Finance
│   ├── Service Requests / Orders
│   ├── Rates & Commercials
│   ├── Payouts
│   └── Statements
│
├── Performance
│   ├── Ratings & Reviews
│   ├── Customer Feedback
│   ├── Performance Summary
│   └── Improvement Insights
│
├── Communication & Support
│   ├── Notifications
│   ├── Help & Support
│   ├── Open Tickets
│   └── Resolved Tickets
│
├── Account
│   ├── Change Profile
│   └── Logout
│
└── Category Operations
```

---

## 4. Common Partner Header

Every Partner Workspace shall display a common governed profile header.

The header should show:

```text
Business Name
Partner Category
Profile Photo / Business Logo
Approval Status
KYC Status
Operational Status
Rating Summary
Profile Completeness
Critical Alerts or Action Required
```

Example:

```text
Naft Design
Designer Partner

Approved
KYC Verified
Operationally Active
```

The header may show category-specific secondary metrics, but the common lifecycle and status presentation must remain consistent across all Partner categories.

---

## 5. Common Partner Account Modules

### 5.1 Profile

```text
My Profile
Business Details
Addresses
Team Members
Operational Preferences
```

The common profile area manages Partner information that applies across categories.

Module visibility may vary by Partner type and approved capabilities.

For example:

```text
Team Members
```

may be hidden for solo operators.

### 5.2 Business & Finance

```text
Service Requests / Orders
Rates & Commercials
Payouts
Statements
```

`Service Requests / Orders` may route to the relevant category-specific operational module rather than functioning as one universal screen.

### 5.3 Performance

```text
Ratings & Reviews
Customer Feedback
Performance Summary
Improvement Insights
```

Performance information must be understandable, transaction-linked, fair, and actionable.

### 5.4 Communication & Support

```text
Notifications
Help & Support
Open Tickets
Resolved Tickets
```

The support module shall use centrally managed statuses, message codes, reason codes, and audit history.

### 5.5 Account

```text
Change Profile
Logout
```

`Change Profile` remains part of the common account area because one SuiSakhi account may contain a Customer profile and multiple approved Partner profiles.

---

# ARCH-PARTNER-032: Financial Transparency

Every Partner shall receive transparent, traceable, and auditable financial information.

## 6. Payout Overview

The common Payout module should display:

```text
Available Balance
Pending Payout
Next Payout Date
Completed Payouts
Adjustments
Deductions
Settlement Method
Download Statement
```

## 6.1 Transaction Breakdown

Every Partner financial transaction should display:

```text
Gross Service Amount
SuiSakhi Commission
Taxes and Statutory Deductions
Refunds or Penalties
Manual Adjustments with Governed Reason
Net Payable Amount
Expected Payout Date
Payment Status
Settlement Reference
Linked Order or Service Request
```

## 6.2 Payout Lifecycle

```text
Accrued
→ Under Validation
→ Approved
→ Scheduled
→ Paid
```

Supported exception states:

```text
On Hold
Disputed
Adjusted
Failed
Reprocessed
```

Every hold, deduction, adjustment, failure, or reprocessing action must display:

```text
Standardized Reason
Amount
Effective Date
Expected Resolution Date
Audit Reference
Related Order or Service Request
```

---

# ARCH-PARTNER-033: Ratings, Feedback, and Improvement

Partner ratings and feedback shall be:

```text
Transaction-Linked
Auditable
Category-Relevant
Actionable
Fair and Governed
```

Partners should be able to view:

```text
Current Rating
Number of Completed Jobs
Rating Trend
Positive Feedback
Improvement Areas
Open Complaints
Resolved Complaints
Recommended Actions
```

Category-relevant rating dimensions may include:

```text
Quality
Timeliness
Communication
Professional Conduct
Measurement Accuracy
Fit Satisfaction
Packaging and Handling
Pickup and Delivery Experience
Issue Resolution
```

## 7.1 Improvement Guidance

The platform should connect feedback to a concrete improvement action.

Example:

```text
Observation:
Several recent jobs exceeded the promised completion date.

Recommended Action:
Reduce daily capacity or block unavailable dates.

Related Setting:
Operational Preferences → Capacity Management
```

## 7.2 Fairness and Disputes

```text
Ratings must link to completed orders or service requests.
Duplicate ratings for the same transaction must be prevented.
Disputed feedback remains visible with Under Review status.
Audit history must be preserved.
Partners may submit a governed professional response.
One isolated extreme rating must not immediately change Partner eligibility.
```

Any operational impact should follow:

```text
Feedback Received
→ Pattern Detected
→ Partner Notified
→ Correction Opportunity
→ Admin Review, When Required
→ Governed Outcome
```

No opaque penalty, payout hold, profile suspension, or capability restriction shall occur without notification, reason, correction opportunity, and governed review.

---

# ARCH-PARTNER-034: Service Request Foundation

`Service Request` is the common operational request concept where applicable.

Each category may use category-appropriate terminology and subordinate queues without forcing all Partner types into one identical workflow.

## 8.1 Tailor

```text
Service Requests / Orders
→ Acceptance Queue
→ Assigned Orders
→ Active Orders
→ Completed Orders
```

## 8.2 Garment Care

```text
Service Requests
→ Pickup Queue
→ Washing / Processing Queue
→ Quality Check
→ Delivery Queue
→ Completed Orders
```

## 8.3 QuickCare

```text
Service Requests
→ Assigned Requests
→ Today's Requests
→ In Progress
→ Completed Requests
```

## 8.4 Delivery Partner

```text
Service Requests / Deliveries
→ Pickup Queue
→ Assigned Deliveries
→ In Transit
→ Delivery Queue
→ Completed Deliveries
```

## 8.5 Measurement Partner

```text
Measurement Requests
→ Assigned Visits
→ Today's Visits
→ Video Measurement Sessions
→ Home-Visit Measurements
→ Completed Measurements
```

## 8.6 Designer

```text
Catalogue Contributions
→ Draft
→ Ready for Review
→ Changes Requested
→ Approved
→ Published
→ Rejected
```

---

# ARCH-PARTNER-035: Metadata-Driven Partner Workspace

Partner Workspace navigation shall be generated through one centrally managed module registry.

The registry may evaluate:

```text
Partner Category
Approved Capabilities
Lifecycle Status
Operational Status
Permissions
Feature Availability
Feature Flags
```

The registry controls presentation and routing attributes such as:

```text
Module Code
Label
Section
Icon
Route
Display Order
Category Applicability
Capability Requirement
Lifecycle Visibility
Status Badge Source
Permission Requirement
Feature Flag
```

The module registry controls presentation and navigation only.

Authorization remains governed by:

```text
Services
Business Rules
Lifecycle Validators
Firestore Rules
Storage Rules
Admin Governance
```

A visible module must not be treated as proof of authorization.

---

# ARCH-PARTNER-036: Rates & Commercials Foundation

`Rates & Commercials` shall be the common navigation entry for every Partner category.

The actual rate behavior shall be determined by:

```text
Partner Category
Commercial Model
Approved Capabilities
Admin Governance Policy
Service or Product Type
```

The common module may operate in one of these modes:

```text
1. View Only
2. Request Changes
3. Propose New Rates
4. Partner-Maintained Pricing Subject to SuiSakhi Rules
```

## 9.1 Tailor

The Tailor module may present a `Rate Card` under the common `Rates & Commercials` entry.

The Partner may:

```text
View Current Approved Rates
Request Rate Modification
Propose New Service Rates
View Pending Approval Requests
View Rate History
```

Governed lifecycle:

```text
Partner Proposal
→ Admin Review
→ Approved
→ Active Rate Card
```

The currently approved Rate Card remains active until Admin approves the proposed replacement.

## 9.2 Designer

The Designer module may present:

```text
Expected Design Price
Approved Design Charge
Royalty Rules
Commercial History
Pending Commercial Requests
```

Governed lifecycle:

```text
Designer Proposal
→ Admin Review
→ Approved
→ Active Commercial Rule
```

The Designer may propose or maintain permitted pricing information, while the Admin-approved charge remains governed by SuiSakhi.

## 9.3 Boutique

```text
Product Pricing
Customization Charges
Design Charges
Commercial Rules
```

Partner-maintained pricing may be supported subject to SuiSakhi commercial rules and Admin governance.

## 9.4 Brand

```text
Collection Pricing
Brand Commercial Policies
Approved Charges
Royalty or Revenue Sharing Rules
```

## 9.5 Rental

```text
Rental Charges
Security Deposit Rules
Late Return Charges
Damage Charges
Commercial History
```

## 9.6 Printing

```text
Printing Rate Card
Material Charges
Quantity Slabs
Customization Charges
Commercial Terms
```

## 9.7 Garment Care

Garment Care rates may be centrally governed and view-only to the Partner.

Example:

```text
Wash & Fold
Steam Iron
Dry Cleaning
Stain Removal
```

The Partner may view:

```text
Current Rate
Effective Date
Applicable Service Area
Commercial Policy
Rate History
```

Direct Partner edits may be disabled.

## 9.8 Delivery Partner

Delivery rates will normally be:

```text
View Only
```

unless a future commercial policy supports Partner proposals.

Possible components:

```text
Pickup Fee
Distance Slabs
Weight Slabs
Delivery Incentive
Special Handling Charge
```

## 9.9 Measurement Partner

The Measurement Partner commercial mode may be:

```text
View Only
```

or:

```text
Request Rate Change
```

depending on future business decisions.

## 9.10 Frozen Commercial Rule

`Rates & Commercials` is the common entry point, while the actual rate behavior is category- and commercial-model-specific.

The common UI must not assume that every Partner can directly edit rates.

---

## 10. Category-Specific Partner Operations

### 10.1 Designer Operations

```text
My Catalogue Designs
Upload Design
Draft
Ready for Review
Changes Requested
Approved
Published
Rejected
Catalogue Performance, Later
```

### 10.2 Tailor Operations

```text
Service Requests / Orders
Acceptance Queue
Assigned Orders
Active Orders
Completed Orders
Rate Card
Capacity Management
Measurement Preferences
Measurement Coordination
QR Tracking
Quality Checklist
Garment DNA
Post-Stitch Reports
```

### 10.3 Measurement Partner Operations

```text
Measurement Requests
Assigned Visits
Today's Visits
Video Measurement Sessions
Home-Visit Measurements
Completed Measurements
Availability
Service Area
```

### 10.4 Garment Care Operations

```text
Service Requests
Pickup Queue
Washing / Processing Queue
Quality Check
Delivery Queue
Completed Orders
Rates & Commercials
Capacity Management
```

### 10.5 QuickCare Operations

```text
Service Requests
Assigned Requests
Today's Requests
In Progress
Completed Requests
Availability
Service Radius
```

### 10.6 Delivery Partner Operations

```text
Service Requests / Deliveries
Pickup Queue
Assigned Deliveries
In Transit
Delivery Queue
Completed Deliveries
Availability
Service Area
```

### 10.7 Boutique Operations

```text
Service Requests / Orders
Catalogue
Custom Orders
Assigned Orders
Active Orders
Completed Orders
Rates & Commercials
Capacity
```

### 10.8 Brand Operations

```text
Catalogue
Licensed Collections
Commercial Terms
Orders
Inventory Linkage, Later
Performance
```

### 10.9 Rental Operations

```text
Rental Requests
Availability Calendar
Reservations
Dispatch Queue
Return Queue
Inspection
Cleaning / Maintenance
Completed Rentals
Rates & Commercials
```

---

## 11. Module Visibility and Capability Rules

The common architecture does not require every Partner to see every module.

Examples:

```text
Team Members
→ May be hidden for solo operators.

Rates & Commercials
→ May be view-only or hidden when centrally governed.

Addresses
→ May display Business Address, Service Locations, or Pickup Points.

Payouts
→ May display category-specific earnings components.
```

Module visibility shall be determined by:

```text
Partner Category
Approved Capabilities
Operational Status
Commercial Model
Feature Availability
Permissions
Lifecycle Status
```

---

## 12. Reusable UI Component Model

The common implementation should provide reusable components such as:

```text
PartnerWorkspaceScreen
PartnerWorkspaceHeader
PartnerStatusBanner
PartnerWorkspaceSection
PartnerWorkspaceMenuTile
PartnerWorkspaceModuleRegistry
PartnerAccountScreen
PartnerFinancialSummaryCard
PartnerPerformanceSummaryCard
PartnerSupportSummaryCard
```

Category-specific business logic shall remain in separate operational modules, for example:

```text
DesignerCatalogueScreen
TailorOperationsScreen
MeasurementPartnerOperationsScreen
GarmentCareOperationsScreen
DeliveryOperationsScreen
```

The common workspace routes to category modules and must not contain their business logic.

---

## 13. Navigation Rule

The standard Partner navigation shall be:

```text
Select Profile
→ Resolve Active Partner Profile
→ Partner Workspace
→ Partner Operations
```

Every Partner operational screen shall provide a consistent upper-right Partner Account icon.

The icon shall open the common Partner Account area and provide access to:

```text
My Profile
Business Details
Addresses
Team Members
Operational Preferences
Rates & Commercials
Payouts
Statements
Ratings & Reviews
Notifications
Help & Support
Change Profile
Logout
```

Successful child-screen actions should return to the existing Partner Workspace or operational screen stack instead of rebuilding the destination through stack-replacing navigation.

---

## 14. Approved Partner Profile Change Rule

Approved Partner profiles may edit permitted operational information, including:

```text
Business Details
Capabilities
Availability
Addresses
Capacity
Fulfillment Information
Team Information
Operational Preferences
Service Areas
```

These edits must not directly overwrite governed production data.

Required lifecycle:

```text
Approved Profile
→ Partner Proposes Changes
→ Controlled Change Request / New Version
→ Admin Review
→ Approve / Request Corrections / Reject
→ Approved Replacement Becomes Active
```

The currently approved profile version remains active until Admin approves the replacement.

The following fields remain immutable or Admin-governed:

```text
Account Ownership
Partner Category
KYC Identity
Approval Linkage
Source Application
Approved Partner Profile ID
Admin Decision History
```

---

## 15. Roles and Permissions

### 15.1 Partner

May:

```text
View own Partner Account and Partner Operations
Edit permitted fields through governed change flow
View payouts and statements
View ratings and feedback
Manage operational preferences
Use support and notifications
Switch profiles
Logout
```

Must not:

```text
Approve own profile
Modify KYC identity or ownership
View another Partner's private data
Modify governed payout history
Modify governed rating history
Bypass Admin approval
```

### 15.2 Admin

May:

```text
Review Partner profile changes
Govern rates and commercials
Govern payouts, holds, disputes, and adjustments
Review feedback disputes
Manage support escalations
View Partner 360-degree operational context
Approve, reject, or request corrections
```

Must not:

```text
Delete governed audit history
Create opaque adjustments without reason
Bypass standardized reason and message codes
```

### 15.3 Customer

May interact through supported:

```text
Orders
Service Requests
Ratings
Reviews
Support
```

Must not access:

```text
Partner Payouts
Partner Statements
Team Information
Private Operational Preferences
Partner Governance Data
```

---

## 16. Status and Banner Standardization

Common Partner Workspace and category modules shall use consistent lifecycle banners and governed messages.

Examples:

```text
Approved
Operationally Active
Changes Requested
Suspended
On Hold
Rejected
Payout On Hold
Rating Under Review
Compliance Action Required
```

Requirements:

```text
Admin comments must be visible where corrections are required.
Final rejection reasons must be visible.
Payout holds and deductions must show standardized reason codes.
Feedback disputes must retain history and show Under Review status.
Critical notices must appear at workspace and module level when relevant.
```

---

## 17. Development Sequence

### Phase P1: Common Partner Workspace Shell

```text
Reusable Partner Workspace Screen
Common Header and Status Banner
Common Sections and Menu Tiles
Module Registry
Change Profile
Logout
Designer Catalogue Integration
Right-Upper Partner Account Navigation
```

### Phase P2: Common Profile Modules

```text
My Profile
Business Details
Addresses
Team Members
Operational Preferences
Approved-Profile Change-Review Handling
```

### Phase P3: Finance, Performance, and Support

```text
Payout Overview
Statements
Rates & Commercials Foundation
Ratings & Reviews
Customer Feedback
Notifications
Helpdesk
```

### Phase P4: Tailor Operations

```text
Order Acceptance and Queues
Assigned and Active Orders
Measurements and Coordination
Rate Card and Capacity
Quality Checklist
QR Tracking
Garment DNA and Post-Stitch Reports
```

### Phase P5: Additional Partner Operations

```text
Measurement Partner
Garment Care
QuickCare
Delivery Partner
Boutique
Brand
Rental
Printing
Other Future Categories
```

---

## 18. Definition of Done for Phase P1

```text
Approved Designer profile opens Partner Workspace.
Partner Workspace displays accurate profile and status information.
Designer Operations opens My Catalogue Designs.
Right-upper Partner Account icon opens the common account area.
Change Profile works.
Logout works.
Module registry shows only relevant modules.
Invalid or unauthorized modules remain inaccessible.
Partner cannot access another Partner profile's private information.
Current Designer Catalogue and Admin governance flows remain unaffected.
Flutter analyzer reports no issues.
Navigation regression tests pass.
Architecture and project-context documents are updated and committed.
```

---

## 19. Implementation Principles

```text
Common where the business concept is common.
Category-specific where operational behavior differs.
Metadata-driven for presentation and routing.
Service- and rule-driven for authorization.
Versioned and audited for governed changes.
Transparent for finance, performance, and feedback.
Simple for Partners to understand and operate.
Reusable for all future Partner categories.
```

---

## 20. Final Freeze Statement

This document is the frozen architecture for the SuiSakhi Common Partner Workspace Foundation.

All approved Partner categories shall reuse this foundation rather than building independent profile, account, finance, performance, support, and navigation experiences.

Approved Partner categories shall share:

```text
Profile
Business & Finance
Performance
Communication & Support
Account
```

Only category-specific operational modules and commercial behavior shall vary.

`Rates & Commercials` is the common navigation entry, while the actual rate behavior is category- and commercial-model-specific.

**Status: FROZEN FOR IMPLEMENTATION** ✅

---

## 21. Recommended Next Step

Implement only Phase P1 first:

```text
Common Partner Workspace Shell
→ Common Header and Status
→ Module Registry
→ Partner Account Navigation
→ Change Profile and Logout
→ Connect Existing Designer Catalogue
```

After Phase P1 is stable, begin Tailor Operations using the same workspace foundation.
