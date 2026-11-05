---
title: "pdtf-core (Python)"
description: "Python bindings for PDTF 2.0 core via PyO3 — keys, signing, verification, DIDs, status lists, legacy TIR."
---

Python bindings for the PDTF 2.0 core library, built via [PyO3](https://pyo3.rs/) from the Rust implementation. Provides native performance with a Pythonic API.

:::note[Implementation state]
This library implements the Data Integrity representation (`DataIntegrityProof`, `eddsa-jcs-2022`) and the W3C Bitstring Status List only. That is the current implementation state, not the spec's answer: the provisional securing mechanism is SD-JWT-VC with Token Status List ([02 §2.4](/specs/02-vc-data-model/#24-securing-mechanism), [14 §1](/specs/14-credential-revocation/#1-purpose), consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)).
:::

```bash
pip install pdtf-core
```

**Repository:** [property-data-standards-co/core-rs](https://github.com/property-data-standards-co/core-rs) (`bindings/python/`)

---

## Quick Start

```python
import json
import pdtf_core

# Generate an Ed25519 keypair
kp = pdtf_core.generate_keypair()
print(kp['did'])  # did:key:z6Mk...

# Create and sign a Verifiable Credential
vc = {
    "@context": [
        "https://www.w3.org/ns/credentials/v2",
        "https://propdata.org.uk/credentials/v2"
    ],
    "type": ["VerifiableCredential", "PropertyDataCredential"],
    "id": "urn:uuid:example-001",
    "issuer": kp['did'],
    "validFrom": "2026-01-01T00:00:00Z",
    "credentialSubject": {
        "id": "urn:pdtf:uprn:100023336956",
        "energyEfficiency": {"rating": "B", "score": 85}
    }
}

signed_json = pdtf_core.sign_vc(json.dumps(vc), kp['secret_key_hex'])
signed = json.loads(signed_json)
print(signed['proof']['proofValue'])  # z3FRRbp...

# Verify
assert pdtf_core.verify_proof_py(signed_json, kp['public_key_hex']) is True
```

---

## API Reference

### `generate_keypair() → dict`

Generate an Ed25519 keypair with a derived `did:key` identifier.

**Returns:**
```python
{
    "did": "did:key:z6Mk...",
    "public_key_hex": "248a...",   # 32 bytes hex-encoded
    "secret_key_hex": "abab..."    # 32 bytes hex-encoded
}
```

### `sign_vc(vc_json: str, secret_key_hex: str) → str`

Sign a Verifiable Credential using `eddsa-jcs-2022`.

- `vc_json` — JSON string of the unsigned VC
- `secret_key_hex` — 64-character hex-encoded Ed25519 secret key

**Returns:** JSON string of the signed VC with a `DataIntegrityProof`.

**Raises:** `ValueError` if the JSON is invalid or key is malformed.

### `verify_proof_py(vc_json: str, public_key_hex: str) → bool`

Verify a `DataIntegrityProof` on a VC.

- `vc_json` — JSON string of the signed VC (must include `proof`)
- `public_key_hex` — 64-character hex-encoded Ed25519 public key

**Returns:** `True` if the signature is valid, `False` otherwise.

### `resolve_did_key(did: str) → str`

Resolve a `did:key` identifier to its DID Document.

```python
doc = json.loads(pdtf_core.resolve_did_key("did:key:z6Mk..."))
print(doc['verificationMethod'][0]['publicKeyMultibase'])
```

**Returns:** JSON string of the DID Document.

### `create_status_list(size: int) → str`

Create an empty Bitstring Status List.

- `size` — Number of bits (minimum 131,072 per W3C spec)

**Returns:** base64-encoded gzip bitstring.

### `check_status(bitstring_b64: str, index: int) → bool`

Check if a bit is set in a status list.

- `bitstring_b64` — base64-encoded gzip bitstring
- `index` — Bit index to check

**Returns:** `True` if the bit is set (credential revoked), `False` otherwise.

### `check_tir(registry_json: str, issuer_did: str, paths: list[str]) → str`

Check Trusted Issuer Registry authorisation.

:::caution[Legacy]
PDTF 2.0 replaced the Trusted Issuer Registry with OpenID Federation ([04 §1.1](/specs/04-openid-federation/#11-why-openid-federation)). This module predates that change and is kept for backward compatibility and entity:path matching only; do not use it for trust decisions. Resolve trust with `FederationRegistryResolver` and the Trust Anchor `https://propdata.org.uk` (see [Verify Trust](/docs/guides/integrate-federation/)). Its trust-level strings may predate the canonical snake_case levels `root_issuer`, `trusted_proxy`, `account_provider` and `assertion` ([04 §8](/specs/04-openid-federation/#8-trust-levels)).
:::

```python
result = json.loads(pdtf_core.check_tir(
    json.dumps(registry),
    "did:key:z6Mk...",
    ["Property:/energyEfficiency/certificate"]
))
print(result['trusted'])  # True/False
```

**Returns:** JSON string with verification result including `trusted`, `issuer_slug`, `trust_level`, `paths_covered`, `uncovered_paths`, and `warnings`.

---

## Building from Source

Requires Rust toolchain and [maturin](https://github.com/PyO3/maturin):

```bash
cd core-rs/bindings/python
python -m venv .venv && source .venv/bin/activate
pip install maturin
maturin develop        # Dev build (editable install)
maturin build --release  # Release wheel
```

---

## Tests

10 end-to-end tests consuming shared cross-language test vectors:

| Test Class | Tests | Coverage |
|------------|-------|----------|
| TestKeyDerivation | 2 | Format validation, DID document resolution |
| TestSigningAndVerification | 4 | Roundtrip, TS vector verification, tamper detection, wrong key |
| TestStatusList | 2 | Empty list, TS bitstring decode |
| TestTirPathMatching | 1 | All vector patterns via `check_tir` |
| TestEndToEnd | 1 | Full lifecycle: generate → sign → verify → tamper → reject |

```bash
cd core-rs
pip install pytest
pytest bindings/python/tests/ -v
```
