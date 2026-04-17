---
title: Authentication & Exchange
description: How Verifiable Credentials are exchanged securely using OID4VP, OID4VCI, and the Model Context Protocol (MCP).
---

PDTF 2.0 shifts property data from proprietary API silos into portable Verifiable Credentials. Once these credentials exist, relying parties (like lenders, conveyancers, and property portals) need a standardised, secure mechanism to request and receive them.

This architecture uses the OpenID Foundation's credential exchange standards alongside the Model Context Protocol (MCP) to provide both programmatic and agentic data access.

## The Exchange Protocols

PDTF 2.0 mandates standard protocols rather than inventing a bespoke property API:

| Protocol | Purpose | Direction |
|----------|---------|-----------|
| **OID4VCI** | OpenID for Verifiable Credential Issuance | **Push:** A primary source or adapter issues a credential to an entity's wallet. |
| **OID4VP** | OpenID for Verifiable Presentations | **Pull:** A relying party requests specific credentials from an entity's wallet. |
| **MCP** | Model Context Protocol | **Agentic:** AI agents securely query a platform's aggregated property graph. |

---

## 1. Verifiable Presentations (OID4VP)

When a relying party needs property data, they do not make a traditional REST API `GET` request. Instead, they request a **Verifiable Presentation** using OID4VP.

### How it works

1. **Presentation Definition:** The relying party creates a Presentation Definition (using the W3C Presentation Exchange spec) declaring exactly what they need.
   *Example: "I need a `TitleCredential` and an `EnergyPerformanceCertificateCredential` for `urn:pdtf:title:ABC12345`."*
2. **Authorisation Request:** The relying party sends this request to the holder (e.g., the seller's conveyancer or a data hub like NPTN).
3. **Presentation Evaluation:** The holder checks if they possess the requested credentials.
4. **Access Control (The Graph):** The holder checks if the relying party is authorised to receive them. In PDTF 2.0, this is evaluated by traversing the entity graph. Does the relying party hold a `DelegatedConsent` or `Representation` credential that authorises this access?
5. **Presentation Submission:** The holder packages the requested credentials into a Verifiable Presentation, signs it with their own DID, and returns it.

### Example: A Lender Requesting Property Data

A mortgage lender needs the property pack to issue a mortgage offer.

1. **The Request:** The lender sends an OID4VP request to the Estate Agent's platform.
2. **The Capability Token:** Alongside their request, the lender presents a `DelegatedConsent` credential they received from the buyer.
3. **Graph Traversal (Validation):** The Estate Agent's platform verifies the `DelegatedConsent`. It checks the graph:
   - Does this `DelegatedConsent` belong to the buyer?
   - Does the buyer hold an accepted `Offer` on this `Transaction`?
4. **Fulfillment:** Since the graph proves the lender's right to access, the agent's platform packages the `Property` and `Title` credentials into a Verifiable Presentation and returns them to the lender.

The lender has received cryptographically verifiable data straight from the primary sources, without the agent needing a bespoke API integration with the lender.

---

## 2. Multi-Hub Sync and Encrypted Pools

In reality, property data isn't held by a single party. It is aggregated across multiple hubs (the agent's CRM, the conveyancer's CMS, a data hub like LMS).

To prevent fragmented data silos, PDTF 2.0 supports **Encrypted VC Replication**.

When a Transaction is initiated, the participating platforms form a synchronization ring. 
1. As new credentials are issued (e.g., a local authority search arrives), they are added to a VC pool.
2. The credentials are encrypted using the `X25519KeyAgreementKey2020` public keys of the authorised participants (discovered via their `did:web` or `did:key` DID documents).
3. These encrypted envelopes are synced across the participating hubs.

This ensures all parties have a real-time, identical view of the transaction state, while GDPR and confidentiality are enforced mathematically via encryption, rather than relying on API gatekeepers.

---

## 3. The Model Context Protocol (MCP)

While OID4VP is the standard for system-to-system exchange, the rise of AI agents requires a different interface. PDTF 2.0 provides an MCP binding for agentic access to the property graph.

MCP allows AI agents (like a conveyancer's copilot or a diligence engine) to query the aggregated state of a transaction securely.

### The MCP Interface

The PDTF MCP server exposes tools that map directly to the entity graph:

- `get_credentials(id)`: Returns the traversed bundle of raw Verifiable Credentials for a given URN/DID based on the caller's authorised scope.
- `get_state(id)`: Recomposes the full v3-style property pack or v4 entity map by traversing the graph and assembling the retrieved credentials.
- `issue_credential(payload, type)`: Issues a new VC (e.g., vouching for data, uploading a document) signed by the agent/user's DID.
- `verify_credential(vc)`: Cryptographically verifies a VC against its signature and OpenID Federation Trust Marks.

### Agentic Access Control

When an AI agent connects to a PDTF MCP server, it authenticates using the identity of its human operator. The MCP server evaluates access by performing the exact same graph traversal as OID4VP:

1. Agent authenticates as `did:key:conveyancer_123`.
2. Agent requests `get_state("did:web:...abc")`.
3. Server checks: Does `did:key:conveyancer_123` hold a valid `Representation` credential for the seller on this transaction?
4. If yes, the server traverses the graph, decrypts the VC pool, and returns the aggregated JSON context to the agent.

This unified access model means whether data is being pulled by a legacy API gateway, requested via OID4VP by a lender, or queried by an AI agent via MCP, the authorisation logic is identical: **the graph is the ACL.**