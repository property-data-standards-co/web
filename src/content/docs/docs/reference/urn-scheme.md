---
title: "URN Scheme"
description: "PDTF URN namespace and identifier formats"
---

## Namespace

PDTF uses the `urn:pdtf` namespace for non-actor identifiers.

These URNs identify graph subjects, not issuers or authenticating parties.

## URN catalogue

| Pattern | Identifies | Source |
|---|---|---|
| `urn:pdtf:uprn:{uprn}` | Property | Ordnance Survey UPRN |
| `urn:pdtf:titleNumber:{number}` | Registered title | HMLR title number |
| `urn:pdtf:unregisteredTitle:{id}` | Unregistered title | platform-generated identifier |
| `urn:pdtf:ownership:{id}` | Ownership relationship entity | generated |
| `urn:pdtf:representation:{id}` | Representation relationship entity | generated |
| `urn:pdtf:consent:{id}` | Delegated consent relationship entity | generated |
| `urn:pdtf:offer:{id}` | Offer relationship entity | generated |
| `urn:pdtf:vc:{id}` | Credential identifier when used | generated |
| `urn:pdtf:status:{id}` | status-oriented resource identifier when used | generated or host-mapped namespace |

## Canonical forms

### Property

```text
urn:pdtf:uprn:100023456789
```

- numeric UPRN
- stable property identifier
- used as `credentialSubject.id` for `PropertyCredential`

### Registered title

```text
urn:pdtf:titleNumber:AB12345
```

- HMLR title number based
- used as `credentialSubject.id` for `TitleCredential`

### Unregistered title

```text
urn:pdtf:unregisteredTitle:f47ac10b-58cc-4372-a567-0e02b2c3d479
```

- minted when land has no HMLR title number
- may later transition to a registered title URN after first registration

### Ownership

```text
urn:pdtf:ownership:7c9e6679-7425-40de-944b-e07fc1f90ae7
```

- identifies a thin ownership assertion entity
- subject of `OwnershipCredential`

### Representation

```text
urn:pdtf:representation:a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d
```

- identifies delegated authority from person to organisation
- subject of `RepresentationCredential`

### Consent

```text
urn:pdtf:consent:b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e
```

- identifies delegated consent scope and purpose
- subject of `DelegatedConsentCredential`

### Offer

```text
urn:pdtf:offer:c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f
```

- identifies offer entity
- subject of `OfferCredential`

### Credential URN

A credential `id` MAY be omitted, but when present PDTF uses:

```text
urn:pdtf:vc:{uuid}
```

Example:

```text
urn:pdtf:vc:epc-7f3a2b1c-9d4e-5f6a-8b7c-0d1e2f3a4b5c
```

### Status URN

Status entries in deployed systems typically use HTTPS URLs for `credentialStatus.id` and `statusListCredential`, but a URN form can be used for internal or referenced resource modelling:

```text
urn:pdtf:status:{id}
```

## ABNF

```abnf
pdtf-urn          = "urn:pdtf:" pdtf-nss

pdtf-nss          = property-urn
                  / title-urn
                  / unregistered-title-urn
                  / ownership-urn
                  / representation-urn
                  / consent-urn
                  / offer-urn
                  / vc-urn
                  / status-urn

property-urn      = "uprn:" uprn
uprn              = 1*12DIGIT

title-urn         = "titleNumber:" title-number
title-number      = district-prefix 1*8DIGIT
district-prefix   = 1*4ALPHA

unregistered-title-urn = "unregisteredTitle:" uuid-v4
ownership-urn     = "ownership:" uuid-v4
representation-urn = "representation:" uuid-v4
consent-urn       = "consent:" uuid-v4
offer-urn         = "offer:" uuid-v4
vc-urn            = "vc:" 1*(ALPHA / DIGIT / "-")
status-urn        = "status:" 1*(ALPHA / DIGIT / "-")

uuid-v4           = 8hexdig "-" 4hexdig "-" "4" 3hexdig "-"
                    variant-char 3hexdig "-" 12hexdig
variant-char      = "8" / "9" / "a" / "b" / "A" / "B"
hexdig            = DIGIT / "a" / "b" / "c" / "d" / "e" / "f"
                  / "A" / "B" / "C" / "D" / "E" / "F"
```

## Semantics by identifier type

| URN | Semantics |
|---|---|
| `uprn` | real-world property identifier |
| `titleNumber` | real-world registered legal title identifier |
| `unregisteredTitle` | provisional PDTF title identifier |
| `ownership` | graph relationship node |
| `representation` | graph relationship node |
| `consent` | graph relationship node |
| `offer` | graph relationship node |
| `vc` | optional credential-level identifier |
| `status` | internal status resource namespace if needed |

## Design rules

- Use DIDs for actors that sign, authenticate, or host endpoints.
- Use `urn:pdtf:*` for graph subjects that do not sign.
- `Property` always uses `uprn`.
- `Title` uses `titleNumber` where registered, `unregisteredTitle` otherwise.
- Relationship entities use generated identifiers and are stable for the life of the relationship assertion.

## Migration notes

| v3 source | v4 URN form |
|---|---|
| `propertyPack.uprn` | `urn:pdtf:uprn:{uprn}` |
| `titlesToBeSold[].titleNumber` | `urn:pdtf:titleNumber:{number}` |
| existing offer key | `urn:pdtf:offer:{existing-key-or-generated-id}` |

## Examples in graph use

```json
{
  "properties": {
    "urn:pdtf:uprn:100023456789": {}
  },
  "titles": {
    "urn:pdtf:titleNumber:AB12345": {}
  },
  "ownership": {
    "urn:pdtf:ownership:own-a1b2c3": {
      "titleId": "urn:pdtf:titleNumber:AB12345"
    }
  },
  "offers": {
    "urn:pdtf:offer:off-j1k2l3": {}
  }
}
```

## Validation guidance

A validator should confirm:

1. namespace prefix is exactly `urn:pdtf:`
2. category segment is recognised
3. category-specific payload matches expected format
4. title URNs use `titleNumber` only for registered titles
5. relationship URNs are not reused across distinct graph entities
