---
title: "Organisation Onboarding"
description: "Onboard your organisation as a PDTF 2.0 participant"
---

Organisation onboarding in PDTF 2.0 is about establishing a stable cryptographic identity for your organisation (a DID), then getting your organisation recognised for specific claim types through OpenID Federation. (Earlier drafts used a Trusted Issuer Registry; federation replaced it, see [04 §1.1](/specs/04-openid-federation/#11-why-openid-federation).)

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

## Join the federation

Being able to sign a credential proves identity, not authority.

To be treated as *authoritative* for a given claim, your organisation needs a Trust Mark from the PDTF Trust Anchor (`https://propdata.org.uk`). For issuers this is `pdtf-verified-issuer`, whose `delegation.authorised_paths` lists the entity:path combinations you are allowed to assert (for example `Property:/energyEfficiency/certificate`). Account providers hold `account-provider` and regulated conveyancing firms hold `regulated-conveyancer`. The catalogue is provisional, pending consultation [Q7](/consultation/#q7-trust-mark-granularity) ([04 §5](/specs/04-openid-federation/#5-trust-marks)).

Operationally, you apply to the Trust Anchor operator (in Phase 1, the platform operator as interim, project-led Trust Anchor; long-term governance is consultation [Q6](/consultation/#q6-trust-anchor-governance)). Once it issues your Subordinate Entity Statement and Trust Mark, publish your Entity Configuration at `/.well-known/openid-federation` with `authority_hints` pointing to the Trust Anchor. Verifiers then resolve trust for your credentials on those paths. Trust Marks are short-lived and re-issued before expiry ([04 §10.2](/specs/04-openid-federation/#102-accreditation-process)).

## Validate your setup

Before issuing anything, do a quick end-to-end check:

1. Resolve your DID (for `did:web`, confirm `/.well-known/did.json` is reachable over HTTPS).
2. Confirm your signing key appears under `assertionMethod`.
3. Issue a test credential and verify it locally using `@pdtf/core`.
4. Check federation trust resolution for the exact paths you assert.
5. Add a revocation status entry and ensure your signed status list is reachable. The current libraries use Bitstring `credentialStatus`; the spec's provisional mechanism is Token Status List ([14 §1](/specs/14-credential-revocation/#1-purpose), consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)).

## Next steps

- If you are building an adapter, follow the adapter guide and keep credentials sparse, path-scoped, and backed by clear evidence.
- If you are a platform, plan for transaction `did:web` lifecycle and long-lived org key management.
