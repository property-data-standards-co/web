---
title: "Build an Adapter"
description: "Create a data source adapter that issues PDTF credentials"
---

A PDTF adapter is a trusted proxy. It fetches data from a source system, maps that data into a PDTF entity shape, signs a credential with its own `did:web` identity, and publishes revocation state for anything it issues.

In practice, an adapter has five moving parts:

1. a `did:web` DID document
2. an issuer key and `VcSigner`
3. access to the source API
4. a mapper from source response to PDTF JSON
5. status list allocation and publishing

## 1. Define the adapter identity

A typical adapter DID looks like this:

```text
did:web:adapters.propdata.org.uk:epc
```

That resolves to:

```text
https://adapters.propdata.org.uk/epc/did.json
```

Your DID document should expose at least one verification method, include it in `assertionMethod`, and usually advertise service endpoints for VC issuance and revocation.

## 2. Initialise the signer

```ts
import { VcSigner } from '@pdtf/core';
import type { KeyProvider } from '@pdtf/core';

const issuerDid = 'did:web:adapters.propdata.org.uk:epc';
const keyId = 'adapter/epc/signing-key-1';
const keyProvider: KeyProvider = getYourKeyProvider();

const signer = new VcSigner(keyProvider, keyId, issuerDid);
```

## 3. Fetch from the source API

Keep source fetching separate from credential issuance. That makes it easier to test the mapping logic.

```ts
type EpcApiResponse = {
  uprn: string;
  currentEnergyRating: string;
  potentialEnergyRating: string;
  lodgementDate: string;
  expiryDate: string;
  certificateNumber: string;
  sourceUrl: string;
};

async function fetchEpc(uprn: string): Promise<EpcApiResponse> {
  const response = await fetch(`https://source.example/epc/${uprn}`);
  if (!response.ok) throw new Error(`Source API failed: ${response.status}`);
  return response.json();
}
```

## 4. Map the source data to PDTF

The adapter should issue a complete subtree for the paths it is authoritative for.

```ts
function mapToCredentialSubject(source: EpcApiResponse) {
  return {
    id: `urn:pdtf:uprn:${source.uprn}`,
    energyEfficiency: {
      certificate: {
        currentEnergyRating: source.currentEnergyRating,
        potentialEnergyRating: source.potentialEnergyRating,
        lodgementDate: source.lodgementDate,
        expiryDate: source.expiryDate,
        certificateNumber: source.certificateNumber,
      },
    },
  };
}
```

## 5. Allocate status and sign

```ts
async function allocateStatusEntry() {
  return {
    id: 'https://adapters.propdata.org.uk/status/epc/list-042#18293',
    type: 'BitstringStatusListEntry' as const,
    statusPurpose: 'revocation' as const,
    statusListIndex: '18293',
    statusListCredential: 'https://adapters.propdata.org.uk/status/epc/list-042',
  };
}

export async function issueEpcVc(uprn: string) {
  const source = await fetchEpc(uprn);
  const credentialStatus = await allocateStatusEntry();

  return signer.sign({
    type: 'PropertyCredential',
    credentialSubject: mapToCredentialSubject(source),
    credentialStatus,
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

## 6. Validate before returning

Adapters should self-validate what they issue.

```ts
import { DidResolver, TirClient, VcValidator } from '@pdtf/core';

const validator = new VcValidator();

async function issueAndVerify(uprn: string) {
  const vc = await issueEpcVc(uprn);

  const result = await validator.validate(vc, {
    didResolver: new DidResolver(),
    tirClient: new TirClient(),
    credentialPaths: ['Property:/energyEfficiency/*'],
  });

  if (!result.valid) {
    throw new Error(`Adapter issued invalid VC: ${JSON.stringify(result.stages)}`);
  }

  return vc;
}
```

## 7. Operational guidance

A good adapter is mostly disciplined plumbing:

- keep the source fetch, mapping, signing, and publishing steps separate
- issue for the exact paths your TIR entry authorises, no more
- treat source metadata as evidence, not as issuer identity
- revoke old credentials when source data changes
- publish status lists at stable HTTPS URLs
- keep signing keys out of code, ideally in KMS

The trust model matters here. The credential is signed by the adapter DID, not by the underlying source authority. The reason verifiers can trust it is that the TIR explicitly authorises that adapter DID for the relevant `entity:path` combinations.