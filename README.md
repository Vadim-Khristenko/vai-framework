<p align="center">
  <img src="docs/assets/banner.svg" alt="VAI-Framework" width="720" />
</p>

<h1 align="center">VAI-Framework</h1>

<p align="center">
  <strong>Hybrid-registry PowerShell toolkit</strong> for humans who ship.<br/>
  Modules · Agent hub · Docker · Git · SEX task runner · DevBuild presets
</p>

<p align="center">
  <a href="https://github.com/Vadim-Khristenko/vai-framework/actions/workflows/ci.yml"><img src="https://github.com/Vadim-Khristenko/vai-framework/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT" /></a>
  <a href="https://github.com/Vadim-Khristenko/vai-framework/releases"><img src="https://img.shields.io/github/v/release/Vadim-Khristenko/vai-framework?include_prereleases" alt="Release" /></a>
  <img src="https://img.shields.io/badge/PowerShell-7%2B%20%7C%205.1-5391FE?logo=powershell&logoColor=white" alt="PowerShell" />
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey" alt="Platform" />
</p>

---

## Why VAI?

Modern shells collect **aliases forever** until PATH becomes a landfill.  
VAI is a **modular framework**: each capability is a package with a manifest, load order, lazy stubs, and a **single registry**.

| You want | You get |
|----------|---------|
| Short commands | `gs`, `dps`, `sex up`, `ai`, `db build` |
| Namespaces | `git:gs`, `docker:dps`, `sex:sex` |
| Script API | `Invoke-Vai Git gs` · `$Vai.M.Docker.dps` |
| Portable drop-in | `Import-Vai -Root … -Modules Git,sex` |

**Slogan (SEX module):** *Ship. Execute. eXcite.*

---

## Quick start

```powershell
# Clone
git clone https://github.com/Vadim-Khristenko/vai-framework.git
cd vai-framework

# Load into current session
. .\init.ps1

# See the roster
vai-module list
vai-doctor
```

Optional: add to your PowerShell profile:

```powershell
. "D:\path\to\vai-framework\init.ps1"
```

### Bash companion (optional)

```bash
source contrib/bash/vai.sh
vai help
vai doctor
vai modules
ai list
dps
kgp
```

See [`contrib/bash/README.md`](contrib/bash/README.md) — v0.3 tracks PowerShell UX (pills, doctor, k8s).

---

## How it works

```
init.ps1
  └─ core/          # state, registry, loader, TUI, platform, update
  └─ modules/       # one folder = one module
        ├─ config.json      # Meta + Settings + Exports
        ├─ module.ps1       # Register-VaiExport …
        ├─ lib/*.ps1        # implementation (optional split)
        └─ changelog.json
```

1. **Scan** `modules/*` (manifests).
2. **Topo-sort** by `DependsOn` + `LoadPriority`.
3. **Load** eager modules; **lazy** modules install stubs until first call.
4. **Bind** three surfaces: short alias · `prefix:cmd` · `$Vai.M` / `Invoke-Vai`.

```powershell
# All equivalent once GitTweaks is available:
gs
git:gs
Invoke-Vai Git gs
& $Vai.M.Git.gs
```

---

## Modules

| Module | Prefix | Highlights |
|--------|--------|------------|
| **sex** | `sex` | Project task runner — see below 🔥 |
| **AgentHub** | `ai` | Claude, Grok, Codex, OpenCode, **Antigravity**, install via bun/npm |
| **DevBuild** | `db` | Detect cargo/bun/uv/npm/go/dotnet · `db build/test/run` |
| **DockerTweaks** | `docker` | `dps` `dup` `dhealth` `dbuild` `dprune` … |
| **KubeTweaks** | `k` | `kctx` `kns` `kgp` `klogs` `ksh` `kapp` `kpf` … |
| **GitTweaks** | `git` | Conventional commits, status TUI, sync helpers |
| **vai-net** | `net` | Ping, ports, DNS, scan, HTTP, speed |
| **CommandNotFound** | `cnf` | Fuzzy suggestions + install hints |

```powershell
vai-module list
vai-module info sex
vai-new-module MyThing -Prefix mt
```

---

## SEX — Script EXecutor

> **Not that kind of framework.**  
> SEX is the part of VAI that makes your repo **dangerous in the best way**: one file, many targets, zero ceremony.

**Ship. Execute. eXcite.**

Drop a `sex.yaml` in the project root and stop memorizing “which compose file + which package script + which agent”:

```yaml
name: the-wall
default: up

tools:
  bun: bun
  docker: docker

targets:
  up:
    desc: "Bring the stack up and open the UI"
    run:
      - cmd: docker compose up -d
      - cmd: bun run dev
        bg: true
    open:
      - http://localhost:3000
    after: "You're in. Ship. Execute. eXcite."

  test:
    desc: "Prove it still works"
    run:
      - cmd: bun test
```

### Commands

| Command | What it does |
|---------|----------------|
| `sex` | Help + vibe check |
| `sex init` | Scaffold `sex.yaml` |
| `sex list` | Targets + descriptions |
| `sex which` | Which config file wins |
| `sex up` | Run target `up` |
| `sex <target> --dry` | Plan only — no side effects |
| `sex down` | Stop session background jobs |

### How SEX resolves config

1. `./sex.yaml` / `./sex.yml` / `./sex.json`
2. Walk up to project root (git / markers)
3. User config dir
4. Framework sample (if any)

### How a target runs

1. Merge `env` (global + target).
2. For each `run[]` step: `argv` (preferred) or `cmd` (split / optional `shell: true`).
3. `bg: true` → background process (tracked for `sex down`).
4. `open[]` → browser / `xdg-open` / `open`.
5. Print `after` — because closure matters.

YAML parsing: **mini-dialect built-in** (zero deps). Optional backends: `powershell-yaml`, `yq`, Python+PyYAML.

```powershell
sex init
sex list
sex up --dry
sex up
```

Keep it spicy. Keep it shippable. Keep it in git.

---

## AgentHub

```powershell
ai                 # dashboard
ai list            # PATH + bun globals + npm globals
ai install claude
ai install codex -Via bun
ai install antigravity   # Google Antigravity CLI (agy) — Gemini CLI successor
ai go              # default agent
ai run grok
```

---

## DevBuild

```powershell
db                 # detect stacks in project
db tools           # cargo / bun / uv / npm / …
db build
db test
db run
db install
db build -Stack cargo
```

---

## KubeTweaks

```powershell
kctx                 # contexts (+ switch: kctx prod)
kns                  # namespaces (+ set: kns default)
kgp                  # pods (picker-friendly)
klogs [pod] -Follow
ksh [pod]            # bash/sh into container
ktop pods|nodes
kapp deploy.yaml
kpf my-pod 8080:80
kev
kube-help            # or k:help
```

Requires `kubectl` on PATH; degrades cleanly if the cluster is offline.

---

## Core CLI

| Command | Purpose |
|---------|---------|
| `vai-module list\|info\|deps\|set\|log` | Module manager |
| `vai-doctor` | Environment diagnostics |
| `vai-reload` | Hot reload framework |
| `vai-call Module cmd …` | Sugar for `Invoke-Vai` |
| `vai-update` | Update channel (ready for GitHub Releases) |
| `vai-new-module Name` | Scaffold under `modules/` |
| `vai-changelog Module` | Module changelog |

Set update channel after clone (optional):

```powershell
$env:VAI_UPDATE_REPO = "Vadim-Khristenko/vai-framework"
vai-update
```

---

## Layout

```
vai-framework/
├── init.ps1                 # entry
├── core/                    # framework kernel
├── modules/                 # first-class modules
├── contrib/bash/            # portable bash companion
├── docs/                    # guides & design notes
├── tests/                   # CI smoke tests
└── .github/                 # Actions, templates
```

---

## Requirements

- **PowerShell 7+** recommended (Windows / Linux / macOS)
- Windows PowerShell **5.1** supported for core paths
- Optional tools: Docker, Git, bun, npm, uv, AI CLIs — modules degrade gracefully

---

## Development

```powershell
# Smoke tests (same suite as CI)
pwsh -NoProfile -File tests/Smoke-Vai.ps1
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

[MIT](LICENSE) © Vadim Khristenko

---

<p align="center">
  <sub>Built for people who type faster than they document — and still want structure.</sub><br/>
  <sub><em>Ship. Execute. eXcite.</em></sub>
</p>
