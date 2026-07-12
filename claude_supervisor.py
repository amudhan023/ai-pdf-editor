#!/usr/bin/env python3

import os
import subprocess
import time
import json
import re
from datetime import datetime, timedelta

# =========================================================
# PROJECT ROOT
# =========================================================
#
# WARNING: each iteration runs `claude -p` with cwd=PROJECT_DIR, doing real git
# operations (branch/commit) there. If you also work interactively in this same
# checkout while this script is running, your own `git checkout`/`branch`/`reset`
# can move the shared HEAD out from under a live iteration mid-task (observed
# 2026-07-05 - caught via `git reflog` and reverted with no data loss, but it was
# a live near-miss). Do any interactive git work in a separate `git worktree`
# instead: `git worktree add ../<dir> -b <branch> origin/main`. See
# docs/AGENT_LOOP.md §2 for the full writeup.

PROJECT_DIR = os.getcwd()

SUPERVISOR_DIR = os.path.join(PROJECT_DIR, ".claude-supervisor")
LOG_DIR = os.path.join(SUPERVISOR_DIR, "logs")
STATE_FILE = os.path.join(SUPERVISOR_DIR, "state.json")

TASKS_DIR = os.path.join(PROJECT_DIR, "tasks")

# =========================================================
# BOOTSTRAP PROMPT (Vaultform-native)
# =========================================================

BOOTSTRAP_PROMPT = """
Read CLAUDE.md.

You MUST follow docs/AGENT_LOOP.md exactly.

You are operating inside a strict task system.

RULES:
- Pick EXACTLY ONE task from tasks/backlog/<current-phase>/
- Do NOT guess or invent tasks
- Only select tasks whose dependencies are satisfied (tasks in tasks/done/)
- Move selected task to tasks/in-progress/
- Work ONLY within the primary package defined by the task
- Do NOT expand scope across packages unless explicitly marked [INTEGRATION]
- Run verify.sh <PackageName>
- Ensure CI readiness
- Fix issues until passing
- Update task state files
- Exit after completing ONE task only

If no valid task exists, exit immediately.
"""

# =========================================================
# CONFIG
# =========================================================

RETRY_DELAY_SECONDS = 30
SUCCESS_DELAY_SECONDS = 2

# A run that exits 0 but produces no new commit is not a completed task - it's
# the bootstrap prompt's "no valid task exists, exit immediately" path (empty
# or fully-blocked backlog), which used to be treated as SUCCESS and re-looped
# after only SUCCESS_DELAY_SECONDS - a near-infinite full-Claude-invocation
# spin once the backlog drains. Back off much further in that case instead.
NO_OP_DELAY_SECONDS = 300

# A real (non-token-limit) failure that keeps recurring - broken env, a task
# that can't pass verify.sh, etc. - has no natural "try again later" signal
# the way a token limit does. Retrying it forever at a flat 30s is the same
# class of silent waste the token-limit-detection gap already cost ~3 hours
# once (see TOKEN_ERROR_PATTERNS below). Stop and surface it instead.
MAX_CONSECUTIVE_FAILURES = 5

TOKEN_RESET_TIMES = ["02:00", "06:00", "14:00", "18:00", "23:00"]

# Match on the exact wording Claude's CLI has been observed to use, not a guess at what
# it "should" say - "session limit" wasn't in this list originally and cost ~3 hours of a
# 30s-retry spin loop (337 no-op cycles, $0 cost but pure waste) before being caught and
# added on 2026-07-05. If a future rate-limit message slips past this list again, add its
# exact phrase here rather than trying to generalize the wording.
TOKEN_ERROR_PATTERNS = [
    "token limit",
    "usage limit",
    "session limit",
    "rate limit",
    "quota exceeded",
    "try again later",
    "too many requests",
    '"api_error_status":429',
    '"api_error_status": 429',
]

# =========================================================
# UTIL
# =========================================================

def ensure_dirs():
    os.makedirs(LOG_DIR, exist_ok=True)


def log(msg):
    line = f"[{datetime.now().isoformat()}] {msg}"
    print(line)

    with open(os.path.join(LOG_DIR, "supervisor.log"), "a") as f:
        f.write(line + "\n")


def git_head():
    """Current commit SHA of PROJECT_DIR's checked-out ref, or None on any
    failure. Used to tell a real completed task (produces a commit) apart
    from a no-op run (empty/blocked backlog, or a task that made no
    progress) - both exit 0, so exit code alone can't distinguish them."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=10,
        )
        return result.stdout.strip() if result.returncode == 0 else None
    except Exception:
        return None


def load_state():
    if not os.path.exists(STATE_FILE):
        return {}
    with open(STATE_FILE, "r") as f:
        return json.load(f)


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# =========================================================
# PROJECT VALIDATION
# =========================================================

def validate_project():
    required = ["CLAUDE.md", "tasks"]
    for f in required:
        if not os.path.exists(os.path.join(PROJECT_DIR, f)):
            raise Exception(f"Missing required path: {f}")


# =========================================================
# TASK VALIDATION LAYER (light enforcement)
# =========================================================

def list_tasks(folder):
    path = os.path.join(TASKS_DIR, folder)
    if not os.path.exists(path):
        return []
    return [f for f in os.listdir(path) if f.endswith(".md")]


def has_in_progress_conflict(task_file):
    inprog = list_tasks("in-progress")
    return task_file in inprog


# =========================================================
# TOKEN RESET LOGIC (macOS safe)
# =========================================================

def next_reset_seconds():
    now = datetime.now()
    today = now.date()

    candidates = []

    for t in TOKEN_RESET_TIMES:
        hh, mm = map(int, t.split(":"))
        target = datetime.combine(today, datetime.min.time()).replace(hour=hh, minute=mm)
        if target <= now:
            target += timedelta(days=1)
        candidates.append((target - now).total_seconds())

    return min(candidates)


TOKEN_POLL_INTERVAL_SECONDS = 300


def wait_for_reset(state):
    """Re-probe with a real request every TOKEN_POLL_INTERVAL_SECONDS instead of
    blindly sleeping for the full duration implied by the fixed reset-time table
    (that table is only a guess and the actual usage window can reopen sooner)."""
    max_wait = next_reset_seconds()
    deadline = time.time() + max_wait
    hours = int(max_wait // 3600)
    minutes = int((max_wait % 3600) // 60)

    log(f"⛔ Token limit hit. Probing every {TOKEN_POLL_INTERVAL_SECONDS // 60}m "
        f"(safety cap {hours}h {minutes}m)")

    while time.time() < deadline:
        time.sleep(TOKEN_POLL_INTERVAL_SECONDS)

        state["runs"] += 1
        save_state(state)

        exit_code, output = run_claude(state)

        with open(os.path.join(LOG_DIR, f"run-{state['runs']}.log"), "w") as f:
            f.write(output or "")

        if not is_token_limit(output):
            log("✅ Token window resumed (detected via probe)")
            return exit_code, output

        log("⏳ Still rate-limited, continuing to probe...")

    log("⚠️ Safety cap reached without a clean probe; resuming normal loop")
    return None


# =========================================================
# TOKEN DETECTION
# =========================================================

def is_token_limit(output):
    if not output:
        return False
    text = output.lower()
    return any(p in text for p in TOKEN_ERROR_PATTERNS)


# =========================================================
# CLAUDE EXECUTION
# =========================================================
#
# NOTE: a task killed by CLAUDE_RUN_TIMEOUT_SECONDS leaves whatever it had
# uncommitted sitting in the working tree, and the *next* invocation is a brand
# new `claude -p` session with zero memory of that in-progress work (each
# invocation is stateless - no conversation continuity). See docs/AGENT_LOOP.md
# Step 3 for why small, frequent commits are the mitigation, not just style.
#
# NOTE: if you edit this file while an instance of it is already running, the
# running process keeps the old code in memory (Python doesn't hot-reload) -
# you must kill and restart the process for a fix to actually take effect.

CLAUDE_RUN_TIMEOUT_SECONDS = 900


def run_claude(state):
    log("🚀 Launching Claude (non-interactive print mode)...")

    try:
        proc = subprocess.run(
            [
                "claude",
                "-p", BOOTSTRAP_PROMPT,
                "--output-format", "json",
                "--permission-mode", "bypassPermissions",
                "--effort", "medium",
            ],
            cwd=PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=CLAUDE_RUN_TIMEOUT_SECONDS,
        )

        output = proc.stdout + proc.stderr

        is_error = proc.returncode != 0
        try:
            parsed = json.loads(proc.stdout)
            is_error = is_error or bool(parsed.get("is_error", False))
        except (json.JSONDecodeError, AttributeError):
            pass

        return (1 if is_error else 0), output

    except subprocess.TimeoutExpired as e:
        log(f"❌ Claude run timed out after {CLAUDE_RUN_TIMEOUT_SECONDS}s")
        timed_out_output = (e.stdout or "") + (e.stderr or "")
        return 1, timed_out_output

    except Exception as e:
        log(f"❌ Claude execution failure: {e}")
        return 1, str(e)

# =========================================================
# OUTCOME CLASSIFICATION
# =========================================================

def record_outcome(state, exit_code, head_before, head_after):
    """Classifies one run, updates the consecutive-no-op/consecutive-failure
    counters in `state`, and returns how long to sleep before the next run -
    or None to signal the supervisor should stop entirely.

    exit_code == 0 alone does not mean a task was completed: the bootstrap
    prompt's "no valid task exists, exit immediately" path also exits 0. The
    only reliable signal that real work happened is a new commit (the task
    workflow is commit-per-task by design), so a exit-0 run whose HEAD didn't
    move is treated as a no-op and backed off harder, not as success.
    """
    if exit_code == 0:
        made_progress = bool(head_after) and head_after != head_before
        if made_progress:
            log("✅ Task completed (single-task contract fulfilled)")
            state["consecutive_no_op_runs"] = 0
        else:
            state["consecutive_no_op_runs"] += 1
            log(
                "💤 No commits produced (empty/blocked backlog, or a no-op run) - "
                f"consecutive no-op runs: {state['consecutive_no_op_runs']}"
            )
        state["consecutive_failures"] = 0
        save_state(state)
        return SUCCESS_DELAY_SECONDS if made_progress else NO_OP_DELAY_SECONDS

    state["consecutive_failures"] += 1
    save_state(state)

    if state["consecutive_failures"] >= MAX_CONSECUTIVE_FAILURES:
        log(
            f"🛑 {state['consecutive_failures']} consecutive failures - stopping the "
            f"supervisor for human review instead of retrying forever. "
            f"Check {LOG_DIR}/run-{state['runs']}.log for the latest failure."
        )
        return None

    log(f"⚠️ Failure detected (consecutive: {state['consecutive_failures']}), retrying...")
    return RETRY_DELAY_SECONDS


# =========================================================
# MAIN LOOP
# =========================================================

def main():
    ensure_dirs()
    validate_project()

    log("===================================")
    log(" Vaultform Claude Supervisor ")
    log("===================================")

    state = load_state()
    state.setdefault("runs", 0)
    state.setdefault("token_hits", 0)
    state.setdefault("consecutive_no_op_runs", 0)
    state.setdefault("consecutive_failures", 0)

    while True:
        state["runs"] += 1
        save_state(state)

        head_before = git_head()
        exit_code, output = run_claude(state)

        with open(os.path.join(LOG_DIR, f"run-{state['runs']}.log"), "w") as f:
            f.write(output or "")

        log(f"Claude exit code: {exit_code}")

        # -----------------------------
        # TOKEN HANDLING
        # -----------------------------
        if is_token_limit(output):
            state["token_hits"] += 1
            save_state(state)

            result = wait_for_reset(state)
            if result is not None:
                exit_code, output = result
                log(f"Claude exit code: {exit_code}")
                sleep_seconds = record_outcome(state, exit_code, head_before, git_head())
                if sleep_seconds is None:
                    return
                time.sleep(sleep_seconds)
            continue

        # -----------------------------
        # OUTCOME (success / no-op / failure)
        # -----------------------------
        sleep_seconds = record_outcome(state, exit_code, head_before, git_head())
        if sleep_seconds is None:
            return
        time.sleep(sleep_seconds)


if __name__ == "__main__":
    main()