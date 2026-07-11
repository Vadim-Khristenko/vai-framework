# VAI User Guide

## Installation

```powershell
git clone https://github.com/Vadim-Khristenko/vai-framework.git
cd vai-framework
. .\init.ps1
```

Profile (example):

```powershell
# $PROFILE
. "$HOME\src\vai-framework\init.ps1"
```

## Portable load

```powershell
Import-Vai -Root "C:\tools\vai-framework" -Modules Git,sex -Quiet
Invoke-Vai Git gs
```

## Registry surfaces

| Surface | Example |
|---------|---------|
| Short | `gs`, `dps`, `sex up` |
| Prefix | `git:gs`, `docker:dps` |
| API | `Invoke-Vai Git gs`, `$Vai.M.Sex.sex` |

Prefix style is detected at boot (`Colon` or `Slash` fallback).

## Writing a module

```powershell
vai-new-module CoolStuff -Prefix cool
# → modules/CoolStuff/{config.json,module.ps1,lib/01-main.ps1,changelog.json}
vai-reload
cool-hello   # or cool:hello / Invoke-Vai Cool hello
```

`config.json` essentials:

- `Meta.Name`, `Meta.Prefix`, `Meta.Version`
- `Settings.EnableModule`, `LazyLoad`, `Exports`, `ShortAliases`, `DependsOn`

## SEX deep dive

See the **SEX** section in the [README](../README.md#sex--script-executor).

Config discovery and runner semantics are implemented in:

- `modules/sex/lib/01-config.ps1`
- `modules/sex/lib/02-runner.ps1`
- `modules/sex/lib/03-cli.ps1`

## Updates

```powershell
$env:VAI_UPDATE_REPO = "Vadim-Khristenko/vai-framework"
vai-update
```

## Bash

```bash
source contrib/bash/vai.sh
vai help
```
