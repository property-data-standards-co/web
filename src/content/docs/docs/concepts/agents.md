---
title: AI Agents & MCP
description: How PDTF 2.0 enables secure, agentic workflows using the Model Context Protocol and Verifiable Credentials.
---

As property professional workflows transition from manual data entry to AI-assisted and fully agentic models, the fundamental constraint is no longer software capability—it is **data trust**.

If a conveyancer's AI copilot is drafting an enquiry about a restrictive covenant, or a lender's automated underwriting engine is evaluating flood risk, the AI must be operating on cryptographically verifiable facts. Hallucinations or stale data in an agentic workflow carry severe legal and financial consequences.

PDTF 2.0 solves this by combining **Verifiable Credentials** (for absolute data trust) with the **Model Context Protocol (MCP)** (for secure, agentic data access).

---

## The Importance of Trusted Data

In a traditional workflow, a human conveyancer reads a PDF of a title register, identifies a restriction, and drafts a letter. The human is the trust anchor: they verify the source of the PDF and use their professional judgment to interpret it.

In an agentic workflow, an AI model reads the data. If that data is pulled from a standard API without cryptographic signatures, the model has no way to prove provenance. Did this EPC rating come from the government register, or was it scraped from an outdated portal? Has the leasehold length been tampered with? 

### The PDTF 2.0 Trust Guarantee

By representing every property fact as a W3C Verifiable Credential:
1. **Provenance is mathematically proven:** The AI can verify the `Ed25519` signature to know exactly who issued the credential.
2. **Authority is governed:** The AI can perform an OpenID Federation trust chain resolution to ensure the issuer is authorised to provide that specific data path.
3. **Revocation is instant:** The AI can check the Bitstring Status List to ensure the credential hasn't been revoked since issuance.

When an AI model operates on PDTF 2.0 credentials, it is operating on verified facts, drastically reducing the risk of confident but incorrect outputs.

---

## Agentic Access via MCP

While OID4VP is the standard protocol for system-to-system credential exchange, AI models (like Claude, GPT-4, or specialized local models) require a different interface to retrieve context dynamically.

PDTF 2.0 provides a standard **Model Context Protocol (MCP)** binding. MCP allows AI agents to query the property graph as naturally as they query a local database, while the MCP server handles the complexity of cryptographic verification, graph traversal, and access control.

### Real Usage in Practice: The Diligence Copilot

Consider a conveyancing firm using an AI copilot to review a transaction.

**1. Authentication:**
The human conveyancer logs into their system. The AI agent assumes their identity via a `did:key` identifier linked to the firm's `Organisation` DID.

**2. Graph Traversal as Access Control:**
The agent issues an MCP tool call to retrieve the property pack:

```json
{
  "tool": "get_transaction_state",
  "arguments": {
    "transactionDid": "did:web:moverly.com:transactions:abc123"
  }
}
```

Before returning data, the PDTF MCP server checks the graph: Does this conveyancer's DID hold a valid `Representation` credential for the seller on this transaction? If yes, access is granted. **The graph is the ACL.**

**3. State Assembly:**
The MCP server doesn't just return a raw pile of JSON-LD credentials. It runs the `@pdtf/core` `composeV4StateFromGraph` algorithm:
- It fetches the `Property`, `Title`, and `Transaction` credentials.
- It verifies their signatures and OpenID Federation trust marks.
- It resolves any conflicting claims (e.g., two different EPC ratings) based on issuance time and trust level.
- It returns a clean, fully assembled JSON object representing the canonical state of the property.

**4. Agentic Action:**
The AI model now has the verified context in its prompt. It sees a `Title` object containing the register extract, and cross-references it with the seller's responses in the `Property` object's TA6 overlay. 

The agent notices a discrepancy regarding a boundary wall, and prompts the conveyancer:
> *"The seller stated on the TA6 that they do not share responsibility for the boundary wall, but the Title register extract (verified via HMLR adapter, issued 2 hours ago) contains a covenant stating joint maintenance. Shall I draft an enquiry to the buyer's solicitor to clarify this?"*

---

## Future-Proofing the Industry

As the UK property market digitises, the distinction between a "software tool" and an "AI agent" will blur. Platforms that rely on unsecured REST APIs and proprietary data silos will struggle to adopt agentic workflows safely.

By adopting PDTF 2.0 and MCP, implementers ensure that their data is portable, cryptographically sound, and ready to be consumed by the next generation of property intelligence engines.