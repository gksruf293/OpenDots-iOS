# OpenDots for iPhone

Native SwiftUI iOS client for the Codex-backed OpenDots server installed at
`C:\CV\OpenDots`. This is a standalone app, with native screens and URLSession
streaming; it does not embed the website in a WebView.

Features: Dot selection, new/recent conversations, streamed Codex replies,
stop/recovery, save conversation as page, Space document library, Markdown
view/edit with revision checks, and server credentials in iOS Keychain.

## Virtual macOS build

The GitHub Actions workflow `.github/workflows/ios-build.yml` uses the hosted
`macos-15` runner. It generates the Xcode project, builds the app for simulator
and device, runs XCTest, launches it in an iPhone simulator and uploads a native
screenshot, logs, test result bundle and simulator app.

The simulator ZIP and unsigned device build are **not installable iPhone IPAs**.
Physical-device installation needs Apple signing and provisioning. No Apple
passwords, signing keys, connection tokens or PC conversation data belong in
this repository. CI does not connect to the PC or use the Codex account.

## On a Mac or macOS runner

```sh
brew install xcodegen
xcodegen generate
xcodebuild -project OpenDots.xcodeproj -scheme OpenDots \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Requires iOS 17 or later. Set a unique bundle ID and your Apple team in Xcode
before installing on a registered physical iPhone. A signed distribution
workflow can be added after choosing an Apple Developer team and distribution
method. GitHub runner minutes may be limited by the account's plan.

## Server connection

The PC currently listens only on `127.0.0.1:4310`. Before connecting an actual
iPhone, configure a reachable **HTTPS** address with owner authentication.
The app asks for that address and owner token. The owner token is unrelated to
an OpenAI API key. Never expose the current unauthenticated loopback service
directly to the Internet.

The native client does not send browser Origin headers. It uses the existing
server Bearer-token authentication. Redirects are rejected so connection
credentials cannot be forwarded to a different server. A loopback HTTP address
is accepted only for simulator development; on iPhone it refers to the phone,
not this PC. PC Codex execution requires the PC to remain running.

Backend routes used:

- `GET /api/workspace`
- `POST /api/conversations`
- `GET /api/conversations/:id/messages`
- `POST /api/conversations/:id/turn` (NDJSON)
- `POST /api/conversations/:id/stop`
- `POST /api/conversations/:id/page`
- `GET /api/spaces/:id/pages`
- `PATCH /api/spaces/:id/pages/:pageId`

Voice, Slack and Dot computer tools remain outside this first native release.
