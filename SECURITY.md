# Security

Experimental single-owner software. Use HTTPS and a strong owner token for
remote access. A provider terminating TLS can read content; this release has
no end-to-end content encryption. Keep auth files and conversation databases
private. Do not use it as a public multi-user service.

For suspected vulnerabilities, use GitHub **Security → Report a vulnerability**
when available. Otherwise request a private contact in an issue without exploit
details or sensitive data. Never attach tokens, databases, or account files.

If exposed, rotate the owner token in `server/.env`, restart, and update the
clients. Rotate a leaked tunnel-provider token through its dashboard.
