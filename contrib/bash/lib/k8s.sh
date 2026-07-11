#!/usr/bin/env bash
# Kubernetes helpers (bash) — closer to pwsh KubeTweaks

_kube_ready() {
  if ! vai_has kubectl; then
    vai_err "kubectl not in PATH"
    return 1
  fi
  return 0
}

_kube_ctx() { kubectl config current-context 2>/dev/null || echo "(none)"; }
_kube_ns() {
  local ns
  ns="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)"
  [[ -z "$ns" ]] && ns="default"
  echo "$ns"
}

cmd_kctx() {
  _kube_ready || return 1
  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-l" || "$name" == "--list" ]]; then
    vai_banner "CONTEXTS" "current: $(_kube_ctx)"
    local cur c
    cur="$(_kube_ctx)"
    while IFS= read -r c; do
      [[ -z "$c" ]] && continue
      if [[ "$c" == "$cur" ]]; then
        printf "  %s %s %s\n" "$(vai_pill "*" hot)" "$(vai_pill "current" ok)" "${VAI_C_CYAN}$c${VAI_C_RESET}"
      else
        echo "      ${VAI_C_GRAY}$c${VAI_C_RESET}"
      fi
    done < <(kubectl config get-contexts -o name 2>/dev/null)
    echo ""
    return 0
  fi
  kubectl config use-context "$name" && vai_ok "context → $name"
}

cmd_kns() {
  _kube_ready || return 1
  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-l" ]]; then
    vai_banner "NAMESPACES" "current: $(_kube_ns)"
    local cur n
    cur="$(_kube_ns)"
    while IFS= read -r n; do
      [[ -z "$n" ]] && continue
      if [[ "$n" == "$cur" ]]; then
        printf "  %s %s\n" "$(vai_pill "current" ok)" "${VAI_C_GREEN}$n${VAI_C_RESET}"
      else
        echo "      $n"
      fi
    done < <(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
    echo ""
    return 0
  fi
  kubectl config set-context --current --namespace="$name" && vai_ok "namespace → $name"
}

cmd_kgp() {
  _kube_ready || return 1
  vai_banner "PODS" "ctx=$(_kube_ctx) · ns=$(_kube_ns)"
  if [[ "${1:-}" == "-A" || "${1:-}" == "--all" ]]; then
    kubectl get pods -A -o wide
  else
    kubectl get pods -o wide "$@"
  fi
}

cmd_kgd() { _kube_ready || return 1; vai_banner "DEPLOYMENTS"; kubectl get deploy -o wide "$@"; }
cmd_kgs() { _kube_ready || return 1; vai_banner "SERVICES"; kubectl get svc -o wide "$@"; }
cmd_kgn() { _kube_ready || return 1; vai_banner "NODES"; kubectl get nodes -o wide; }

cmd_klogs() {
  _kube_ready || return 1
  local pod="${1:-}" follow=()
  shift || true
  for a in "$@"; do [[ "$a" == "-f" || "$a" == "--follow" ]] && follow=(-f); done
  if [[ -z "$pod" ]]; then
    pod="$(kubectl get pods --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -n1)"
  fi
  [[ -z "$pod" ]] && { vai_err "no pod"; return 1; }
  vai_banner "LOGS" "$pod"
  kubectl logs --tail=100 "${follow[@]}" "$pod"
}

cmd_ksh() {
  _kube_ready || return 1
  local pod="${1:-}"
  if [[ -z "$pod" ]]; then
    pod="$(kubectl get pods --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -n1)"
  fi
  [[ -z "$pod" ]] && { vai_err "no pod"; return 1; }
  printf "  %s %s\n" "$(vai_pill "exec" hot)" "$pod"
  kubectl exec -it "$pod" -- sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

cmd_ktop() {
  _kube_ready || return 1
  local what="${1:-pods}"
  vai_banner "TOP" "$what"
  if [[ "$what" == "nodes" ]]; then kubectl top nodes; else kubectl top pods "$@"; fi
}

cmd_kapp() {
  _kube_ready || return 1
  local f="${1:-}"
  [[ -z "$f" || ! -f "$f" ]] && { vai_err "usage: kapp <file.yaml>"; return 1; }
  vai_banner "APPLY" "$f"
  kubectl apply -f "$f" && vai_ok "applied"
}

cmd_kev() {
  _kube_ready || return 1
  vai_banner "EVENTS"
  kubectl get events --sort-by=.lastTimestamp "$@"
}

cmd_kpf() {
  _kube_ready || return 1
  local pod="${1:-}" ports="${2:-8080:80}"
  [[ -z "$pod" ]] && { vai_err "usage: kpf <pod> [local:remote]"; return 1; }
  vai_banner "PORT-FORWARD" "$pod · $ports"
  kubectl port-forward "pod/$pod" "$ports"
}

cmd_khelp() {
  vai_banner "KUBE (bash)" "v${VAI_BASH_VERSION}"
  cat <<'EOF'
  kctx [name]       list / switch context
  kns  [name]       list / set namespace
  kgp [-A]          get pods
  kgd kgs kgn       deploy / svc / nodes
  klogs [pod] [-f]  logs
  ksh [pod]         shell
  ktop [pods|nodes] top
  kapp <file>       apply -f
  kev               events
  kpf <pod> [ports] port-forward
EOF
}
