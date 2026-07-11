# VAI Bash Companion v0.3

Closer UX to PowerShell VAI: **banners, pills, doctor, modules roster, Kubernetes, Docker**.

PowerShell remains the **primary** runtime (full registry, SEX YAML dialect, TUI).

## Install

```bash
source /path/to/vai-framework/contrib/bash/vai.sh
# or
bash /path/to/vai-framework/contrib/bash/vai.sh help
```

`~/.bashrc`:

```bash
source ~/src/vai-framework/contrib/bash/vai.sh
```

## Commands (parity map)

| Area | Bash | PowerShell |
|------|------|------------|
| Boot help | `vai help` / `vai doctor` / `vai modules` | `. init.ps1` / `vai-doctor` / `vai-module list` |
| Docker | `dps` `dup` `dhealth` `dimg` … | same short names |
| Kubernetes | `kctx` `kns` `kgp` `klogs` `ksh` … | **KubeTweaks** module |
| Agents | `ai list` `ai install` `ai run` | `ai` |
| SEX | `sex init` `sex up` | `sex` |
| Build | `db build` | `db` |

## Kubernetes

```bash
kctx              # list / switch contexts
kns production    # set namespace
kgp               # pods
kgp -A
klogs my-pod -f
ksh my-pod
kapp deploy.yaml
kpf my-pod 8080:80
khelp
```

## Layout

```
contrib/bash/
  vai.sh
  lib/common.sh   # banners, pills, doctor, modules
  lib/docker.sh
  lib/k8s.sh
  lib/agents.sh
  lib/sex.sh
  lib/build.sh
```
