#!/usr/bin/env bash
# VAI docker module (bash) — advanced wrappers
# shellcheck source=common.sh

vai_docker_ready() {
  if ! vai_has docker; then
    vai_err "docker not in PATH"
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    vai_warn "docker daemon not responding"
    return 1
  fi
  return 0
}

vai_compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif vai_has docker-compose; then
    docker-compose "$@"
  else
    vai_err "docker compose not available"
    return 1
  fi
}

cmd_dps() {
  vai_docker_ready || return 1
  local all=()
  [[ "${1:-}" == "-a" || "${1:-}" == "--all" ]] && all=(-a)
  vai_banner "DOCKER" "containers"
  docker ps "${all[@]}" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
}

cmd_dsh() {
  vai_docker_ready || return 1
  local name="${1:-}" id
  if [[ -n "$name" ]]; then
    id="$(docker ps --format '{{.ID}}\t{{.Names}}' | awk -v n="$name" '$2 ~ n {print $1; exit}')"
  else
    id="$(docker ps --format '{{.ID}}' | head -n1)"
  fi
  [[ -z "$id" ]] && { vai_err "no running container"; return 1; }
  vai_ok "exec into $id"
  docker exec -it "$id" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

cmd_dlogs() {
  vai_docker_ready || return 1
  local name="${1:-}" follow=()
  [[ "${2:-}" == "-f" || "${1:-}" == "-f" ]] && follow=(-f)
  local id
  if [[ -n "$name" && "$name" != "-f" ]]; then
    id="$(docker ps -a --format '{{.ID}}\t{{.Names}}' | awk -v n="$name" '$2 ~ n {print $1; exit}')"
  else
    id="$(docker ps --format '{{.ID}}' | head -n1)"
  fi
  [[ -z "$id" ]] && { vai_err "no container"; return 1; }
  docker logs --tail 100 --timestamps "${follow[@]}" "$id"
}

cmd_dup() {
  vai_docker_ready || return 1
  vai_banner "COMPOSE UP" "-d"
  vai_compose up -d "$@"
}

cmd_ddown() {
  vai_docker_ready || return 1
  vai_banner "COMPOSE DOWN"
  vai_compose down "$@"
}

cmd_dhealth() {
  vai_docker_ready || return 1
  vai_banner "DOCKER HEALTH"
  vai_kv "server" "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?')"
  docker system df
}

cmd_dbuild() {
  vai_docker_ready || return 1
  local tag="${1:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]'):dev}"
  vai_banner "BUILD" "$tag"
  docker build -t "$tag" .
}

cmd_dprune() {
  vai_docker_ready || return 1
  vai_banner "PRUNE"
  docker image prune -f
  docker builder prune -f
  docker network prune -f
  vai_ok "prune done"
}

cmd_docker_help() {
  vai_banner "DOCKER (bash)" "v0.2"
  cat <<'EOF'
  dps [-a]          list containers
  dsh [name]        shell into container
  dlogs [name] [-f] logs
  dup / ddown       compose up -d / down
  dbuild [tag]      docker build
  dhealth / dprune  disk + prune
EOF
}
