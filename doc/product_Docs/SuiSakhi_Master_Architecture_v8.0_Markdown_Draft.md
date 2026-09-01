# SuiSakhi Master Architecture v8.0
**Status:** Draft for joint review and gap analysis  
**Date:** 20 August 2026  
**Next proposed focus:** Partner Management Foundation

> This Markdown companion mirrors the review baseline in the DOCX. The DOCX is the formatted master review copy.

## Scope
- Architecture Decisions (AD)
- Business Rules (BR)
- Firestore Schema Changes
- Roadmap Milestones
- Metadata Domain Definitions
- Roles and Governance
- Monetization and Partner Commercial Model
- Partner Ledger, Payout and Settlement

## Core Direction
Protect the recovered Profile Context Foundation and build one reusable Partner Management Foundation before tailor, designer, delivery and future service-specific modules.

## Protected Profile Context Foundation
- `mobile_accounts`
- `accounts`
- `accounts/{accountId}/profiles`
- `accounts/{accountId}/profiles/{profileId}/family_members`
- `accounts/{accountId}/addresses`
- `measurements`
- `customer_designs`
- `order_drafts`

## Architecture Decisions
### AD-8.001 Customer-first account architecture
**Status:** Confirmed
One mobile maps to one generated account. A Customer profile is auto-created and remains the default profile.

### AD-8.002 Multiple profiles per account
**Status:** Confirmed
An account may contain Customer and approved partner profiles. Paid designs are profile-owned; subscriptions are account-owned.

### AD-8.003 Profile Context Foundation is protected
**Status:** Confirmed
mobile_accounts, accounts, profiles, family_members, addresses, measurements, customer_designs and order_drafts form one dependent foundation. Rule changes require full regression testing.

### AD-8.004 Unified Partner Management Foundation
**Status:** Proposed
All partner types use one onboarding, KYC, approval, capability, service-area and commercial foundation with type-specific extensions.

### AD-8.005 Admin-only partner activation
**Status:** Confirmed
Every new partner profile starts inactive. Only Admin-authorized governance may approve and activate it.

### AD-8.006 Metadata-driven business logic
**Status:** Proposed
Production, care, pricing and routing logic should use versioned central metadata rather than scattered hardcoded rules.

### AD-8.007 Customer price, partner cost and platform revenue are separate
**Status:** Proposed
Financial values must be stored independently to support margin, revenue share, tax, refund and audit.

### AD-8.008 Partner ledger before payout
**Status:** Proposed
No payout is made directly from order totals. Every earning, fee, adjustment and payout flows through an auditable partner ledger.

### AD-8.009 Design catalog governance
**Status:** Proposed
Catalog entries support free, paid and premium access; partner publication requires approval and catalog moderation.

### AD-8.010 Standardization engines consume masters
**Status:** Proposed
Stitching, laundry and pressing engines consume garment, material and service metadata and return explainable recommendations.

### AD-8.011 Archival over physical deletion
**Status:** Confirmed
Family members and historical operational records are archived, preserving order, measurement, draft and review links.

### AD-8.012 Multi-platform shared backend
**Status:** Confirmed
Android first, with future iOS, Web, Admin Portal, Partner Portal and dashboards using shared governed backend services.

### AD-8.013 Environment isolation
**Status:** Confirmed
DEV, UAT and PROD environments and release controls are required before pilot/public rollout.

### AD-8.014 Financial configuration can vary by partner
**Status:** Proposed
Payout model, rates, commission, settlement cycle, tax, incentives and penalties may vary by partner and effective date.

### AD-8.015 Doorstep services use partner capabilities
**Status:** Proposed
Rafu, repair, alteration, pico-fall, measurement visits and future home services are modeled as services/capabilities, not one-off screens.

## Business Rules
- **BR-8.201 Partner default state:** All partner profiles are inactive on creation and cannot receive work, publish a catalog or enter payout eligibility.
- **BR-8.202 Partner lifecycle:** Draft → Submitted → Under Review → Approved/Rejected → Active; Active may move to Suspended or Inactive.
- **BR-8.203 KYC approval:** Approval requires mandatory profile data, KYC/document review and admin decision with timestamp and reviewer.
- **BR-8.204 Partner-type selection:** Registration captures one or more partner types; each activated type requires its own approved capability scope.
- **BR-8.205 Capability visibility:** Only approved, active capabilities can be used for discovery, allocation, rate negotiation or catalog publishing.
- **BR-8.206 Service areas:** Partner services are constrained by approved service areas, radius, pincodes, pickup rules and availability.
- **BR-8.207 Capacity:** Allocation must respect daily/weekly capacity, specialization, holidays, service pause and peak-season capacity.
- **BR-8.208 Tailor expected rates:** Tailor-entered rates are internal negotiation/benchmark inputs and are never directly shown as customer prices.
- **BR-8.209 SuiSakhi standard rate:** Customer pricing is governed by SuiSakhi rate rules, customizations, urgency, season, service and discounts.
- **BR-8.210 Margin separation:** Partner cost, customer price, platform fee, tax, discount and platform margin are independently recorded.
- **BR-8.211 Design catalog access:** Catalog items have free, paid or premium access, moderation status, ownership and effective availability.
- **BR-8.212 Paid design ownership:** Purchased designs belong to the selected profile; account subscription entitlements may allow access according to plan limits.
- **BR-8.213 Design partner payout:** Designer earnings follow the effective commercial agreement, such as revenue share, fixed royalty or hybrid model.
- **BR-8.214 Tailor certification:** Tailor tier is derived from verified capabilities, sample work, fabrics, garment types, quality and operational performance.
- **BR-8.215 Measurement acceptance:** Tailor onboarding records acceptance of trained measurer, standardized sheet, video verification, old-garment reference and QC remeasurement.
- **BR-8.216 Quality and rework:** Rework responsibility, trial policy, damage handling, SLA breach and compensation terms are captured and versioned.
- **BR-8.217 Payout eligibility:** A transaction becomes payout-eligible only after defined completion, confirmation, return/rework window and dispute checks.
- **BR-8.218 Partner-specific payout:** Payout model and settlement cycle may vary by partner; the effective agreement is snapshotted on each order/earning.
- **BR-8.219 Payout methods:** Supported payout destinations may include verified bank account, UPI or approved provider account; verification is mandatory.
- **BR-8.220 Adjustments:** Bonuses, penalties, refunds, rework deductions, taxes and manual adjustments require reason codes and audit trail.
- **BR-8.221 Admin authority:** Admin manages operational approvals, catalogs, disputes and metadata within assigned permissions.
- **BR-8.222 Super Admin authority:** Super Admin manages admin identities, global commercial rules, security policy, platform configuration and sensitive overrides.
- **BR-8.223 Four-eyes control:** High-risk actions such as payout override, commission change, bulk refund and super-admin assignment should require elevated approval or dual control.
- **BR-8.224 Metadata versioning:** Rates and production/care rules are effective-dated and versioned; historical orders retain the version used.
- **BR-8.225 Service pause:** Partners or services may be paused by date, capacity, emergency, compliance or operational decision without deleting history.
- **BR-8.226 Peak season:** Peak windows may alter capacity, SLA, customer rate and partner cost according to approved rules.
- **BR-8.227 Doorstep service:** Rafu, repair, alteration, pico-fall and measurement visits use service type, skill, radius, price, SLA and pickup/delivery rules.
- **BR-8.228 Auditability:** Approval, metadata, pricing, allocation and payout changes record actor, reason, prior value, new value and timestamp.
- **BR-8.229 No silent financial recomputation:** Once an order is accepted, financial snapshots change only through explicit adjustment workflows.
- **BR-8.230 Data retention:** Partner KYC and financial records follow retention/legal requirements and are not physically removed by routine application actions.

## Roles and Governance
### Super Admin
- Purpose: Platform governance
- Permissions: Create/deactivate Admins; global security and metadata policy; monetization; commission frameworks; settlement policies; sensitive overrides; audit access.
- Restrictions: Cannot bypass audit; high-risk actions should use dual control.

### Admin
- Purpose: Operational governance
- Permissions: Partner KYC approval/rejection/suspension; catalog moderation; operational metadata; orders, disputes and partner performance.
- Restrictions: Cannot create Super Admin or silently alter historical financial snapshots.

### Customer
- Purpose: Account service user
- Permissions: Profiles, family members, addresses, measurements, designs, orders, reviews and subscriptions.
- Restrictions: Only own account/profile-scoped data.

### Partner
- Purpose: Approved service provider
- Permissions: Maintain approved services, capacity, availability, order workflow, documents, earnings and payout destinations.
- Restrictions: No service visibility before approval; no access to unrelated customer/partner data.

### Tailor/Partner staff
- Purpose: Delegated worker
- Permissions: Assigned production tasks, limited status/QC updates according to shop policy.
- Restrictions: No commercial or payout changes unless explicitly delegated.

### Finance operator
- Purpose: Optional controlled role
- Permissions: Review payout runs, exceptions, invoices, tax data and reconciliations.
- Restrictions: No partner approval or metadata publishing unless separately granted.

### Support/QC operator
- Purpose: Optional controlled role
- Permissions: Case handling, trial/QC evidence, customer communication and rework workflow.
- Restrictions: No unrestricted financial change.

## Partner Ecosystem
Tailor, Boutique, Designer/Fashion Services, Fabric Supplier, Printing, Embroidery, Rental, Accessories, Brand, Delivery, Laundry/Dry Cleaning, Rafu/Repair/Alteration/Pico-Fall, Measurement/Home Visit and future metadata-configured partner types.

## Metadata Domains
- **Identity & profile:** Profile types, roles, statuses, relationships, archival reasons, preferences.
- **Partner:** Partner types, lifecycle, KYC requirements, documents, capability codes, tiers, service pauses.
- **Garment:** Dress types, components, complexity, wear type, size/measurement requirements, production time.
- **Fabric/material:** Composition, weave, GSM, stretch, opacity, drape, shrinkage, direction, care, season and risk.
- **Design:** Catalog type, occasion, style, silhouette, premium level, rights, compatibility and complexity.
- **Tailoring production:** Machine, needle, thread, stitch type/density, seam, margin, lining, interfacing, cutting and finishing.
- **Measurement:** Methods, source, units, validation ranges, review states, version types and confidence.
- **Pricing:** Base rates, garment/fabric/customization modifiers, location, urgency, season, minimums and rounding.
- **Discount & promotion:** Coupon type, eligibility, funding source, caps, stacking, dates and redemption limits.
- **Peak season & capacity:** Festival/season windows, multipliers, SLA changes, buffers and service pauses.
- **Laundry/washing:** Wash method, detergent type, water temperature, agitation, bleaching, drying and stain precautions.
- **Pressing/finishing:** Iron temperature, steam, pressing cloth, embellishment protection, folding and packaging.
- **Quality/QC:** Checklists, trial requirement, tolerances, photo evidence, defect severity, rework and acceptance.
- **Delivery:** Pickup/drop type, pincode/radius, parcel class, handover evidence, SLA, attempts and exceptions.
- **Commercial & payout:** Payout models, commission, platform fees, tax, settlement cycles, thresholds, incentives and penalties.
- **Audit & reason codes:** Approval, rejection, pause, cancellation, adjustment, refund and override reasons.
- **Localization:** Languages, labels, units, currency, regional tax/holiday and city/pincode mappings.

## Monetization
- **Stitching margin:** Difference between SuiSakhi customer price and agreed partner cost, separately recorded.
- **Platform/service fee:** Fixed or percentage fee charged to customer, partner or both according to transparent policy.
- **Paid design marketplace:** Design purchase with designer royalty/revenue share and platform share.
- **Account subscriptions:** Basic, family, premium/unlimited or future business plans with account-level entitlements.
- **Express/priority services:** Premium for urgency, reserved capacity, same-day or priority handling.
- **Measurement services:** AI-assisted, video verification, home visit, partner measurement or measurement-only service.
- **Doorstep services:** Pickup/drop, rafu, repair, alteration, pico-fall, laundry and pressing.
- **Marketplace commissions:** Fabric, accessories, rentals, brands and curated packages.
- **Premium QC/trial:** Optional enhanced trial, specialist QC, photo verification or bridal handling.
- **Partner enablement:** Optional promoted catalog placement, tools or value-added partner services, subject to policy.

## Firestore Schema Changes
- **Account foundation:** mobile_accounts; accounts; accounts/{accountId}/profiles; profiles/{profileId}/family_members; accounts/{accountId}/addresses.
- **Partner foundation:** partner_approvals; partner_profiles or profile extension; partner_documents; partner_capabilities; partner_service_areas; partner_capacity; partner_performance.
- **Tailor extension:** tailor_capabilities; tailor_machines; tailor_samples; tailor_rate_expectations; tailor_certifications; tailor_qc_checklists.
- **Design/catalog:** catalog/designTemplates current path; customer_designs; design_collections; design_licenses; design_purchases; catalog_moderation.
- **Metadata:** metadata_domains; metadata_items; metadata_versions; metadata_publications; rate_cards; pricing_rules; care_rules.
- **Measurements:** measurements with accountId, customerProfileId, personId, source, status, measurementValues and version/review fields.
- **Orders:** order_drafts; orders; order_status_history; order_assignments; order_qc; order_exceptions; order_financial_snapshot.
- **Commercial:** partner_agreements; commission_rules; pricing_rules; subscription_plans; coupons; promotions.
- **Financial:** partner_ledger; partner_transactions; partner_settlements; partner_payouts; partner_invoices; refunds; payment_events.
- **Governance:** admin_users; role_permissions; audit_events; approval_tasks; reason_codes; platform_configuration.

## Roadmap
- **Completed / current baseline:** Customer/account/profile/family/address foundation; measurements; Design Your Dress; design catalog filters; customer upload; fabric metadata/estimation; local price estimation; recovered Profile Context rules.
- **Milestone 8.1:** Partner registration foundation: unified partner type selection, inactive draft, profile/KYC, documents, submission and status.
- **Milestone 8.2:** Admin/Super Admin governance: permission model, approval queue, audit trail, activation/suspension and metadata publishing.
- **Milestone 8.3:** Tailor partner extension: checklist, capabilities, machines, fabrics, capacity, service area, expected rates, samples and certification.
- **Milestone 8.4:** Central metadata MVP: partner, garment, fabric, tailoring, pricing, season/service pause and reason codes.
- **Milestone 8.5:** Design partner/catalog governance: onboarding, moderation, free/paid/premium, pricing/licensing and design payouts.
- **Milestone 8.6:** Doorstep service partners: rafu, repair, alteration, pico-fall, measurement visit and pickup/drop service definitions.
- **Milestone 8.7:** Assignment and production workflow: capability/location/capacity matching, acceptance, SLA, status, QC and exceptions.
- **Milestone 8.8:** Partner commercial/ledger MVP: agreements, earning snapshots, weekly settlement, statements and controlled payouts.
- **Milestone 8.9:** Laundry and pressing metadata/engines: care masters, partner capability and standardized recommendations.
- **Milestone 8.10:** Pilot hardening: DEV/UAT/PROD, Firebase App Distribution, audits, analytics, support and operational runbooks.

## Open Questions
- **Partner identity:** Can one partner profile have multiple partner types? Is approval per profile, per type or per capability?
- **Admin model:** Will Phase-1 use one owner/admin account or separate Admin and Super Admin identities immediately?
- **KYC:** Which documents are mandatory by partner type and which external verification is planned?
- **Tailor organization:** Can one shop contain multiple staff users, machines and workstations?
- **Commercial agreement:** Is the agreement per partner, city, service or rate-card version? Who may negotiate/approve it?
- **Customer pricing:** Which components are shown separately to the customer: design, stitching, fabric, delivery, tax and service fee?
- **Payout:** Initial payout cycle, minimum threshold, hold period, UPI/bank preference and failure process?
- **Tax:** When are GST/TDS required and who issues invoices? Legal/accounting validation is needed before production.
- **Designer rights:** How will copyright/license declarations, takedowns and territory/usage rights be handled?
- **Catalog entitlement:** Does subscription include paid designs, discounts, credits or unlimited access by plan?
- **Assignment:** Manual admin assignment first or automatic recommendation first?
- **Peak season:** Who defines peak calendars, customer multipliers, capacity buffers and service pauses?
- **Doorstep services:** Will the service partner also deliver, or will a separate delivery partner be assigned?
- **Damage/liability:** How are material loss, cutting damage, incorrect measurement and rework costs shared?
- **Laundry/pressing:** Are these Phase-2 services or only metadata preparation in v8.0?
- **Security:** How will Admin/Super Admin stronger authentication, claims and emergency access be implemented?
- **Migration:** Which proposed collections extend current schema versus requiring migration?
- **Pilot scope:** Which partner types are essential for the first controlled pilot?

## Next Action
Jointly review gaps, approve/revise AD and BR identifiers, freeze the Partner Management MVP, and update `doc/SuiSakhi_PROJECT_CONTEXT.md` after approval.