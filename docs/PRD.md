# Product Requirements Document

## Product: **Vaultform** — A Native macOS PDF Editor with a Privacy-First AI Autofill Assistant

| | |
|---|---|
| **Version** | 1.0 (Draft) |
| **Date** | July 3, 2026 |
| **Status** | For review |
| **Platform** | macOS 14+ (Apple Silicon–optimized, Intel supported) |

---

## 1. Product Vision

**Every year, people fill out the same information — name, address, passport number, employment history, insurance details — hundreds of times across visa applications, tax forms, medical intake forms, rental agreements, and school enrollments. Today that data either lives in their head, in scattered documents, or in a cloud service they don't control.**

Vaultform is a professional, native macOS PDF editor whose defining capability is a **local-first AI Autofill Assistant**: a structured, encrypted personal knowledge vault that lives entirely on the user's Mac and intelligently fills any PDF form — including scanned, flat, and non-standard forms — in seconds, with full user review and zero data leaving the device.

**Positioning statement:**
> *For privacy-conscious professionals and families who repeatedly fill out complex forms, Vaultform is a native macOS PDF editor that fills any form intelligently using a personal data vault that never leaves your Mac — unlike Adobe Acrobat, which routes AI features through the cloud and charges a subscription for basic editing.*

**Long-term ambition:** Become the default PDF application on macOS — the app people reach for instead of both Preview (too limited) and Acrobat (too heavy, too cloud-dependent, too expensive) — and expand the local vault into the user's canonical "personal data layer" for all document workflows.

**Why now:**
- Apple Silicon + Core ML + on-device foundation models make professional-grade local OCR, entity extraction, and semantic field matching feasible without a server.
- Privacy regulation (GDPR, CCPA, EU AI Act) and consumer sentiment are shifting hard against cloud processing of identity documents.
- Acrobat's move to subscription + cloud AI has created visible churn and an underserved "pro but private" segment.
- macOS Preview has stagnated; the gap between "free but basic" and "$240/yr Acrobat" is wide open.

---

## 2. Goals

### Product goals
1. **G1 — Professional PDF editing:** Deliver a PDF editor covering ≥90% of the everyday Acrobat use cases (view, annotate, edit text/images, organize pages, forms, OCR, redaction, export) with native macOS performance and design.
2. **G2 — Best-in-class form filling:** Fill any form — AcroForm, flat, or scanned — faster and more accurately than any competitor, using the local profile vault.
3. **G3 — Privacy as verifiable architecture, not marketing:** All personal-profile processing happens on-device by default. The user can audit, export, and delete everything. Network access for core features is zero.
4. **G4 — Effortless profile building:** Users build a rich structured profile in minutes by dropping in existing documents (IDs, resumes, prior filled forms, certificates) rather than typing.
5. **G5 — Trustworthy AI:** Every autofilled value is traceable to its source, confidence-scored, and reviewed by the user before commit. No silent writes.

### Business goals
1. **B1:** Reach 100K MAU within 18 months of GA on macOS.
2. **B2:** Achieve ≥5% free-to-paid conversion with a one-time-purchase + optional subscription hybrid model.
3. **B3:** Establish "local-first AI" as the brand wedge before Adobe/Apple close the gap.
4. **B4:** 4.7+ average App Store rating; top-3 ranking in Productivity/PDF category on the Mac App Store.

---

## 3. Non-Goals

Explicitly out of scope (for the foreseeable roadmap unless revisited):

1. **Windows, Linux, or web versions.** macOS-native excellence is the moat. (iOS/iPadOS companion is a *future* consideration, not a commitment — see §10.)
2. **Cloud storage or sync service of our own.** We will not build a Vaultform cloud. Any future sync rides on end-to-end-encrypted iCloud (CloudKit) only.
3. **Real-time multi-user collaboration** (co-editing, shared comments servers). Acrobat/Google territory; contradicts local-first architecture.
4. **Legally certified e-signature workflows** (DocuSign/Adobe Sign equivalents with audit trails, identity verification, compliance certifications). We support *drawing/placing* signatures; we do not become a signature authority in v1.
5. **Full XFA (XML Forms Architecture) support.** Legacy, dying format; render-with-warning only.
6. **PDF creation/authoring suite** (design-from-scratch layout tools à la InDesign).
7. **Being a general password manager or identity wallet.** The vault stores form-relevant personal data; it does not replace 1Password/Apple Passwords.
8. **Automated form *submission*.** We fill and export; we never submit forms to third parties on the user's behalf.
9. **Server-side AI as a default path.** Optional, opt-in, clearly-labeled cloud model access may exist later (§10), but no core feature may *require* it.

---

## 4. User Personas

### P1 — Priya, the Immigration Journey (Primary)
- 31, software engineer in San Francisco on an H-1B, going through green card processing; also managed her parents' visitor visas.
- Fills out **dozens of near-identical government forms** (DS-160, I-485, I-130, G-325A, tax forms) with passport numbers, address history (5 years!), employment history, travel history.
- **Pain:** Retyping the same 40 fields; transcription errors on critical forms; deep distrust of uploading her passport to random "form filler" websites.
- **Needs:** A vault holding identity documents + full history timelines; accurate fill of long, hostile government PDFs; confidence that nothing touches a server.
- **Success looks like:** "I filled my I-485 in 20 minutes instead of 3 hours, and I never worried about where my passport data went."

### P2 — Marcus, the Freelancer / Small-Business Owner (Primary)
- 42, independent contractor (construction consulting), 1099 economy.
- Constantly fills W-9s, insurance certificates, vendor onboarding packets, client contracts, permit applications. Sends 10–20 filled PDFs a month.
- **Pain:** Acrobat subscription feels like a tax; Preview can't handle half the forms clients send; his EIN, insurance policy numbers, and license numbers live in a Notes file.
- **Needs:** Fast fill of business identity (EIN, licenses, insurance, banking), reusable signature, batch handling, one-time purchase pricing.
- **Success looks like:** "Vendor packet arrives, I'm done in 5 minutes, signed and emailed back."

### P3 — Dr. Chen, the Privacy-Bound Professional (Primary)
- 55, physician in private practice (equally: attorney, therapist, accountant).
- Handles credentialing forms, insurance panel applications, CME certificates, hospital privilege renewals — forms containing *her own* extensive professional history (NPI, DEA number, licenses across states, malpractice history).
- **Pain:** Professionally *obligated* to be careful with data; cloud AI tools are a compliance non-starter; forms are long, repetitive, and high-stakes.
- **Needs:** Verifiably offline processing; profile sections for licenses/certifications with expiry tracking; redaction tools she can trust (true content removal, not black boxes).
- **Success looks like:** "I can honestly tell my compliance officer that nothing leaves this machine."

### P4 — Elena, the Family Operations Manager (Secondary)
- 38, parent of two, manages the household's paperwork: school enrollment, camp forms, pediatric intake, DMV, passport renewals for four people.
- **Pain:** Forms ask for *other people's* data (kids' birthdays, allergies, pediatrician, emergency contacts); every school year is a fresh pile of the same forms.
- **Needs:** **Multiple profiles per vault** (self, spouse, each child) with relationship-aware filling ("emergency contact = spouse"); simplicity over pro features.
- **Success looks like:** "Back-to-school paperwork for both kids done in one evening."

### P5 — Sam, the Ops/HR Administrator (Secondary, growth vector)
- 29, HR coordinator at a 60-person company. Prepares offer packets, benefits enrollments, I-9 templates.
- **Pain:** Repetitive company-side data (entity name, EIN, addresses, plan numbers) across every packet; Acrobat licenses are a budget fight.
- **Needs:** An "organization profile," template workflows, page assembly/organization tools.
- **Note:** Sam pulls Vaultform toward team features (future); in v1 she's served as a power individual user.

---

## 5. User Stories

Format: *As a [persona], I want [capability], so that [outcome].* Priority: **[P0]** MVP-critical, **[P1]** MVP-desirable, **[P2]** post-MVP.

### Vault & profile
1. **[P0]** As Priya, I want to create my profile by dragging in my passport, resume, and a previously filled form, so that I don't type 100 fields by hand.
2. **[P0]** As Priya, I want every extracted value to show me the source document snippet it came from, so that I can verify it before trusting it.
3. **[P0]** As Marcus, I want to manually add, edit, and organize profile fields (including custom fields like "Contractor License #"), so that the vault matches my real-world data.
4. **[P0]** As Dr. Chen, I want the vault encrypted at rest and locked behind Touch ID, so that a stolen laptop doesn't mean a stolen identity.
5. **[P0]** As Elena, I want separate profiles for each family member with defined relationships, so that "child's emergency contact" fills with *my* phone number.
6. **[P1]** As Priya, I want the vault to store *history lists* (addresses with date ranges, employers, trips abroad), so that forms demanding "all addresses in the last 5 years" can be filled.
7. **[P1]** As any user, I want to export my entire vault to an open format and delete it completely, so that I'm never locked in.
8. **[P2]** As Dr. Chen, I want expiry tracking on licenses/passports/certifications with reminders, so that I renew before deadlines.

### Autofill
9. **[P0]** As Marcus, I want to open a W-9 and click "Autofill," so that every field I have data for is filled instantly.
10. **[P0]** As any user, I want a review panel showing each proposed value with confidence level and the ability to accept/edit/reject per field, so that I stay in control.
11. **[P0]** As Priya, I want autofill to work on **scanned/flat forms with no interactive fields**, so that government PDFs (the worst offenders) still work.
12. **[P0]** As Elena, I want to choose *which* profile fills a given form (or per-field), so that my daughter's camp form uses her data and my contact info.
13. **[P1]** As any user, I want the assistant to learn from my corrections (locally), so that the same form fills better next time.
14. **[P1]** As Marcus, I want per-form "fill memory," so that reopening last year's version of a form reuses my prior answers.
15. **[P2]** As Priya, I want to ask in natural language ("fill this like my I-130 but with my brother as beneficiary"), so that complex fills get faster.
16. **[P2]** As Sam, I want to batch-fill a folder of PDFs against one profile, so that packet prep scales.

### PDF editing (the editor must stand on its own)
17. **[P0]** As any user, I want fast open/scroll/zoom/search on large PDFs, so that the app never feels worse than Preview.
18. **[P0]** As any user, I want annotations (highlight, underline, strikethrough, notes, freehand, shapes, stamps), so that review workflows are covered.
19. **[P0]** As Marcus, I want to edit existing text and images in a PDF, so that I can fix a typo without the source file.
20. **[P0]** As Sam, I want page operations (reorder, rotate, insert, delete, extract, merge, split), so that document assembly is trivial.
21. **[P0]** As Marcus, I want to create, save, and place my signature and initials, so that sign-and-return is one click.
22. **[P0]** As Dr. Chen, I want OCR on scanned documents, so that they become searchable and fillable.
23. **[P1]** As Dr. Chen, I want true redaction (content removal + metadata scrubbing), so that shared documents leak nothing.
24. **[P1]** As any user, I want to create interactive form fields on any PDF, so that I can turn a flat form into a fillable one.
25. **[P1]** As any user, I want export to Word/images/text and compression/optimization, so that PDFs fit downstream needs.
26. **[P2]** As Sam, I want Bates numbering, headers/footers, and watermarks, so that professional document prep is covered.

### Trust & privacy
27. **[P0]** As Dr. Chen, I want a visible indicator and an auditable log proving no network calls occur during document processing, so that trust is verifiable, not asserted.
28. **[P0]** As any user, I want the app to work fully offline (airplane mode), so that "local-first" is demonstrably true.
29. **[P1]** As Priya, I want per-document "never store anything from this file" mode, so that one-off sensitive documents leave no trace.

---

## 6. Functional Requirements

### FR-1: PDF Engine (Viewer & Editor)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Render PDF 1.4–2.0 with high fidelity: text, vector, raster, transparency, embedded fonts, annotations, layers (OCG). | P0 |
| FR-1.2 | Open, continuous scroll, zoom (fit/width/custom), thumbnails, outline/TOC, full-text search with result highlighting. | P0 |
| FR-1.3 | Annotations per PDF spec (stored as standard annotation objects, interoperable with Acrobat/Preview): highlight, underline, squiggly, strikeout, sticky note, free text, ink, shapes, stamps, links. | P0 |
| FR-1.4 | Content editing: edit/add/delete text blocks with font matching (embedded-font substitution warnings); move/resize/replace/delete images; basic vector object manipulation. | P0 |
| FR-1.5 | Page management: reorder (drag in thumbnail view), rotate, insert (blank/from file), delete, duplicate, extract, split, merge multiple PDFs. | P0 |
| FR-1.6 | Signatures: create by trackpad/camera/typed style; store encrypted in vault; place/resize; flatten on export. | P0 |
| FR-1.7 | OCR: on-device text recognition (Vision framework class accuracy) producing a searchable text layer; ≥12 major Latin-script languages at launch; auto language detection. | P0 |
| FR-1.8 | Forms: render and fill AcroForm fields (text, checkbox, radio, combo, list, date); respect field formatting/validation/JS-lite calculation where safe; tab-order navigation. | P0 |
| FR-1.9 | Form field creation/editing: add interactive fields to any PDF; auto-detect probable fields on flat forms and offer one-click conversion. | P1 |
| FR-1.10 | True redaction: irreversible content removal (text, image regions), metadata/XMP scrubbing, hidden-content (deleted annotations, embedded files) audit. | P1 |
| FR-1.11 | Export: flattened PDF, PDF/A, Word (.docx), plain text, PNG/JPEG per page; file size optimization presets. | P1 |
| FR-1.12 | Password/permission handling: open protected files; apply/remove AES-256 encryption and permissions (with password). | P1 |
| FR-1.13 | XFA forms: detect, warn, render static representation if possible. No dynamic XFA execution. | P2 |

### FR-2: Personal Data Vault

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Structured profile schema with core sections: Identity (names, DOB, POB, nationality, SSN/TIN, passport(s), driver's license), Contact (addresses incl. history w/ date ranges, phones, emails), Employment (history w/ dates, titles, employer addresses, income), Education, Family/Relationships, Financial (bank basics, EIN/business), Health basics (insurance, physician, allergies — optional section), Licenses & Certifications, Travel history, Custom fields/sections. | P0 |
| FR-2.2 | Every field supports: value, type (string/date/number/enum/list), label aliases, source attribution (manual or document+region), confidence, last-verified date, sensitivity tier. | P0 |
| FR-2.3 | Multiple person profiles per vault with typed relationships (spouse, child, parent, emergency contact); one organization/business profile type. | P0 |
| FR-2.4 | Storage: local encrypted database (AES-256-GCM), key wrapped via Secure Enclave/Keychain; unlock via Touch ID / Apple Watch / password; auto-lock on idle (configurable). | P0 |
| FR-2.5 | Sensitivity tiers: Standard, Sensitive (SSN, passport #, financial) — Sensitive fields masked in UI by default, require re-auth to reveal, and require explicit per-fill confirmation. | P0 |
| FR-2.6 | Full vault export (encrypted archive + documented open JSON schema) and one-click secure erase (crypto-shred). | P1 |
| FR-2.7 | Attachment store: original ingested documents kept (optional, per-document) encrypted alongside extracted data. | P1 |
| FR-2.8 | Field expiry metadata + local notifications for expiring documents. | P2 |

### FR-3: Document Ingestion Pipeline

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Accept PDF, DOCX, TXT, RTF, PNG/JPEG/HEIC (photos of documents), with drag-and-drop, file picker, and Continuity Camera capture. | P0 |
| FR-3.2 | Pipeline stages (all on-device): format normalization → OCR (if needed) → document classification (passport, driver's license, resume, filled form, certificate, utility bill, generic) → entity extraction → schema mapping → conflict detection. | P0 |
| FR-3.3 | Entity extraction: names, dates, addresses, ID numbers, phone/email, employers, schools, monetary values — via on-device NER models + document-type-specific extractors (e.g., passport MRZ parsing, license barcode/PDF417 decode). | P0 |
| FR-3.4 | **Mandatory review UI:** extracted fields presented side-by-side with source-image snippets; user accepts/edits/rejects each before anything enters the vault. Nothing is stored without explicit confirmation. | P0 |
| FR-3.5 | Conflict resolution: when a new value differs from an existing one (moved house), prompt to replace, keep both (history), or discard. | P0 |
| FR-3.6 | Ingestion of *previously filled forms*: read AcroForm field values directly (lossless) as a high-confidence profile source. | P0 |
| FR-3.7 | Per-ingestion "ephemeral mode": extract for a one-time fill without persisting anything. | P1 |
| FR-3.8 | Batch ingestion with queued review. | P2 |

### FR-4: AI Autofill Assistant

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | **Field understanding:** For AcroForm fields, use field name, tooltip, format hints, and surrounding page text. For flat/scanned forms, detect fields visually (labels, blank lines, boxes, checkbox glyphs) via on-device layout model + OCR geometry. | P0 |
| FR-4.2 | **Semantic matching:** Map each detected field to vault fields using on-device semantic embedding/LLM matching — must handle label variation ("Surname"/"Family Name"/"Last Name"), abbreviations, multi-language labels (top 5 languages at launch), and composite fields (full name → first+last; address → components). | P0 |
| FR-4.3 | **Formatting adaptation:** Render values to the form's expected format: date formats (MM/DD/YYYY vs DD-MM-YYYY vs separate boxes), phone formats, comb fields (one char per box), checkbox/radio selection from enum values (gender, marital status), state abbreviations. | P0 |
| FR-4.4 | **Review-before-commit:** All proposed fills land in a review panel (sidebar): per-field proposed value, confidence (high/medium/low), source field in vault; accept-all-high-confidence, or per-field accept/edit/reject. Filled values visually badged in-document until user confirms. | P0 |
| FR-4.5 | Profile selection: choose the person (or org) profile for the fill; per-field override for mixed forms (parent + child). | P0 |
| FR-4.6 | Sensitive-field gating: fields mapped from Sensitive-tier data require individual confirmation and Touch ID if vault relock interval passed. | P0 |
| FR-4.7 | Unfillable-field handling: fields with no vault match are listed as "needs your input" with quick-add-to-vault affordance after manual entry. | P0 |
| FR-4.8 | **Local learning loop:** user corrections (field mapping + formatting) stored as local mapping memory keyed by form fingerprint; identical/similar forms improve over time. No model training data leaves device. | P1 |
| FR-4.9 | Form fingerprinting & fill memory: recognize a previously filled form (hash + structure similarity) and offer "restore previous answers." | P1 |
| FR-4.10 | Explainability: any filled value can show "why": source vault field → source document snippet → transformation applied. | P1 |
| FR-4.11 | Natural-language instructions scoped to fill ("use my work address", "fill for my son Leo") interpreted on-device. | P2 |
| FR-4.12 | Batch autofill across multiple documents. | P2 |

### FR-5: Privacy, Transparency & Trust Surface

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Zero network requirement for all P0 features; app fully functional offline forever. | P0 |
| FR-5.2 | Privacy dashboard: what's stored (field counts by section), local processing log (what was ingested/filled, when), network activity disclosure (should read: none, or enumerate exactly: update check, license validation — each toggleable). | P0 |
| FR-5.3 | App Sandbox + Hardened Runtime + notarization; no analytics SDK that can touch document or vault content; crash reports opt-in and content-scrubbed. | P0 |
| FR-5.4 | All AI inference on-device (Core ML / Apple Foundation Models). If a future opt-in cloud model tier exists, it must be off by default, per-action consented, visually distinct, and blocked for Sensitive-tier fields. | P0 |
| FR-5.5 | Published, human-readable privacy architecture whitepaper; reproducible network-silence claims (documented for third-party audit). | P1 |

### FR-6: macOS Platform Integration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-6.1 | Native app (Swift/SwiftUI+AppKit); default-app registration for PDF; Quick Look integration; drag-and-drop everywhere; multi-window + tabs; full menu bar & keyboard shortcut coverage; trackpad gestures. | P0 |
| FR-6.2 | Accessibility: full VoiceOver support for reading and *filling* PDFs, Dynamic Type where applicable, high-contrast modes. | P0 |
| FR-6.3 | Continuity Camera (scan documents from iPhone), Share extension, Services menu ("Fill with Vaultform"), Shortcuts actions (open/fill/export). | P1 |
| FR-6.4 | Spotlight indexing of user's PDFs metadata (never vault contents). | P2 |

---

## 7. Non-Functional Requirements

### Performance
- **NFR-P1:** Cold app launch < 1.5s; open a 100-page text PDF < 1s; 500-page < 3s (M-series baseline: M1/16GB).
- **NFR-P2:** Scroll/zoom at 60fps (120fps ProMotion target) on typical documents; progressive rendering for heavy pages.
- **NFR-P3:** Autofill end-to-end (analyze + propose) on a 6-page AcroForm < 3s; scanned flat form < 10s including OCR.
- **NFR-P4:** Ingestion of a 2-page ID/resume document < 15s to review-ready.
- **NFR-P5:** Memory ceiling: < 1.5GB working set for a 1,000-page document (streamed page rendering, not full-document in memory).

### Security
- **NFR-S1:** Vault: AES-256-GCM at rest; keys in Secure Enclave via Keychain; memory hygiene for decrypted values (no swap, zeroed on lock).
- **NFR-S2:** No vault content in logs, crash reports, clipboard history (use transient pasteboard), or Spotlight.
- **NFR-S3:** Annual third-party security audit of vault and ingestion pipeline; findings summary published.
- **NFR-S4:** Code signing, notarization, Hardened Runtime, App Sandbox (App Store build) with security-scoped bookmarks for file access.

### Reliability
- **NFR-R1:** Crash-free session rate ≥ 99.8%.
- **NFR-R2:** Never corrupt a user's PDF: atomic saves, automatic versioned backups of edited files (configurable), document recovery after crash.
- **NFR-R3:** Vault database: transactional integrity, automatic local encrypted backups, corruption self-check on open.

### Accuracy (AI quality bars — measured on internal benchmark suite)
- **NFR-A1:** AcroForm field mapping: ≥ 95% precision on top-200 common form-field labels (English) at launch.
- **NFR-A2:** Flat/scanned form field detection: ≥ 85% field-level recall on benchmark set (gov forms, medical intake, HR packets).
- **NFR-A3:** OCR: ≥ 98% character accuracy on 300-dpi scans, ≥ 93% on phone photos.
- **NFR-A4:** Zero-tolerance rule: never fill a Sensitive-tier value into a low-confidence field match without explicit user confirmation (enforced by policy layer, not model discretion).

### Compatibility & footprint
- **NFR-C1:** macOS 14+; Apple Silicon first-class, Intel functional (AI features may degrade gracefully — smaller models, slower).
- **NFR-C2:** Output PDFs conform to spec; annotations/fills round-trip cleanly with Acrobat and Preview.
- **NFR-C3:** App download ≤ 400MB including on-device models (models beyond core set downloadable on demand, checksummed, still offline-executed).

### Usability & accessibility
- **NFR-U1:** First-run to first successful autofill ≤ 10 minutes for a novice (usability-tested).
- **NFR-U2:** WCAG 2.1 AA-equivalent for app UI; VoiceOver-complete form filling.
- **NFR-U3:** Localization-ready architecture; launch languages: English; fast-follow: Spanish, German, French, Portuguese, Japanese.

---

## 8. MVP Definition

**MVP thesis:** Ship the smallest product where *both* pillars are credible: a PDF editor good enough to replace Preview for daily use, and an autofill experience good enough to feel like magic on the forms people actually fear. The editor earns the install; autofill earns the word-of-mouth and the payment.

### MVP scope (GA is gated by the acceptance criteria below, not a calendar date — execution is dependency-sequenced by AI agents; see ROADMAP.md)

**PDF Editor core**
- Viewer: rendering, scroll/zoom/search/thumbnails/outline (FR-1.1, 1.2)
- Annotations: full standard set (FR-1.3)
- Text & image editing: single-block text edits, image replace/move/delete (FR-1.4, constrained)
- Page management: full (FR-1.5)
- Signatures: create/store/place (FR-1.6)
- OCR: English + top-5 Latin languages (FR-1.7)
- AcroForm fill & navigation (FR-1.8)
- Export: flattened PDF, images, text; basic compression (subset of FR-1.11)
- Password-protected file open (subset of FR-1.12)

**Vault**
- Full core schema, manual entry/edit, custom fields (FR-2.1, 2.2)
- Multiple person profiles + relationships (FR-2.3)
- Encryption + Touch ID + auto-lock + sensitivity tiers (FR-2.4, 2.5)

**Ingestion**
- PDF, DOCX, images via drag-drop and picker (FR-3.1, minus Continuity Camera if needed)
- Classification + extraction for: passport/ID (incl. MRZ), driver's license, resume, previously filled AcroForms, generic documents (FR-3.2, 3.3, 3.6)
- Mandatory review UI + conflict handling (FR-3.4, 3.5)

**Autofill**
- AcroForm semantic autofill with formatting adaptation (FR-4.1–4.3 for AcroForms)
- Flat/scanned form fill — **v1 quality bar:** detect and fill common field patterns; clearly staged as "beta" if benchmarks miss NFR-A2 (FR-4.1 flat-form path)
- Review panel, profile selection, sensitive gating, needs-input list (FR-4.4–4.7)

**Trust & platform**
- Fully offline operation, privacy dashboard v1, sandbox/notarization (FR-5.1–5.4)
- Native shell: tabs, shortcuts, default-app, drag-drop, VoiceOver for core flows (FR-6.1, 6.2)

### Explicitly deferred from MVP
Redaction, form-field creation, PDF/A & Word export, local learning loop, fill memory, ephemeral mode, batch anything, NL instructions, expiry reminders, Shortcuts/Services, vault export tooling (manual JSON export ships; polished archive later), Bates/watermarks, opt-in cloud tier.

### MVP acceptance gates (go/no-go for GA)
1. Benchmark suite: NFR-A1 and NFR-A3 met; NFR-A2 met *or* flat-form fill labeled beta.
2. 25-user beta cohort: ≥70% complete profile-to-filled-form journey unassisted in ≤10 min.
3. Zero PDF corruption across the automated 10K-document round-trip suite.
4. Network audit: zero non-consented connections under packet capture during full feature walkthrough.

### Monetization at MVP
- **Free tier:** Full viewer + annotations + basic page ops + 1 profile with limited fields + 3 autofills/month.
- **Vaultform Pro (one-time purchase, ~$79, per-major-version):** Full editor, unlimited vault, unlimited autofill.
- Subscription option (~$4.99/mo) for users who prefer it; both unlock identical features. Pricing validated during beta.

---

## 9. Future Features (Post-MVP Roadmap)

**Horizon 1 (first post-GA wave) — Deepen the core**
- True redaction + metadata scrubbing (Dr. Chen's headline feature)
- Local learning loop + form fingerprint fill memory (FR-4.8, 4.9)
- Form field creation & flat-to-fillable conversion (FR-1.9)
- Word/PDF-A export, file optimization presets
- Ephemeral mode; vault export/secure-erase polish; Continuity Camera; Shortcuts actions
- Localization wave 1

**Horizon 2 (after H1) — Expand the moat**
- **On-device document Q&A:** "What does clause 7 obligate me to?" — local LLM over the open document (never the vault without consent)
- Natural-language fill instructions (FR-4.11); batch autofill
- History-aware timelines UX (address/employment/travel) with gap detection — killer feature for immigration forms
- Expiry tracking + notifications; organization profiles v2
- Document comparison (diff two PDF versions); Bates numbering, headers/footers, watermarks
- **E2E-encrypted iCloud vault sync** (CloudKit, keys never leave user devices) — prerequisite for iOS

**Horizon 3 (long horizon, decision-gated) — Grow the surface**
- **iOS/iPadOS companion:** capture documents, review vault, fill on the go (shared vault via E2E sync)
- Optional **opt-in cloud model tier** for users who choose maximum capability (clearly labeled, per-action consent, sensitive fields excluded) — decision gate: only if on-device models leave a demonstrable quality gap
- Team/small-business edition: shared org profile, admin-managed templates (serves Sam)
- Template marketplace/library: community-mapped popular forms (mappings only — never data)
- Plugin/extension API for vertical workflows (legal, medical credentialing, immigration firms)

---

## 10. Risks & Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | **PDF format complexity underestimated.** The spec is ~1,000 pages; real-world PDFs violate it constantly. Editing (font substitution, reflow) is notoriously hard. | High | High | Build on proven foundation (PDFKit for render baseline; evaluate licensing a mature engine — PDFium-based or commercial — for editing); maintain a 10K+ real-document test corpus from day 1; constrain MVP editing scope deliberately. |
| R2 | **Flat/scanned form field detection misses quality bar,** making the flagship demo (government forms) unreliable. | Medium-High | High | Benchmark from Wave 0 on a curated corpus of the top ~100 real target forms (USCIS, IRS, medical intake); ship AcroForm autofill as the guaranteed path; label flat-form fill "beta" if needed; per-form template mappings for the top-50 forms as deterministic fallback. |
| R3 | **Wrong-value fills on high-stakes forms** (visa/tax) cause real user harm and trust collapse. | Medium | Very High | Review-before-commit is non-negotiable (FR-4.4); confidence thresholds; sensitive gating (NFR-A4); explainability trail; prominent "verify before submitting" UX on export of filled government forms. |
| R4 | **Vault = honeypot.** A breach of the local vault (malware, stolen unlocked laptop) is catastrophic for the user and the brand. | Low-Medium | Very High | Secure Enclave key wrapping, auto-lock, memory hygiene, third-party audits, no plaintext anywhere, sensitivity tiers, security disclosure program. Accept: we cannot protect a fully compromised OS — document threat model honestly. |
| R5 | **Apple platform risk:** Preview + Apple Intelligence could absorb "autofill forms" as an OS feature. | Medium | High | Move fast; go deeper than an OS feature ever will (history timelines, multi-profile families, ingestion pipeline, pro editing); the pro editor is the durable business even if basic autofill commoditizes. |
| R6 | **Adobe responds** with local-processing marketing or macOS-native investment. | Medium | Medium | Adobe's cloud-AI strategy and subscription model are structural; our one-time-purchase + verifiable-local architecture is hard for them to copy without cannibalizing. Speed + focus. |
| R7 | **On-device model constraints** (size, Intel Macs, older hardware) degrade the experience. | Medium | Medium | Tiered model strategy (small/large per hardware); Apple Foundation Models where available; Intel gets reduced AI with honest messaging; download-on-demand model packs (NFR-C3). |
| R8 | **Regulatory/liability exposure** from storing SSNs, health data, minors' data — even locally. | Medium | High | Local-only architecture minimizes our controller/processor role (we never possess user data); explicit no-server design; health section optional and user-initiated; legal review pre-GA (COPPA posture, state privacy laws); clear ToS on user responsibility for filled-form accuracy; export-compliance backend confirmation folded into this same pre-GA legal review pass (`docs/specs/export-compliance.md`). |
| R9 | **Free-tier gravity:** Preview is free and "good enough" for many; conversion stalls. | Medium | High | Free tier must beat Preview outright (annotation + pages) to win installs; paywall sits exactly on the pain (unlimited autofill + editing); target acquisition through high-pain channels (immigration, freelancer, medical communities). |
| R10 | **Scope creep toward Acrobat parity** delays MVP past the market window. | High | Medium | Ruthless MVP gate (§8); "compete with Acrobat" is a 3-year vision, not a v1 checklist; PM owns a public not-doing list (§3). |
| R11 | **Mac App Store sandbox** restricts file access patterns and may complicate the vault/ingestion UX. | Medium | Medium | Dual distribution (MAS + direct notarized build with Sparkle updates); design within sandbox from day 1 so MAS is not an afterthought. |
| R12 | **OCR/extraction quality on non-Latin scripts and poor photos** disappoints international users — a core segment (immigrants). | Medium | Medium | Set expectations by language; quality bars per language before enabling; photo-capture guidance UX (edge detection, glare warnings). |

---

## 11. Success Metrics

### North Star
**Forms Successfully Autofilled per Month (FSA/mo)** — a form counts when the user accepts autofill results and saves/exports the document. This single number captures acquisition, activation, trust, and habit.

### Activation funnel (measured via privacy-safe, opt-in, content-free telemetry; all metrics computable from aggregate event counts — never document or vault contents)
| Metric | Target (6 mo post-GA) |
|--------|------|
| Install → opens a PDF in first session | ≥ 85% |
| Install → creates vault profile (≥5 fields) within 7 days | ≥ 40% |
| Profile created → first successful autofill within 7 days | ≥ 60% |
| Time-to-first-autofill (median, first session attempters) | ≤ 10 min |

### AI quality (measured on-device, reported as opt-in aggregates + internal benchmark suite)
| Metric | Target |
|--------|--------|
| Autofill acceptance rate (proposed fields accepted w/o edit) | ≥ 80% AcroForm / ≥ 65% flat forms |
| Fields auto-filled per form (median, forms with ≥10 fields) | ≥ 70% of fillable fields |
| Ingestion extraction acceptance rate | ≥ 85% |
| Harmful-fill reports (wrong value user says they submitted) | ~0; every report triaged as Sev-1 |

### Engagement & retention
| Metric | Target (6 mo) |
|--------|--------|
| W4 retention (users with ≥1 autofill in week 1) | ≥ 45% |
| Monthly forms filled per active Pro user | ≥ 4 |
| % of MAU using Vaultform as default PDF app | ≥ 30% |

### Business
| Metric | Target |
|--------|--------|
| MAU | 100K @ 18 months |
| Free → paid conversion | ≥ 5% |
| Mac App Store rating | ≥ 4.7 |
| Refund rate | ≤ 3% |
| Revenue mix sanity check | Autofill cited as purchase driver in ≥ 50% of purchase surveys |

### Trust (the brand metric)
| Metric | Target |
|--------|--------|
| Users who can correctly state "my data stays on my Mac" in surveys | ≥ 90% of active users |
| Third-party security audit findings (high/critical) unresolved at GA | 0 |
| Privacy-related support tickets expressing confusion/distrust | < 1% of tickets |

### Counter-metrics (watch for health, not targets)
- Autofill **rejection** rate rising over time → model regression or trust erosion.
- Review-panel bypass attempts / feature requests to "skip review" → tension between safety and speed; resolve with accept-all-high-confidence UX, never by removing review.
- Vault field counts stagnating after week 1 → ingestion pipeline not pulling weight.

---

## Appendix A — Key Product Principles (tie-breakers for future decisions)
1. **Local by default, cloud by consent, never by requirement.**
2. **The user commits every fill.** AI proposes; humans dispose.
3. **Every value is traceable** to where it came from and how it was transformed.
4. **Beat Preview for free; beat Acrobat for money.**
5. **When editing fidelity and shipping speed conflict, protect the user's document** — never corrupt, never silently reflow.
