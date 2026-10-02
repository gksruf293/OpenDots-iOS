# Local Codex backend

This installation can use Codex app-server with ChatGPT login instead of model
API keys and CopilotKit Intelligence. The API backend remains available by setting
`AGENT_BACKEND=api` and supplying its original credentials.

## Run

1. Install Codex CLI and run `codex login` with ChatGPT. Verify with
   `codex login status`.
2. In `.env`, set `AGENT_BACKEND=codex`. On Windows, set `CODEX_COMMAND` to the
   actual installed `codex.exe`; Node cannot directly spawn the npm `.cmd` shim.
3. Run `npm run build` after source updates, then `npm start`. This installation
   provides portable `../../scripts/setup-server.ps1` and
   `../../scripts/start-server.ps1` helpers; see the
   [installation guide](../../docs/INSTALL.md).
4. Open <http://127.0.0.1:4310>. Allow a moment for the login/model check.

The bridge uses the account's reported default model, independent of a stale
model setting in the user's global Codex configuration. Usage counts against
the signed-in account's Codex allowance. Authentication remains inside Codex;
the application does not read or copy login tokens.

## Storage and capabilities

Messages, documents and Dot configuration live in `data/opendots.sqlite`.
Conversation turns stream to the browser. A new ephemeral Codex thread receives
the latest 30 local messages (bounded to 60,000 context characters) for each
request. The full saved local conversation remains available after restart.

Dots can list authorized Spaces, read/create/edit pages, use enabled preferences,
save chat transcripts as pages, and run scheduled requests in local conversations.
Page revisions and existing Space access checks still apply. Review-before-save
requests use a draft in chat followed by the owner's explicit confirmation.

This backend does not integrate voice, managed Slack, Automatic Learning, or
OpenBot computer tools. It disables built-in shell execution, applies a read-only
Codex sandbox, and declines tool/permission requests outside its page tools.
No model or Intelligence API key is needed for local text chat.

Keep the service bound to localhost unless separately configuring authenticated
remote access. Mobile browser access still requires a reachable deployment;
this change does not expose the PC to the network.

## Validation

`npm test`, `npm run lint`, `npm run typecheck`, and `npm run build` validate the
implementation. For a live check, send a chat in the app, reopen the conversation,
and save it as a page. This uses the signed-in account's Codex allowance.
