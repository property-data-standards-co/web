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
| `Title` | `urn:pdtf:titleNumber:{number}` or `urn:pdtf:unregisteredTitle:{id}` | Legal title entity | Register extract, title extents, ownership type, leasehold terms, encumbrances |
| `Person` | `did:key:{...}` | Identity entity | Natural person, role-free, referenced by relationship entities |
| `Organisation` | `did:key:{...}` or `did:web:{domain}` | Identity entity | Law firm, estate agent, lender, surveyor, etc. |
| `Ownership` | `urn:pdtf:ownership:{id}` | Relationship entity | Thin signed assertion linking a person or organisation to a title |
| `Representation` | `urn:pdtf:representation:{id}` | Relationship entity | Delegated authority from a person to an organisation |
| `DelegatedConsent` | `urn:pdtf:consent:{id}` | Relationship entity | Authorised access scope for a third party |
| `Offer` | `urn:pdtf:offer:{id}` | Relationship entity | Buyer linkage to transaction, amount, status, conditions |

## Top-level v4 combined structure

The v4 combined schema uses ID-keyed collections rather than arrays.

```json
{
  "$schema": "https://trust.propdata.org.uk/schemas/v4/combined.json",
  "transactionId": "did:web:platform.example.com:transactions:abc123",
  "status": "Active",
  "saleContext": {},
  "sellerConfirmations": {},
  "completion": {},
  "milestones": {},
  "contracts": {},
  "chain": {},
  "valuationComparisonData": {},
  "persons": {
    "did:key:z6Mkh...": {}
  },
  "organisations": {
    "did:web:smithandco.law": {}
  },
  "properties": {
    "urn:pdtf:uprn:100023456789": {}
  },
  "titles": {
    "urn:pdtf:titleNumber:AB12345": {}
  },
  "ownership": {
    "urn:pdtf:ownership:own-1": {}
  },
  "representation": {
    "urn:pdtf:representation:rep-1": {}
  },
  "delegatedConsent": {
    "urn:pdtf:consent:dc-1": {}
  },
  "offers": {
    "urn:pdtf:offer:off-1": {}
  },
  "enquiries": {}
}
```

## Entity schema references

### Transaction

**Identifier:** `did:web`

**Contains:**
- `status`
- `externalIds`
- `saleContext`
- `sellerConfirmations`
- `completion`
- `milestones`
- `contracts`
- `chain`
- `valuationComparisonData`
- references to related property/title/person/organisation/relationship entities

**Does not contain:** embedded property logbook data, title register data, or person role semantics.

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
| `ownership.ownershipsToBeTransferred` | `Title.ownership` |
| seller count, mortgage, Help to Buy, limited company sale | `Transaction.saleContext` |
| legal owners | `Person` / `Organisation` + `Ownership` |
| seller confirmations | `Transaction.sellerConfirmations` |
| completion and moving | `Transaction.completion` |

### Title

**Identifier:**
- Registered: `urn:pdtf:titleNumber:{number}`
- Unregistered: `urn:pdtf:unregisteredTitle:{id}`

**Contains:**
- `titleExtents`
- `registerExtract`
- `additionalDocuments`
- `ownership.ownershipType`
- `ownership.leaseholdDetails` where relevant
- `isFirstRegistration`

**Important:** title ownership details such as freehold or leasehold belong here, not on `Ownership`.

### Person

**Identifier:** `did:key`

**Contains:**
- `name`
- `dateOfBirth`
- `contact`
- `address`
- `verification`
- `externalIds`

**Does not contain:** transaction role. Roles are conveyed via `Ownership`, `Representation`, and `Offer`.

### Organisation

**Identifier:** `did:key` or `did:web`

**Contains:**
- `name`
- `type`
- `regulatoryBody`
- `contact`
- `externalIds`

**Usage note:** organisations are first-class graph entities. Internal fee-earner assignment is out of scope.

### Ownership

**Identifier:** `urn:pdtf:ownership:{id}`

**Shape:** thin relationship schema.

```json
{
  "id": "urn:pdtf:ownership:own-a1b2c3",
  "personId": "did:key:z6Mkh...",
  "titleId": "urn:pdtf:titleNumber:AB12345",
  "status": "verified",
  "verificationLevel": "registerCrossReferenced",
  "verifiedAt": "2026-03-18T09:00:00Z"
}
```

**Allowed subject linkage:** exactly one of `personId` or `organisationId`, plus `titleId`.

### Representation

**Identifier:** `urn:pdtf:representation:{id}`

```json
{
  "id": "urn:pdtf:representation:rep-d4e5f6",
  "organisationId": "did:web:smithandco.law",
  "role": "sellerConveyancer",
  "grantedBy": "did:key:z6Mkh...",
  "transactionId": "did:web:platform.example.com:transactions:tx-789",
  "status": "active"
}
```

**Role enum:**
- `sellerConveyancer`
- `buyerConveyancer`
- `estateAgent`
- `buyerAgent`
- `surveyor`
- `mortgageBroker`

### DelegatedConsent

**Identifier:** `urn:pdtf:consent:{id}`

```json
{
  "id": "urn:pdtf:consent:dc-g7h8i9",
  "organisationId": "did:web:bigbank.co.uk",
  "grantedBy": "did:key:z6Mkh...",
  "transactionId": "did:web:platform.example.com:transactions:tx-789",
  "scope": ["Property:energyEfficiency", "Title:registerExtract"],
  "purpose": "Mortgage valuation and underwriting",
  "status": "active",
  "validUntil": "2026-09-22T16:00:00Z"
}
```

### Offer

**Identifier:** `urn:pdtf:offer:{id}`

```json
{
  "id": "urn:pdtf:offer:off-j1k2l3",
  "transactionId": "did:web:platform.example.com:transactions:tx-789",
  "buyerIds": ["did:key:z6Mkh..."],
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

## ID-keyed collection rules

| Collection | v3 form | v4 form | Key source |
|---|---|---|---|
| Participants | array | `persons{}` / `organisations{}` | DID |
| Titles to be sold | array | `titles{}` | title URN |
| Offers | object | `offers{}` | offer URN |
| Searches | array | ID-keyed map | provider reference or generated ID |
| Documents | array | ID-keyed map | generated ID |
| Surveys | array | ID-keyed map | generated ID |
| Valuations | array | ID-keyed map | `valuationId` |
| Contracts | array | ID-keyed map | generated ID |
| Chain onward purchase | array | ID-keyed map | `transactionId` |

## Schema extraction rules

Entity schemas are generated from the combined v4 schema, not hand-maintained separately.

| Extracted schema | Source in v4 combined |
|---|---|
| `Transaction.json` | top-level fields excluding entity collections |
| `Property.json` | `properties[*]` |
| `Title.json` | `titles[*]` |
| `Person.json` | `persons[*]` |
| `Organisation.json` | `organisations[*]` |
| `Ownership.json` | `ownership[*]` |
| `Representation.json` | `representation[*]` |
| `DelegatedConsent.json` | `delegatedConsent[*]` |
| `Offer.json` | `offers[*]` |

## Assembly constraints

- State assembly starts from `Transaction`.
- Property and title entities are merged by identifier.
- Relationship entities populate graph links, they do not duplicate canonical source data.
- Sparse credential payloads are deep-merged during composition.
- Dependency pruning is applied after merge to remove schema-invalid subtrees when discriminators change.

## Developer notes

- Arrays that are true value lists remain arrays.
- Arrays that identify graph nodes or mutable collections become ID-keyed maps.
- `Ownership` is intentionally thin. Title evidence remains on `Title.registerExtract`.
- `Property` is governed by the logbook test, `Transaction` by this sale only, `Title` by legal title intrinsic facts.
