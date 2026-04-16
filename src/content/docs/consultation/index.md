---
title: Industry Consultation
description: Open architectural questions for the PDTF 2.0 specification.
sidebar:
  order: 1
---

PDTF 2.0 represents a significant architectural shift from the first iteration of the framework. As we transition from a monolithic data structure relying on central platforms to a distributed, cryptographic graph of Verifiable Credentials, we are consulting the industry on several key design decisions.

This consultation is structured to present the problem, the viable options, our current recommendation, and the specific question we are seeking feedback on.

---

## Section 1: The Data Foundation

### Q1. Core Data Structure

**The Problem:** 
Currently, property data is exchanged via proprietary API integrations. Each integration requires custom mapping, bilateral agreements, and brittle point-to-point connections. PDTF v1 solved the mapping problem with a common schema, but the data remained bound to the platform that served it.

**The Options:**
- **Option A (Status Quo):** Continue building bilateral API integrations.
- **Option B (OIDC Claims):** Use standard OAuth/OIDC to verify claims against a central property identity provider.
- **Option C (Verifiable Credentials):** Issue data as W3C Verifiable Credentials (VCs). Data becomes cryptographically verifiable, independent of the platform that issued it, and highly portable.

**Our Recommendation (Option C):** 
Verifiable Credentials are the globally adopted standard for digital trust. Aligning with VCs prepares the UK property market for interoperability with GOV.UK One Login, the EU Digital Identity Architecture, and Smart Data initiatives.

**Consultation Question:**
> *Do you agree that W3C Verifiable Credentials are the correct foundational data structure for the next generation of property data exchange?*

---

### Q2. Decomposing the Property Pack

**The Problem:** 
PDTF v1 represents a property transaction as a single JSON document (around 4,000 data paths). If an EPC rating updates, the entire transaction document is conceptually altered. Furthermore, data collected during a failed transaction is locked inside that transaction's context, rather than surviving alongside the property for the next buyer.

**The Options:**
- **Option A (Monolithic):** Retain a single massive transaction document.
- **Option B (Entity Graph):** Decompose the schema into nine distinct, independently credentialed entities: `Property` (physical facts), `Title` (legal facts), `Transaction` (this-sale facts), `Person`, `Organisation`, and relationship credentials (`SellerCapacity`, `Representation`, `DelegatedConsent`, `Offer`).

**Our Recommendation (Option B):** 
The entity graph follows the "Logbook Test" — facts that belong to the property (EPCs, flood risks) stay with the property entity and survive the transaction. Facts that belong to the title stay with the title. This enables genuine data reuse across aborted transactions.

**Consultation Question:**
> *Does the proposed Entity Graph cleanly separate physical property facts, legal title facts, and transient transaction state? Are there any missing entities?*

---

## Section 2: Identity & Wallets

### Q3. Pragmatic Identity for Firms

**The Problem:** 
To issue or present Verifiable Credentials, an entity needs a Decentralised Identifier (DID). Expecting every conveyancing firm and high-street estate agent to manage their own cryptographic keys and host a DID document (`did:web`) is an unrealistic barrier to adoption in the near term.

**The Options:**
- **Option A:** Require all participating firms to self-host `did:web` infrastructure.
- **Option B:** Mandate a central registry that generates and holds keys for everyone.
- **Option C (Provider-Managed Identity):** Allow firms to use ephemeral or provider-managed `did:key` identifiers, issued by their technology provider (e.g., their CRM or a platform like LMS/Moverly). Only tech-forward firms and major platforms are expected to self-host `did:web`.

**Our Recommendation (Option C):** 
We must support account-provider-managed `did:key` identity for the vast majority of firms. It drastically lowers the barrier to entry while maintaining cryptographic integrity.

**Consultation Question:**
> *Do you agree with the assumption that the majority of participating organisations will rely on their technology providers for DID management, rather than self-hosting?*

---

### Q4. The Consumer Wallet Gap

**The Problem:** 
Consumers (buyers and sellers) do not currently possess digital wallets capable of receiving, holding, and presenting Verifiable Credentials.

**The Options:**
- **Option A:** Build a proprietary, property-specific wallet app that consumers must download.
- **Option B:** Force integration with early-stage, generic commercial wallets (fragmented market, high UX friction).
- **Option C (Delayed Consumer Wallets):** In Phase 1, consumer identity is managed ephemerally by their conveyancer or agent using `did:key`. We delay direct consumer wallet integration until GOV.UK One Login or EU DI wallets reach critical mass.

**Our Recommendation (Option C):** 
Property is too high-friction an environment to act as the wedge for consumer wallet adoption. We should abstract the cryptography away from the consumer entirely in Phase 1.

**Consultation Question:**
> *Is delaying direct consumer wallet integration in favour of provider-managed identity the most viable strategy for Phase 1 adoption?*

---

## Section 3: Trust & Governance

### Q5. OpenID Federation

**The Problem:** 
If anyone can issue a Verifiable Credential, how does a relying party (like a lender) know if the issuer is actually authorised to provide that data? (e.g., How do we know this DID belongs to a legitimate EPC assessor?)

**The Options:**
- **Option A:** Every platform maintains its own proprietary whitelist of trusted issuers.
- **Option B:** A bespoke, git-hosted Trusted Issuer Registry (the PDTF v0.8 approach).
- **Option C (OpenID Federation):** Adopt the OpenID Federation standard, using Trust Anchors, Entity Statements, and Trust Marks to cryptographically prove an issuer's authority.

**Our Recommendation (Option C):** 
OpenID Federation is an established standard designed exactly for this problem. It allows dynamic trust resolution without relying on a bespoke registry format.

**Consultation Question:**
> *Does OpenID Federation provide the correct framework for governing trust and issuer authorisation in the UK property market?*

---

### Q6. Trust Anchor Governance

**The Problem:** 
OpenID Federation relies on a root "Trust Anchor" — a cryptographic key that issues the ultimate Trust Marks to participating organisations. Someone has to hold this key and govern the policy for issuing Trust Marks.

**The Options:**
- **Option A:** A government regulator (authoritative, but likely years away from implementation).
- **Option B:** A new joint-venture consortium of major industry players (neutral, but slow to establish).
- **Option C (Interim Project Governance):** This project operates an interim, proof-of-concept Trust Anchor (`trust.pdtf.org`) to bootstrap the ecosystem, with a roadmap to transition to a formal industry consortium or regulator once proven.

**Our Recommendation (Option C):** 
To maintain momentum and prove the architecture works in practice, an interim Trust Anchor is required. Governance can be formalised as the network scales.

**Consultation Question:**
> *Is an interim, project-led Trust Anchor acceptable for bootstrapping the ecosystem, provided there is a clear transition path to formal industry or regulatory governance?*

---

### Q7. Trust Mark Granularity

**The Problem:** 
Trust is rarely binary. A provider authorised to issue an EPC credential is not necessarily authorised to issue a Title credential.

**The Options:**
- **Option A:** Blanket trust. If an issuer is in the federation, they can issue any property credential.
- **Option B (Path Delegation):** Trust Marks include a `delegation` claim that explicitly authorises the issuer for specific data paths (e.g., `Property:/energyPerformanceCertificate`). Validators reject credentials issued outside this scope.

**Our Recommendation (Option B):** 
Granular, path-based delegation is essential for a diverse ecosystem containing specialist data providers.

**Consultation Question:**
> *Do you agree that Trust Marks must explicitly declare the data paths an issuer is authorised to populate?*

---

## Section 4: Access & Exchange

### Q8. Intent-Based Access Control

**The Problem:** 
Property data is highly sensitive. How do we ensure that only authorised parties (e.g., a mortgage lender) can access the data, without relying on a central, proprietary Access Control List (ACL)?

**The Options:**
- **Option A:** Central API gateways enforce access rules based on user accounts.
- **Option B (Intent-based Graph Traversal):** The graph itself dictates access. A `Transaction` represents the intent to sell; an `Offer` represents the intent to buy. If a buyer grants a lender a `DelegatedConsent` credential referencing their accepted `Offer`, the lender is cryptographically authorised to traverse the graph and read the property data.

**Our Recommendation (Option B):** 
Using relationship credentials (`Representation`, `DelegatedConsent`) as capability tokens removes the need for central API gatekeepers.

**Consultation Question:**
> *Does the framing of Transaction (Intent to Sell) and Offer (Intent to Buy) provide a robust enough foundation for distributed access control?*

---

### Q9. Standardised Exchange Protocols

**The Problem:** 
Once a credential exists, how is it requested and delivered between different platforms?

**The Options:**
- **Option A:** Define a custom REST API specification for the property industry.
- **Option B:** Adopt OID4VCI (OpenID for Verifiable Credential Issuance) and OID4VP (OpenID for Verifiable Presentations).

**Our Recommendation (Option B):** 
Adopting existing OIDF standards ensures compatibility with generic enterprise identity infrastructure and reduces the maintenance burden on the property industry.

**Consultation Question:**
> *Should OID4VCI and OID4VP be mandated as the standard protocols for exchanging property credentials?*