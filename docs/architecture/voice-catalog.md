# Issue-backed community voices (MVP)

The public catalog lives in `JevonsCode/dingdong-voices`. The application and static catalog do not need a server, OAuth app, database, or bundled API token. GitHub is the public submission/discussion/reaction store. No application update is required for a newly reviewed submission.

## Public contract

- An open, non-PR Issue must have the `voice-approved` label. The API supplies title, login, creation/update dates and reaction totals, not claims in Markdown.
- The Issue Form uses `Description`, `Audio`, `License`, `Source` and `Rights confirmation` headings. The Audio field contains one HTTPS GitHub file attachment URL ending in `.wav`; external file hosts, credentials, ports, query strings and fragments are not accepted.
- Rights confirmation must contain a checked checkbox. Submitting a meme does not establish redistribution rights. No third-party recording is downloaded or included as a seed.
- Text is rendered as plain text. No HTML or Issue scripts execute.
- Public files are at most 5 MiB and exactly one standard PCM WAV `fmt ` and `data` chunk, with a consistent RIFF length, mono/stereo, 8/16/24/32-bit samples, 8–192 kHz rate, consistent frame/block/byte rates and at most 3 seconds of sample frames. Only zero-length PCM extensions are accepted. These public constraints do **not** alter local custom imports (15 seconds, 5 MiB, 64 library entries).

## Approval pins content, not just a mutable label

A maintainer reviews provenance/license and audio, then posts a plain JSON comment:

```json
{"dingdongVoiceApproval":1,"issue":7,"metadataSha256":"64 lowercase hex characters","audioSha256":"64 lowercase hex characters"}
```

The entire body must be this JSON, optionally preceded by the exact first line `🕵🏻‍♀️[DOT]` and a newline. No arbitrary wrapper, Markdown or trailing text is accepted.

The comment must be authored by the repository owner's API account ID `36203025` with API association `OWNER`. Account display names or text claiming ownership are insufficient. This owner binding must be deliberately updated if repository ownership changes.

The metadata digest is SHA-256 over UTF-8 JSON serialization of this exact array:

```text
[raw API issue.title, Description.trim(), extracted Audio URL, Source.trim(), License.trim(), Rights confirmation.trim()]
```

The shared fixture under `test/fixtures/voices/` is the executable cross-language contract. The title is not trimmed before hashing. Newlines and escaped text are preserved as JSON values. Approval is checked lazily before accessing audio so listing a page does not consume one API request per card. Discovery cards are untrusted plain-text metadata; an approval label is not sufficient to play or import bytes.

Every audio action re-fetches the current Issue, validates state/label/current fields, finds an owner comment matching those fields, downloads with bounded time/size/redirect policies, validates PCM frames and compares the actual file SHA-256 with the approval. Edited metadata or replaced bytes cannot reuse an old approval. Removing the label or closing the Issue stops new imports. Already downloaded user-owned copies remain usable offline; moderation does not silently delete local files.

## Subscriptions on a desktop

Settings → Community voices loads the public catalog only when the user opens it. A pasted exact catalog Issue link can be looked up directly even when its page has not yet loaded. Subscribe explicitly downloads and validates that voice into content-addressed app storage. The audio library records its source Issue, author, approved license/provenance and audio/metadata SHA-256 digests for offline attribution, and existing reminder sound selectors expose it immediately.

Subscribing never changes a reminder's active sound. A subscription is a pinned local copy, not automatic background updates or GitHub account synchronization. Browser storage does not sync into the app. The website provides the Issue link and instructions; it does not make unauthenticated localhost requests or claim a native deep-link integration.

The locally saved subscriptions section remains manageable even when an Issue is closed, delisted or absent from the current page. Closing during a pending subscription prevents registration or selection; at most one inert downloaded file (≤5 MiB) may remain in app storage. It is not deleted automatically because another window/reminder may share the content-addressed copy.

Unsubscribe removes the catalog library entry without deleting audio files or changing active reminder profiles. A sound still selected by a reminder stays available through that reminder until the user chooses another sound. Updating a sound requires an explicit unsubscribe/resubscribe; no downloaded file is overwritten in place.

## Requests and limits

- No credentials are sent. Public GitHub rate limits apply.
- Desktop list pages use a five-minute in-memory metadata cache, 100 API items per page, explicit load-more and a ten-page limit. Fresh metadata and approval are used for subscription regardless of list cache.
- Approval lookup is bounded to ten comment pages of 100 comments. Missing approval or a limit fails closed. Very long discussions should use a fresh submission.
- HTTP reads are capped (4 MiB list/comments, 128 KiB individual Issue, 5 MiB audio), with a 30-second overall timeout and 15-second connection timeout.
- Download redirects must remain HTTPS on explicitly allowed GitHub attachment destinations. A CDN change fails closed until the allowlist is reviewed.
- 👍/👎 counts are GitHub reactions. Voting takes the user to the Issue and requires their GitHub account; local UI clicks are not represented as globally saved votes.

## Verification and release

Run `flutter analyze`, focused `flutter test test/features/settings/voice_catalog_test.dart test/features/settings/reminder_settings_service_test.dart`, and the website's Node tests. Shared fixtures verify Unicode JSON digests and audio duration/hash in both implementations. The normal desktop and golden suites remain release gates on their supported platforms.

The static Pages workflow is release-triggered. Adding files or creating a draft PR does not deploy a route, publish an app update, create public labels, or install an Issue Form in the separate repository. Those are explicit rollout steps. No new privileged Actions workflow is needed.
