---
trigger: model_decision
description: Apply when modifying Ed25519 licensing constants, device code format (VP-...), activation token verification (VPK1-...), or release APK build scripts across ventoPOS and ventoPOS_Keygen.
---

# Cross-Project Licensing & Release Continuity Rules

1. **Synchronized Protocol Constants**:
   Whenever updating `protocolVersion`, `deviceCodePrefix` (`VP`), `activationKeyPrefix` (`VPK1-`), `signatureDomainTag` (`VP-LICENSE-V1:`), `licenseEpochUtc`, or `publicKeyBase64Url`, verify both:
   - `ventoPOS/lib/core/license/license_constants.dart` & `license_codec.dart`
   - `ventoPOS_Keygen/lib/core/constants/keygen_constants.dart` & `ed25519_license_signer.dart`

2. **Private Key Isolation**:
   - The 32-byte Ed25519 private signing seed (`VP_KEYGEN_PRIVATE_SEED`) belongs strictly in `ventoPOS_Keygen`.
   - Never expose private signing material in `ventoPOS` source files, assets, logs, or error messages.

3. **Android Release Upgrade Continuity**:
   - `ventoPOS` uses `applicationId = "com.ventopos.ventopos"` signed with `android/keystore/ventopos-release.jks`.
   - `ventoPOS_Keygen` uses `applicationId = "com.ventopos.ventopos_keygen"` signed with `android/keystore/keygen-release.jks`.
   - Never fall back to debug signing for release APKs so field devices can install updates in-place without losing local customer/order data.

