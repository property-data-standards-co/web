---
title: "Signing & Proof"
description: "Cryptographic signing with eddsa-jcs-2022"
---

PDTF 2.0 uses **W3C Data Integrity proofs** so that credentials can be verified cryptographically, not just trusted because they came from a familiar platform. Signing is what turns JSON into a verifiable assertion.

## The proof format PDTF uses

Every PDTF credential includes a `proof` object using:

- `type`: `DataIntegrityProof`
- `cryptosuite`: `eddsa-jcs-2022`
- Ed25519 keys
- a verification method taken from the issuer's DID document

Example:

```json
{
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "eddsa-jcs-2022",
    "verificationMethod": "did:web:adapters.propdata.org.uk:epc#key-1",
    "proofPurpose": "assertionMethod",
    "created": "2026-03-24T10:00:00Z",
    "proofValue": "z4oJ9Bvn..."
  }
}
```

## Why `eddsa-jcs-2022`

PDTF standardises on this cryptosuite because it is a pragmatic fit for structured property data:

- **Ed25519** gives fast, compact signatures
- **JCS** (JSON Canonicalization Scheme) gives deterministic JSON serialisation
- it works cleanly with DID-based verification
- it avoids depending on more complex RDF canonicalisation flows

In short, it is standards-based without being unnecessarily heavy.

## How signing works

At issuance time, the issuer:

1. builds the credential
2. canonicalises the JSON using JCS
3. signs the canonical byte sequence with its Ed25519 private key
4. embeds the resulting proof in the credential

The signing key must correspond to a verification method listed under the issuer DID's `assertionMethod`.

## How verification works

A verifier checks a PDTF credential in roughly this order:

1. parse the credential structure
2. resolve the issuer DID
3. locate the referenced verification method
4. canonicalise the credential payload the same way
5. verify the Ed25519 signature in `proofValue`
6. confirm the key is authorised for `assertionMethod`
7. check revocation status and TIR authorisation

If any of those steps fail, the credential should not be trusted.

## Key management in PDTF

The specs standardise on **Ed25519** keys. Operationally, PDTF expects:

- one key per trusted adapter
- one key per user identity where custodial or wallet-based identity is in play
- platform-managed keys for issuance flows in Phase 1
- cloud KMS or HSM-backed storage for high-value issuer keys

`did:key` identities cannot rotate in place, because the key is the identifier. `did:web` identities can rotate by publishing a new key in the DID document and overlapping old and new keys during transition.

## What signing changes

Signing is the mechanism that shifts PDTF from a platform-trust model to a verifiable trust model.

Without signing, a consumer has to trust that an API response is authentic and unchanged. With signing, it can verify:

- who issued the credential
- whether the payload was altered
- whether the issuer key is valid
- whether the issuer is authorised for that claim

That is why proof is not an optional embellishment in PDTF 2.0. It is the technical basis for federation.
