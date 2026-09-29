# The AI assistant: bring your own key

**Status: not implemented.** There is no HTTP client in the codebase, no
provider SDK, and no code path that sends a CV anywhere. This document is the
contract the implementation must satisfy — written now, before the feature, so
that the security properties are designed in rather than retrofitted.

It exists because of a specific failure mode: an AI feature bolted onto an
offline app is how a user's CV, their email address and their phone number end
up in a third party's logs without anyone deciding that should happen.

## What already exists, and why

| Piece | Where | Purpose |
|---|---|---|
| `flutter_secure_storage` | `pubspec.yaml` | Where the key will live: Android Keystore-backed, not `SharedPreferences`, not a file |
| `aiProviderId`, `aiModel` | `AppSettings` | Provider and model can already be chosen and persisted |
| `aiConsentGranted` | `AppSettings` | Consent is already a stored, withdrawable state rather than a dialog that is dismissed once |
| Localised consent, key, provider, model, test-connection, and
accept/edit/reject strings | `lib/l10n/strings_{en,fa,de}.dart` | The UI contract exists in all three languages |
| `lib/features/ai/` | (empty directory) | The feature's home |

Nothing about the *content* of a CV has been invented: the analyser still
produces its findings offline, and the assistant is designed to rewrite what
the user already wrote, never to invent a new employer, degree, skill, number
or date.

## The contract

### 1. The key

- Stored **only** in `FlutterSecureStorage` under a single key name, e.g.
  `cvpro.ai.key.<providerId>`.
- Never written to `SharedPreferences`, a log, an analytics event, a crash
  report, a file in `exports/`, or a `SnackBar`.
- Never committed: not in `lib/`, not in `assets/`, not in `pubspec.yaml`.
  There is no `.env` file in this project, and adding one would be a bug, not
  a feature.
- Redacted whenever it must be shown: `sk-…abcd` (first three and last four
  characters), never the whole value — including in error messages returned by
  the provider, which sometimes echo the key they rejected.
- Deletable in one action, with the app saying exactly what deleting it
  removes: the key, and nothing else. The CVs stay.

### 2. Consent

Two separate things, both required:

1. **Standing consent** — a dialog that explains what will be sent, to whom,
   before the first request ever leaves the device. Stored as
   `aiConsentGranted`. Withdrawable in Settings.
2. **Per-request confirmation** — the first request for a given piece of text
   shows what the user is about to send (the field's text, not the whole CV),
   and sends nothing until they confirm.

Neither is a checkbox buried in an onboarding flow. A user who never grants
consent is not asked again for that session.

### 3. What may be sent

Only the text the user is looking at, and only after they confirm:

| Allowed | Never |
|---|---|
| The summary paragraph the user is rewriting | The whole CV "for context", unprompted |
| The bullets of one role, as the user wrote them | Contact details (name, email, phone, city, LinkedIn) — strip them before sending, even if they appear in the selected text |
| A job advert the user pasted for matching | A photo, a national ID, a date of birth, marital status — fields the app already keeps off by default |
| The CV type and market, as bare labels ("professional CV", "Germany") | The user's industry history, saved adverts, version snapshots or analyses |

The rule behind the table: **the request must be reconstructible from what the
user can see on the screen in front of them.** If the user cannot point at what
was sent, it was not consented to.

### 4. The honesty rules (these are product requirements, not model prompts)

The assistant may **rewrite, tighten, structure and translate** what the user
wrote. It may not add facts. Concretely, the UI must reject a suggestion that
introduces:

- an employer, institution, job title, degree or certificate that is not in
  the CV;
- a technology, tool or skill the user has not listed;
- a number, percentage, currency amount or date range that does not appear in
  the source text;
- a claim of seniority ("led a team of 12") not evidenced in the CV.

Enforcement is layered, because a prompt is a request and not a guarantee:

1. **Prompt** — the system prompt states the constraint, in the user's
   language.
2. **Validation** — the response is checked against the source text: new
   capitalised proper nouns, new digits, and new skill-like terms are flagged.
3. **Presentation** — a flagged suggestion is shown with the specific addition
   highlighted and the question "the app does not know this — do you have it?"
   rather than being silently applied.
4. **User decision** — every suggestion is **Accept / Edit / Reject**. Nothing
   is written into the document without one of the first two.

When the CV lacks the data to answer (for example, "improve this bullet's
numbers" with no numbers in it), the assistant asks the user a question
instead of inventing an answer.

### 5. Transport

- HTTPS only, to the provider the user chose. The app targets SDK 36, where
  cleartext HTTP is disabled by the platform; do not add
  `android:usesCleartextTraffic`.
- No certificate pinning by default. It would be more secure in theory and
  worse in practice: pinning a third-party provider's certificate in a
  client the user cannot update quickly breaks the feature for everyone when
  the provider rotates it. The key is the user's, not the developer's, and the
  channel is the platform's TLS stack.
- Timeouts on every call. A hung request must fail visibly — "the assistant
  did not answer" is a supported outcome, and the offline core keeps working.
- No retry that could send the same text twice without the user asking twice.

### 6. Cost, and being honest about it

The user's key is billed to the user. Before the first request, say so in
plain language, in all three languages. Do not use a CV as a way to spend
someone's credit silently.

## Suggested implementation shape

```
lib/features/ai/
  ai_providers.dart          # provider/model catalogue, capability flags
  ai_client.dart             # one interface, one HTTPS implementation
  ai_key_store.dart          # FlutterSecureStorage wrapper, redaction helpers
  ai_consent.dart            # consent state, withdrawal, per-request gate
  suggestion_validator.dart  # the honesty rules above, as pure Dart over text
  ai_assistant_panel.dart    # Accept / Edit / Reject UI
```

`ai_client.dart` should take the key as a parameter and never read storage
itself — that makes it possible to test the client with a fake transport and
impossible for a log line to reach the key.

## Testing requirements before this ships

- A widget test that a request is impossible without consent.
- A unit test that the validator flags every invented-fact category above.
- A unit test that the key never appears in `toString()`, in an error message,
  or in a `SnackBar` payload.
- A unit test that withdrawal of consent removes the key from secure storage.
- A test that the analyser's offline path still works with the AI feature
  entirely absent (the app must be useful with no key, forever).

## What is not happening

There is no free tier of AI requests, no developer-supplied key, no proxy
service that would let the app "just work" for everyone. Each of those turns
the developer into the processor of every user's CV, which is the opposite of
this app's stated design.
