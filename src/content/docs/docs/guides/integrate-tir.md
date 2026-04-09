---
title: "Integrate with the TIR"
description: "Register as an issuer and verify against the Trusted Issuer Registry"
---

The Trusted Issuer Registry, or TIR, is the second half of PDTF trust. A valid signature tells you who signed a credential. The TIR tells you whether that issuer is authorised to sign for the specific entity paths being claimed.

In `@pdtf/core`, use `TirClient` to load the registry and `verifyIssuer` to test authorisation.

## 1. Create a TIR client

```ts
import { TirClient } from '@pdtf/core';

const tir = new TirClient({
  registryUrl: 'https://tir.moverly.com/v1/registry',
  ttlMs: 60 * 60 * 1000,
});
```

The client caches the registry and supports normal HTTP cache patterns such as ETags when the endpoint provides them.

## 2. Look up an issuer by DID

This is useful for diagnostics, admin tooling, and debugging failed validation.

```ts
const issuer = await tir.findIssuerByDid('did:web:adapters.propdata.org.uk:epc');

if (!issuer) {
  throw new Error('Issuer DID not found in TIR');
}

console.log(issuer.slug);
console.log(issuer.entry.trustLevel);
console.log(issuer.entry.authorisedPaths);
```

A TIR entry is keyed by slug, but in verification flows you normally start with the DID from the credential.

## 3. Check path authorisation

The simplest production check is `verifyIssuer`.

```ts
import { verifyIssuer } from '@pdtf/core';

const result = await verifyIssuer({
  issuerDid: 'did:web:adapters.propdata.org.uk:epc',
  credentialPaths: ['Property:/energyEfficiency/*'],
  tirClient: tir,
});

if (!result.trusted) {
  console.error(result.uncoveredPaths);
  throw new Error('Issuer is not authorised for requested paths');
}

console.log(result.issuerSlug);
console.log(result.trustLevel);
```

`verifyIssuer` checks:

1. the DID exists in the registry
2. the issuer status is not `revoked` or `planned`
3. any validity window has not expired
4. the issuer's `authorisedPaths` cover the credential paths you supplied

If some paths are missing, `trusted` will be false and `uncoveredPaths` will show exactly what failed.

## 4. Example: protect an issuance or ingest pipeline

```ts
async function assertIssuerAuthorised(issuerDid: string, credentialPaths: string[]) {
  const check = await verifyIssuer({
    issuerDid,
    credentialPaths,
    tirClient: tir,
  });

  if (!check.trusted) {
    throw new Error(
      `Issuer ${issuerDid} is not authorised for: ${check.uncoveredPaths.join(', ')}`
    );
  }
}

await assertIssuerAuthorised(
  'did:web:adapters.propdata.org.uk:epc',
  ['Property:/energyEfficiency/*'],
);
```

This is worth doing even if you also use `VcValidator`, because it lets you fail early in custom workflows.

## 5. How this relates to full VC verification

If you use `VcValidator`, TIR integration is built in:

```ts
import { DidResolver, TirClient, VcValidator } from '@pdtf/core';

const validator = new VcValidator();
const validation = await validator.validate(vc, {
  didResolver: new DidResolver(),
  tirClient: new TirClient(),
  credentialPaths: ['Property:/energyEfficiency/*'],
});
```

That is the normal path for verifier applications. Use direct `verifyIssuer` calls when you want TIR checks outside full VC validation.

## 6. Registering your issuer

To become trusted, your issuer needs an entry in the registry with:

- a stable slug
- your issuer DID
- `trustLevel` such as `rootIssuer` or `trustedProxy`
- the exact `authorisedPaths`
- `status: active`
- `proxyFor` if you are a trusted proxy adapter

Path scope is the important part. Being trusted for one subtree does not grant authority over another.

## 7. Recommended pattern

For every credential you verify or issue:

1. derive the claimed entity paths
2. run a TIR check against those paths
3. reject partial coverage
4. log `issuerSlug`, `trustLevel`, and warnings for audit

In PDTF, TIR authorisation is not an optional enrichment. It is what stops a perfectly signed but unauthorised issuer from being treated as authoritative.