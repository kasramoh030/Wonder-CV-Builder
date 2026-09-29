# QA report — v1.0.0

Run on every push by GitHub Actions (`.github/workflows/`), and reproducible
locally with the commands below. The environment this was developed in has no
Flutter SDK and no Android SDK, so every result in the table comes from CI or
from a static inspection of the built artifact — that limitation is stated
rather than hidden, and it is the reason the store screenshot step is still
outstanding.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-warnings --no-fatal-infos
flutter test --coverage
flutter build apk --release
flutter build appbundle --release
tools/verify_release_artifact.sh <apk> <aab>
```

## Results

| CHECK | RESULT | DETAILS |
|---|---|---|
| Code generation (drift, json_serializable) | PASS | `build_runner` clean, no uncommitted generated drift |
| `flutter analyze --fatal-warnings` | PASS | 0 errors, 0 warnings, 0 infos |
| Unit + widget tests | PASS | 7 suites: regional rules, analyser, rule engine, builder forms, app boot, PDF rendering, backup files |
| Debug APK | PASS | Per push; inspected automatically |
| Release APK build | PASS | The release variant is built on every push; R8 runs there, which is where the missing-keep-rule failure appeared |
| Release AAB build | PASS | Same build, bundle task |
| Release APK (signed with the upload key) | BLOCKED | Four signing secrets are not configured on this repository — `docs/RELEASE.md`. Until then, the smoke artifacts are signed with the debug key and are named `…-UNSIGNED-smoke` so they cannot be mistaken for publishable |
| Artifact inspection | PASS | Package, version, targetSdk 36, INTERNET only, one exported component, no embedded secrets, no cleartext traffic |
| Manual device run | NOT RUN | No Android runtime in this environment; see `docs/STORE_CHECKLIST.md` |
| Screenshots | BLOCKED | Must be captured on a real device or emulator |

## What the tests cover

| Suite | Covered |
|---|---|
| `test/data/regional_rules_test.dart` | All six bundled packs parse and match their id; section order, required/recommended sections, date-system defaults, page guidance, advisory wording; sensitive fields off by default everywhere; Germany's photo optional; US Letter with a one-page ideal; Iran offering Jalali without forcing it; no advisist phrased as a legal requirement; malformed bundles degrade to the neutral profile |
| `test/domain/analyzer_engine_test.dart` | A strong CV scores well with no critical findings; an empty CV fails loudly; every recommendation carries a priority and a category; weak writing is detected by pattern; the region changes expectations and weights; a missing required section is reported; a photo in a discouraging market is flagged; advisories become findings; a decorative template costs ATS points; the job-match dimension exists only with an advert; stats describe the document measured; the analyser never writes content |
| `test/domain/regional_rule_engine_test.dart` | Market order leads, user order preserved; synthetic photo policy |
| `test/features/builder_forms_test.dart` | Every section has an editor; every record field's reader and writer agree (including clearing a date); a created record lands in the document; bullet parsing keeps a mid-sentence dash; export file names are safe and fall back correctly |
| `test/widget/app_smoke_test.dart` | A fresh install boots into onboarding, and the app renders without overflow at 320×640 |
| `test/pdf/pdf_rendering_test.dart` | Real documents rendered through the real engine and read back through the importer's extractor: a one-page CV with searchable contact details, a twelve-role CV spilling to a second page without shrinking the type, Persian text recovered as Persian (presentation forms folded, reading order restored), German diacritics, US Letter for the United States and never for A4, every bullet printed, and the export file-naming rules |
| `test/features/library_backup_test.dart` | The backup file name is dated and file-system safe; the payload is indented UTF-8 JSON that survives Persian and numbers; a restore accepts only a backup this app wrote and refuses a foreign file, non-JSON, non-object JSON, non-UTF-8 bytes, an empty file and a file truncated mid-write — each of which leaves the library untouched |

## Not covered, and why

| Area | Reason | What would cover it |
|---|---|---|
| PDF rendering on a device (opened in a viewer) | No Flutter SDK and no emulator here | Open a generated file on a real device; the engine's output is already parsed back by `test/pdf/pdf_rendering_test.dart` |
| Import from a real PDF/DOCX | Needs fixture files and a device run | Golden files under `test/fixtures/` |
| Jalali date rendering | Covered by unit tests only for conversion | Golden widget test with a Persian locale |
| RTL layout at scale | Smoke test only | Golden tests in `fa` with `TextDirection.rtl` |
| Upgrade path from a previous version | No previous release exists | A migration test using `AppDatabase` with an old schema |
