---
title: "Verify a Credential"
description: "Step-by-step guide to verifying a PDTF Verifiable Credential"
---

PDTF credential verification has four jobs: validate the VC structure, verify the Data Integrity proof, confirm the issuer is trusted for the claimed paths, and check the credential has not been revoked.

In `@pdtf/core`, the easiest way to do that is `VcValidator`. It combines DID resolution, proof verification, TIR lookup, and Bitstring Status List checking in one pipeline.

## 1. Install and initialise

```bash
npm install @pdtf/core
```

```ts
import { DidResolver, TirClient, VcValidator, type VerifiableCredential } from '@pdtf/core';

const didResolver = new DidResolver({
  defaultTtlMs: 60 * 60 * 1000,
});

const tirClient = new TirClient({
  registryUrl: 'https://tir.platform.example.com/v1/registry',
});

const validator = new VcValidator();
```

`DidResolver` resolves `did:key` locally and `did:web` over HTTPS. `TirClient` loads the Trusted Issuer Registry and caches it. `VcValidator` orchestrates the checks.

## 2. Supply the credential paths

TIR authorisation is path-based, not issuer-wide. That means you should tell the validator which PDTF entity paths the credential is asserting.

For an EPC credential, that might be:

```ts
const credentialPaths = [
  'Property:/energyEfficiency/*',
];
```

If you skip `credentialPaths`, the validator can still check structure, signature, and revocation, but it cannot confirm the issuer is authorised for the data being claimed.

## 3. Validate the credential

```ts
const vc: VerifiableCredential = await loadCredentialSomehow();

const result = await validator.validate(vc, {
  didResolver,
  tirClient,
  credentialPaths,
});

if (!result.valid) {
  console.error(result.stages);
  throw new Error('Credential failed validation');
}

console.log('Credential is valid');
console.log(result.stages.tir.details);
```

The result is stage-based:

- `structure`: required VC and PDTF fields
- `signature`: resolves the issuer DID, checks `verificationMethod`, confirms the key is in `assertionMethod`, then runs `verifyProof`
- `tir`: checks the issuer DID against the TIR and verifies path coverage
- `status`: fetches the Bitstring Status List and checks the credential bit

## 4. What the validator enforces

`VcValidator` is intentionally fail-closed in the places that matter:

- `issuer` must match the DID used in `proof.verificationMethod`
- the verification method must exist in the DID document
- the verification method must be listed in `assertionMethod`
- `credentialStatus` must be present for revocation checking
- a set status bit means the credential is rejected

That aligns with the PDTF model: a valid signature is not enough on its own.

## 5. Verify just the proof, if you need a lower-level check

If you already resolved the public key yourself, you can call `verifyProof` directly:

```ts
import { DidResolver, verifyProof, type VerifiableCredential } from '@pdtf/core';
import { base58btc } from 'multiformats/bases/base58';

const vc: VerifiableCredential = await loadCredentialSomehow();
const resolver = new DidResolver();

const vm = vc.proof!.verificationMethod;
const issuerDid = vm.split('#')[0]!;
const didDoc = await resolver.resolve(issuerDid);
const method = didDoc.verificationMethod!.find((m) => m.id === vm)!;

const decoded = base58btc.decode(method.publicKeyMultibase!);
const publicKey = decoded[0] === 0xed && decoded[1] === 0x01
  ? decoded.slice(2)
  : decoded;

const ok = verifyProof({
  document: vc,
  publicKey,
});

console.log({ ok });
```

Use this lower-level path when you are embedding verification into a custom flow, but prefer `VcValidator` for production verification because it also checks TIR authorisation and revocation.

## 6. Recommended production pattern

For most PDTF consumers, the right flow is:

1. Parse the VC JSON.
2. Call `validator.validate(...)` with `credentialPaths`.
3. Reject if any stage fails.
4. Log `warnings` and TIR details for audit.
5. Cache DID documents, TIR responses, and status lists for short periods only.

If the credential is about access or authority, such as Ownership, Representation, or DelegatedConsent, do not skip the status check. Revocation is what turns an old mandate into an invalid one.