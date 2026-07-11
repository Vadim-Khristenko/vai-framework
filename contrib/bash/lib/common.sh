#!/usr/bin/env bash
# VAI bash lib — colors, log, tools, pills (bash 4+)
# shellcheck disable=SC2034

set -euo pipefail

VAI_BASH_VERSION="0.3.0"

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  VAI_C_MAGENTA=$'\033[38;5;201m'
  VAI_C_CYAN=$'\033[38;5;45m'
  VAI_C_GREEN=$'\033[38;5;82m'
  VAI_C_YELLOW=$'\033[38;5;220m'
  VAI_C_RED=$'\033[38;5;196m'
  VAI_C_GRAY=$'\033[38;5;244m'
  VAI_C_BLUE=$'\033[38;5;39m'
  VAI_C_RESET=$'\033[0m'
  VAI_PILL_OK=$'\033[38;5;16;48;5;82m'
  VAI_PILL_HOT=$'\033[38;5;16;48;5;201m'
  VAI_PILL_INFO=$'\033[38;5;16;48;5;45m'
  VAI_PILL_DIM=$'\033[38;5;250;48;5;236m'
  VAI_PILL_FAIL=$'\033[38;5;255;48;5;196m'
else
  VAI_C_MAGENTA=''
  VAI_C_CYAN=''
  VAI_C_GREEN=''
  VAI_C_YELLOW=''
  VAI_C_RED=''
  VAI_C_GRAY=''
  VAI_C_BLUE=''
  VAI_C_RESET=''
  VAI_PILL_OK=''
  VAI_PILL_HOT=''
  VAI_PILL_INFO=''
  VAI_PILL_DIM=''
  VAI_PILL_FAIL=''
fi

vai_banner() {
  local title="${1:-VAI}" sub="${2:-}"
  echo ""
  echo "  ${VAI_C_MAGENTA}╭──────────────────────────────────────────────────────────────╮${VAI_C_RESET}"
  printf "  ${VAI_C_MAGENTA}│${VAI_C_RESET}  %-60s${VAI_C_MAGENTA}│${VAI_C_RESET}\n" "$title"
  if [[ -n "$sub" ]]; then
    printf "  ${VAI_C_MAGENTA}│${VAI_C_RESET}  ${VAI_C_GRAY}%-60s${VAI_C_RESET}${VAI_C_MAGENTA}│${VAI_C_RESET}\n" "$sub"
  fi
  echo "  ${VAI_C_MAGENTA}╰──────────────────────────────────────────────────────────────╯${VAI_C_RESET}"
}

vai_pill() {
  local text="$1" kind="${2:-info}"
  local open=""
  case "$kind" in
    ok)   open="$VAI_PILL_OK" ;;
    hot)  open="$VAI_PILL_HOT" ;;
    fail) open="$VAI_PILL_FAIL" ;;
    dim)  open="$VAI_PILL_DIM" ;;
    *)    open="$VAI_PILL_INFO" ;;
  esac
  if [[ -n "$open" ]]; then
    printf '%s %s %s' "$open" "$text" "$VAI_C_RESET"
  else
    printf '[%s]' "$text"
  fi
}

vai_ok()   { echo "  ${VAI_C_GREEN}[OK]${VAI_C_RESET} $*"; }
vai_warn() { echo "  ${VAI_C_YELLOW}[!]${VAI_C_RESET} $*"; }
vai_err()  { echo "  ${VAI_C_RED}[X]${VAI_C_RESET} $*" >&2; }
vai_kv()   { printf "  ${VAI_C_GRAY}• %-12s${VAI_C_RESET} %s\n" "$1" "$2"; }
vai_rule() {
  local label="${1:-}"
  if [[ -n "$label" ]]; then
    echo "  ${VAI_C_GRAY}──── ${label} ────────────────────────────────────────${VAI_C_RESET}"
  else
    echo "  ${VAI_C_GRAY}────────────────────────────────────────────────────────${VAI_C_RESET}"
  fi
}

vai_has()  { command -v "$1" >/dev/null 2>&1; }

vai_tool() {
  local c
  for c in "$@"; do
    if vai_has "$c"; then
      command -v "$c"
      return 0
    fi
  done
  return 1
}

vai_project_root() {
  local d="${1:-$PWD}"
  while [[ "$d" != "/" ]]; do
    for m in .git sex.yaml sex.yml package.json Cargo.toml pyproject.toml go.mod; do
      if [[ -e "$d/$m" ]]; then
        echo "$d"
        return 0
      fi
    done
    d="$(dirname "$d")"
  done
  echo "$PWD"
}

# Rough module roster (parity with pwsh boot roster — status of tools)
vai_modules_list() {
  vai_banner "VAI MODULES" "bash companion v${VAI_BASH_VERSION}"
  echo "  ${VAI_C_GRAY}      name             status   notes${VAI_C_RESET}"
  vai_rule "roster"

  _row() {
    local name="$1" ok="$2" note="$3"
    if [[ "$ok" == "1" ]]; then
      printf "  %s %s %-16s %s\n" "$(vai_pill "ON" ok)" "${VAI_C_CYAN}" "$name" "${VAI_C_RESET}${VAI_C_GRAY}$note${VAI_C_RESET}"
    else
      printf "  %s %s %-16s %s\n" "$(vai_pill "off" dim)" "${VAI_C_GRAY}" "$name" "$note${VAI_C_RESET}"
    fi
  }

  _row "sex" 1 "task runner (sex.yaml)"
  _row "AgentHub" 1 "ai list|install|run"
  _row "DevBuild" 1 "db build|test|run"
  _row "Docker" "$(vai_has docker && echo 1 || echo 0)" "dps dup dhealth …"
  _row "Kubernetes" "$(vai_has kubectl && echo 1 || echo 0)" "kgp kctx klogs …"
  _row "Git" "$(vai_has git && echo 1 || echo 0)" "use host git / pwsh GitTweaks"
  echo ""
}

vai_doctor() {
  vai_banner "VAI DOCTOR" "bash environment"
  vai_kv "shim" "$VAI_BASH_VERSION"
  vai_kv "root" "${_VAI_BASH_ROOT:-?}"
  vai_kv "shell" "${BASH_VERSION:-?}"
  vai_kv "os" "$(uname -s 2>/dev/null || echo unknown)"
  vai_rule "tools"
  for t in pwsh docker kubectl git bun npm uv cargo go; do
    if vai_has "$t"; then
      printf "  %s %-10s %s\n" "$(vai_pill "ON" ok)" "$t" "$(command -v "$t")"
    else
      printf "  %s %s\n" "$(vai_pill "off" dim)" "$t"
    fi
  done
  echo ""
  printf "  %s %s %s\n" "$(vai_pill "tip" hot)" "" "${VAI_C_GRAY}Full experience: source PowerShell init.ps1${VAI_C_RESET}"
  echo ""
}
