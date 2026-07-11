#!/usr/bin/env bash
# VAI AgentHub (bash) — PATH + bun + npm detect, install, launch
# Antigravity CLI (agy) replaces Gemini CLI (Google I/O 2026)

# key|name|bins(comma)|npm_pkg|bun_pkg|hint
AGENT_ROWS=(
  "claude|Claude Code|claude|@anthropic-ai/claude-code|@anthropic-ai/claude-code|npm/bun global"
  "grok|Grok Build|grok,grok-build|||Install from xAI"
  "codex|OpenAI Codex|codex|@openai/codex|@openai/codex|npm/bun global"
  "opencode|OpenCode|opencode|opencode-ai|opencode-ai|npm/bun global"
  "cursor|Cursor|cursor,cursor-agent|||https://cursor.com"
  "aider|Aider|aider|||uv tool install aider-chat"
  "antigravity|Antigravity CLI|agy,antigravity,antigravity-cli|||https://antigravity.google/download (Gemini CLI successor)"
  "ollama|Ollama|ollama|||https://ollama.com"
)

_agent_field() {
  local row="$1" idx="$2"
  echo "$row" | cut -d'|' -f"$idx"
}

_bun_has_bin() {
  local bin="$1" dir
  vai_has bun || return 1
  dir="$(bun pm bin -g 2>/dev/null | tr -d '\r' || true)"
  [[ -n "$dir" && -x "$dir/$bin" ]] || [[ -n "$dir" && -f "$dir/$bin" ]]
}

_npm_has_bin() {
  local bin="$1" dir
  vai_has npm || return 1
  dir="$(npm bin -g 2>/dev/null | tr -d '\r' || true)"
  [[ -n "$dir" && ( -x "$dir/$bin" || -f "$dir/$bin" ) ]]
}

_resolve_agent() {
  # sets RES_KEY RES_NAME RES_PATH RES_VIA RES_HINT RES_NPM RES_BUN
  local key="$1" row bins b
  RES_KEY= RES_NAME= RES_PATH= RES_VIA= RES_HINT= RES_NPM= RES_BUN=
  for row in "${AGENT_ROWS[@]}"; do
    [[ "$(_agent_field "$row" 1)" == "$key" ]] || continue
    RES_KEY="$key"
    RES_NAME="$(_agent_field "$row" 2)"
    RES_HINT="$(_agent_field "$row" 6)"
    RES_NPM="$(_agent_field "$row" 4)"
    RES_BUN="$(_agent_field "$row" 5)"
    IFS=',' read -ra bins <<< "$(_agent_field "$row" 3)"
    for b in "${bins[@]}"; do
      if vai_has "$b"; then
        RES_PATH="$(command -v "$b")"
        RES_VIA="path"
        return 0
      fi
    done
    for b in "${bins[@]}"; do
      if _bun_has_bin "$b"; then
        RES_PATH="$(bun pm bin -g 2>/dev/null | tr -d '\r')/$b"
        RES_VIA="bun"
        return 0
      fi
    done
    for b in "${bins[@]}"; do
      if _npm_has_bin "$b"; then
        RES_PATH="$(npm bin -g 2>/dev/null | tr -d '\r')/$b"
        RES_VIA="npm"
        return 0
      fi
    done
    return 1
  done
  return 2
}

cmd_ai_list() {
  vai_banner "AgentHub" "PATH · bun · npm"
  local row key present path via
  local on=0 total=0
  for row in "${AGENT_ROWS[@]}"; do
    total=$((total + 1))
    key="$(_agent_field "$row" 1)"
    if _resolve_agent "$key"; then
      on=$((on + 1))
      printf "  ${VAI_C_GREEN}[ON ]${VAI_C_RESET} ${VAI_C_GRAY}%-4s${VAI_C_RESET} ${VAI_C_CYAN}%-12s${VAI_C_RESET} %s\n" \
        "$RES_VIA" "$key" "$RES_PATH"
    else
      printf "  ${VAI_C_GRAY}[off]${VAI_C_RESET}      %-12s %s\n" "$key" "$(_agent_field "$row" 2)"
    fi
  done
  vai_rule
  vai_kv "ready" "$on / $total"
  vai_kv "managers" "bun=$(vai_has bun && echo yes || echo no) npm=$(vai_has npm && echo yes || echo no)"
}

cmd_ai_which() {
  local key="${1:-}"
  [[ -z "$key" ]] && { vai_err "usage: ai which <agent>"; return 1; }
  [[ "$key" == "gemini" ]] && key="antigravity"
  if _resolve_agent "$key"; then
    vai_ok "$key → $RES_PATH (via $RES_VIA)"
  else
    vai_warn "$key not found"
    _resolve_agent "$key" || true
    # print hint from row
    local row
    for row in "${AGENT_ROWS[@]}"; do
      [[ "$(_agent_field "$row" 1)" == "$key" ]] && { vai_kv "hint" "$(_agent_field "$row" 6)"; break; }
    done
  fi
}

cmd_ai_install() {
  local key="${1:-}" via="${2:-auto}"
  [[ -z "$key" ]] && { vai_err "usage: ai install <agent> [bun|npm|auto]"; return 1; }
  [[ "$key" == "gemini" ]] && { vai_warn "Gemini CLI deprecated → antigravity"; key="antigravity"; }

  local row npm_pkg bun_pkg hint
  for row in "${AGENT_ROWS[@]}"; do
    [[ "$(_agent_field "$row" 1)" == "$key" ]] || continue
    npm_pkg="$(_agent_field "$row" 4)"
    bun_pkg="$(_agent_field "$row" 5)"
    hint="$(_agent_field "$row" 6)"
    break
  done
  [[ -z "${hint:-}" && -z "${npm_pkg:-}" ]] && { vai_err "unknown agent $key"; return 1; }

  vai_banner "AI INSTALL" "$key"

  if _resolve_agent "$key"; then
    vai_ok "already installed: $RES_PATH"
    return 0
  fi

  if [[ "$via" == "auto" ]]; then
    if [[ -n "$bun_pkg" ]] && vai_has bun; then via="bun"
    elif [[ -n "$npm_pkg" ]] && vai_has npm; then via="npm"
    else via="manual"
    fi
  fi

  vai_kv "method" "$via"
  case "$via" in
    bun)
      [[ -z "$bun_pkg" ]] && { vai_err "no bun package"; return 1; }
      vai_has bun || { vai_err "bun missing"; return 1; }
      bun add -g "$bun_pkg"
      ;;
    npm)
      [[ -z "$npm_pkg" ]] && { vai_err "no npm package"; return 1; }
      vai_has npm || { vai_err "npm missing"; return 1; }
      npm i -g "$npm_pkg"
      ;;
    *)
      vai_warn "manual install"
      echo "  $hint"
      if [[ "$key" == "antigravity" ]]; then
        echo "  ${VAI_C_CYAN}https://antigravity.google/download${VAI_C_RESET}"
      fi
      return 0
      ;;
  esac

  if _resolve_agent "$key"; then
    vai_ok "installed: $RES_PATH"
  else
    vai_warn "install ran; binary not on PATH yet — restart shell"
  fi
}

cmd_ai_run() {
  local key="${1:-}"; shift || true
  [[ -z "$key" ]] && { vai_err "usage: ai run <agent> [args...]"; return 1; }
  [[ "$key" == "gemini" ]] && key="antigravity"
  if ! _resolve_agent "$key"; then
    vai_err "$key not installed — try: ai install $key"
    return 1
  fi
  vai_banner "AI · $key" "$RES_PATH"
  exec "$RES_PATH" "$@"
}

cmd_ai() {
  local sub="${1:-list}"; shift || true
  case "$sub" in
    list|ls|"") cmd_ai_list ;;
    which)      cmd_ai_which "${1:-}" ;;
    install|i)  cmd_ai_install "${1:-}" "${2:-auto}" ;;
    run)        cmd_ai_run "$@" ;;
    help|-h)    vai_banner "AgentHub (bash)"; echo "  ai list | which | install | run";;
    *)
      # shortcut: ai claude
      if _resolve_agent "$sub" 2>/dev/null || [[ "$sub" == "gemini" ]]; then
        cmd_ai_run "$sub" "$@"
      else
        vai_err "unknown: $sub"
        return 1
      fi
      ;;
  esac
}
