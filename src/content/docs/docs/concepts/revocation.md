---
title: "Revocation"
description: "How credentials are revoked using Bitstring Status List"
---

PDTF 2.0 treats revocation as mandatory infrastructure, not an optional extra. Property transactions change constantly, so a verifier needs to know not just whether a credential was valid when issued, but whether it is **still** valid now.

## Why revocation matters

Examples where revocation is essential:

- a seller changes conveyancer
- a buyer withdraws an offer
- a new EPC supersedes an old one
- ownership or authority no longer applies
- incorrect data is discovered and replaced

Without revocation, a stale but correctly signed credential could continue to look valid.

## The mechanism: Bitstring Status List

PDTF 2.0 uses the W3C **Bitstring Status List** model. Every credential includes a `credentialStatus` entry pointing to a status list credential and a bit position inside it.

Example:

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

The status list itself is a Verifiable Credential containing a compressed bitstring.

- bit = `0` means **not revoked**
- bit = `1` means **revoked**

## How the check works

When verifying a credential:

1. fetch the referenced status list credential
2. verify the status list's own signature
3. decode the bitstring
4. inspect the bit at `statusListIndex`
5. reject the credential if that bit is set

This allows large numbers of credentials to be checked efficiently without one separate revocation object per credential.

## What gets revoked in PDTF

In practice, revocation matters especially for relationship credentials:

- **OwnershipCredential**
- **RepresentationCredential**
- **DelegatedConsentCredential**
- **OfferCredential**

These can become unsafe quickly if they outlive the real-world relationship they represent.

It also applies to property and title data when newer authoritative data supersedes older data.

## Issuer responsibilities

Each issuer hosts its own status list endpoints. For example:

- adapters host status lists for credentials they issue
- platforms host status lists for platform-issued credentials

When revoking, the issuer:

1. flips the relevant bit
2. re-signs the status list credential
3. republishes it at the same URL

That means revocation can be checked using stable references.

## Caching and freshness

Status lists are cacheable, but only with short TTLs. PDTF expects verifiers to cache them briefly and refresh regularly, especially for sensitive checks like representation or consent.

This balances performance with the need to reflect changes quickly.

## Why PDTF chose this model

Bitstring Status Lists are a good fit because they are:

- standardised
- compact
- efficient at scale
- easy to host at stable public URLs
- compatible with VC verification flows

Most importantly, they let PDTF model a basic truth of property transactions: **authority changes over time**. A signature proves what was asserted. Revocation proves whether that assertion should still be relied on.
