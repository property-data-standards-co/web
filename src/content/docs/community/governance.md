---
title: Governance
description: How the PDTF framework is governed — accreditation, conformance, change control, and dispute resolution under the UK's Smart Data model.
---

## Introduction

The UK Government's Department for Business and Trade (DBT) [Smart Data](https://www.gov.uk/government/consultations/smart-data-putting-consumers-in-control-of-their-data-and-enabling-innovation) programme establishes a federated model for sector-specific data sharing. Each sector designates an **Implementation Entity** responsible for trust infrastructure, accreditation, and conformance within its domain.

PDTF 2.0 is designed as the property sector's Implementation Entity. It provides the technical trust architecture — identity federation, credential issuance, accreditation, and conformance testing — that enables regulated data sharing across the residential property transaction ecosystem.

This governance framework describes how that architecture is operated, how participants are accredited, how software is tested, how standards evolve, and how bad actors are removed.

## The Federated Smart Data Model

The Smart Data model is federated: each sector operates its own trust infrastructure while conforming to cross-sector principles set by a future **Smart Data Coordination Entity (SDCE)**.

PDTF 2.0 implements this through a **Trust Anchor** at `trust.pdtf.org`. The Trust Anchor is the root of an [OpenID Federation](https://openid.net/specs/openid-federation-1_0.html) hierarchy that:

- Publishes the federation's entity configuration and signing keys
- Issues Trust Marks to accredited participants
- Maintains the trust chain from which all participant credentials derive authority

HM Land Registry is identified in the Smart Data analysis as the likely **lead regulator** for the property sector. As the regulatory landscape matures, the Trust Anchor's policies and accreditation criteria will align with HMLR's regulatory requirements, and `trust.pdtf.org` will integrate with whatever cross-sector coordination the SDCE establishes.

This means PDTF is not a closed ecosystem. It is one node in a wider government-endorsed data-sharing architecture, with a clear path to interoperability with other Smart Data sectors (energy, finance, telecoms) as they come online.

## Accreditation (Trust Marks)

Firms participating in the PDTF ecosystem — conveyancers, search providers, lenders, surveyor platforms — must be **accredited** as Authorised Third-party Providers (ATPs).

Accreditation is implemented through **OpenID Federation Trust Marks**. A Trust Mark is a signed credential issued by the Trust Anchor that attests a participant meets the framework's requirements. Trust Marks _are_ the technical implementation of ATP accreditation — there is no separate administrative process.

To receive a Trust Mark, a participant must:

1. **Register** as a Subordinate Entity under the Trust Anchor's federation hierarchy.
2. **Pass conformance testing** against the relevant sub-specifications (see below).
3. **Demonstrate regulatory standing** — e.g. SRA/CLC registration for conveyancers, appropriate FCA authorisation for lenders.
4. **Maintain compliance** — Trust Marks are time-limited and subject to renewal and revocation.

Trust Marks are machine-readable. Any participant in the federation can verify another participant's accreditation status in real time by resolving their Trust Mark against the Trust Anchor.

## Conformance & Compliance

Software that implements PDTF protocols must pass conformance testing before its operator can be accredited.

**Sub-spec 15: Conformance Test Suite** defines the testing framework:

- **Credential issuance tests** — verifying that Verifiable Credentials are correctly structured, signed, and include required claims.
- **Trust chain resolution tests** — confirming that entity statements, subordinate statements, and Trust Marks resolve correctly through the federation hierarchy.
- **Schema validation tests** — ensuring property data payloads conform to PDTF schema definitions.
- **Interoperability tests** — verifying that credentials issued by one participant can be verified and consumed by another.

Conformance is not a one-time gate. The test suite is versioned alongside the specifications, and participants must re-certify when breaking changes are introduced.

## Change Control & Standards

PDTF specifications and schemas are developed in the open on GitHub under the [`property-data-standards-co`](https://github.com/property-data-standards-co) organisation.

### How changes are made

1. **Issue** — raise an issue describing the problem or proposal.
2. **Pull request** — open a PR with the smallest coherent change.
3. **Review** — review focuses on interoperability, clarity, and backwards compatibility.
4. **Merge** — update spec text and examples so implementers are not guessing.

### Industry consultation

Material changes to trust architecture, credential formats, or accreditation requirements are subject to industry consultation. This includes:

- Changes to the Trust Anchor's federation policies
- New or modified Trust Mark definitions
- Breaking changes to credential schemas
- Changes to conformance test requirements

Consultation is conducted through GitHub discussions, with a minimum comment period before adoption.

### Versioning

Specifications are versioned. Breaking changes are rare and explicitly called out with migration guidance. Schemas follow semantic versioning and are published to npm as `@pdtf/schemas`.

## Dispute Resolution & Revocation

Trust requires the ability to remove bad actors quickly and transparently.

### Credential revocation

All Verifiable Credentials issued within the PDTF ecosystem include a `credentialStatus` field referencing a **Bitstring Status List** (W3C). This allows any verifier to check whether a specific credential has been revoked without contacting the issuer directly.

Revocation is immediate and cryptographically verifiable.

### Trust Mark revocation

If an accredited participant breaches the framework's requirements — through non-compliance, regulatory action, or misconduct — their Trust Mark is revoked at the Trust Anchor. This:

- Immediately removes their ATP status from the federation
- Causes all real-time Trust Mark verification checks to fail
- Is logged with a rationale and timestamp for audit purposes

### Dispute process

1. **Report** — any participant can raise a concern via the governance issue tracker.
2. **Investigation** — the framework operator reviews the complaint against accreditation criteria and conformance requirements.
3. **Action** — outcomes range from remediation plans to immediate Trust Mark revocation, depending on severity.
4. **Appeal** — revoked participants may appeal through a documented review process.

Emergency removals (e.g. fraud, data breach) bypass the standard timeline and take effect immediately, with documentation following.
