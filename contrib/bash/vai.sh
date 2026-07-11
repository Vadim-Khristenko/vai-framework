#!/usr/bin/env bash
# =============================================================================
# VAI Framework — Bash advanced shim (v0.2)
# Companion to PowerShell VAI — not full parity, production-minded subset.
# Usage:
#   source /path/to/contrib/bash/vai.sh
#   vai help | dps | ai list | sex init | db build
# =============================================================================

# Resolve lib dir even when sourced
_VAI_BASH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/common.sh"
# shellcheck source=/dev/null
source "$_VAI_BASH_ROOT/lib/docker.sh"
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
    vai help              this help
    vai version           versions

  Docker:
    dps dsh dlogs dup ddown dbuild dhealth dprune
    vai docker help

  Agents:
    ai list | which | install | run
    ai claude | ai antigravity

  SEX:
    sex init | list | which | <target> [--dry]

  DevBuild:
    db | db tools | db build|test|run|install|clean

  PowerShell remains primary. This is the portable companion.
EOF
      ;;
    version)
      vai_kv "bash-shim" "$VAI_BASH_VERSION"
      vai_kv "root" "$_VAI_BASH_ROOT"
      vai_has docker && vai_kv "docker" "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo client-only)"
      vai_has bun && vai_kv "bun" "$(bun --version 2>/dev/null)"
      vai_has npm && vai_kv "npm" "$(npm --version 2>/dev/null)"
      ;;
    docker) cmd_docker_help ;;
    ai)     cmd_ai "$@" ;;
    sex)    cmd_sex "$@" ;;
    db)     cmd_db "$@" ;;
    dps)    cmd_dps "$@" ;;
    dsh)    cmd_dsh "$@" ;;
    dlogs)  cmd_dlogs "$@" ;;
    dup)    cmd_dup "$@" ;;
    ddown)  cmd_ddown "$@" ;;
    dbuild) cmd_dbuild "$@" ;;
    dhealth) cmd_dhealth "$@" ;;
    dprune) cmd_dprune "$@" ;;
    *)
      vai_err "unknown: $cmd — vai help"
      return 1
      ;;
  esac
}

# Convenience aliases when sourced (optional — comment out if noisy)
alias dps='cmd_dps'
alias dsh='cmd_dsh'
alias dlogs='cmd_dlogs'
alias dup='cmd_dup'
alias ddown='cmd_ddown'
alias dbuild='cmd_dbuild'
alias dhealth='cmd_dhealth'
alias dprune='cmd_dprune'
alias ai='cmd_ai'
alias sex='cmd_sex'
alias db='cmd_db'

# If executed (not sourced), run as CLI
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  vai "$@"
fi
