---
title: "Cross-Language Interoperability"
description: "How PDTF 2.0 libraries prove byte-level compatibility across TypeScript, Rust, Python, and C#."
---

PDTF 2.0 provides four language implementations that are proven to be interoperable through shared deterministic test vectors.

## The Interop Promise

A credential signed in **any** language can be verified in **any** other language. This isn't aspirational — it's tested on every commit.

| Operation | TypeScript | Rust | Python | C# |
|-----------|-----------|------|--------|-----|
| Key generation | ✅ | ✅ | ✅ | ✅ |
| `did:key` derivation | ✅ | ✅ | ✅ | ✅ |
| VC signing (eddsa-jcs-2022) | ✅ | ✅ | ✅ | ✅ |
| VC verification | ✅ | ✅ | ✅ | ✅ |
| Status list create/check | ✅ | ✅ | ✅ | ✅ |
| TIR path matching | ✅ | ✅ | ✅ | ✅ |
| DID document resolution | ✅ | ✅ | ✅ | ✅ |

---

## How It Works

### Shared Test Vectors

The TypeScript reference implementation generates `test-vectors/vectors.json` from a fixed Ed25519 seed. Every other language consumes these vectors and validates its output matches exactly.

```
@pdtf/core (TypeScript)
    │
    ├── generates test-vectors/vectors.json
    │       │
    │       ├── pdtf-core (Rust) consumes → 6 integration tests
    │       ├── pdtf-core (Python) consumes → 10 pytest tests
    │       └── Pdtf.Core (C#) consumes → 9 xUnit tests
    │
    └── self-validates → 17 vitest tests
```

### What's in the Vector File

```json
{
  "keys": {
    "seed": "ababab...",
    "publicKeyHex": "248acb...",
    "did": "did:key:z6Mk...",
    "publicKeyMultibase": "z6Mk..."
  },
  "signing": [
    {
      "name": "minimal-vc",
      "unsignedVc": { ... },
      "signedVc": { ... },
      "proofValue": "z3vv14hX..."
    }
  ],
  "verification": [
    { "name": "valid-signature", "expectedValid": true },
    { "name": "tampered-subject", "expectedValid": false },
    { "name": "wrong-key", "expectedValid": false }
  ],
  "statusList": { ... },
  "tirPathMatching": [ ... ]
}
```

### What's Proven

| Test Category | What's Compared | Pass Criteria |
|--------------|-----------------|---------------|
| **Key derivation** | `did:key` string from raw public key | Exact string match |
| **Signing** | Proof value from same unsigned VC + key + timestamp | Byte-identical Ed25519 signatures |
| **Verification** | Valid/tampered/wrong-key outcomes | Boolean match |
| **Status lists** | Decoded bit arrays from encoded bitstrings | Logical equivalence (decoded bytes identical) |
| **TIR matching** | Pattern + path → match result | Boolean match |

> **Note on gzip:** Different gzip implementations may produce different compressed byte sequences for the same data. Status list tests compare *decoded* content (logical equivalence), not raw base64 strings. This is by design — the W3C Bitstring Status List spec defines the logical format, not the compression output.

---

## Test Matrix

| Language | Framework | Tests | Status |
|----------|-----------|-------|--------|
| TypeScript | Vitest | 68 (17 vector) | ✅ Passing |
| Rust | cargo test | 84 (6 cross-lang) | ✅ Passing |
| Python | pytest | 10 | ✅ Passing |
| C# | xUnit | 9 cross-lang + 5 unit | ✅ Written (needs .NET SDK) |

**Total: 172+ tests across 4 languages.**

---

## Adding a New Language

To add PDTF support in a new language:

1. **Implement the core operations**: key generation, JCS canonicalization, SHA-256, Ed25519 signing, base58-btc encoding
2. **Download `test-vectors/vectors.json`** from the [core-rs repository](https://github.com/property-data-standards-co/core-rs/tree/main/test-vectors)
3. **Write tests that consume the vectors** — every test category must pass
4. **Submit a PR** to add your language to the interop matrix

The vector file is the contract. If your implementation produces the same outputs for the same inputs, it's compatible.

---

## Regenerating Vectors

```bash
cd core-ts
npx tsx scripts/generate-vectors.ts
# Copies to test-vectors/vectors.json

# Then copy to Rust repo
cp test-vectors/vectors.json ../core-rs/test-vectors/
```

⚠️ **Do not change the seed or timestamps** — all existing tests depend on deterministic output.
