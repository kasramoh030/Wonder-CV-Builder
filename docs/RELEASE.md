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

**Once per project, and then never on a machine that is not yours.**

`keytool` ships with the JDK. The command prompts for the passwords; the
keystore file it writes is the app's identity for the rest of its life on the
store — losing it means you can never update the app under the same package
name.

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storetype JKS
```

- Store `upload-keystore.jks` somewhere durable and private (a password
  manager's file storage, an encrypted volume). **Never** commit it, and never
  put it in the repository folder where a `git add -A` can find it.
- Back it up twice, in two places. There is no recovery path.
- If you already had a debug-signed build installed from an earlier attempt,
  uninstall it before installing a release build: the signatures differ, so
  Android will refuse to update in place.

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

Add four **repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

```bash
base64 -w0 upload-keystore.jks   # Linux
base64 -i upload-keystore.jks    # macOS, no line wrapping
```

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
