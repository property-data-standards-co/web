---
title: Credentials
description: How PDTF 2.0 uses W3C Verifiable Credentials to wrap entity data with cryptographic proof.
---

PDTF 2.0 represents property data as **W3C Verifiable Credentials (VCs)**. Each credential is a signed, portable statement about an entity in the PDTF graph (Property, Title, Transaction, or a relationship entity).

## Why credentials

A credential carries its own cryptographic proof. A recipient can verify integrity and issuer identity without trusting the API or database that delivered the JSON.

In PDTF, signatures are necessary but not sufficient. Verifiers also consult the **OpenID Federation** (Trust Anchors, Entity Statements, and [Property Trust Marks](/trust-marks/) such as `pdtf-verified-issuer`) to confirm the issuer is authorised for the specific **entity:path** combinations being asserted.

## Sparse credentials

PDTF credentials are usually **sparse**. An EPC issuer does not re-issue a whole Property object. It issues a `PropertyCredential` containing only the `energyEfficiency` subtree.

State assembly combines many sparse credentials into a composed view, applying pruning when discriminators change so stale subtrees are removed.

## Credential types

Credential types align with the entity graph:

- `PropertyCredential` and `TitleCredential` for facts about those entities.
- Relationship credentials (`SellerCapacityCredential`, `OfferCredential`, `GiftCredential`, `RepresentationCredential`, `TransactionRoleCredential`) to express each party's role and authority.
- `TransactionCredential` for sale-specific lifecycle state.

## Access control

VCs can include `termsOfUse` to express confidentiality and role restrictions. The vocabulary is `public`, `transactionParticipants`, `roleRestricted` and `partyOnly`, with `roleRestrictions`. It is provisional and stated in [02 §7.2–7.4](/specs/02-vc-data-model/#7-terms-of-use) (consultation [Q17](/consultation/#q17-intent-based-access-control)). A third party such as a lender is tied to the transaction by its `TransactionRoleCredential`; how a scoped consent should sit on top of that is an open consultation question.

## Revocation

Every PDTF credential carries a revocation reference so verifiers can check whether it is still valid. Under the provisional SD-JWT-VC securing mechanism, this is the IETF **Token Status List** `status` claim, stated in [Sub-spec 14 §1](/specs/14-credential-revocation/#1-purpose). The W3C Bitstring Status List (`credentialStatus`) is the equivalent in the earlier Data Integrity representation, which the current libraries implement. Either way the status list is signed by its issuer.

## Where to go next

- See the protocol specs for the VC data model and revocation.
- Use `@pdtf/core` to issue and verify credentials in development.
