#!/usr/bin/env bash
# Preview Forge — monitor dispatcher.
#
# Gates every declarative monitor on the presence of an active pf workspace
# (cwd has a `runs/` directory with at least one run subdirectory). When the
# cwd is not a pf workspace, the dispatcher exits 0 silently — preventing
# idle monitors from running in every project that has the pf plugin enabled.
#
# Background: entries in monitors/monitors.json auto-start for every Claude
# Code session where the plugin is enabled, regardless of cwd. Before this
# dispatcher, the three pf monitors (blackboard-tail, cost-regression,
# cost-snapshot-watcher) looped in every cwd that lacked a runs/ directory,
# emitting noise and — on zsh without null_glob — hard errors. See
# issue #18 for the design discussion and #15 for the prior symptomatic fix.
#
# Usage (from monitors.json):
#   bash "${CLAUDE_PLUGIN_ROOT}/monitors/dispatch.sh" <monitor-name>

set -u

name="${1:-}"
if [ -z "$name" ]; then
  echo "dispatch.sh: missing monitor name" >&2
  exit 2
fi

# Workspace gate: exit 0 silently when cwd is not a pf workspace.
# A pf workspace has a `runs/` directory populated by /pf:new
# (commands/new.md: "runs/r-<ts>/ 디렉토리 생성 (cwd 기준)").
#
# We sleep for PF_MONITOR_IDLE_BACKOFF seconds (default 60) before
# exiting so the Claude Code monitor runner does not tight-respawn us
# in unrelated projects. One sleeping shell per monitor (~3 total) is
# the same idle footprint as v1.5.2 — but with zero work and zero
# stderr output. Tests that want to exercise the gate quickly can set
# PF_MONITOR_IDLE_BACKOFF=0.
idle_backoff="${PF_MONITOR_IDLE_BACKOFF:-60}"
if [ ! -d runs ] || ! find runs -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null | grep -q .; then
  [ "$idle_backoff" -gt 0 ] 2>/dev/null && sleep "$idle_backoff"
  exit 0
fi

: "${CLAUDE_PLUGIN_ROOT:=}"

# Sentinel pattern (shared by watermark-using monitors; see issue #20):
#   1. Initialize per-monitor watermark to epoch if missing (first run).
#   2. Capture "now" in <watermark>.next BEFORE running find, so any file
#      written between the capture and the find completion is still picked
#      up next iteration (compared against the OLD watermark this round,
#      the pre-find capture next round).
#   3. Promote <watermark>.next to <watermark> AFTER find. This would
#      otherwise be racey: a file written between find and touch would
#      have mtime > post-find-touch time and be permanently skipped.
#
# Prior to this, blackboard-tail and cost-snapshot-watcher shared a single
# runs/.last-check file — blackboard-tail never advanced it (repeat emits)
# and cost-snapshot-watcher's advance starved blackboard-tail of events.
case "$name" in
  blackboard-tail)
    # Emit ALL updated blackboard.db paths (one per line = one notification
    # each) before advancing the watermark. v1.5.2 used `| head -1` here but
    # never advanced the watermark, so the dropped entries were re-emitted
    # next iteration. Now that the watermark advances, truncating output
    # would permanently lose events from concurrent runs — drop head -1.
    [ -e runs/.last-check.blackboard ] || touch -t 197001010000 runs/.last-check.blackboard
    touch runs/.last-check.blackboard.next
    find runs -name 'blackboard.db' -newer runs/.last-check.blackboard 2>/dev/null || true
    touch -r runs/.last-check.blackboard.next runs/.last-check.blackboard 2>/dev/null || true
    sleep 1
    ;;
  cost-regression)
    find runs -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | while IFS= read -r d; do
      python3 "${CLAUDE_PLUGIN_ROOT}/hooks/cost-regression.py" "$d" 2>&1 | grep -E '(WARN|ALERT)' || true
    done
    sleep 30
    ;;
  cost-snapshot-watcher)
    [ -e runs/.last-check.cost-snapshot ] || touch -t 197001010000 runs/.last-check.cost-snapshot
    touch runs/.last-check.cost-snapshot.next
    find runs -name 'cost-snapshot.json' -newer runs/.last-check.cost-snapshot 2>/dev/null || true
    touch -r runs/.last-check.cost-snapshot.next runs/.last-check.cost-snapshot 2>/dev/null || true
    sleep 15
    ;;
  *)
    echo "dispatch.sh: unknown monitor '$name'" >&2
    exit 2
    ;;
esac
