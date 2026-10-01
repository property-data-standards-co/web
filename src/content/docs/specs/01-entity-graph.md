---
title: "01 Entity Graph & Schema"
description: "PDTF 2.0 specification document."
---


**Version:** 0.3 (Draft)
**Date:** 1 October 2026
**Author:** Ed Molyneux
**Status:** Draft for review (LMS collaboration)
**Parent:** [00 — Architecture Overview](/specs/00-architecture-overview/)

**Changes in v0.3:** Aligned with the generated v4 schemas in the schemas repository (`dev`, 3.6.0-dev.26). Ten entities: `DelegatedConsent` is withdrawn; `Gift` and `TransactionRole` are added. Role now lives only on the relationship credential that embodies it, and every relationship credential references the Transaction rather than nesting inside the Offer (new decision **D32**, which supersedes D31). The Transaction carries a roster of parties (`participants[]`) with no roles. Field names follow the schemas (`seller`, `buyer`, `donor`, `representative`, `representedParty`, `participant`, `transaction`). Representation is one credential per (representative, represented party) pair. Field mapping in §4 and §7 now follows the generated mapping manifest. Diagrams redrawn.

**Changes in v0.2:** Buyer-side relationship credentials were nested inside the Offer (D31, now superseded). Added entity-graph diagrams to §3.2.

---

## 1. Purpose

This sub-spec defines the PDTF 2.0 entity graph: the set of entities, their schemas, identifiers, relationships, and the rules for decomposing a monolithic transaction into entities and recomposing entities back into transaction state.

It replaces the single `pdtf-transaction.json` (combined.json) with a graph of independently identifiable, independently credentialed entities — while maintaining full backward compatibility with the v3 schema through bidirectional transformation.

---

## 2. Design Principles

### 2.1 The Logbook Test

The governing principle for entity assignment:

> **Property entity** = facts that travel with the property across transactions (the logbook). If the next buyer needs to know it, it belongs on Property.
>
> **Title entity** = facts about the legal title — register data, ownership type, encumbrances. Intrinsic to the title, not the sale.
>
> **Transaction entity** = facts about this particular sale — who's involved, financing, milestones, status. Irrelevant to the next owner.
>
> **Relationship credentials** (SellerCapacity, Offer, Gift, Representation, TransactionRole) = who holds what role, in relation to whom. These are thin signed assertions linking persons/organisations to the transaction, and they are the *only* place a party's role is recorded.

### 2.2 ID-Keyed Collections

All entity collections use ID-keyed maps, not arrays. This enables:
- Deterministic addressing (credential subjects reference entities by ID)
- Merge semantics (updates target a specific entity by key)
- Graph traversal (follow references by ID without index fragility)

Where the v3 schema uses arrays (participants, titlesToBeSold, searches, etc.), the v4 schema converts them to `{ [id]: entity }` maps. Where v3 array order carried meaning, it lives on the Transaction: `titlesToBeSold` and `participants` are ordered reference lists, authoritative for recomposition. No position is written into an entity document, so a credential never carries an index that could diverge from another producer's.

### 2.3 Single Development Artifact

The v3 `combined.json` remains the single development artifact. The v4 entity schemas are **generated** from it (`npm run generate:v4` in the schemas repository), not maintained separately. The same run emits a mapping manifest (`v4/mapping.json`: v3 pointer → entity + pointer, and the inverse) and the `decompose` / `recompose` helpers, and it fails the build if any v3 field has no home in v4. This keeps all context in one place during development and guarantees that the two representations cannot drift.

```
v3/combined.json (single dev artifact)
    │
    ├──→ generate:v4 ──→ v4 entity schemas
    │         │             (Property.json, Title.json, …, TransactionRole.json)
    │         │
    │         ├──→ credentialSubject shapes for Verifiable Credentials
    │         │
    │         └──→ v4/mapping.json (prefix rules, projections, round-trip exceptions)
    │
    ├──→ decompose(v3) ──→ entity documents + relationship credentials
    │
    └──→ recompose(entities) ──→ v3 instance (deep equality, documented exceptions)
```

---

## 3. Core Entities

### 3.1 Entity Summary

Five entities carry data. Five are **relationship credentials**: thin, signed assertions that link a party to the transaction and, in doing so, embody that party's role.

| Entity | Kind | Identifier | Schema | Description |
|--------|------|-----------|--------|-------------|
| **Transaction** | data | `did:web` | `v4/Transaction.json` | Sale metadata, status, milestones, offers, enquiries, contracts, chain, residual sale context, and the ordered roster of parties. The root of the graph. |
| **Property** | data | `urn:pdtf:uprn:{uprn}` | `v4/Property.json` | Physical property: address, build info, features, energy, environmental, legal questions — everything that goes in the logbook. |
| **Title** | data | `urn:pdtf:titleNumber:{number}` or `urn:pdtf:unregisteredTitle:{id}` | `v4/Title.json` | Legal title: register extract, tenure (freehold/leasehold/commonhold), leasehold terms, encumbrances. |
| **Person** | data | `did:key` | `v4/Person.json` | Natural person: name, contact, address, verification status. Role-free — role is contextual via relationship credentials. The `did:key` is stable across transactions. |
| **Organisation** | data | `did:web` | `v4/Organisation.json` | Legal entity: law firm, estate agency, lender. The one entity outside the v3 round trip: the roster records a participant's firm by name and reference, and resolving the participant's DID gives the Organisation. |
| **SellerCapacity** | credential | `urn:pdtf:capacity:{id}` | `v4/SellerCapacity.json` | The capacity in which a Person/Org sells (legal owner, personal representative, attorney, mortgagee in possession…). Issued for every seller. **Implies the Seller role.** Revocable. |
| **Offer** | credential | `urn:pdtf:offer:{id}` | `v4/Offer.json` | An offer to buy: buyer, amount, status, conditions, buyer circumstances. **Implies the Buyer role.** |
| **Gift** | credential | `urn:pdtf:gift:{id}` | `v4/Gift.json` | A gift of funds towards an offer, with the terms a conveyancer must resolve before reporting to a lender. **Implies the Giftor role.** |
| **Representation** | credential | `urn:pdtf:representation:{id}` | `v4/Representation.json` | One party instructed by another: one credential per (representative, represented party) pair. Carries the kind of representation as its `role`. Revocable. |
| **TransactionRole** | credential | `urn:pdtf:role:{id}` | `v4/TransactionRole.json` | A party's role where no more specific relationship credential applies (Lender, Landlord, Tenant, Surveyor, Platform Support), or where the specific relationship is not yet established. |

### 3.2 Relationship Model

```
Transaction (did:web:platform.example.com:transactions:{id})
    │
    ├── property:       "urn:pdtf:uprn:100023456789"
    ├── titlesToBeSold: ["urn:pdtf:titleNumber:AB12345"]        // ordered
    │
    ├── participants: [                                        // ordered ROSTER — no roles
    │     { participant: "did:key:z6Mkh...abc", participantId: "s1" },
    │     { participant: "did:key:z6Mkh...xyz", participantId: "b1" },
    │     { participant: "did:key:z6Mkj...c1",  participantId: "c1",
    │       organisation: "Smith & Co Law", organisationReference: "SC/118" },
    │     { participant: "did:web:bigbank.co.uk", participantId: "l1" }
    │   ]
    │
    ├── offers:   { "o1": { amount: 450000, status: "Accepted", … } }   // offer terms, keyed by offer id
    ├── enquiries, milestones, contracts, chain, saleContext, …
    │
    │   relationship credentials — each references the Transaction and embodies a role:
    │
    ├── SellerCapacity   "urn:pdtf:capacity:{id}"
    │     { seller: "did:key:z6Mkh...abc", transaction: <did>,
    │       sellersCapacity: { capacity: "Legal Owner" } }                    ⇒ Seller
    │
    ├── Offer            "urn:pdtf:offer:{id}"
    │     { buyer: "did:key:z6Mkh...xyz", transaction: <did>, offerId: "o1",
    │       amount: 450000, status: "Accepted", buyerCircumstances: {…} }     ⇒ Buyer
    │
    ├── Gift             "urn:pdtf:gift:{id}"
    │     { donor: "did:key:z6Mkp...gf", transaction: <did>, offerId: "o1",
    │       giftDetails: {…} }                                               ⇒ Giftor
    │
    ├── Representation   "urn:pdtf:representation:{id}"
    │     { representative: "did:key:z6Mkj...c1", representedParty: "did:key:z6Mkh...abc",
    │       role: "Seller's Conveyancer", transaction: <did> }
    │
    └── TransactionRole  "urn:pdtf:role:{id}"
          { participant: "did:web:bigbank.co.uk", role: "Lender", transaction: <did> }
```

**Roles live on the credentials.** The roster carries only what stays true of a party regardless of any relationship: their DID, a transaction-local id, and the firm they work for. Role is stored nowhere else than on the relationship credential that embodies it:

| Credential | Asserts | Role |
|---|---|---|
| `SellerCapacity` | this person sells, in this capacity | **implied**: Seller |
| `Offer` | this person made this offer | **implied**: Buyer |
| `Gift` | this person gifts funds towards a purchase | **implied**: Giftor |
| `Representation` | this party is instructed by that party | explicit — which kind |
| `TransactionRole` | this party takes this role | explicit — which role |

For the first three, role follows 1:1 from the credential's existence: v3 puts `sellersCapacity` only on the Seller branch and `giftDetails` only on the Giftor branch. `offerId` is on both the Buyer and Giftor branches, so a giftor's offer link lives on `Gift` rather than `Offer`, which keeps `Offer ⇒ Buyer` exact. `Representation` and `TransactionRole` each span several roles, so they carry role as their own discriminator: acting for a seller tells you the side, not whether the party is the conveyancer, the agent or the surveyor.

Every participant carrying a role receives exactly one role-bearing credential: the specific one where the relationship exists, `TransactionRole` otherwise. A participant with no role receives none.

**The two intents.** The Transaction is the seller's intent to sell, embodied by `SellerCapacity`. An Offer is a buyer's intent to buy. Buyers participate only through Offers, and a transaction can carry several. Everyone else is linked to the party they act for: a buyer's conveyancer holds a `Representation` whose `representedParty` is the buyer, and the buyer's link to their offer is the `Offer` credential itself.

**Figure 1 — Entity graph (schema level).** Entity types and identifiers, colour-coded by family. Every relationship credential references the Transaction:

![PDTF entity graph — entity types, identifiers, and the relationship credentials that embody each role](/diagrams/entity-graph.svg)

**Figure 2 — Worked example.** The same model instantiated for a single sale ("14 Elm Road"): the seller's SellerCapacity, the buyer's Offer, a parent's Gift, three Representations and the lender's TransactionRole all reference the Transaction, and each can be presented or revoked on its own:

![PDTF entity graph worked example — the 14 Elm Road sale, with every party linked to the Transaction by the credential that embodies their role](/diagrams/entity-graph-example-intents.svg)

### 3.3 Key Design Decisions

**D26: Transaction-centric graph.** The Transaction is the root. Property and Title are referenced by the Transaction, not the other way around. This handles unregistered titles (no title number), multi-property transactions (house + garage on separate titles), and multi-title properties naturally.

**D27: Organisation as first-class entity.** Estate agents, conveyancers, and lenders participate as Organisations with their own identity, regulatory IDs and PI insurance. A participant's firm is recorded on the Transaction roster (`organisation`, `organisationReference`) rather than on any credential, because where someone works does not stop being true when a representation ends. Resolving the participant's DID gives the Organisation.

**D28: Thin SellerCapacity credentials.** The SellerCapacity entity is a signed assertion of the capacity in which a party sells. It does not duplicate title details (leasehold terms, restrictions). Those belong on the Title entity. The claim is verified by cross-referencing against `Title.registerExtract.proprietorship` from HMLR. It is scoped to the transaction, since the Transaction already lists the titles being sold; an optional `title` reference narrows it where a sale involves several.

**D29: Buyers through Offers.** Buyers exist in the transaction only through Offer credentials. This models reality: a buyer doesn't participate until they make an offer, multiple competing offers can exist simultaneously, and each offer has its own status and conditions. The existing `offerId` on v3 participants provides the migration path. A prospective buyer who has not yet made an offer can still be represented, because Representation links to the person, not the offer.

**D30: The Logbook Test.** Data belongs on Property if and only if it's relevant to the next owner. EPC, flood risk, legal questions, fixtures — logbook. Number of sellers, outstanding mortgage, SDLT details — not logbook. This principle governs all field placement decisions.

**D31 (superseded by D32): Buyer-side relationships nest inside the Offer.** v0.2 nested the buyer's-conveyancer Representation and a lender DelegatedConsent inside the Offer. Withdrawn: nesting created a second home for role and relationship, and `DelegatedConsent` duplicated what the roster and `TransactionRole` already express.

**D32: Role lives only on the relationship credential, and every relationship credential references the Transaction.** Firing a conveyancer means revoking their `Representation`. If the Transaction also recorded "Seller's Conveyancer" against that participant, revocation would remove the relationship and leave the role assertion standing — two sources of truth, disagreeing, with the stale one still readable. So the roster carries no role, and dropping a credential and recomposing gives back a v3 instance in which that party has no role and no relationship, which is exactly what revocation should mean. Each credential references the Transaction directly (`transaction`), with `Offer` and `Gift` additionally carrying the `offerId` they relate to; nothing nests. Lender access is expressed by the lender's `TransactionRole`; how a scoped, time-limited consent should sit on top of that is an open consultation question.

**D33: One Representation per (representative, represented party) pair.** A conveyancer instructed jointly by two sellers holds two Representations, each presentable or revocable on its own. A separated couple instructing their own conveyancers yields one each — the case the role-only model could not express. The retainer is with the client, so `representedParty` is a person or organisation, never an offer.

---

## 4. Field Mapping: v3 → v4 Entities

### 4.1 Property Entity

The Property entity corresponds to `propertyPack` in v3, minus titles and minus sale-specific ownership fields.

**Included — passes the logbook test:**

| v3 Path | Description |
|---------|-------------|
| `propertyPack.address` | Property address |
| `propertyPack.uprn` | Unique Property Reference Number (becomes the entity identifier) |
| `propertyPack.location` | Lat/long, what3words |
| `propertyPack.localAuthority` | Council tax, planning authority |
| `propertyPack.priceInformation` | Guide price, listing price |
| `propertyPack.lettingInformation` | Rental history |
| `propertyPack.summaryDescription` | Marketing description |
| `propertyPack.marketingTenure` | Advertised tenure |
| `propertyPack.media` | Photos, floorplans, virtual tours |
| `propertyPack.buildInformation` | Build date, type, materials |
| `propertyPack.residentialPropertyFeatures` | Bedrooms, bathrooms, parking |
| `propertyPack.nearbyFacilities` | Schools, transport, healthcare |
| `propertyPack.delayFactors` | Known issues that may delay sale |
| `propertyPack.parking` | Parking arrangements |
| `propertyPack.listingAndConservation` | Listed building status, conservation area |
| `propertyPack.typeOfConstruction` | Wall type, roof type |
| `propertyPack.energyEfficiency` | EPC data, recommendations |
| `propertyPack.councilTax` | Band, amount |
| `propertyPack.disputesAndComplaints` | Boundary disputes, complaints |
| `propertyPack.alterationsAndChanges` | Planning permissions, building regs |
| `propertyPack.notices` | Legal notices served/received |
| `propertyPack.specialistIssues` | Japanese knotweed, flooding, subsidence |
| `propertyPack.fixturesAndFittings` | What's included/excluded |
| `propertyPack.electricity` | Supply details |
| `propertyPack.waterAndDrainage` | Water supply, drainage |
| `propertyPack.heating` | Heating system |
| `propertyPack.connectivity` | Broadband, mobile coverage |
| `propertyPack.insurance` | Building insurance details |
| `propertyPack.rightsAndInformalArrangements` | Rights of way, shared access |
| `propertyPack.environmentalIssues` | Flood, radon, contamination, ground stability |
| `propertyPack.otherIssues` | Anything else |
| `propertyPack.additionalInformation` | Free text additions |
| `propertyPack.consumerProtectionRegulationsDeclaration` | CPR compliance |
| `propertyPack.legalBoundaries` | Boundary ownership, disputes |
| `propertyPack.servicesCrossing` | Pipes, cables, drains crossing |
| `propertyPack.electricalWorks` | Electrical installation certificates |
| `propertyPack.smartHomeSystems` | Smart home tech |
| `propertyPack.guaranteesWarrantiesAndIndemnityInsurances` | Guarantees held |
| `propertyPack.occupiers` | Current occupants |
| `propertyPack.localSearches` | Local land charges, local authority searches |
| `propertyPack.searches` | Environmental, drainage, other searches |
| `propertyPack.documents` | Supporting documents |
| `propertyPack.surveys` | Building surveys |
| `propertyPack.valuations` | Property valuations |

**Excluded from Property — moved to other entities:**

| v3 Path | Moved to | Reason |
|---------|----------|--------|
| `propertyPack.titlesToBeSold` | **Title** | Intrinsic to the title, not the property |
| `propertyPack.ownership.ownershipsToBeTransferred` | **Title** (nested as `ownership`) | Leasehold terms, ownership type — title details |
| `propertyPack.ownership.numberOfSellers` | **Transaction** | This sale only |
| `propertyPack.ownership.numberOfNonUkResidentSellers` | **Transaction** | SDLT context for this sale |
| `propertyPack.ownership.outstandingMortgage` | **Transaction** | Discharged on completion |
| `propertyPack.ownership.existingLender` | **Transaction** | Gone after this sale |
| `propertyPack.ownership.hasHelpToBuyEquityLoan` | **Transaction** | Discharged on completion |
| `propertyPack.ownership.isFirstRegistration` | **Title** | Property of the title itself |
| `propertyPack.ownership.isLimitedCompanySale` | **Transaction** | About the seller entity type |
| `propertyPack.legalOwners` | **Person/Organisation** entities + **SellerCapacity** credentials | Becomes structured entities with DIDs |
| `propertyPack.confirmationOfAccuracyByOwners` | **Transaction** | Seller signatures for this sale |
| `propertyPack.saleReadyDeclarations` | **Transaction** | Seller declarations for this sale |
| `propertyPack.completionAndMoving` | **Transaction** | Completion date, key arrangements — this sale |

### 4.2 Title Entity

Each title in `propertyPack.titlesToBeSold[]` becomes a Title entity, keyed by `urn:pdtf:titleNumber:{number}`.

| Source | v4 Location | Notes |
|--------|-------------|-------|
| `titlesToBeSold[].titleNumber` | Title identifier (part of URN) | Becomes the entity key |
| `titlesToBeSold[].titleExtents` | `titleExtents` | GeoJSON boundary |
| `titlesToBeSold[].registerExtract` | `title.registerExtract` | OC1 summary + register data from HMLR |
| `titlesToBeSold[].additionalDocuments` | `title.additionalDocuments` | Filed copies, plans, etc. |
| `ownership.ownershipsToBeTransferred[].ownershipType` | `ownershipType` | Freehold/Leasehold/etc. — matched by titleNumber |
| `ownership.ownershipsToBeTransferred[].{leasehold details}` | `{leasehold details}` | Lease terms, ground rent, etc. (via discriminator) |
| `ownership.isFirstRegistration` | `isFirstRegistration` | Title registration status |

**Unregistered titles:** Use `urn:pdtf:unregisteredTitle:{generated-id}`. The title may gain a `titleNumber` after first registration, at which point the URN updates. The graph must handle this transition.

**ownershipToBeTransferred (moved to top level):**
Because a `TitleCredential` fundamentally represents an ownership interest being conveyed, the fields previously inside `ownershipsToBeTransferred[]` move to the top level of the Title entity, and the register evidence moves into a `title` sub-object:

```json
Title (credential subject):
{
  "ownershipType": "Freehold" | "Leasehold" | "CommonholdUnit",
  // additional interest-specific fields (e.g. leaseholdDetails)
  "title": {
    "registerExtract": { ... },
    "additionalDocuments": [ ... ]
  }
}
```
Note that this applies to both registered (`urn:pdtf:titleNumber:*`) and unregistered (`urn:pdtf:unregisteredTitle:*`) titles.

*These fields represent the decomposition of the v1 monolithic `ownership` schema object per Q7.1 (architecture overview §14.2.1). Unregistered title identifier resolution is tracked as Q7.2 — the schema is stable for both cases but the identifier format is pending.*


### 4.3 Transaction Entity

The Transaction is the root entity and container for sale-specific data.

| Source | v4 Location | Notes |
|--------|-------------|-------|
| `transactionId` | Transaction DID (`did:web`) | Becomes the entity identifier |
| `status` | `status` | Transaction lifecycle status |
| `externalIds` | `externalIds` | Cross-system references |
| `milestones` | `milestones` | Listed, SSTC, searches, exchange, completion |
| `contracts` | `contracts` | Contract templates, terms, signatures |
| `chain` | `chain` | Onward purchase chain links |
| `valuationComparisonData` | `valuationComparisonData` | Comparable properties data |
| `ownership.numberOfSellers` | `saleContext.numberOfSellers` | Grouped under sale context |
| `ownership.numberOfNonUkResidentSellers` | `saleContext.numberOfNonUkResidentSellers` | |
| `ownership.outstandingMortgage` | `saleContext.outstandingMortgage` | |
| `ownership.existingLender` | `saleContext.existingLender` | |
| `ownership.hasHelpToBuyEquityLoan` | `saleContext.hasHelpToBuyEquityLoan` | |
| `ownership.isLimitedCompanySale` | `saleContext.isLimitedCompanySale` | |
| `confirmationOfAccuracyByOwners` | `sellerConfirmations.accuracy` | Sale-specific seller sign-off |
| `saleReadyDeclarations` | `sellerConfirmations.saleReady` | Sale-specific declarations |
| `completionAndMoving` | `completion` | Completion date, arrangements |

### `saleContext` details
| Field | Type | Description |
|-------|------|-------------|
| `numberOfSellers` | integer | Total number of individual sellers |
| `numberOfNonUkResidentSellers` | integer | Number of sellers not UK resident for tax purposes |
| `outstandingMortgage` | enum `Yes` \| `No` | Whether the sellers have an outstanding mortgage on any title being sold |
| `existingLender` | string | Name of the existing mortgage lender (if applicable) |
| `hasHelpToBuyEquityLoan` | enum `Yes` \| `No` | Help to Buy equity loan flag |
| `isLimitedCompanySale` | enum `Yes` \| `No` | Whether the sale is from a limited company |

These are transaction-scoped facts — they describe the sale context and are re-asserted per transaction. They are not title-level facts.

*These fields represent the decomposition of the v1 monolithic `ownership` schema object per Q7.1 (architecture overview §14.2.1). Unregistered title identifier resolution is tracked as Q7.2 — the schema is stable for both cases but the identifier format is pending.*


### 4.4 Person Entity

Extracted from `participants[]`: the fields that describe the party, not their relationship to this transaction.

| Source | v4 Location | Notes |
|--------|-------------|-------|
| `participants[].did` | `id` / `did` | The party's own DID, used verbatim. Stable across transactions. |
| `participants[].name` | `name` | First, middle, last, title |
| `participants[].dateOfBirth` | `dateOfBirth` | |
| `participants[].phone` | `phone` | |
| `participants[].email` | `email` | |
| `participants[].address` | `address` | |
| `participants[].verification` | `verification` | Identity, AML, source of funds |
| `participants[].participantStatus` | `participantStatus` | |
| `participants[].externalIds` | `externalIds` | |

**Not included:** `role`, `sellersCapacity`, `dateBecameOwnerOrAuthority`, `offerId`, `giftDetails`, `actingFor` — these describe the party's relationship to *this transaction* and move to the relationship credentials (§4.6–4.10). `organisation`, `organisationReference` and `participantId` move to the Transaction roster (§4.3).

**Identity:** v3 participants carry a `did`, minted when the party is created. v4 uses it verbatim as `Person.id`; a DID is minted only for instances that carry none. Identity must be stable *across* transactions: a person selling one property and buying another appears in two transactions and should be the same subject in both — one wallet, accumulating credentials, not one identity per participation. A DID repeated within one transaction is the same party listed twice, which `decompose` refuses: a transaction is a single sale, so nobody is both its buyer and its seller.

### 4.5 Organisation Entity

Standalone entity for firms and companies: name, trading name, organisation type, Companies House number, VAT number, regulatory IDs, registered address, contact details, external IDs.

**Outside the round trip:** v3 records a participant's firm as free text (`organisation`, `organisationReference`), which stays on the Transaction roster. Organisation entities are therefore not required to reconstruct a v3 instance; they are resolved from a participant's DID.

**Identity note:** Organisations use `did:web`. Small firms are expected to use orchestrator-hosted identities in Phase 1; the account provider is trusted to verify the organisation's identity and regulatory status.

### 4.6 SellerCapacity Entity

The capacity in which a party sells. Projected from `participants[]` on the Seller branch. **Implies the Seller role.**

| Field | Source | Description |
|-------|--------|-------------|
| `id` | generated | `urn:pdtf:capacity:{id}` |
| `seller` | `participants[].participant` | DID of the Person or Organisation selling |
| `transaction` | `Transaction.id` | Transaction DID |
| `title` | — | Optional Title URN. v3 does not tie a seller's capacity to a particular title, so a sale of several titles yields a capacity scoped to the transaction. |
| `sellersCapacity` | `participants[].sellersCapacity` | `{ capacity }`: `Legal Owner`, `Personal Representative for a Deceased Owner`, `Under Power of Attorney`, `Mortgagee in Possession`, `Company Director`, `Company Secretary`, `Trustee`, `Assistant`, `Other` |
| `dateBecameOwnerOrAuthority` | `participants[].dateBecameOwnerOrAuthority` | |

**Emitted for every seller**, whether or not a capacity has been declared yet, so the credential embodying the Seller role is never missing while a form is still being filled in.

**What it is NOT:** The SellerCapacity entity does not contain leasehold terms, tenure, or title register details. Those are properties of the Title itself.

### 4.7 Offer Entity

An offer made by a prospective buyer. Projected from `participants[]` carrying an `offerId`, merged with that offer's terms from `Transaction.offers[offerId]`. **Implies the Buyer role.**

| Field | Source | Description |
|-------|--------|-------------|
| `id` | generated | `urn:pdtf:offer:{id}` |
| `buyer` | `participants[].participant` | DID of the Person or Organisation making the offer |
| `transaction` | `Transaction.id` | Transaction DID |
| `offerId` | `participants[].offerId` | The key of this offer in `Transaction.offers` |
| `amount`, `currency`, `status` | `offers[offerId].*` | Status: `Pending`, `Accepted`, `Withdrawn`, `Rejected`, `Note of Interest` |
| `inclusions`, `exclusions`, `conditions` | `offers[offerId].*` | |
| `buyerCircumstances` | `offers[offerId].buyerCircumstances` | First-time buyer, chain, mortgage requirement |
| `metadata` | `offers[offerId].metadata` | Vendor-namespaced |

An Offer always identifies exactly one buyer. Joint purchasers each hold an Offer credential with the same `offerId`.

### 4.8 Gift Entity

A gift of funds towards a purchase. Projected from `participants[]` on the Giftor branch. **Implies the Giftor role.**

| Field | Source | Description |
|-------|--------|-------------|
| `id` | generated | `urn:pdtf:gift:{id}` |
| `donor` | `participants[].participant` | DID of the Person or Organisation making the gift |
| `transaction` | `Transaction.id` | Transaction DID |
| `offerId` | `participants[].offerId` | The offer this gift contributes towards. Held here rather than on Offer so that an Offer credential always identifies a buyer. |
| `giftDetails` | `participants[].giftDetails` | `amount`, `currency`, `relationshipToBuyer`, `fundsTransferred` (`None`/`Part`/`All`), `repayable`, `confersBeneficialInterest`, `willOccupyProperty` |

### 4.9 Representation Entity

One party instructed by another. Projected from `participants[]` with a non-empty `actingFor`, **one entity per (representative, represented party) pair** (D33).

| Field | Source | Description |
|-------|--------|-------------|
| `id` | generated | `urn:pdtf:representation:{id}` |
| `representative` | `participants[].participant` | DID of the Person or Organisation who is instructed |
| `representedParty` | `participants[].actingFor[n]`, resolved against `participants[*].participantId` (or `did`) | DID of the Person or Organisation who instructed them |
| `role` | `participants[].role` | The kind of representation: `Seller's Conveyancer`, `Buyer's Conveyancer`, `Estate Agent`, `Buyer's Agent`, `Mortgage Broker`, `Surveyor`, … (the v3 role enum) |
| `transaction` | `Transaction.id` | Transaction DID |

**v3 additions that make this derivable:** `participants[].participantId` (stable identity within the transaction) and `participants[].actingFor` (the `participantId`s this participant is instructed by). Both are optional and additive. Previously v3 referred to people by role only, so a representation relationship was underivable: two sellers with separate conveyancers were unrepresentable.

**Issuer semantics:** The instructing party issues (or, in Phase 1, the platform issues on their behalf). The representative's firm is on the Transaction roster, not here.

### 4.10 TransactionRole Entity

A party's role where no more specific relationship credential applies — Lender, Landlord, Tenant, Surveyor, Platform Support — or where the specific relationship is not yet established. Projected from `participants[]` with a `role` and no other role-bearing credential.

| Field | Source | Description |
|-------|--------|-------------|
| `id` | generated | `urn:pdtf:role:{id}` |
| `participant` | `participants[].participant` | DID of the Person or Organisation holding the role |
| `role` | `participants[].role` | The v3 role enum |
| `transaction` | `Transaction.id` | Transaction DID |

Asserts participation in a role, not a relationship to another named party. It is the guarantee that every participant carrying a role has exactly one credential embodying it.

### 4.11 Transaction roster

`Transaction.participants[]` is an ordered list, one entry per party, carrying only what remains true of a party regardless of any relationship:

| Field | Source | Description |
|-------|--------|-------------|
| `participant` | `participants[].did` | DID reference to the Person or Organisation entity |
| `participantId` | `participants[].participantId` | Transaction-local identity; the fallback for implementations that do not mint DIDs |
| `organisation` | `participants[].organisation` | The firm the participant works for |
| `organisationReference` | `participants[].organisationReference` | The firm's own reference |

The array order is the v3 participants order and is authoritative for recomposition.

---

## 5. Identifier System

### 5.1 Identifier Types

| Entity | Identifier Format | Example | Source |
|--------|------------------|---------|--------|
| Transaction | `did:web` | `did:web:platform.example.com:transactions:abc123` | Platform-assigned; embeds the v3 `transactionId` |
| Property | `urn:pdtf:uprn:{uprn}` | `urn:pdtf:uprn:100023456789` | Ordnance Survey UPRN |
| Title | `urn:pdtf:titleNumber:{number}` | `urn:pdtf:titleNumber:AB12345` | HMLR title number |
| Title (unregistered) | `urn:pdtf:unregisteredTitle:{id}` | `urn:pdtf:unregisteredTitle:ut-7f3a` | Generated, may transition to registered |
| Person | `did:key` | `did:key:z6Mkhabc123...` | The party's own DID, stable across transactions |
| Organisation | `did:web` | `did:web:smithandco.law` | Self-hosted or orchestrator-hosted |
| SellerCapacity | `urn:pdtf:capacity:{id}` | `urn:pdtf:capacity:own-1a2b` | Generated |
| Offer | `urn:pdtf:offer:{id}` | `urn:pdtf:offer:off-7g8h` | Generated (or migrated from v3 offer key) |
| Gift | `urn:pdtf:gift:{id}` | `urn:pdtf:gift:gf-9i0j` | Generated |
| Representation | `urn:pdtf:representation:{id}` | `urn:pdtf:representation:rep-3c4d` | Generated |
| TransactionRole | `urn:pdtf:role:{id}` | `urn:pdtf:role:tr-5e6f` | Generated |

Entity ids come from the `idFactory` passed to `decompose`. The built-in default is deterministic and derived from `transactionId`, so repeated runs are stable and diffable, but it is a placeholder: supply your own to mint real identifiers. `Transaction.id` is synthetic — `decompose` mints it and `recompose` drops it — so the choice of DID method makes no difference to the v3 that comes back.

### 5.2 ID-Key Migration from v3

| v3 Collection | v3 Key | v4 Key | Notes |
|--------------|--------|--------|-------|
| `participants[]` | Array index | Person/Org DID (`participants[].did`) | Roster order preserved on `Transaction.participants[]` |
| `titlesToBeSold[]` | Array index | `urn:pdtf:titleNumber:{n}` | Natural key from `titleNumber` field |
| `offers{}` | Existing string key | `urn:pdtf:offer:{existing-key}` | Already ID-keyed, wrap in URN |
| `enquiries{}` | Existing string key | Preserved | Already ID-keyed |
| `searches[]` | Array index | Generated or `providerReference` | Need stable key strategy |
| `documents[]` | Array index | Generated | Need stable key strategy |
| `surveys[]` | Array index | Generated | Need stable key strategy |
| `valuations[]` | Array index | `valuationId` | Natural key already exists |
| `contracts[]` | Array index | Generated | Need stable key strategy |
| `chain.onwardPurchase[]` | Array index | `transactionId` | Natural key already exists |

---

## 6. v4 Combined Schema

### 6.1 Top-Level Structure

Composed v4 state keeps the Transaction's own fields at the top level, with ID-keyed maps for the data entities and one collection per relationship credential type:

```json
{
  "$schema": "https://trust.propdata.org.uk/schemas/v4/combined.json",
  "id": "did:web:platform.example.com:transactions:abc123",
  "transactionId": "abc123",
  "status": "Active",
  "externalIds": { ... },

  "saleContext": {
    "numberOfSellers": 2,
    "numberOfNonUkResidentSellers": 0,
    "outstandingMortgage": "Yes",
    "existingLender": "Nationwide",
    "hasHelpToBuyEquityLoan": "No",
    "isLimitedCompanySale": "No",
    "legalOwners": { ... }
  },

  "milestones": { ... },
  "contracts": [ ... ],
  "chain": { ... },
  "valuationComparisonData": { ... },
  "offers": { "o1": { "amount": 450000, "currency": "GBP", "status": "Accepted", "buyerCircumstances": { ... } } },
  "enquiries": { ... },

  "property": "urn:pdtf:uprn:100023456789",
  "titlesToBeSold": ["urn:pdtf:titleNumber:AB12345"],

  "participants": [
    { "participant": "did:key:z6Mkh...abc", "participantId": "s1" },
    { "participant": "did:key:z6Mkh...xyz", "participantId": "b1" },
    { "participant": "did:key:z6Mkj...c1",  "participantId": "c1", "organisation": "Smith & Co Law", "organisationReference": "SC/118" },
    { "participant": "did:key:z6Mkj...c2",  "participantId": "c2", "organisation": "Jones Legal", "organisationReference": "JL/42" },
    { "participant": "did:web:bigbank.co.uk", "participantId": "l1" }
  ],

  "persons": {
    "did:key:z6Mkh...abc": { /* Person */ },
    "did:key:z6Mkh...xyz": { /* Person */ }
  },
  "organisations": {
    "did:web:smithandco.law": { /* Organisation */ },
    "did:web:bigbank.co.uk": { /* Organisation */ }
  },
  "properties": {
    "urn:pdtf:uprn:100023456789": { /* Property — full propertyPack data */ }
  },
  "titles": {
    "urn:pdtf:titleNumber:AB12345": { /* Title — register, tenure, encumbrances */ }
  },

  "sellerCapacities": {
    "urn:pdtf:capacity:own-1": {
      "seller": "did:key:z6Mkh...abc",
      "transaction": "did:web:platform.example.com:transactions:abc123",
      "sellersCapacity": { "capacity": "Legal Owner" }
    }
  },
  "offerCredentials": {
    "urn:pdtf:offer:off-1": {
      "buyer": "did:key:z6Mkh...xyz",
      "transaction": "did:web:platform.example.com:transactions:abc123",
      "offerId": "o1",
      "amount": 450000, "currency": "GBP", "status": "Accepted"
    }
  },
  "gifts": { },
  "representations": {
    "urn:pdtf:representation:rep-1": {
      "representative": "did:key:z6Mkj...c1",
      "representedParty": "did:key:z6Mkh...abc",
      "role": "Seller's Conveyancer",
      "transaction": "did:web:platform.example.com:transactions:abc123"
    },
    "urn:pdtf:representation:rep-2": {
      "representative": "did:key:z6Mkj...c2",
      "representedParty": "did:key:z6Mkh...xyz",
      "role": "Buyer's Conveyancer",
      "transaction": "did:web:platform.example.com:transactions:abc123"
    }
  },
  "transactionRoles": {
    "urn:pdtf:role:tr-1": {
      "participant": "did:web:bigbank.co.uk",
      "role": "Lender",
      "transaction": "did:web:platform.example.com:transactions:abc123"
    }
  }
}
```

### 6.2 What Changed from v3

| Change | v3 | v4 | Breaking? |
|--------|----|----|-----------|
| Participants | `participants[]` array with `role` | `participants[]` roster (no role) + `persons{}` / `organisations{}` + relationship credentials carrying role | Yes — structural |
| Titles | `propertyPack.titlesToBeSold[]` and `propertyPack.ownership.ownershipsToBeTransferred[]` | `titles{}` (ID-keyed), correlated by `titleNumber`; order on `Transaction.titlesToBeSold[]` | Yes — merged + restructured |
| Property pack | `propertyPack` | `properties{}` (ID-keyed by UPRN) | Yes — wrapped in map |
| Residual ownership | `propertyPack.ownership.*` (except `ownershipsToBeTransferred`), `propertyPack.legalOwners` | `Transaction.saleContext` | Yes — moved |
| Offers | `offers{}` (ID-keyed) + `participants[].offerId` | `offers{}` unchanged; one `Offer` credential per buyer, `Gift` credential per giftor | Minor — additive |
| Role | `participants[].role` | Only on the relationship credential that embodies it (D32) | Yes — moved |
| Representation | underivable (role only) | `Representation` per (representative, represented party) pair, from new optional `participantId` / `actingFor` | Additive on v3 |
| Enquiries | `enquiries{}` (ID-keyed) | `enquiries{}` (unchanged) | No |

---

## 7. Transformation Rules

### 7.1 Schema generation (v3 combined → entity schemas)

`npm run generate:v4` reads `v3/combined.json` and emits the ten entity schemas, which define the `credentialSubject` shape for Verifiable Credentials, together with `v4/mapping.json`.

**Generation rules:**

1. **Property** — `propertyPack` minus `titlesToBeSold`, `ownership` and `legalOwners`.
2. **Title** — the union of `propertyPack.titlesToBeSold[*]` and `propertyPack.ownership.ownershipsToBeTransferred[*]`, including the `oneOf` tenure branches (leasehold, managed freehold/commonhold, estate rentcharges, whole freehold). `titleNumber` is the one shared key and correlates the two.
3. **Transaction** — every top-level v3 field except `propertyPack` and `participants`, plus `saleContext` (the rest of `propertyPack.ownership`, and `propertyPack.legalOwners`), `property`, `titlesToBeSold[]` and the `participants[]` roster.
4. **Person** — the party fields of `participants[*]` (§4.4).
5. **Organisation** — standalone; not generated from v3.
6. **Relationship credentials** — projected from `participants[*]` per §4.6–4.10, with `SellerCapacity` derived from the Seller branch (`sellersCapacity`, `dateBecameOwnerOrAuthority`) and `Gift` from the Giftor branch (`giftDetails`).

Rules are **prefix rewrites**, resolved by longest-prefix match (`{index}` matches an array index), so pointers far deeper than anything listed resolve correctly and the manifest does not churn when a v3 field is added. `verifyCoverage()` runs at generation time and fails the build if any v3 key is unclaimed, or if a rule claims a key absent from its target entity.

### 7.2 Recomposition (entities → v3 combined)

`recompose(entities)` reverses `decompose`, to deep equality with documented exceptions.

**Recomposition rules:**

1. **Roster + credentials → `participants[]`.** Walk `Transaction.participants[]` in order. For each entry, take the party fields from the Person, the roster's `participantId`, `organisation` and `organisationReference`, and then the role and relationship fields from whichever credential names this participant: `SellerCapacity` → `role: "Seller"`, `sellersCapacity`, `dateBecameOwnerOrAuthority`; `Offer` → `role: "Buyer"` (or `"Prospective Buyer"`), `offerId`; `Gift` → `role: "Giftor"`, `offerId`, `giftDetails`; `Representation` → `role`, `actingFor` (the represented parties' `participantId`s); `TransactionRole` → `role`. A participant named by no credential has no role.
2. **`titles{}` → `propertyPack.titlesToBeSold[]` and `propertyPack.ownership.ownershipsToBeTransferred[]`** — split each Title by the keys each source array owns, in `Transaction.titlesToBeSold[]` order. A Title carrying only shared keys goes to `titlesToBeSold` alone.
3. **`properties{}` → `propertyPack`** — unwrap (single property).
4. **`saleContext` → `propertyPack.ownership` and `propertyPack.legalOwners`.**
5. **`offers{}` → `offers{}`** — unchanged; the buyer linkage is restored via `participants[].offerId` from the Offer and Gift credentials.
6. `Transaction.id` is dropped; `$schema` is always emitted.

**Known exceptions** (carried at runtime in `mapping.roundTrip.knownExceptions`): overlay metadata keys (`*Ref`, `*Required`) are schema-level only and never appear in instances; `ownershipsToBeTransferred` is canonicalised to `titlesToBeSold` order (its order carries no meaning in v3); an explicitly empty container recomposes as absent.

**Refused rather than guessed:** a `titleNumber` repeated within one source array, or a `did` repeated across participants, throws.

### 7.3 Graph Composition (entity VCs → v4 state)

Assembles full transaction state from individual entity Verifiable Credentials. This is the reverse of extraction, operating on credential payloads rather than schemas.

**Composition rules:**

1. Start with the Transaction VC as the root
2. Resolve `property` and `titlesToBeSold[]` → merge Property and Title VC `credentialSubject` data
3. Resolve roster DIDs → merge Person / Organisation data
4. Collect every relationship credential whose `transaction` is this Transaction → populate `sellerCapacities{}`, `offerCredentials{}`, `gifts{}`, `representations{}`, `transactionRoles{}`. Nothing nests: a credential's position is determined by its type, and its parties by the DIDs it names.
5. Verify credential signatures and revocation status during composition. A revoked relationship credential is dropped, and with it the role it embodied.
6. Output: complete v4 state object (or further recompose to v3)

**Dual output:**
- `composeV4StateFromGraph(credentials[])` → v4 combined state
- `composeV3StateFromGraph(credentials[])` → v4 composition + recomposition (§7.2)

---

## 8. Collection Conversion Details

### 8.1 Collections Converting from Arrays to ID-Keyed Maps

| Collection | v3 (array) | v4 (ID-keyed) | ID Source |
|-----------|------------|---------------|----------|
| `participants[]` | Index-based | `participants[]` roster (order kept) + `persons{}` / `organisations{}` + relationship credentials | DID |
| `titlesToBeSold[]`, `ownership.ownershipsToBeTransferred[]` | Index-based | `titles{}` (order kept on `Transaction.titlesToBeSold[]`) | `urn:pdtf:titleNumber:{titleNumber}` |
| `searches[]` | Index-based | `properties[uprn].searches{}` | `providerReference` or generated |
| `documents[]` | Index-based | `properties[uprn].documents{}` | Generated |
| `surveys[]` | Index-based | `properties[uprn].surveys{}` | Generated |
| `valuations[]` | Index-based | `properties[uprn].valuations{}` | `valuationId` (natural key) |
| `contracts[]` | Index-based | `contracts{}` | Generated |
| `chain.onwardPurchase[]` | Index-based | `chain.onwardPurchase{}` | `transactionId` (natural key) |
| `media[]` | Index-based | `properties[uprn].media{}` | Generated |

### 8.2 Collections Already ID-Keyed (no change)

| Collection | Key Type |
|-----------|----------|
| `offers{}` | String key (becomes URN) |
| `enquiries{}` | String key (preserved) |
| All `externalIds{}` | Pattern maps |

### 8.3 Value Arrays (remain as arrays)

The following are *value lists*, not entity collections. They remain as arrays:

- `ownershipsToBeTransferred[].additionalDocuments[]`
- `energyEfficiency.recommendations[]`
- `fixturesAndFittings.*.otherItems[]`
- `localLandCharges[]`
- Planning decision arrays
- Survey photo arrays
- `legalOwners.namesOfLegalOwners[]` (migrates to Person/Org entities)
- Environmental risk subcategory arrays
- All `conditions[]`, `inclusions[]`, `exclusions[]` on Offers

---

## 9. Open Questions

### 9.1 For LMS / Implementer Discussion

1. **Search ID strategy**
   *Question:* `providerReference` is available but may not be unique across providers. Should we generate synthetic IDs, or use a composite key (`providerName:providerReference`)?
   *Working Assumption:* Providers mint their own IDs with the strict requirement that they are globally unique (effectively a URN or UUID). If extracting from PDFs without native IDs, we synthesise a deterministic ID (e.g., hash of search type + provider + date).

2. **Multi-property transactions**
   *Question:* The v4 model supports `properties{}` with multiple UPRNs. How should overlays and form mappings work when there's more than one property?
   *Working Assumption:* The schema is constrained to **single property, multi-title** only. A transaction models exactly one Property entity, but may link to multiple Title entities (e.g., freehold + leasehold, or house + separate garage). This makes form mapping trivial.

3. **Organisation discovery & identity**
   *Question:* How do Organisations identify themselves? Do we need a registry?
   *Working Assumption:* We introduce `Organisation` as a discrete entity in the graph holding org-level data (Companies House, SRA number), distinct from individual `Person` participants. Trust resolution will use OpenID Federation Trust Marks, tying identities to verifiable framework registries.

4. **Participant migration**
   *Question:* Current participants with `role: "Seller's Conveyancer"` become a roster entry plus a Representation credential (once `actingFor` is populated) or a TransactionRole credential (until it is). What's the migration strategy for live transactions?
   *Working Assumption:* Translation is purely in code and unidirectional (**v4 → v3 mapping only**). The v4 entity graph is fully self-describing, and backend systems will dynamically recompose v3 bundles for legacy consumers.

5. **Evolving identifiers (Unregistered Titles / No UPRN)**
   *Question:* When an unregistered title gets registered, or a new build receives a UPRN, how does the URN transition?
   *Working Assumption:* We use the standard W3C `alsoKnownAs` property on the Verifiable Credential. The new VC uses the permanent identifier as its `subject.id`, but lists the old synthetic/unregistered identifier in `alsoKnownAs`. Traversal logic will resolve both to the same entity.

### 9.2 Internal (Platform)

6. **v4 combined.json creation** — First step is transforming current v3 combined.json to v4 format. This is the bootstrap for all subsequent extraction and tooling work.

7. **Overlay compatibility** — Current overlays (BASPI, NTS, TA, CON29R) reference v3 paths. Need overlay migration strategy or dual-path overlay resolution.

8. **Scoped consent** — v0.2's `DelegatedConsent` carried an access `scope`, a `purpose` and an expiry. D32 withdraws it as an entity, because the lender's participation is already embodied by `TransactionRole` and a second role-bearing record was the problem D32 solves. Whether a separate, scoped, time-limited consent credential should sit on top of the relationship credentials for access control is an open consultation question.

---

## 10. Implementation Plan

### Phase 1: Schema generation *(done — schemas repo `dev`)*
1. `generate:v4` emits the ten entity schemas and `v4/mapping.json` from `v3/combined.json`
2. `verifyCoverage()` fails the build on any unclaimed v3 key
3. v3 gains optional `participants[].participantId`, `actingFor` and `did`

### Phase 2: Decompose / recompose *(done — schemas repo `dev`)*
4. `decomposeToV4(v3)` → entities + relationship credentials, with a pluggable `idFactory`
5. `recomposeFromV4(entities)` → v3, to deep equality with documented exceptions
6. Round-trip tests: the example transaction, a synthetic awkward instance (two-array title merge, index divergence, one-sided titles), edge cases, and a 3,000-transaction production round trip

### Phase 3: Graph Composition
7. Implement `composeV4StateFromGraph()` over signed credentials (§7.3)
8. Implement `composeV3StateFromGraph()` = composition + recomposition
9. Fixture generation to exercise the ~88% of the v3 leaf-path surface the example transaction does not touch

### Phase 4: Overlay Migration
12. Map v3 overlay paths to v4 entity paths
13. Generate entity-specific overlays
14. Validate: overlays apply correctly to entity schemas

---

## Appendix A: v3 Participant Role → v4 Credential Mapping

Every participant carrying a role receives exactly one role-bearing credential. The roster entry (DID, local id, firm) is emitted for every participant regardless.

| v3 Role | Role-bearing credential | How role is carried | Notes |
|---------|------------------------|---------------------|-------|
| `Seller` | SellerCapacity | implied | Emitted for every seller, capacity declared or not |
| `Prospective Buyer` | Offer (status: Pending / Note of Interest) | implied | Or TransactionRole until an `offerId` exists |
| `Buyer` | Offer (status: Accepted) | implied | One per buyer; joint purchasers share an `offerId` |
| `Giftor` | Gift | implied | Carries the giftor's `offerId` |
| `Seller's Conveyancer` | Representation | explicit `role` | `representedParty` = the seller(s) in `actingFor`; one credential per seller |
| `Buyer's Conveyancer` | Representation | explicit `role` | `representedParty` = the buyer |
| `Estate Agent` | Representation | explicit `role` | `representedParty` = the seller |
| `Buyer's Agent` | Representation | explicit `role` | `representedParty` = the buyer |
| `Mortgage Broker` | Representation | explicit `role` | `representedParty` = the buyer |
| `Surveyor` | Representation if `actingFor` is set, else TransactionRole | explicit `role` | |
| `Lender` | TransactionRole | explicit `role` | Participation, not representation |
| `Landlord` | TransactionRole | explicit `role` | Leasehold context |
| `Tenant` | TransactionRole | explicit `role` | Occupancy, not ownership |
| `Platform Support` | TransactionRole | explicit `role` | |

Any role with a non-empty `actingFor` yields Representation(s); any role with none and no implied credential yields a TransactionRole.

---


