---
title: "Entities"
description: "The ten entity types that compose the PDTF graph"
---

PDTF 2.0 replaces the old monolithic transaction document with an **entity graph**. Instead of one giant schema containing everything, the model is decomposed into independently identifiable entities linked by explicit relationships.

## Why PDTF uses an entity graph

The old structure made provenance, reuse, and verification awkward. In PDTF 2.0, each part of a transaction can be addressed, credentialed, and verified separately.

This enables:

- independent credentials for property, title, and transaction data
- clearer separation between enduring facts and sale-specific facts
- better provenance and trust decisions
- backward-compatible state composition for legacy consumers

The graph is **transaction-centric**. A transaction references the relevant property, titles, people and organisations, and every relationship credential references the transaction back.

## The ten entity types

### Data entities

- **Transaction**: the root of the graph, identified by `did:web`. Carries the sale's status, milestones, offers, enquiries and an ordered roster of parties.
- **Property**: enduring physical-property facts, identified by `urn:pdtf:uprn:{uprn}`
- **Title**: legal title facts, identified by `urn:pdtf:titleNumber:{number}` or an unregistered-title URN
- **Person**: a natural person, identified by a `did:key` that is stable across transactions
- **Organisation**: a firm or company, identified by `did:web`

### Relationship credentials

Each embodies a party's role. Role is stored nowhere else.

- **SellerCapacity**: the capacity in which a person or organisation sells. Implies Seller.
- **Offer**: an offer to buy, with amount, status and conditions. Implies Buyer.
- **Gift**: a gift of funds towards a purchase. Implies Giftor.
- **Representation**: one party instructed by another, carrying the kind of representation as its role
- **TransactionRole**: a role with no more specific relationship, such as lender, landlord, tenant or surveyor

## The logbook test

The main rule for placing data is simple:

> **Does this fact travel with the property to a new owner?**

If yes, it usually belongs on **Property**. If it is intrinsic to the legal estate, it belongs on **Title**. If it describes this sale only, it belongs on **Transaction**.

Examples:

- EPC data, flood risk, fixtures and fittings, planning history → **Property**
- register extract, title number, leasehold terms → **Title**
- number of sellers, outstanding mortgage, completion arrangements → **Transaction**

## Relationships are explicit

PDTF 2.0 avoids vague participant records. The Transaction keeps a **roster** of parties, but it carries only their DID, a transaction-local id and the firm they work for. Everything about *why* a party is in the sale is a separate credential, so that revoking the credential removes the role along with the relationship.

### SellerCapacity

A **thin claim**: a person or organisation asserts the capacity in which they sell (legal owner, executor, attorney, mortgagee in possession…). The supporting evidence sits on the Title entity, especially the proprietorship section of the register extract. One is issued per seller, whether or not a capacity has been declared yet.

### Offer

Buyers enter the transaction through offers. This matches the real-world process better than treating every potential buyer as a generic participant. An Offer always identifies a buyer.

### Gift

Records that someone is contributing funds towards an offer, and the terms a conveyancer needs before reporting to a lender. The giftor's link to the offer lives here, not on Offer.

### Representation

Records that one party has instructed another, one credential per (representative, represented party) pair:

- a seller's conveyancer, instructed by the seller
- a buyer's conveyancer, instructed by the buyer
- an estate agent, instructed by the seller
- a buyer's agent or mortgage broker, instructed by the buyer

The retainer is with the client, so representation links to a person, not to an offer. The representative's firm is on the transaction roster.

### TransactionRole

Covers parties with a role but no relationship to a specific other party — lender, landlord, tenant, surveyor, platform support — and acts as the fallback until a more specific relationship is established. Every party with a role holds exactly one role-bearing credential.

## Example shape

```text
Transaction
├── property        → Property
├── titlesToBeSold  → Title[]
├── participants[]  → Person / Organisation   (roster, no roles)
├── offers{}
│
│   relationship credentials, each referencing the Transaction:
├── SellerCapacity[]
├── Offer[]
├── Gift[]
├── Representation[]
└── TransactionRole[]
```

## Why it matters

The entity graph is the structural foundation of PDTF 2.0. It lets systems issue credentials against the correct subject, compose state from multiple trusted sources, and keep property facts separate from transaction-specific context.

That separation is what makes the framework scalable, auditable, and reusable across different platforms. Instead of one platform-specific blob, PDTF becomes a graph of verifiable facts with clear trust boundaries.
