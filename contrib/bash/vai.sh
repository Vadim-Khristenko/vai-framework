#!/usr/bin/env bash
# =============================================================================
# VAI Framework — Bash companion (v0.3)
# Closer UX to PowerShell VAI: banners, pills, doctor, modules, k8s, docker
# Usage:
#   source /path/to/contrib/bash/vai.sh
#   vai help | vai doctor | dps | kgp | ai list | sex init | db build
# =============================================================================

_VAI_BASH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/docker.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/k8s.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/agents.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/sex.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/build.sh"

vai() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    help|-h|--help)
      vai_banner "VAI bash" "v${VAI_BASH_VERSION} · Ship. Execute. eXcite."
      cat <<'EOF'
  Core:
    vai help | version | doctor | modules

  Docker:     dps dsh dlogs dup ddown dcmp dbuild dimg dvol dnet dhealth dprune
  Kubernetes: kctx kns kgp kgd kgs kgn klogs ksh ktop kapp kev kpf khelp
  Agents:     ai list | which | install | run | doctor
  SEX:        sex init | list | which | <target> [--dry]
  DevBuild:   db | db tools | db build|test|run|install|clean

  PowerShell remains primary (. .\init.ps1). This shim tracks the same vibes.
EOF
      ;;
    version)
      vai_banner "VERSION" "bash companion"
      vai_kv "bash-shim" "$VAI_BASH_VERSION"
      vai_kv "root" "$_VAI_BASH_ROOT"
      vai_has docker && vai_kv "docker" "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo client-only)"
      vai_has kubectl && vai_kv "kubectl" "$(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion:/{print $2; exit}')"
      vai_has bun && vai_kv "bun" "$(bun --version 2>/dev/null)"
      vai_has npm && vai_kv "npm" "$(npm --version 2>/dev/null)"
      ;;
    doctor|doc)   vai_doctor ;;
    modules|list) vai_modules_list ;;
    docker)       cmd_docker_help ;;
    k|kube|khelp) cmd_khelp ;;
    ai)           cmd_ai "$@" ;;
    sex)          cmd_sex "$@" ;;
    db)           cmd_db "$@" ;;
    # docker shortcuts
    dps)     cmd_dps "$@" ;;
    dsh)     cmd_dsh "$@" ;;
    dlogs)   cmd_dlogs "$@" ;;
    dup)     cmd_dup "$@" ;;
    ddown)   cmd_ddown "$@" ;;
    dcmp)    cmd_dcmp "$@" ;;
    dbuild)  cmd_dbuild "$@" ;;
    dhealth) cmd_dhealth "$@" ;;
    dprune)  cmd_dprune "$@" ;;
    dimg)    cmd_dimg "$@" ;;
    dvol)    cmd_dvol "$@" ;;
    dnet)    cmd_dnet "$@" ;;
    # k8s
    kctx)    cmd_kctx "$@" ;;
    kns)     cmd_kns "$@" ;;
    kgp)     cmd_kgp "$@" ;;
    kgd)     cmd_kgd "$@" ;;
    kgs)     cmd_kgs "$@" ;;
    kgn)     cmd_kgn "$@" ;;
    klogs)   cmd_klogs "$@" ;;
    ksh)     cmd_ksh "$@" ;;
    ktop)    cmd_ktop "$@" ;;
    kapp)    cmd_kapp "$@" ;;
    kev)     cmd_kev "$@" ;;
    kpf)     cmd_kpf "$@" ;;
    *)
      vai_err "unknown: $cmd — vai help"
      return 1
      ;;
  esac
}

# Convenience aliases when sourced
alias dps='cmd_dps'
alias dsh='cmd_dsh'
alias dlogs='cmd_dlogs'
alias dup='cmd_dup'
alias ddown='cmd_ddown'
alias dcmp='cmd_dcmp'
alias dbuild='cmd_dbuild'
alias dhealth='cmd_dhealth'
alias dprune='cmd_dprune'
alias dimg='cmd_dimg'
alias dvol='cmd_dvol'
alias dnet='cmd_dnet'
alias kctx='cmd_kctx'
alias kns='cmd_kns'
alias kgp='cmd_kgp'
alias kgd='cmd_kgd'
alias kgs='cmd_kgs'
alias kgn='cmd_kgn'
alias klogs='cmd_klogs'
alias ksh='cmd_ksh'
alias ktop='cmd_ktop'
alias kapp='cmd_kapp'
alias kev='cmd_kev'
alias kpf='cmd_kpf'
alias khelp='cmd_khelp'
alias ai='cmd_ai'
alias sex='cmd_sex'
alias db='cmd_db'

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vai "$@"
fi
