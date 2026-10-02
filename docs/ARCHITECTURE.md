# Architecture and limitations

```text
iPhone SwiftUI client
  | HTTPS + owner Bearer token (optional ngrok)
  v
OpenDots Node.js server on the user's PC
  |-- SQLite: Dots, Spaces, pages, conversations, messages
  |-- NDJSON: message / delta / tool / done / error
  `-- Codex CLI app-server over local stdio
       `-- existing Codex account authentication
```

Native URLSession rejects HTTP redirects to avoid forwarding credentials to
another origin. Tokens are stored per endpoint in Keychain, accessible when
unlocked on that device only. The phone does not need Codex or ngrok auth files.

Each turn creates an ephemeral Codex thread with the latest 30 saved messages
and bounded context. Full local history persists, but existing terminal Codex
sessions are not seamlessly mirrored. The adapter exposes bounded workspace
page tools and a read-only sandbox, not unrestricted shell execution.

This is a single-owner prototype. It has no multi-user accounts, push
notifications, built-in relay, or end-to-end content encryption. The Codex
adapter does not implement upstream voice/Slack/computer features.

Verified before public release: six native XCTest cases, simulator launch,
unsigned ARM64 device build, physical iPhone installation, and authenticated
remote Codex streaming. CI repeats server checks and native tests. CI does not
perform live model calls, Apple signing, or physical device installation.

Future work: easier pairing, PC packaging, signed distribution, end-to-end
encryption, and broader platform testing. These are not implemented in v0.1.
