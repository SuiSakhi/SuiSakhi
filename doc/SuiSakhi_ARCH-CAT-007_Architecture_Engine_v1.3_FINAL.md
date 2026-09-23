# SuiSakhi ARCH-CAT-007
## Designer Catalogue Architecture Engine, Multi-View Design Preview, Structured SVG, Design Semantics and Material Preview

**Version:** 1.3 REVIEW DRAFT  
**Date:** 23 September 2026  
**Status:** FINAL REVIEW CANDIDATE, not yet frozen  
**Parent milestone:** SuiSakhi Catalogue Engine V1 live success  
**Architecture start tag:** `catalogue-structured-svg-c1.4-start-23sep2026`  
**Live compatibility baseline:** The deployed C1.3 raster-processing worker remains unchanged until C1.4 local validation and a separate cloud-integration approval.

---

## 1. Purpose

ARCH-CAT-007 defines a simple, modular and audit-first Architecture Engine for **Designer Catalogue Designs**.

The engine accepts monochrome structured designs uploaded by a Designer or Admin. The upload may contain one or more design views. The engine uses the supplied evidence to understand the garment design, proposes missing design views where appropriate, creates structural masks, prepares a structured SVG, derives governed design semantics, supports material assignment, validates visual consistency, and produces an approved **360° Design Preview**.

This engine is a design-understanding and design-preview engine. It is not a measurement engine, order-measurement engine, body-measurement engine, manufacturing-pattern engine, or Virtual Try-On engine.

---

## 2. Simple SuiSakhi capability boundary

### 2.1 Included in ARCH-CAT-007

- Designer or Admin monochrome structured design upload
- One or multiple supplied design views
- View detection and registration
- Missing design-view proposals where appropriate
- Multi-view visual consistency validation
- Garment-piece and component masks
- Structured SVG representation
- Governed Design Semantics
- Material Assignment Map
- Material-aware fabric preview foundation
- Admin or governed design-review gate
- Approved 360° Design Preview
- Future integration point for Virtual Try-On

### 2.2 Explicitly excluded from ARCH-CAT-007

- Customer body measurements
- Garment/order dimensions such as bust, shoulder, sleeve length or blouse length
- Measurement inference from Designer drawings
- Tailor-confirmed final measurements
- Automatic cutting patterns
- Automatic grading across sizes
- Manufacturing-authoritative seam allowances
- Customer photo processing in the current phase
- Customer Reference Design conversion
- Live Virtual Try-On implementation
- Body-fit claims or fabric-physics claims

---

## 3. Frozen separation of responsibilities

### 3.1 Catalogue Architecture Engine

Purpose:

```text
Understand and represent the Designer's visual design
```

The Catalogue Architecture Engine understands views, garment structure, component regions, visual semantics and material assignments.

### 3.2 Measurement Engine

Purpose:

```text
Manage customer/order measurements and tailor finalisation
```

The Measurement Engine remains separate and owns customer, family-member and order-specific measurement workflows.

### 3.3 Fabric Estimation Engine

Purpose:

```text
Estimate fabric requirements using approved design metadata and relevant order inputs
```

The existing Fabric Estimation Engine remains independent. It may consume approved Design Semantics, garment type, material assignments and relevant customer/order information through governed integration, but it is not part of 360° Design Preview generation.

### 3.4 Future Virtual Try-On Engine

Purpose:

```text
Combine approved design and material representations with a separate future customer representation
```

Virtual Try-On is reserved, not implemented in C1.4.

---

## 4. Designer Catalogue Design versus Customer Reference Design

### 4.1 Designer Catalogue Design

Input:

```text
Monochrome structured design uploaded by Designer or Admin
```

Possible upload combinations:

- Front only
- Back only
- Front and Back
- Front and Side
- Front, Back and Side
- Multiple additional detail views
- Combined front/back or multi-view technical drawing

Processing:

```text
Designer/Admin Upload
        ↓
Architecture Engine
        ↓
Understand supplied design views
        ↓
Propose appropriate missing design views
        ↓
Masks
        ↓
Structured SVG
        ↓
Design Semantics
        ↓
Material Assignment Map
        ↓
Multi-View Visual Consistency Check
        ↓
Admin / Design Review Gate
        ↓
360° Design Preview
        ↓
Material/Fabric Preview for uploaded fabric material
        ↓
Future: AI Virtual Try-On
```

### 4.2 Customer Reference Design

Input:

```text
Customer photo, screenshot, social-media image or other reference image
```

Current-phase behavior:

- Reference only
- Stored with the customer order or design discussion
- Available to the Tailor as an order reference
- No automatic Catalogue conversion
- No automatic masks
- No automatic structured SVG
- No 360° Design Preview
- No Virtual Try-On

This separation prevents unnecessary system complexity and avoids representing informal customer references as governed Catalogue assets.

---

## 5. Input views are design evidence, not measurements

The engine may identify visual characteristics such as:

- Neck shape
- Sleeve style
- Silhouette
- Approximate visual proportion or visual length category
- Border placement
- Embroidery or embellishment placement
- Closure appearance
- Garment-piece composition

The engine must not infer or require physical values such as:

- Bust = 36 inches
- Blouse length = 15 inches
- Sleeve length = 10 inches
- Shoulder = 14 inches

These values belong to the Measurement, Order and Tailor workflows.

---

## 6. Source-view taxonomy

### 6.1 Canonical design-view codes

- `front`
- `back`
- `leftSide`
- `rightSide`
- `threeQuarterFrontLeft`
- `threeQuarterFrontRight`
- `threeQuarterBackLeft`
- `threeQuarterBackRight`
- `neckDetail`
- `sleeveDetail`
- `borderDetail`
- `embellishmentDetail`
- `closureDetail`
- `constructionDetail`
- `combinedFrontBack`
- `combinedMultiView`
- `singleUnclassifiedView`

Existing C1.3 view codes remain backward-compatible until an approved model migration introduces additional values.

### 6.2 View origin

- `designerUploaded`
- `adminUploaded`
- `combinedImageExtracted`
- `systemNormalized`
- `suisakhiAssistedGenerated`
- `aiGeneratedPreview`
- `interpolatedFor360Preview`
- `manuallyCorrected`
- `approvedDerived`

### 6.3 Evidence class

- `observed`: directly visible in the uploaded Designer/Admin design.
- `partiallyObserved`: supported by multiple supplied views but not fully visible.
- `inferred`: generated from limited evidence.
- `interpolated`: generated between approved canonical views for smooth preview.
- `manuallySpecified`: supplied or corrected during governed review.

---

## 7. Supported Designer input scenarios

### 7.1 Front only

```text
Observed: Front
Proposed where appropriate: Back, Left Side, Right Side
```

Hidden details remain inferred or uncertain. The system does not claim that generated back or side details are directly observed.

### 7.2 Back only

```text
Observed: Back
Proposed where appropriate: Front, Left Side, Right Side
```

The same provenance and review controls apply.

### 7.3 Front and Back

```text
Observed: Front and Back
Proposed: Left Side and Right Side
```

Cross-view evidence improves visual consistency, but side details remain reviewable proposals.

### 7.4 Front and Side

```text
Observed: Front and one Side
Proposed: Back and missing opposite Side
```

### 7.5 Front, Back and Side

```text
Observed: Front, Back and one or both Side views
Proposed: Missing opposite Side and intermediate preview frames
```

This is the preferred input for a stronger 360° Design Preview.

### 7.6 Multiple additional detail views

Detail views may improve neckline, sleeve, border, closure, embroidery, motif and construction-feature understanding. Detail views do not independently establish a full garment view.

### 7.7 Combined technical drawing

A combined image is retained as an immutable original. The engine proposes separate bounded front, back or detail view assets linked to the combined source.

### 7.8 Multi-piece design

A multi-piece outfit is represented as independently addressable garment pieces, for example:

```text
Lehenga Set
├── Blouse
├── Skirt
└── Dupatta
```

Each piece may have different supplied views, masks, semantics, material assignments and reconstruction confidence.

---

## 8. Multi-view design reconstruction

### 8.1 Objective

Use all supplied Designer/Admin views to create a coherent set of design-view proposals appropriate for review and customer preview.

### 8.2 Responsibilities

- Inventory supplied views
- Detect or confirm view type
- Detect combined-view layouts
- Identify garment pieces
- Align supplied views to canonical orientation
- Propose missing canonical design views where appropriate
- Preserve visual evidence and provenance
- Record uncertainty internally
- Generate reviewable design-view revisions
- Produce approved preview frames for the 360° Design Preview

### 8.3 Reconstruction modes

- `originalViewsOnly`
- `canonicalViewProposal`
- `approvedCanonicalViews`
- `turntablePreviewFrames`

Full physical 3D garment simulation is not included.

### 8.4 Statuses

- `notRequested`
- `queued`
- `processing`
- `sourceReviewRequired`
- `canonicalViewsGenerated`
- `reconstructionReviewRequired`
- `changesRequested`
- `approvedForDesignPreview`
- `failed`
- `rejected`
- `superseded`

---

## 9. 360° Design Preview

### 9.1 Correct customer-facing capability name

The current and planned capability is:

```text
360° Design Preview
```

It is not yet:

```text
360° Garment Simulation
```

and it is not yet:

```text
Virtual Try-On
```

### 9.2 Customer experience

- Original design gallery
- Front, Back and Side selector
- Swipe or drag preview
- Optional auto-rotation
- Zoomable design details
- Original Design and SuiSakhi Assisted View distinction
- Accessible non-motion fallback

### 9.3 Customer-facing terminology

Use:

- `Original Design`
- `SuiSakhi Assisted View`
- `AI-Assisted Preview`
- `AI-Generated Preview`

Do not show customers raw technical values such as confidence `0.47`, probability `62%`, or an internal threshold. Technical scores remain available to Admin, developers and review tools.

### 9.4 Display readiness

- `originalDesignOnly`
- `assistedCanonicalViewsReady`
- `turntableDesignPreviewReady`
- `interactiveStructuredPreviewReady`

The customer UI uses the highest approved readiness level. A pending or rejected generated view never replaces an approved Original Design.

---

## 10. Multi-View Visual Design Consistency Gate

Before a generated view becomes customer-ready, the engine validates visual consistency across supplied and generated views.

### 10.1 Required consistency dimensions

- Neckline style
- Sleeve type
- Silhouette
- Approximate visual proportion or visual length category
- Major embellishment placement
- Closure style and placement
- Garment-piece composition
- Border continuity
- Major panel or yoke continuity
- Material-region continuity where assignments exist

### 10.2 Correct visual validation

```text
Front design appears cropped or waist-length
→ Generated Back maintains the same visual proportion
```

### 10.3 Incorrect physical validation

```text
Front design = 15 inches
→ Generated Back must be 15 inches
```

The engine validates visual design consistency, not physical dimensions.

### 10.4 Example failures

```text
Front: Full sleeve
Generated Side: Sleeveless
→ Consistency Review Required
```

```text
Front: One-piece dress
Generated Back: Separate blouse and skirt
→ Consistency Review Required
```

```text
Front: Major central embroidery
Generated Back: Same embroidery copied without evidence
→ Hidden Detail Review Required
```

### 10.5 Statuses

- `designConsistencyPending`
- `designConsistencyPassed`
- `designConsistencyReviewRequired`
- `designConsistencyFailed`

---

## 11. Garment-piece model

- `upperGarment`
- `lowerGarment`
- `onePieceGarment`
- `dupattaOrStole`
- `outerLayer`
- `lining`
- `underskirtOrPetticoat`
- `detachableComponent`
- `accessoryComponent`
- `unknownPiece`

Each piece receives a stable `pieceId` and independent view, mask, semantic and material-assignment records.

---

## 12. Industry-aligned structural masks

Front, Back and Side remain view types. Masks describe visual regions inside a governed view.

### 12.1 Silhouette and body

- `silhouette`
- `mainBody`
- `bodice`
- `skirtBody`
- `bottomBody`
- `frontPanel`
- `backPanel`
- `centerPanel`
- `sidePanelLeft`
- `sidePanelRight`
- `yokeFront`
- `yokeBack`
- `waistband`
- `peplum`
- `basque`

### 12.2 Sleeve and arm region

- `sleeveLeft`
- `sleeveRight`
- `sleeveCombined`
- `upperSleeve`
- `underSleeve`
- `sleeveCap`
- `armholeLeft`
- `armholeRight`
- `cuffLeft`
- `cuffRight`
- `sleevePlacketLeft`
- `sleevePlacketRight`

### 12.3 Neck and collar region

- `necklineFront`
- `necklineBack`
- `neckband`
- `collar`
- `collarStand`
- `lapelLeft`
- `lapelRight`
- `facing`

### 12.4 Edge and finish region

- `hem`
- `hemBorder`
- `neckBorder`
- `sleeveBorderLeft`
- `sleeveBorderRight`
- `waistBorder`
- `sideBorderLeft`
- `sideBorderRight`
- `piping`
- `binding`
- `trim`
- `frillOrRuffle`
- `laceRegion`

### 12.5 Opening and closure region

- `centerFrontOpening`
- `centerBackOpening`
- `sideOpening`
- `placket`
- `zipper`
- `buttonRegion`
- `buttonholeRegion`
- `hookAndEyeRegion`
- `tieOrDrawcord`
- `slitOrVent`

### 12.6 Functional components

- `pocketLeft`
- `pocketRight`
- `pocketCombined`
- `pocketFlapLeft`
- `pocketFlapRight`
- `belt`
- `beltLoopRegion`
- `hood`
- `gusset`
- `godet`
- `flounce`
- `panelInsert`

---

## 13. Surface-design and visual-material masks

- `baseFabricRegion`
- `contrastFabricRegion`
- `printRegion`
- `motifRegion`
- `embroideryRegion`
- `appliqueRegion`
- `beadOrStoneRegion`
- `sequinRegion`
- `mirrorWorkRegion`
- `zariRegion`
- `cutworkRegion`
- `sheerRegion`
- `liningVisibleRegion`
- `textureRegion`
- `gradientOrShadingRegion`

Surface-design regions may overlap structural masks.

---

## 14. Construction and pattern-guidance candidates

The engine may identify visible construction candidates such as:

- `seamLine`
- `cuttingLine`
- `foldLine`
- `grainline`
- `centerFrontLine`
- `centerBackLine`
- `dart`
- `pleat`
- `gatherLine`
- `styleLine`
- `stitchLine`
- `topstitchLine`
- `placementLine`
- `notch`
- `matchingPoint`
- `buttonPoint`
- `buttonholeLine`
- `zipperPlacement`
- `pocketPlacement`
- `annotation`

These remain visual candidates. ARCH-CAT-007 does not convert these candidates into manufacturing authority.

---

## 15. Layer applicability

### Requirement

- `required`
- `optional`
- `notApplicable`

### Observation state

- `present`
- `missing`
- `notApplicable`
- `notVisible`
- `uncertain`

### Review status

- `notReviewed`
- `reviewRequired`
- `changesRequested`
- `corrected`
- `approved`
- `rejected`
- `notRequired`

Examples:

- Sleeveless design: sleeve layer is `notApplicable`.
- Back neckline in a Front-only original: `notVisible`.
- Low-contrast border candidate: `uncertain` and `reviewRequired`.

---

## 16. Structured SVG

### 16.1 Purpose

- Editable approved design geometry
- Component highlighting
- Controlled recoloring
- Material-region visualization support
- Semantic anchors
- Controlled design customization
- Future downstream preparation

### 16.2 Group model

```text
svg
├── metadata
└── views
    └── {viewId}
        └── pieces
            └── {pieceId}
                ├── structural
                ├── surfaceDesign
                ├── constructionCandidates
                └── annotations
```

### 16.3 Statuses

- `notRequested`
- `queued`
- `generating`
- `reviewRequired`
- `changesRequested`
- `approved`
- `failed`
- `rejected`
- `superseded`

An approved SVG is linked to approved mask revisions.

---

## 17. Design Semantics

Masks answer **where** a feature exists. Design Semantics answer **what** the feature represents.

### 17.1 Categories

- Neck style
- Sleeve style
- Silhouette style
- Visual length category
- Hem style
- Closure style
- Surface and embellishment style
- Fit and structure style
- Occasion metadata

### 17.2 Example semantic values

Neck:

- `roundNeck`
- `boatNeck`
- `vNeck`
- `squareNeck`
- `sweetheartNeck`
- `halterNeck`
- `keyholeNeck`
- `offShoulderNeck`
- `highNeck`
- `mandarinCollar`

Sleeve:

- `sleeveless`
- `capSleeve`
- `shortSleeve`
- `elbowSleeve`
- `threeQuarterSleeve`
- `fullSleeve`
- `puffSleeve`
- `bellSleeve`
- `bishopSleeve`
- `raglanSleeve`
- `flutterSleeve`
- `coldShoulderSleeve`

Silhouette:

- `straight`
- `aLine`
- `fitAndFlare`
- `anarkali`
- `umbrella`
- `mermaid`
- `empireLine`
- `princessLine`
- `peplumStyle`
- `bodycon`
- `flared`

Embellishment:

- `printed`
- `embroidered`
- `zariWork`
- `mirrorWork`
- `stoneWork`
- `sequinWork`
- `beadWork`
- `appliqueWork`
- `cutwork`
- `laceWork`
- `patchwork`
- `plainOrSolid`

Occasion codes reference the existing centrally governed SuiSakhi Occasion Metadata foundation.

### 17.3 Governance

- Designer-declared semantics remain preserved.
- AI-detected semantics include internal provenance and confidence.
- Conflicts create a review task rather than silently replacing approved data.
- Customer-facing labels use centrally managed codes and templates.

---

## 18. Material Assignment Map

Material Assignment is metadata, not a new mask type.

### 18.1 Example

```text
Blouse
├── Main Body → Fabric A
├── Sleeve → Fabric B
├── Border → Fabric C
└── Embroidery → Preserve
```

### 18.2 Example metadata

```json
{
  "pieceId": "upperGarment_1",
  "assignments": [
    {
      "targetLayerCodes": ["mainBody"],
      "materialReferenceId": "fabric-a",
      "assignmentType": "baseMaterial"
    },
    {
      "targetLayerCodes": ["sleeveLeft", "sleeveRight"],
      "materialReferenceId": "fabric-b",
      "assignmentType": "contrastMaterial"
    },
    {
      "targetLayerCodes": ["hemBorder", "neckBorder"],
      "materialReferenceId": "fabric-c",
      "assignmentType": "borderMaterial"
    },
    {
      "targetLayerCodes": ["embroideryRegion"],
      "assignmentType": "preserveDesignDetail"
    }
  ]
}
```

### 18.3 Governance

- Material assignments reference uploaded or governed Fabric Metadata.
- A material assignment does not alter the approved structural mask.
- Customer-selected fabric remains order-owned information.
- Preview assignments may be temporary until the customer confirms the order fabric.
- Assignment changes retain audit history.

---

## 19. Material/Fabric Preview

Material visualization is material-aware, not color replacement only.

A meaningful fashion preview may consider:

- Color
- Print or motif scale
- Texture
- Surface shine
- Reflectance
- Transparency or sheerness
- Drape impression
- Fabric fall
- Region direction or grain appearance
- Preservation of embroidery and borders

A red cotton preview and a red silk preview must not be treated as equivalent merely because the color is identical.

### 19.1 Current boundary

C1.4 reserves and structures material-aware preview. It does not claim physically accurate fabric simulation.

### 19.2 Fabric Estimation integration

The Material Assignment Map and approved Design Semantics may later provide governed inputs to the existing Fabric Estimation Engine. The Fabric Estimation Engine remains independent and may additionally use relevant order and customer information that is outside ARCH-CAT-007.

---

## 20. Future Virtual Try-On reservation

Virtual Try-On is not part of the 360° Design Preview engine.

Future Virtual Try-On consumes:

```text
Approved Design Representation
+
Approved or selected Material Representation
+
Future Customer Image or Avatar
+
Future Pose and Customer Representation
        ↓
AI Virtual Try-On
```

### 20.1 Reserved future customer concepts

- Customer image or avatar
- Pose
- Customer representation
- Body-region handling
- Garment-to-customer alignment
- Occlusion handling
- Privacy and consent
- Generated-output provenance

### 20.2 Important exclusions

- No customer-body processing in C1.4
- No body-measurement inference in C1.4
- No Catalogue measurement input
- No claim of exact fit
- No claim of physical fabric behavior

### 20.3 Modular rule

Virtual Try-On consumes approved outputs from this architecture but remains a separate engine and future architecture.

---

## 21. Customer Order flow

```text
Customer selects approved Design
        ↓
Customer uploads or selects Fabric
        ↓
Material/Fabric Preview when supported
        ↓
Future AI Virtual Try-On when supported
        ↓
Customer adds customization note, if any
        ↓
Measurement finalisation by Tailor
        ↓
Tailor reviews approved design, material and notes
        ↓
Stitching
```

Measurement finalisation remains with the Tailor/order workflow and does not modify the generic Catalogue design.

---

## 22. Customer experience progression

```text
SuiSakhi Design
        ↓
360° Design Preview
        ↓
"Looks beautiful"
        ↓
Upload or select Fabric
        ↓
Material/Fabric Preview
        ↓
"I can imagine it"
        ↓
Future AI Try-On
        ↓
"I can see myself"
        ↓
Customization note and design finalisation
        ↓
"This is my design"
        ↓
Tailor reviews design before stitching
```

---

## 23. Storage architecture

The live C1.3 paths remain unchanged. New outputs are versioned and additive.

```text
catalogue_designs/{designId}/versions/{versionId}/
├── views/{sourceViewId}/
│   ├── original/source.{ext}
│   ├── normalized/preview.webp
│   ├── thumbnails/card.webp
│   └── structured/manifest.json
├── reconstructed_views/{profileCode}/revisions/{revisionId}/
│   ├── front/preview.webp
│   ├── back/preview.webp
│   ├── left_side/preview.webp
│   ├── right_side/preview.webp
│   ├── turntable/frame_000.webp
│   └── reconstruction_manifest.json
├── masks/{profileCode}/revisions/{revisionId}/
│   ├── views/{viewId}/pieces/{pieceId}/
│   │   ├── silhouette.webp
│   │   ├── main_body.webp
│   │   └── ...
│   └── mask_manifest.json
└── structured_svg/{profileCode}/revisions/{revisionId}/
    ├── structured.svg
    └── svg_manifest.json
```

Original, generated, corrected, approved, rejected and superseded revisions remain auditable.

---

## 24. Firestore architecture

### 24.1 Existing Design/View anchor

```text
designs/{designId}/versions/{versionId}/views/{viewId}
```

### 24.2 Revision subcollections

```text
designs/{designId}/versions/{versionId}/multiview_revisions/{revisionId}
```

```text
designs/{designId}/versions/{versionId}/views/{viewId}/segmentation_revisions/{revisionId}
```

```text
designs/{designId}/versions/{versionId}/views/{viewId}/svg_revisions/{revisionId}
```

```text
designs/{designId}/versions/{versionId}/semantic_revisions/{revisionId}
```

```text
designs/{designId}/versions/{versionId}/material_assignment_revisions/{revisionId}
```

### 24.3 Audit fields

- `revisionId`
- `parentRevisionId`
- `sourceGeneration`
- `sourceViewIds`
- `profileCode`
- `profileVersion`
- `engine`
- `engineVersion`
- `status`
- `createdByType`
- `createdByUid`
- `createdAt`
- `submittedAt`
- `reviewedByUid`
- `reviewedAt`
- `reviewReasonCode`
- `reviewComments`
- `approvedAt`
- `supersededAt`
- `lastUpdatedByUid`
- `updatedAt`

---

## 25. Manifest Version 2

Manifest V2 extends but does not overwrite the live raster Manifest V1.

```json
{
  "schemaVersion": "2.0",
  "sourceManifestVersion": "1.0",
  "profileCode": "suisakhiStructuredDesignV1",
  "profileVersion": "1.3.0",
  "inputType": "designerCatalogueDesign",
  "sourceGeneration": "storage-generation",
  "inputViews": [],
  "generatedViews": [],
  "garmentPieces": [],
  "maskSummary": {},
  "structuredSvg": {},
  "designSemantics": [],
  "materialAssignments": [],
  "visualConsistency": {
    "status": "designConsistencyPending",
    "warnings": []
  },
  "customerReadiness": "originalDesignOnly",
  "audit": {
    "createdAt": "ISO-8601",
    "engine": "suisakhi-architecture-engine",
    "engineVersion": "1.0.0-local-prototype"
  }
}
```

---

## 26. Governance and approval

```text
Generated revision
→ Review required
→ Approve, reject or request changes
→ Corrected child revision
→ Review
→ Approved revision becomes active
```

Rules:

- Original uploads are immutable.
- Generated revisions are immutable.
- Corrections retain parent linkage.
- Currently approved representation remains active during a newer review.
- Admin retains final approval.
- Central reason codes and notification templates are used.
- Views, masks, SVG, semantics and material assignments may be reviewed independently.
- An unrelated approved Original Design remains available when one generated layer fails.

---

## 27. Quality gates

### 27.1 Source-view gates

- Image decodes successfully
- View type recognized or marked unclassified
- Combined views split or flagged
- Dimensions and checksum recorded
- Garment pieces reviewable

### 27.2 Generated-view gates

- Supplied-source provenance retained
- Generated dimensions valid
- Visual consistency status recorded
- Hidden details marked as inferred or uncertain internally
- Original view never overwritten
- Customer display requires approved readiness

### 27.3 Mask gates

- Mask dimensions match normalized view
- Required masks are not empty or accidental full-frame masks
- Applicability and state are consistent
- Every garment piece has a silhouette candidate
- Checksums and engine/profile versions recorded

### 27.4 SVG gates

- SVG renders successfully
- View, piece and layer identifiers are valid
- Complexity thresholds respected
- Approved SVG linked to approved masks

### 27.5 Semantic gates

- Semantic code exists in governed metadata
- Designer/AI conflicts create review
- Customer labels use centrally governed codes

### 27.6 Material gates

- Material assignment targets valid piece/layer codes
- Referenced fabric exists
- Preserved design details remain preserved
- Preview does not claim physical simulation

---

## 28. Failure and warning codes

### Multi-view

- `MVR_SOURCE_NOT_FOUND`
- `MVR_SOURCE_DECODE_FAILED`
- `MVR_VIEW_TYPE_UNSUPPORTED`
- `MVR_COMBINED_VIEW_SPLIT_FAILED`
- `MVR_INSUFFICIENT_EVIDENCE`
- `MVR_RECONSTRUCTION_FAILED`
- `MVR_OUTPUT_INVALID`
- `MVR_CLAIM_LOST`

Warnings:

- `MVR_FRONT_ONLY_INFERENCE`
- `MVR_BACK_ONLY_INFERENCE`
- `MVR_HIDDEN_DETAIL_UNCERTAIN`
- `MVR_OPPOSITE_SIDE_INFERRED`
- `MVR_ASYMMETRY_REVIEW_REQUIRED`
- `MVR_LOW_CONFIDENCE_VIEW`
- `MVR_MANUAL_CORRECTION_REQUIRED`

### Visual consistency

- `CONSISTENCY_NECKLINE_MISMATCH`
- `CONSISTENCY_SLEEVE_MISMATCH`
- `CONSISTENCY_SILHOUETTE_MISMATCH`
- `CONSISTENCY_VISUAL_PROPORTION_MISMATCH`
- `CONSISTENCY_EMBELLISHMENT_MISMATCH`
- `CONSISTENCY_CLOSURE_MISMATCH`
- `CONSISTENCY_GARMENT_PIECE_MISMATCH`
- `CONSISTENCY_BORDER_MISMATCH`

### Masks and SVG

- `SEG_PROFILE_NOT_FOUND`
- `SEG_REQUIRED_LAYER_EMPTY`
- `SEG_MASK_DIMENSION_MISMATCH`
- `SEG_MASK_INVALID`
- `SEG_ENGINE_FAILED`
- `SVG_SOURCE_REVISION_NOT_APPROVED`
- `SVG_TOPOLOGY_INVALID`
- `SVG_RENDER_FAILED`

### Semantics and material

- `SEM_UNKNOWN_CODE`
- `SEM_LOW_CONFIDENCE`
- `SEM_DESIGNER_AI_CONFLICT`
- `MAT_REFERENCE_NOT_FOUND`
- `MAT_TARGET_LAYER_INVALID`
- `MAT_PREVIEW_UNSUPPORTED`
- `MAT_REVIEW_REQUIRED`

---

## 29. Backward compatibility

1. C1.3 raster Manifest remains `schemaVersion: 1.0`.
2. C1.4 structured Manifest uses `schemaVersion: 2.0`.
3. Existing preview and thumbnail assets remain valid.
4. Existing `structuredSvgAsset: null` remains valid until approval.
5. Existing mobile clients continue using `bestPreviewUrl`.
6. New outputs use profile- and revision-specific paths.
7. No C1.4 process deletes or overwrites live C1.3 assets.
8. Customer Reference Designs remain unaffected.
9. Measurement and Fabric Estimation engines remain independent.

---

## 30. Local implementation roadmap

### C1.4B-1: Designer source-view foundation

- Front-only
- Back-only
- Front/Back
- Front/Side
- Front/Back/Side
- Combined views
- Detail views
- Multi-piece inputs
- Deterministic source inventory
- No Firebase access

### C1.4B-2: Controlled missing-view proposal prototype

- Simple normalized monochrome line drawing
- Local canonical-view proposals
- Provenance and uncertainty
- Local reconstruction manifest
- No customer publication

### C1.4B-3: Mask prototype

- Silhouette
- Main body
- Neckline
- Sleeve candidates when applicable
- Mask metrics
- Local tests

### C1.4B-4: Structured SVG prototype

- Contour extraction
- Path simplification
- Piece and layer groups
- Render validation

### C1.4B-5: Design Semantics prototype

- Neck style
- Sleeve style
- Silhouette
- Visual length category
- Embellishment presence

### C1.4B-6: Material Assignment prototype

- Region-to-fabric metadata
- Preserve embroidery or border rules
- Simple material-aware preview experiment
- No physical-fabric claim

### C1.4C: Review tools

- Compare Original Design and SuiSakhi Assisted View
- Approve, reject or request changes
- Correct view type, pieces, masks, semantics and material assignments

### C1.4D: Cloud integration

Only after local architecture, tests, manual review, backward compatibility and deployment gates pass.

---

## 31. Cloud integration gate

No C1.4 code is added to the live worker until:

- This architecture is approved and frozen
- Source-view and garment profile contracts are approved
- Local tests pass
- Representative outputs are manually reviewed
- Customer terminology is approved
- Storage and Firestore rules are reviewed separately
- Existing C1.3 tests remain green
- Live C1.3 output remains unchanged
- Explicit backup, commit and tag exist
- Deployment remains limited to the named Catalogue worker

---

## 32. Final architecture decision summary

**ARCH-CAT-007 v1.3 decision:** SuiSakhi will implement a simple, modular and audit-first Architecture Engine for monochrome Designer Catalogue Designs. The engine consumes only the design views supplied by a Designer or Admin, proposes missing design views where appropriate, validates visual design consistency, creates component masks, prepares structured SVG, derives governed Design Semantics, supports a metadata-based Material Assignment Map, and produces an approved 360° Design Preview and future material-aware preview.

Designer Catalogue Design, Customer Reference Design, Measurement, Fabric Estimation, Customer Order and future Virtual Try-On remain separate capabilities with explicit integration boundaries. The 360° Design Preview does not consume customer measurements and does not claim physical garment simulation or body fit. Future Virtual Try-On will consume an approved Design Representation, an approved or selected Material Representation and a separate future Customer Representation.

---

## 33. Final review checklist

- [x] Designer Catalogue input clarified
- [x] Front, Back, Side and multi-view inputs covered
- [x] Missing design-view proposal covered
- [x] Design input separated from measurement input
- [x] Visual proportion separated from physical dimension
- [x] Customer Reference Design kept reference-only
- [x] 360° Design Preview terminology adopted
- [x] Multi-View Visual Design Consistency Gate included
- [x] Masks and structured SVG included
- [x] Design Semantics included
- [x] Material Assignment Map included as metadata
- [x] Material-aware preview direction included
- [x] Fabric Estimation Engine kept independent
- [x] Customer Order flow kept independent
- [x] Future Virtual Try-On reserved modularly
- [x] No body-measurement inference in C1.4
- [x] Customer-friendly AI terminology included
- [ ] Final Owner approval
- [ ] Rename to FINAL
- [ ] Copy into repository `doc/`
- [ ] Update project context and Catalogue recovery documents
- [ ] Commit and tag architecture freeze
- [ ] Authorize C1.4B local coding
