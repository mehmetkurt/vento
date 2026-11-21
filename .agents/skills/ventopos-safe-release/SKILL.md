---
name: ventopos-safe-release
description: Audits in-place Android APK upgrade safety, verifies Drift SQLite schema migrations and Ed25519 license continuity, synchronizes pubspec and AppInfoConstants versions, builds production-signed obfuscated VentoPOS release APKs, and runs /git-commit-and-push. Use when creating a VentoPOS release package, bumping app version or build numbers, running pre-release safety checks, or publishing updates without breaking installed field apps.
---

# VentoPOS Safe Release and In-Place Upgrade Workflow

Executes an end-to-end pre-release safety audit, version synchronization, production-signed obfuscated APK build, and `/git-commit-and-push` workflow for **VentoPOS** (`package:ventopos`, `com.ventopos.ventopos`).

**Working directories**: The umbrella workspace root is `D:\projects\vento`. Flutter analyze/test/build commands and relative paths in the gate table below run from **`ventoPOS/`** unless noted. The unified release entry point `vento-unified-safe-release.bat` lives at the umbrella root.

## Non-Negotiable Core Principle: Never Break Installed Field Apps

When the generated APK is installed directly on top of an active **VentoPOS** installation in the field (**in-place update**):

- Android must **never** reject the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ("Paket çakışıyor / Yüklenemedi").
- Existing SQLite database records (`ventopos_enterprise_db`) including customers, orders, cash transactions, routes, subcontractor factory accounts, order photos, and receipt/message templates must open with **zero data loss**.
- Active hardware-bound Ed25519 license keys (`VPK1-...`) on customer devices must remain **100% valid without reactivation**.

## Governance and Language Rules

1. Read `AGENTS.md` from start to finish before editing any file or running release commands.
2. Keep all Dart/Kotlin identifiers, code comments, and Git commit messages in **English** (`AGENTS.md` Section 7).
3. Present all intermediate audit results, test summaries, and the final release report to the user in **Turkish**.
4. Never bypass a failing check. If any audit, static analysis rule, or test fails, fix the root cause and re-run verification before building the release APK or pushing to Git.

## Decision Tree

- **`android/key.properties` or production keystore (`ventopos-release.jks`) is missing**: Abort immediately. Never sign a release build with the `Android Debug` certificate; doing so breaks in-place updates on every field device.
- **Signing continuity (offline sideload, no Play Store)**: Field devices already carry the **original production certificate**. Release builds MUST keep signing with that same keystore forever, or in-place updates fail (`INSTALL_FAILED_UPDATE_INCOMPATIBLE` / bat: `Uretim sertifikasi onceki surumle eslesmiyor.`). Do **not** adopt a rotated `.jks` for POS release unless the entire fleet is wiped and reinstalled. Pin `android/release_certificate.sha256` must match the field cert (POS Expected: `b57229c7075ca3f0255af278188d16aacf8aa628ebeaf9d2990564ff38cd5398`). Production aliases are `ventopos` / `keygen` — never `ventopos_release` / `keygen_release` (those belonged to the unused rotated keystores). `android/key.properties.example` and `android/app/build.gradle.kts` must keep that wiring; release tasks assert the keystore cert against the pin before signing. Operator archive notes: Project store `docs/keystore-rotate.md`. Never commit `.jks` / `key.properties`; passwords stay in local `key.properties`, Windows Credential Manager / DPAPI under `%USERPROFILE%\.vento\signing\`, or CI env vars (`VENTOPOS_*` / `KEYGEN_*`). Verify `apksigner verify --print-certs` against the pin.
- **`pubspec.yaml` build number (`+N`) was not incremented**: Increment `versionCode` (`+N` -> `+(N+1)`) and bump `versionName` (`X.Y.Z`) according to release scope, then synchronize `AppInfoConstants.fallbackPubspecVersionSpec` so `AppUpgradeSafetyManager` triggers its automatic **post-shell** JSON backup (`currentBuild > lastBuild`). That JSON is written after Drift migration from the new schema; the separate **pre-migration** binary SQLite under `pre_migration_backups/` (`prepareNativeDatabase` / `VACUUM INTO`) is the artifact for old-schema recovery — do not conflate the two.
- **Non-idempotent SQL detected in `AppDatabase.migration.onUpgrade`**: Refactor raw `ALTER TABLE` statements to `_addColumnIfMissing(...)`, enforce `CREATE TABLE IF NOT EXISTS` / `CREATE UNIQUE INDEX IF NOT EXISTS`, and deduplicate historical rows before creating unique indexes.
- **`.runtimeType.toString()` in mappers or missing `@pragma('vm:entry-point')` on `Isolate` entry points**: Replace `.runtimeType.toString()` with enum `.name` or explicit string constants so `--obfuscate` cannot break serialization in release mode.
- **Any warning/error in `flutter analyze` or failure in `flutter test`**: Fix the underlying issue and re-run both suites until 0 analyzer issues and 100% test pass rate are achieved.
- **Secrets or build artifacts appear in `git status`**: Unstage immediately and verify `.gitignore` excludes `android/key.properties`, `*.jks`, `*.keystore`, `/dist/`, `/debug_symbols/`, and `/build/` before running `/git-commit-and-push`.

## Workflow Steps

### Step 1: In-Place Upgrade and Backward Compatibility Audit

There is **no** shipped `verify_release_gates.py` helper under this skill. Manually verify all 5 critical invariants below inside **`ventoPOS/`** (paths are relative to that submodule):

| Gate | Target Files (under `ventoPOS/`) | Mandatory Verification |
| :--- | :--- | :--- |
| **1. Android Package & Signing Continuity** | `android/app/build.gradle.kts`, `android/key.properties`, `android/release_certificate.sha256` | Confirm `applicationId = "com.ventopos.ventopos"` is unchanged, `minSdk = 24` was not raised, and `android/key.properties` plus `ventopos-release.jks` exist on disk. Release builds signed with debug keys are strictly forbidden. Pin must match field cert `b57229c7075ca3f0255af278188d16aacf8aa628ebeaf9d2990564ff38cd5398`. |
| **2. SQLite Database & Multi-Schema Migration** | `lib/data/database/app_database.dart`, `lib/data/database/connection/database_connection.dart` | Confirm `kVentoPosEnterpriseDbName = 'ventopos_enterprise_db'` and `getApplicationSupportDirectory` are unchanged. Audit every `from < 2` ... `from < schemaVersion` branch in `AppDatabase.migration.onUpgrade`: all new columns must use `_addColumnIfMissing(...)`, tables/indexes must use `IF NOT EXISTS`, `idx_carpet_orders_receipt_number` must run pre-index deduplication on blank/duplicate historical numbers, and new `NOT NULL` columns must define safe `DEFAULT` values. |
| **3. License, Photos & `SharedPreferences` Continuity** | `lib/core/license/license_constants.dart`, `license_codec.dart`, `DeviceIdentityHandler.kt`, `PreferencesService` | Confirm no change invalidates existing `VP-...` device codes or `VPK1-...` Ed25519 license signatures / public verification key bytes. Confirm existing `pref*` keys in `PreferencesService` and stored order photo file paths resolve backward-compatibly. Keygen private seeds remain SecureStorage-only (never compile-time `VP_KEYGEN_PRIVATE_SEED`). |
| **4. Release `--obfuscate` & `build_runner` Sync** | `lib/**/*.g.dart`, data/JSON/SQLite mappers, background isolates | From `ventoPOS/`, run `dart run build_runner build --delete-conflicting-outputs` and confirm `app_database.g.dart` and all `.g.dart` files match current definitions. Scan `lib/data` and `lib/domain` to ensure zero `.runtimeType.toString()` usage in mappers and safe entry points on any background `Isolate`. |
| **5. Upgrade Safety Integration Test** | `test/data/database/in_place_upgrade_safety_test.dart`, `AppUpgradeSafetyManager` | Run the existing integration test at `ventoPOS/test/data/database/in_place_upgrade_safety_test.dart` verifying that legacy SQLite databases populated with customers, orders, cash transactions, routes, and settings upgrade cleanly to the current `schemaVersion` and pass `AppUpgradeSafetyManager` pre-upgrade safety checks with zero errors and zero data loss. |

### Step 2: Version Increment and Synchronization (`versionName` & `versionCode`)

1. From `ventoPOS/`, read `version: X.Y.Z+N` in `pubspec.yaml` (for example `2.1.0+11`).
2. Increment the semantic version and Android `versionCode` (`+N`) for seamless field upgrades (for example `2.1.0+11` -> `2.2.0+12`; if already incremented in the working tree, confirm `+N` is strictly greater than the latest released build).
3. Update `fallbackPubspecVersionSpec` in `ventoPOS/lib/core/constants/app_info_constants.dart` to match `pubspec.yaml` character-for-character so About/Dashboard labels and `AppUpgradeSafetyManager` pre-upgrade snapshot triggers stay synchronized.

### Step 3: Static Analysis and Full Automated Test Suite

Execute both commands sequentially from **`ventoPOS/`** and require 100% clean pass before building the release APK:

```bash
cd ventoPOS
flutter analyze
flutter test
```

- `flutter analyze` must return **0 errors and 0 warnings** (`No issues found!`).
- `flutter test` must pass **100% of unit, database migration, and widget tests**. Do not proceed if even a single test fails.

### Step 4: Signed Obfuscated Release APK Build and Certificate Verification

1. Run the single workspace release entry point. Its PowerShell payload is embedded in the BAT; do not create or invoke standalone release PS1 files:

```powershell
D:\projects\vento\vento-unified-safe-release.bat --pos --no-open
```

   *(If running on macOS or Linux without PowerShell, execute the exact equivalent pipeline: `flutter build apk --release --obfuscate --split-debug-info=debug_symbols/ventopos` and copy `build/app/outputs/flutter-apk/app-release.apk` to both `dist/VentoPOS-release.apk` and `dist/VentoPOS-v<Version>-build<Build>-release.apk`.)*

2. The BAT embeds strict APK verification and writes a versioned update folder, ZIP, SHA-256 files, and manifest under the workspace `dist/`. It updates repository APK aliases only after all selected applications and the archive pass verification. Git commit/push is opt-in through `--commit` or `--push`. Perform post-build binary verification on `dist/VentoPOS-release.apk`:
   - Confirm the APK file exists on disk with a valid non-zero size.
   - Verify `package: name='com.ventopos.ventopos'`, `versionCode`, and `versionName` via `aapt dump badging` or Gradle build metadata.
   - Run `apksigner verify --print-certs dist/VentoPOS-release.apk` and confirm the APK is signed with the **Production Release Keystore** (strictly reject `CN=Android Debug`).

### Step 5: Secret Hygiene Audit and `/git-commit-and-push`

1. Inspect `git status` and `git diff --stat`:
   - Confirm `.gitignore` excludes `android/key.properties`, `*.jks`, `*.keystore`, `/dist/`, `/debug_symbols/`, and `/build/` so no signing credentials or compiled binaries are tracked.
   - Remove any temporary test or log artifacts left in the working tree.
2. Execute the `/git-commit-and-push` workflow to stage, commit with a descriptive English Conventional Commit message (for example: `chore(release): bump version to 2.2.0+12 and finalize safe in-place upgrade checks`), and push to `origin`.
3. Present the final release report in **Turkish** with clear bullet points covering:
   - Yeni sürüm ve build numarası (`Versiyon X.Y.Z Build N`),
   - Yerinde güncelleme (`in-place upgrade`), SQLite migrasyon ve lisans sürekliliği doğrulama sonuçları,
   - `flutter analyze` ve `flutter test` çalışma özeti,
   - Üretilen imzalı release APK dosya yolları ve `apksigner` sertifika doğrulama durumu,
   - Git commit hash ve uzak depoya (`origin`) push durumu.
