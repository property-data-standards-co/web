---
title: "Pdtf.Core (.NET)"
description: "C#/.NET bindings for PDTF 2.0 core via Rust FFI — keys, signing, verification, DIDs, status lists, legacy TIR."
---

C#/.NET wrapper for the PDTF 2.0 core library, calling into the Rust implementation via C-ABI FFI. Provides a type-safe .NET API for all core operations.

:::note[Implementation state]
This library implements the Data Integrity representation (`DataIntegrityProof`, `eddsa-jcs-2022`) and the W3C Bitstring Status List only. That is the current implementation state, not the spec's answer: the provisional securing mechanism is SD-JWT-VC with Token Status List ([02 §2.4](/specs/02-vc-data-model/#24-securing-mechanism), [14 §1](/specs/14-credential-revocation/#1-purpose), consultation [Q20](/consultation/#q20-credential-format--securing-mechanism)).
:::

```bash
# Coming soon to NuGet
dotnet add package Pdtf.Core
```

**Repository:** [property-data-standards-co/core-rs](https://github.com/property-data-standards-co/core-rs) (`bindings/dotnet/` and `bindings/dotnet-ffi/`)

---

## Quick Start

```csharp
using Pdtf.Core;
using System.Text.Json;

// Generate an Ed25519 keypair
var kp = PdtfCore.GenerateKeyPair();
Console.WriteLine(kp.Did);  // did:key:z6Mk...

// Create a VC
var vc = JsonSerializer.Serialize(new {
    context = new[] {
        "https://www.w3.org/ns/credentials/v2",
        "https://propdata.org.uk/credentials/v2"
    },
    type = new[] { "VerifiableCredential", "PropertyDataCredential" },
    id = "urn:uuid:example-001",
    issuer = kp.Did,
    validFrom = "2026-01-01T00:00:00Z",
    credentialSubject = new {
        id = "urn:pdtf:uprn:100023336956",
        energyEfficiency = new { rating = "B", score = 85 }
    }
});

// Sign and verify
var signedJson = PdtfCore.SignCredential(vc, kp.SecretKeyHex);
var valid = PdtfCore.VerifyProof(signedJson, kp.PublicKeyHex);
Console.WriteLine($"Valid: {valid}");  // Valid: True
```

---

## API Reference

### `PdtfCore.GenerateKeyPair() → KeyPair`

Generate an Ed25519 keypair.

```csharp
public sealed class KeyPair
{
    public string Did { get; set; }           // did:key:z6Mk...
    public string PublicKeyHex { get; set; }   // 64-char hex
    public string SecretKeyHex { get; set; }   // 64-char hex
}
```

### `PdtfCore.SignCredential(vcJson, secretKeyHex) → string`

Sign a VC with `eddsa-jcs-2022`. Returns the signed VC as JSON.

**Throws:** `PdtfException` on invalid input.

### `PdtfCore.VerifyProof(vcJson, publicKeyHex) → bool`

Verify a `DataIntegrityProof`. Returns `true` if valid.

### `PdtfCore.ResolveDidKey(did) → string`

Resolve a `did:key` to its DID Document (JSON string).

### `PdtfCore.CheckTir(registryJson, issuerDid, paths) → TirVerificationResult`

Check Trusted Issuer Registry authorisation.

:::caution[Legacy]
PDTF 2.0 replaced the Trusted Issuer Registry with OpenID Federation ([04 §1.1](/specs/04-openid-federation/#11-why-openid-federation)). This module predates that change and is kept for backward compatibility and entity:path matching only; do not use it for trust decisions. Resolve trust with `FederationRegistryResolver` and the Trust Anchor `https://propdata.org.uk` (see [Verify Trust](/docs/guides/integrate-federation/)). Its trust-level strings may predate the canonical snake_case levels `root_issuer`, `trusted_proxy`, `account_provider` and `assertion` ([04 §8](/specs/04-openid-federation/#8-trust-levels)).
:::

```csharp
public sealed class TirVerificationResult
{
    public bool Trusted { get; set; }
    public string? IssuerSlug { get; set; }
    public string? TrustLevel { get; set; }
    public string? Status { get; set; }
    public List<string> PathsCovered { get; set; }
    public List<string> UncoveredPaths { get; set; }
    public List<string> Warnings { get; set; }
}
```

### `PdtfCore.CreateStatusList(size) → string`

Create an empty status list bitstring (base64 gzip).

### `PdtfCore.CheckStatus(bitstringBase64, index) → bool`

Check if a credential is revoked.

---

## Architecture

The .NET bindings use a two-layer design:

```
C# Application
    ↓
Pdtf.Core (C# wrapper)      ← Type-safe API, model classes, error handling
    ↓ P/Invoke
dotnet-ffi (Rust cdylib)     ← C-ABI functions, catch_unwind, thread-local errors
    ↓
pdtf-core (Rust lib)         ← Core cryptographic implementation
```

**FFI Safety:**
- All Rust FFI functions use `catch_unwind` to prevent panics crossing the FFI boundary
- Thread-local error storage for detailed error messages
- Null pointer handling on all string parameters
- Caller-owned strings freed via `pdtf_free_string`

### Platform Support

| Platform | Architecture | Status |
|----------|-------------|--------|
| Linux | x64 | ✅ Tested |
| macOS | x64 / ARM64 | ✅ Builds |
| Windows | x64 | ✅ Builds |

Requires the native `pdtf_dotnet_ffi` shared library (`libpdtf_dotnet_ffi.so` / `.dylib` / `.dll`) in the application's library search path.

---

## Building from Source

```bash
# Build the Rust FFI library
cd core-rs/bindings/dotnet-ffi
cargo build --release

# Build the C# wrapper
cd ../dotnet/Pdtf.Core
dotnet build

# Run tests
cd ../Pdtf.Core.Tests
dotnet test
```

---

## Tests

19 tests across FFI and C# layers:

| Layer | Tests | Coverage |
|-------|-------|----------|
| Rust FFI (`dotnet-ffi`) | 8 | Function correctness, error handling, null safety |
| C# xUnit (existing) | 5 | KeyTests, DidTests, SignerTests, StatusListTests, TirTests |
| C# xUnit (cross-language) | 9 | TS vector verification, full lifecycle, tamper detection |

> **Note:** C# tests require .NET 8.0 SDK and the compiled native library.

```bash
dotnet test bindings/dotnet/Pdtf.Core.Tests/
```
