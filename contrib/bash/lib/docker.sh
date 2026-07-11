#!/usr/bin/env bash
# VAI docker module (bash) — closer to pwsh DockerTweaks

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
  [[ "${1:-}" == "-a" || "${1:-}" == "--all" || "${1:-}" == "-All" ]] && all=(-a)
  vai_banner "DOCKER" "containers"
  if [[ ${#all[@]} -gt 0 ]]; then
    docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
  else
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}'
  fi
  local up down
  up="$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"
  down="$(docker ps -aq -f status=exited 2>/dev/null | wc -l | tr -d ' ')"
  vai_rule
  printf "  %s %s\n" "$(vai_pill "up $up" ok)" "$(vai_pill "exited $down" dim)"
  echo ""
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
  printf "  %s %s\n" "$(vai_pill "exec" hot)" "$id"
  docker exec -it "$id" sh -c 'command -v bash >/dev/null && exec bash || exec sh'
}

cmd_dlogs() {
  vai_docker_ready || return 1
  local name="" follow=()
  for a in "$@"; do
    if [[ "$a" == "-f" || "$a" == "--follow" ]]; then follow=(-f)
    elif [[ -z "$name" ]]; then name="$a"
    fi
  done
  local id
  if [[ -n "$name" ]]; then
    id="$(docker ps -a --format '{{.ID}}\t{{.Names}}' | awk -v n="$name" '$2 ~ n {print $1; exit}')"
  else
    id="$(docker ps --format '{{.ID}}' | head -n1)"
  fi
  [[ -z "$id" ]] && { vai_err "no container"; return 1; }
  vai_banner "LOGS" "$id"
  docker logs --tail 100 --timestamps "${follow[@]}" "$id"
}

cmd_dup() {
  vai_docker_ready || return 1
  vai_banner "COMPOSE UP" "-d"
  vai_compose up -d "$@" && vai_ok "stack up"
}

cmd_ddown() {
  vai_docker_ready || return 1
  vai_banner "COMPOSE DOWN"
  vai_compose down "$@" && vai_ok "stack down"
}

cmd_dcmp() {
  vai_docker_ready || return 1
  vai_banner "COMPOSE PS"
  vai_compose ps
}

cmd_dbuild() {
  vai_docker_ready || return 1
  local tag="${1:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_.-' '-' ):dev}"
  vai_banner "BUILD" "$tag"
  docker build -t "$tag" . && vai_ok "built $tag"
}

cmd_dhealth() {
  vai_docker_ready || return 1
  vai_banner "DOCKER HEALTH"
  vai_kv "server" "$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?')"
  docker system df
}

cmd_dprune() {
  vai_docker_ready || return 1
  vai_banner "PRUNE"
  docker image prune -f
  docker builder prune -f
  docker network prune -f
  vai_ok "prune done"
  cmd_dhealth
}

cmd_dimg() {
  vai_docker_ready || return 1
  vai_banner "IMAGES"
  docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}'
}

cmd_dvol() {
  vai_docker_ready || return 1
  vai_banner "VOLUMES"
  docker volume ls
}

cmd_dnet() {
  vai_docker_ready || return 1
  vai_banner "NETWORKS"
  docker network ls
}

cmd_docker_help() {
  vai_banner "DOCKER (bash)" "v${VAI_BASH_VERSION}"
  cat <<'EOF'
  dps [-a]          list containers (+ pills)
  dsh [name]        shell into container
  dlogs [name] [-f] logs
  dup / ddown / dcmp  compose up -d / down / ps
  dbuild [tag]      docker build
  dimg dvol dnet    images / volumes / networks
  dhealth / dprune  disk + prune
EOF
}
