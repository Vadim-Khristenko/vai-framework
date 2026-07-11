#!/usr/bin/env bash
# SEX — Script EXecutor (bash) — mini YAML runner for simple sex.yaml
# Slogan: Ship. Execute. eXcite.

SEX_SLOGAN="Ship. Execute. eXcite."

_sex_find_config() {
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    for f in sex.yaml sex.yml; do
      [[ -f "$d/$f" ]] && { echo "$d/$f"; return 0; }
    done
    d="$(dirname "$d")"
  done
  return 1
}

_sex_sample() {
  cat <<EOF
# SEX — Script EXecutor
# $SEX_SLOGAN
name: my-app
default: up

targets:
  up:
    desc: "Spin up local dev"
    run:
      - cmd: echo SEX bash is live
    after: "You're in. $SEX_SLOGAN"

  test:
    desc: "Tests"
    run:
      - cmd: echo wire tests here
EOF
}

# Very small subset: list target names + run first 'cmd:' under target
_sex_list_targets() {
  local cfg="$1"
  awk '
    /^targets:/ { in_t=1; next }
    in_t && /^[a-zA-Z0-9_-]+:/ && !/^  / { in_t=0 }
    in_t && /^  [a-zA-Z0-9_-]+:/ {
      gsub(/:/,"",$1); gsub(/^  /,"",$1); print $1
    }
  ' "$cfg"
}

_sex_run_target() {
  local cfg="$1" target="$2" dry="${3:-0}"
  local in_target=0 in_run=0
  vai_banner "SEX · $target" "$SEX_SLOGAN"
  vai_kv "config" "$cfg"

  while IFS= read -r line || [[ -n "$line" ]]; do
    # skip comments/empty
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue

    if [[ "$line" =~ ^[[:space:]]{2}${target}: ]]; then
      in_target=1; in_run=0; continue
    fi
    if [[ $in_target -eq 1 && "$line" =~ ^[[:space:]]{2}[a-zA-Z0-9_-]+: && ! "$line" =~ ^[[:space:]]{2}${target}: ]]; then
      # next sibling target
      if [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
        in_target=0; in_run=0
      fi
    fi
    if [[ $in_target -eq 1 && "$line" =~ ^[[:space:]]{4}run: ]]; then
      in_run=1; continue
    fi
    if [[ $in_run -eq 1 && "$line" =~ cmd:[[:space:]]*(.*)$ ]]; then
      local cmd="${BASH_REMATCH[1]}"
      cmd="${cmd#\"}"; cmd="${cmd%\"}"
      cmd="${cmd#\'}"; cmd="${cmd%\'}"
      if [[ "$dry" == "1" ]]; then
        echo "  ${VAI_C_YELLOW}-${VAI_C_RESET} $cmd"
      else
        echo "  ${VAI_C_GREEN}+${VAI_C_RESET} $cmd"
        # shellcheck disable=SC2086
        eval "$cmd" || vai_warn "step failed: $cmd"
      fi
    fi
    if [[ $in_run -eq 1 && "$line" =~ ^[[:space:]]{4}[a-z]+: && ! "$line" =~ run: ]]; then
      in_run=0
    fi
  done < "$cfg"
  echo ""
  echo "  ${VAI_C_MAGENTA}$SEX_SLOGAN${VAI_C_RESET}"
}

cmd_sex() {
  local sub="${1:-help}"; shift || true
  case "$sub" in
    help|-h|--help|"")
      vai_banner "SEX" "$SEX_SLOGAN"
      echo "  sex init | list | which | <target> | <target> --dry"
      ;;
    init)
      if [[ -f sex.yaml ]]; then
        vai_warn "sex.yaml exists"
      else
        _sex_sample > sex.yaml
        vai_ok "wrote sex.yaml"
      fi
      ;;
    which)
      if cfg="$(_sex_find_config)"; then vai_ok "config: $cfg"; else vai_warn "no sex.yaml"; fi
      ;;
    list|ls)
      cfg="$(_sex_find_config)" || { vai_err "no sex.yaml — sex init"; return 1; }
      vai_banner "SEX TARGETS" "$cfg"
      _sex_list_targets "$cfg" | while read -r t; do echo "  ${VAI_C_GREEN}$t${VAI_C_RESET}"; done
      ;;
    *)
      local dry=0 target="$sub"
      for a in "$@"; do [[ "$a" == "--dry" ]] && dry=1; done
      cfg="$(_sex_find_config)" || { vai_err "no sex.yaml — sex init"; return 1; }
      _sex_run_target "$cfg" "$target" "$dry"
      ;;
  esac
}
