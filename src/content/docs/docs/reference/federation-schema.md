---
title: "Federation Schema"
description: "Reference for OpenID Federation entity statements and Property Trust Mark JWT formats used in PDTF"
---

This page documents the JWT formats for **entity statements** and **Property Trust Marks** as used in the PDTF federation. These follow the [OpenID Federation 1.0](https://openid.net/specs/openid-federation-1_0.html) specification with PDTF-specific trust mark definitions.

## Entity statement JWT

Every federation participant publishes a self-signed entity statement at `{entity_url}/.well-known/openid-federation`. The Trust Anchor also publishes **subordinate statements** for each entity it trusts.

### Header

```json
{
  "alg": "EdDSA",
  "kid": "key-1",
  "typ": "entity-statement+jwt"
}
```

### Payload (self-signed)

```json
{
  "iss": "https://adapters.propdata.org.uk/hmlr",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "iat": 1776038400,
  "exp": 1776124800,
  "jwks": {
    "keys": [
      {
        "kty": "OKP",
        "crv": "Ed25519",
        "kid": "key-1",
        "x": "base64url-encoded-public-key",
        "use": "sig"
      }
    ]
  },
  "authority_hints": [
    "https://propdata.org.uk"
  ],
  "metadata": {
    "federation_entity": {
      "organization_name": "PDTF HMLR Adapter",
      "homepage_uri": "https://platform.example.com",
      "contacts": ["trust@propdata.org.uk"]
    },
    "openid_credential_issuer": {
      "credential_endpoint": "https://adapters.propdata.org.uk/hmlr/credentials",
      "credential_configurations_supported": {}
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

### Payload fields

| Field | Type | Required | Description |
|---|---|---|---|
| `iss` | string | ✓ | Issuer — the entity itself (self-signed) or the superior (subordinate statement) |
| `sub` | string | ✓ | Subject — the entity being described |
| `iat` | number | ✓ | Issued-at timestamp (Unix seconds) |
| `exp` | number | ✓ | Expiration timestamp |
| `jwks` | object | ✓ | The entity's public keys (JWK Set) |
| `authority_hints` | string[] | ✓* | URLs of superior entities. Required for non-anchor entities |
| `metadata` | object | ✓ | Entity metadata (see below) |
| `trust_marks` | array | — | Trust marks held by this entity |
| `constraints` | object | — | Policy constraints on subordinates (anchor only) |

### Subordinate statement

The Trust Anchor publishes subordinate statements at its fetch endpoint, `https://propdata.org.uk/federation/fetch?sub={entity_url}` (advertised as `federation_fetch_endpoint`):

```json
{
  "iss": "https://propdata.org.uk",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "iat": 1776038400,
  "exp": 1776124800,
  "jwks": {
    "keys": [{ "..." : "..." }]
  },
  "metadata_policy": {
    "openid_credential_issuer": {
      "credential_endpoint": { "value": "https://adapters.propdata.org.uk/hmlr/credentials" }
    }
  }
}
```

The subordinate statement is signed by the **superior** (the Trust Anchor), not by the subject. This is what creates the trust chain.

## Metadata types

### `federation_entity`

General information about the organisation:

```json
{
  "organization_name": "PDTF HMLR Adapter",
  "homepage_uri": "https://platform.example.com",
  "contacts": ["trust@propdata.org.uk"],
  "logo_uri": "https://platform.example.com/logo.png",
  "policy_uri": "https://platform.example.com/trust-policy"
}
```

### `openid_credential_issuer`

Present when the entity issues credentials via [OID4VCI](/docs/concepts/oid4vc/):

```json
{
  "credential_endpoint": "https://adapters.propdata.org.uk/hmlr/credentials",
  "credential_configurations_supported": {
    "TitleCredential": {
      "format": "dc+sd-jwt",
      "vct": "urn:pdtf:vct:TitleCredential",
      "cryptographic_binding_methods_supported": ["did:key", "did:web"]
    }
  }
}
```

`dc+sd-jwt` is the OID4VCI format for SD-JWT-VC, the spec's provisional securing mechanism ([02 §2.4](/specs/02-vc-data-model/#24-securing-mechanism), consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)). The superseded Data Integrity representation, which the current libraries implement, uses `ldp_vc` with a `credential_definition`.

### `openid_relying_party`

Present when the entity is a verifier requesting credentials via OID4VP:

```json
{
  "redirect_uris": ["https://platform.example.com/callback"],
  "vp_formats": {
    "dc+sd-jwt": {
      "sd-jwt_alg_values": ["EdDSA", "ES256"],
      "kb-jwt_alg_values": ["EdDSA", "ES256"]
    }
  }
}
```

## Property Trust Mark JWT

Trust marks are signed JWTs issued by the Trust Anchor.

### Header

```json
{
  "alg": "EdDSA",
  "kid": "anchor-key-1",
  "typ": "trust-mark+jwt"
}
```

### Payload

```json
{
  "iss": "https://propdata.org.uk",
  "sub": "https://adapters.propdata.org.uk/hmlr",
  "id": "https://propdata.org.uk/trust-marks/pdtf-verified-issuer",
  "iat": 1776038400,
  "exp": 1776643200,
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

Trust marks have short lifetimes (days, not years) and are re-issued before expiry. The example uses seven days (`exp - iat = 604800`). An `account-provider` mark carries `delegation.trust_level: "account_provider"` with `identity_verification` and `managed_organisations` instead of `authorised_paths` ([04 §5.2](/specs/04-openid-federation/#52-account-provider-structure)).

### Trust mark fields

| Field | Type | Required | Description |
|---|---|---|---|
| `iss` | string | ✓ | The Trust Anchor that issued this mark |
| `sub` | string | ✓ | The entity this mark is issued to |
| `id` | string | ✓ | Trust mark type URI |
| `iat` | number | ✓ | Issued-at timestamp |
| `exp` | number | ✓ | Expiration; short-lived (days), with live status from the status endpoint |
| `ref` | string | — | Reference URI for the trust mark policy |
| `delegation` | object | ✓* | PDTF extension; present on `pdtf-verified-issuer` and `account-provider` marks |
| `delegation.trust_level` | string | ✓ | `root_issuer`, `trusted_proxy` or `account_provider` |
| `delegation.proxy_for` | string | — | Required for `trusted_proxy`: the root issuer entity URL |
| `delegation.authorised_paths` | string[] | ✓* | Entity:path combinations this entity is authorised for (`pdtf-verified-issuer`) |
| `delegation.identity_verification` | object | ✓* | Identity verification methods (`account-provider`) |
| `delegation.managed_organisations` | string | — | URL of the signed managed organisations document (`account-provider`) |

### Trust mark types

:::note[Provisional]
The trust mark catalogue is stated in [04 §5](/specs/04-openid-federation/#5-trust-marks) and is provisional pending consultation [Q7](/consultation/#q7-trust-mark-granularity). Authority over data categories is expressed by `delegation.authorised_paths` inside `pdtf-verified-issuer`, not by a mark per category.
:::

| ID | Slug | Purpose |
|---|---|---|
| `https://propdata.org.uk/trust-marks/pdtf-verified-issuer` | `pdtf-verified-issuer` | Issue PDTF credentials for specific entity:path combinations (adapters, root issuers) |
| `https://propdata.org.uk/trust-marks/account-provider` | `account-provider` | Issue user/organisation DIDs |
| `https://propdata.org.uk/trust-marks/regulated-conveyancer` | `regulated-conveyancer` | SRA/CLC regulated conveyancing firm |

The earlier per-category marks (`title-data-provider`, `property-data-provider`, `search-provider`, `energy-data-provider`, `environmental-data-provider`) are withdrawn.

### Trust levels

Trust levels are canonical in [04 §8](/specs/04-openid-federation/#8-trust-levels).

| Level | Description |
|---|---|
| `root_issuer` | Primary authoritative source (e.g. HMLR for title data) |
| `trusted_proxy` | Authorised adapter fetching from a primary source API |
| `account_provider` | Platform issuing user or organisation identifiers |
| `assertion` | Credential level, not recorded in the federation: a credential whose `evidence` is a `UserAttestation` |

The first three are recorded as `delegation.trust_level`. Conflict ordering is `root_issuer` > `trusted_proxy` > `account_provider` > `assertion`.

## Entity:path format

Authorised paths follow the pattern `Entity:/json/pointer/path` using JSON Pointer (RFC 6901):

| Pattern | Matches |
|---|---|
| `Title:/registerExtract/schedule` | Exactly that path |
| `Title:/registerExtract/*` | All paths under `/registerExtract` |
| `Property:/*` | All paths on the Property entity |

Wildcards (`*`) are only supported as the final path segment.

## Trust chain resolution

A verifier resolves trust by:

1. Fetch the leaf entity statement from `{entity}/.well-known/openid-federation`
2. For each entry in `authority_hints`, fetch the subordinate statement from the superior's `federation_fetch_endpoint` (for the Trust Anchor, `https://propdata.org.uk/federation/fetch?sub={entity}`)
3. Verify the subordinate statement signature against the superior's keys
4. Repeat up the chain until reaching a recognised Trust Anchor
5. The chain is valid if every signature checks out and the anchor is trusted

### Trust chain validation rules

- Maximum chain depth: 5 (configurable)
- Every statement must be within its `iat`/`exp` window
- The leaf entity's `jwks` must match the keys in the subordinate statement
- Trust marks must be signed by an issuer listed for that mark in the Trust Anchor's `trust_mark_issuers`
- If trust resolution fails, the credential is excluded; there is no fallback trust level

## Trust mark status endpoint

The Trust Anchor operates a status endpoint (`federation_trust_mark_status_endpoint`) for checking trust mark validity:

```
GET https://propdata.org.uk/federation/trust_mark_status
  ?sub=https://adapters.propdata.org.uk/hmlr
  &trust_mark_id=https://propdata.org.uk/trust-marks/pdtf-verified-issuer
```

Response:

```json
{
  "active": true
}
```

This allows real-time revocation checking without waiting for trust mark expiry.
