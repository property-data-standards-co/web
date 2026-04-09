---
title: "Check Revocation Status"
description: "Query Bitstring Status Lists to check credential validity"
---

Every PDTF credential must carry a `credentialStatus` entry pointing to a W3C Bitstring Status List. Revocation checking is how a verifier learns that a previously valid credential is now stale, withdrawn, or superseded.

In `@pdtf/core`, the low-level tools are `checkStatus`, `createStatusList`, `encodeStatusList`, `decodeStatusList`, and `getBit`.

## 1. Check a credential's status directly

If you already have the credential, the quickest path is `checkStatus`.

```ts
import { checkStatus, type VerifiableCredential } from '@pdtf/core';

const vc: VerifiableCredential = await loadCredentialSomehow();

const isRevoked = await checkStatus(
  vc.credentialStatus!.statusListCredential,
  parseInt(vc.credentialStatus!.statusListIndex, 10),
);

console.log({ isRevoked });
```

`checkStatus` fetches the status list VC, reads `credentialSubject.encodedList`, decodes it, and checks the bit at the requested index. A bit value of `1` means revoked or suspended, depending on `statusPurpose`.

## 2. Understand the status list shape

A PDTF status list credential is itself a signed VC. The important part is the subject:

```json
{
  "id": "https://adapters.propdata.org.uk/status/epc/list-042",
  "type": "BitstringStatusList",
  "statusPurpose": "revocation",
  "encodedList": "H4sIAAAAAAAAA..."
}
```

The `encodedList` value is a gzip-compressed, base64 string representing the raw bitstring.

## 3. Decode and inspect the list manually

If you want more control, decode the list yourself.

```ts
import { decodeStatusList, getBit } from '@pdtf/core';

const response = await fetch('https://adapters.propdata.org.uk/status/epc/list-042');
const statusListVc = await response.json();

const bitstring = decodeStatusList(statusListVc.credentialSubject.encodedList);

console.log(getBit(bitstring, 18293));
```

This is useful for debugging, bulk inspection, or writing your own higher-level verifier.

## 4. Create a new empty list

Issuers need to create lists before they can allocate indices.

```ts
import { createStatusList, encodeStatusList } from '@pdtf/core';

const bitstring = createStatusList();
const encodedList = encodeStatusList(bitstring);

console.log(bitstring.length); // 16KB raw by default
console.log(encodedList);
```

`createStatusList()` enforces the PDTF minimum size of 131,072 bits, which gives herd privacy and enough capacity for normal issuer volumes.

## 5. Revoke a credential by setting its bit

If you are the issuer, revocation is just a bit flip in the underlying list.

```ts
import { createStatusList, revokeCredential, getBit } from '@pdtf/core';

const bitstring = createStatusList();

revokeCredential(bitstring, 18293);

console.log(getBit(bitstring, 18293)); // true
```

In a real system you would then:

1. re-encode the list
2. rebuild the status list VC
3. sign it with the issuer key
4. publish it back to the stable HTTPS URL

## 6. Full verifier behaviour

A robust verifier should do more than just read the bit:

1. verify the credential proof
2. fetch the status list VC
3. verify the status list VC proof
4. confirm the status list issuer matches the credential issuer
5. decode the bitstring and inspect the bit

If you use `VcValidator`, step 5 is already integrated into the validation pipeline. The standalone status helpers are best when you need targeted revocation logic or issuer-side tooling.

## 7. Operational advice

A few rules matter in production:

- never reuse a `statusListIndex`
- keep the `statusListCredential` URL stable for the lifetime of the VC
- serve status lists over HTTPS with short cache lifetimes
- revoke old credentials when source data changes, not just when fraud occurs
- treat missing or unreachable status information as a verification failure for high-trust decisions

In PDTF, revocation is not edge-case plumbing. It is part of the trust contract. Ownership, representation, consent, and adapter data all need a way to become invalid when the world changes.