---
title: "Schemas"
description: "JSON Schema definitions for all PDTF 2.0 entity types"
---

## Overview

PDTF 2.0 models transaction data as an entity graph. The development artifact is a v4 combined schema with ID-keyed maps. Standalone entity schemas are extracted from that combined schema and become the expected `credentialSubject` shapes for W3C Verifiable Credentials.

## Core entities

| Entity | Identifier | Schema role | Description |
|---|---|---|---|
| `Transaction` | `did:web:{host}:transactions:{id}` | Root entity | Sale metadata, milestones, chain, sale context, completion, seller confirmations |
| `Property` | `urn:pdtf:uprn:{uprn}` | Logbook entity | Physical property facts that travel with the property across transactions |
| `Title` | `urn:pdtf:titleNumber:{number}` or `urn:pdtf:unregisteredTitle:{uuid}` | Legal title entity | Register extract, title extents, ownership type, leasehold terms, encumbrances |
| `Person` | `did:key:{...}` | Identity entity | Natural person, role-free, referenced by relationship entities |
| `Organisation` | `did:key` (provider-managed) or `did:web:{domain}` (self-hosted) | Identity entity | Law firm, estate agent, lender, surveyor, etc. Outside the v3 round trip |
| `SellerCapacity` | `urn:pdtf:capacity:{uuid}` | Relationship credential | The capacity in which a party sells; implies Seller |
| `Offer` | `urn:pdtf:offer:{uuid}` | Relationship credential | Buyer linkage to transaction, amount, status, conditions; implies Buyer |
| `Gift` | `urn:pdtf:gift:{uuid}` | Relationship credential | Gift of funds towards an offer; implies Giftor |
| `Representation` | `urn:pdtf:representation:{uuid}` | Relationship credential | One party instructed by another, with the kind of representation |
| `TransactionRole` | `urn:pdtf:role:{uuid}` | Relationship credential | A role with no more specific relationship |

## Top-level v4 combined structure

The v4 combined schema uses ID-keyed collections rather than arrays. The Transaction keeps an ordered roster of parties; every relationship credential references the transaction and lives in its own collection.

```json
{
  "$schema": "https://trust.propdata.org.uk/schemas/v4/combined.json",
  "id": "did:web:platform.example.com:transactions:abc123",
  "transactionId": "abc123",
  "status": "Active",
  "saleContext": {},
  "milestones": {},
  "contracts": [],
  "chain": {},
  "offers": { "o1": {} },
  "enquiries": {},
  "property": "urn:pdtf:uprn:100023456789",
  "titlesToBeSold": ["urn:pdtf:titleNumber:AB12345"],
  "participants": [
    { "participant": "did:key:z6Mkh...", "participantId": "s1" },
    { "participant": "did:key:z6Mkj...", "participantId": "c1", "organisation": "Smith & Co Law", "organisationReference": "R1" }
  ],
  "persons": { "did:key:z6Mkh...": {} },
  "organisations": { "did:web:smithandco.law": {} },
  "properties": { "urn:pdtf:uprn:100023456789": {} },
  "titles": { "urn:pdtf:titleNumber:AB12345": {} },
  "sellerCapacities": { "urn:pdtf:capacity:own-1": {} },
  "offerCredentials": { "urn:pdtf:offer:off-1": {} },
  "gifts": { "urn:pdtf:gift:gf-1": {} },
  "representations": { "urn:pdtf:representation:rep-1": {} },
  "transactionRoles": { "urn:pdtf:role:tr-1": {} }
}
```

Relationship keys such as `own-1` and `off-1` are abbreviated for readability; real keys are UUID v4 URNs such as `urn:pdtf:capacity:7c9e6679-7425-40de-944b-e07fc1f90ae7`.

`properties{}` stays an ID-keyed map for uniform addressing, but it holds exactly one Property: a transaction references one Property and one or more Titles.

:::note[Provisional]
The single-property, multi-title constraint is the working assumption in [01 §9.1 Q2](/specs/01-entity-graph/#91-for-lms--implementer-discussion) (consultation [Q11](/consultation/#q11-single-property-multiple-titles)).
:::

The roster carries only what stays true of a party regardless of any relationship: DID, transaction-local id, and firm. Role and every relationship live on the credentials, so that revoking a credential removes what it asserts (see [01 — Entity Graph](/specs/01-entity-graph/)).

## Entity schema references

### Transaction

**Identifier:** `did:web`

**Contains:**
- `transactionId`, `externalIds`, `metadata`
- `status`
- `saleContext` (residual sale-level ownership facts: outstanding mortgage, Help to Buy, number of sellers, legal owners)
- `milestones`
- `contracts`
- `chain`
- `offers`, `enquiries`
- `valuationComparisonData`
- `property` and `titlesToBeSold` references
- `participants[]` roster: `participant` DID, `participantId`, `organisation`, `organisationReference`

**Does not contain:** embedded property logbook data, title register data, or any party's role. Roles live only on the relationship credentials.

### Property

**Identifier:** `urn:pdtf:uprn:{uprn}`

**Rule:** if the next buyer needs to know it, it belongs on `Property`.

**Typical sections:**
- `address`
- `location`
- `localAuthority`
- `priceInformation`
- `lettingInformation`
- `summaryDescription`
- `marketingTenure`
- `media`
- `buildInformation`
- `residentialPropertyFeatures`
- `nearbyFacilities`
- `delayFactors`
- `parking`
- `listingAndConservation`
- `typeOfConstruction`
- `energyEfficiency`
- `councilTax`
- `disputesAndComplaints`
- `alterationsAndChanges`
- `notices`
- `specialistIssues`
- `fixturesAndFittings`
- `electricity`
- `waterAndDrainage`
- `heating`
- `connectivity`
- `insurance`
- `rightsAndInformalArrangements`
- `environmentalIssues`
- `otherIssues`
- `additionalInformation`
- `consumerProtectionRegulationsDeclaration`
- `legalBoundaries`
- `servicesCrossing`
- `electricalWorks`
- `smartHomeSystems`
- `guaranteesWarrantiesAndIndemnityInsurances`
- `occupiers`
- `localSearches`
- `searches`
- `documents`
- `surveys`
- `valuations`

**Explicitly moved elsewhere:**

| v3 area | New entity |
|---|---|
| `titlesToBeSold` | `Title` |
| `ownership.ownershipsToBeTransferred` | `Title` (tenure details, correlated by `titleNumber`) |
| the rest of `ownership`, and `legalOwners` | `Transaction.saleContext` |

### Title

**Identifier:**
- Registered: `urn:pdtf:titleNumber:{number}`
- Unregistered: `urn:pdtf:unregisteredTitle:{uuid}`

**Contains:**
- `titleExtents`
- `registerExtract`
- `additionalDocuments`
- `ownershipType`
- `leaseholdInformation`, `managedFreeholdOrCommonholdInformation`, `estateRentcharges`, `wholeFreeholdForSale` where relevant
- `titleRestrictions`, `keyFacts`, `covenantAnalysis`

**Important:** tenure details such as freehold or leasehold belong here, not on `SellerCapacity`.

### Person

**Identifier:** `did:key`

**Contains:**
- `name`
- `dateOfBirth`
- `phone`, `email`
- `address`
- `verification` (identity, anti-money-laundering, source of funds)
- `participantStatus`
- `externalIds`

**Does not contain:** transaction role. Roles are conveyed via `SellerCapacity`, `Offer`, `Gift`, `Representation` and `TransactionRole`. A Person's `did:key` is stable across transactions.

### Organisation

**Identifier:** `did:web`

**Contains:**
- `name`, `tradingName`
- `organisationType`
- `companiesHouseNumber`, `vatNumber`, `regulatoryIds`
- `registeredAddress`, `phone`, `email`, `website`
- `externalIds`

**Usage note:** organisations are first-class graph entities and the one entity outside the v3 round trip. A participant's firm is recorded by name and reference on the Transaction roster; resolving the participant's DID gives the Organisation.

### SellerCapacity

**Identifier:** `urn:pdtf:capacity:{uuid}`

**Shape:** thin relationship schema. Implies the Seller role; issued for every seller.

```json
{
  "id": "urn:pdtf:capacity:7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "seller": "did:key:z6Mkh...",
  "transaction": "did:web:platform.example.com:transactions:tx-789",
  "sellersCapacity": { "capacity": "Legal Owner" },
  "dateBecameOwnerOrAuthority": "2014-06-01"
}
```

`title` is optional: v3 does not tie a seller's capacity to a particular title, so a sale of several titles yields a capacity scoped to the transaction.

### Offer

**Identifier:** `urn:pdtf:offer:{uuid}`

Implies the Buyer role. Always identifies exactly one buyer.

```json
{
  "id": "urn:pdtf:offer:c3d4e5f6-a7b8-4c9d-8e1f-2a3b4c5d6e7f",
  "buyer": "did:key:z6Mkh...",
  "transaction": "did:web:platform.example.com:transactions:tx-789",
  "offerId": "o1",
  "amount": 450000,
  "currency": "GBP",
  "status": "Accepted",
  "conditions": ["Subject to survey"],
  "buyerCircumstances": {
    "isFirstTimeBuyer": true,
    "mortgageRequired": true
  }
}
```

### Gift

**Identifier:** `urn:pdtf:gift:{uuid}`

Implies the Giftor role. Carries the giftor's link to the offer, so that `Offer` always means buyer.

```json
{
  "id": "urn:pdtf:gift:b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
  "donor": "did:key:z6Mkp...",
  "transaction": "did:web:platform.example.com:transactions:tx-789",
  "offerId": "o1",
  "giftDetails": {
    "amount": 50000,
    "currency": "GBP",
    "relationshipToBuyer": "Parent",
    "fundsTransferred": "None",
    "repayable": false,
    "confersBeneficialInterest": false,
    "willOccupyProperty": false
  }
}
```

### Representation

**Identifier:** `urn:pdtf:representation:{uuid}`

One per (representative, represented party) pair. The represented party is a person or organisation, never an offer. The representative's firm is on the Transaction roster.

```json
{
  "id": "urn:pdtf:representation:a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d",
  "representative": "did:key:z6Mkj...",
  "representedParty": "did:key:z6Mkh...",
  "role": "Seller's Conveyancer",
  "transaction": "did:web:platform.example.com:transactions:tx-789"
}
```

**Role enum** (shared with `TransactionRole` and the v3 participant roles):
`Seller`, `Seller's Conveyancer`, `Prospective Buyer`, `Buyer`, `Buyer's Conveyancer`, `Giftor`, `Estate Agent`, `Buyer's Agent`, `Surveyor`, `Mortgage Broker`, `Lender`, `Landlord`, `Tenant`, `Platform Support`.

### TransactionRole

**Identifier:** `urn:pdtf:role:{uuid}`

A party's role where no more specific relationship credential applies. Asserts participation in a role, not a relationship to another named party.

```json
{
  "id": "urn:pdtf:role:d4e5f6a7-b8c9-4d0e-9f2a-3b4c5d6e7f8a",
  "participant": "did:web:bigbank.co.uk",
  "role": "Lender",
  "transaction": "did:web:platform.example.com:transactions:tx-789"
}
```

## ID-keyed collection rules

| Collection | v3 form | v4 form | Key source |
|---|---|---|---|
| Participants | array | `participants[]` roster + `persons{}` / `organisations{}` | DID |
| Titles to be sold | array | `titles{}` | title URN |
| Offers | object | `offers{}` | offer URN |
| Searches | array | ID-keyed map | provider reference or generated ID |
| Documents | array | ID-keyed map | generated ID |
| Surveys | array | ID-keyed map | generated ID |
| Valuations | array | ID-keyed map | `valuationId` |
| Contracts | array | ID-keyed map | generated ID |
| Chain onward purchase | array | ID-keyed map | `transactionId` |

## Schema extraction rules

Entity schemas are generated from the v3 combined schema by `npm run generate:v4` in the schemas repository, not hand-maintained separately. The same run emits a mapping manifest (v3 pointer → entity + pointer, and the inverse) and `decompose` / `recompose` helpers, and fails if any v3 field has no home in v4.

| Extracted schema | Source in v4 combined |
|---|---|
| `Transaction.json` | top-level fields excluding entity collections |
| `Property.json` | `properties[*]` |
| `Title.json` | `titles[*]` |
| `Person.json` | `persons[*]` |
| `Organisation.json` | `organisations[*]` |
| `SellerCapacity.json` | projected from `participants[*]` on the Seller branch |
| `Offer.json` | projected from `participants[*]` carrying an `offerId`, merged with `offers[offerId]` |
| `Gift.json` | projected from `participants[*]` on the Giftor branch |
| `Representation.json` | projected from `participants[*]` with `actingFor` |
| `TransactionRole.json` | projected from `participants[*]` with a role and no other role-bearing credential |

## Assembly constraints

- State assembly starts from `Transaction`.
- Property and title entities are merged by identifier.
- Relationship credentials populate graph links and carry role; they do not duplicate canonical source data.
- Sparse credential payloads are deep-merged during composition.
- Dependency pruning is applied after merge to remove schema-invalid subtrees when discriminators change.

## Developer notes

- Arrays that are true value lists remain arrays.
- Arrays that identify graph nodes or mutable collections become ID-keyed maps.
- `SellerCapacity` is intentionally thin. Title evidence remains on `Title.registerExtract`.
- `Representation`, `SellerCapacity`, `Offer`, `Gift` and `TransactionRole` are part of the round trip: dropping one and recomposing gives a v3 instance in which that party has no role and no relationship.
- `Property` is governed by the logbook test, `Transaction` by this sale only, `Title` by legal title intrinsic facts.
