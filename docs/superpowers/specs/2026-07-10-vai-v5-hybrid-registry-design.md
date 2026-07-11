# VAI-Framework v5 — Hybrid Registry, Power Core & SEX

**Date:** 2026-07-10  
**Status:** Ready for user review  
**Author:** Vadim Khristenko + Grok  
**Slogan (SEX):** *Ship. Execute. eXcite.*

---

## 1. Goals

### 1.1 Product goals

1. **Namespaced modules** — no more dumping everything into global scope by accident.
2. **Three call surfaces** — short aliases, `prefix:cmd`, and a real API for scripts/other modules.
3. **Portable core** — drop `init.ps1` + `core/` + needed modules into any machine/script and run.
4. **Power core** — rich helpers so modules stay thin and consistent.
5. **Cross-platform** — first-class Windows; Linux & macOS must boot and run non-Windows-specific modules.
6. **SEX** — cheeky task runner (`sex.yaml`) for dev stacks, scripts, and tool launch. Tone: bold + light NSFW, still GitHub-safe.
7. **Advanced by default** — registry, lazy stubs, dependency graph, doctor, dry-run, structured config — not a bag of aliases.

### 1.2 Non-goals (this cycle)

- Full rewrite as classic `Import-Module` `.psd1` packs (can wrap later).
- Mandatory move of all modules into `modules/` (optional later).
- Complete bash reimplementation of every module (optional shim only).
- Breaking removal of v4 short names (`gs`, `dps`, …) in v5.0.

---

## 2. Architecture overview

```
┌──────────────────────────────────────────────────────────────┐
│  Bootstrap: init.ps1  |  Import-Vai [-Root] [-Modules …]     │
├──────────────────────────────────────────────────────────────┤
│  core/                                                        │
│    VaiState.ps1       — version, paths, OS flags, $Vai root  │
│    VaiHelpers.ps1     — files, JSON, strings, process, path  │
│    VaiPlatform.ps1    — OS/arch, paths, which, open URL      │
│    VaiLogger.ps1      — leveled file + console log           │
│    VaiRegistry.ps1    — Register / Invoke / Get / M map      │
│    VaiModuleLoader.ps1— scan, topo, load, lazy stubs         │
│    VaiCli.ps1         — vai-module, doctor, reload, new      │
├──────────────────────────────────────────────────────────────┤
│  Modules (sibling dirs; optional modules/ later)              │
│    GitTweaks | DockerTweaks | vai-net | CommandNotFound       │
│    sex (v5.1 full; stub ok in v5.0)                           │
└──────────────────────────────────────────────────────────────┘
```

### 2.1 Call surfaces (single source of truth = registry)

| Surface | Example | Audience |
|---------|---------|----------|
| Short alias | `gs`, `dps`, `sex up` | Interactive shell |
| Prefix | `git:gs`, `docker:dps`, `sex:up` | Explicit namespace |
| API | `Invoke-Vai Git gs`, `$Vai.M.Git.gs` | Scripts, modules, CI |

All three resolve to the same registered scriptblock.

### 2.2 Design principles

- **Exports are declared** — modules register public commands; internals stay `script:` / private.
- **Proxies, not copies** — short/prefix names are thin dispatchers into the registry (reload-safe).
- **Fail soft** — missing tools (docker, git) degrade with a clear message; core still loads.
- **Cross-platform by construction** — platform helpers abstract path, open, admin, package hints.
- **GitHub-safe spice** — SEX branding is playful; no hardcore NSFW in default help, logs, or README.

---

## 3. Core object: `$Vai`

Single root object (hashtable or PSCustomObject) held in `$global:Vai` for ergonomics, with nested structure:

```powershell
$Vai.Version          # "5.0.0"
$Vai.Root             # framework root
$Vai.IsWindows / .IsLinux / .IsMacOS / .IsCore
$Vai.Colors           # Magenta, Cyan, Green, Yellow, Red, Gray, Blue, Reset
$Vai.M                # Module map: $Vai.M.Git.gs → scriptblock
$Vai.Modules          # Manifest cache (list/info for CLI)
$Vai.LogLevel
$Vai.Slogan.Sex       # "Ship. Execute. eXcite."
```

**Legacy:** `$global:VAI_Cyan` etc. remain as thin aliases in v5; documented as deprecated for v6.

**PowerShell 7+ note:** avoid clobbering automatic `$IsWindows` / `$IsLinux` / `$IsMacOS` — only read them; store copies under `$Vai.*`.

---

## 4. Registry API

### 4.1 Public functions

```powershell
Register-VaiExport
  -Module <string>          # logical name, e.g. Git
  -Name <string>            # command key, e.g. gs
  -ScriptBlock <scriptblock>
  [-Alias <string>]         # short global name; default = Name if ShortAliases
  [-Prefix <string>]        # override module prefix for this export

Invoke-Vai
  [-Module] <string>
  [-Command] <string>
  [remaining args splat to scriptblock]

Get-VaiModule [[-Name] <string>]
Get-VaiExport [-Module] <string> [[-Name] <string>]
Test-VaiModule [-Name] <string> [-Loaded]
Import-Vai [-Root <path>] [-Modules <string[]>] [-Quiet]
```

### 4.2 Binding rules

On register (eager load or after lazy resolve):

1. `$Vai.M.<Module>.<Name> = $ScriptBlock` (module key normalized: alphanumeric; display name from manifest).
2. Prefix function: `Set-Item "function:${Prefix}:${Name}"` → proxy invoking registry.
3. If `ShortAliases`: `Set-Item "function:global:$Alias"` → same proxy.
4. Unregister on reload: remove prefix + short proxies tracked in registry metadata.

**Colon names:** function names like `git:gs` are registered as a single function name (not scope syntax). If a host rejects them, fallback prefix style is `git/gs` or dispatcher `Invoke-Vai` only — detect once at boot, store `$Vai.PrefixStyle = 'Colon' | 'Slash'`.

### 4.3 Lazy stubs

For lazy modules, **do not** require manual `LazyTriggers` lists.

1. Read `Exports` (+ optional Alias map) from `config.json`.
2. Install stub proxies for each export (short + prefix + empty `$Vai.M` slots marked Lazy).
3. First invoke: load `module.ps1`, real `Register-VaiExport` calls, then re-enter original command with same args.

`LazyTriggers` in old configs: still accepted as extra stub names for one release; ignored if `Exports` present.

---

## 5. Module contract

### 5.1 Layout (unchanged)

```
ModuleName/
  config.json
  changelog.json
  module.ps1
```

### 5.2 `config.json` v5 schema

```json
{
  "Meta": {
    "Name": "GitTweaks",
    "Prefix": "git",
    "Version": "1.1.0",
    "Author": "Vadim Khristenko <vadim@vai-rice.space>",
    "Description": "Git utilities with Conventional Commits"
  },
  "Settings": {
    "EnableModule": true,
    "LoadPriority": 100,
    "LazyLoad": true,
    "DependsOn": [],
    "ShortAliases": true,
    "Exports": ["gs", "glg", "gcommit", "gundo", "gstats", "help"]
  }
}
```

| Field | Required | Notes |
|-------|----------|--------|
| `Meta.Name` | yes | Unique module id |
| `Meta.Prefix` | yes (v5) | Short namespace token: `git`, `docker`, `net`, `sex` |
| `Settings.Exports` | yes (v5 public modules) | Public command keys |
| `Settings.ShortAliases` | no | Default `true` |
| `Settings.LazyLoad` | no | Default `false` |
| `Settings.DependsOn` | no | Module **Name** list |
| `Settings.LazyTriggers` | legacy | Optional bridge |

**Prefix vs Name:** `$Vai.M` key prefers `Prefix` title-cased (`git` → `Git`) or explicit `Meta.RegistryKey` if we need disambiguation. Document: `RegistryKey` optional override; default = `Prefix` with first letter uppercased, multi-segment `vai-net` → `Net` if Prefix is `net`.

Recommendation locked in:

- `GitTweaks` → Prefix `git` → `$Vai.M.Git`
- `DockerTweaks` → Prefix `docker` → `$Vai.M.Docker`
- `vai-net` → Prefix `net` → `$Vai.M.Net`
- `CommandNotFound` → Prefix `cnf` → `$Vai.M.Cnf`
- `sex` → Prefix `sex` → `$Vai.M.Sex`

### 5.3 `module.ps1` pattern

```powershell
# Private implementation
function script:Invoke-GitStatus { ... }

# Public registration (required for exports)
Register-VaiExport -Module $VaiModule.RegistryKey -Name gs `
    -ScriptBlock ${function:Invoke-GitStatus} -Alias gs
```

While loading, loader sets:

```powershell
$VaiModule = [pscustomobject]@{
  Name, Prefix, RegistryKey, Version, ConfigPath, ScriptPath, Settings
}
```

Modules **must not** declare `function global:…` for public API in v5 (migration: replace with register). Exception: temporary dual-write during migration is allowed only inside one release if needed for emergency, then removed.

### 5.4 Generator

`vai-new-module` scaffolds v5 layout: Prefix, Exports sample, `Register-VaiExport` example, changelog entry.

---

## 6. Loader pipeline

```
1. Resolve root (init path or Import-Vai -Root)
2. Dot-source core files in order:
   VaiState → VaiHelpers → VaiPlatform → VaiLogger → VaiRegistry → VaiModuleLoader → VaiCli
3. Scan directories (exclude: core, logs, docs, .git, .vscode, 7, node_modules, …)
4. Parse manifests; skip invalid with WARN
5. Topological sort (Kahn) + LoadPriority tie-break
6. Per module:
   - disabled → Sleeping
   - lazy → stubs + status Lazy
   - eager → . module.ps1; status Loaded | Failed
7. Boot summary (counts, ms)
```

**Reload:** clear registry exports + tracked proxies + module cache; re-run init under existing guard.

**Import-Vai -Modules A,B:** only load those names (+ their DependsOn closure).

---

## 7. Power core helpers (expanded)

Goal: modules call core instead of reinventing JSON, process, platform, UI chrome.

### 7.1 Existing (keep / harden)

| Function | Role |
|----------|------|
| `Write-VaiFile` | UTF-8 write ± BOM, ensure dir |
| `Read-VaiJson` | Safe JSON read |
| `Test-VaiProperty` / `Get-VaiValue` | Safe object access |
| `Get-VaiChangelogEntries` | Dual changelog formats |
| `Write-VaiLog` | Leveled log |

### 7.2 New helpers (v5.0)

**Config & data**

- `Read-VaiYaml` — YAML → object. **Fallback order (locked):** (1) `powershell-yaml` module if imported/available, (2) `yq` on PATH → JSON → `ConvertFrom-Json`, (3) `python -c` + PyYAML/`yaml` if available, (4) clear error with install hint. No hand-rolled full YAML parser in v5.
- `Read-VaiConfig` — load module config by name/path with defaults merge.
- `Merge-VaiHashtable` — deep merge settings.

**Process & tools**

- `Test-VaiCommand` — command on PATH (cross-platform).
- `Invoke-VaiNative` — run external with arg array, timeout, capture stdout/stderr/exit; never shell-inject.
- `Get-VaiTool` — resolve tool from map / PATH (`bun`, `uv`, `cargo`, `git`, `docker`, agents…).
- `Assert-VaiCommand` — like Test but friendly error + optional install hint.

**Platform**

- `Get-VaiOS` — Windows | Linux | macOS | Unknown.
- `Get-VaiHomePath` — user home.
- `Get-VaiConfigDir` — `~/.config/vai` or Windows equivalent.
- `Open-VaiPath` / `Open-VaiUrl` — explorer/xdg-open/open.
- `Test-VaiAdmin` — elevation check when meaningful; false/neutral on non-Windows if N/A.

**UX**

- `Write-VaiHost` — colored line using `$Vai.Colors`.
- `Write-VaiHeader` / `Write-VaiSeparator` — consistent chrome.
- `Write-VaiTable` — simple aligned columns.
- `Confirm-VaiAction` — y/N with RU/EN yes; `-Force` skip.
- `Get-VaiBar` — percent bar (shared with docker stats style).

**Path & project**

- `Find-VaiProjectRoot` — walk up for `.git`, `sex.yaml`, `Cargo.toml`, `package.json`, `pyproject.toml`.
- `Resolve-VaiPath` — expand `~`, relative to root/cwd.

**Error style**

- `Write-VaiError` / `Write-VaiWarn` / `Write-VaiOk` — one-liners with icons that degrade on dumb terminals.

All new helpers are **`global:` only if needed for modules loaded via dot-source**; prefer registry later for core too, but v5.0 may keep core helpers as functions in global/script of init session for simplicity. Document: core helpers are public API of the framework.

---

## 8. Cross-platform

### 8.1 Requirements

| Area | Behavior |
|------|----------|
| Paths | `Join-Path`; never hardcode `\` only in new code |
| Line ends | tolerate CRLF/LF in configs |
| Docker/Git modules | require tools; clear message if missing |
| CommandNotFound | works on PS Core all OS; package hints: winget/scoop/choco on Windows; apt/brew/pacman hints on Unix where detectable |
| Admin check | Windows-only meaningful; Unix: optional `id -u` |
| UTF-8 | set console output UTF-8 when safe; don't crash in limited hosts |
| ANSI | already gated by modern host |

### 8.2 CI / smoke (manual or script)

- Windows PS 5.1 + PS 7
- Linux pwsh 7 (smoke: init, list modules, Invoke-Vai if git present)
- macOS pwsh 7 (same)

### 8.3 Optional bash port (`contrib/bash/` or `sh/`) — best effort

Not a second full framework. Goal: **thin shims** for environments without pwsh.

```
contrib/bash/
  vai.sh          # source-able: VAI_ROOT, minimal log, which
  sex.sh          # read sex.yaml via yq/python; run targets
  README.md       # requires bash 4+, yq optional
```

- Feature parity: **not** required.
- SEX targets that are pure command lists should run under `sex.sh`.
- Registry/modules: **PowerShell only**.
- Document as experimental; GitHub badge: “pwsh primary, bash shim optional”.

---

## 9. SEX — Script EXecutor

### 9.1 Branding

- **Name:** SEX  
- **Slogan:** *Ship. Execute. eXcite.*  
- **Tone:** cocky, fun, lightly NSFW double-entendres in help/flavor text; no explicit sexual content in defaults, logs, or generated files.  
- **GitHub:** README explains acronym + slogan; keep it meme-aware, professional enough for a public repo.

### 9.2 Role

Project-local (or user-global) task runner driven by `sex.yaml`:

- Bring up dev instances (compose, bun dev, etc.)
- Run test/build chains
- Launch AI CLIs / tools via configured map
- Open browser URLs after “up”
- Dry-run plans before execution

### 9.3 Config discovery (first wins)

1. `./sex.yaml` or `./sex.yml` from cwd  
2. Walk up to project root (`Find-VaiProjectRoot`)  
3. `$Vai.Root/sex/default.yaml` (framework sample)  
4. User: `Join-Path (Get-VaiConfigDir) 'sex.yaml'`

### 9.4 Schema (`sex.yaml`)

```yaml
name: my-app
default: up
slogan: "Ship. Execute. eXcite."   # optional override display

env:
  NODE_ENV: development

tools:
  bun: bun
  uv: uv
  cargo: cargo
  claude: claude
  grok: grok
  codex: codex
  opencode: opencode

targets:
  up:
    desc: "Spin up local dev"
    cwd: .
    run:
      - cmd: docker compose up -d
      - cmd: bun run dev
        bg: true
    open:
      - http://localhost:3000
    after: "You're in. Ship. Execute. eXcite."

  test:
    desc: "Run test suite"
    run:
      - cmd: uv run pytest
      - cmd: cargo test
```

**Semantics**

- `run[].cmd` — string; executed via `Invoke-VaiNative` with shell only if `shell: true` (default false → split carefully or use `argv: []` preferred form).
- Preferred advanced form: `argv: ["docker", "compose", "up", "-d"]` to avoid quoting hell.
- `bg: true` — start background; track PIDs in session for optional `sex down`.
- `env` — merged into process env for that target.
- `open` — `Open-VaiUrl` each.
- `after` / `before` — flavor + optional messages (not executed as shell unless `run`).

### 9.5 CLI

| Command | Action |
|---------|--------|
| `sex` | Help + slogan + list targets |
| `sex <target>` | Run target |
| `sex list` | Targets + descriptions |
| `sex init` | Write sample `sex.yaml` in cwd |
| `sex which` | Resolved config path |
| `sex <target> --dry` | Print plan only |
| `sex:up` etc. | Prefix form via registry |

**UX (locked):** single registry export `sex` (dispatcher). Subcommands are arguments: `sex up`, `sex list`, `sex init`, `sex which`, `sex <target> --dry`. Short alias `sex` on. Prefix form `sex:sex` is **not** registered (redundant); module Prefix `sex` reserved for future sub-exports if needed. `$Vai.M.Sex.sex` invokes the same dispatcher.

### 9.6 Phasing

| Version | SEX scope |
|---------|-----------|
| **v5.0** | Design + optional stub module (help + slogan + `sex init` writing sample yaml) OR folder reserved only |
| **v5.1** | Full runner: discovery, dry-run, bg, open, tools map |
| **v5.2** | `sex down`, profiles, hooks, bash `sex.sh` |

**v5.0 decision:** implement **stub** `sex` module: `sex` / `sex init` / slogan help — proves registry + branding; no full executor yet. Full executor is v5.1 immediately after core stabilizes.

---

## 10. Migration of existing modules (v5.0)

| Module | Prefix | RegistryKey | Notes |
|--------|--------|-------------|--------|
| GitTweaks | `git` | Git | All commands via Register-VaiExport; private helpers script: |
| DockerTweaks | `docker` | Docker | Lazy; stubs from Exports |
| vai-net | `net` | Net | Keep `vai-ping` style short names as aliases; also `net:ping` mapping |
| CommandNotFound | `cnf` | Cnf | Enable/Disable + `vai-suggest`; package hints cross-platform |

**vai-net naming:** short aliases remain `vai-ping`, `vai-port`, … for muscle memory; prefix forms `net:ping`, `net:port`, … map to same. Export keys: `ping`, `port`, `dns`, … with Alias `vai-ping` etc.

**Colors:** migrate `$global:VAI_*` usages to `$Vai.Colors.*` or `$Vai.Cyan` convenience.

---

## 11. CLI updates

- `vai-module list` — show Prefix, export count, Lazy/Loaded  
- `vai-module info <name>` — list exports + short aliases  
- `vai-doctor` — OS, PS version, registry size, failed modules, prefix style, YAML capability  
- `vai-reload` — full registry teardown + rebind  
- `vai-new-module` — v5 template  
- New: `vai-call <Module> <cmd> [args…]` as CLI sugar for `Invoke-Vai` (optional)

---

## 12. Future modules (post v5.1)

| Module | Prefix | Purpose |
|--------|--------|---------|
| DevTools | `dev` | cargo / bun / uv ergonomics |
| AgentHub | `ai` | claude, grok, codex, opencode launcher + detect |
| PathKit | `path` | PATH audit, conflicts |
| Proj | `proj` | project root, jump, env |

SEX may call them via `Invoke-Vai` without owning their logic.

---

## 13. File change map (v5.0 implementation)

| Path | Action |
|------|--------|
| `init.ps1` | Version 5; load order; `Import-Vai` entry |
| `core/VaiState.ps1` | `$Vai` structure, OS flags, slogan constants |
| `core/VaiHelpers.ps1` | Expand helpers §7 |
| `core/VaiPlatform.ps1` | **New** |
| `core/VaiRegistry.ps1` | **New** |
| `core/VaiLogger.ps1` | Minor: use colors via `$Vai` |
| `core/VaiModuleLoader.ps1` | Registry integration, lazy stubs, Exports |
| `core/VaiCli.ps1` | doctor/list/info/new-module |
| `GitTweaks/*` | Migrate + config Exports/Prefix |
| `DockerTweaks/*` | Migrate |
| `vai-net/*` | Migrate |
| `CommandNotFound/*` | Migrate + Unix hints |
| `sex/*` | Stub module |
| `docs/superpowers/specs/…` | This doc |
| `contrib/bash/*` | Optional later or minimal README placeholder |
| `README.md` | When releasing to GitHub (not blocking core) |

---

## 14. Success criteria

1. `. init.ps1` on Windows PS 7: all previously active modules work via short names.  
2. `Invoke-Vai Git gs` and `git:gs` (or slash fallback) work.  
3. `$Vai.M.Git.gs` is invokable.  
4. Lazy Docker: no heavy docker calls until first docker export used.  
5. `vai-doctor` reports OS + registry export count.  
6. `Import-Vai -Modules Git` loads core + Git (+ deps) only.  
7. `sex` prints slogan *Ship. Execute. eXcite.* and can `sex init`.  
8. No hard crash on Linux/macOS init without docker/git.  
9. Tone: playful SEX help text; no explicit NSFW.

---

## 15. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| `prefix:cmd` parse issues | Detect PrefixStyle; fallback slash/dispatcher |
| YAML without dependencies | Prefer argv-heavy sex later; Read-VaiYaml multi-backend |
| PS 5.1 limitations | Keep 5.1-safe syntax in core (no PS7-only operators in core paths) |
| Scope pollution still high | Core helpers global by necessity; modules register only exports |
| Branding backlash on GitHub | README acronym + tasteful slogan; configurable quiet mode later |

---

## 16. Implementation order (for plan)

1. VaiState v5 + colors object cleanup  
2. VaiPlatform + expanded VaiHelpers  
3. VaiRegistry  
4. VaiModuleLoader rewrite (stubs, context `$VaiModule`)  
5. VaiCli updates  
6. Migrate CommandNotFound → Git → Docker → Net  
7. SEX stub  
8. Smoke tests / doctor pass  
9. (Optional) contrib/bash placeholder  

---

## 17. Open decisions (resolved)

| Topic | Decision |
|-------|----------|
| Architecture | Hybrid Registry (C) |
| Short aliases | On by default |
| v5.0 scope | Core + migrate 4 modules + SEX stub |
| SEX slogan | Ship. Execute. eXcite. |
| Tone | Bold, light NSFW, GitHub-safe |
| Cross-platform | Required for core + graceful module degrade |
| Bash | Optional shim, not blocking |

---

*End of design. Review this file, then approve for implementation planning.*
