---
title: "TIR Schema"
description: "JSON schema for Trusted Issuer Registry entries"
---

## Overview

The Trusted Issuer Registry (TIR) is a version-controlled JSON file that maps issuer DIDs to the specific entity:path combinations they are authorised to issue credentials about. It also lists user account providers.

**Canonical location:**

```
https://github.com/property-data-standards-co/trusted-issuer-registry
```

**Raw fetch URL:**

```
https://raw.githubusercontent.com/property-data-standards-co/trusted-issuer-registry/main/registry.json
```

**Preferred fetch (conditional requests with ETag):**

```
GET https://api.github.com/repos/property-data-standards-co/trusted-issuer-registry/contents/registry.json
Accept: application/vnd.github.raw+json
If-None-Match: "{etag}"
```

## Top-level structure

```json
{
  "$schema": "./schema/tir-schema.json",
  "version": "1.0",
  "updated": "2026-03-24T12:00:00Z",
  "issuers": {},
  "userAccountProviders": {}
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `$schema` | string | recommended | relative path to schema file |
| `version` | string | required | semantic version of the registry format, e.g. `1.0` |
| `updated` | ISO 8601 datetime | required | timestamp of last modification |
| `issuers` | object | required | map of issuer entries keyed by slug |
| `userAccountProviders` | object | required | map of account provider entries keyed by slug |

## Issuer entry

Each entry in `issuers` is keyed by a **slug** — a lowercase-hyphenated stable identifier.

```json
{
  "moverly-hmlr": {
    "name": "Moverly (HMLR Proxy)",
    "did": "did:web:adapters.propdata.org.uk:hmlr",
    "authorisedPaths": [
      "Title:/titleNumber",
      "Title:/titleExtents",
      "Title:/registerExtract/*",
      "Title:/ownership/*"
    ],
    "trustLevel": "trustedProxy",
    "proxyFor": "hmlr",
    "status": "active",
    "validFrom": "2026-03-01T00:00:00Z",
    "validUntil": null,
    "contact": "trust@moverly.com",
    "website": "https://moverly.com"
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | required | human-readable name |
| `did` | string | required | issuer DID |
| `authorisedPaths` | array of strings | required | entity:path combinations this issuer may assert |
| `trustLevel` | enum | required | `rootIssuer`, `trustedProxy`, or `accountProvider` |
| `proxyFor` | string | conditional | required when `trustLevel` is `trustedProxy`; the slug of the root issuer whose data this proxy fetches |
| `status` | enum | required | `active`, `planned`, `deprecated`, or `revoked` |
| `validFrom` | ISO 8601 or null | optional | validity start; null means from entry creation |
| `validUntil` | ISO 8601 or null | optional | validity end; null means no expiry |
| `contact` | string | optional | contact email |
| `website` | string | optional | website URL |

## User account provider entry

Each entry in `userAccountProviders` is keyed by a slug. These entries describe platforms that issue user DIDs.

```json
{
  "moverly": {
    "name": "Moverly",
    "did": "did:web:moverly.com",
    "description": "Issues user DIDs (did:key) as account provider. Validates user identity at onboarding.",
    "trustLevel": "accountProvider",
    "identityVerification": {
      "methods": ["email", "sms"],
      "description": "Email and SMS verification at registration."
    },
    "managedOrganisations": "https://moverly.com/.well-known/pdtf-managed-orgs.json",
    "status": "active",
    "validFrom": "2026-03-01T00:00:00Z",
    "validUntil": null,
    "contact": "trust@moverly.com",
    "website": "https://moverly.com"
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | required | human-readable name |
| `did` | string | required | provider DID |
| `description` | string | optional | what the provider does |
| `trustLevel` | string | required | always `accountProvider` |
| `identityVerification.methods` | array | optional | verification methods at onboarding, e.g. `email`, `sms`, `govuk-verify`, `document-check` |
| `identityVerification.description` | string | optional | human description of verification process |
| `managedOrganisations` | URL string | optional | URL of signed JSON listing `did:key` identifiers of organisations verified by this provider |
| `status` | enum | required | `active`, `planned`, `deprecated`, or `revoked` |
| `validFrom` | ISO 8601 or null | optional | validity start |
| `validUntil` | ISO 8601 or null | optional | validity end |
| `contact` | string | optional | contact email |
| `website` | string | optional | website URL |

## Managed organisations document

When `managedOrganisations` is present, it points to a signed JSON document listing organisation `did:key` identifiers verified by the provider.

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
    "proofValue": "z..."
  }
}
```

This document MUST be signed by the provider's DID key and served over HTTPS. Recommended cache TTL: 1h.

## Trust levels

| Trust level | Definition | Registry section |
|---|---|---|
| `rootIssuer` | primary authoritative source; issues VCs directly from canonical data | `issuers` |
| `trustedProxy` | authorised adapter; fetches from a primary source API and wraps as VCs | `issuers` |
| `accountProvider` | platform that issues user or organisation DIDs | `userAccountProviders` |

### Priority when assembling state

```
rootIssuer > trustedProxy > accountProvider
```

For conflicting path claims, higher trust level wins regardless of timestamp.

### `proxyFor` requirement

`proxyFor` is required when `trustLevel` is `trustedProxy`. It references the slug of the root issuer whose data the proxy fetches. Example: a Moverly-operated HMLR adapter has `"proxyFor": "hmlr"`.

## Entity:path authorisation format

Authorised paths follow the pattern:

```
Entity:/json/pointer/path
```

Where `Entity` is the capitalised entity type and the path is a JSON Pointer (RFC 6901).

### Wildcards

- `*` as the final segment matches all sub-paths.
- Mid-path wildcards are not supported.

| Pattern | Covers |
|---|---|
| `Property:/energyEfficiency/certificate` | exactly that path |
| `Property:/energyEfficiency/*` | all paths under `energyEfficiency` |
| `Property:/*` | all paths on the Property entity |
| `Title:/registerExtract/*` | all paths under `registerExtract` |

### Path matching algorithm

```text
For each authorisedPath:
  split on ":"  ->  authEntity, authPath
  if authEntity != entityType: skip
  if authPath == dataPath: match
  if authPath ends with "/*":
    prefix = authPath without trailing "/*"
    if dataPath starts with prefix + "/": match
    if dataPath == prefix: match
return no-match if no path matched
```

### Examples

EPC adapter:

```json
"authorisedPaths": [
  "Property:/energyEfficiency/*"
]
```

HMLR proxy:

```json
"authorisedPaths": [
  "Title:/titleNumber",
  "Title:/titleExtents",
  "Title:/registerExtract/*",
  "Title:/ownership/*"
]
```

Flood risk adapter:

```json
"authorisedPaths": [
  "Property:/environmentalIssues/flooding/*"
]
```

## Slug conventions

- lowercase alphanumeric and hyphens: `^[a-z][a-z0-9-]*$`
- start with a letter
- stable once published; never renamed
- organisation prefix for proxy adapters: `moverly-hmlr`, `moverly-epc`
- natural abbreviations for root issuers: `hmlr`, `voa`

## JSON Schema

The complete JSON Schema for `registry.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://raw.githubusercontent.com/property-data-standards-co/trusted-issuer-registry/main/schema/tir-schema.json",
  "title": "PDTF Trusted Issuer Registry",
  "type": "object",
  "required": ["version", "updated", "issuers", "userAccountProviders"],
  "additionalProperties": false,
  "properties": {
    "$schema": { "type": "string" },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+$"
    },
    "updated": {
      "type": "string",
      "format": "date-time"
    },
    "issuers": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": { "$ref": "#/$defs/issuerEntry" }
      },
      "additionalProperties": false
    },
    "userAccountProviders": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": { "$ref": "#/$defs/accountProviderEntry" }
      },
      "additionalProperties": false
    }
  },
  "$defs": {
    "issuerEntry": {
      "type": "object",
      "required": ["name", "did", "authorisedPaths", "trustLevel", "status"],
      "additionalProperties": false,
      "properties": {
        "name": { "type": "string", "minLength": 1 },
        "did": { "type": "string", "pattern": "^did:[a-z]+:.+$" },
        "authorisedPaths": {
          "type": "array",
          "items": {
            "type": "string",
            "pattern": "^[A-Z][a-zA-Z]*:/[a-zA-Z0-9/*_-][a-zA-Z0-9/*._-]*$"
          },
          "minItems": 1,
          "uniqueItems": true
        },
        "trustLevel": {
          "type": "string",
          "enum": ["rootIssuer", "trustedProxy", "accountProvider"]
        },
        "proxyFor": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9-]*$"
        },
        "status": {
          "type": "string",
          "enum": ["active", "planned", "deprecated", "revoked"]
        },
        "validFrom": { "type": ["string", "null"], "format": "date-time" },
        "validUntil": { "type": ["string", "null"], "format": "date-time" },
        "contact": { "type": "string", "format": "email" },
        "website": { "type": "string", "format": "uri" }
      },
      "if": {
        "properties": { "trustLevel": { "const": "trustedProxy" } }
      },
      "then": {
        "required": ["proxyFor"]
      }
    },
    "accountProviderEntry": {
      "type": "object",
      "required": ["name", "did", "trustLevel", "status"],
      "additionalProperties": false,
      "properties": {
        "name": { "type": "string", "minLength": 1 },
        "did": { "type": "string", "pattern": "^did:[a-z]+:.+$" },
        "description": { "type": "string" },
        "trustLevel": { "type": "string", "const": "accountProvider" },
        "identityVerification": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "methods": {
              "type": "array",
              "items": { "type": "string" }
            },
            "description": { "type": "string" }
          }
        },
        "managedOrganisations": { "type": "string", "format": "uri" },
        "status": {
          "type": "string",
          "enum": ["active", "planned", "deprecated", "revoked"]
        },
        "validFrom": { "type": ["string", "null"], "format": "date-time" },
        "validUntil": { "type": ["string", "null"], "format": "date-time" },
        "contact": { "type": "string", "format": "email" },
        "website": { "type": "string", "format": "uri" }
      }
    }
  }
}
```

## Verification result object

A TIR lookup produces:

```typescript
interface TIRVerificationResult {
  trusted: boolean;
  issuerSlug: string | null;
  trustLevel: "rootIssuer" | "trustedProxy" | "accountProvider" | null;
  status: "active" | "planned" | "deprecated" | "revoked" | "unknown";
  pathsCovered: boolean;
  uncoveredPaths: string[];
  warnings: string[];
}
```

## Status lifecycle

| Status | Meaning |
|---|---|
| `planned` | entry declared but issuer not yet active; credentials from this DID are untrusted |
| `active` | trusted, credentials accepted |
| `deprecated` | still trusted but scheduled for removal; verifiers should emit a warning |
| `revoked` | no longer trusted; all credentials from this issuer must be rejected |

## Caching guidance

| Scenario | Recommended TTL |
|---|---|
| Normal operation | 1h |
| After transient fetch failure | 5min |
| Origin unreachable | serve last known registry up to 24h |

Use ETag/If-None-Match conditional requests to avoid unnecessary downloads.

## Initial registry entries (Phase 1)

### Issuers

| Slug | Name | DID | Trust level | Authorised paths |
|---|---|---|---|---|
| `hmlr` | HM Land Registry | `did:web:hmlr.gov.uk` | `rootIssuer` | `Title:/*` |
| `mhclg-epc` | MHCLG EPC Register | `did:web:epc.communities.gov.uk` | `rootIssuer` | `Property:/energyEfficiency/*` |
| `voa` | Valuation Office Agency | `did:web:voa.gov.uk` | `rootIssuer` | `Property:/councilTax/*` |
| `ea-flood` | Environment Agency | `did:web:environment-agency.gov.uk` | `rootIssuer` | `Property:/environmentalIssues/flooding/*` |
| `moverly-hmlr` | Moverly (HMLR Proxy) | `did:web:adapters.propdata.org.uk:hmlr` | `trustedProxy` | `Title:/titleNumber`, `Title:/titleExtents`, `Title:/registerExtract/*`, `Title:/ownership/*` |
| `moverly-epc` | Moverly (EPC Proxy) | `did:web:adapters.propdata.org.uk:epc` | `trustedProxy` | `Property:/energyEfficiency/*` |
| `moverly-ea-flood` | Moverly (EA Flood Proxy) | `did:web:adapters.propdata.org.uk:ea-flood` | `trustedProxy` | `Property:/environmentalIssues/flooding/*` |

### Account providers

| Slug | Name | DID |
|---|---|---|
| `moverly` | Moverly | `did:web:moverly.com` |
