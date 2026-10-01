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
| `SellerCapacityCredential` | SellerCapacity | `urn:pdtf:capacity:{id}` | account provider / platform | The capacity in which a party sells; implies Seller |
| `OfferCredential` | Offer | `urn:pdtf:offer:{id}` | platform on behalf of buyer | Buyer linkage, amount, conditions, status; implies Buyer |
| `GiftCredential` | Gift | `urn:pdtf:gift:{id}` | platform on behalf of giftor | Gift of funds towards an offer; implies Giftor |
| `RepresentationCredential` | Representation | `urn:pdtf:representation:{id}` | platform on behalf of instructing party | One party instructed by another, with the kind of representation |
| `TransactionRoleCredential` | TransactionRole | `urn:pdtf:role:{id}` | platform | A role with no more specific relationship (lender, landlord, tenant, surveyor) |
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

## SellerCapacityCredential

**Subject:** `urn:pdtf:capacity:{id}`

**Design rule:** thin claim only. It records the capacity in which a party sells; it does not duplicate title register content. Issued for every seller, whether or not a capacity has been declared yet, so the credential embodying the Seller role is never missing.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `seller` | yes | DID of the Person or Organisation selling |
| `transaction` | yes | transaction DID |
| `title` | no | Title URN, where a capacity is specific to one of several titles |
| `sellersCapacity.capacity` | no | `Legal Owner`, `Personal Representative for a Deceased Owner`, `Under Power of Attorney`, `Mortgagee in Possession`, `Company Director`, `Company Secretary`, `Trustee`, `Assistant`, `Other` |
| `dateBecameOwnerOrAuthority` | no | date the seller acquired the title or the authority to sell it |

**Example:**

```json
{
  "type": ["VerifiableCredential", "SellerCapacityCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:capacity:own-a1b2c3",
    "seller": "did:key:z6MkhSellerAbc123",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "sellersCapacity": { "capacity": "Legal Owner" },
    "dateBecameOwnerOrAuthority": "2014-06-01"
  }
}
```

## OfferCredential

**Subject:** `urn:pdtf:offer:{id}`

**Rule:** an Offer always identifies a buyer. A giftor contributing towards an offer is linked to it through `GiftCredential`, not here.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `buyer` | yes | DID of the Person or Organisation making the offer |
| `transaction` | yes | transaction DID |
| `offerId` | no | the key of this offer in `Transaction.offers` |
| `amount` | no | numeric offer amount |
| `currency` | no | ISO 4217 currency code |
| `status` | no | `Pending`, `Accepted`, `Withdrawn`, `Rejected`, `Note of Interest` |
| `conditions`, `inclusions`, `exclusions` | no | free text lists |
| `buyerCircumstances` | no | first-time buyer, chain, mortgage, etc. |

**Example:**

```json
{
  "type": ["VerifiableCredential", "OfferCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:offer:off-j1k2l3",
    "buyer": "did:key:z6MkhBuyerXyz789",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "offerId": "o1",
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

## GiftCredential

**Subject:** `urn:pdtf:gift:{id}`

**Purpose:** records that a party is gifting funds towards a purchase, and the terms a conveyancer must resolve before reporting to a lender.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `donor` | yes | DID of the Person or Organisation making the gift |
| `transaction` | yes | transaction DID |
| `offerId` | no | the offer this gift contributes towards |
| `giftDetails` | no | `amount`, `currency`, `relationshipToBuyer`, `fundsTransferred` (`None`, `Part`, `All`), `repayable`, `confersBeneficialInterest`, `willOccupyProperty` |

**Example:**

```json
{
  "type": ["VerifiableCredential", "GiftCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:gift:gf-m4n5o6",
    "donor": "did:key:z6MkhParentPqr456",
    "transaction": "did:web:platform.example.com:transactions:tx-789",
    "offerId": "o1",
    "giftDetails": {
      "amount": 50000,
      "currency": "GBP",
      "relationshipToBuyer": "Parent",
      "repayable": false,
      "confersBeneficialInterest": false,
      "willOccupyProperty": false
    }
  }
}
```

## RepresentationCredential

**Subject:** `urn:pdtf:representation:{id}`

**Rule:** one credential per (representative, represented party) pair. A conveyancer instructed jointly by two sellers holds two; a couple instructing separate conveyancers yields one each. The retainer is with the client, so the represented party is a person or organisation, never an offer. The representative's firm is recorded on the Transaction roster, not here.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `representative` | yes | DID of the Person or Organisation who is instructed |
| `representedParty` | yes | DID of the Person or Organisation who instructed them |
| `role` | yes | the kind of representation: `Seller's Conveyancer`, `Buyer's Conveyancer`, `Estate Agent`, `Buyer's Agent`, `Mortgage Broker`, `Surveyor`, … |
| `transaction` | yes | transaction DID |

**Example:**

```json
{
  "type": ["VerifiableCredential", "RepresentationCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:representation:rep-d4e5f6",
    "representative": "did:key:z6MkhConveyancerDef456",
    "representedParty": "did:key:z6MkhSellerAbc123",
    "role": "Seller's Conveyancer",
    "transaction": "did:web:platform.example.com:transactions:tx-789"
  }
}
```

## TransactionRoleCredential

**Subject:** `urn:pdtf:role:{id}`

**Purpose:** asserts a party's role where no more specific relationship credential applies — lender, landlord, tenant, surveyor, platform support — or where the specific relationship is not yet established. Every party carrying a role holds exactly one role-bearing credential.

**Fields:**

| Field | Required | Notes |
|---|---|---|
| `participant` | yes | DID of the Person or Organisation holding the role |
| `role` | yes | one of the transaction roles, e.g. `Lender`, `Landlord`, `Tenant`, `Surveyor`, `Platform Support` |
| `transaction` | yes | transaction DID |

**Example:**

```json
{
  "type": ["VerifiableCredential", "TransactionRoleCredential"],
  "credentialSubject": {
    "id": "urn:pdtf:role:tr-g7h8i9",
    "participant": "did:web:bigbank.co.uk",
    "role": "Lender",
    "transaction": "did:web:platform.example.com:transactions:tx-789"
  }
}
```

## TransactionCredential

**Subject:** `did:web:{host}:transactions:{id}`

**Fields:**
- `status`
- `milestones`
- `saleContext`
- `property`
- `titlesToBeSold`
- `participants` (roster)
- transaction metadata relevant to graph composition

**Example:**

```json
{
  "type": ["VerifiableCredential", "TransactionCredential"],
  "credentialSubject": {
    "id": "did:web:platform.example.com:transactions:tx-789",
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
    "property": "urn:pdtf:uprn:100023456789",
    "titlesToBeSold": ["urn:pdtf:titleNumber:AB12345"],
    "participants": [
      { "participant": "did:key:z6MkhSellerAbc123", "participantId": "s1" },
      { "participant": "did:key:z6MkhConveyancerDef456", "participantId": "c1", "organisation": "Smith & Co Law", "organisationReference": "SC/2026/118" }
    ]
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
| `SellerCapacityCredential` | links a seller to the transaction; embodies the Seller role |
| `OfferCredential` | links a buyer to the transaction; embodies the Buyer role |
| `GiftCredential` | links a giftor to an offer; embodies the Giftor role |
| `RepresentationCredential` | links a representative to the party who instructed them |
| `TransactionRoleCredential` | links a party to the transaction in a named role |
| `TransactionCredential` | root state and graph context |

## Validation constraints

A validator should check:

1. `type` includes `VerifiableCredential` and exactly one PDTF credential type.
2. `credentialSubject.id` format matches the declared credential type.
3. Proof verifies against issuer DID document.
4. Credential is not revoked or suspended.
5. Issuer is authorised for the asserted entity:path combinations via the TIR.
6. Sparse payload paths are valid against the corresponding entity schema.
