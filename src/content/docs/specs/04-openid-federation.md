---
title: "04 OpenID Federation Trust Architecture"
description: "PDTF 2.0 specification document."
---


**Version:** 0.1 (Draft)
**Date:** 16 April 2026
**Author:** Ed Molyneux / Moverly
**Status:** Draft
**Parent:** [00 — Architecture Overview](/web/specs/00-architecture-overview/)

---

## Table of Contents

1. [Purpose](#1-purpose)
2. [Design Principles](#2-design-principles)
3. [Trust Anchor](#3-trust-anchor)
4. [Entity Statements](#4-entity-statements)
5. [Trust Marks](#5-trust-marks)
6. [Entity:Path Authorisation (delegation claim)](#6-entitypath-authorisation-delegation-claim)
7. [Trust Resolution](#7-trust-resolution)
8. [Trust Levels](#8-trust-levels)
9. [Federation Metadata Cache](#9-federation-metadata-cache)
10. [Governance](#10-governance)
11. [Migration Path](#11-migration-path)
12. [Security Considerations](#12-security-considerations)
13. [Open Questions](#13-open-questions)
14. [Implementation Notes](#14-implementation-notes)

---

## 1. Purpose

PDTF 2.0 replaces the single-platform trust model of v1 with a federated architecture where multiple issuers produce W3C Verifiable Credentials about property data. This creates a fundamental question: **how does a verifier know whether a given issuer is authorised to make the claims it's making?**

A Verifiable Credential's cryptographic signature proves that the credential has not been tampered with and was issued by the entity controlling the signing key. But it does *not* prove that the issuer had the **authority** to make those claims. Anyone can mint a VC claiming a property has an EPC rating of A — the question is whether the issuer is recognised as a legitimate source for EPC data.

PDTF 2.0 answers this question using **[OpenID Federation 1.0](https://openid.net/specs/openid-federation-1_0.html)**. A federation Trust Anchor publishes signed Entity Statements about subordinate entities, and issues signed **Trust Marks** that carry a PDTF-specific `delegation` claim describing the exact entity:path combinations an issuer is authorised to populate.

Verifiers establish trust by:

- Resolving the issuer's Entity Configuration (at `.well-known/openid-federation`)
- Walking the `authority_hints` chain to a recognised Trust Anchor
- Verifying the Trust Anchor's signed Entity Statement about the issuer
- Verifying the Trust Mark JWT(s) the issuer presents
- Checking the `delegation.authorised_paths` claim against the claims inside the VC

### 1.1 Why OpenID Federation

Earlier drafts of this specification described a bespoke GitHub-hosted Trusted Issuer Registry. External review flagged this as reinventing OpenID Federation with weaker guarantees (unsigned JSON vs signed JWTs) and a flat topology that would not scale beyond a handful of issuers. OpenID Federation provides:

- **Signed trust chains** — every level is cryptographically verifiable, not just the leaf credential
- **Decentralised governance** — each Trust Anchor sets its own policy; there is no single registry to control
- **Ecosystem alignment** — UK Smart Data, GOV.UK Wallet, and EUDI are all converging on OpenID Federation
- **Credential-format agnostic** — works with both Data Integrity VCs and JWT VCs
- **Existing infrastructure** — plugs into the OAuth/OIDC infrastructure platforms already operate

### 1.2 What the Federation Is Not

The federation is **not** a certificate authority. Issuers manage their own key material (see [Sub-spec 06: Key Management](/web/specs/06-key-management/)). The Trust Anchor signs Entity Statements and Trust Marks, not issuer keys.

The federation is **not** a DID registry. DID resolution happens separately via the appropriate DID method (`did:web`, `did:key`). Entity Statements and DID documents are complementary: Entity Statements describe what an entity is authorised to *do* in the federation; DID documents describe how to cryptographically verify the entity's signatures.

The federation is **not** an access control list. It governs *issuance authority*, not *read access*. Who can access a credential is governed by `termsOfUse` within the credential itself and by participation credentials presented at the API layer.

---

## 2. Design Principles

### 2.1 Standards-First

Everything is an OpenID Federation standard construct where one exists: Entity Configuration, Subordinate Entity Statements, Trust Marks, Trust Chain resolution. PDTF's only extension is a single claim (`delegation`) inside the Trust Mark.

### 2.2 Signed All The Way Down

Every level of the trust chain is a signed JWT. A verifier never has to "trust GitHub" or any HTTP endpoint as a source of authority — it only has to trust the Trust Anchor's public key (pinned out-of-band).

### 2.3 Entity:Path Granularity

Trust is not binary. The Trust Mark's `delegation.authorised_paths` claim specifies exactly which entity types and JSON paths an issuer is authorised for. An issuer trusted for EPC data is not automatically trusted for title register data.

> **Decision D20:** Authorisation is expressed as entity:path combinations (e.g. `Property:/energyEfficiency/certificate`), not issuer-level trust.

### 2.4 Federation Topology Can Grow

Phase 1 is a flat topology (Trust Anchor → leaf issuers). Phase 2+ can introduce intermediate entities (a sector authority below the Trust Anchor, or a conveyancing regulator issuing its own Trust Marks). No schema changes are required — OpenID Federation supports arbitrary chain depth natively.

> **Decision D24:** 3-phase evolution — Moverly proxies → independently hosted adapters → primary-source root issuers.

---

## 3. Trust Anchor

The PDTF Trust Anchor is operated at:

| Property | Value |
|----------|-------|
| Entity identifier | `https://trust.pdtf.org` |
| DID | `did:web:trust.pdtf.org` |
| Entity Configuration | `https://trust.pdtf.org/.well-known/openid-federation` |
| Fetch endpoint | `https://trust.pdtf.org/federation/fetch` |
| List endpoint | `https://trust.pdtf.org/federation/list` |
| Trust Mark issuance | `https://trust.pdtf.org/federation/trust_mark` |
| Trust Mark status | `https://trust.pdtf.org/federation/trust_mark_status` |

### 3.1 Entity Configuration

The Trust Anchor's self-signed Entity Configuration is a JWT published at `.well-known/openid-federation`:

```json
{
  "iss": "https://trust.pdtf.org",
  "sub": "https://trust.pdtf.org",
  "iat": 1776038400,
  "exp": 1776124800,
  "jwks": {
    "keys": [
      {
        "kty": "OKP",
        "crv": "Ed25519",
        "kid": "ta-2026-01",
        "x": "..."
      }
    ]
  },
  "metadata": {
    "federation_entity": {
      "organization_name": "PDTF Trust Anchor",
      "federation_fetch_endpoint": "https://trust.pdtf.org/federation/fetch",
      "federation_list_endpoint": "https://trust.pdtf.org/federation/list",
      "federation_trust_mark_endpoint": "https://trust.pdtf.org/federation/trust_mark",
      "federation_trust_mark_status_endpoint": "https://trust.pdtf.org/federation/trust_mark_status"
    }
  },
  "trust_mark_issuers": {
    "https://propdata.org.uk/trust-marks/pdtf-verified-issuer": [
      "https://trust.pdtf.org"
    ],
    "https://propdata.org.uk/trust-marks/account-provider": [
      "https://trust.pdtf.org"
    ],
    "https://propdata.org.uk/trust-marks/regulated-conveyancer": [
      "https://trust.pdtf.org",
      "https://sra.org.uk",
      "https://clc-uk.org"
    ]
  }
}
```

The Trust Anchor's public key is the single out-of-band root of trust. It is pinned in verifier configuration and in reference implementation bundles.

---

## 4. Entity Statements

A **Subordinate Entity Statement** is a signed JWT issued by the Trust Anchor (or an intermediate entity) about an entity immediately below it in the federation.

A subordinate entity (e.g. an adapter) publishes its own self-signed **Entity Configuration** at its `.well-known/openid-federation` URL, and declares the Trust Anchor(s) that accredit it via `authority_hints`.

### 4.1 Adapter Entity Configuration

```json
{
  "iss": "https://adapters.propdata.org.uk/hmlr",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "iat": 1776038400,
  "exp": 1776124800,
  "jwks": { "keys": [ { "kty": "OKP", "crv": "Ed25519", "kid": "hmlr-2026-01", "x": "..." } ] },
  "authority_hints": ["https://trust.pdtf.org"],
  "metadata": {
    "federation_entity": {
      "organization_name": "Moverly HMLR Adapter",
      "contacts": ["trust@moverly.com"]
    },
    "openid_credential_issuer": {
      "credential_issuer": "https://adapters.propdata.org.uk/hmlr",
      "credential_endpoint": "https://adapters.propdata.org.uk/hmlr/credential",
      "credentials_supported": [
        {
          "format": "ldp_vc",
          "types": ["VerifiableCredential", "TitleCredential"],
          "cryptographic_binding_methods_supported": ["did:web"]
        }
      ]
    }
  },
  "trust_marks": [
    {
      "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer",
      "trust_mark": "eyJhbGciOiJFZERTQSIs..."
    }
  ]
}
```

### 4.2 Subordinate Entity Statement (issued by Trust Anchor)

When a verifier fetches `https://trust.pdtf.org/federation/fetch?sub=https://adapters.propdata.org.uk/hmlr`, the Trust Anchor returns a signed JWT:

```json
{
  "iss": "https://trust.pdtf.org",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "iat": 1776038400,
  "exp": 1776124800,
  "jwks": { "keys": [ { "kty": "OKP", "crv": "Ed25519", "kid": "hmlr-2026-01", "x": "..." } ] },
  "metadata_policy": {
    "openid_credential_issuer": {
      "credentials_supported": {
        "subset_of": [
          { "types": ["VerifiableCredential", "TitleCredential"] }
        ]
      }
    }
  }
}
```

The `jwks` in the subordinate statement pins the keys the Trust Anchor has witnessed. A verifier therefore does not have to trust the subordinate's DNS-delivered JWKS on its own — the Trust Anchor's attestation is authoritative.

---

## 5. Trust Marks

A **Trust Mark** is a signed JWT asserting that a subject entity meets a named policy. PDTF defines the following trust marks:

| Trust Mark ID | Meaning | Typical Subject |
|---------------|---------|-----------------|
| `https://propdata.org.uk/trust-marks/pdtf-verified-issuer` | Authorised to issue PDTF VCs for specific entity:path combinations | Adapters, root issuers |
| `https://propdata.org.uk/trust-marks/account-provider` | Authorised to issue user/organisation DIDs on behalf of people | Moverly, LMS, wallet providers |
| `https://propdata.org.uk/trust-marks/regulated-conveyancer` | SRA/CLC regulated conveyancing firm | Conveyancer organisations |

### 5.1 `pdtf-verified-issuer` Structure

```json
{
  "iss": "https://trust.pdtf.org",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer",
  "iat": 1776038400,
  "exp": 1807574400,
  "ref": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer/policy",
  "delegation": {
    "trust_level": "trusted_proxy",
    "proxy_for": "https://hmlr.gov.uk",
    "authorised_paths": [
      "Title:/titleNumber",
      "Title:/titleExtents",
      "Title:/registerExtract/*",
      "Title:/ownership/*"
    ]
  }
}
```

The `delegation` claim is the PDTF-specific extension. Everything else is vanilla OpenID Federation.

### 5.2 `account-provider` Structure

```json
{
  "iss": "https://trust.pdtf.org",
  "sub": "https://moverly.com",
  "id": "https://propdata.org.uk/trust-marks/account-provider",
  "iat": 1776038400,
  "exp": 1807574400,
  "delegation": {
    "trust_level": "account_provider",
    "identity_verification": {
      "methods": ["email", "sms", "document-check"],
      "description": "Email + SMS at registration; document-based identity checks for seller/buyer roles."
    },
    "managed_organisations": "https://moverly.com/.well-known/pdtf-managed-orgs.json"
  }
}
```

The `managed_organisations` URL points to a signed JSON document listing the `did:key` identifiers of organisations whose identity has been verified by this account provider (see §5.4).

### 5.3 Trust Mark Revocation

Each trust mark carries `iat`/`exp` and can be checked for live status against the `federation_trust_mark_status_endpoint`. The Trust Anchor SHOULD set short lifetimes (days, not years) for high-impact trust marks and rely on status endpoint polling for faster revocation than the cache TTL would allow.

### 5.4 Managed Organisations Document

The `delegation.managed_organisations` URL points to a JSON document signed by the account provider's DID key:

```json
{
  "provider": "did:web:moverly.com",
  "updated": "2026-03-24T12:00:00Z",
  "organisations": [
    {
      "did": "did:key:z6MkpJmqLFMmaFHCqS9jVjMNRNHriSNkFCyG3MLbiqkVMhvm",
      "name": "Smith & Jones LLP",
      "sraNumber": "612345",
      "companyNumber": "OC123456",
      "verifiedAt": "2026-03-15T10:30:00Z"
    }
  ],
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "eddsa-jcs-2022",
    "verificationMethod": "did:web:moverly.com#key-1",
    "created": "2026-03-24T12:00:00Z",
    "proofPurpose": "assertionMethod",
    "proofValue": "z4FXQje2VihZqE3WPgtvJh4Kv8..."
  }
}
```

Verifiers consult this document to trace an Organisation's `did:key` back to a trusted account provider. Recommended cache TTL: 1 hour, with ETag-based conditional fetches.

---

## 6. Entity:Path Authorisation (delegation claim)

The `delegation.authorised_paths` array inside a `pdtf-verified-issuer` Trust Mark carries the entity:path authorisation that was, in earlier drafts, expressed as the `authorisedPaths` field of a TIR entry.

### 6.1 Format

```
Entity:/json/pointer/path
```

Where **Entity** is the PDTF entity type name, capitalised as per the entity graph (`Property`, `Title`, `Person`, `Organisation`, `SellerCapacity`, `Representation`, `Transaction`). The colon `:` separates entity from path. **Path** is a JSON Pointer (RFC 6901) prefixed with `/`.

### 6.2 Wildcards

A final path segment of `*` matches any subtree beneath the preceding path:

| Pattern | Matches |
|---------|---------|
| `Title:/registerExtract/*` | Any path under `/registerExtract` |
| `Property:/energyEfficiency/*` | Any path under `/energyEfficiency` |
| `Property:/*` | Any path on the Property entity |

The wildcard `*` MUST appear only as the **final** path segment. Mid-path wildcards (e.g. `Property:/*/certificate`) are not supported.

### 6.3 Path Matching Algorithm

```
function isPathAuthorised(entityType, dataPath, authorisedPaths):
    for each authorisedPath in authorisedPaths:
        [authEntity, authPath] = split(authorisedPath, ":")
        if authEntity != entityType: continue
        if authPath == dataPath: return true
        if authPath ends with "/*":
            prefix = authPath without trailing "/*"
            if dataPath starts with prefix + "/": return true
            if dataPath == prefix: return true
    return false
```

### 6.4 Multiple Issuers Per Path

Multiple issuers are permitted for the same entity:path — for example, competing search providers or valuers. The federation does not enforce exclusivity; state assembly (see [Sub-spec 07](/web/specs/07-state-assembly/)) merges credentials from multiple issuers for the same path using timestamp-ordered semantics.

---

## 7. Trust Resolution

When a verifier receives a VC, trust resolution proceeds as follows:

```
┌────────────────────────────────────────────┐
│ 1. Parse VC; extract issuer identifier    │
│    (DID or HTTPS URL) and entity:paths    │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 2. Fetch issuer Entity Configuration       │
│    from .well-known/openid-federation      │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 3. Walk authority_hints to Trust Anchor    │
│    At each step, fetch the superior's      │
│    Subordinate Entity Statement about the  │
│    issuer; verify signatures; collect JWKS │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 4. Verify Trust Anchor identity            │
│    Trust Anchor key MUST match pinned      │
│    value. Fail if not.                     │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 5. Verify Trust Mark(s)                   │
│    Verify signature by a permitted issuer  │
│    listed in trust_mark_issuers at the TA. │
│    Optionally poll trust_mark_status.      │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 6. Check delegation.authorised_paths       │
│    For each entity:path in the VC, run     │
│    the path matching algorithm against the │
│    Trust Mark's delegation claim.          │
└───────────────┬────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────┐
│ 7. Return TrustResolutionResult            │
└────────────────────────────────────────────┘
```

### 7.1 Result Object

```typescript
interface TrustResolutionResult {
  /** Whether the issuer is trusted for the claimed paths */
  trusted: boolean;

  /** The issuer's federation entity identifier */
  issuer: string;

  /** Trust chain: [leaf, ..., trust anchor] */
  trustChain: string[];

  /** Trust level derived from the delegation claim */
  trustLevel: "root_issuer" | "trusted_proxy" | "account_provider" | null;

  /** Whether all entity:paths in the VC are covered by delegation.authorised_paths */
  pathsCovered: boolean;

  /** Paths not covered by the delegation claim */
  uncoveredPaths: string[];

  /** Non-fatal warnings */
  warnings: string[];
}
```

---

## 8. Trust Levels

The `delegation.trust_level` claim classifies the subject. The same three levels that appeared in the earlier TIR design are preserved.

### 8.1 `root_issuer`

The primary authoritative source for the data. Issues VCs directly from its own canonical dataset. Examples: HM Land Registry (title data), MHCLG EPC Register, Valuation Office Agency. `delegation.proxy_for` is omitted.

### 8.2 `trusted_proxy`

An authorised intermediary that fetches data from a primary source's API and repackages it as signed VCs. `delegation.proxy_for` is REQUIRED and references the root issuer's entity identifier. The VC's `evidence` section should reference the source API call for auditability.

### 8.3 `account_provider`

A platform that issues user or organisation DIDs and is responsible for identity verification at onboarding. Uses the separate `account-provider` trust mark (not `pdtf-verified-issuer`). Carries `delegation.identity_verification` and optionally `delegation.managed_organisations`.

### 8.4 Comparison

| Aspect | root_issuer | trusted_proxy | account_provider |
|--------|-------------|---------------|------------------|
| Data source | Own canonical dataset | Primary source API | User onboarding |
| VC content | Authoritative assertion | Faithful reproduction | Identity binding |
| `proxy_for` required | No | Yes | No |
| Trust mark ID | `pdtf-verified-issuer` | `pdtf-verified-issuer` | `account-provider` |
| Phase | Phase 3 (future) | Phase 1 (now) | Phase 1 (now) |

---

## 9. Federation Metadata Cache

Verifiers MUST NOT resolve trust chains from scratch on every credential verification. OpenID Federation provides several caching hooks.

### 9.1 Cache Keys

| Object | Cache key | Recommended TTL |
|--------|-----------|-----------------|
| Entity Configuration | `iss` URL | `exp - iat` (typically 1 day) |
| Subordinate Entity Statement | `(iss, sub)` | `exp - iat` (typically 1 day) |
| Trust Mark JWT | `(iss, sub, id)` | `exp - iat` |
| Trust Mark status | `(iss, sub, id)` | 1 hour |
| Managed Organisations document | URL | 1 hour (use ETag) |

### 9.2 Stale Behaviour

| Scenario | Behaviour |
|----------|-----------|
| Cache fresh | Use cache |
| Cache expired, fetch succeeds | Replace cache |
| Cache expired, fetch fails, within stale window (24h) | Use stale, log warning |
| No cache, fetch fails | Fail verification |

**Fail-open vs fail-closed** is a deployment decision. Reference implementations default to fail-closed for high-assurance verifier contexts and fail-open with `trustUnverified` flagging for UI display.

### 9.3 Bootstrap Bundle

Reference implementations SHOULD ship with a bundled snapshot of the Trust Anchor's Entity Configuration and the set of currently active Subordinate Entity Statements. This is used on first run before any network fetch and as a last-resort fallback.

---

## 10. Governance

### 10.1 Phase 1

The Trust Anchor is operated by Moverly as PDTF 2.0 steward:

| Role | Responsibility | Phase 1 Holder |
|------|---------------|----------------|
| Trust Anchor operator | Signs Entity Statements and Trust Marks; operates federation endpoints | Moverly |
| Trust Mark issuer (`pdtf-verified-issuer`) | Decides which adapters/issuers are accredited | Moverly |
| Trust Mark issuer (`account-provider`) | Accredits account providers | Moverly |
| Trust Mark issuer (`regulated-conveyancer`) | Issues conveyancer trust marks | Moverly (interim), SRA/CLC (target) |

### 10.2 Accreditation Process

1. Entity applies to the Trust Anchor operator
2. Trust Anchor verifies the entity's identity and authorisation (e.g. SRA registration for conveyancers, contractual relationship for data adapters)
3. Trust Anchor issues a Subordinate Entity Statement and the appropriate Trust Marks
4. Entity publishes its Entity Configuration referencing the Trust Anchor via `authority_hints`

### 10.3 Emergency Revocation

If an issuer is compromised, the Trust Anchor:

1. Marks the Trust Mark as revoked via the `federation_trust_mark_status_endpoint`
2. Stops serving the Subordinate Entity Statement (or serves one with `exp` in the past)
3. Publishes an incident note

Verifiers polling the status endpoint (recommended every hour for high-impact trust marks) pick up the revocation within that interval.

### 10.4 Phase 2+

As PDTF 2.0 adoption grows, a multi-stakeholder property-sector governance body should operate the Trust Anchor (or become a higher-level Trust Anchor above Moverly). Multiple Trust Mark issuers will emerge (e.g. SRA issues `regulated-conveyancer` directly). No schema changes are required — this is native OpenID Federation topology.

---

## 11. Migration Path

> **Decision D24:** 3-phase evolution: Moverly proxies → separately hosted adapters → root issuers.

### 11.1 Phase 1 → Phase 2: Adapter Independence

1. New adapter publishes Entity Configuration at its own domain
2. Trust Anchor issues new Subordinate Entity Statement + Trust Mark
3. Old adapter's Trust Mark lifetime is not renewed; status endpoint eventually returns `revoked`
4. During overlap both adapters are live

### 11.2 Phase 2 → Phase 3: Root Issuer Activation

When a primary source (e.g. HMLR) begins issuing PDTF-compliant VCs directly:

1. HMLR publishes its own Entity Configuration, optionally as a subordinate of the PDTF Trust Anchor, or as its own Trust Anchor that PDTF verifiers pin alongside `trust.pdtf.org`
2. The Trust Anchor issues a `pdtf-verified-issuer` Trust Mark to HMLR with `trust_level: root_issuer`
3. The corresponding proxy's Trust Mark is allowed to expire / marked revoked
4. Verifiers begin preferring the root issuer's credentials

### 11.3 Backward Compatibility

Existing VCs issued by deprecated proxies remain cryptographically valid — signatures don't change. Trust Mark status affects **new verification decisions**, not historical ones.

---

## 12. Security Considerations

### 12.1 Trust Anchor Key Compromise

**Threat:** An attacker obtains the Trust Anchor's signing key and mints fraudulent Entity Statements or Trust Marks.

**Mitigations:**
- HSM-held root keys with break-glass procedures
- Annual key rotation with overlap period
- Monitoring for unexpected signing events
- Reference implementations pin key IDs as well as raw keys

### 12.2 `did:web` DNS Attacks

**Threat:** An attacker compromises DNS for a subordinate domain and serves a malicious DID document / Entity Configuration.

**Mitigations:**
- DNSSEC on all `did:web` domains used in the federation
- The Subordinate Entity Statement pins the JWKS — verifiers MUST use the Trust Anchor's pinned keys, not the DNS-delivered ones, as authoritative
- Certificate Transparency monitoring for federation domains

### 12.3 Stale Cache Exploitation

**Threat:** Attacker targets the window between a Trust Mark being revoked and verifier caches refreshing.

**Mitigations:**
- Short-lived Trust Marks (days, not years)
- Active `trust_mark_status_endpoint` polling for high-impact marks
- VC-level revocation (Bitstring Status List) operates on minutes, independent of federation caches

### 12.4 Enumeration and Privacy

The federation endpoints are public. They reveal which organisations participate in PDTF 2.0 and what they are authorised for. This is intentional — transparency is a feature of the trust model. No personal data is exposed. User DIDs are `did:key`, so the federation reveals the account *provider* but not individual users.

---

## 13. Open Questions

| # | Question | Status |
|---|----------|--------|
| Q1 | Should `pdtf-verified-issuer` Trust Marks support multiple `authorised_paths` arrays (to distinguish paths by trust level)? | Open |
| Q2 | Should the Trust Anchor also publish a signed aggregate list for verifiers that want to pre-load the whole federation? | Open |
| Q3 | How should "multi-path" credentials be handled when some paths are covered and some are not? | Leaning: ALL paths must be covered |
| Q4 | Separate Trust Anchor for test/staging, or a `test` marker on trust marks? | Open |
| Q5 | Should the federation publish a separate `proxy_for` trust mark for proxies of non-root data? | Open |

---

## 14. Implementation Notes

### 14.1 Reference Implementation

Federation trust resolution lives in the `@pdtf/core` package:

```
property-data-standards-co/core
├── src/
│   ├── federation/
│   │   ├── fetch.ts              # Entity Configuration + Statement fetching
│   │   ├── cache.ts              # Federation metadata cache
│   │   ├── resolve.ts            # Trust chain resolution
│   │   ├── trustMark.ts          # Trust Mark JWT verification
│   │   ├── pathMatch.ts          # Entity:path matching
│   │   └── types.ts
│   └── ...
```

### 14.2 Integration with VC Validator

```typescript
import { verifyCredential } from '@pdtf/vc-validator';

const result = await verifyCredential(credential, {
  trustAnchor: 'https://trust.pdtf.org',
  trustAnchorKeys: pinnedJwks,
  federationCache: cache,
  trustFailMode: 'closed',
});

// result.federation contains TrustResolutionResult
// result.signature contains cryptographic verification result
// result.revocation contains revocation check result
// result.valid is the composite boolean
```

### 14.3 Architecture Decision References

| Decision | Summary | Status |
|----------|---------|--------|
| **D8** | Trust infrastructure is OpenID Federation with PDTF Trust Anchor at `trust.pdtf.org` | ✅ Confirmed (supersedes earlier GitHub-TIR decision) |
| **D20** | Authorisation expressed as entity:path combinations inside the Trust Mark `delegation` claim | ✅ Confirmed |
| **D21** | Account providers carry an `account-provider` Trust Mark; user DIDs traced via `managed_organisations` | ✅ Confirmed |
| **D24** | 3-phase evolution: Moverly proxies → independently hosted adapters → primary-source root issuers | ✅ Confirmed |

---

## Appendix A: Entity:Path Quick Reference

| Entity:Path | Description | Typical Issuer |
|-------------|-------------|----------------|
| `Title:/titleNumber` | Title number | HMLR (via proxy) |
| `Title:/titleExtents` | Boundary geometry (GeoJSON) | HMLR (via proxy) |
| `Title:/registerExtract/*` | Full register extract | HMLR (via proxy) |
| `Title:/ownership/*` | Ownership assertions | HMLR (via proxy) |
| `Property:/energyEfficiency/certificate` | EPC certificate | MHCLG (via proxy) |
| `Property:/environmentalIssues/flooding/*` | Flood risk data | EA (via proxy) |
| `Property:/councilTax/*` | Council tax band + valuation | VOA (via proxy) |
| `SellerCapacity:/status` | SellerCapacity claim status | Account provider |
| `Representation:/role` | Representation role | Account provider |

---

## Appendix B: Glossary

| Term | Definition |
|------|-----------|
| **Trust Anchor** | The root entity of the federation; signs Entity Statements and Trust Marks |
| **Entity Configuration** | A self-signed JWT an entity publishes at `.well-known/openid-federation` describing itself |
| **Subordinate Entity Statement** | A JWT signed by a superior entity describing a subordinate |
| **Trust Mark** | A signed JWT asserting a subject meets a named policy |
| **`delegation` claim** | PDTF extension to the Trust Mark carrying `trust_level`, `authorised_paths`, `proxy_for` |
| **Trust Chain** | The sequence of Entity Statements from leaf issuer back to the Trust Anchor |
| **Entity:path** | `Entity:/json/pointer/path` — a location in the PDTF entity graph |
| **Root issuer** | Primary authoritative data source (e.g. HMLR) |
| **Trusted proxy** | Authorised intermediary that repackages source data as VCs |
| **Account provider** | Platform that issues user/org DIDs with identity verification |

---
