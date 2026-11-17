# Unified safe Android release

`D:/projects/vento/vento-unified-safe-release.bat` is the only release entry point for both independent repositories. All checks, build orchestration, APK verification, and update packaging live in its embedded PowerShell payload. No standalone release `.ps1` file is required.

## Usage

Double-click the BAT to choose VentoPOS, Keygen, or both and select a version. From a terminal:

```powershell
.\vento-unified-safe-release.bat --both --no-open
.\vento-unified-safe-release.bat --pos --version 2.8.6+27 --no-open
.\vento-unified-safe-release.bat --keygen --version 1.1.4+6 --no-open
.\vento-unified-safe-release.bat --both --verify-only --no-open
.\vento-unified-safe-release.bat --self-test --no-open
```

Use versions higher than the currently published APKs. The examples above are illustrative; inspect the current `pubspec.yaml` and published build first.

Automatic selection compares the working-tree version with both Git HEAD and the verified previous APK. A prepared version is reused only if its build is higher than the published APK. Otherwise, the default increments the patch and uses `max(source build, previous APK build) + 1`. For example, source `2.8.5+26` and published build `26` produce `2.8.6+27`, even when HEAD still contains `2.8.4+25`. Retrying an unpublished prepared version keeps that version. Explicit versions and the keep-version option must still pass the strict increasing-build check.

| Option | Behavior |
| --- | --- |
| `--pos`, `--ventopos` | Build only VentoPOS. |
| `--keygen` | Build only the administrator app. |
| `--both`, `--all` | Build and verify both before publishing either APK alias. |
| `--pos-version X.Y.Z+N` | Set the VentoPOS version explicitly. |
| `--keygen-version X.Y.Z+N` | Set the Keygen version explicitly. |
| `--version X.Y.Z+N` | Explicit version for a single selected target. |
| `--verify-only` | Read-only checks against existing APKs, certificate pins, signing configuration, source compatibility, and secret tracking. No version, build, or Git mutation. |
| `--self-test` | Isolated automatic-version selection/retry, certificate rejection, increasing-build, atomic publication, missing-tool, and ZIP integrity checks. Uses temporary fixtures, not production builds. |
| `--no-open` | Do not open the resulting release folder. |
| `--commit` | Commit selected repository changes after successful packaging. |
| `--push` | Commit and push selected repositories after successful packaging. |
| `--no-push` | Compatibility alias for local commit without push. |
| `--no-git` | Disable Git mutations; this is the default. |
| `--help` | Show command help. |

`--skip-codegen` is intentionally rejected. Release generation must regenerate Drift code and pass analysis and tests. CLI calls do not pause; double-click mode pauses at exit.

## Safety sequence

1. Validate all selected repositories before building: package IDs, minimum/target SDK, Java target, production signing properties and keystore, unchanged licensing public key/protocol, and secret/artifact tracking.
2. Require Android `aapt` and `apksigner`. Verify each existing canonical APK against its repository's `android/release_certificate.sha256`. Pins must match the **field production certificate** used for offline sideload updates (not a rotated unused key). Confirm installed devices with `apksigner verify --print-certs` on a pulled APK when in doubt; see Project store `docs/keystore-rotate.md`.
3. Require the new APK build number to exceed the previously published APK. Synchronize `pubspec.yaml` with application version constants.
4. Resolve dependencies, regenerate VentoPOS Drift code, run static analysis, and run the complete test suite. A failure stops release generation.
5. Build production-signed obfuscated APKs. Keep version-specific debug symbols outside distribution packages. Delete stale build candidates before building so failed commands cannot reuse old APKs.
6. Verify candidate package, version name, version code, signature validity, and exact pinned production certificate. Do not overwrite existing published aliases during this phase.
7. Stage versioned APKs, SHA-256 files, an installation guide, and a release manifest. Build ZIPs and read back each APK from the archive to verify its hash.
8. Publish the complete release folders/ZIPs, then replace repository APK aliases using same-directory temporary files and atomic replacement.
9. Run Git commit/push only if explicitly requested by a flag. The two repositories remain independent.

## Outputs

Workspace `dist/` contains a timestamped release folder, ZIP, and ZIP SHA-256 file. A release containing both applications is named `Vento-admin-release-*` and is administrator-only. Separate `VentoPOS-update-*` and `VentoPOS_Keygen-admin-update-*` packages are also created. Send only the VentoPOS package to customers.

Each package contains only the selected versioned APK(s), APK SHA-256 files, `release-manifest.json`, and `INSTALLATION.txt`. The manifest records versions/builds, certificate and file hashes, source commit IDs, and whether the source tree contained uncommitted changes.

Repository aliases remain available at:

- `ventoPOS/dist/VentoPOS-release.apk`
- `ventoPOS_Keygen/dist/VentoPOS_Keygen-release.apk`

Older versioned APKs and release packages remain available. Build failures preserve the prior APK aliases. Packaging or publication I/O failures stop the command; completed versioned packages and staging files remain for diagnosis. Multi-file alias replacement is not a distributed filesystem transaction.

## Secrets and update continuity

Keep `android/key.properties`, keystores, signing seeds, build outputs, and debug symbols out of Git. Local signing files are required and must not be deleted when removing them from the Git index. Removing tracking does not erase secrets from existing Git history or previously distributed APKs; this workflow does not rewrite history or rotate production keys.

Keygen seeds are provisioned through the app's signing-key setup screen and stored in platform secure storage. Legacy preference seeds migrate after validation and a verified secure-storage write. Builds never accept `VP_KEYGEN_PRIVATE_SEED` through `--dart-define`. Existing administrator installs that relied exclusively on the old embedded seed need the existing administrator seed provisioned once after updating. Customer-app verification keys and tokens remain unchanged.

Install the new APK over the existing application without uninstalling it. Database migration, license continuity, and receipt-sequence tests run before release. Actual physical-device installation, OEM behavior, and Bluetooth printing still require field verification.

## Upgrade safety backups (operators & support)

In-place upgrades produce **two different** automatic safety artifacts. Support must pick the right one:

1. **Pre-migration SQLite** (`…/pre_migration_backups/before_v*_to_v_*.sqlite`) — written by `prepareNativeDatabase` with `VACUUM INTO` **before** Drift schema migration. Use this when recovering from a failed migration or when the old schema must be restored bit-for-bit.
2. **Post-shell JSON** (`…/ventopos_pre_upgrade_backups/ventopos_pre_upgrade_b*_to_b_*.json`) — written by `AppUpgradeSafetyManager` after `AppShellScreen` starts, from the database **after** migration. Use this for portable logical restore through the app backup path; it is **not** a pre-schema SQLite clone.

Uninstalling the app deletes both folders with application data. Day-to-day operator backups remain under Settings → Yedekleme. See `ventoPOS/README.md` for the operator table.
