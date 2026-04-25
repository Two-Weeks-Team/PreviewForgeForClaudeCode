#!/usr/bin/env bash
# Preview Forge — Phase 2 (Gap B fix): post-H2 local preview server launcher.
#
# Bridges the gap between TestDD freeze (H2 approval) and the user actually
# seeing the generated app in their browser. Before this script the user had
# to run `pnpm -r dev` or `docker compose up` manually after every freeze,
# breaking the README "human clicks twice" promise and the
# DEMO-STORYBOARD.md L1:50–2:00 expectation that a new tab pops up at
# http://localhost:18080 automatically.
#
# Profiles auto-detected from <run_dir> contents (also probes <run_dir>/generated/
# since be-lead.md and the QA leads write apps to runs/<id>/generated/, while
# /pf:freeze and /pf:preview pass `runs/<id>/`):
#   1. pro / max     — docker-compose.yml at run_dir/ or run_dir/generated/.
#                      → `docker compose up -d`, wait for any service Up,
#                        extract first published port, open browser.
#   2. standard      — apps/api/package.json AND apps/web/package.json at
#                      run_dir/ or run_dir/generated/.
#                      → install (pnpm > npm), pick free port from 18080+,
#                        spawn api + web `pnpm dev` in background, persist
#                        PIDs, wait for web TCP, open browser.
#   3. neither       — exit 2 with stderr message (TestDD scaffold incomplete).
#
# CLI:
#   start-preview-server.sh <run_dir>
#       Idempotent: if PIDs in <run_dir>/.preview-server.pid are alive,
#       only re-open the browser. Otherwise start fresh.
#   start-preview-server.sh stop <run_dir>
#       SIGTERM → wait 5s → SIGKILL. For docker, `docker compose down`.
#       Removes .preview-server.{pid,id,url}. Idempotent (no-op if no PID).
#   start-preview-server.sh status <run_dir>
#       Exit 0 if a preview server is running for <run_dir> (PIDs alive
#       OR docker project still up), prints URL on stdout.
#       Exit 1 otherwise.
#
# Env flags (test/CI helpers):
#   PF_PREVIEW_DRY_RUN=1   — print the actions that would happen, then exit
#                            0. No `pnpm install`, no `docker compose up`,
#                            no background process spawn, no browser open.
#                            Used by tests/fixtures/post-h2-preview to keep
#                            the unit suite light. Profile detection still
#                            runs; missing-scaffold still exits 2.
#
# Style anchors:
#   - exit-code contract follows scripts/h1-modal-helper.sh
#   - browser open delegated to scripts/open-browser.sh
#   - portability: lsof is preinstalled on macOS+Linux; pnpm fallback to
#     npm; docker check via `command -v`.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENER="$SCRIPT_DIR/open-browser.sh"

usage() {
  cat <<'EOF' >&2
usage:
  start-preview-server.sh <run_dir>
  start-preview-server.sh stop <run_dir>
  start-preview-server.sh status <run_dir>
EOF
  exit 1
}

# ---- arg parsing ----
action="start"
case "${1:-}" in
  "" )
    usage
    ;;
  stop|status )
    action="$1"
    shift
    ;;
esac

run_dir="${1:-}"
[ -n "$run_dir" ] || usage
# Strip trailing slash for consistent file paths.
run_dir="${run_dir%/}"
if [ ! -d "$run_dir" ]; then
  echo "start-preview-server.sh: run_dir not found: $run_dir" >&2
  exit 1
fi

PID_FILE="$run_dir/.preview-server.pid"
ID_FILE="$run_dir/.preview-server.id"
URL_FILE="$run_dir/.preview-server.url"
API_LOG="$run_dir/.preview-api.log"
WEB_LOG="$run_dir/.preview-web.log"

# ---- helpers ----
pids_alive() {
  # Echo each alive PID found in PID_FILE; return 0 if any alive.
  [ -f "$PID_FILE" ] || return 1
  local any=1 line pid
  while IFS= read -r line; do
    # lines look like "api 12345" or "web 67890" or just "12345"
    pid="${line##* }"
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      any=0
    fi
  done <"$PID_FILE"
  return "$any"
}

docker_project_up() {
  [ -f "$ID_FILE" ] || return 1
  local compose_file="${scaffold_root:-$run_dir}/docker-compose.yml"
  [ -f "$compose_file" ] || return 1
  command -v docker >/dev/null 2>&1 || return 1
  # Any service in `running` state?
  local running
  running="$(docker compose -f "$compose_file" ps --status running --quiet 2>/dev/null || true)"
  [ -n "$running" ]
}

pick_free_port() {
  # Print first free TCP port in [start, start+max-1]; exit 1 if none found.
  local start="$1" max="${2:-11}" p
  for ((i = 0; i < max; i++)); do
    p=$((start + i))
    if command -v lsof >/dev/null 2>&1; then
      lsof -iTCP:"$p" -sTCP:LISTEN -Pn >/dev/null 2>&1 || { echo "$p"; return 0; }
    else
      # Fallback: try /dev/tcp probe (bash-only; cheap).
      (echo > "/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1 || { echo "$p"; return 0; }
    fi
  done
  return 1
}

wait_tcp() {
  # wait_tcp <host> <port> <timeout_sec>
  local host="$1" port="$2" timeout="$3" t=0
  while [ "$t" -lt "$timeout" ]; do
    if command -v nc >/dev/null 2>&1; then
      nc -z "$host" "$port" >/dev/null 2>&1 && return 0
    else
      (echo > "/dev/tcp/$host/$port") >/dev/null 2>&1 && return 0
    fi
    sleep 1
    t=$((t + 1))
  done
  return 1
}

open_url() {
  local url="$1"
  if [ -x "$OPENER" ] || [ -r "$OPENER" ]; then
    bash "$OPENER" "$url" >/dev/null 2>&1 || true
  fi
  echo "$url" >"$URL_FILE"
  echo "preview server up: $url"
}

# ---- profile detection ----
# Engineering teams (be-lead.md) write apps to `runs/<id>/generated/`, but
# `/pf:freeze` and `/pf:preview` instruct callers to pass `runs/<id>/`. So if
# the scaffold isn't directly under run_dir, transparently fall through to
# `<run_dir>/generated/` before declaring "scaffold missing".
scaffold_root=""
profile=""
for cand in "$run_dir" "$run_dir/generated"; do
  if [ -f "$cand/docker-compose.yml" ]; then
    scaffold_root="$cand"; profile="docker"; break
  elif [ -f "$cand/apps/api/package.json" ] && [ -f "$cand/apps/web/package.json" ]; then
    scaffold_root="$cand"; profile="standard"; break
  fi
done

# ---- action: status ----
if [ "$action" = "status" ]; then
  case "$profile" in
    standard )
      if pids_alive >/dev/null; then
        [ -f "$URL_FILE" ] && cat "$URL_FILE" || echo "running"
        exit 0
      fi
      ;;
    docker )
      if docker_project_up; then
        [ -f "$URL_FILE" ] && cat "$URL_FILE" || echo "running"
        exit 0
      fi
      ;;
  esac
  echo "no preview server for $run_dir" >&2
  exit 1
fi

# ---- action: stop ----
if [ "$action" = "stop" ]; then
  # PID-based stop (standard).
  if [ -f "$PID_FILE" ]; then
    while IFS= read -r line; do
      pid="${line##* }"
      case "$pid" in ''|*[!0-9]*) continue ;; esac
      kill -TERM "$pid" 2>/dev/null || true
    done <"$PID_FILE"
    # Wait up to 5s for graceful exit.
    for _ in 1 2 3 4 5; do
      pids_alive >/dev/null || break
      sleep 1
    done
    if pids_alive >/dev/null; then
      while IFS= read -r line; do
        pid="${line##* }"
        case "$pid" in ''|*[!0-9]*) continue ;; esac
        kill -KILL "$pid" 2>/dev/null || true
      done <"$PID_FILE"
    fi
    rm -f "$PID_FILE"
  fi
  # Docker-based stop. Scaffold may live under either run_dir or run_dir/generated.
  stop_compose=""
  for cand in "$run_dir" "$run_dir/generated"; do
    if [ -f "$cand/docker-compose.yml" ]; then
      stop_compose="$cand/docker-compose.yml"; break
    fi
  done
  if [ -f "$ID_FILE" ] && [ -n "$stop_compose" ] && command -v docker >/dev/null 2>&1; then
    docker compose -f "$stop_compose" down >/dev/null 2>&1 || true
  fi
  rm -f "$ID_FILE" "$URL_FILE"
  echo "preview server stopped (run_dir=$run_dir)"
  exit 0
fi

# ---- action: start (default) ----

# No profile detected → caller has not run TestDD freeze yet.
if [ -z "$profile" ]; then
  echo "neither apps/{api,web}/package.json nor docker-compose.yml found in $run_dir or $run_dir/generated; cannot start preview server" >&2
  exit 2
fi

# Idempotency: if something is already alive, just re-open the URL.
if [ "$profile" = "standard" ] && pids_alive >/dev/null; then
  if [ -f "$URL_FILE" ]; then
    url="$(cat "$URL_FILE")"
    echo "preview server already running (idempotent re-open)"
    if [ "${PF_PREVIEW_DRY_RUN:-0}" = "1" ]; then
      echo "[dry-run] would re-open $url"
      exit 0
    fi
    open_url "$url"
    exit 0
  fi
fi
if [ "$profile" = "docker" ] && docker_project_up; then
  if [ -f "$URL_FILE" ]; then
    url="$(cat "$URL_FILE")"
    echo "preview server already running (idempotent re-open)"
    if [ "${PF_PREVIEW_DRY_RUN:-0}" = "1" ]; then
      echo "[dry-run] would re-open $url"
      exit 0
    fi
    open_url "$url"
    exit 0
  fi
fi

# ---- profile: docker (pro / max) ----
if [ "$profile" = "docker" ]; then
  compose_file="$scaffold_root/docker-compose.yml"
  if [ "${PF_PREVIEW_DRY_RUN:-0}" = "1" ]; then
    echo "[dry-run] profile=docker compose_file=$compose_file"
    echo "[dry-run] would: docker compose -f $compose_file up -d --quiet-pull"
    echo "[dry-run] would: poll docker compose ps until any service Up (≤30s)"
    echo "[dry-run] would: extract first published port and open-browser.sh"
    exit 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "start-preview-server.sh: docker not on PATH but $compose_file requires it" >&2
    exit 1
  fi
  docker compose -f "$compose_file" up -d --quiet-pull >/dev/null 2>&1 || {
    echo "start-preview-server.sh: docker compose up failed; see compose logs" >&2
    exit 1
  }
  # Wait up to 30s for at least one service running.
  t=0
  while [ "$t" -lt 30 ]; do
    if [ -n "$(docker compose -f "$compose_file" ps --status running --quiet 2>/dev/null || true)" ]; then
      break
    fi
    sleep 1
    t=$((t + 1))
  done
  # Extract first host port via `docker compose ps --format json`.
  port=""
  host="localhost"
  if command -v python3 >/dev/null 2>&1; then
    port="$(docker compose -f "$compose_file" ps --format json 2>/dev/null \
      | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
records = []
if raw:
    # Older docker emits a single JSON array; newer ones emit NDJSON.
    try:
        parsed = json.loads(raw)
        records = parsed if isinstance(parsed, list) else [parsed]
    except json.JSONDecodeError:
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue
for rec in records:
    if not isinstance(rec, dict):
        continue
    for p in rec.get("Publishers") or []:
        pub = p.get("PublishedPort")
        if pub:
            print(pub); sys.exit(0)
' || true)"
  fi
  if [ -z "$port" ]; then
    # Fallback: assume Caddy or web service on 18080 per project convention.
    port="18080"
  fi
  # Stash compose project name (basename of run_dir is used by default).
  project_name="$(basename "$run_dir")"
  echo "$project_name" >"$ID_FILE"
  url="http://$host:$port/"
  open_url "$url"
  exit 0
fi

# ---- profile: standard (apps/api + apps/web) ----
api_dir="$scaffold_root/apps/api"
web_dir="$scaffold_root/apps/web"

# Pick free ports: web on 18080+, api on 18180+ (offset of 100 keeps logs scannable).
web_port="$(pick_free_port 18080 11)" || {
  echo "start-preview-server.sh: no free port in 18080..18090" >&2
  exit 1
}
api_port="$(pick_free_port 18180 11)" || {
  echo "start-preview-server.sh: no free port in 18180..18190" >&2
  exit 1
}

if [ "${PF_PREVIEW_DRY_RUN:-0}" = "1" ]; then
  echo "[dry-run] profile=standard"
  echo "[dry-run] api_dir=$api_dir api_port=$api_port"
  echo "[dry-run] web_dir=$web_dir web_port=$web_port"
  echo "[dry-run] would: install deps (pnpm > npm), spawn api+web in background"
  echo "[dry-run] would: wait_tcp 127.0.0.1 $web_port 60"
  echo "[dry-run] would: open http://localhost:$web_port/"
  exit 0
fi

# Install deps. Prefer pnpm if pnpm-lock.yaml exists; else npm.
pkg_mgr=""
if command -v pnpm >/dev/null 2>&1 && [ -f "$scaffold_root/pnpm-lock.yaml" ]; then
  pkg_mgr="pnpm"
elif command -v pnpm >/dev/null 2>&1 && [ -f "$scaffold_root/pnpm-workspace.yaml" ]; then
  pkg_mgr="pnpm"
elif command -v npm >/dev/null 2>&1; then
  pkg_mgr="npm"
else
  echo "start-preview-server.sh: neither pnpm nor npm available" >&2
  exit 1
fi
case "$pkg_mgr" in
  pnpm )
    (cd "$scaffold_root" && pnpm install --frozen-lockfile >/dev/null 2>&1) || \
      (cd "$scaffold_root" && pnpm install >/dev/null 2>&1) || {
        echo "start-preview-server.sh: pnpm install failed in $scaffold_root" >&2
        exit 1
      }
    dev_cmd="pnpm dev"
    ;;
  npm )
    (cd "$scaffold_root" && npm install >/dev/null 2>&1) || true
    (cd "$api_dir" && npm install >/dev/null 2>&1) || true
    (cd "$web_dir" && npm install >/dev/null 2>&1) || true
    dev_cmd="npm run dev"
    ;;
esac

# Cleanup spawned api/web on early exit so a wait_tcp timeout does not leak
# zombie processes that would still hold the port and force the next retry to
# pick a higher port (causing PID_FILE drift).
cleanup_spawned() {
  local pid
  for pid in "${api_pid:-}" "${web_pid:-}"; do
    case "$pid" in
      ''|*[!0-9]*) continue ;;
    esac
    kill -TERM "$pid" 2>/dev/null || true
  done
  rm -f "$PID_FILE"
}

# Spawn api + web in background, redirecting output. nohup detaches them
# from the controlling tty so they survive shell exit.
api_pid="$( ( cd "$api_dir" && PORT="$api_port" nohup $dev_cmd >"$API_LOG" 2>&1 & echo $! ) )"
web_pid="$( ( cd "$web_dir" && PORT="$web_port" NEXT_PUBLIC_API_URL="http://localhost:$api_port" nohup $dev_cmd >"$WEB_LOG" 2>&1 & echo $! ) )"

# Persist PIDs (one per line, role-labeled).
{
  echo "api $api_pid"
  echo "web $web_pid"
} >"$PID_FILE"

# Wait for web to accept TCP (up to 60s).
if ! wait_tcp 127.0.0.1 "$web_port" 60; then
  echo "start-preview-server.sh: web server did not start on :$web_port within 60s" >&2
  echo "  api log: $API_LOG"
  echo "  web log: $WEB_LOG"
  cleanup_spawned
  exit 1
fi

url="http://localhost:$web_port/"
open_url "$url"
exit 0
