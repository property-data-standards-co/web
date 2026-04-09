---
title: "Organisation Onboarding"
description: "Onboard your organisation as a PDTF 2.0 participant"
---

Organisation onboarding in PDTF 2.0 is about establishing a stable cryptographic identity for your organisation (a DID), then getting that DID recognised for specific claim types via the Trusted Issuer Registry (TIR).

## What you need to participate

At minimum you need:

- An organisation DID (`did:key` or `did:web`).
- A signing key (Ed25519) that corresponds to the DID document (for `did:web`) or to the `did:key` itself.
- A plan for key storage and rotation (dev can be local, production should be KMS-backed).

## Choose an organisation DID method

PDTF supports two patterns:

- `did:key` (provider-managed): simplest operationally, no hosting required.
- `did:web` (self-hosted): publish a DID document over HTTPS at `/.well-known/did.json`.

If you operate a public service (adapter, platform, validation service), `did:web` is typically the best fit because it is resolvable and can advertise service endpoints.

## Get listed in the Trusted Issuer Registry

Being able to sign a credential proves identity, not authority.

To be treated as *authoritative* for a given claim, your DID needs to be listed in the TIR with the entity:path combinations you are allowed to assert (for example `Property:/energyEfficiency/certificate`).

Operationally, this is a pull request against the public TIR repo. Once merged, verifiers can immediately start trusting credentials signed by your DID for those paths.

## Validate your setup

Before issuing anything, do a quick end-to-end check:

1. Resolve your DID (for `did:web`, confirm `/.well-known/did.json` is reachable over HTTPS).
2. Confirm your signing key appears under `assertionMethod`.
3. Issue a test credential and verify it locally using `@pdtf/core`.
4. Check TIR authorisation for the exact paths you assert.
5. Add `credentialStatus` and ensure your status list endpoint is reachable.

## Next steps

- If you are building an adapter, follow the adapter guide and keep credentials sparse, path-scoped, and backed by clear evidence.
- If you are a platform, plan for transaction `did:web` lifecycle and long-lived org key management.
