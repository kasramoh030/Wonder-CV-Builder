# Wonder CV Builder — International CV & Resume Builder

**Create → Customize → Analyze → Improve → Export**, entirely on device.

Wonder CV Builder builds CVs and resumes for six hiring markets (Iran, Europe,
Germany, the United Kingdom, the United States and international employers)
across eleven document types, analyses them against real ATS conventions, and
exports press-quality, text-searchable PDFs — including Persian, right to
left, with Jalali dates.

The core promise of the product is one sentence long:

> **No internet ≠ No app.**

The Android package name is `dev.cvpro.builder`; the product name shown to
users is **Wonder CV Builder**. (The applicationId is the app's permanent
identity on every store, so it keeps its original value on purpose.)

---

## Status

| Area | State |
| --- | --- |
| Architecture, theme, localisation (EN/FA/DE, RTL) | ✅ |
| Domain model, templates, regional rules engine | ✅ |
| Offline database, repositories | ✅ |
| Builder, preview, PDF engine | ✅ |
| Offline analyser, job matching | ✅ |
| Import (PDF / DOCX / TXT) | ✅ |
| Android release configuration, signing, CI | ✅ |
| Privacy actions (export, restore, delete all data) | ✅ |
| Tests (unit, widget, PDF, rules, backup) | ✅ |
| AI assistant (bring-your-own-key) | ⏳ designed in [`docs/AI_BYOK.md`](docs/AI_BYOK.md), not implemented |
| Image import (OCR) | ⏳ the app says it is unavailable rather than guessing |
| Freemium, payments, ads | ⏳ not implemented; policy recorded in [`docs/FREEMIUM.md`](docs/FREEMIUM.md) |

Nothing in the list is faked: a feature is either implemented and tested, or it
is absent, and the app says so where a user would look for it.

---

## Offline vs. online

Everything that makes the product useful works with the radio turned off:

| Capability | Network required |
| --- | --- |
| Create, edit, duplicate, archive, delete CVs | ❌ |
| Master Profile and multi-CV management | ❌ |
| Versioning and restore | ❌ |
| All 12 templates | ❌ |
| Live preview | ❌ |
| PDF generation, save, open, share, print | ❌ |
| Export all data as a JSON backup, and restore from one | ❌ |
| CV analysis (structure, content, ATS, language) | ❌ |
| Job description analysis and keyword matching | ❌ |
| Import PDF / DOCX / TXT | ❌ |
| AI rewrite and advanced semantic analysis | ✅ (optional, bring your own key) |
| Online/offline indicator | ✅ (a hostname lookup, carrying no user data) |

The app requests exactly one Android permission, `INTERNET`, and only for the
indicator and the optional assistant. See [`docs/PERMISSIONS.md`](docs/PERMISSIONS.md)
and [`docs/PRIVACY.md`](docs/PRIVACY.md).

---

## Architecture

Clean Architecture with a strict dependency rule: `presentation → domain ←
data`. The domain layer has no Flutter, database or network imports.

```
lib/
├── app/            # root widget, router, theme (design system)
├── core/           # cross-cutting services and shared widgets
├── domain/         # entities, enums, rules, template metadata — pure Dart
├── data/           # Drift database, repositories, importers
├── features/       # one folder per screen group (onboarding, builder, …)
├── pdf/            # PDF engine: layout, page-break control, text shaping
└── l10n/           # typed localisations (en, fa, de)
```

| Concern | Choice | Why |
| --- | --- | --- |
| State & DI | Riverpod | Compile-safe providers, testable without a widget tree |
| Database | Drift (SQLite) | Typed queries, reactive streams, migrations |
| Navigation | go_router | Declarative routes, stateful bottom-navigation shell |
| Settings | SharedPreferences | Small, synchronous, needed before first frame |
| Secrets | Android Keystore | API keys never ship inside the APK |
| PDF | `pdf` plus a custom shaper | Pure Dart, embeds fonts, no native dependency |

The regional rules are data, not code: `assets/data/regional_rules/*.json`
describes each market's section order, personal-information conventions, photo
policy, date system, paper size, ATS expectations and academic conventions, and
adding a market is a new file rather than a change to the engine.

---

## Building

Requires Flutter **3.47.5** (stable) and the Android SDK.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-warnings --no-fatal-infos
flutter test

flutter build apk --release        # universal APK — Cafe Bazaar, Myket
flutter build appbundle --release  # AAB — Google Play
```

Release signing (keystore, local `key.properties`, the four CI secrets) is
documented in [`docs/RELEASE.md`](docs/RELEASE.md). A build without signing
material still succeeds, but says loudly in the Gradle log that it fell back to
the debug key.

### Verifying what was built

```bash
export ANDROID_HOME=$HOME/Android/Sdk

# Identity, version, target SDK, permissions, exported components, signature,
# embedded secrets, cleartext traffic, native ABIs — fails on anything that
# would block a store upload.
tools/verify_release_artifact.sh \
  build/app/outputs/flutter-apk/app-release.apk \
  build/app/outputs/bundle/release/app-release.aab
```

### Working without a Dart SDK

`tools/check_dart_syntax.py` is a small local tokenizer check (comments,
strings, raw strings and interpolation stripped, then delimiter balance and a
few always-wrong patterns). It is not a compiler; it is what turns
"CI says line 402" into an answer before a five-minute round trip.

```bash
python3 tools/check_dart_syntax.py
```

Brand assets are generated rather than hand-drawn:

```bash
python3 tools/generate_brand_assets.py   # icons, splash, store graphics
```

---

## Continuous integration

| Workflow | Purpose |
| --- | --- |
| [`analyze.yml`](.github/workflows/analyze.yml) | code generation + `flutter analyze --fatal-warnings` |
| [`test.yml`](.github/workflows/test.yml) | `flutter test` with coverage |
| [`android-debug.yml`](.github/workflows/android-debug.yml) | an installable debug APK per push, inspected with the same script the release uses |
| [`android-release.yml`](.github/workflows/android-release.yml) | the signed, verified, publishable APK and AAB |

All four publish their failure output — and the debug build its inspection
table — as a **commit comment**, readable through the ordinary API. The raw
Actions log requires repository sign-in, which is useless to an agent or a
script working from a shell.

---

## Tests

| Suite | What it holds |
| --- | --- |
| `test/data/regional_rules_test.dart` | Every bundled market parses, matches its id, and keeps sensitive fields off by default |
| `test/domain/regional_rule_engine_test.dart` | Rule resolution: market order leads, the user's order is preserved |
| `test/domain/analyzer_engine_test.dart` | Scoring, findings, priorities, and that the analyser never writes content |
| `test/features/builder_forms_test.dart` | Every section's editor, every field's reader and writer, file naming |
| `test/features/library_backup_test.dart` | Backup file naming, UTF-8 payload, and refusing a foreign file |
| `test/pdf/pdf_rendering_test.dart` | Real PDFs rendered and read back: page count, paper size, Persian, German, no dropped bullets |
| `test/widget/app_smoke_test.dart` | A fresh install boots into onboarding without overflow |

Current results, what is covered and what is not: [`docs/QA.md`](docs/QA.md).

---

## Documentation

| Document | Contents |
| --- | --- |
| [`docs/RELEASE.md`](docs/RELEASE.md) | Keystore, signing, versioning, the four secrets, which artifact for which store |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | What is stored, where, and what the store's data-safety form should say |
| [`docs/PERMISSIONS.md`](docs/PERMISSIONS.md) | Every permission, why, and how to verify it |
| [`docs/QA.md`](docs/QA.md) | Test results, coverage, and the gaps stated plainly |
| [`docs/STORE_CHECKLIST.md`](docs/STORE_CHECKLIST.md) | Play, Cafe Bazaar and Myket requirements, per item |
| [`docs/store/listing.md`](docs/store/listing.md) | Listing copy in English and Persian, feature list, FAQ |
| [`docs/AI_BYOK.md`](docs/AI_BYOK.md) | The contract the AI assistant must satisfy before it ships |
| [`docs/FREEMIUM.md`](docs/FREEMIUM.md) | The agreed free/premium split and the advertising policy |
| [`docs/release-notes/`](docs/release-notes/) | Per-version release notes |

---

## Fonts

Bundled under the SIL Open Font License 1.1 so PDFs render identically on
every device and never need a network fetch:

| Family | Scripts | Licence |
| --- | --- | --- |
| Inter | Latin, Cyrillic, Greek | OFL 1.1 |
| Vazirmatn | Perso-Arabic (fa) | OFL 1.1 |
| Noto Sans | Latin | OFL 1.1 |
| Lato | Latin | OFL 1.1 |
| Open Sans | Latin | OFL 1.1 |

Full licence texts: `assets/fonts/licenses/`.

---

## Privacy in one paragraph

Your CVs are stored on your device and are never uploaded. There is no
account, no analytics, no advertising and no tracking. The only outbound
traffic is a hostname lookup that decides whether to show the offline banner —
it carries nothing about you or your documents. Export a JSON backup whenever
you like, and delete everything with one button. The full account, including
what the store form should say, is in [`docs/PRIVACY.md`](docs/PRIVACY.md).

---

## Disclaimer

CV analysis in this app is based on common resume conventions, ATS practices,
the selected target market, and the information the user provides. **It does
not guarantee employment, university admission, or ATS acceptance.** No format
is described as the only valid one for any country; the regional rules offer
conventions with the reasoning attached.

The AI assistant, when it is implemented, may only restructure and rephrase
text the user has already written. It will not invent experience, employers,
qualifications, dates or metrics, and every suggestion requires explicit
accept / edit / reject. It is described in [`docs/AI_BYOK.md`](docs/AI_BYOK.md)
before it exists, so its security properties are designed rather than
retrofitted.
