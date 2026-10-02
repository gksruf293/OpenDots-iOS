# Installation

The fully documented/tested path is **Windows x64 + iPhone**. Follow the command
sequence in the root README. Requirements: PowerShell 7, Git, Node.js 24 LTS,
Codex CLI 0.157.1, and a ChatGPT account eligible for Codex. Complete account
authentication yourself. Usage counts against your account allowance.

## PC server

`setup-server.ps1` installs locked dependencies, builds the bundled server,
discovers the npm-installed native `codex.exe`, and generates a random owner
token. It refuses to overwrite an existing `server/.env`. Run `start-server.ps1`
and keep it running. Open `http://127.0.0.1:4310`, use the token from
`.local-tools/connection.txt`, and verify a local conversation first.
SQLite data is in `server/data/opendots.sqlite` and is ignored by Git.

macOS/Linux manual path: run `npm ci` and `npm run build` in `server/`, copy
`.env.example` to `.env`, set `AGENT_BACKEND=codex`, `HOST=127.0.0.1`, a random
`OWNER_TOKEN` of at least 24 characters, and the actual executable in
`CODEX_COMMAND`. Run `codex login`, then `npm start`. These operator installation
paths are not yet validated by the Windows helper; iOS builds are validated on
macOS CI. Windows `.cmd` shims cannot be spawned by the server adapter.

## HTTPS without an iPhone VPN

Install [official ngrok](https://ngrok.com/download/windows), sign in to its
dashboard, and use the account-assigned dev domain:

```powershell
ngrok config add-authtoken YOUR_NGROK_AUTHTOKEN
ngrok http http://127.0.0.1:4310 --url https://YOUR_ASSIGNED_DOMAIN --inspect=false
```

The ngrok authtoken stays on the PC. The phone uses the separate OpenDots owner
token. Both processes must remain running. The hostname is account-assigned
and stable across sessions. Free plans have usage limits; check
[current limits](https://ngrok.com/docs/pricing-limits/free-plan-limits).
The URL is publicly reachable, but API requests require the owner token.
ngrok terminates TLS and can access content: this is not end-to-end encryption.
`--inspect=false` disables local inspection, not all provider-side processing.

Autostart is an optional operator setup step: follow
[ngrok service instructions](https://ngrok.com/docs/agent/cli/#ngrok-service)
and create a Windows startup shortcut with an absolute path to `start-server.ps1`.
The helpers do not register services automatically. PC sleep interrupts access.
Tailscale Serve is a private alternative, but requires its VPN on the phone.

## iPhone build and signing without a local Mac

Fork the repo, enable Actions, run **iPhone package (unsigned)**, and download
artifact **OpenDots-iPhone-Unsigned**. Unzip to obtain `OpenDots-Unsigned.ipa`.
This is an unsigned device build and **must be signed before installation**.
Simulator ZIPs cannot be installed on an iPhone. Runner minutes depend on your
GitHub plan. The workflows require no Apple or model account credentials.

On Windows, follow [AltStore's official guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
for AltServer and its required Apple components. Connect/unlock/trust the phone.
Complete Apple account authentication yourself. Shift-click the AltServer tray
icon → **Sideload .ipa…**, then select the IPA. This direct route does not
require installing AltStore on the phone first. Trust the developer profile
under Settings → General → VPN & Device Management. Enable Developer Mode
under Privacy & Security and follow the restart prompts.

Free-account sideloads generally expire after **7 days**; re-sign/reinstall, or
use AltStore's refresh feature. This is not an indefinite signed release.
On a Mac, generate the project with XcodeGen and use your own team and unique
bundle identifier to sign/install in Xcode instead.

## Connect and troubleshoot

Enter your HTTPS **origin** without `/api` and the OpenDots owner token in the
native app. Connect, choose a Dot, and test chat and page saving. For ngrok,
test over cellular with Tailscale disconnected. Tokens are stored in Keychain.

- 401: verify you used the owner token, not the ngrok authtoken.
- Tunnel offline: check both processes, PC sleep, and provider quotas.
- Codex not ready: check login status, executable path, and account limits.
- iCloud 1722: see [AltStore troubleshooting](https://faq.altstore.io/altstore-classic/troubleshooting-guide).
- Apple -22411: check account and 2FA; the code alone does not identify a cause.
- iTunes -45054: follow [Apple guidance](https://support.apple.com/en-us/108339), backing up before changing auth folders.

Never disable Windows security to force installation or attach tokens/auth
files/databases to bug reports. Include tool versions and redacted errors.
