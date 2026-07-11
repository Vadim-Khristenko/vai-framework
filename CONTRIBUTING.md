# Contributing to VAI-Framework

Thanks for showing up. We like PRs that are **focused**, **tested**, and **don’t dump twenty unrelated aliases into global scope**.

## Ground rules

1. **Modules over globals** — public surface via `Register-VaiExport`.
2. **Cross-platform** — use `Join-Path`, `Test-VaiCommand`, avoid hard-coded `C:\`.
3. **Degrade gracefully** — missing docker/git/bun must not crash boot.
4. **No drive-by refactors** — keep diffs reviewable.
5. **Commit messages** — imperative, clear (`feat(sex): support argv steps`). No tooling spam in messages.

## Dev setup

```powershell
git clone https://github.com/Vadim-Khristenko/vai-framework.git
cd vai-framework
. .\init.ps1
pwsh -NoProfile -File tests/Smoke-Vai.ps1
```

## Adding a module

1. `vai-new-module Name -Prefix xx` **or** copy an existing module under `modules/`.
2. Implement in `lib/`, register exports in `module.ps1`.
3. Update `changelog.json` and root `CHANGELOG.md` if user-facing.
4. Run smoke tests.
5. Open a PR with what/why.

## Code style

- PowerShell: prefer `CmdletBinding`, explicit params, `$global:Vai.Colors` / TUI helpers.
- Bash companion: bash 4+, `set -euo pipefail` in libraries where safe; keep feature parity intentional, not total.

## Pull requests

- Fill out the PR template.
- Link related issues.
- CI must pass (Windows + Ubuntu smoke).

## Reporting bugs

Use the **Bug report** issue template. Include:

- OS + `$PSVersionTable`
- `vai-doctor` output
- Minimal repro

## Security

See [SECURITY.md](SECURITY.md). Do not file public issues for sensitive reports.
