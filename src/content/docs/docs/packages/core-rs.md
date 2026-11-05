---
title: "pdtf-core (Rust)"
description: "Rust implementation of PDTF 2.0 core — keys, signing, verification, DIDs, status lists, legacy TIR. With Python and C# bindings."
---

Native Rust implementation of the PDTF 2.0 core library. Designed for performance-critical workloads and as the foundation for cross-language bindings.

:::note[Implementation state]
This library implements the Data Integrity representation (`DataIntegrityProof`, `eddsa-jcs-2022`) and the W3C Bitstring Status List only. That is the current implementation state, not the spec's answer: the provisional securing mechanism is SD-JWT-VC with Token Status List ([02 §2.4](/specs/02-vc-data-model/#24-securing-mechanism), [14 §1](/specs/14-credential-revocation/#1-purpose), consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)).
:::

```toml
[dependencies]
pdtf-core = { git = "https://github.com/property-data-standards-co/core-rs" }
```

**Repository:** [property-data-standards-co/core-rs](https://github.com/property-data-standards-co/core-rs)

---

## Architecture

```
core-rs/
├── crates/pdtf-core/      # Core Rust library
│   ├── src/
│   │   ├── keys/           # Ed25519 key generation, did:key encoding
│   │   ├── signer/         # DataIntegrityProof creation (eddsa-jcs-2022)
│   │   ├── validator/      # Proof verification
│   │   ├── did/            # DID resolution (did:key, did:web, URN)
│   │   ├── status/         # Bitstring Status List
│   │   └── tir/            # Trusted Issuer Registry client (legacy)
│   └── tests/
│       └── cross_language.rs   # Shared vector validation
├── bindings/
│   ├── python/             # PyO3 bindings
│   ├── dotnet-ffi/         # C-ABI FFI layer
│   └── dotnet/             # C# wrapper + tests
└── test-vectors/
    └── vectors.json        # Shared cross-language test vectors
```

---

## Modules

### keys::ed25519

Ed25519 key generation, `did:key` derivation, and multibase encoding.

```rust
use pdtf_core::keys::ed25519::{generate_keypair, derive_did_key, public_key_to_multibase};

let kp = generate_keypair();
let did = derive_did_key(kp.verifying_key.as_bytes())?;
// did:key:z6Mk...

let multibase = public_key_to_multibase(kp.verifying_key.as_bytes())?;
// z6Mk...

// Round-trip
let recovered = did_key_to_public_key(&did)?;
assert_eq!(recovered.as_slice(), kp.verifying_key.as_bytes());
```

### signer::proof

Create and verify `DataIntegrityProof` using `eddsa-jcs-2022`.

```rust
use pdtf_core::signer::proof::{create_proof, verify_proof, CreateProofOptions};

// Sign
let proof = create_proof(CreateProofOptions {
    document: &vc,
    key_id: "my-key",
    verification_method: "did:key:z6Mk...#z6Mk...",
    key_provider: &my_key_provider,
    created: None, // defaults to now
}).await?;

// Verify
let valid = verify_proof(&signed_vc, &public_key_bytes);
```

**Algorithm** (identical to TypeScript):
1. JCS-canonicalize proof options → SHA-256
2. JCS-canonicalize document (no proof) → SHA-256
3. Concatenate hashes (64 bytes)
4. Ed25519 sign (raw bytes)
5. base58-btc encode with `z` prefix

### did

DID resolution for `did:key`, `did:web`, and `urn:pdtf:*`.

```rust
use pdtf_core::did::resolver::resolve;

let doc = resolve("did:key:z6Mk...").await?;
let doc = resolve("did:web:example.com:transactions:abc123").await?;
```

### status::bitstring

Bitstring Status List — create, encode (gzip+base64), decode, and check bits.

```rust
use pdtf_core::status::bitstring::*;

let mut list = create_status_list(131_072)?;
set_bit(&mut list, 42)?;

let encoded = encode_status_list(&list)?;  // base64(gzip(bytes))
let decoded = decode_status_list(&encoded)?;
assert!(get_bit(&decoded, 42)?);
```

### tir

Trusted Issuer Registry — load, validate issuer entries, path matching.

:::caution[Legacy]
PDTF 2.0 replaced the Trusted Issuer Registry with OpenID Federation ([04 §1.1](/specs/04-openid-federation/#11-why-openid-federation)). This module predates that change and is kept for backward compatibility and entity:path matching only; do not use it for trust decisions. Resolve trust with `FederationRegistryResolver` and the Trust Anchor `https://propdata.org.uk` (see [Verify Trust](/docs/guides/integrate-federation/)). Its trust-level strings may predate the canonical snake_case levels `root_issuer`, `trusted_proxy`, `account_provider` and `assertion` ([04 §8](/specs/04-openid-federation/#8-trust-levels)).
:::

```rust
use pdtf_core::tir::verify::verify_tir;
use pdtf_core::tir::path_match::path_matches;

// Path matching
assert!(path_matches("Property:/energyEfficiency/*", "Property:/energyEfficiency/certificate"));
assert!(!path_matches("Property:*", "Title:/registerExtract/entries"));

// Full TIR verification
let result = verify_tir(&registry, "did:key:z6Mk...", &["Property:/energyEfficiency/certificate"]);
assert!(result.trusted);
```

---

## Tests

84 tests across the workspace:

| Crate | Tests | Coverage |
|-------|-------|----------|
| pdtf-core (unit) | 67 | Keys, signing, verification, DID, status, TIR, structure validation |
| pdtf-core (integration) | 6 | Cross-language vector validation against TypeScript |
| dotnet-ffi | 8 | FFI function correctness, error handling |
| doc-tests | 3 | Inline documentation examples |

```bash
cargo test --workspace
```

---

## Cross-Language Interop

The Rust tests consume `test-vectors/vectors.json` generated by the TypeScript reference implementation using a fixed Ed25519 seed. This proves byte-level interoperability:

| Test | What's proven |
|------|---------------|
| `crosslang_key_derivation` | Identical `did:key` and multibase encoding |
| `crosslang_signing_produces_identical_proofs` | Same JCS + SHA-256 + Ed25519 = identical proof values |
| `crosslang_verification` | Rust verifies TypeScript-signed VCs (valid, tampered, wrong key) |
| `crosslang_status_list_empty_roundtrip` | Decoded status lists are byte-identical |
| `crosslang_status_list_operations` | Set/check operations produce same results |
| `crosslang_tir_path_matching` | Wildcard pattern matching is consistent |

> **Note:** Gzip implementations may produce different compressed byte sequences, so status list tests compare decoded (logical) content rather than raw base64 strings.
