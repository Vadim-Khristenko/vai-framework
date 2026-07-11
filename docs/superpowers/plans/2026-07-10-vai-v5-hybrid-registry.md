# VAI v5 Hybrid Registry Implementation Plan

> **For agentic workers:** Execute task-by-task. Checkboxes track progress. Inline execution preferred (single session, full control).

**Goal:** Ship VAI-Framework v5: hybrid registry (short + prefix + API), power core helpers, cross-platform boot, migrate 4 modules, SEX stub.

**Architecture:** Single registry (`VaiRegistry`) is source of truth; loaders bind short aliases and `prefix:cmd` proxies; modules register exports via `Register-VaiExport`; lazy stubs auto-bind from `config.json` Exports.

**Tech Stack:** PowerShell 5.1+ / 7+, no external deps required for core; optional yq/python for YAML later.

**Spec:** `docs/superpowers/specs/2026-07-10-vai-v5-hybrid-registry-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `init.ps1` | Bootstrap, Import-Vai, load core order |
| `core/VaiState.ps1` | `$Vai` root object, version 5, OS flags, colors |
| `core/VaiHelpers.ps1` | File/JSON/UX/merge/project helpers |
| `core/VaiPlatform.ps1` | OS, which, open URL/path, admin, native invoke |
| `core/VaiLogger.ps1` | Logging (use `$Vai.Colors`) |
| `core/VaiRegistry.ps1` | Register/Invoke/Get/Clear, prefix style |
| `core/VaiModuleLoader.ps1` | Scan, topo, load, lazy stubs |
| `core/VaiCli.ps1` | CLI: module, doctor, reload, new-module, call |
| `GitTweaks/*`, `DockerTweaks/*`, `vai-net/*`, `CommandNotFound/*` | Migrate to registry |
| `sex/*` | Stub: slogan, help, init |

---

### Task 1: VaiState v5

**Files:** Modify `core/VaiState.ps1`

- [ ] Replace flat globals with structured `$global:Vai` hashtable: Version, Root, Colors, M, Modules, LogLevel, PrefixStyle, IsWindows/Linux/MacOS/Core/Modern, Slogan.Sex
- [ ] Keep `$global:VaiFrameworkRoot`, `$global:VaiLogPath`, `$global:VaiModulesCache`, `$global:VaiLogLevels`, `$global:VaiMinLogLevel` for v4 bridge
- [ ] Legacy `$global:VAI_*` color aliases
- [ ] Cross-platform OS detection without clobbering automatic `$IsWindows`

**Verify:** `. .\init.ps1` later; after Task 1 alone not fully bootable until loader updated.

---

### Task 2: VaiPlatform + Helpers power-up

**Files:** Create `core/VaiPlatform.ps1`; Modify `core/VaiHelpers.ps1`

Platform:
- `Get-VaiOS`, `Test-VaiCommand`, `Invoke-VaiNative`, `Get-VaiTool`, `Assert-VaiCommand`
- `Get-VaiHomePath`, `Get-VaiConfigDir`, `Open-VaiUrl`, `Open-VaiPath`, `Test-VaiAdmin`

Helpers:
- Keep existing Read/Write JSON helpers
- Add: `Merge-VaiHashtable`, `Write-VaiHost`, `Write-VaiHeader`, `Write-VaiSeparator`, `Write-VaiOk/Warn/Error`, `Confirm-VaiAction`, `Get-VaiBar`, `Find-VaiProjectRoot`, `Resolve-VaiPath`, `Read-VaiYaml` (backend chain)

---

### Task 3: VaiRegistry

**Files:** Create `core/VaiRegistry.ps1`

- Internal: `$script:VaiExportTable` or under `$Vai._Registry`
- `Register-VaiExport -Module -Name -ScriptBlock [-Alias] [-Prefix]`
- Bind `$Vai.M.<Module>.<Name>`, prefix function, optional short alias
- `Invoke-Vai`, `Get-VaiModule`, `Get-VaiExport`, `Test-VaiModule`, `Clear-VaiRegistry`
- Detect PrefixStyle Colon vs Slash
- Track proxies for clean reload

---

### Task 4: Loader + init

**Files:** Modify `core/VaiModuleLoader.ps1`, `init.ps1`

- Load new core files in order
- Manifest: Prefix, Exports, ShortAliases, RegistryKey
- Lazy stubs from Exports
- Set `$VaiModule` context before dot-sourcing module.ps1
- `Import-Vai` function
- Version 5.0.0

---

### Task 5: VaiCli

**Files:** Modify `core/VaiCli.ps1`

- list/info show prefix + exports
- doctor: OS, registry count, prefix style
- new-module v5 template with Register-VaiExport
- vai-call → Invoke-Vai
- reload clears registry

---

### Task 6: Migrate CommandNotFound

**Files:** `CommandNotFound/config.json`, `module.ps1`

- Prefix `cnf`, Exports, Register-VaiExport
- Cross-platform package hints
- Use `$Vai.Colors`

---

### Task 7: Migrate GitTweaks

**Files:** `GitTweaks/config.json`, `module.ps1`

- Prefix `git`, all commands via registry
- Short aliases preserved

---

### Task 8: Migrate DockerTweaks

**Files:** `DockerTweaks/config.json`, `module.ps1`

- Prefix `docker`, LazyLoad true, Exports list

---

### Task 9: Migrate vai-net

**Files:** `vai-net/config.json`, `module.ps1`

- Prefix `net`, export keys ping/port/… with aliases vai-ping etc.

---

### Task 10: SEX stub

**Files:** Create `sex/config.json`, `changelog.json`, `module.ps1`

- Slogan, help, `sex init` sample yaml
- Dispatcher export `sex`

---

### Task 11: Smoke verification

```powershell
pwsh -NoProfile -Command ". D:\PowerShell\init.ps1; vai-doctor; Get-VaiExport; sex; Invoke-Vai Git help"
```

Expected: boot OK, no Failed critical, sex slogan, registry populated.

---

## Execution

User chose: **inline, full control, no subagent fan-out.**
