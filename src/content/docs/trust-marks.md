---
title: "Property Trust Marks"
description: "The authorisation badges that declare what each organisation can do in the PDTF ecosystem"
---

**Property Trust Marks** are signed tokens issued by the PDTF Trust Anchor (`https://propdata.org.uk`) that declare what an organisation is authorised to do within the federation. They are the PDTF-specific application of the [OpenID Federation trust mark](https://openid.net/specs/openid-federation-1_0.html#name-trust-marks) mechanism.

:::note[Provisional catalogue]
The trust mark catalogue is defined once, in [Sub-spec 04 §5](/specs/04-openid-federation/#5-trust-marks). It is provisional pending consultation [Q7](/consultation/#q7-trust-mark-granularity), and this page summarises it. Earlier drafts listed a mark per data category (`title-data-provider`, `property-data-provider` and others). Those marks are withdrawn: authority over a data category is now the `authorised_paths` inside a `pdtf-verified-issuer` mark.
:::

## What trust marks do

A trust mark is a digital badge. When the Trust Anchor issues a trust mark to an adapter, it's saying: *"We've reviewed this organisation, and they are authorised to issue these specific types of property credentials."*

Without trust marks, anyone could stand up an endpoint, sign credentials, and claim to be a title data provider. Trust marks make authorisation **verifiable**. A relying party can cryptographically confirm that the badge was issued by the Trust Anchor and hasn't been revoked.

## Current Property Trust Marks

### `pdtf-verified-issuer`

**URI:** `https://propdata.org.uk/trust-marks/pdtf-verified-issuer`

Authorises the holder to issue PDTF credentials **for specific entity:path combinations**. What it may issue is set by the mark's `delegation.authorised_paths`, so one mark type covers title data, EPCs, flood risk, searches and so on.

| Holder | `trust_level` | Typical `authorised_paths` |
|--------|---------------|----------------------------|
| PDTF HMLR Adapter | `trusted_proxy` (`proxy_for` HMLR) | `Title:/titleNumber`, `Title:/titleExtents`, `Title:/registerExtract/*`, `Title:/ownership/*` |
| PDTF EPC Adapter | `trusted_proxy` (`proxy_for` MHCLG) | `Property:/energyEfficiency/*` |
| Environment Agency, issuing directly | `root_issuer` | `Property:/environmentalIssues/flooding/*` |

---

### `account-provider`

**URI:** `https://propdata.org.uk/trust-marks/account-provider`

Authorises the holder to issue **user and organisation DIDs**, the identifiers that tie real people and companies to their roles in transactions.

Account providers verify identity at onboarding and manage the link between a person's real-world identity and their cryptographic DID. The mark carries `delegation.trust_level: "account_provider"`, the identity verification methods used, and a `managed_organisations` document listing the organisation `did:key`s the provider has verified.

An account provider is also the issuer of the credentials that record its users' own statements, such as a seller's TA6 answers. This is the working assumption, stated in [Sub-spec 02 §3.2.1](/specs/02-vc-data-model/) and provisional under consultation [Q4](/consultation/#q4-the-consumer-wallet-gap). Those credentials sit at the `assertion` trust level.

**Example holders:** the reference platform, LMS, wallet providers.

---

### `regulated-conveyancer`

**URI:** `https://propdata.org.uk/trust-marks/regulated-conveyancer`

Marks the holder as a **conveyancing firm** regulated by the **SRA** (Solicitors Regulation Authority) or **CLC** (Council of Licensed Conveyancers). The Trust Anchor issues it in Phase 1. The SRA and CLC are listed as permitted issuers so that they can issue it directly later.

## Trust mark structure

Each trust mark is a signed JWT. The PDTF-specific `delegation` claim carries the trust level and the authorised paths:

```json
{
  "iss": "https://propdata.org.uk",
  "sub": "https://adapters.propdata.org.uk/epc",
  "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer",
  "iat": 1776038400,
  "exp": 1776643200,
  "ref": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer/policy",
  "delegation": {
    "trust_level": "trusted_proxy",
    "proxy_for": "https://epc.communities.gov.uk",
    "authorised_paths": ["Property:/energyEfficiency/*"]
  }
}
```

Key points:
- **`delegation.trust_level`** records the issuer's level: `root_issuer`, `trusted_proxy` or `account_provider`. The taxonomy, including the credential-level `assertion`, is defined in [Sub-spec 04 §8](/specs/04-openid-federation/#8-trust-levels).
- **`delegation.authorised_paths`** uses entity:path notation with wildcard support. This is what makes trust **granular**, not all-or-nothing.
- **`delegation.proxy_for`** links a proxy back to the root issuer it draws data from.
- **Short lifetimes.** Marks last days, not years: this example lasts seven days and is re-issued before it expires. The Trust Anchor's status endpoint gives faster revocation still.

## How trust marks are verified

1. Extract the trust mark JWT from the entity's federation statement
2. Verify the JWT signature against the Trust Anchor's public key
3. Check `exp` hasn't passed (or query the [trust mark status endpoint](/docs/reference/federation-schema/#trust-mark-status-endpoint))
4. Confirm `delegation.authorised_paths` covers the credential paths being checked

```typescript
import { FederationRegistryResolver } from '@pdtf/core';

const resolver = new FederationRegistryResolver({
  trustAnchors: ['https://propdata.org.uk'],
});

const result = await resolver.verifyIssuer({
  issuerUrl: 'https://adapters.propdata.org.uk/epc',
  credentialPaths: ['Property:/energyEfficiency/*'],
});

// result.trusted === true
// result.trustMarkId === 'https://propdata.org.uk/trust-marks/pdtf-verified-issuer'
// result.trustLevel === 'trusted_proxy'
```

## Getting a trust mark

To receive a Property Trust Mark, an organisation must:

1. **Register as a federation entity** — publish an entity statement at `/.well-known/openid-federation`
2. **Apply to the Trust Anchor** — submit a request specifying which trust mark and which `authorised_paths`
3. **Pass review** — the Trust Anchor verifies the organisation's authority (e.g. regulatory status, API access agreements)
4. **Receive the signed trust mark** — the Trust Anchor issues a trust mark JWT and publishes a subordinate statement

In Phase 1 the Trust Anchor is an interim, project-led service run by the platform operator ([Sub-spec 04 §10.1](/specs/04-openid-federation/#10-governance)). Who operates it in the long term is open for consultation ([Q6](/consultation/#q6-trust-anchor-governance)). The governance process for trust mark issuance is managed through the [property-data-standards-co](https://github.com/property-data-standards-co) GitHub organisation.
