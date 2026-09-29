# Store readiness checklist

Status of each requirement for the three target stores. Where the current
requirement is something only the store's own panel can confirm, that is said
rather than guessed — a checklist that invents a rule is worse than no
checklist.

Legend: **done** · **todo** (work remains) · **verify in panel** (depends on
the store's current documentation or on an account only the owner has) ·
**n/a**

## Everything, everywhere

| Item | Status | Notes |
|---|---|---|
| applicationId `dev.cvpro.builder` | done | Store identity; changing it later starts a new app |
| versionName / versionCode from `pubspec.yaml` | done | `1.0.0` / `1` |
| targetSdk 36 | done | Verified in CI on the built artifact |
| Release signing | done (code) / todo (keys) | Four GitHub secrets must be added — `docs/RELEASE.md` |
| Signed AAB | todo | Built by the release workflow once secrets exist |
| Signed universal APK | todo | Same |
| App icon (512×512) | done | `docs/store/icon-512.png` |
| Adaptive icon | done | `res/mipmap-anydpi-v26/`, with a monochrome layer for themed icons |
| Splash screen | done | Brand gradient + mark, plus the Android 12+ system splash |
| Privacy policy | done (text) / todo (URL) | `docs/PRIVACY.md`; must be hosted at a public URL |
| Data Safety answers | done (answers) / todo (form) | Table in `docs/PRIVACY.md` |
| Permissions declared | done | INTERNET only — `docs/PERMISSIONS.md` |
| Content rating | todo | Likely "Everyone", but the questionnaire must be filled in the panel |
| Screenshots | **todo — blocker** | Real device screenshots cannot be produced from this environment; see below |
| Store descriptions | done | `docs/store/listing.md`, English and Persian |
| Feature graphic | done | `docs/store/feature-graphic.png` (1024×500) |
| Release notes | done | `docs/release-notes/` |
| Support contact / developer info | todo | Needs the owner's email and, for Bazaar, a phone number |

### The screenshot blocker, plainly

Screenshots must show the real app. This environment cannot run it — no
Android runtime, no emulator, and the Flutter SDK is not installable here — so
any screenshot produced here would be a mock-up, and a store listing built on
mock-ups is a review rejection and a false advertisement. The workflow that
does produce them:

```bash
# on a machine with a device or emulator attached
flutter run --release
# or, once the app is on a phone:
adb exec-out screencap -p > shot.png
```

Minimum set (Play requires 2, allows 8; Bazaar and Myket want 3–8):

1. Dashboard with two sample CVs, dark and light
2. Builder with the section list and preview side by side (tablet) or tabs (phone)
3. Market selection (the country cards)
4. The analysis report with a score and the recommendation list
5. Job-advert comparison showing found vs missing keywords
6. The template gallery

## Google Play

| Requirement | Status | Notes |
|---|---|---|
| AAB upload | todo | From the release workflow |
| targetSdk current | done | 36 |
| Play App Signing | verify in panel | Play re-signs with its own key; upload key is ours |
| Data safety form | done (answers) / todo (form) | `docs/PRIVACY.md` |
| Privacy policy URL | todo | Must be public and reachable |
| Content rating questionnaire | todo | In panel |
| Ads declaration | done | "No ads" — no ad SDK is integrated |
| News / COVID / health / government app declarations | n/a | Not applicable |
| Financial features declaration | n/a | No payments in this version |
| Target audience and content | todo | Recommend 18+ or 13+; a CV tool is not child-directed |
| Store listing: title ≤ 30 chars | done | "Wonder CV Builder" (17) |
| Store listing: short description ≤ 80 chars | done | See `docs/store/listing.md` |
| Store listing: full description ≤ 4000 chars | done | Same |
| App category | todo | In panel; "Productivity" |
| Contact email | todo | Required; owner-supplied |
| Screenshots (2–8, phone) | **todo — blocker** | See above |
| Feature graphic 1024×500 | done | |
| Icon 512×512 | done | |
| Tablet screenshots | optional | Required only if declaring tablet support in the listing |
| Closed testing requirement for new personal accounts | verify in panel | Play has required a closed test with a minimum number of testers before production for new personal developer accounts; confirm the current rule for your account type |
| Release rollout | todo | Suggest staged: internal → closed → production |

## Cafe Bazaar (کافه بازار)

| Requirement | Status | Notes |
|---|---|---|
| Package name | done | `dev.cvpro.builder` |
| Signed APK or AAB | todo | Universal signed APK is the safe choice |
| Version code increase per upload | done | Policy exists in `docs/RELEASE.md` |
| App name (Persian) | done | `docs/store/listing.md` |
| Short + full description (Persian) | done | Same file |
| Icon 512×512 | done | |
| Screenshots (3–8) | **todo — blocker** | Real device screenshots |
| Privacy policy | todo | Bazaar requires a privacy statement for apps that handle user data; the text exists, it needs hosting |
| Permissions justification | done | INTERNET only; text in `docs/PERMISSIONS.md` |
| Developer information (name, email, phone) | todo | Owner-supplied; Bazaar asks for contact details |
| Category selection | todo | In panel |
| Content rating / age range | todo | In panel |
| Payment / in-app purchase registration | n/a | No payments in this version |
| Iranian hosting requirement for network services | n/a today | App works fully offline; DNS probes are the only outbound traffic. If online AI is added later, this rule needs a fresh look |
| Marketplace-specific rules for foreign services | verify in panel | Requirements change; check the current developer documentation before submitting |

## Myket (مایکت)

| Requirement | Status | Notes |
|---|---|---|
| Package name | done | Same APK as Bazaar |
| Signed APK or AAB | todo | Same artifact |
| Icon 512×512 | done | |
| Screenshots | **todo — blocker** | Real device screenshots |
| Description (Persian) | done | `docs/store/listing.md` |
| Privacy policy | todo | Same text, same URL issue |
| Permissions declared accurately | done | INTERNET only |
| Developer account information | todo | Owner-supplied |
| Category | todo | In panel |
| Content rating | todo | In panel |

## Freemium, payments and ads — current state

Nothing is implemented, and nothing has been faked.

| Item | Status | Notes |
|---|---|---|
| Free tier | n/a | Every feature in the app today is free and fully functional |
| Premium tier | not implemented | No paywall, no entitlement check, no billing client. `docs/FREEMIUM.md` records the agreed split for when it is built |
| In-app purchase | not implemented | Deliberately no mock subscription: a fake entitlement system produces real support tickets and no revenue |
| Ads | not integrated | No ad SDK, no `AD_ID` permission |
| Policy for future ads | decided | Never in a PDF, never in the preview, never mid-form. If ads are ever added they must sit on the dashboard, be removable by a purchase, and carry no CV data — see `docs/FREEMIUM.md` |

## Verify-before-submitting commands

```bash
# The artifact a reviewer will inspect
export ANDROID_HOME=$HOME/Android/Sdk
tools/verify_release_artifact.sh dist/wonder-cv-builder-release.apk dist/wonder-cv-builder-release.aab

# Permissions the store will list
$ANDROID_HOME/build-tools/*/aapt2 dump badging dist/wonder-cv-builder-release.apk | grep uses-permission

# The version being published
grep '^version:' pubspec.yaml
```
