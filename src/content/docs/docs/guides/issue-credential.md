---
title: "Issue a Credential"
description: "How to issue a signed PDTF credential as an authorised issuer"
---

Issuing a PDTF credential means building a W3C Verifiable Credential envelope, adding PDTF-specific fields like `credentialStatus`, and signing it with an issuer key using `eddsa-jcs-2022`.

In `@pdtf/core`, the main entry point is `VcSigner`.

## 1. Create or load an issuer key

`VcSigner` needs three things:

- a `KeyProvider`
- a `keyId` in that provider
- the issuer DID, usually a `did:web` for adapters and platforms

The exact `KeyProvider` depends on your environment. In development you might use a local provider, and in production a KMS-backed one.

```ts
import { VcSigner } from '@pdtf/core';
import type { KeyProvider } from '@pdtf/core';

const keyProvider: KeyProvider = getYourKeyProvider();
const keyId = 'adapter/epc/signing-key-1';
const issuerDid = 'did:web:adapters.propdata.org.uk:epc';

const signer = new VcSigner(keyProvider, keyId, issuerDid);
```

For `did:web` issuers, `VcSigner` uses the conventional verification method `did:web:...#key-1`, so your hosted DID document must expose the matching key in both `verificationMethod` and `assertionMethod`.

## 2. Allocate a revocation entry before signing

Every PDTF credential must include `credentialStatus`. That means you should allocate a status list index before issuing the VC.

```ts
const credentialStatus = {
  id: 'https://adapters.propdata.org.uk/status/epc/list-042#18293',
  type: 'BitstringStatusListEntry' as const,
  statusPurpose: 'revocation' as const,
  statusListIndex: '18293',
  statusListCredential: 'https://adapters.propdata.org.uk/status/epc/list-042',
};
```

In a real issuer, these values usually come from your status list service, not hard-coded strings.

## 3. Build the credential subject

The subject is ordinary JSON, but it must include `id` and it should match the PDTF schema for the entity and paths you are asserting.

```ts
const credentialSubject = {
  id: 'urn:pdtf:uprn:100023456789',
  energyEfficiency: {
    certificate: {
      currentEnergyRating: 'C',
      potentialEnergyRating: 'B',
      lodgementDate: '2026-03-15',
      expiryDate: '2036-03-14',
      certificateNumber: '0123-4567-8901-2345-6789',
    },
  },
};
```

## 4. Sign the credential

```ts
const vc = await signer.sign({
  id: 'urn:uuid:6df1a7c2-4207-4d79-9b37-685c6b4c8e74',
  type: 'PropertyCredential',
  credentialSubject,
  credentialStatus,
  evidence: [
    {
      type: 'ElectronicRecord',
      source: 'https://epc-register.example/certificates/0123-4567-8901-2345-6789',
      retrievedAt: new Date().toISOString(),
    },
  ],
  validFrom: new Date().toISOString(),
});

console.log(JSON.stringify(vc, null, 2));
```

The returned credential includes:

- W3C VC v2 context
- PDTF context
- issuer DID
- `credentialStatus`
- your subject and evidence
- `proof` with `DataIntegrityProof` and `cryptosuite: "eddsa-jcs-2022"`

## 5. What `VcSigner` does for you

Under the hood, `VcSigner`:

1. builds the unsigned VC
2. derives the verification method from the issuer DID
3. canonicalises the proof options and the VC with JCS
4. signs the combined hash with your Ed25519 key
5. encodes the signature as multibase in `proof.proofValue`

You do not need to construct `proof` manually.

## 6. Minimal adapter issuance flow

A practical adapter flow usually looks like this:

```ts
async function issueEpcCredential(uprn: string) {
  const source = await fetchEpcFromSourceApi(uprn);
  const status = await allocateStatusEntry(issuerDid);

  return signer.sign({
    type: 'PropertyCredential',
    credentialSubject: mapEpcToCredentialSubject(source),
    credentialStatus: status,
    evidence: [
      {
        type: 'ElectronicRecord',
        source: source.sourceUrl,
        retrievedAt: new Date().toISOString(),
      },
    ],
  });
}
```

## 7. Production checks before returning the VC

Before you publish or return the credential:

1. make sure the issuer DID is active in the TIR for the claimed paths
2. confirm the DID document is hosted and resolves correctly
3. persist the credential ID to status-list index mapping
4. store enough source metadata to support reissuance or audit
5. run a self-check with `VcValidator`

If you skip `credentialStatus`, or your DID document does not contain the signing key in `assertionMethod`, downstream verifiers should reject the credential even if the signature bytes are mathematically valid.