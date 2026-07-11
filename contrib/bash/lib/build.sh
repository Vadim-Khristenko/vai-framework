#!/usr/bin/env bash
# DevBuild (bash) — stack detect + presets

_detect_stack() {
  local root="${1:-$PWD}"
  if [[ -f "$root/Cargo.toml" ]] && vai_has cargo; then echo cargo; return; fi
  if [[ -f "$root/bun.lockb" || -f "$root/bun.lock" ]] && vai_has bun; then echo bun; return; fi
  if [[ -f "$root/pnpm-lock.yaml" ]] && vai_has pnpm; then echo pnpm; return; fi
  if [[ -f "$root/yarn.lock" ]] && vai_has yarn; then echo yarn; return; fi
  if [[ -f "$root/package.json" ]] && vai_has npm; then echo npm; return; fi
  if [[ -f "$root/uv.lock" || -f "$root/pyproject.toml" ]] && vai_has uv; then echo uv; return; fi
  if [[ -f "$root/go.mod" ]] && vai_has go; then echo go; return; fi
  if compgen -G "$root/*.sln" >/dev/null && vai_has dotnet; then echo dotnet; return; fi
  if [[ -f "$root/Makefile" ]] && vai_has make; then echo make; return; fi
  echo ""
}

_preset() {
  local action="$1" stack="$2"
  case "$stack:$action" in
    cargo:build)  echo "cargo build" ;;
    cargo:test)   echo "cargo test" ;;
    cargo:run)    echo "cargo run" ;;
    cargo:clean)  echo "cargo clean" ;;
    bun:build)    echo "bun run build" ;;
    bun:test)     echo "bun test" ;;
    bun:run)      echo "bun run dev" ;;
    bun:install)  echo "bun install" ;;
    npm:build)    echo "npm run build" ;;
    npm:test)     echo "npm test" ;;
    npm:run)      echo "npm run dev" ;;
    npm:install)  echo "npm install" ;;
    pnpm:build)   echo "pnpm run build" ;;
    pnpm:test)    echo "pnpm test" ;;
    pnpm:run)     echo "pnpm run dev" ;;
    pnpm:install) echo "pnpm install" ;;
    uv:test)      echo "uv run pytest" ;;
    uv:install)   echo "uv sync" ;;
    uv:run)       echo "uv run python main.py" ;;
    go:build)     echo "go build ./..." ;;
    go:test)      echo "go test ./..." ;;
    go:run)       echo "go run ." ;;
    dotnet:build) echo "dotnet build" ;;
    dotnet:test)  echo "dotnet test" ;;
    make:build)   echo "make" ;;
    make:test)    echo "make test" ;;
    *)            echo "" ;;
  esac
}

cmd_db() {
  local sub="${1:-}"; shift || true
  local root
  root="$(vai_project_root)"
  case "$sub" in
    ""|dash|status)
      vai_banner "DevBuild" "$root"
      local s
      s="$(_detect_stack "$root")"
      if [[ -n "$s" ]]; then vai_kv "stack" "$s"; else vai_warn "no stack detected"; fi
      echo "  db build|test|run|install|clean|tools"
      ;;
    tools)
      vai_banner "TOOLS"
      for t in cargo bun npm pnpm yarn uv go dotnet make docker; do
        if vai_has "$t"; then
          printf "  ${VAI_C_GREEN}[ON ]${VAI_C_RESET} %-10s %s\n" "$t" "$(command -v "$t")"
        else
          printf "  ${VAI_C_GRAY}[off]${VAI_C_RESET} %s\n" "$t"
        fi
      done
      ;;
    build|test|run|install|clean|fix|check)
      local stack="${VAI_STACK:-$(_detect_stack "$root")}"
      [[ -z "$stack" ]] && { vai_err "no stack — export VAI_STACK=cargo"; return 1; }
      local cmd
      cmd="$(_preset "$sub" "$stack")"
      [[ -z "$cmd" ]] && { vai_err "no preset $sub for $stack"; return 1; }
      vai_banner "DB · ${sub^^}" "$stack @ $root"
      vai_kv "cmd" "$cmd"
      vai_rule
      ( cd "$root" && eval "$cmd" )
      ;;
    *)
      vai_err "unknown: $sub"
      return 1
      ;;
  esac
}
