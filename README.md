# CV Pro — International CV & Resume Builder

**Create → Customize → Analyze → Improve → Export**, entirely on device.

CV Pro builds CVs and resumes for six hiring markets (Iran, Europe, Germany,
the United Kingdom, the United States and international employers) across
eleven document types, analyses them against real ATS conventions, and
exports press-quality, text-searchable PDFs.

The core promise of the product is one sentence long:

> **No internet ≠ No app.**

---

## Status

| Area | State |
| --- | --- |
| Architecture, theme, localisation (EN/FA/DE, RTL) | ✅ |
| Domain model, templates, regional rules engine | 🚧 in progress |
| Offline database, repositories | 🚧 in progress |
| Builder, preview, PDF engine | 🚧 in progress |
| Offline analyser, job matching | 🚧 in progress |
| AI assistant (bring-your-own-key) | 🚧 in progress |
| Import (PDF / DOCX / TXT) | 🚧 in progress |
| Tests, release configuration | 🚧 in progress |

The table is updated as phases land; see [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Offline vs. online

Everything that makes the product useful works with the radio turned off:

| Capability | Network required |
| --- | --- |
| Create, edit, duplicate, delete CVs | ❌ |
| Master Profile and multi-CV management | ❌ |
| Versioning and restore | ❌ |
| All 12 templates | ❌ |
| Live preview | ❌ |
| PDF generation, save, open, share, print | ❌ |
| Export / import JSON backup | ❌ |
| CV analysis (structure, content, ATS, language) | ❌ |
| Job description analysis and keyword matching | ❌ |
| Import PDF / DOCX / TXT | ❌ |
| AI rewrite and advanced semantic analysis | ✅ (optional, BYO key) |
| Template and regional-rule updates | ✅ (optional) |

The app requests exactly one Android permission, `INTERNET`, and only for
the two optional online features. See
[`docs/PRIVACY.md`](docs/PRIVACY.md).

---

## Architecture

Clean Architecture with a strict dependency rule: `presentation → domain ←
data`. The domain layer has no Flutter, database or network imports.

```
lib/
├── app/            # root widget, router, theme (design system)
├── core/           # cross-cutting services and shared widgets
├── domain/         # entities, enums, rules, template metadata — pure Dart
├── data/           # Drift database, repositories, seed data
├── features/       # one folder per screen group (onboarding, builder, …)
├── pdf/            # PDF engine: layout, page-break control, text shaping
└── l10n/           # typed localisations (en, fa, de)
```

| Concern | Choice | Why |
| --- | --- | --- |
| State & DI | Riverpod 2 | Compile-safe providers, testable without a widget tree |
| Database | Drift (SQLite) | Typed queries, reactive streams, migrations |
| Navigation | go_router | Declarative routes, stateful bottom-navigation shell |
| Settings | SharedPreferences | Small, synchronous, needed before first frame |
| Secrets | Android Keystore | API keys never ship inside the APK |
| PDF | `pdf` + custom shaper | Pure Dart, embeds fonts, no native dependency |

Full rationale: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Building

Requires Flutter **3.47.5** (stable) and the Android SDK.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build appbundle --release
```

Release builds are produced by CI
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)), which uploads a
split-per-ABI APK set and an AAB for every green commit.

---

## Fonts

Bundled under the SIL Open Font License 1.1 so PDFs render identically on
every device and never need a network fetch:

| Family | Scripts | Licence |
| --- | --- | --- |
| Inter | Latin, Cyrillic, Greek | OFL 1.1 |
| Vazirmatn | Perso-Arabic (fa) | OFL 1.1 |
| Lato | Latin | OFL 1.1 |
| Noto Sans | Latin | OFL 1.1 |
| Open Sans | Latin | OFL 1.1 |

Full licence texts: `assets/fonts/licenses/`.

---

## Disclaimer

CV analysis in this app is based on common resume conventions, ATS practices,
the selected target market, and the information the user provides. **It does
not guarantee employment, university admission, or ATS acceptance.**

The AI assistant may only restructure and rephrase text the user has already
written. It will not invent experience, employers, qualifications, dates or
metrics, and every suggestion requires explicit accept / edit / reject.
