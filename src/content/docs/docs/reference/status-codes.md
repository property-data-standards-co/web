---
title: "Status Codes"
description: "API status codes and error responses"
---

## Overview

PDTF 2.0 uses W3C Bitstring Status List v1.0 for credential revocation and suspension. Every credential issued within the ecosystem MUST include a `credentialStatus` field. Credentials without one MUST be rejected.

This reference covers:

- Bitstring Status List structure and index allocation
- Status purposes (`revocation` and `suspension`)
- The verification algorithm
- URL patterns for status list endpoints
- Status state matrix
- Caching requirements

## Credential status field

Every PDTF credential MUST include:

```json
{
  "credentialStatus": {
    "id": "https://adapters.propdata.org.uk/status/epc/list-042#18293",
    "type": "BitstringStatusListEntry",
    "statusPurpose": "revocation",
    "statusListIndex": "18293",
    "statusListCredential": "https://adapters.propdata.org.uk/status/epc/list-042"
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | URI | required | unique identifier for this status entry; `{statusListCredential}#{statusListIndex}` |
| `type` | string | required | MUST be `BitstringStatusListEntry` |
| `statusPurpose` | enum | required | `revocation` or `suspension` |
| `statusListIndex` | string | required | non-negative integer as string, bit position in the list |
| `statusListCredential` | URI | required | HTTPS URL of the status list VC |

A credential MAY include two `credentialStatus` entries — one for revocation, one for suspension — each referencing separate status lists.

## Status list credential

The status list is itself a Verifiable Credential.

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2"],
  "id": "https://adapters.propdata.org.uk/status/epc/list-042",
  "type": ["VerifiableCredential", "BitstringStatusListCredential"],
  "issuer": "did:web:adapters.propdata.org.uk:epc",
  "validFrom": "2026-01-01T00:00:00Z",
  "credentialSubject": {
    "id": "https://adapters.propdata.org.uk/status/epc/list-042#list",
    "type": "BitstringStatusList",
    "statusPurpose": "revocation",
    "encodedList": "H4sIAAAAAAAAA..."
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "eddsa-jcs-2022",
    "verificationMethod": "did:web:adapters.propdata.org.uk:epc#key-1",
    "proofPurpose": "assertionMethod",
    "created": "2026-03-24T12:00:00Z",
    "proofValue": "z..."
  }
}
```

| Field | Requirement |
|---|---|
| `id` | MUST match the URL at which the status list is hosted |
| `type` | MUST include `BitstringStatusListCredential` |
| `issuer` | MUST match the `issuer` of the credentials this list covers |
| `credentialSubject.type` | MUST be `BitstringStatusList` |
| `credentialSubject.statusPurpose` | MUST match `statusPurpose` in referencing credentials |
| `credentialSubject.encodedList` | gzip-compressed, base64-encoded bitstring |
| minimum list size | 131,072 bits (16 KB uncompressed) |

## Encoding

```text
1. Start with a bitstring of at least 131,072 bits, all zeros
2. Set bit at each revoked credential's statusListIndex to 1
3. Compress using gzip
4. Base64-encode the compressed bytes (no padding)
→ encodedList value
```

**Decoding:**

```text
1. Base64-decode encodedList
2. Gzip-decompress
3. Read bit at statusListIndex
```

## Index allocation

| Rule | Detail |
|---|---|
| Sequential allocation | indices are assigned in order from 0 up |
| Unique per list | each credential gets exactly one index |
| Never reused | once assigned, an index is never reassigned, even after revocation |
| Capacity | standard list holds 131,072 indices |
| Overflow | when full, create a new list and reset counter to 0 |

## Status purposes

| `statusPurpose` | Meaning | Reversible |
|---|---|---|
| `revocation` | permanent invalidation | no — bit is never unset |
| `suspension` | temporary hold | yes — bit may be unset to reinstate |

## State matrix

| Revocation bit | Suspension bit | State | Verifier action |
|---|---|---|---|
| 0 | 0 | **Active** | accept |
| 0 | 1 | **Suspended** | reject, temporary |
| 1 | 0 | **Revoked** | reject, permanent |
| 1 | 1 | **Revoked** | reject, permanent — revocation takes precedence |

## Verification algorithm

```text
For each credentialStatus entry in the credential:

  1. Resolve issuer DID → get signing key
  2. Fetch statusListCredential from the URL
     - use cached copy if within TTL
  3. Verify status list credential proof
     - status list issuer MUST match the credential issuer
  4. Base64-decode and gzip-decompress encodedList
  5. Read bit at statusListIndex
     - byteIndex = floor(index / 8)
     - bitIndex  = index % 8
     - bit = (bitstring[byteIndex] >> (7 - bitIndex)) & 1
  6. If bit == 1:
     - statusPurpose == "revocation" → credential is REVOKED
     - statusPurpose == "suspension" → credential is SUSPENDED

If any entry is revoked → reject
If any entry is suspended → reject (or warn, per policy)
If all entries are 0 → credential status is active
```

## Issuer matching

The status list credential's `issuer` MUST match the original credential's `issuer`. A mismatch is a hard failure.

```text
Credential issuer:    did:web:adapters.propdata.org.uk:epc
Status list issuer:   did:web:adapters.propdata.org.uk:epc   ✅ OK

Credential issuer:    did:web:adapters.propdata.org.uk:epc
Status list issuer:   did:web:evil.example.com              ❌ REJECT
```

## Hosting URL patterns

### Adapter-issued credentials

```
https://adapters.propdata.org.uk/status/{adapter}/{listId}
```

Examples:
```
https://adapters.propdata.org.uk/status/epc/list-001
https://adapters.propdata.org.uk/status/hmlr/list-001
https://adapters.propdata.org.uk/status/ea-flood/list-001
```

### Platform-issued credentials

```
https://moverly.com/status/{category}/{listId}
```

Examples:
```
https://moverly.com/status/ownership/list-001
https://moverly.com/status/representation/list-001
https://moverly.com/status/consent/list-001
```

## HTTP requirements for status endpoints

```http
HTTP/1.1 200 OK
Content-Type: application/vc+ld+json
Cache-Control: public, max-age=300
ETag: "a1b2c3d4"
Access-Control-Allow-Origin: *
```

- MUST respond over HTTPS
- MUST include CORS headers
- SHOULD include `Cache-Control: public, max-age=300`
- SHOULD include `ETag` for conditional request support

## Revocation triggers by credential type

| Credential type | Revocation trigger |
|---|---|
| `OwnershipCredential` | title transfers on sale completion |
| `RepresentationCredential` | mandate withdrawn, conveyancer replaced, transaction completed or cancelled |
| `PropertyCredential` | underlying data superseded by new issue (e.g. new EPC) |
| `DelegatedConsentCredential` | consent withdrawn, access period expired, transaction completed |
| `OfferCredential` | offer withdrawn or rejected |
| user identity credential | account disabled, suspended, or deleted |

## Suspension guidance

Suspension is appropriate for:

- pending fraud investigation
- temporary access hold during case review
- disputed ownership not yet resolved
- account under review but not confirmed disabled

Suspension is **not** appropriate for permanent invalidation — use revocation.

## Caching guidance

| Scenario | Recommended TTL |
|---|---|
| Normal status list fetch | `Cache-Control` from server (typically 5 min) |
| High-sensitivity credentials (ownership, representation) | shorter TTL recommended, e.g. 60s |
| On verification failure | bypass cache, re-fetch once |
| Origin unreachable | serve stale for up to 60s, then fail |

Verifiers SHOULD store the ETag alongside each cached status list and use `If-None-Match` on subsequent requests.

## Batch revocation

When multiple credentials must be revoked simultaneously (e.g. on transaction completion):

1. Group credentials by status list.
2. For each affected list: set all target bits, re-encode, re-sign, publish.
3. Record all revocations atomically.

Batch revocation within a single list is atomic. Revocations spanning multiple lists are eventually consistent.

## Dual-purpose status example

```json
{
  "credentialStatus": [
    {
      "id": "https://adapters.propdata.org.uk/status/epc/rev/list-042#18293",
      "type": "BitstringStatusListEntry",
      "statusPurpose": "revocation",
      "statusListIndex": "18293",
      "statusListCredential": "https://adapters.propdata.org.uk/status/epc/rev/list-042"
    },
    {
      "id": "https://adapters.propdata.org.uk/status/epc/sus/list-042#18293",
      "type": "BitstringStatusListEntry",
      "statusPurpose": "suspension",
      "statusListIndex": "18293",
      "statusListCredential": "https://adapters.propdata.org.uk/status/epc/sus/list-042"
    }
  ]
}
```

Revocation and suspension lists are separate. Same index may be used in both.

## Status list rotation

When a list reaches capacity (131,072 indices allocated):

- create a new list with the next sequential list ID
- old list remains hosted and accepts revocation updates indefinitely
- new credentials are allocated from the new list
- status URLs are stable for the life of any credential that references them

List IDs are sequential and scoped per issuer and purpose:

```
list-001  (full)
list-002  (full)
list-003  (active)
```

## Implementation notes

- Index allocation MUST be atomic. Use a database-level transaction or atomic increment.
- Revocation bit flips MUST be atomic within a single list.
- The status list credential `id` MUST exactly match its hosting URL.
- Status lists MUST be accessible to any verifier over the public internet.
- Status lists should be served from CDN-backed infrastructure for availability and low latency.
