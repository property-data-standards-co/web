---
title: "Entities"
description: "The nine entity types that compose the PDTF graph"
---

PDTF 2.0 replaces the old monolithic transaction document with an **entity graph**. Instead of one giant schema containing everything, the model is decomposed into independently identifiable entities linked by explicit relationships.

## Why PDTF uses an entity graph

The old structure made provenance, reuse, and verification awkward. In PDTF 2.0, each part of a transaction can be addressed, credentialed, and verified separately.

This enables:

- independent credentials for property, title, and transaction data
- clearer separation between enduring facts and sale-specific facts
- better provenance and trust decisions
- backward-compatible state composition for legacy consumers

The graph is **transaction-centric**. A transaction references the relevant properties, titles, people, organisations, and relationship entities.

## The nine core entity types

### Primary entities

- **Transaction**: the root of the graph, identified by `did:web`
- **Property**: enduring physical-property facts, identified by `urn:pdtf:uprn:{uprn}`
- **Title**: legal title facts, identified by `urn:pdtf:titleNumber:{number}` or an unregistered-title URN
- **Person**: a natural person, identified by `did:key`
- **Organisation**: a firm or company, identified by `did:key` or `did:web`

### Relationship entities

- **Ownership**: links a person or organisation to a title
- **Representation**: delegated authority to act for someone
- **DelegatedConsent**: authorised access for a third party such as a lender
- **Offer**: links buyer parties to a transaction

## The logbook test

The main rule for placing data is simple:

> **Does this fact travel with the property to a new owner?**

If yes, it usually belongs on **Property**. If it is intrinsic to the legal estate, it belongs on **Title**. If it describes this sale only, it belongs on **Transaction**.

Examples:

- EPC data, flood risk, fixtures and fittings, planning history → **Property**
- register extract, title number, leasehold terms → **Title**
- number of sellers, outstanding mortgage, completion arrangements → **Transaction**

## Relationships are explicit

PDTF 2.0 avoids vague participant records. Instead, it models precise relationship types.

### Ownership

Ownership is a **thin claim**: a person or organisation asserts ownership of a title. The supporting evidence sits on the Title entity, especially the proprietorship section of the register extract.

### Representation

Representation records authority such as:

- seller conveyancer
- buyer conveyancer
- estate agent
- buyer agent

This is usually granted to the **firm**, not an individual fee earner.

### DelegatedConsent

This covers authorised access for entities that need data but are not direct participants, for example a lender.

### Offer

Buyers enter the transaction through offers. This matches the real-world process better than treating every potential buyer as a generic participant.

## Example shape

```text
Transaction
├── Property[]
├── Title[]
├── Person[]
├── Organisation[]
├── Ownership[]
├── Representation[]
├── DelegatedConsent[]
└── Offer[]
```

## Why it matters

The entity graph is the structural foundation of PDTF 2.0. It lets systems issue credentials against the correct subject, compose state from multiple trusted sources, and keep property facts separate from transaction-specific context.

That separation is what makes the framework scalable, auditable, and reusable across different platforms. Instead of one platform-specific blob, PDTF becomes a graph of verifiable facts with clear trust boundaries.
