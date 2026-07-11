#!/usr/bin/env bash
# VAI bash lib — colors, log, tools (bash 4+)
# shellcheck disable=SC2034

set -euo pipefail

VAI_BASH_VERSION="0.2.0"

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "1" ]]; then
  VAI_C_MAGENTA=$'\033[38;5;201m'
  VAI_C_CYAN=$'\033[38;5;45m'
  VAI_C_GREEN=$'\033[38;5;82m'
  VAI_C_YELLOW=$'\033[38;5;220m'
  VAI_C_RED=$'\033[38;5;196m'
  VAI_C_GRAY=$'\033[38;5;244m'
  VAI_C_BLUE=$'\033[38;5;39m'
  VAI_C_RESET=$'\033[0m'
else
  VAI_C_MAGENTA= VAI_C_CYAN= VAI_C_GREEN= VAI_C_YELLOW=
  VAI_C_RED= VAI_C_GRAY= VAI_C_BLUE= VAI_C_RESET=
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

vai_ok()   { echo "  ${VAI_C_GREEN}[OK]${VAI_C_RESET} $*"; }
vai_warn() { echo "  ${VAI_C_YELLOW}[!]${VAI_C_RESET} $*"; }
vai_err()  { echo "  ${VAI_C_RED}[X]${VAI_C_RESET} $*" >&2; }
vai_kv()   { printf "  ${VAI_C_GRAY}• %-12s${VAI_C_RESET} %s\n" "$1" "$2"; }
vai_rule() { echo "  ${VAI_C_GRAY}────────────────────────────────────────────────────────${VAI_C_RESET}"; }

vai_has()  { command -v "$1" >/dev/null 2>&1; }

vai_tool() {
  # resolve first available binary
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
