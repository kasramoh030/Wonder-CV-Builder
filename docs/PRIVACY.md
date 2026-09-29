# Privacy and data safety

Wonder CV Builder is **local-first**: the CVs a user writes are stored on their
own device, are never uploaded, and are readable by nobody but them. There is
no account, no sign-up and no server belonging to this project.

This document is the engineering record behind the store's Data Safety /
privacy declarations. It says what the code actually does, so the declarations
can be answered without guessing.

## What the app stores, and where

| Data | Where | Personal? | Encrypted? | Retention | Leaves the device? |
|---|---|---|---|---|---|
| CV content: name, email, phone, city, country, links, summary | SQLite database in the app's private storage (`/data/data/dev.cvpro.builder/`) | **Yes** | No (Android app sandbox; see below) | Until the user deletes it | **No**, unless a future AI request is explicitly confirmed |
| Work history: employers, dates, duties, achievements | Same database | **Yes** | No | Until deleted | No |
| Education, skills, languages, projects, certificates | Same database | **Yes** | No | Until deleted | No |
| Optional sensitive fields: date of birth, gender, nationality, marital status, national ID, military service | Same database — **off by default in every market**, and switched on only by the user | **Yes** | No | Until deleted | No |
| Photo (only if the user chooses one) | Copied into the app's private files directory | **Yes** | No | Until deleted | No — never sent to an ad SDK or analytics |
| Version snapshots and job adverts the user chose to save | Same database | **Yes** | No | Until deleted | No |
| Analyses | Same database | Yes (derived from the CV) | No | Until deleted | No |
| App settings (theme, language, market, paper size, calendar) | `SharedPreferences` | No | No | Until reset | No |
| Generated PDFs | The app's documents directory, `exports/` | **Yes** | No | Until the user deletes them | No |
| AI provider key (not implemented yet) | — | — | — | — | — |

### "Encrypted?" — the honest answer

The CV database and the files are **not** encrypted by the app. They live in
the app's private sandbox, which Android protects from other apps by UID
isolation; on an unrooted device another app cannot read them. They are
readable by anyone who has root, physical access with a debug bridge, or a
full-device backup that the user themselves exported.

That is the same posture as the phone's own notes and contacts apps. If a
user's threat model requires more, the app should not be where their CV lives.

### Android backup

`android:allowBackup="true"` with explicit rules
(`res/xml/backup_rules.xml`, `res/xml/data_extraction_rules.xml`):

- **included**: the database, the app's files, shared preferences — so a lost
  phone does not mean a lost CV;
- **excluded**: the generated `exports/` directory — re-creatable output that
  would otherwise bloat a backup.

Cloud backup goes to the **user's own Google account**, controlled by them in
Android settings. The developer never receives a copy. Setting
`allowBackup="false"` would be more private but would silently delete a user's
only copy of a document they spent a week writing; the rules above are the
deliberate trade-off, and the store's Data Safety form should say "data is
stored on the device and may be included in the user's own device backup".

## What leaves the device today

Exactly one thing, and it contains no user data:

| Destination | What is sent | When | User data? |
|---|---|---|---|
| `one.one.one.one` and `dns.google` (DNS lookups, UDP/53) | A DNS query for a hostname, to decide whether the app should show "offline" or "online" | Every 30 seconds while the app is in the foreground | **No.** A hostname in a DNS query says nothing about the user or their CV. |

This is worth stating plainly because a DNS probe is still network traffic: a
network observer can see that the device resolved `one.one.one.one`, and can
infer that the app is installed, though not which CVs exist. The probe exists
so the app can tell the user the truth about whether the AI features could
work, instead of failing unhelpfully.

**No analytics, crash reporting, attribution or advertising SDK is
integrated.** There is no first-party telemetry either. `AppSettings` has an
`analyticsEnabled` field; it defaults to `false`, and nothing currently reads
it as anything but a preference.

## The AI assistant (not implemented — and the rules it must follow)

The app does not currently send anything to an AI provider: there is no HTTP
client in the codebase. `docs/AI_BYOK.md` defines the contract the
implementation must satisfy. In summary:

- nothing is ever sent without explicit, per-request consent;
- the key is the user's own, stored in the Android Keystore, never in the
  repository;
- the request never carries data the user did not choose to include;
- the user can delete the key at any time, and the app tells them what that
  removes.

## User rights, as implemented

| Right | Where it is in the app | Status |
|---|---|---|
| See everything stored | Open any CV; every field the app holds is visible in the builder | shipped |
| Correct anything | Edit any field; edits are saved automatically | shipped |
| Export a copy | Settings → Privacy → Export all data writes one JSON file to a location the user picks (`LibraryBackupService`, `ResumeRepository.exportLibrary`); the PDF export has its own share/save/print sheet | export shipped |
| Delete a document | Archive (recoverable) or delete from the dashboard | shipped |
| Delete everything | Settings → Privacy → Delete all data (`DataWipeService.wipe`) | shipped |
| Restore from a backup | Settings → Privacy → Restore from a backup: the file must parse as a backup this app wrote, the user confirms against the number of documents found in it, and the import keeps existing CVs and updates only the ids it finds | shipped |
| Withdraw consent | Not applicable yet; no consent is currently granted to anything | not applicable |

## Store declarations — Google Play Data safety

The answers the form expects, with the reason:

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing is transmitted to the developer or to a third party. Data that never leaves the device is not "collection" under Play's definition. |
| Data processed ephemerally? | Not applicable | No server processing exists. |
| Data shared with third parties? | **No** | No SDK receives user data. |
| Is data encrypted in transit? | Not applicable | Nothing is transmitted. (If an AI request is added later, the answer becomes "yes" for exactly that path, over HTTPS.) |
| Can users request data deletion? | **Yes**, in-app | Settings → Delete all data, plus per-document delete |
| Data types to tick as *not collected* | Location, Personal info, Financial info, Health, Messages, Photos (except a photo the user themselves attaches, which is stored locally and never transmitted), Files, Calendar, Contacts, App activity, Web browsing, App info and performance, Device or other IDs | See the table above |
| Ads / advertising ID | **No ads** | No ad SDK, no `AD_ID` permission |
| Content rating | Everyone | A CV editor with no user-generated content sharing, no ads, no purchases, no social features |

**One nuance to answer carefully:** Play's own backup mechanism (Android
Auto Backup) copies app data to the user's Google Drive. In the Data safety
form this is not "collection by the developer" — Google's own guidance treats
the user's device backup as outside the app's data collection — but the
listing's privacy policy should still mention that the OS may back up app
data, which the policy text below does.

## Privacy policy text (to be hosted at a public URL)

Store listings require a public URL. This is the text; host it (GitHub Pages
is enough) and put the URL in the listings.

> **Wonder CV Builder — Privacy Policy**
>
> Wonder CV Builder is an offline CV builder. Your CVs are stored on your
> device and are not uploaded to us. We have no server that receives your
> documents, and there is no account to create.
>
> **What we store.** The CVs, version snapshots, saved job adverts, analyses
> and exported PDFs you create, in the app's private storage on your device.
> Your app settings are stored on the device too.
>
> **What we collect.** Nothing. The app contains no analytics, no crash
> reporting, no advertising and no tracking. We do not have access to your
> name, your contact details, your work history or your documents.
>
> **What leaves your device.** The app checks whether the device is online by
> looking up a public hostname (`one.one.one.one`, operated by Cloudflare, or
> `dns.google`). That check sends no information about you or your CV — only
> the hostname being resolved. It exists so the app can tell you honestly
> whether its optional online features are available.
>
> **Optional AI features.** If you later enable an AI assistant by entering
> your own API key for a provider you choose, the text you explicitly submit
> is sent to that provider under their terms, using your key. Nothing is sent
> before you confirm a specific request, and your key is stored in Android's
> secure storage on your device. You can delete the key at any time in
> Settings.
>
> **Device backup.** Android may include app data in the backup of your own
> Google account, which you control in Android's settings. We never receive
> that backup.
>
> **Permissions.** The app requests one permission: internet access, needed by
> the features described above. It does not request access to your camera,
> microphone, contacts, location or files.
>
> **Children.** The app is not directed at children under 13.
>
> **Restoring a backup.** Settings → Privacy → Restore from a backup reads a
> file you exported earlier. It never deletes anything: documents in the file
> are added, and a document with the same identifier is updated. A file that
> is not a Wonder CV backup, or that is damaged, changes nothing and says so.
>
> **Deleting your data.** Settings → Privacy → Delete all data removes every
> CV, its saved versions, its analyses, the saved job adverts, the generated
> PDF files and the copies the file picker kept in its cache. Your language,
> theme and market preferences are kept, so the app does not walk you through
> setup again. Deleting the app removes everything the app stored.
>
> **Changes.** If a future version changes any of the above — for example by
> adding an optional online service — this policy will say so before that
> version is published, and the store listing will be updated.
>
> **Contact.** <your contact email>

## Re-auditing this document

Re-read it whenever any of these change: a new dependency, a new permission,
a new SDK, a new network call, or a change to `allowBackup`. The claims above
are verifiable from the repository:

```bash
# The only permission in the manifest
grep uses-permission android/app/src/main/AndroidManifest.xml

# Every network call the Dart code can make
grep -rn "InternetAddress\|HttpClient\|package:http" lib/

# Every third-party SDK (nothing to find means nothing to declare)
grep -rn "id(\"com\." android/app/build.gradle.kts
```
