# Architecture (overview)

## Goals

- **Namespaced modules** without polluting the global scope by accident
- **Three call surfaces**: short · prefix · API
- **Lazy load** for heavy tools (Docker, Git helpers)
- **Cross-platform** core with graceful degradation

## Boot pipeline

1. `init.ps1` sets `VaiFrameworkRoot`, loads `core/*` in order.
2. `Initialize-VaiRegistry` probes prefix style (`git:cmd` vs slash).
3. `Initialize-VaiModules` scans `modules/`, topo-sorts, loads or stubs.
4. `Show-VaiBootSummary` prints the module roster.

## Registry

`Register-VaiExport -Module -Name -ScriptBlock [-Alias] [-Prefix]`

- Stores scriptblock in `$Vai.M.<Module>.<Name>`
- Binds `function:<prefix>:<name>` (or slash style)
- Optionally binds short global alias

## Module contract

```
modules/Name/
  config.json     # Meta + Settings + Exports
  module.ps1      # Register-VaiExport calls
  lib/*.ps1       # optional split (dot-sourced in module scope)
  changelog.json
```

## SEX

Config discovery → parse YAML/JSON → run steps → open URLs → after message.  
See README § SEX.

## Bash companion

`contrib/bash/` mirrors a subset for non-pwsh environments. Not full parity.
