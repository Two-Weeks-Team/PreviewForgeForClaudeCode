#!/usr/bin/env bash
# Preview Forge — `claude` CLI stub PLACEHOLDER (T-7, issue #79).
#
# WHY THIS FILE LOOKS NEARLY EMPTY
# --------------------------------
# The original T-7 spec proposed prepending a fake `claude` CLI to PATH so
# `/pf:new` would route to a stub that fed canned AskUserQuestion answers.
# That approach turned out to be intractable in v1.6 scope:
#
#   - `/pf:new` is a Claude Code slash command whose backing markdown
#     (`plugins/preview-forge/commands/new.md`) is interpreted by the LLM at
#     runtime. There is no `claude` binary that, given the markdown, will
#     mechanically execute its 12-step orchestration without an LLM.
#   - Faithful stubbing would require re-implementing AskUserQuestion modal
#     dispatch, the 26-Task() parallel advocate fan-out, and Blackboard write
#     semantics — itself a multi-week project that would also need maintenance
#     every time an agent prompt changed (the very "maintenance overhead"
#     concern that originally deferred T-7 in ASSESSMENT.md).
#
# CHOSEN STRATEGY: DIRECT-SCRIPT-INVOCATION
# -----------------------------------------
# `tests/e2e/mock-bootstrap.sh` instead drives the *deterministic* scripts the
# real /pf:new pipeline invokes (filled-ratio-gate, generate-gallery,
# h1-modal-helper, lint-framework-convergence, generate-spec-anchor-audit) and
# materialises canned spec + advocate cards in between. This catches every
# regression in those scripts + the schemas they consume — which is the
# subset of /pf:new that *can* break without an LLM in the loop.
#
# This file remains so future contributors who grep for `claude-stub.sh` (the
# name in plan/noble-enchanting-floyd.md and ASSESSMENT.md) land on the
# rationale for why a CLI-level stub does NOT exist. If the project ever
# adopts a real claude-CLI replay engine (e.g. Anthropic ships a recorder),
# this is where it would live.
#
# Exit 0 so accidental invocation does not break CI.
echo "claude-stub.sh: not used — see file header for the direct-script-invocation rationale" >&2
exit 0
