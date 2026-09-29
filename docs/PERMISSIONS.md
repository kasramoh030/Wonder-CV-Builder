# Android permissions

The manifest declares **one** permission. That is a product decision, not an
oversight: everything the app can do without a network — writing a CV,
analysing it, importing a file, generating and printing a PDF — works with no
permission at all.

## What is declared

| Permission | Why | Necessary? | Removable? |
|---|---|---|---|
| `android.permission.INTERNET` | Two optional features contact a server: the reachability probe behind the online/offline indicator, and the AI assistant (a key the user supplies) when the user explicitly asks for it. | Yes, for those two features. The offline core does not use it. | Removing it is possible but would remove the online/offline indicator and the consent-gated assistant. Kept. |

### Declared, but by a library rather than by this app

| Permission | Origin | Why |
|---|---|---|
| `dev.cvpro.builder.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | `androidx.core` (merged from its manifest) | A signature-level permission the library defines to protect receivers the app registers at runtime. No other app can obtain it. It appears in the merged manifest of any modern AndroidX app. |

The artifact inspection (`tools/verify_release_artifact.sh`) fails on any
permission other than these two, so a dependency cannot quietly add a third.

## What is deliberately absent

| Permission | Not needed because |
|---|---|
| `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_*` | The app never browses the file system. Importing and photo selection go through the system document/photo picker, which hands back a single URI the user chose. Exports are written into the app's own directory, which needs no permission, and are then offered to the system share sheet or print service. |
| `CAMERA` | Taking a photo is not offered; only choosing an existing one, through the picker (which runs in another app that owns the camera permission). |
| `RECORD_AUDIO` | No audio feature exists. |
| `POST_NOTIFICATIONS` | The app never posts a notification. |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Location is never requested, inferred or stored. The country of an application is a setting the user picks. |
| `READ_CONTACTS` | References are typed by hand. |
| `AD_ID` | No advertising SDK is integrated (see `docs/STORE_CHECKLIST.md`). |
| `QUERY_ALL_PACKAGES` | Only `ACTION_PROCESS_TEXT` is queried, which does not require the broad visibility permission. |

## Hardware features

No `<uses-feature>` element is declared. The app does not require a camera, a
GPS receiver, a telephony radio or any sensor, and it must remain installable
on tablets, Chromebooks and devices without them.

## Verifying

The release workflow runs the inspection automatically. Locally:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
$ANDROID_HOME/build-tools/*/aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep uses-permission
```

Expect exactly `android.permission.INTERNET` (plus the androidx receiver
permission described above).
