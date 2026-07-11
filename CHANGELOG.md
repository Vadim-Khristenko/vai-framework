# Changelog

All notable changes to **VAI-Framework** are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/).  
Versioning follows [SemVer](https://semver.org/).

## [5.2.0] - 2026-07-11

### Added
- **KubeTweaks** module: `kctx` `kns` `kgp` `kgd` `kgs` `kgn` `klogs` `ksh` `ktop` `kdesc` `kapp` `kdel` `kwatch` `kpf` `kev`
- Bash companion **v0.3**: pills, `vai doctor` / `vai modules`, full k8s helpers, richer docker

### Improved
- Bash UX closer to PowerShell (banners, status pills, parity command map)

## [5.1.3] - 2026-07-11

### Added
- DockerTweaks **1.5**: `dbuild`, `dcp`, `dports`, `dhealth`, `dprune`, `dcmp`, `dclogs`
- AgentHub **1.3**: PATH + bun + npm detection; `ai install`; **Antigravity CLI** (Google, successor to Gemini CLI)
- Advanced bash companion under `contrib/bash/` (docker, agents, sex, devbuild)

### Fixed
- `Write-VaiKV` color argument handling in AgentHub
- Module roster UI: every module counted and listed (including lazy)

## [5.1.0] - 2026-07-10

### Added
- Hybrid registry: short aliases, `prefix:cmd`, `Invoke-Vai` / `$Vai.M`
- Power core: TUI, platform helpers, YAML mini-dialect, update scaffolding
- Modules under `modules/`: sex, AgentHub, DevBuild, Git, Docker, Net, CommandNotFound
- SEX full runner (`sex.yaml`), slogan *Ship. Execute. eXcite.*

## [5.0.0] - 2026-07-10

### Added
- Initial hybrid registry architecture (v5)

## [4.0.0] - earlier

### Added
- Original core loader, module manifests, Git/Docker/Net/CNF modules
