---
title: "DID Methods"
description: "Reference for did:key and did:web usage in PDTF"
---

## DID method selection

PDTF 2.0 uses three identifier families:

| Family | Used for | Why |
|---|---|---|
| `did:key` | persons, provider-managed organisations | self-certifying, no hosting, derived directly from Ed25519 public key |
| `did:web` | self-hosted organisations, transactions, trusted adapters | discoverable DID documents, service endpoints, key rotation |
| `urn:pdtf:*` | non-actor graph subjects | properties, titles, relationship entities, credentials, status resources |

## When to use which

| Entity type | Identifier |
|---|---|
| Person | `did:key` |
| Organisation, provider-managed | `did:key` |
| Organisation, self-hosted | `did:web:{domain}` |
| Transaction | `did:web:{platform}:transactions:{id}` |
| Trusted adapter | `did:web:{host}:{adapter}` |

## `did:key`

### Characteristics

- no network resolution
- Ed25519 only in PDTF 2.0
- immutable, key rotation means new DID
- suited to persons and provider-managed organisations

### Derivation

PDTF uses Ed25519 public keys with multicodec prefix `0xed01`, encoded as multibase base58-btc.

```text
1. Generate Ed25519 key pair
2. Prepend multicodec prefix 0xed01
3. Base58-btc encode with multibase prefix z
4. Prepend did:key:
```

**Example:**

```text
did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK
```

All PDTF Ed25519 `did:key` identifiers begin with `did:key:z6Mk`.

### Resolved document shape

```json
{
  "id": "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
  "verificationMethod": [
    {
      "id": "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK#z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
      "publicKeyMultibase": "z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
    }
  ],
  "authentication": ["did:key:...#z6Mk..."],
  "assertionMethod": ["did:key:...#z6Mk..."],
  "capabilityDelegation": ["did:key:...#z6Mk..."],
  "capabilityInvocation": ["did:key:...#z6Mk..."]
}
```

### Constraints

| Constraint | Value |
|---|---|
| key algorithm | Ed25519 |
| verification method type | `Ed25519VerificationKey2020` |
| public key encoding | `publicKeyMultibase` |
| rotation model | new DID required |
| hosting | none |

## `did:web`

### Characteristics

- resolved over HTTPS
- supports hosted DID documents
- supports service discovery
- supports in-place key rotation
- used where endpoints must be discoverable

### Resolution rules

| DID | Resolves to |
|---|---|
| `did:web:smithandjones.co.uk` | `https://smithandjones.co.uk/.well-known/did.json` |
| `did:web:moverly.com:transactions:abc123` | `https://moverly.com/transactions/abc123/did.json` |
| `did:web:adapters.propdata.org.uk:hmlr` | `https://adapters.propdata.org.uk/hmlr/did.json` |

**General mapping:**

```text
did:web:{domain} -> https://{domain}/.well-known/did.json
did:web:{domain}:{path1}:{path2} -> https://{domain}/{path1}/{path2}/did.json
```

Ports are percent-encoded in the DID.

### Organisation patterns

| Pattern | Usage |
|---|---|
| `did:web:{firm-domain}` | self-hosted organisation identity |
| `did:key:{...}` | provider-managed organisation identity |

### Transaction pattern

```text
did:web:{platform}:transactions:{id}
```

Example:

```text
did:web:moverly.com:transactions:abc123
```

### Adapter pattern

```text
did:web:{host}:{adapter-name}
```

Example:

```text
did:web:adapters.propdata.org.uk:hmlr
```

## DID document requirements

### Common verification method requirements

| Field | Requirement |
|---|---|
| `type` | `Ed25519VerificationKey2020` |
| `publicKeyMultibase` | required |
| `assertionMethod` | required for any issuer |
| `authentication` | required where DID auth is used |

### Transaction DID document

A transaction DID document MUST advertise service endpoints.

```json
{
  "id": "did:web:moverly.com:transactions:abc123",
  "controller": "did:web:moverly.com",
  "verificationMethod": [
    {
      "id": "did:web:moverly.com:transactions:abc123#key-1",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:web:moverly.com:transactions:abc123",
      "publicKeyMultibase": "z6MknGc3ocHs3zdPiJbnaaqDi58NGb4pk1Sp7eTbCt2DADLY"
    }
  ],
  "authentication": ["did:web:moverly.com:transactions:abc123#key-1"],
  "assertionMethod": ["did:web:moverly.com:transactions:abc123#key-1"],
  "service": [
    {
      "id": "did:web:moverly.com:transactions:abc123#pdtf-api",
      "type": "PdtfTransactionEndpoint",
      "serviceEndpoint": "https://api.moverly.com/v2/transactions/abc123"
    },
    {
      "id": "did:web:moverly.com:transactions:abc123#mcp",
      "type": "McpEndpoint",
      "serviceEndpoint": "https://api.moverly.com/mcp/transactions/abc123"
    }
  ]
}
```

### Adapter DID document

An adapter DID document SHOULD advertise issuance and status endpoints.

```json
{
  "id": "did:web:adapters.propdata.org.uk:hmlr",
  "controller": "did:web:adapters.propdata.org.uk",
  "verificationMethod": [
    {
      "id": "did:web:adapters.propdata.org.uk:hmlr#key-1",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:web:adapters.propdata.org.uk:hmlr",
      "publicKeyMultibase": "z6MkpTHR8VNs5xhqAKbSQgpzGRwXaN7cPsMjczbEPceFRFw8"
    }
  ],
  "assertionMethod": ["did:web:adapters.propdata.org.uk:hmlr#key-1"],
  "service": [
    {
      "id": "did:web:adapters.propdata.org.uk:hmlr#vc-issuance",
      "type": "VcIssuanceEndpoint",
      "serviceEndpoint": "https://adapters.propdata.org.uk/hmlr/credentials/issue",
      "credentialTypes": ["TitleCredential", "OwnershipCredential"]
    },
    {
      "id": "did:web:adapters.propdata.org.uk:hmlr#status",
      "type": "BitstringStatusListEndpoint",
      "serviceEndpoint": "https://adapters.propdata.org.uk/hmlr/status"
    }
  ]
}
```

### Self-hosted organisation DID document

A self-hosted organisation MAY expose regulatory and PDTF endpoints.

Typical service types:
- `RegulatoryRegistration`
- `CompanyRegistration`
- `PdtfOrganisationEndpoint`

## Verification relationships

| Relationship | PDTF use |
|---|---|
| `authentication` | DID auth challenge-response |
| `assertionMethod` | VC issuance |
| `capabilityDelegation` | present on `did:key` resolved docs |
| `capabilityInvocation` | present on `did:key` resolved docs |

## Key rotation

### `did:key`

`did:key` cannot rotate in place.

| Action | Result |
|---|---|
| rotate key | mint new DID |
| preserve linkage | optional DID succession credential |
| update references | reissue credentials pointing at new DID |

### `did:web`

`did:web` rotates in place by updating the DID document.

Recommended process:
1. add new key alongside old key
2. include both in `assertionMethod`
3. sign new credentials with new key
4. keep old key published during overlap period
5. remove old key only after old credentials are no longer needed

## Caching guidance

| DID type | Suggested TTL |
|---|---|
| `did:key` | no cache required, deterministic |
| organisation `did:web` | 24h |
| transaction `did:web` | 1h |
| adapter `did:web` | 24h |

On verification failure, resolvers should bypass cache and re-fetch once.

## Security constraints

- `did:web` MUST resolve over HTTPS only.
- DID document `id` MUST exactly match the queried DID.
- Verifiers SHOULD cross-check issuer DIDs against the Trusted Issuer Registry.
- DNS and TLS integrity matter for `did:web`; DNSSEC is recommended, especially for adapter infrastructure.

## Quick reference

| Question | Answer |
|---|---|
| Can a person use `did:web`? | Not in PDTF 2.0, persons use `did:key`. |
| Can an organisation use `did:key`? | Yes, provider-managed is the default/common case. |
| Can an organisation use `did:web`? | Yes, when self-hosting and direct control are desired. |
| Why do transactions use `did:web`? | They need discoverable API and MCP endpoints. |
| Why do properties use URNs, not DIDs? | They are credential subjects, not actors. |
