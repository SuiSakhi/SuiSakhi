# SuiSakhi Master Architecture v8.2 Delta
## Metadata Foundation, Governance, Approval Framework & Super Admin Architecture

Version: 8.2 Draft  
Status: Review Draft  
Baseline: v8.1 Delta  
Created By: Architecture Review  
Purpose: Governance, Metadata Standardization, Approval Foundation, Super Admin Controls

---

# 1. Purpose

This delta extends the v8.1 architecture and introduces:

- Metadata Management Foundation
- Standardized Reason Codes
- Standardized Notification Templates
- Approval Governance Framework
- Super Admin Architecture
- Super Admin Direct Partner Registration
- Partner Source Tracking
- Enhanced Audit Requirements
- Commercial Metadata Foundation
- Helpdesk Metadata Foundation

---

# 2. Metadata Management Foundation

## AD-8.2-001

Metadata becomes a first-class platform capability.

All reusable operational configurations should be centrally managed.

Examples:

- Design Metadata
- Occasion Metadata
- Fabric Metadata
- Measurement Metadata
- Partner Metadata
- Commercial Metadata
- Helpdesk Metadata
- Notification Metadata

---

# 3. Catalog & Metadata Domain

## New Admin Module

Catalog & Metadata

### Design Metadata

- Design Categories
- Design Tags
- Design Attributes
- Seasonal Designs

### Occasion Metadata

- Wedding
- Party
- Festival
- Casual
- Office
- School

### Fabric Metadata

- Cotton
- Silk
- Chiffon
- Georgette
- Linen
- Blended Fabrics

### Garment Metadata

- Kurti
- Blouse
- Dress
- Gown
- Lehenga
- Saree Services

### Measurement Metadata

- Standard Measurements
- Measurement Validation Rules
- Measurement Templates

---

# 4. Standardized Reason Code Foundation

## AD-8.2-002

All reusable reasons must be centrally managed.

Operational records should store:

reasonCode
messageSnapshot

Reason codes support:

- Analytics
- Localization
- Standardization
- Auditing

---

# 5. Partner Rejection Reasons

Suggested Codes:

workshop_verification_failed
service_area_not_supported
documents_invalid
duplicate_business
unsupported_service_category
kyc_failed
mandatory_information_missing
commercial_requirements_not_met
other

---

# 6. Partner Change Request Reasons

Suggested Codes:

workshop_address_required
service_area_required
capacity_details_required
quality_policy_required
expected_rates_required
kyc_documents_required
business_name_correction_required
contact_information_correction_required
other

---

# 7. KYC Failure Reasons

Suggested Codes:

identity_document_invalid
identity_document_expired
identity_mismatch
address_not_verified
business_verification_failed
duplicate_identity
other

---

# 8. Notification Template Metadata

## AD-8.2-003

Notification content should be template-driven.

Examples:

partner_application_submitted
partner_review_started
partner_changes_requested
partner_rejected
partner_approved

kyc_under_verification
kyc_verified
kyc_failed

partner_suspended
partner_reactivated

Each template should contain:

Notification Title
Message Body
Severity
Supported Channels
Active Flag
Version

---

# 9. Notification Delivery Channels

## Channel Policy

Normal Lifecycle Updates

In-App

Action Required

In-App
WhatsApp

Approval / Rejection

In-App
WhatsApp
Email

Critical Events

In-App
WhatsApp
Email
Optional SMS

---

# 10. Super Admin Architecture

## AD-8.2-004

Admin and Super Admin responsibilities must be separated.

### Current Phase

Admin = Super Admin Login

### Future Phase

Separate role management.

---

# 11. User Types

Super Admin

Admin

Partner Operations User

Verification User

Commercial User

Helpdesk User

---

# 12. Super Admin Privileges

Only Super Admin may:

Direct Partner Registration

Force Partner Approval

Suspend Partner

Reactivate Partner

Override Operational Restrictions

Create System Configurations

Manage Admin Users

---

# 13. Admin Privileges

Admin may:

Review Applications

Request Changes

Perform KYC Verification

Verify Onboarding Sections

Reject Applications

Manage Partner Operations

Admin may NOT:

Bypass Partner Approval Workflow

Directly Activate Partner Profiles

Create Super Admins

---

# 14. Super Admin Direct Registration

## AD-8.2-005

Super Admin may directly register known and trusted partners.

Examples:

Pilot Participants

Known Tailors

Known Designers

Known Boutique Owners

Known Service Providers

Strategic Partners

---

# 15. Direct Registration Flow

Super Admin
→ Direct Partner Registration
→ Active Partner Profile

Partner Application workflow is optional in this path.

---

# 16. Direct Registration Audit

Even when bypassing applications:

Required Records:

Partner Profile

Commercial Configuration

KYC Status

Partner Source

Approval Record

Audit Record

No special partner schema may exist.

---

# 17. Onboarding Methods

New Field:

onboardingMethod

Values:

customerApplication

adminSponsored

superAdminDirect

---

# 18. Partner Source Tracking

New Field:

partnerSource

Examples:

customerReferral

partnerReferral

knownPartner

pilotParticipant

fieldVisit

advertisement

campaign

organic

adminAcquired

Supports future analytics.

---

# 19. Approval Governance Framework

## AD-8.2-006

Partner Approval becomes rule-based.

Approve button must remain disabled until:

Status = Under Review

KYC = Verified

Mandatory Sections = Verified

Commercial Terms = Accepted

Declaration = Accepted

---

# 20. Approval Transaction

Approval must:

Validate Approval Conditions

Create Partner Profile

Link Application

Save approvedPartnerProfileId

Create Audit Record

Create Notifications

Activate Partner Profile

---

# 21. Commercial Metadata Foundation

Metadata should drive:

Rate Rules

Commission Rules

Partner Rates

Platform Fees

Discount Rules

Payout Rules

Incentive Rules

Penalty Rules

---

# 22. Helpdesk Metadata Foundation

Metadata should manage:

Ticket Categories

Priority Codes

Escalation Reasons

Resolution Reasons

Closure Reasons

Priority Levels:

Critical

High

Medium

Low

---

# 23. Audit Enhancements

Every major action must record:

eventCode

reasonCode

messageSnapshot

actorUid

actorType

entityId

timestamp

---

# 24. Future Metadata Collections

Suggested Collections:

metadata_reason_codes

metadata_notification_templates

metadata_rate_rules

metadata_discount_rules

metadata_helpdesk

metadata_partner_certifications

metadata_service_areas

metadata_partner_categories

---

# 25. Business Rules

## BR-8.2-001

Only Super Admin may bypass Partner Application workflow.

## BR-8.2-002

Admin users cannot bypass Partner Approval workflow.

## BR-8.2-003

Directly registered Partners must use the same profile schema.

## BR-8.2-004

Partner onboarding path must be tracked.

## BR-8.2-005

Reason codes must be standardized.

## BR-8.2-006

Notification templates must be metadata-driven.

## BR-8.2-007

Operational records must store reasonCode and messageSnapshot.

## BR-8.2-008

Metadata must support localization.

## BR-8.2-009

Approval eligibility must be rule-driven.

## BR-8.2-010

Partner source tracking must be captured.

---

# 26. Deferred Items

Future Releases:

Partner Certification Engine

Advanced Analytics

Revenue Intelligence

Campaign Engine

Partner Scoring

Auto Assignment Engine

Franchise Operations

Regional Admin Framework

---

# Review Notes

This document intentionally focuses on governance,
metadata centralization,
approval eligibility,
direct registration,
and future operational scale.

No implementation should begin before this document
is reviewed and approved.
