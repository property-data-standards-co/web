---
title: "Decentralised Identifiers"
description: "DID methods and resolution in PDTF 2.0"
---

PDTF 2.0 uses **decentralised identifiers (DIDs)** to give issuers, people, organisations, and transactions stable, verifiable identities. This replaces opaque platform-specific IDs with identifiers that can be resolved and checked independently.

## Why DIDs matter in PDTF

A Verifiable Credential is only useful if you can answer two questions:

1. **Who issued this?**
2. **How do I verify their key?**

DIDs solve that problem. They let a verifier resolve the issuer's public key and, where needed, discover service endpoints.

PDTF also uses **URNs** for non-actor entities such as properties and titles.

## The DID methods PDTF uses

PDTF 2.0 deliberately uses only two DID methods.

### `did:key`

Used for:

- people
- provider-managed organisations

`did:key` is self-contained. The public key is encoded directly into the DID, so it can be resolved with no network call.

Example:

```text
did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK
```

This is ideal for people because it is simple, portable, and requires no hosting.

### `did:web`

Used for:

- self-hosted organisations
- transactions
- trusted adapters

`did:web` resolves through HTTPS and can publish richer DID documents with service endpoints.

Examples:

```text
did:web:smithandjones.co.uk
did:web:moverly.com:transactions:abc123
did:web:adapters.propdata.org.uk:hmlr
```

This method is used where discoverability matters.

## URNs for subjects

Not everything needs a DID. Properties and titles do not sign credentials, so PDTF identifies them with URNs:

```text
urn:pdtf:uprn:100023456789
urn:pdtf:titleNumber:DN123456
urn:pdtf:unregisteredTitle:f47ac10b-58cc-4372-a567-0e02b2c3d479
```

Relationship entities such as Ownership, Representation, Consent, and Offer also use URNs.

## DID documents

A DID document tells a verifier:

- which keys are valid
- what those keys may be used for
- which services are available

A transaction DID document typically exposes endpoints like:

- a `PdtfTransactionEndpoint`
- an `McpEndpoint`

An adapter DID document can expose:

- a `VcIssuanceEndpoint`
- a revocation status endpoint

Example transaction DID shape:

```json
{
  "id": "did:web:moverly.com:transactions:abc123",
  "service": [
    {
      "type": "PdtfTransactionEndpoint",
      "serviceEndpoint": "https://api.moverly.com/v2/transactions/abc123"
    },
    {
      "type": "McpEndpoint",
      "serviceEndpoint": "https://api.moverly.com/mcp/transactions/abc123"
    }
  ]
}
```

## Resolution model

- **`did:key`**: resolve locally, no HTTP required
- **`did:web`**: fetch the DID document over HTTPS

For `did:web`, the domain becomes part of the trust boundary. That is also how PDTF separates environments such as local, staging, and production.

## Why this matters

DIDs are how PDTF moves from platform trust to cryptographic trust. A verifier can inspect the issuer identifier, resolve the key, validate the proof, and then check the issuer against the Trusted Issuer Registry.

That means identity is no longer implicit in the API hostname or database row. It is explicit, portable, and verifiable, which is exactly what a federated property-data ecosystem needs.
