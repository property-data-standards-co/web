---
title: Migration from v1
description: How to migrate from PDTF v1 to PDTF 2.0 — backward compatibility, state assembly, and phased adoption.
---

PDTF 2.0 is designed to be adoptable incrementally. Platforms can start issuing and verifying Verifiable Credentials while still serving legacy consumers a familiar combined document.

## The migration pattern

1. **Start issuing VCs** for selected paths (for example EPC data as a `PropertyCredential`).
2. **Assemble state** from credentials into the v4 entity graph.
3. **Downgrade** the v4 graph back into the legacy v3-style combined shape for systems that have not migrated.
4. Expand credential coverage until the credential-native representation becomes the default.

## Parallel running

During transition, expect parallel flows:

- v1/v3 style inputs (forms and integrations)
- adapter-issued credentials (trusted proxies)
- seller attestations (user-supplied or platform mediated)

The assembly layer merges and prunes, then produces consistent outputs.

## Trust migration

In early phases, many credentials will be issued by trusted proxy adapters. Over time, more primary sources can issue credentials directly, and the OpenID Federation trust marks evolve to reflect that.

## What changes for consumers

Legacy consumers can continue to request a combined JSON document.

Credential-native consumers can instead:

- fetch the minimal set of credentials they need
- verify them independently
- apply their own business rules on top of verified facts

## Where to go next

- See the *State Assembly* spec for merge and pruning rules.
- See the *OpenID Federation* spec for authorisation and governance.
