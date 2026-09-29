# Free, premium, and ads

**Status: nothing here is implemented, and nothing is mocked.** Every feature
in the app today is free and complete: building, analysing, importing,
exporting and printing a CV all work with no account, no purchase and no
network. That is a deliberate launch position, not an unfinished one — a CV
writer that works is the product; a paywall is a business decision that has
not been made yet.

This file records the intended split so that, when the decision is made, it is
implemented once, in the right place, instead of being sprinkled through the
UI.

## The proposed split

| Capability | Free | Premium | Why |
|---|---|---|---|
| Create / edit / delete / duplicate CVs | yes | — | The core promise. Never gated. |
| Offline PDF generation | yes | — | A CV you cannot export is not a CV. Never gated. |
| Offline analyser (score, ATS checks, recommendations) | yes | — | The honesty features are what makes the app trustworthy; gating advice is how you sell an empty upgrade. |
| Market rule packs (Iran, Europe, Germany, UK, US, international) | yes | — | Adding a market is a JSON file; there is nothing to meter. |
| Templates | the bundled set | premium templates | The natural axis: taste, not capability. Free users keep every layout they can already print. |
| Advanced (online, BYOK) analysis: semantics, job matching | — | yes | It costs the *user* money per call. Charging for access on top is reasonable only because it also costs us the feature work. |
| Job-description matching | basic | advanced | Keyword overlap is free; deeper skill-gap analysis is premium. |
| AI assistant (user's own key) | — | yes | Same reasoning as advanced analysis. The user's key pays for the call; the subscription pays for the feature. |
| Custom fonts and accent colours | partial | full | Free: the bundled fonts and a small palette. |
| Import (PDF/DOCX/TXT) | yes | — | Nobody should be locked out of their own existing CV. |
| Ad-free | — | yes | See below. |
| CV limit | unlimited | unlimited | A limit on documents punishes the exact behaviour the app encourages. If a limit is ever needed for cost reasons, it belongs on *server* features, not on local ones. |

## How the split must be implemented

- **One authority.** A single `Entitlement` value in the domain layer, read
  through one provider, so "is this premium?" has one answer. Nothing in a
  screen may invent its own rule.
- **Capability checks, not feature flags sprayed through widgets.** A screen
  asks for an entitlement and chooses one of two presentations; it does not
  know what a store SKU is.
- **No billing code in the widget tree.** Google Play Billing, Bazaar's IAP
  and Myket's are three different integrations behind one interface. The app
  must work with none of them present (a build without billing should compile
  and run, with premium simply unavailable).
- **Restore purchases** must exist on day one. A user who reinstalls must not
  lose what they paid for.
- **Never gate data.** Reading, editing, exporting and deleting a CV the user
  already created stays free forever, even if a subscription lapses. Holding
  someone's own document hostage is the one thing this app must never do.

## Ads — the policy, before any SDK is added

Not integrated today. If they are ever added:

| Rule | Reason |
|---|---|
| Never in the PDF, never on the preview screen | The document is the product |
| Never inside the builder or any editing form | Interrupting writing is destructive to trust and to the work |
| Never between "generate" and "your file is ready" | That moment is the whole point of the app |
| Allowed on: the dashboard, the template gallery, the empty states | Places where a user is browsing, not working |
| Removable by purchase | Stated in the listing |
| No CV data to the ad SDK | The SDK gets an ad request, not the user's name, email or content; no custom audiences built from CV fields |
| No personalised ads by default in the free tier | Personalised advertising needs an advertising ID and a consent flow per region; the default is the non-personalised request |
| `AD_ID` permission | Only declared if an SDK genuinely requires it, and only alongside a Data safety update |

Each of those is a review question for the ad network as much as for the store.

## What must be true before charging anyone

1. The premium features exist and are tested. (Today: none of them do.)
2. `docs/AI_BYOK.md` is implemented — a paid tier that promises AI cannot
   ship on top of a feature that does not exist.
3. Prices, refund policy and the store's tax handling are decided by the
   owner.
4. The privacy policy is updated to mention purchases (there is a
   `docs/PRIVACY.md` section waiting for it).
5. Store listings say plainly what is free and what is not.
