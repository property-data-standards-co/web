---
layout: ../../layouts/SpecLayout.astro
title: "Industry Consensus Session"
description: "PDTF 2.0 Sub-specification"
---

# PDTF 2.0 — Industry Consensus Session

**Purpose:** Introduce PDTF 2.0 architecture, surface all framework questions requiring multi-stakeholder agreement, and resolve enough to unblock specification completion and implementation.

**Audience:** Technical representatives from LMS, Connells, conveyancer software vendors, and any other PDTF implementers.

**Format:** Half-day working session (3–4 hours)

---

## What Needs Consensus vs What Doesn't

The PDTF 2.0 spec suite has ~50 open questions. Most are **internal Moverly implementation decisions** (key storage, caching strategy, CI pipelines) that don't need industry input.

**18 questions require industry consensus.** They fall into 6 themes:

| # | Theme | Why It Needs Consensus |
|---|-------|----------------------|
| 1 | Claims merge semantics | Every implementer must compose state the same way |
| 2 | Entity model & credential boundaries | What data goes where — everyone reads and writes these |
| 3 | Identifier design | Must be universally understood — no room for ambiguity |
| 4 | Organisation & person identity | Firms must host DIDs or delegate hosting; persons must reuse identity across transactions |
| 5 | Trust infrastructure governance | TIR is multi-stakeholder by design |
| 6 | Migration & backward compatibility | Live transactions must keep working |

---

## Agenda

### Part 1 — Architecture Introduction (45 min)

_Goal: Shared understanding. No decisions yet._

1. **Why PDTF 2.0** (10 min)
   - The verification problem: you trust the platform, not the data
   - What Verifiable Credentials change: verify the proof, not the intermediary
   - Three-phase trust evolution: Moverly proxies → hosted adapters → root issuers

2. **The Entity Graph** (15 min)
   - From monolithic transaction to 9 composable entities
   - Transaction, Property, Title, Person, Organisation, SellerCapacity, Representation, DelegatedConsent, Offer
   - The "logbook test": Property = travels with the building; Title = legal facts; Transaction = this-sale facts
   - Relationship model: Transaction-centric, not Property→Title→Transaction
   - **Person/Organisation symmetry:** both can own, sell, buy, represent. Companies buy property, individuals represent firms. The difference is structural (Companies House, SRA, PI insurance), not role-based
   - **SellerCapacity as right to sell:** the legal owner self-asserts their ownership, which establishes the right to dispose of the title. Verified against the proprietorship register (claim-vs-evidence separation)

3. **How It Works** (20 min)
   - Credential lifecycle: issue → verify → revoke
   - Identifiers: DIDs for actors (`did:key`, `did:web`), URNs for subjects
   - **Source documents:** evidence references files (title register PDF, survey report) via `pdtf://` URIs, with VP-based authenticated fetch and per-document confidentiality
   - State assembly: credentials compose into transaction state (v4 format + v3 backward compat)
   - Trusted Issuer Registry: who's authorised to issue what
   - **API:** MCP-compliant for AI agents + OpenAPI for traditional integrators — same service, dual transport
   - **Platform sync:** VC envelope encryption (ECDH-ES+A256KW) enables GDPR-safe replication between platforms

4. **What's Written** (5 min)
   - 9 sub-specs complete (architecture, entity graph, VC data model, DIDs, TIR, key management, state assembly, reference implementations, revocation)
   - 4 implementation specs (key management, revocation, DID infrastructure, TIR)
   - Reference website: propdata.org.uk
   - What's blocking: these 18 consensus questions

---

### Part 2 — Consensus Questions (2 hours)

_Goal: Decision or clear next step on each item._

#### Theme 1: Claims Merge Semantics (30 min) ⚡ HIGHEST PRIORITY

This is the single most consequential design decision. It affects every implementer.

**Q1.1 — Sparse objects + dependency pruning vs section-level REPLACE**
_Specs: 02 §5, 07 §4_

When a seller changes their heating type from "Central heating" to "None", what happens to the `centralHeatingDetails` object?

- **Option A: Dependency pruning.** The compositor detects the discriminator change and prunes the stale branch. Elegant, precise, but complex to implement — requires walking JSON Schema discriminators (`oneOf`, `if/then/else`).
- **Option B: Section-level REPLACE.** The new credential replaces the entire section. Simpler, but overwrites data that might still be valid.
- **Option C: Pruning with opt-out.** Pruning by default, but issuers can mark sections as REPLACE-semantics.

_What we need:_ Agreement on merge semantics. Every party composing state must do it identically.

**Q1.2 — Credential granularity for seller attestations**
_Spec: 02 §3_

When a seller fills in BASPI, is it:
- (a) One PropertyCredential per form
- (b) One PropertyCredential per section (heating, fixtures, legal questions, etc.)
- (c) Implementer's choice within constraints

_Affects:_ Revocation granularity. If a seller corrects one answer, do we revoke/reissue the whole form or just one section?

**Q1.3 — Multi-credential merge conflicts**
_Spec: 02 §13.2 Q6_

When two credentials for the same entity have overlapping paths with different values, which wins?
- Current design: later `validFrom` timestamp wins
- Alternative: trust level priority (root issuer > trusted proxy > user attestation)
- Alternative: explicit conflict resolution (flag it, let the consumer decide)

---

#### Theme 2: Entity Model & Credential Boundaries (20 min)

**Q2.1 — Multi-property transactions**
_Specs: 01 §9.1 Q2, 07 §12.1 Q3_

A house and its garage on separate titles — two properties in one transaction. How do:
- Overlays and form mappings work?
- v3 backward-compatible state handle `propertyPack` (singular) when there are multiple properties?

Options: primary property only (lossy), merge (conflicts), array of property packs (v3 schema change).

**Q2.2 — Conflict visibility**
_Spec: 07 §12.1 Q4_

Should trust-level conflicts be visible to transaction participants? E.g. "The EPC adapter says energy rating C, but the seller claimed D."

---

#### Theme 3: Identifier Design (20 min)

**Q3.1 — Search result identifiers**
_Spec: 01 §9.1 Q1_

Searches have `providerReference` but it may not be unique across providers. Options:
- Composite key: `{providerName}:{providerReference}`
- Synthetic UUID
- Provider-scoped URN: `urn:pdtf:search:{providerSlug}:{reference}`

**Q3.2 — Unregistered title identifiers**
_Spec: 03 §10.1_

Unregistered land has no title number. Proposed: `urn:pdtf:unregisteredTitle:{uuid}`.

- UUID v5 (deterministic from UPRN — same land always gets same ID) is preferred where a clean UPRN mapping exists
- UUID v4 (random) as fallback when no UPRN, or UPRN doesn't map cleanly to title boundaries
- When land gets registered at HMLR, how does the identifier transition? Succession credential? Alias (`alsoKnownAs`)? Both?
- Need LMS/HMLR input on how often unregistered land has usable UPRNs in practice

**Q3.3 — Credential IDs**
_Spec: 02 §13.1 Q5_

Should every credential have an `id` field? IDs enable deduplication and reference but create correlation vectors (privacy concern). Options: mandatory, optional, or issuer-specific policy.

---

#### Theme 4: Organisation & Person Identity (20 min)

**Q4.1 — Organisation DID hosting for small firms**
_Spec: 03 §10.2_

Organisations can use `did:key` (managed by account provider like LMS) or `did:web` (self-hosted at their domain). Questions:
- Should account-provider-managed `did:key` be the default path for most firms?
- For `did:web` self-hosters: mandatory self-hosting with PDTF tooling (@pdtf/did-tools), or registry-hosted delegation also available?
- What's the migration path from `did:key` (managed) to `did:web` (self-hosted) as firms gain capability?

**Q4.2 — Organisation discovery**
_Spec: 01 §9.1 Q3_

How do organisations identify themselves? Is domain-based identity sufficient, or do we need a discovery registry? SRA numbers, Companies House numbers, or domain-only?

**Q4.3 — Cross-party identity reuse**
_Specs: 03 §10.5, 06 §10_

A person verified in Transaction A enters Transaction B. How do they carry their verified identity across without re-verification, and how does the receiving party trust the assertion "this is my identity that I want to share into this transaction"?

- **Option A: Bearer VC presentation.** Person holds an identity VC and presents it directly. Receiving firm verifies the signature and checks the issuer in the Federated Registry. Simple, but without holder-binding the credential is a bearer token — anyone with a copy can present it. Requires additional anti-replay measures.
- **Option B: Firm-to-firm transfer with consent.** Person authorises their current firm to share the identity credential with the new firm. Platform brokers the handoff. No key management for the person, but they have no independent control — reuse is tied to the originating firm's willingness to share.
- **Option C: DID-bound credential with proof of control.** _(Recommended)_ Person's identity VC is bound to their `did:key` via `credentialSubject.id`. When entering a new transaction, the platform proves DID control on their behalf (signing a challenge with the person's platform-managed key) and presents the credential. Receiving firm verifies: credential signature valid, DID binding matches, challenge signature proves control, issuer in Federated Registry, credential not revoked. Cryptographically clean — the assertion "this is my identity" is provable, not just claimed. Forward-compatible with self-sovereign wallets.

_Our assumption:_ Option C. The platform manages the key on behalf of the account holder, giving cryptographic guarantees without consumer-facing key management. The credential format is identical whether the key is platform-managed (Phase 1) or wallet-held (future). We've documented this in detail in Sub-spec 03 §10.5 but are leaving it open for industry discussion.

_What we need:_ Agreement on the trust model for cross-party identity reuse — specifically, whether DID-bound proof of control is the right default, or whether the industry prefers a simpler bearer model or firm-to-firm delegation.

---

#### Theme 5: Trust Infrastructure Governance (15 min)

**Q5.1 — TIR governance model**
_Spec: 04 §13_

Phase 1: Moverly maintains the TIR. Phase 2+: multi-stakeholder. Questions:
- Who reviews and approves new TIR entries?
- What's the governance structure?
- Should the TIR itself be signed (JWS)?

**Q5.2 — Multiple issuers for the same data path**
_Spec: 04 §13 Q6_

Can two trusted proxies both be authorised for `Property:/energyEfficiency/certificate`? (Proposed: yes, verifier accepts any matching entry.)

**Q5.3 — Test/staging TIR**
_Spec: 04 §13 Q4_

Separate registry for non-production issuers, or a `test` status flag in the main registry?

---

#### Theme 6: Migration & Backward Compatibility (20 min)

**Q6.1 — Participant migration**
_Spec: 01 §9.1 Q4_

Current `participants` with role strings (e.g. "Seller's Conveyancer") become Organisation + Representation credential. What's the migration strategy for **live transactions**?

**Q6.2 — Buyer Person/Organisation creation timing**
_Spec: 01 §9.1 Q5_

When is a buyer Person or Organisation entity created? On offer submission? On acceptance? What minimum data is required? (Note: companies can be buyers too — this isn't Person-only.)

**Q6.3 — v3 backward compatibility contract**
_Spec: 07 §12.1 Q2_

Should v3-from-graph composition guarantee the same array ordering as the current v3-from-claims composer? Or is "semantically equivalent but differently ordered" acceptable?

---

### Part 3 — Decisions & Next Steps (15 min)

- Record decisions made
- Assign owners for questions needing follow-up
- Agree timeline for remaining decisions
- Next session date (if needed)

---

## Pre-Reading

Participants should review:
1. Architecture Overview (Sub-spec 00) — 15 min read
2. Entity Graph summary (Sub-spec 01, sections 1–5) — 15 min read

Available at: https://property-data-standards-co.github.io/webv2/specs/

---

## Decision Log Template

| # | Question | Decision | Rationale | Owner | Date |
|---|----------|----------|-----------|-------|------|
| Q1.1 | Merge semantics | | | | |
| Q1.2 | Credential granularity | | | | |
| Q1.3 | Merge conflicts | | | | |
| Q2.1 | Multi-property transactions | | | | |
| Q2.2 | Conflict visibility | | | | |
| Q3.1 | Search result identifiers | | | | |
| Q3.2 | Unregistered title identifiers | | | | |
| Q3.3 | Credential IDs | | | | |
| Q4.1 | Organisation DID hosting | | | | |
| Q4.2 | Organisation discovery | | | | |
| Q4.3 | Cross-party identity reuse | | | | |
| Q5.1 | TIR governance | | | | |
| Q5.2 | Multiple issuers for same path | | | | |
| Q5.3 | Test/staging TIR | | | | |
| Q6.1 | Participant migration | | | | |
| Q6.2 | Buyer creation timing | | | | |
| Q6.3 | v3 array ordering | | | | |
