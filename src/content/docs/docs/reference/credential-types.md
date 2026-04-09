---
title: "Credential Types"
description: "Complete list of PDTF credential types and their subjects"
---

## Overview

PDTF 2.0 uses W3C Verifiable Credentials v2.0 with Data Integrity proofs. Every credential MUST include:

- `@context`
- `type`
- `issuer`
- `validFrom`
- `credentialSubject`
- `credentialStatus`
- `proof`

PDTF credentials use a single `credentialSubject`, never an array.

## Credential type matrix

| Credential type | Subject entity | `credentialSubject.id` format | Typical issuer | Purpose |
|---|---|---|---|---|
| `PropertyCredential` | Property | `urn:pdtf:uprn:{uprn}` | trusted proxy, root issuer, platform | Property facts and logbook data |
| `TitleCredential` | Title | `urn:pdtf:titleNumber:{n}` or `urn:pdtf:unregisteredTitle:{id}` | HMLR proxy or root issuer | Register extract, title extents, legal title details |
| `OwnershipCredential` | Ownership | `urn:pdtf:ownership:{id}` | account provider / platform | Thin assertion that a person or organisation owns a title |
| `RepresentationCredential` | Representation | `urn:pdtf:representation:{id}` | platform on behalf of granting party | Delegated authority to an organisation |
| `DelegatedConsentCredential` | DelegatedConsent | `urn:pdtf:consent:{id}` | platform on behalf of granting party | Third-party access scope and purpose |
| `OfferCredential` | Offer | `urn:pdtf:offer:{id}` | platform on behalf of buyer | Buyer linkage, amount, conditions, status |
| `TransactionCredential` | Transaction | `did:web:{host}:transactions:{id}` | platform | Transaction lifecycle and sale context |

## Common envelope

```json
{
  "@context": [
    "https://www.w3.org/ns/credentials/v2",
    "https://trust.propdata.org.uk/ns/pdtf/v2"
  ],
  "type": ["VerifiableCredential", "PropertyCredential"],
  "issuer": "did:web:adapters.propdata.org.uk:epc",
  "validFrom": "2026-03-24T10:00:00Z",
  "credentialSubject": {
    "id": "urn:pdtf:uprn:100023456789"
  },
  "credentialStatus": {
    "id": "https://adapters.propdata.org.uk/status/epc/list-042#18293",
    "type": "BitstringStatusListEntry",
    "statusPurpose": "revocation",
    "statusListIndex": "18293",
    "statusListCredential": "https://adapters.propdata.org.uk/status/epc/list-042"
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "eddsa-jcs-2022",
    "verificationMethod": "did:web:adapters.propdata.org.uk:epc#key-1",
    "proofPurpose": "assertionMethod",
    "created": "2026-03-24T10:00:00Z",
    "proofValue": "z..."
  }
}
```

## PropertyCredential

**Subject:** `urn:pdtf:uprn:{uprn}`

**Use:** sparse subset of the `Property` schema. One credential may assert one or more property paths.

**Typical paths:**
- `energyEfficiency.*`
- `environmentalIssues.flooding.*`
- `buildInformation.*`
- `residentialPropertyFeatures.*`
- `heating.*`
- `fixturesAndFittings.*`
- `councilTax.*`
- `localSearches.*`
- `searches.*`
- `disputesAndComplaints.*`
- `alterationsAndChanges.*`
- `connectivity.*`
- `address.*`

**Important constraint:** an EPC is not a separate first-class credential type. It is a `PropertyCredential` carrying `energyEfficiency` paths.

**Example:**

```json
{
  "type": ["VerifiableCredential", "PropertyCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:uprn:100023456789",
    "energyEfficiency": {
      "certificate": {
        "certificateNumber": "1234-5678-9012-3456-7890",
        "currentEnergyRating": "C",
        "currentEnergyEfficiency": 72,
        "potentialEnergyRating": "B",
        "potentialEnergyEfficiency": 85
      }
    }
  }
}
```

## TitleCredential

**Subject:**
- `urn:pdtf:titleNumber:{number}`
- `urn:pdtf:unregisteredTitle:{id}`

**Use:** sparse subset of the `Title` schema.

**Typical paths:**
- `registerExtract.*`
- `titleExtents`
- `ownership.ownershipType`
- `ownership.leaseholdDetails.*`
- `additionalDocuments`
- `isFirstRegistration`

**Example:**

```json
{
  "type": ["VerifiableCredential", "TitleCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:titleNumber:AB12345",
    "registerExtract": {
      "proprietorship": {},
      "restrictions": [],
      "charges": []
    },
    "ownership": {
      "ownershipType": "Freehold"
    }
  }
}
```

## OwnershipCredential

**Subject:** `urn:pdtf:ownership:{id}`

**Design rule:** thin claim only. It links actor to title, it does not duplicate title register content.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `personId` or `organisationId` | yes, exactly one | DID of owner claimant |
| `titleId` | yes | Title URN |
| `status` | yes | `claimed`, `verified`, `disputed` |
| `verificationLevel` | yes | `selfDeclared`, `nameMatched`, `registerCrossReferenced`, `professionallyVerified` |
| `verifiedAt` | conditional | required when verified |

**Example:**

```json
{
  "type": ["VerifiableCredential", "OwnershipCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:ownership:own-a1b2c3",
    "personId": "did:key:z6MkhSellerAbc123",
    "titleId": "urn:pdtf:titleNumber:AB12345",
    "status": "verified",
    "verificationLevel": "registerCrossReferenced",
    "verifiedAt": "2026-03-18T09:00:00Z"
  }
}
```

## RepresentationCredential

**Subject:** `urn:pdtf:representation:{id}`

**Rule:** representation is granted to organisations, not individual fee earners.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `organisationId` | yes | DID of instructed firm or organisation |
| `role` | yes | `sellerConveyancer`, `buyerConveyancer`, `estateAgent`, `buyerAgent`, `surveyor`, `mortgageBroker` |
| `grantedBy` | yes | DID of person granting authority |
| `transactionId` | yes | transaction DID |
| `status` | yes | `active`, `revoked` |

**Example:**

```json
{
  "type": ["VerifiableCredential", "RepresentationCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:representation:rep-d4e5f6",
    "organisationId": "did:web:smithandco.law",
    "role": "sellerConveyancer",
    "grantedBy": "did:key:z6MkhSellerAbc123",
    "transactionId": "did:web:moverly.com:transactions:tx-789",
    "status": "active"
  }
}
```

## DelegatedConsentCredential

**Subject:** `urn:pdtf:consent:{id}`

**Purpose:** grants scoped third-party access.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `organisationId` | yes | recipient organisation DID |
| `grantedBy` | yes | granting person DID |
| `transactionId` | yes | transaction DID |
| `scope` | yes | array of `Entity:path` patterns |
| `purpose` | yes | human-readable purpose |
| `status` | yes | `active`, `revoked` |
| `validUntil` | no | optional expiry |

**Scope examples:**
- `Property:energyEfficiency`
- `Property:*`
- `Title:registerExtract`
- `Title:ownership`

**Example:**

```json
{
  "type": ["VerifiableCredential", "DelegatedConsentCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:consent:dc-g7h8i9",
    "organisationId": "did:web:bigbank.co.uk",
    "grantedBy": "did:key:z6MkhBuyerXyz789",
    "transactionId": "did:web:moverly.com:transactions:tx-789",
    "scope": [
      "Property:energyEfficiency",
      "Property:environmentalIssues",
      "Title:registerExtract",
      "Title:ownership"
    ],
    "purpose": "Mortgage valuation and underwriting",
    "status": "active"
  }
}
```

## OfferCredential

**Subject:** `urn:pdtf:offer:{id}`

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `transactionId` | yes | transaction DID |
| `buyerIds` | yes | array of buyer person DIDs |
| `amount` | yes | numeric offer amount |
| `currency` | yes | ISO 4217 currency code |
| `status` | yes | `Pending`, `Accepted`, `Withdrawn`, `Rejected`, `NoteOfInterest` |
| `conditions` | no | free text list |
| `inclusions` | no | free text list |
| `exclusions` | no | free text list |
| `buyerCircumstances` | no | first-time buyer, chain, mortgage, etc. |

**Example:**

```json
{
  "type": ["VerifiableCredential", "OfferCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:offer:off-j1k2l3",
    "transactionId": "did:web:moverly.com:transactions:tx-789",
    "buyerIds": ["did:key:z6MkhBuyerXyz789"],
    "amount": 450000,
    "currency": "GBP",
    "status": "Accepted",
    "conditions": ["Subject to survey"],
    "buyerCircumstances": {
      "isFirstTimeBuyer": true,
      "mortgageRequired": true,
      "mortgageAgreedInPrinciple": true
    }
  }
}
```

## TransactionCredential

**Subject:** `did:web:{host}:transactions:{id}`

**Fields:**
- `status`
- `milestones`
- `saleContext`
- `propertyIds`
- `titleIds`
- transaction metadata relevant to graph composition

**Example:**

```json
{
  "type": ["VerifiableCredential", "TransactionCredential"],
  "credentialSubject": {
    "id": "did:web:moverly.com:transactions:tx-789",
    "status": "Active",
    "milestones": {
      "listed": "2026-03-01T00:00:00Z",
      "saleAgreed": "2026-03-20T00:00:00Z"
    },
    "saleContext": {
      "numberOfSellers": 1,
      "outstandingMortgage": "Yes",
      "existingLender": "Nationwide"
    },
    "propertyIds": ["urn:pdtf:uprn:100023456789"],
    "titleIds": ["urn:pdtf:titleNumber:AB12345"]
  }
}
```

## Evidence types used by PDTF credentials

| Evidence type | Meaning |
|---|---|
| `ElectronicRecord` | data fetched from authoritative API or electronic source |
| `DocumentExtraction` | data extracted from source document |
| `UserAttestation` | data attested by user |
| `ProfessionalVerification` | data verified by professional |

## Terms of use

PDTF uses `PdtfAccessPolicy` in `termsOfUse`.

| Field | Meaning |
|---|---|
| `confidentiality` | `public`, `restricted`, `confidential` |
| `pii` | whether credential contains personal data |
| `roleRestrictions` | allowed requester roles |

## Revocation

Every credential MUST include `credentialStatus` referencing a Bitstring Status List entry.

| Field | Meaning |
|---|---|
| `type` | `BitstringStatusListEntry` |
| `statusPurpose` | usually `revocation`, optionally also `suspension` |
| `statusListIndex` | bit position in status list |
| `statusListCredential` | URL of status list VC |

## Proof format

All PDTF credentials use:

- `type`: `DataIntegrityProof`
- `cryptosuite`: `eddsa-jcs-2022`
- `proofPurpose`: `assertionMethod`

## Mapping from credential type to entity graph

| Credential type | Graph role |
|---|---|
| `PropertyCredential` | contributes sparse property state |
| `TitleCredential` | contributes sparse title state |
| `OwnershipCredential` | links person/org to title |
| `RepresentationCredential` | links person grantor to organisation role |
| `DelegatedConsentCredential` | links person grantor to authorised access scope |
| `OfferCredential` | links buyer person(s) to transaction |
| `TransactionCredential` | root state and graph context |

## Validation constraints

A validator should check:

1. `type` includes `VerifiableCredential` and exactly one PDTF credential type.
2. `credentialSubject.id` format matches the declared credential type.
3. Proof verifies against issuer DID document.
4. Credential is not revoked or suspended.
5. Issuer is authorised for the asserted entity:path combinations via the TIR.
6. Sparse payload paths are valid against the corresponding entity schema.
