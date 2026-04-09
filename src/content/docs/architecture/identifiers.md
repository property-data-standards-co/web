---
title: Identifiers
description: DID methods and URN schemes used to identify entities in the PDTF 2.0 graph.
---

PDTF 2.0 uses two identifier families:

- **DIDs** for actors that sign or act (people, organisations, transactions, adapters).
- **URNs** for subjects that are talked about (UPRNs, title numbers, relationship entities, and credential IDs).

This split makes it clear which identifiers must resolve to keys and endpoints, and which are stable subject references.

## DIDs (actors)

PDTF uses:

- `did:key` for **persons** (simple, no hosting).
- `did:key` or `did:web` for **organisations** (provider-managed vs self-hosted).
- `did:web` for **transactions** and most **public services**, because they need discoverable HTTPS endpoints.

A DID’s DID document binds signatures to keys. In practice, verifiers check that the `proof.verificationMethod` is present under `assertionMethod`.

## URNs (subjects)

PDTF uses `urn:pdtf:*` identifiers for the entity graph and credentials, for example:

- `urn:pdtf:uprn:{uprn}` for properties
- `urn:pdtf:titleNumber:{number}` for registered titles
- `urn:pdtf:unregisteredTitle:{id}` for unregistered titles
- `urn:pdtf:ownership:{id}` / `urn:pdtf:representation:{id}` / `urn:pdtf:consent:{id}` / `urn:pdtf:offer:{id}` for relationship entities
- `urn:pdtf:vc:{uuid}` for credential IDs (when present)

URNs identify the subject of a claim. They do not resolve to DID documents.

## Why this matters

- Verifiers can distinguish *who is speaking* (DID) from *what they are speaking about* (URN).
- Credentials remain meaningful even when delivered out-of-band.
- Relationship entities become first-class objects with clean revocation semantics.

## Where to go next

- See the DID methods spec for `did:key` and `did:web` rules.
- See the URN scheme reference for exact formats and validation guidance.
