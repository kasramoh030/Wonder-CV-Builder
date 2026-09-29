# Releasing Wonder CV Builder

Everything a maintainer needs to produce a signed, publishable build — and
nothing that would put a signing key in the repository.

- [Identity and versioning](#identity-and-versioning)
- [Create the upload keystore](#create-the-upload-keystore)
- [Local release builds](#local-release-builds)
- [CI release builds](#ci-release-builds)
- [Verify an artifact before uploading it](#verify-an-artifact-before-uploading-it)
- [Which artifact for which store](#which-artifact-for-which-store)
- [Troubleshooting](#troubleshooting)

## Identity and versioning

| Field | Value | Where it lives |
|---|---|---|
| applicationId | `dev.cvpro.builder` | `android/app/build.gradle.kts` |
| namespace | `dev.cvpro.builder` | `android/app/build.gradle.kts` |
| versionName / versionCode | `1.0.0` / `1` | `version:` in `pubspec.yaml` |
| minSdk | 24 (Android 7.0) | `flutter.minSdkVersion` |
| targetSdk / compileSdk | 36 | `flutter.targetSdkVersion` / `flutter.compileSdkVersion` |
| launcher label | Wonder CV Builder | `res/values/strings.xml` |

**The version lives in exactly one place.** `version: 1.0.0+1` in
`pubspec.yaml` is read by the Flutter Gradle plugin and becomes `versionName`
and `versionCode`. Never edit the version in Gradle: a store build that
disagrees with itself is a support ticket.

To release `1.1.0`:

```bash
# pubspec.yaml: version: 1.1.0+2   (the code must always increase)
git commit -am "release: 1.1.0"
git tag v1.1.0
git push origin main --tags
```

The tag triggers the signed release workflow, which refuses to run if the tag
and `pubspec.yaml` disagree.

## Create the upload keystore

**Run this on your own machine, never in CI and never in a shared or agent
sandbox.** The keystore is the app's permanent identity: it is what lets an
update install over the version already on a user's phone. Whoever holds it
can publish as this app, and losing it means the ability to update
`dev.cvpro.builder` is gone forever.

```bash
./tools/create_release_keystore.sh            # create
./tools/create_release_keystore.sh --check    # verify an existing one
```

The script:

- writes the keystore **outside any git repository** and refuses to run if the
  target directory is inside one, because a keystore in a working tree is one
  `git add -A` away from being published;
- passes the passwords to `keytool` through `0600` files it shreds afterwards,
  so they never appear in `ps`, `/proc` or your shell history;
- never echoes a password, never writes one to a log, and prints only what is
  safe to share: the path, the alias and the certificate's SHA-256;
- prints the exact `gh secret set` commands, each reading from a file rather
  than a `--body` argument, so the values never reach your terminal scrollback;
- prints the credentials record to keep — keystore path, alias, application id,
  version, certificate fingerprint, backup slots — with the two passwords named
  as fields rather than filled in, so the page you keep holds no secret;
- reads the fingerprint from the keystore itself (both `keytool` spellings, JDK
  8 and newer) and tells you that an empty pin protects nothing if it cannot.

You choose the keystore password, the key alias (`upload` by default) and the
key password. Choose a strong keystore password and put it in your password
manager **before** you start: there is no recovery, and no way to change it
afterwards without re-signing everything.

### Where the credentials live

| Value | Where it belongs | Where it must never be |
|---|---|---|
| Keystore file (`.jks`) | Your machine, plus two backups elsewhere | Any git repository, any CI artifact, any chat |
| Keystore password | Your password manager, and the `KEYSTORE_PASSWORD` secret | Repository, logs, shell history, screenshots |
| Key alias | Recorded in this document's table below | — (it is not secret, but it must stay consistent) |
| Key password | Your password manager, and the `KEY_PASSWORD` secret | As above |
| Certificate SHA-256 | Here, in `ANDROID_CERT_SHA256`, and in your release notes | — (it is public information) |

### Owner release credentials

Fill this in once, keep it where you keep your other credentials, and keep the
fingerprint in the repository:

```
Owner release credentials — Wonder CV Builder
────────────────────────────────────────────
Keystore file:      <your secure local path>
Keystore password:  <in your password manager>
Key alias:          upload
Key password:       <in your password manager>
Application ID:     dev.cvpro.builder
Version:            see pubspec.yaml (currently 1.0.0+1)
Cert SHA-256:       <printed by the script; also in ANDROID_CERT_SHA256>
Created:            <date>
Backup 1:           <where>
Backup 2:           <where>
```

### Back up the keystore twice

An upload key cannot be regenerated. If it is lost after the first release,
the app can never be updated again under this package name — the listing, the
reviews and the install base all become unreachable, and the only way forward
is a new app.

Two copies, two locations, neither of them the machine you build on:

1. an encrypted archive in your password manager's file storage, or an
   encrypted volume you already back up;
2. a second copy in a physically different place — an encrypted USB key in a
   drawer, or a different provider's encrypted storage.

Verify a backup by restoring it somewhere else and running
`./tools/create_release_keystore.sh --check` against the restored file: a
backup nobody has read is a backup nobody knows is broken.

### A note on sandboxes and agents

Do not generate this key in a shared, ephemeral or automated environment, and
do not paste it into a chat. A key created where someone else can read the
disk is a key someone else may have. This repository's own tooling follows
that rule: nothing in `tools/` creates key material on your behalf, CI only
ever receives it as a secret, and `tools/check_no_key_material.sh` fails the
build if key material appears in the tree.

### Point a local machine at it

`android/key.properties` (git-ignored — see `android/.gitignore`):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

Prefer not to have the passwords in a file? Set the four environment
variables instead; they take priority over `key.properties`:

```bash
export ANDROID_KEYSTORE_PATH=/absolute/path/to/upload-keystore.jks
export ANDROID_KEYSTORE_PASSWORD=…
export ANDROID_KEY_ALIAS=upload
export ANDROID_KEY_PASSWORD=…
```

### Point GitHub Actions at it

`./tools/create_release_keystore.sh` prints these commands ready to paste. Add
four **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

The shorter names — `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD` — are accepted too, because they are what most guides use.
Either naming works; whichever values are missing are named in the failure.

**As of this commit those secrets are not configured**, so the tag-triggered
release run stops at the first step and says which four values it needs. That
is the only thing between this repository and a publishable build.

```bash
# Linux: base64 -w0; macOS: base64 -i (no line wrapping)
gh secret set KEYSTORE_BASE64   < keystore.base64
gh secret set KEYSTORE_PASSWORD < .store-password
gh secret set KEY_ALIAS         --body upload
gh secret set KEY_PASSWORD      < .key-password
```

The workflow verifies the AAB and APK are **not** signed with the debug key.

### Pin the certificate fingerprint

The fingerprint is public — every store shows it — so it belongs in the
repository as a *variable*, not a secret:

```bash
gh variable set ANDROID_CERT_SHA256 --body '<hex from the script, no colons>'
```

The release workflow then fails any artifact signed with a different key,
which is the one failure a store will happily let through: a valid, non-debug
signature made with the wrong key.

The workflow writes the keystore into `$RUNNER_TEMP`, never into the
workspace, so it cannot end up in an uploaded artifact or a stray `git add`.

Without those four secrets the release workflow **fails immediately**, naming
the missing ones. That is deliberate: a pipeline that quietly falls back to
the debug key produces an APK that can never be published or updated.

## Local release builds

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-warnings --no-fatal-infos
flutter test

# Universal APK — for Cafe Bazaar and Myket
flutter build apk --release

# App bundle — for Google Play
flutter build appbundle --release
```

Outputs:

```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/app/outputs/mapping/release/mapping.txt   # R8 mapping
```

Keep `mapping.txt` for every published build. It is the only way to read a
stack trace from a crash report of a minified release.

## CI release builds

`.github/workflows/android-release.yml`, triggered by a `v*` tag or by hand
(workflow_dispatch). It:

1. checks the four signing secrets are present, and stops if they are not;
2. resolves dependencies, generates code, runs `flutter analyze` and
   `flutter test`;
3. verifies the tag matches `pubspec.yaml`;
4. builds the signed release APK and AAB;
5. runs `tools/verify_release_artifact.sh` over both;
6. uploads them named `wonder-cv-builder-release.apk` and
   `wonder-cv-builder-release.aab`, and attaches them to a GitHub release when
   the trigger was a tag.

The other workflows:

| Workflow | Purpose |
|---|---|
| `analyze.yml` | codegen + `flutter analyze --fatal-warnings` |
| `test.yml` | `flutter test` with coverage |
| `android-debug.yml` | an installable debug APK per push, plus the same artifact inspection |
| `android-release.yml` | the signed, verified, publishable build |

All four publish their failure output (and, for the debug build, the
inspection table) as a **commit comment**, because the raw Actions log
requires repository sign-in to read.

## Guarding the repository

```bash
tools/check_no_key_material.sh                  # check now
tools/check_no_key_material.sh --install-hook   # check before every commit
```

It runs in CI on every push, before anything is built. It fails on key
material by name (`*.jks`, `key.properties`, `.env`, …), by content (a PEM
private key, an API-key shape, base64 that decodes to a JKS magic number), and
on a password written as a literal in a properties, YAML, JSON or Gradle file.

## Verify an artifact before uploading it

```bash
export ANDROID_HOME=$HOME/Android/Sdk
tools/verify_release_artifact.sh \
  build/app/outputs/flutter-apk/app-release.apk \
  build/app/outputs/bundle/release/app-release.aab
```

It reports, and fails on anything that would block a release:

| Check | Why it matters |
|---|---|
| package name | a typo publishes under the wrong identity, permanently |
| version name / code | the store rejects an unchanged versionCode |
| target SDK | Play rejects a build that does not target a current API |
| `android:debuggable` | a debuggable release is a security finding |
| permissions | anything beyond INTERNET needs a justification |
| exported components | an exported service or receiver is an attack surface |
| signature certificate | catches the debug key before it reaches a store |
| embedded secrets | catches a key that was compiled in by accident |
| cleartext traffic | plain HTTP to an AI provider would leak the key |
| native ABIs | confirms the universal APK really is universal |

## Smoke artifacts (not publishable)

Every push also builds the release variant — the same Gradle tasks a release
uses, signed with the debug key — and uploads the result for 14 days as
`smoke-unsigned-<sha>`, named
`wonder-cv-builder-release-UNSIGNED-smoke.apk` / `.aab`.

They exist to prove the release build compiles (R8 and resource shrinking run
only there, so a missing keep rule is invisible in a debug build) and to give
a build someone can install on a phone and test. They are **not** publishable:
the debug key cannot be used for a store upload, and no update signed with the
real key will install over one. Uninstall before installing a properly signed
build.

## Which artifact for which store

| Store | Artifact | Notes |
|---|---|---|
| Google Play | `wonder-cv-builder-release.aab` | Play generates per-device APKs and signs delivery |
| Cafe Bazaar | `wonder-cv-builder-release.apk` | universal APK, signed with your upload key |
| Myket | `wonder-cv-builder-release.apk` | universal APK, same key |

Both stores also accept an AAB in recent panels, but a **signed universal APK
is the safe common denominator** — and it is what the release workflow
produces. The APK is large (all three ABIs in one file); if a smaller download
matters, `flutter build apk --release --split-per-abi` produces three APKs, but
then you must upload all three and the store must support multi-APK uploads.

## Troubleshooting

**"no release signing configuration found"** — the warning in the Gradle log
means the build fell back to the debug key. Set the environment variables or
`android/key.properties`.

**`INSTALL_FAILED_UPDATE_INCOMPATIBLE`** — an older build signed with a
different key is installed. Uninstall it first.

**The AAB uploads but Play says the version code is already used** — the
`+N` in `pubspec.yaml` must increase for *every* upload, even for a draft.

**Play warns about `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`** — expected.
`androidx.core` declares it to protect receivers the app registers at runtime.
It is signature-level: no other app can obtain it.
