# SuiSakhi Master Architecture v8.2.1 Operational Review Addendum

## Geo Services, Commercial Flexibility, Design Ownership, Garment Traceability, Doorstep Services, Laundry, Pressing, Rental, Risk Mitigation, and Partner Agreements

**Baseline:** SuiSakhi Master Architecture v8.2 Consolidated Delta  
**Version:** 8.2.1 Review Addendum  
**Date:** 28 August 2026  
**Status:** Review Draft  
**Purpose:** Capture all architectural and operational decisions identified during the v8.2 review before the next development phase.

---

## 1. Purpose and Scope

This addendum captures the following additions and corrections:

- Map-based address selection and geo coordinates
- Default zero joining fee with metadata-driven override
- SuiSakhi-owned, Designer-owned, Partner-owned, commissioned, and licensed design models
- Fabric visualization limited to standardized SuiSakhi catalog designs in Phase 1
- Garment identity independent from Order identity
- QR-based garment tracking using low-cost Bluetooth thermal label printers
- Chain of custody and Partner handover tracking
- Doorstep Services Partner as a Phase-1 category
- Separate Rental, Laundry, Pressing, and Dry-Clean operational extensions
- Operational photo evidence and configurable deletion
- Comprehensive risk and mitigation framework
- Partner agreement and risk acknowledgment
- Partner operational readiness and release checklists
- Preference for simple QR technology before RFID, NFC, or advanced IoT

---

## 2. Partner Location and Geo-Services Foundation

### AD-8.2-013: Location-Aware Partner Operations

SuiSakhi shall support location-aware Partner discovery, assignment, pickup, delivery, measurement, doorstep services, service-area validation, and route planning.

Customers and Partners shall not manually enter latitude and longitude. The preferred flow is:

```text
Search or Enter Address
→ Select Verified Map Result
→ Confirm Map Pin
→ Store Normalized Address and Coordinates
```

### 2.1 Suggested location model

```text
addressLine1
addressLine2
locality
city
district
state
country
pincode
placeId
latitude
longitude
geoHash
serviceRadiusKm
pickupRadiusKm
deliveryRadiusKm
locationVerifiedAt
locationVerifiedByUid
```

### 2.2 Future use cases

```text
Nearest Tailor Partner
Nearest Measurement Partner
Nearest Laundry Partner
Nearest Pressing Partner
Nearest Doorstep Services Partner
Nearest Delivery Partner
Service-Area Compatibility
Pickup and Delivery Validation
Partner Assignment Optimization
Emergency Reassignment
Route Planning
```

### 2.3 Privacy rule

A home-based Partner's exact address shall not be exposed publicly unless required for a confirmed service. Customer-facing discovery may show approximate locality, verified service area, and calculated distance.

---

## 3. Joining Fee and Commercial Flexibility

### BR-8.2-025: Default Joining Fee

During pilot and early growth:

```text
Default Partner Joining Fee = INR 0
```

The amount remains editable through centrally managed commercial metadata. Category-specific, plan-specific, geography-specific, campaign-specific, invited-Partner, or enterprise fees may be configured later.

### 3.1 Configurable fields

```text
joiningFeeAmount
joiningFeeStatus
joiningFeeWaived
joiningFeeWaiverReasonCode
securityDepositAmount
securityDepositStatus
subscriptionAmount
commissionRuleCode
settlementRuleCode
commercialPlanCode
effectiveFrom
effectiveTo
```

A fee must not be hardcoded in the mobile application.

---

## 4. Design Ownership and Premium Catalog Architecture

Paid and premium designs may use multiple ownership models.

### 4.1 Ownership types

```text
designerOwned
partnerOwned
suisakhiOwned
commissionedForSuiSakhi
licensedThirdParty
exclusiveLicensedDesign
publicDomainReference
```

### 4.2 SuiSakhi-owned designs

SuiSakhi may:

```text
Purchase a design with one-time ownership transfer
Commission an original design
Acquire exclusive commercial rights
Acquire non-exclusive catalog rights
Create an internal premium collection
Offer a design free, paid, bundled, or subscription-based
```

### 4.3 Suggested fields

```text
designOwnershipType
ownerProfileId
creatorProfileId
licenseType
licenseReference
exclusiveFlag
ownershipEffectiveAt
ownershipExpiryAt
oneTimePurchaseAmount
royaltyRuleCode
customerDesignPrice
currency
rightsTerritories
rightsEvidenceUrls
```

A design must not be published until ownership, license, commissioning, or source evidence is reviewed.

---

## 5. Fabric Visualization Scope

### BR-8.2-026: Catalog-Only Fabric Visualization in Phase 1

Fabric and color visualization shall initially be supported only for approved SuiSakhi catalog designs with standardized visual assets.

```text
Approved Catalog Design
+ Standardized Line Art or Layered Asset
+ Approved Fabric or Color
→ Fabric Visualization
```

Customer-uploaded designs remain reference designs during Phase 1 and are not automatically processed for fabric replacement.

### 5.1 Reasons

```text
Unstructured customer images
Inconsistent angles and backgrounds
Unclear design ownership
No guaranteed closed garment regions
High segmentation and rendering overhead
Unreliable preview quality
```

### 5.2 Disclaimer

Fabric previews are illustrative and do not guarantee exact drape, print scale, color under lighting, stitch finish, or final garment appearance.

---

## 6. Garment Identity and Garment Passport

### AD-8.2-014: Garment as an Independently Traceable Entity

Every garment, fabric bundle, reference garment, rental item, laundry item, or pressing item handled through SuiSakhi should receive an independent identity wherever operationally applicable.

### 6.1 Identifier hierarchy

```text
Order ID
Garment ID
Material Bundle ID
Package ID
Handover Event ID
Issue ID
```

Example:

```text
SS-ORD-20261014-00001
SS-GRM-20261014-00001-01
SS-GRM-20261014-00001-02
SS-MAT-20261014-00001-01
```

### 6.2 Garment Passport

```text
garmentId
orderId
customerAccountId
customerProfileId
garmentCategory
garmentDescription
designId
fabricId
currentCustodianProfileId
currentLocationType
currentStatus
qrCodeValue
humanReadableCode
createdAt
journeyEvents
issueSummary
finalDeliveryAt
archiveStatus
```

### BR-8.2-027

Garment identity is separate from Order identity. One Order may contain multiple individually tracked garments and material bundles.

---

## 7. QR-Based Garment Tracking

### BR-8.2-028

QR tracking shall be mandatory wherever a garment or material bundle changes custody and the process is operationally applicable.

### 7.1 Phase-1 technology

```text
QR Sticker
Human-Readable Garment Code
Bluetooth Thermal Label Printer
Mobile Camera Scanner
Manual Code Entry Fallback
```

A Delivery Partner may carry an affordable handheld Bluetooth thermal label printer. The SuiSakhi application generates the Garment ID and QR, and the Delivery Partner prints and attaches the label during pickup.

### 7.2 QR privacy

The QR payload shall contain an opaque Garment ID or signed lookup token, not Customer personal information.

### 7.3 Label contents

```text
QR Code
Human-Readable Garment ID
Order Suffix
Garment Sequence
Service Type Color or Symbol
Optional Handling Warning
```

Suggested service colors:

```text
Purple: Tailoring
Blue: Laundry
Green: Pressing
Orange: Rental
Teal: Doorstep Services
```

Color shall not be the only identifier.

### 7.4 Safe attachment

A QR label should normally be attached to removable packaging, a garment-safe loop, hanger, or tag. Adhesive must not be applied directly to delicate fabric.

### 7.5 Technology progression

```text
QR
→ Barcode
→ RFID
→ NFC
→ Advanced IoT
```

---

## 8. Pickup and Identification Workflow

```text
Open Confirmed Pickup
→ Confirm Customer and Order
→ Capture Photos
→ Record Existing Issues
→ Create Garment or Material Entries
→ Generate Garment IDs
→ Print QR Labels
→ Attach Labels Safely
→ Confirm Item Count
→ Customer OTP or Digital Confirmation
→ Complete Pickup
```

Photo evidence shall be captured before custody acceptance.

### 8.1 Tailoring evidence

```text
Fabric Front and Reverse
Fabric Bundle
Lining
Lace
Buttons and Accessories
Reference Garment
Existing Damage or Stain
Customer Notes
```

### 8.2 Laundry and pressing evidence

```text
Front and Back
Visible Stains
Tears or Loose Seams
Missing Buttons or Accessories
Color Condition
Fabric Type
Care Label
```

### 8.3 Rental evidence

```text
Front and Back
Accessories Included
Condition Grade
Existing Damage
Return Condition
Missing Items
```

---

## 9. Chain of Custody and Handover Events

### BR-8.2-029

Every Partner-to-Partner and Partner-to-Customer handover shall create a traceable custody event.

### 9.1 Handover fields

```text
handoverEventId
garmentId
orderId
fromProfileId
fromRole
toProfileId
toRole
handoverType
scannedAt
receivedAt
location
conditionStatus
issueIds
photoEvidenceIds
senderConfirmation
receiverConfirmation
createdByUid
```

### 9.2 Typical journey

```text
Customer
→ Delivery Partner
→ Tailor Partner
→ Laundry Partner, if required
→ Pressing Partner, if required
→ Delivery Partner
→ Customer
```

### 9.3 Failure fallback

```text
Manual Code Entry
Offline Event Queue
Label Photo
Admin-Assisted Reprint
Exception Reason Code
Mandatory Sync After Connectivity Returns
```

A Partner shall never accept an unidentified garment into custody.

---

## 10. Operational Issue Evidence and Customer Communication

When an issue is identified:

```text
Identify Issue
→ Capture Photo
→ Select Standard Issue Code
→ Add Notes
→ Notify Customer
→ Obtain Approval, Rejection, or Change Instruction
→ Continue, Hold, or Return
```

Issues include:

```text
Tear
Permanent Stain
Color-Bleed Risk
Shrinkage Risk
Missing Button
Broken Zip
Weak Seam
Fabric Defect
Pressing Risk
Chemical-Cleaning Risk
Missing Accessory
Existing Damage
```

Customer-visible messages shall be template-driven and stored with a snapshot.

---

## 11. Evidence Retention and Storage Optimization

### BR-8.2-030

Operational photos shall not be retained permanently unless a dispute, legal requirement, fraud investigation, claim, audit, unresolved issue, warranty, or policy exception requires longer retention.

### 11.1 Default lifecycle

```text
Photo Uploaded
→ Order Delivered
→ Payment Settled
→ Feedback or Acceptance Window Completed
→ No Open Dispute
→ Retention Period
→ Automatic Deletion
→ Deletion Audit
```

### 11.2 Initial default

```text
90 days after delivery and payment settlement
```

The period remains configurable by evidence type, service type, risk, jurisdiction, and dispute status.

### 11.3 Eligible photos

```text
Fabric Photos
Material Pickup Photos
Laundry Photos
Pressing Photos
Routine Issue Photos
Delivery Photos
Doorstep Before and After Photos
Rental Condition Photos after closure period
```

### 11.4 Persisted metadata

```text
Order Metadata
Garment Passport
Traceability Events
Issue Codes and Resolution
Evidence Type
Evidence CreatedAt
Evidence Deleted Flag
Evidence DeletedAt
Retention Policy Code
Ratings and Reviews
Financial Records
Audit Records
```

### 11.5 Deletion holds

```text
Open Dispute
Chargeback
Customer or Partner Claim
Legal Hold
Fraud Review
Insurance Claim
Regulatory Audit
Unresolved Loss or Damage
Linked Open Helpdesk Ticket
```

The objective is to balance privacy, dispute protection, legal obligations, and cloud storage cost.

---

## 12. Doorstep Services Partner

### AD-8.2-015

Doorstep Services Partner is a full Phase-1 Partner category.

Potential Partner sources:

```text
Home-Based Service Providers
Tailoring Institutes
Skilled Individuals
Self-Help Groups
Existing Tailors offering Mobile Service
Society-Based Service Providers
```

### 12.1 Services

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
Curtain Alteration
Cushion Cover Repair
School Uniform Quick Fix
Emergency Event-Wear Repair
```

### 12.2 Metadata

```text
serviceCodes
serviceRadiusKm
coveragePincodes
minimumVisitCharge
travelChargeRuleCode
sameDayAvailable
emergencyAvailable
workingHours
averageServiceMinutes
toolsCarried
supportedFabrics
societyEntryRequirements
beforePhotoRequired
afterPhotoRequired
customerOtpRequired
```

### 12.3 Flow

```text
Select Quick Fix
→ Upload Optional Photo
→ Select Address and Time
→ Receive Estimate
→ Assign Partner
→ Partner Arrives
→ Confirm Scope
→ Perform Service
→ Approve Additional Work, if any
→ Capture Completion Evidence
→ Customer OTP or Sign-Off
→ Payment and Rating
```

---

## 13. Rental Partner Ecosystem

Rental is a separate business stream.

### 13.1 Categories

```text
Bridal Wear Rental
Designer Wear Rental
Occasion Wear Rental
Girls Event Wear Rental
Jewellery Rental
Accessories Rental
Family Event Packages
```

### 13.2 Metadata

```text
inventoryItemId
sizeAndFit
conditionGrade
rentalDuration
availabilityCalendar
securityDepositRule
lateFeeRule
damagePolicy
cleaningPolicy
accessoriesIncluded
replacementValue
pickupAndReturnRules
```

### 13.3 Lifecycle

```text
Available
→ Reserved
→ Prepared
→ Delivered or Picked Up
→ In Use
→ Returned
→ Inspection
→ Damage or Missing-Item Resolution
→ Cleaning
→ Ready Again
```

---

## 14. Laundry Partner Ecosystem

Laundry is a separate fabric-aware service category.

### 14.1 Metadata

```text
washMethod
waterTemperatureRange
detergentType
detergentBrandOrStandard
bleachPolicy
colorProtectionMethod
separateWashRequired
fabricCompatibility
stainTreatmentMethods
dryingMethod
shrinkageRisk
customerConsentRequired
```

### 14.2 Lifecycle

```text
Pickup
→ QR Confirmation
→ Inspection
→ Stain and Damage Classification
→ Customer Notification, if required
→ Process Selection
→ Wash or Clean
→ Dry
→ QC
→ Optional Pressing
→ Pack
→ Delivery
```

If a stain may not be removable or treatment may damage the fabric, the Customer shall be informed with evidence before high-risk treatment.

---

## 15. Pressing Partner Ecosystem

Pressing is separate from Laundry and may be ordered independently.

### 15.1 Methods

```text
Hand Press
Steam Press
Roll Press
Vacuum Press
Dry Press
Low-Temperature Press
Protective-Cloth Press
```

### 15.2 Fabric and care rules

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
One-Dot, Two-Dot, and Three-Dot Care Instructions
```

### 15.3 Lifecycle

```text
Pickup
→ QR Confirmation
→ Inspection
→ Fabric and Care Classification
→ Method Selection
→ Pressing
→ QC
→ Packing
→ Delivery
```

---

## 16. Dry-Clean and Chemical-Cleaning Capability

Dry and chemical cleaning are specialized service capabilities, even if provided by a Laundry Partner.

```text
cleaningMethod
chemicalTypeCode
fabricRestrictions
spotTreatmentCapability
luxuryGarmentCapability
bridalWearCapability
leatherCapability
silkCapability
odorTreatment
colorFastnessCheck
customerConsentRequired
safetyCertification
```

High-risk chemical treatment requires documented method selection and Customer approval where applicable.

---

## 17. Risk Severity Model

```text
Critical
High
Medium
Low
```

```text
Critical: Loss, mix-up, fraud, major damage, safety incident, or legal exposure
High: Serious quality failure, major delay, shrinkage, bleed, or failed delivery
Medium: Correctable defect, rework, partial delay, or communication failure
Low: Minor documentation gap or low-impact deviation
```

---

## 18. Operational Risk and Mitigation Framework

### 18.1 Wrong garment delivered

```text
Severity: Critical
Prevention: QR scan, separate packaging, Garment Passport
Detection: Delivery scan mismatch
Response: Stop delivery, trace custody, escalate
Evidence: Handover events, delivery confirmation
Partner Obligation: Verify Garment ID before delivery
```

### 18.2 Garment lost

```text
Severity: Critical
Prevention: Custody scans, inventory reconciliation
Detection: Missing expected receipt or overdue handover
Response: Immediate hold, search, notify, incident workflow
Evidence: Last custody event and route history
Partner Obligation: Report immediately
```

### 18.3 Garment mix-up

```text
Severity: Critical
Prevention: Unique labels, separate packaging, no unidentified items
Detection: Scan mismatch or Customer verification
Response: Stop processing, isolate items, trace affected orders
```

### 18.4 Fabric or garment damage

```text
Severity: Critical or High
Prevention: Pickup condition photos and process rules
Detection: Inspection and QC
Response: Notify Customer, hold processing, assess responsibility
Evidence: Before, issue, and after records
```

### 18.5 Incorrect measurements

```text
Prevention: Versioned, person-scoped, approved measurements
Detection: Tailor verification and trial
Response: Re-measurement and change workflow
Partner Obligation: Use only the approved version
```

### 18.6 Wrong design interpretation or cutting error

```text
Prevention: Approved design snapshot, measurement and fabric checkpoints
Detection: Pre-cut confirmation and milestone review
Response: Stop irreversible processing and escalate
Partner Obligation: Clarify before cutting
```

### 18.7 Tailor overbooking and delay

```text
Prevention: Capacity limits, backlog and pause controls
Detection: Milestone and SLA alerts
Response: Reassignment, revised date, escalation
Partner Obligation: Report delay early
```

### 18.8 Laundry color bleeding or shrinkage

```text
Prevention: Fabric classification, temperature and separate-wash rules
Detection: Pre-test and QC
Response: Stop, notify, document, assess responsibility
Partner Obligation: Follow approved treatment
```

### 18.9 Stain not removable

```text
Prevention: Stain classification and realistic expectation
Detection: Inspection
Response: Notify Customer and obtain treatment approval
Partner Obligation: No high-risk treatment without required approval
```

### 18.10 Press burn, shine, flattening, or print damage

```text
Prevention: Care-label and temperature rules
Detection: Inspection and QC
Response: Stop, record evidence, escalate
Partner Obligation: Use fabric-compatible methods
```

### 18.11 Wrong address or failed delivery

```text
Prevention: Verified map pin and Customer confirmation
Detection: Route or recipient mismatch
Response: Retry, return, or Helpdesk escalation
Evidence: Geo event, scan, OTP
```

### 18.12 Printer, label, scanner, or network failure

```text
Prevention: Charged device, spare labels, cached QR
Detection: Failed print or scan
Response: Manual code, offline queue, reprint, exception code
Partner Obligation: Never accept an unidentified item
```

### 18.13 Doorstep service scope or conduct issue

```text
Prevention: Defined service scope, verified Partner, appointment record
Detection: Customer complaint, check-in/out exceptions
Response: Stop service, Helpdesk escalation, suspension review
Partner Obligation: Follow conduct, privacy, and safety policy
```

### 18.14 Rental damage, missing accessories, or late return

```text
Prevention: Condition records, inventory checklist, reminders
Detection: Return inspection
Response: Evidence-based assessment and policy rules
```

### 18.15 Fake Partner or Partner impersonation

```text
Prevention: KYC, business verification, approval, activation
Detection: Audit, Customer report, mismatch
Response: Immediate suspension and investigation
```

### 18.16 Fraudulent order or payment dispute

```text
Prevention: OTP, payment controls, risk signals
Detection: Payment or behavior anomaly
Response: Hold, investigate, preserve evidence
```

### 18.17 Data loss or unauthorized access

```text
Prevention: Backups, least privilege, Firebase rules, audit
Detection: Monitoring and access anomalies
Response: Recovery, credential action, incident review
```

### 18.18 Notification failure

```text
Prevention: In-app system record and asynchronous external queues
Detection: Delivery status and retry count
Response: Retry, alternate channel, Helpdesk alert
```

### 18.19 Excessive cloud-storage cost

```text
Prevention: Compression, evidence classes, retention metadata
Detection: Storage reporting and growth thresholds
Response: Lifecycle cleanup and policy tuning
```

### 18.20 Unknown or emerging risk

```text
Prevention: Operational training and incident awareness
Detection: Generic incident reporting
Response: Temporary hold, Super Admin review, root-cause analysis
Outcome: Add standardized risk, reason code, and corrective control
```

### BR-8.2-031

All Critical and High risks must have preventive, detective, response, evidence, responsibility, and escalation controls before production enablement.

---

## 19. Partner Agreement and Risk Acknowledgment

Every Partner must accept a category-specific Partner Agreement before activation.

### 19.1 Common acknowledgments

```text
Customer Property Handling
QR and Identification Compliance
Chain-of-Custody Compliance
Photo Evidence Requirements
Customer Data Privacy
Issue and Damage Reporting
Delay and Capacity Reporting
Loss and Mix-Up Escalation
Quality and Rework Responsibilities
Commercial Terms
Audit Cooperation
SLA Commitments
Suspension and Investigation Cooperation
```

### 19.2 Risk-level acknowledgment

```text
Critical Mandatory Acknowledgment
High-Risk Operational Acknowledgment
Standard Service Acknowledgment
Category-Specific Acknowledgment
```

### 19.3 Acceptance fields

```text
agreementVersion
riskPolicyVersion
acceptedByUid
partnerProfileId
acceptedAt
source
messageSnapshot
```

Tailor, Laundry, Pressing, Rental, Delivery, and Doorstep Services Partners shall receive common clauses plus relevant category clauses.

---

## 20. Partner Operational Readiness Checklist

### 20.1 Common foundation

```text
KYC Verified
Business Profile Verified
Service Area Approved
Operational Capacity Configured
Quality Standards Accepted
Commercial Setup Completed
Documents Verified
Compliance Verified
Declarations Accepted
```

### 20.2 Training

```text
QR Process Understood
Garment Handling Understood
Pickup Understood
Handover Understood
Delivery Understood
Issue Reporting Understood
Customer Communication Understood
Escalation Understood
Data Privacy Accepted
```

### 20.3 Traceability

```text
Garment ID Supported
QR Printing or Label Access Confirmed
Scanning Supported
Manual Fallback Understood
Pickup Evidence Supported
Handover Events Supported
Delivery Confirmation Supported
Issue Evidence Supported
```

### 20.4 Tailor readiness

```text
Measurement Standards Accepted
Fabric and Cutting Checkpoint Understood
Rework Policy Accepted
Delay Reporting Accepted
Capacity Limits Configured
```

### 20.5 Laundry readiness

```text
Fabric Handling Standards Accepted
Detergent and Process Standards Recorded
Stain Reporting Accepted
Color-Bleed Risk Accepted
Shrinkage Risk Accepted
```

### 20.6 Pressing readiness

```text
Fabric-Specific Standards Accepted
Temperature Guidance Accepted
Care-Label Process Understood
Damage Reporting Accepted
```

### 20.7 Doorstep readiness

```text
Service Scope Rules Accepted
Additional Work Approval Understood
Before and After Evidence Supported
Customer OTP Supported
Home-Visit Conduct Policy Accepted
```

### 20.8 Rental readiness

```text
Inventory Tracking Ready
Condition Assessment Ready
Accessory Checklist Ready
Return Verification Ready
Cleaning Workflow Ready
Deposit and Damage Rules Accepted
```

---

## 21. Architecture and Release Risk Checklist

Before releasing a major operational feature, verify:

```text
Can every garment be uniquely identified?
Can every custody transfer be traced?
Can Partner accountability be determined?
Can Customer disputes be investigated?
Is personal data protected in QR and public views?
Can evidence be retained and deleted correctly?
Can a failed scan, printer, or network operation use a fallback?
Can incidents be escalated automatically?
Can peak-season overload be controlled?
Can Partner capacity be paused?
Can risky treatment obtain Customer consent?
Can a Partner be suspended without losing history?
Can notifications fail without losing the transaction?
Can unknown risks be recorded and reviewed?
```

---

## 22. Operational Simplicity Principle

### AD-8.2-016

Operational simplicity shall take precedence over advanced technology during pilot and early growth.

```text
QR
→ Barcode
→ RFID
→ NFC
→ Advanced IoT
```

More complex technology shall be introduced only when volume, speed, bulk scanning, loss rate, or commercial value justifies the cost and training.

---

## 23. New Business Rules

### BR-8.2-025
Default Partner joining fee is INR 0 during pilot but remains metadata-driven and editable.

### BR-8.2-026
Phase-1 fabric visualization is limited to approved standardized SuiSakhi catalog designs.

### BR-8.2-027
Garment identity is separate from Order identity.

### BR-8.2-028
QR tracking is mandatory where physical items change custody and the process is applicable.

### BR-8.2-029
Every garment handover creates a traceable custody event.

### BR-8.2-030
Operational photos follow configurable retention and deletion policies.

### BR-8.2-031
Critical and High risks require documented controls before production enablement.

### BR-8.2-032
Partners accept common and category-specific risk obligations before activation.

### BR-8.2-033
Doorstep Services Partner is a full Partner profile and Phase-1 category.

### BR-8.2-034
Rental, Laundry, Pressing, and Dry-Clean services use separate operational extensions and lifecycles.

### BR-8.2-035
SuiSakhi-owned, Partner-owned, Designer-owned, commissioned, and licensed designs are supported through ownership metadata.

### BR-8.2-036
Map-based address selection captures normalized address, place reference, and coordinates without manual coordinate entry.

### BR-8.2-037
Evidence deletion is suspended while a dispute, audit, legal hold, fraud review, or unresolved linked Helpdesk ticket is open.

### BR-8.2-038
Direct personal information must not be embedded in QR payloads.

### BR-8.2-039
A Partner must not accept an unidentified garment or material bundle into custody.

### BR-8.2-040
Unknown incidents use generic incident codes, evidence, temporary holds, escalation, and corrective-action review.

---

## 24. Recommended Development Mapping

The following controls should be implemented gradually and validated screen by screen:

```text
Partner Location Model
Garment ID and Passport Model
QR Generation
Thermal Printer Integration Spike
Pickup Evidence
Customer OTP Pickup Confirmation
Handover Event Model
Partner Scan Screen
Doorstep Services Metadata and Booking
Laundry Process Metadata
Pressing Process Metadata
Rental Inventory and Condition Model
Evidence Retention Metadata
Scheduled Evidence Deletion
Deletion Hold for Disputes
Risk and Incident Codes
Partner Agreement Acceptance
Partner Activation Readiness Checklist
```

The pilot does not require RFID, NFC, or advanced IoT.

---

## 25. Review Status

### Agreed Direction

```text
Google Map or equivalent verified location selection
Default joining fee INR 0 with metadata override
Multiple design ownership models
Catalog-only fabric visualization in Phase 1
Garment Passport
QR labels and thermal printers
Doorstep Services Partner in Phase 1
Separate Rental, Laundry, Pressing, and Dry-Clean lifecycles
90-day default operational photo retention
Dispute and legal-hold exceptions
Risk-driven Partner agreements
Operational readiness before activation
```

### Items to Validate During Implementation

```text
Selected map provider and cost controls
Thermal printer compatibility
Garment-safe label material
Offline scan and print behavior
Exact evidence retention by service type
Customer consent wording
Partner compensation and liability clauses
Insurance requirements
Incident severity and escalation SLA
```

---

**End of SuiSakhi Master Architecture v8.2.1 Operational Review Addendum**
