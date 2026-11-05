---
title: Trust Architecture
description: How trust is established, verified, and evolved in PDTF 2.0.
---

PDTF 2.0 uses a federated trust model where the unit of trust is a **credential**, not the platform that served it.

A verifier answers three questions:

1. **Identity:** Who issued this credential? (DID resolution)
2. **Integrity:** Was it altered? (signature verification)
3. **Authority:** Is the issuer allowed to make this claim? (OpenID Federation authorisation: Trust Anchors, Entity Statements, and [Property Trust Marks](/trust-marks/) such as `pdtf-verified-issuer` and `regulated-conveyancer`)

## Signatures are not enough

Anyone can create a DID and sign JSON. A valid signature proves *who* signed, not whether they are authoritative.

Authority is established via the **OpenID Federation**, which grants trust at **entity:path** scope.

## Trust roles

PDTF recognises four trust levels. The taxonomy is defined in [Sub-spec 04 §8](/specs/04-openid-federation/#8-trust-levels):

- `root_issuer`: the primary authoritative source
- `trusted_proxy`: an adapter that issues faithfully from a primary source
- `account_provider`: a platform trusted to issue or manage user identities
- `assertion`: a human stating something as true, recorded against their verified identity

The first three are **issuer** levels, recorded in the federation as `delegation.trust_level` on the issuer's trust mark. `assertion` is a **credential** level. It is read from the credential's `UserAttestation` evidence, not from the federation. When the levels conflict on the same path, the order is `root_issuer` > `trusted_proxy` > `account_provider` > `assertion` ([07 §7.2](/specs/07-state-assembly/#72-trust-level-ordering)).

An assertion is the only level that is not independent confirmation. It is the right level for the large class of facts that no registry holds and only the occupier knows (the TA6 property information form is the canonical case). Its value comes from the binding: the statement is traceable to an identified individual and the liability that attaches to them, which a physically signed form is not. Credentials at this level carry `UserAttestation` evidence so that verifiers never mistake them for registry data. Under the current working assumption, the person's account provider issues them and names the person in the evidence ([02 §3.2.1](/specs/02-vc-data-model/), consultation [Q4](/consultation/#q4-the-consumer-wallet-gap)).

## Three-phase evolution

PDTF expects trust to evolve:

1. Trusted proxies bootstrap the ecosystem.
2. More independently hosted adapters reduce centralisation.
3. Primary sources issue credentials directly when feasible.

The OpenID Federation is the mechanism that expresses this evolution over time.

## Visibility and conflicts

PDTF does not mandate a single conflict resolution policy across the ecosystem. It provides:

- clear issuer identity
- explicit authority scopes
- revocation checks

Consumers (lenders, conveyancers, agents) can choose how to surface or resolve conflicts.

## Where to go next

- Read the OpenID Federation spec for governance and caching rules.
- Read the VC data model and revocation specs for verification requirements.
