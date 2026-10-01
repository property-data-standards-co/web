---
title: The Entity Graph
description: How PDTF 2.0 decomposes property transactions into ten independently verifiable entities.
---

## Why an entity graph?

PDTF v1 represents a property transaction as a single monolithic JSON document — approximately 4,000 paths covering everything from the seller's name to the flood risk assessment. This made the schema comprehensive, but it also meant:

- **Every credential contains everything.** A conveyancer updating the completion date must issue a claim touching the same document as the EPC provider. There's no separation of concerns.
- **Data doesn't survive the transaction.** When a sale falls through, all that verified data — searches, EPCs, title information — is locked inside a transaction object. The next buyer starts from scratch.
- **Verification is all-or-nothing.** You can't verify the EPC data independently of the title data. The trust model is coarse-grained.

PDTF 2.0 solves this by decomposing the monolithic schema into ten distinct entity types, each independently identifiable and independently verifiable.

## The ten entities

Five entities carry data. Five are **relationship credentials**: thin, signed assertions that link a party to a transaction and, in doing so, embody that party's role.

| Entity | Identifier | What it represents |
|--------|-----------|-------------------|
| **Transaction** | `did:web:host:transactions:{id}` | This particular sale: status, milestones, offers, enquiries, contracts, chain position, and the roster of parties |
| **Property** | `urn:pdtf:uprn:{uprn}` | The physical property: address, features, energy performance, environmental data, legal disclosures |
| **Title** | `urn:pdtf:titleNumber:{number}` | The legal title: register extract, tenure, leasehold terms, encumbrances |
| **Person** | `did:key:z6Mkh...` | A natural person: name, contact details, verification status. Role-free. |
| **Organisation** | `did:web:smithandco.law` | A legal entity: law firm, estate agency, lender |
| **SellerCapacity** | `urn:pdtf:capacity:{id}` | The capacity in which a person or organisation sells (legal owner, executor, attorney…). Implies the Seller role. |
| **Offer** | `urn:pdtf:offer:{id}` | An offer to buy: amount, status, conditions, buyer circumstances. Implies the Buyer role. |
| **Gift** | `urn:pdtf:gift:{id}` | A gift of funds towards a purchase. Implies the Giftor role. |
| **Representation** | `urn:pdtf:representation:{id}` | One party instructed by another: a conveyancer acting for a seller, an agent acting for a buyer. Carries the kind of representation as its role. |
| **TransactionRole** | `urn:pdtf:role:{id}` | A party's role where no more specific relationship applies: lender, landlord, tenant, surveyor, platform support. |

Each entity becomes the `credentialSubject` of a W3C Verifiable Credential, signed by an authorised issuer and independently verifiable.

## Roles live on the credentials

In v1 every party sits in a flat `participants[]` array with a `role` string. PDTF 2.0 keeps a roster on the Transaction, but the roster carries only what stays true of a party regardless of any relationship: their DID, a transaction-local id, and the firm they work for. **Role is stored nowhere else than on the relationship credential that embodies it.**

| Credential | Asserts | Role |
|---|---|---|
| `SellerCapacity` | this person sells, in this capacity | implied: Seller |
| `Offer` | this person made this offer | implied: Buyer |
| `Gift` | this person gifts funds towards a purchase | implied: Giftor |
| `Representation` | this party is instructed by that party | explicit: which kind of representation |
| `TransactionRole` | this party takes this role | explicit: which role |

For the first three the role follows from the credential's existence. `Representation` and `TransactionRole` each span several roles, so they carry role as their own discriminator: acting for a seller tells you the side, not whether the party is the conveyancer, the agent or the surveyor.

Every participant with a role holds exactly one role-bearing credential: the specific one where a relationship exists, `TransactionRole` otherwise.

### Why role is not on the participant

Because a second copy would not be revoked. Firing a conveyancer means revoking their `Representation`. If the transaction also recorded "Seller's Conveyancer" against that participant, revocation would remove the relationship and leave the role assertion standing: two sources of truth, disagreeing, with the stale one still readable.

Dropping a credential from the graph therefore gives back a transaction in which that party has no role and no relationship — which is exactly what revocation should mean.

### Buyers and sellers

A core design principle of the graph is that the two intents in a sale are expressed by different credentials:

1. **Transaction = intent to sell.** The Transaction represents the seller's active intent to sell the referenced Property and Title(s). The seller's `SellerCapacity` embodies that.
2. **Offer = intent to buy.** An `Offer` represents a buyer's intent to purchase. Buyers participate only through Offers; a transaction can carry several, reflecting the real process of accepting and rejecting them.

Everyone else is linked to the party they act for. A buyer's conveyancer holds a `Representation` whose represented party is the buyer; the buyer's link to their offer is the `Offer` credential itself. That keeps `Offer ⇒ Buyer` exact: a giftor contributing funds towards an offer is linked to it through `Gift`, not `Offer`.

![PDTF entity graph worked example — the 14 Elm Road sale, with every party linked to the Transaction by the credential that embodies their role](/diagrams/entity-graph-example-intents.svg)

*A worked example: the seller's SellerCapacity, the buyer's Offer, a parent's Gift, three Representations and the lender's TransactionRole all reference the Transaction. Each is a separate credential that can be presented, or revoked, on its own.*

### Access control and traversal

Because every relationship is a credential that references the Transaction, the graph itself is the access model. No central ACL is required. A party asking for transaction data presents the credential that ties them to it: a conveyancer presents their `Representation`, a lender their `TransactionRole`, a buyer their `Offer`. The holder of the data validates the chain — this Representation names a party who holds an accepted Offer on this Transaction — and decides what to release. How scoped, time-limited consent should sit on top of this is an [open consultation question](/consultation/).

## The governing principle

The decomposition follows a simple test — the **Logbook Test**:

:::tip[The Logbook Test]
Ask: *"Does this fact travel with the property, the title, or the sale?"*

- **Property** = logbook facts. If the next buyer needs to know it, it belongs on Property. EPC ratings, flood risk assessments, building materials, fixtures and fittings, TA6/TA7/TA10 responses — these are property facts.
- **Title** = legal title facts. Register extract, tenure (freehold/leasehold), encumbrances, restrictive covenants, leasehold terms. Intrinsic to the title, not the sale.
- **Transaction** = this-sale facts. Who's involved, what's the price, what stage has it reached, what's the completion date. Irrelevant to the next owner.
:::

Relationship credentials (SellerCapacity, Offer, Gift, Representation, TransactionRole) are **thin assertions** linking people and organisations to the sale. They carry just enough data to express the relationship, and are revocable when circumstances change.

## Transaction-centric graph

The Transaction is the root of the entity graph. All other entities are referenced from it, and every relationship credential references it back:

```
Transaction (did:web)                          ← intent to sell
├── property → Property (urn:pdtf:uprn)
├── titlesToBeSold[] → Title (urn:pdtf:titleNumber)
├── participants[]                             ← roster: DID, local id, firm. No roles.
│   └── → Person (did:key) / Organisation (did:web)
├── offers{}                                   ← offer terms, keyed by offer id
│
│   relationship credentials, each referencing the Transaction:
├── SellerCapacity   seller → Person            (implies Seller)
├── Offer            buyer → Person, offerId    (implies Buyer)
├── Gift             donor → Person, offerId    (implies Giftor)
├── Representation   representative → representedParty, role
└── TransactionRole  participant, role
```

This is deliberate. The Transaction provides the context — *this sale of this property* — and the graph fans out to the entities involved. But each data entity exists independently of the Transaction and can participate in multiple transactions over time.

## Entity deep-dives

### Transaction

The Transaction is the only entity that uses `did:web` as its primary identifier. This means:

- The Transaction has a resolvable DID document
- The DID document contains service endpoints for API access
- Agents and systems can discover how to interact with the transaction by resolving its DID

The Transaction carries sale-specific metadata: status, milestones, offers, enquiries, contract data, chain position, and the residual sale-level ownership facts (`saleContext`: outstanding mortgage, Help to Buy status, number of sellers). It references the Property and Titles by URN, and lists its parties in an ordered roster.

### Property

The Property entity represents the physical property and carries everything that would go in a "property logbook" — data that persists across transactions:

- **Address and location** — UPRN, coordinates, full address
- **Physical characteristics** — property type, construction, bedrooms, bathrooms, parking
- **Energy performance** — EPC data, ratings, recommendations
- **Environmental data** — flood risk, subsidence, contamination, radon
- **Legal disclosures** — TA6 (property information), TA7 (leasehold information), TA10 (fittings)
- **Searches** — local authority, environmental, drainage, mining

The Property is identified by its UPRN (`urn:pdtf:uprn:{uprn}`), which is a stable, nationally unique identifier for every addressable location in the UK.

:::note[Data portability]
When a sale falls through, Property credentials remain valid. The next buyer inherits all the verified property data — searches, EPCs, environmental assessments — without re-ordering them. This is one of the most significant practical benefits of the entity decomposition.
:::

### Title

The Title entity represents the legal title registered at HM Land Registry:

- **Title number** — the unique identifier
- **Register extract** — proprietorship, charges, restrictions
- **Tenure** — freehold, leasehold, commonhold, managed freehold
- **Leasehold terms** — if applicable: lease length, ground rent, service charges, management company
- **Encumbrances** — easements, covenants, notices

A single Property can have multiple Titles (e.g. the freehold and a long leasehold), and a single Title can cover multiple Properties. The relationship is many-to-many, managed through the Transaction's references.

### Person

A Person entity represents a natural person. Critically, it is **role-free**. A Person has no inherent role in a transaction — their role is determined entirely by the relationship credentials that reference them:

- Referenced by a **SellerCapacity** → they're selling
- Referenced by an **Offer** → they're buying
- Referenced by a **Gift** → they're gifting funds
- Referenced by a **Representation** as the representative → they've been instructed; as the represented party → they've instructed someone

A Person's `did:key` is minted once and is stable **across** transactions. Someone selling one property and buying another appears in two transactions as the same subject: one wallet, accumulating credentials, not one identity per participation.

### Organisation

An Organisation represents a legal entity — a law firm, estate agency, lender, or other corporate participant. Organisations use `did:web` identifiers, allowing them to host DID documents with service endpoints.

Organisation is the one entity that stands outside the mechanical v3 round trip: the roster records a participant's firm by name and reference, and resolving the participant's DID gives the Organisation.

### SellerCapacity

SellerCapacity is a **thin credential** — a signed assertion of the capacity in which a person or organisation is acting to transfer title: legal owner, personal representative for a deceased owner, attorney under a power of attorney, mortgagee in possession, company director, trustee.

```json
{
  "credentialSubject": {
    "id": "urn:pdtf:capacity:abc123",
    "seller": "did:key:z6MkhSellerDID",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "sellersCapacity": { "capacity": "Legal Owner" },
    "dateBecameOwnerOrAuthority": "2014-06-01"
  }
}
```

It carries no duplicated data from either the Person or the Title. It simply asserts the relationship. Verification happens by cross-referencing the claim against the Title's register extract (proprietorship data). It is scoped to the transaction, since the Transaction already lists the titles being sold; an optional `title` reference narrows it where a sale involves several.

One SellerCapacity is issued for **every** seller, whether or not a capacity has been declared yet, so the credential embodying the Seller role is never missing while a form is still being filled in. It is **revocable** — essential for when property changes hands.

### Offer

An Offer links a buyer to a Transaction. It captures offer amount, currency, status (pending, accepted, rejected, withdrawn), inclusions, exclusions, conditions, and buyer circumstances (first-time buyer, chain position, mortgage status).

```json
{
  "credentialSubject": {
    "id": "urn:pdtf:offer:off-j1k2l3",
    "buyer": "did:key:z6MkhBuyerDID",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "offerId": "o1",
    "amount": 450000,
    "currency": "GBP",
    "status": "Accepted"
  }
}
```

Buyers exist in the transaction graph only through Offers — there is no separate "buyer participation" entity. A prospective buyer who has not yet made an offer can still be represented, because Representation links to the person, not the offer.

### Gift

A Gift records that a person is contributing funds towards a purchase: the terms a conveyancer has to resolve before reporting to a lender (whether the gift is repayable, whether the giftor will have an interest in the property, and so on).

```json
{
  "credentialSubject": {
    "id": "urn:pdtf:gift:g1",
    "donor": "did:key:z6MkhParentDID",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "offerId": "o1",
    "giftDetails": { "repayable": false, "confersBeneficialInterest": false }
  }
}
```

The link from giftor to offer lives here rather than on Offer, so that an Offer credential always identifies a buyer.

### Representation

Representation is a thin credential that records one party being instructed by another:

```json
{
  "credentialSubject": {
    "id": "urn:pdtf:representation:def456",
    "representative": "did:key:z6MkhConveyancerDID",
    "representedParty": "did:key:z6MkhSellerDID",
    "role": "Seller's Conveyancer",
    "transaction": "did:web:platform.example.com:transactions:tx-789"
  }
}
```

There is one Representation per **(representative, represented party)** pair. A conveyancer instructed jointly by two sellers holds two, each presentable or revocable on its own. A separated couple instructing their own conveyancers yields one each — the case the old role-only model could not express at all.

The retainer is with the client, so a conveyancer is instructed by a person, not by an offer. The representative is the party who was instructed; the firm they work for is recorded on the Transaction roster, because where someone works does not stop being true when a representation ends.

Like SellerCapacity, it's revocable — because clients can and do change solicitors mid-transaction.

### TransactionRole

Some parties take a role in a sale without a relationship to a specific other party: the lender, a landlord or tenant, a surveyor instructed by nobody in the graph, platform support. TransactionRole asserts participation in that role.

```json
{
  "credentialSubject": {
    "id": "urn:pdtf:role:r1",
    "participant": "did:web:bigbank.co.uk",
    "role": "Lender",
    "transaction": "did:web:platform.example.com:transactions:tx-789"
  }
}
```

It is also the fallback while a more specific relationship is not yet established, so that every party carrying a role has exactly one credential embodying it.

## ID-keyed collections

Entity collections in the v4 schema use **ID-keyed maps**, not arrays:

```json
{
  "properties": {
    "urn:pdtf:uprn:123456789": { /* Property entity */ }
  },
  "titles": {
    "urn:pdtf:titleNumber:ABC12345": { /* Title entity */ }
  }
}
```

This enables:
- **Deterministic addressing** — credential subjects reference entities by their ID
- **Merge semantics** — updates target a specific entity by key, no index fragility
- **Graph traversal** — follow references by ID without relying on array positions

Where v3 array order carried meaning, it lives on the Transaction: `titlesToBeSold` and `participants` are ordered reference lists, authoritative for recomposition. No position is written into the entity documents themselves, so a credential never carries an index that could diverge from another producer's.

## From monolithic to graph: the transformation

The entity decomposition is a **mechanical transformation**, not a creative redesign. Every path in the v3 monolithic schema maps to exactly one place in the v4 graph, by longest-prefix rule:

| v3 path | v4 destination |
|---------------|-----------|
| `propertyPack.titlesToBeSold[*]` | Title |
| `propertyPack.ownership.ownershipsToBeTransferred[*]` | Title (correlated with the above by `titleNumber`) |
| `propertyPack.ownership.*` (the rest), `propertyPack.legalOwners` | `Transaction.saleContext` |
| `propertyPack.*` (everything else) | Property |
| `participants[*]` — party facts | Person |
| `participants[*]` — transaction-scoped identity and firm | `Transaction.participants[]` |
| `participants[*]` — role and relationship fields | SellerCapacity, Offer, Gift, Representation, TransactionRole |
| everything else | Transaction |

The mapping is generated, published alongside the schemas as a manifest, and checked at build time: a v3 field with no home in v4 is a hard error rather than a field that silently disappears. The State Assembly specification defines both `composeV3StateFromGraph()` (backward-compatible reassembly) and `composeV4StateFromGraph()` (new ID-keyed format).

[Read the full entity graph specification →](/specs/01-entity-graph/)
