# ARCH-CAT-010: SuiSakhi AI Reconstruction Engine

**Version:** 1.0
**Status:** FROZEN
**Freeze date:** 26 September 2026
**Pilot target:** 14 October 2026
**Architecture domain:** Catalogue Intelligence, AI Reconstruction, Multi-View Foundation, Legacy Asset Readiness
**Evidence baseline:** C1.4E-2C Runs 002 to 005
**Document owner:** SuiSakhi Architecture Governance

---

## 1. Architecture Decision Summary

SuiSakhi shall implement an AI Reconstruction Engine that transforms uploaded garment designs into progressively AI-ready fashion assets.

The engine shall not treat direct Front-image-to-Back-image conversion as the primary reconstruction method. Controlled experiments demonstrated that Front pixels preserve Front-specific construction, even when a Back structural guide is supplied.

The approved research and product direction is:

```text
Design Asset
    ↓
Asset Normalization
    ↓
Boundary and Mask Extraction
    ↓
View Classification
    ↓
Garment Semantic Extraction
    ↓
Hidden-View Structural Proposal
    ↓
AI Structural Generation
    ↓
Automated Validation
    ↓
Mandatory Human Review
    ↓
Approved Generated Candidate
```

### Frozen decision

```text
Direct Front-pixel viewpoint conversion:
REJECTED AS PRIMARY ARCHITECTURE

Semantic and structural hidden-view generation:
APPROVED AS RESEARCH AND PILOT DIRECTION
```

---

## 2. Purpose

The SuiSakhi AI Reconstruction Engine provides the architectural foundation for:

- AI-powered design visualization
- Back-view candidate generation
- Future Left and Right view generation
- Garment semantic understanding
- AI-ready catalogue storage
- Fabric and material visualization
- Boundary-aware rendering
- Future virtual try-on
- Future construction intelligence
- Future pattern-assistance workflows
- Legacy catalogue enrichment without re-upload

The engine is a differentiating SuiSakhi capability intended to provide customers with greater confidence before stitching.

---

## 3. Customer and Business Value

Traditional tailoring and online tailoring workflows often provide only one reference image, usually a Front view. Customers cannot reliably understand:

- How the Back will appear
- Whether sleeves, cuffs, collars, or hems will remain consistent
- Whether the tailor has interpreted the reference correctly
- How a selected fabric may apply to the garment structure
- What the expected finished garment may look like

SuiSakhi shall differentiate itself through an AI Design Assistant that provides governed generated design previews before stitching.

### Pilot value proposition

```text
Upload or select a design
        ↓
Understand garment semantics
        ↓
Generate a Back-view suggestion
        ↓
Review the generated candidate
        ↓
Use the reviewed design during order discussion
```

Generated views are suggestions, not guarantees or observed design truth.

---

## 4. Core Architecture Principles

### ARCH-CAT-010-P01: Progressive AI readiness

Every garment asset shall become progressively AI-ready from the day of upload.

### ARCH-CAT-010-P02: Legacy compatibility

Assets uploaded during the pilot shall remain usable by future AI, multi-view, SVG, fabric-mapping, and virtual try-on capabilities without mandatory customer or partner re-upload.

### ARCH-CAT-010-P03: Original preservation

The original uploaded file shall remain immutable. Derived assets shall never overwrite the original asset.

### ARCH-CAT-010-P04: Generated provenance

Every generated result shall be explicitly identified as a generated candidate.

### ARCH-CAT-010-P05: No automatic truth promotion

Generated candidates shall never automatically become observed truth, approved design truth, or production catalogue truth.

### ARCH-CAT-010-P06: Mandatory review

Every AI-generated candidate shall enter a governed review lifecycle.

### ARCH-CAT-010-P07: Versioned derivation

Normalized images, masks, SVG boundaries, semantic metadata, structural guides, prompts, model revisions, and generated outputs shall be versioned.

### ARCH-CAT-010-P08: Reproducibility

Every generation attempt shall record sufficient information to reproduce or explain the result.

### ARCH-CAT-010-P09: Provider independence

Application-level contracts shall not depend directly on one model provider or one local execution runtime.

### ARCH-CAT-010-P10: Pilot scope discipline

The 14 October 2026 pilot shall expose a governed AI Design Assistant, not claim a complete autonomous 360-degree reconstruction system.

---

## 5. Proven Experimental Evidence

## 5.1 Run-002: Prompt-only image-to-image baseline

### Path

```text
Front image
+
Back-view prompt
+
SDXL image-to-image
```

### Outcome

```text
Technical execution: PASS
Requested Back view: FAIL
Decision: REJECTED
```

### Finding

Prompt engineering alone did not remove the Front placket, Front buttons, or Front-view construction.

---

## 5.2 Run-003: Back structural-guide foundation

### Path

```text
Expected Back benchmark reference
        ↓
Aspect-ratio-preserving normalization
        ↓
Canny edge extraction
        ↓
Back structural guide
```

### Outcome

```text
Structural guide: APPROVED
```

### Finding

The generated guide preserved the Back collar, Back yoke, sleeves, cuffs, curved hem, and overall Back silhouette without introducing Front buttons or a Front placket.

### Disclosure

The guide was derived from the known expected Back benchmark reference. It proves structural conditioning feasibility, not unknown Back inference from Front input alone.

---

## 5.3 Run-004: Front pixels with Back ControlNet guide

### Path

```text
Front source pixels
+
Back Canny guide
+
SDXL ControlNet image-to-image
```

### Outcome

```text
Technical execution: PASS
Requested Back view: FAIL
Decision: REJECTED
```

### Finding

Front source pixels dominated the structural guide and preserved the Front placket and Front buttons.

---

## 5.4 Run-005: Structural Back generation without Front pixels

### Path

```text
Shared garment semantics
+
Back Canny structural guide
+
SDXL ControlNet text-to-image
+
No Front source pixels
```

### Outcome

```text
Technical execution: PASS
Back view achieved: PASS
Decision: CHANGES REQUESTED
```

### Candidate integrity

```text
SHA-256:
0bdda8b0ecb22f499cf859f9e10d2d5dfa3a9243e4a3c46860f7e39b8bfe93b8
```

### Passed checks

- Back view achieved
- Front placket absent
- Front buttons absent
- Back yoke represented
- Garment type preserved
- Sleeve family preserved
- Cuff family preserved
- Curved hem preserved

### Changes requested

- Remove the circular Back-panel artifact
- Remove the grid or drafting-paper background
- Improve collar fidelity
- Improve garment proportions
- Produce a clean white catalogue background

### Architecture conclusion

Back-view feasibility is proven when shared garment semantics are combined with hidden-view structural guidance and Front source pixels are excluded from the generation path.

---

## 6. AI Reconstruction Engine Layers

## 6.1 Layer 1: Asset Intake

### Supported sources

- Designer uploads
- Admin uploads
- Partner catalogue uploads
- Customer reference images
- Licensed catalogue imports
- Governed social-reference imports
- Future marketplace assets

### Required stored data

- Original immutable asset
- Asset ownership and usage rights
- Uploading account and profile
- Upload timestamp
- Source type
- Declared garment category
- Declared view when known
- Original MIME type
- Original dimensions
- Original SHA-256

---

## 6.2 Layer 2: Normalization

Each accepted image shall produce versioned derived assets.

### Pilot normalization outputs

- Orientation-corrected image
- Standard color space
- Transparent or normalized background where supported
- Bounded maximum resolution
- Presentation thumbnail
- AI-processing image
- Normalized SHA-256
- Derivation manifest

### Rules

- Preserve aspect ratio
- Prefer padding over geometric stretching
- Do not overwrite the original
- Record transformation parameters
- Preserve transparent-source information when available

---

## 6.3 Layer 3: Legacy AI-Readiness

Every catalogue asset should gradually receive the following derived artifacts.

### Pilot minimum

```text
Original image
Normalized image
Foreground mask
Outer garment boundary
Boundary SVG
Bounding box
View classification
Basic garment semantics
```

### Future enrichment

```text
Semantic SVG
Panel boundaries
Collar region
Sleeve regions
Cuff regions
Body region
Hem region
Seam proposals
Construction lines
Material regions
Pattern-assistance metadata
```

### Critical legacy rule

A Pilot-era asset may be reprocessed by newer AI engines. Derived assets must be append-only and versioned so older catalogue records can benefit from later capabilities without re-upload.

---

## 6.4 Layer 4: Boundary SVG Foundation

### Purpose

The boundary SVG provides a model-neutral, scalable geometric representation for future visualization and material workflows.

### Pilot boundary SVG scope

The initial SVG may contain only:

- Canvas metadata
- Garment outer contour
- View identifier
- Bounding box
- Coordinate system
- Source image linkage
- Boundary confidence
- Derivation version

### Non-goals for Pilot

The Pilot boundary SVG is not a tailoring pattern and does not claim construction accuracy.

### Future uses

- Fabric texture clipping
- Colour replacement
- Garment-background isolation
- Design comparison
- Structural-guide generation
- Multi-view alignment
- Virtual try-on preparation
- Semantic-panel enrichment

### SVG governance

Store:

```text
svgAssetId
sourceAssetId
sourceAssetVersion
boundaryVersion
coordinateSystem
canvasWidth
canvasHeight
view
confidence
createdByEngine
engineVersion
reviewStatus
createdAt
```

---

## 6.5 Layer 5: View Classification

### Supported view states

- Front
- Back
- Left
- Right
- Three-quarter Front
- Three-quarter Back
- Detail
- Unknown
- Ambiguous

### Rules

- Do not force a confident view when evidence is insufficient
- Record model confidence and review status
- Permit Admin correction
- Preserve the original model prediction in the audit record

---

## 6.6 Layer 6: Garment Semantics

The semantics layer shall use the existing C1.4E-2A foundation and expand through versioned metadata.

### Core semantic attributes

- Garment category
- Dress type
- Wear type
- Collar family
- Neckline family
- Sleeve family
- Sleeve length
- Cuff family
- Body silhouette
- Fit family
- Hem family
- Closure type
- Back-yoke presence
- Fabric category
- Occasion category
- Construction notes
- Visible decorations
- Unknown or inferred attributes

### Semantic authority states

```text
Observed
Declared
Inferred
Generated
Reviewer-confirmed
Unknown
```

Inferred or generated semantics shall not be stored as observed truth.

---

## 6.7 Layer 7: Hidden-View Structural Proposal

### Purpose

Generate or retrieve a candidate structure for an unobserved view before visual generation.

### Pilot benchmark method

The benchmark may use a structure derived from a known expected Back reference for controlled evaluation.

### Production proposal sources

- Garment-category templates
- Construction-rule library
- Semantic SVG templates
- Approved existing designs
- Partner-provided structure
- Admin-selected structural template
- Future dedicated structural proposal model

### Required disclosure

Each guide shall record whether the guide came from:

```text
Observed source
Expected benchmark reference
Template library
Generated proposal
Partner input
Admin input
```

---

## 6.8 Layer 8: AI Generation

### Validated research stack

```text
Stable Diffusion XL Base 1.0 FP16
+
ControlNet Canny SDXL FP16
+
Apple MPS
```

### Product abstraction

The application shall call a provider-independent reconstruction contract.

The product contract shall support:

- Model provider
- Model identifier
- Model revision
- Adapter identifier
- Adapter revision
- Prompt version
- Negative-prompt version
- Seed
- Structural-guide version
- Semantic-manifest version
- Output count
- Execution location
- Generation status
- Failure code

### Output rule

Every output begins as:

```text
provenance = generated
reviewStatus = reviewRequired
customerVisible = false
productionAllowed = false
```

---

## 6.9 Layer 9: Automated Validation

### Pilot validation checks

- Output file exists
- Output MIME type is allowed
- Output dimensions are valid
- Output SHA-256 generated
- One candidate produced when one is requested
- Target-view classifier result
- Front-placket detection
- Front-button detection
- Back-yoke detection
- Background-cleanliness check
- Unexpected-artifact check
- Semantic-family consistency

### Validation outcome

Automated validation may recommend a decision but shall not automatically approve a generated design during the Pilot.

---

## 6.10 Layer 10: Review and Governance

### Review states

```text
reviewRequired
approved
changesRequested
rejected
```

### Required review information

- Reviewer identity
- Review timestamp
- Decision
- Primary reason code
- Secondary reason codes
- Reviewer notes
- Previous candidate linkage
- Replacement candidate linkage

### Governance records

- Original source checksum
- Normalized source checksum
- Mask checksum
- SVG checksum
- Structural-guide checksum
- Generated output checksum
- Model and adapter revisions
- Prompt and negative-prompt versions
- Seed
- Execution environment
- Review decision
- Customer visibility state
- Production approval state

---

## 7. Pilot Scope for 14 October 2026

## 7.1 Included

- Designer and Admin catalogue upload
- Original asset preservation
- Normalized AI-processing asset
- Basic foreground mask
- Basic external boundary or SVG contour
- View classification
- Garment semantics
- Fabric estimation integration
- Back-view suggestion for supported designs
- Generated-candidate provenance
- Mandatory review workflow
- Admin or authorized reviewer decision
- Candidate comparison and audit evidence
- Safe fallback when generation is unavailable

## 7.2 Pilot presentation

The customer-facing feature should be described as:

```text
AI Design Assistant
AI-Powered Design Preview
Generated Back-View Suggestion
```

Avoid claiming:

```text
Guaranteed true Back view
Perfect 360-degree reconstruction
Production tailoring pattern
Observed hidden design truth
```

## 7.3 Deferred until post-pilot

- Fully automatic 360-degree generation
- Production Left and Right views
- Interactive 3D garment
- Virtual try-on
- Tailoring-pattern generation
- Fabric physics
- Sewing simulation
- Autonomous approval
- Unreviewed customer publication

---

## 8. Legacy Data Adoption Strategy

### Day-one rule

All catalogue records shall use stable identifiers and versioned derived-asset references.

### Recommended asset structure

```text
catalogueAsset
├── original
├── normalizedVersions
├── maskVersions
├── boundaryVersions
├── svgVersions
├── semanticVersions
├── structuralGuideVersions
├── generatedCandidateVersions
└── reviewHistory
```

### Reprocessing rule

When a new engine version becomes available:

1. Keep the original asset unchanged.
2. Create a new derived version.
3. Link the new version to its engine and parameters.
4. Do not delete historical derived assets required for audit.
5. Allow Admin review before replacing an approved production version.

### Compatibility rule

Older assets with missing AI fields remain valid. Their AI-readiness status shall indicate what has or has not been generated.

### Suggested readiness states

```text
originalOnly
normalized
boundaryReady
semanticsReady
structureReady
generationReady
reviewed
productionApproved
```

---

## 9. Safety, Rights, and Content Governance

### Required checks before AI processing

- Ownership or permitted usage
- Processing consent where required
- Local-only or production permission
- Customer publication permission
- Model-training permission

### Independent permissions

The following permissions are separate and must not be assumed from one another:

```text
Local evaluation
Automated testing
Generated preview
Customer publication
Production catalogue use
Model training
Commercial redistribution
```

### Fixture-001 limitation

Fixture-001 is SuiSakhi-owned and approved for local evaluation and automated testing. Model-training and customer-publication permissions remain separately governed.

---

## 10. Run-006 Handoff

### Objective

Improve the successful Back-view candidate from Run-005 while preserving Back-view compliance.

### Keep frozen

- SDXL revision
- ControlNet revision
- Text-to-image ControlNet architecture
- No Front source pixels
- Same approved Back Canny guide
- Seed 42 for first comparison
- 512 × 512 resolution
- Offline mode
- One candidate
- Review-required governance

### Initial Run-006 parameters

```text
Inference steps:       12
Guidance scale:        6.0
ControlNet scale:      0.90
Seed:                  42
```

### Negative-prompt additions

```text
grid, graph paper, drafting paper, measurement grid,
construction grid, gray background, textured background,
circular mark, center symbol, annotation, drafting notation,
button on Back panel, emblem, badge, label
```

### Success criteria

- Back view remains achieved
- Front placket remains absent
- Front buttons remain absent
- Back yoke remains represented
- Circular Back-panel artifact removed
- Grid background removed
- Clean white background achieved
- Collar fidelity improved
- Proportion fidelity improved
- Sleeves preserved
- Cuffs preserved
- Curved hem preserved

---

## 11. Implementation Boundaries

### Flutter application

The Flutter application shall not contain direct model-loading logic or large AI dependencies.

### AI execution

AI execution shall remain behind an adapter or service boundary.

### Firebase

No generated artifact shall be uploaded to Firebase until:

1. Production storage architecture is approved.
2. Rights and usage permissions are validated.
3. Review status permits storage or customer visibility.
4. Provenance metadata is complete.

### Local laboratory

The current laboratory is a research environment and is not a production backend.

---

## 12. Decision Log

### Accepted

```text
Semantic-first reconstruction
Structural-guide generation
ControlNet hidden-view generation
Versioned derived assets
Pilot boundary SVG
Mandatory review
Generated provenance
Legacy reprocessing support
```

### Rejected as primary approach

```text
Direct Front-pixel image-to-image viewpoint conversion
Automatic generated-output approval
Overwriting original assets
Treating generated content as observed truth
Unversioned AI metadata
```

### Deferred

```text
Full 360-degree generation
Virtual try-on
3D garment simulation
Pattern generation
Fabric physics
Autonomous review
```

---

## 13. Pilot Readiness Gates

ARCH-CAT-010 implementation may be considered Pilot-ready only when:

- Original asset preservation is verified
- Normalization is repeatable
- Boundary or SVG generation is available for supported assets
- View classification is recorded
- Semantics are versioned
- Generated candidates carry provenance
- Review workflow is enforced
- Rejected candidates remain non-production
- Customer visibility is separately governed
- Model and prompt revisions are recorded
- Failure fallback is defined
- No AI failure blocks the standard tailoring order path

---

## 14. Final Architecture Freeze

```text
Architecture ID:
ARCH-CAT-010

Name:
SuiSakhi AI Reconstruction Engine

Version:
1.0

Status:
FROZEN

Freeze date:
26 September 2026

Pilot target:
14 October 2026
```

### Final finding

```text
Back-view feasibility is proven through garment semantics,
hidden-view structural guidance, and governed ControlNet generation.
```

### Final product direction

```text
SuiSakhi shall build an AI Design Assistant that creates governed,
reviewable fashion-view suggestions while preserving original assets,
legacy compatibility, auditability, and customer trust.
```

---

## 15. Immediate Next Actions

1. Add this frozen architecture document to SuiSakhi documentation.
2. Commit and tag the architecture freeze separately.
3. Copy the reconstruction session summary into the governed documentation area.
4. Define an AI-ready catalogue asset schema and migration rules.
5. Implement or formalize the Pilot boundary SVG contract.
6. Execute Run-006 as a separate immutable experiment.
7. Evaluate Run-006 against the frozen success criteria.
8. Do not begin production integration until storage, review, and provenance contracts are approved.
