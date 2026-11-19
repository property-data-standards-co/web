---
title: "OpenID Federation"
description: "How PDTF uses OpenID Federation to establish who can issue which property credentials"
---

**OpenID Federation** is an [OpenID standard](https://openid.net/specs/openid-federation-1_0.html) that lets organisations establish trust relationships without pre-shared secrets or centralised directories. PDTF 2.0 uses it as the backbone for deciding which data sources and adapters are authorised to issue property credentials.

If Verifiable Credentials answer *"was this data tampered with?"*, OpenID Federation answers *"should I trust the organisation that issued it?"*

## The core idea: trust chains

OpenID Federation works through **trust chains** — a sequence of signed statements that link an organisation back to a known authority.

Every participant in the federation publishes a **federation entity statement** — a signed JSON document at a well-known URL that describes who they are and what they do. A **Trust Anchor** (the top of the chain) signs **subordinate statements** about entities it trusts. Those statements can be chained — the anchor trusts an intermediate, the intermediate trusts a leaf — forming a verifiable path from any participant back to the root.

```
Trust Anchor (propdata.org.uk)
  └─ Subordinate: PDTF HMLR Adapter
  └─ Subordinate: PDTF EPC Adapter
  └─ Subordinate: LMS Title Adapter
```

Each link in the chain is a signed JWT. A verifier walks the chain from bottom to top, checking signatures at each step. If the chain terminates at a Trust Anchor the verifier recognises, the entity is trusted.

## How it works in PDTF

In the PDTF ecosystem:

- **Trust Anchor**: the federation Trust Anchor is `https://propdata.org.uk`. It publishes its own entity statement at `https://propdata.org.uk/.well-known/openid-federation` and signs subordinate statements for authorised adapters. In Phase 1 the platform operator runs it as an interim, project-led Trust Anchor; long-term governance is open for consultation ([Q6](/consultation/#q6-trust-anchor-governance)).
- **Subordinate entities**: Each adapter (e.g. the PDTF HMLR proxy, an EPC adapter) publishes its own entity statement and is referenced by a subordinate statement from the Trust Anchor.
- **Trust Marks**: The Trust Anchor issues **Property Trust Marks** — signed tokens that declare what an entity is authorised to do.

### Entity statements

An entity statement is a signed JWT published at `{entity_url}/.well-known/openid-federation`. It contains:

- **`iss`** — who issued the statement (the entity itself for self-signed, or the superior for subordinate statements)
- **`sub`** — the entity being described
- **`jwks`** — the entity's public keys
- **`metadata`** — what the entity does (e.g. credential issuer metadata, federation entity metadata)
- **`trust_marks`** — the Trust Marks this entity holds

```json
{
  "iss": "https://adapters.propdata.org.uk/hmlr",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "jwks": { "keys": [{ "kty": "OKP", "crv": "Ed25519", "..." : "..." }] },
  "metadata": {
    "federation_entity": {
      "organization_name": "PDTF HMLR Adapter",
      "homepage_uri": "https://platform.example.com"
    },
    "openid_credential_issuer": {
      "credential_configurations_supported": { "..." : "..." }
    }
  },
  "trust_marks": [
    { "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer", "trust_mark": "eyJ..." }
  ]
}
```

## Property Trust Marks

A **Trust Mark** is a signed JWT issued by the Trust Anchor that declares an entity's authorisation. Think of it like a digital badge — *"this adapter is authorised to issue these title data paths"*.

Each Property Trust Mark contains:

| Field | Purpose | Example |
|---|---|---|
| `id` | The trust mark type URI | `https://propdata.org.uk/trust-marks/pdtf-verified-issuer` |
| `iss` | The Trust Anchor that issued it | `https://propdata.org.uk` |
| `sub` | The entity it's issued to | `https://adapters.propdata.org.uk/hmlr` |
| `iat` / `exp` | When issued and when it expires | Short-lived: days, not years (examples use 7 days) |
| `delegation.trust_level` | The issuer's trust level | `trusted_proxy` (or `root_issuer`, `account_provider`) |
| `delegation.authorised_paths` | Which entity:path combos the entity can issue credentials for | `["Title:/registerExtract/*", "Title:/ownership/*"]` |

### Current Property Trust Marks

:::note[Provisional]
The trust mark catalogue is stated in [04 §5](/specs/04-openid-federation/#5-trust-marks) and is provisional pending consultation [Q7](/consultation/#q7-trust-mark-granularity). Earlier per-category marks such as `title-data-provider` and `property-data-provider` are withdrawn.
:::

| Trust Mark ID | Purpose |
|---|---|
| `pdtf-verified-issuer` | Authorised to issue PDTF credentials for specific entity:path combinations (adapters, root issuers) |
| `account-provider` | Authorised to issue user and organisation DIDs |
| `regulated-conveyancer` | An SRA/CLC regulated conveyancing firm |

Authority over a data category is **scoped** by `delegation.authorised_paths` inside the `pdtf-verified-issuer` mark, not by a separate mark per category:

```json
{
  "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer",
  "sub": "https://adapters.propdata.org.uk/epc",
  "delegation": {
    "trust_level": "trusted_proxy",
    "authorised_paths": ["Property:/energyEfficiency/*"]
  }
}
```

This adapter is trusted only for EPC data — not flood, not council tax, not anything else on the Property entity.

## How verification works

When a verifier receives a credential, the trust check follows this sequence:

1. **Resolve the issuer's entity statement** — fetch from `{issuer_url}/.well-known/openid-federation`
2. **Build the trust chain** — follow the chain of subordinate statements up to the Trust Anchor
3. **Validate signatures** — every statement in the chain must be properly signed
4. **Check the Trust Mark** — find the relevant trust mark for the credential type
5. **Verify path authorisation** — confirm the trust mark's `delegation.authorised_paths` cover the credential's data paths
6. **Check status** — ensure the trust mark hasn't expired or been revoked

If trust resolution fails, the credential is excluded; there is no fallback trust level.

```typescript
import { FederationRegistryResolver } from '@pdtf/core';

const resolver = new FederationRegistryResolver({
  trustAnchors: ['https://propdata.org.uk'],
});

const trustResult = await resolver.verifyIssuer({
  issuerUrl: 'https://adapters.propdata.org.uk/epc',
  credentialPaths: ['Property:/energyEfficiency/*'],
});

if (!trustResult.trusted) {
  console.error('Untrusted issuer:', trustResult.reason);
}
```

## Why this matters for property

OpenID Federation isn't just a PDTF invention — it's a standard being adopted across several adjacent ecosystems:

- **UK Smart Data** — the government's initiative for portable, verified data across sectors (energy, telecoms, finance, property)
- **GOV.UK Wallet** — the upcoming UK digital identity wallet will use OpenID Federation for trust establishment
- **EUDI Wallet** — the EU Digital Identity framework uses the same trust chain model

By building on OpenID Federation now, PDTF credentials will be verifiable by wallets and systems that don't know anything about property — they just need to recognise the Trust Anchor. A conveyancer's wallet app, a mortgage lender's system, or a government portal can all verify the same credential using the same trust chain.

This is the difference between building a proprietary trust system that only works within PDTF, and building on an open standard that interoperates with the wider digital identity ecosystem.

## Relationship to the old TIR

Earlier PDTF documentation described a **Trusted Issuer Registry (TIR)** — a static JSON file listing authorised issuers. OpenID Federation replaces this with a dynamic, standards-based approach:

| Aspect | Old TIR | OpenID Federation |
|---|---|---|
| Format | Static JSON file in a Git repo | Signed JWTs at well-known URLs |
| Trust establishment | Manual review of the JSON | Cryptographic trust chains |
| Revocation | Change status in JSON and push | Revoke the trust mark or subordinate statement |
| Interoperability | PDTF-specific | Standard across digital identity ecosystems |
| Discovery | Fetch a known URL | Automatic via `.well-known/openid-federation` |

The `@pdtf/core` library abstracts this — `FederationRegistryResolver` handles trust chain resolution, trust mark verification, and path authorisation checks behind the same `verifyIssuer` interface.
