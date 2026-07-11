# VAI Bash Companion

Advanced **bash 4+** shim for environments without PowerShell.  
PowerShell VAI remains the **primary** runtime (registry, full SEX YAML, TUI).

## Install / use

```bash
# source into shell
source /path/to/PowerShell/contrib/bash/vai.sh

# or run as CLI
bash /path/to/PowerShell/contrib/bash/vai.sh help
```

Add to `~/.bashrc`:

```bash
source ~/path/to/PowerShell/contrib/bash/vai.sh
```

## Modules

| Area | Commands |
|------|----------|
| **Docker** | `dps`, `dsh`, `dlogs`, `dup`, `ddown`, `dbuild`, `dhealth`, `dprune` |
| **AgentHub** | `ai list`, `ai which`, `ai install`, `ai run`, `ai claude` |
| **SEX** | `sex init`, `sex list`, `sex up`, `sex up --dry` |
| **DevBuild** | `db`, `db tools`, `db build\|test\|run\|install\|clean` |

## AgentHub (bash)

Detection order: **PATH → bun global bin → npm global bin**.

```bash
ai list
ai install claude          # prefers bun if available
ai install codex bun
ai install antigravity     # Google Antigravity CLI (agy) — Gemini CLI successor
ai run claude
```

**Antigravity CLI** (`agy`) is Google’s replacement for Gemini CLI (I/O 2026).  
Download: https://antigravity.google/download

## SEX

Mini-YAML subset (targets + `cmd:` lines). Full dialect = PowerShell `sex`.

## Layout

```
contrib/bash/
  vai.sh           # entry (source or exec)
  lib/common.sh
  lib/docker.sh
  lib/agents.sh
  lib/sex.sh
  lib/build.sh
```

## Version

`0.2.0` — companion to VAI PowerShell **5.1.3+**.
