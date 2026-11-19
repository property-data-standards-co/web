---
title: "Signing & Proof"
description: "How PDTF credentials are signed and verified"
---

PDTF 2.0 signs every credential so that it can be verified cryptographically, not just trusted because it came from a familiar platform. Signing is what turns JSON into a verifiable assertion.

:::note[Provisional]
The spec's provisional securing mechanism is **SD-JWT-VC**: a JWS over the claims, with selective disclosure and holder key binding. **Data Integrity** (`DataIntegrityProof`, `eddsa-jcs-2022`) is the superseded representation, and it is what the current libraries implement. This page describes that representation. See [02 §2.4](/specs/02-vc-data-model/#24-securing-mechanism) (consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)).
:::

## The Data Integrity proof format

In the Data Integrity representation, every PDTF credential includes a `proof` object using:

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

The Data Integrity representation uses this cryptosuite because it is a pragmatic fit for structured property data:

- **Ed25519** gives fast, compact signatures
- **JCS** (JSON Canonicalization Scheme) gives deterministic JSON serialisation
- it works cleanly with DID-based verification
- it avoids depending on more complex RDF canonicalisation flows

In short, it is standards-based without being unnecessarily heavy.

## How signing works

In the Data Integrity representation, at issuance time the issuer:

1. builds the credential
2. canonicalises the JSON using JCS
3. signs the canonical byte sequence with its Ed25519 private key
4. embeds the resulting proof in the credential

The signing key must correspond to a verification method listed under the issuer DID's `assertionMethod`. Under SD-JWT-VC the same rule applies to the JWS header `kid`.

## How verification works

A verifier checks a PDTF credential in roughly this order:

1. parse the credential structure
2. resolve the issuer DID
3. locate the referenced verification method
4. canonicalise the credential payload the same way
5. verify the Ed25519 signature in `proofValue`
6. confirm the key is authorised for `assertionMethod`
7. check revocation status and the issuer's OpenID Federation authorisation (trust mark `delegation.authorised_paths`)

If any of those steps fail, the credential should not be trusted.

## Key management in PDTF

The specs standardise on **Ed25519** keys. Operationally, PDTF expects:

- one key per trusted adapter
- one key per user identity where custodial or wallet-based identity is in play; a person's key signs presentations, while the platform signs the credentials that record their assertions ([02 §3.2.1](/specs/02-vc-data-model/#321-issuer-of-a-persons-assertion), provisional)
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
