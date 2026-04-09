---
title: Governance
description: How the PDTF specification is governed, reviewed, and evolved.
---

PDTF 2.0 is developed in the open. Governance is intentionally lightweight: proposals are discussed publicly, decisions are recorded in specs, and changes are traceable through Git history.

## Sources of truth

- **Specs** define protocol requirements, terminology, and examples.
- **Changelogs** in each spec record semantic changes.
- **Reference implementations** provide executable behaviour and test vectors.

## How changes are made

1. Raise an issue describing the problem or proposal.
2. Open a pull request with the smallest coherent change.
3. Review focuses on interoperability, clarity, and backwards compatibility.
4. Merge, then update spec text and examples so implementers are not guessing.

## Stability and versioning

Specs are versioned. Breaking changes should be rare and explicitly called out with migration guidance.

## Trusted Issuer Registry governance

The Trusted Issuer Registry is trust infrastructure. Changes are proposed via PRs and validated in CI (schema checks, DID formats, authorised path patterns). Emergency removals should be fast and explicit, followed by documentation of rationale.
