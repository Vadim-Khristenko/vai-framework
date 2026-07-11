# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 5.1.x   | Yes |
| 5.0.x   | Best effort |
| &lt; 5.0  | No |

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

1. Prefer [GitHub Security Advisories](https://github.com/Vadim-Khristenko/vai-framework/security/advisories/new) on this repository.
2. Or email the maintainer using the address in module metadata / GitHub profile.

Include:

- Affected version / commit
- Impact assessment
- Reproduction steps or proof-of-concept

You should receive an acknowledgement within a reasonable time. Please allow
time for a fix before public disclosure.

## Scope notes

- VAI runs **user-authored** scripts and shell commands (especially SEX targets). Treat `sex.yaml` like code you run with your own privileges.
- Install helpers in AgentHub may download packages (`npm` / `bun` / `uv`). Review package names before installing.
