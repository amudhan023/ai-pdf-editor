#!/usr/bin/env python3

import os
import shutil
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
# PROMPTS (Vaultform-native)
# =========================================================
#
# The loop is split into two `claude -p` calls per iteration instead of one:
# SELECT_PROMPT claims a task (AGENT_LOOP.md Step 0 only) and stops, then the
# supervisor reads the claimed task file's `Complexity` field *before*
# deciding what effort to spend on it, and WORK_PROMPT does the actual work
# (Steps 1-9) at that effort. A single opaque call can't do this because the
# supervisor process never learns which task was picked, or its Complexity,
# until after the (already effort-committed) call returns.

SELECT_PROMPT = """
Read CLAUDE.md.

You MUST follow docs/AGENT_LOOP.md Step 0 (SELECT) exactly, and ONLY Step 0.

Perform task selection and claiming ONLY:
- Refresh main; scan tasks/in-progress/ for packages already claimed by other agents.
- From tasks/backlog/<earliest-incomplete-phase>/, pick the highest-priority
  unblocked task per AGENT_LOOP.md Step 0 (dependencies satisfied in
  tasks/done/, primary package unclaimed; Critical > High > Medium, ties
  broken by unblocking power).
- Move the task file to tasks/in-progress/, add the Owner/Branch/Claimed
  header, and commit that move directly to main (this is the lock).
- Do NOT create a task branch, do NOT implement anything, do NOT run
  verify.sh, do NOT open a PR.

If no valid unblocked task exists, exit immediately without making any changes.

Stop after the claim commit (or after determining no task exists). Do not
proceed to Orient/Plan/Implement.
"""

WORK_PROMPT = """
Read CLAUDE.md.

You MUST follow docs/AGENT_LOOP.md exactly, continuing from Step 1 (ORIENT) onward.

A task has already been selected and claimed for you: exactly one file in
tasks/in-progress/ has an Owner/Branch/Claimed header from this run's
selection step. Do NOT re-select or claim a different task - use that one.
If it turns out to be unworkable (e.g. a conflict discovered only now),
follow AGENT_LOOP.md's escalation rules rather than silently picking another.

RULES:
- Branch task/<ID>-<slug> from main per the claim's Branch header.
- Work ONLY within the primary package defined by the task.
- Do NOT expand scope across packages unless explicitly marked [INTEGRATION]
- Run verify.sh <PackageName>
- Ensure CI readiness
- Fix issues until passing
- Update task state files
- Exit after completing ONE task only
"""

# =========================================================
# CONFIG
# =========================================================

RETRY_DELAY_SECONDS = 30
SUCCESS_DELAY_SECONDS = 2

# The task workflow (tasks/README.md) is trunk-based off main - every task
# branch, PR, and merge assumes it. Starting the loop from anywhere else
# means every branch it creates is based on the wrong tree.
REQUIRED_START_BRANCH = "main"

REQUIRED_COMMANDS = ["claude", "git"]

# The supervisor's own bookkeeping - state.json plus a fresh run-N.log every
# iteration - churns the working tree by design on every single run, so a
# working-tree-cleanliness preflight check has to exclude it; otherwise the
# check would fail on literally every restart, including the very first one
# after a previous run.
SUPERVISOR_OWN_PATH_PREFIX = ".claude-supervisor/"

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

# The selection-only call (SELECT_PROMPT) just refreshes main, scans two
# directories, and does one file move + commit - it should never need
# anywhere near the full work budget. Kept separate from the work call's
# timeout so a stuck selection fails fast instead of eating the whole
# per-iteration budget before the agent even starts the real task.
SELECT_RUN_TIMEOUT_SECONDS = 180

# tasks/README.md "## Complexity scale": S ~= <=1 agent-day, M ~= 1-3 days,
# L ~= 3-5 days. Mirrors that ordering directly - not derived from any other
# signal (task explicitly wants a static table, not a heuristic).
COMPLEXITY_EFFORT = {
    "S": "low",
    "M": "medium",
    "L": "high",
}

# Falls back here whenever Complexity can't be determined at all (missing
# field, malformed header, or no task was actually selected) - per this
# task's Requirements, that must never fail or stall the iteration.
DEFAULT_EFFORT = "medium"

# CLAUDE.md SS7/SS8 outrank token-cost optimization: security/boundary-sensitive
# work keeps a quality floor irrespective of stated Complexity. These patterns
# match a task's `Primary package` field against the boundary packages CLAUDE.md
# SS3.2 calls out - the frozen *API seams, PolicyKit, and the three .xpc service
# targets (Vault.xpc/DocEngine.xpc/Inference.xpc map to Services/VaultService,
# Services/DocEngineService, Services/InferenceService per docs/REPO_STRUCTURE.md;
# matched here by both the conceptual ".xpc" name and the real Services/* target
# name, since task files use either form).
SECURITY_FLOOR_PACKAGE_PATTERNS = [
    r"Packages/\w*API\b",
    r"PolicyKit",
    r"\.xpc\b",
    r"Services/VaultService\b",
    r"Services/DocEngineService\b",
    r"Services/InferenceService\b",
]

TASK_HEADER_FIELD_RE = r"\*\*{field}:\*\*\s*(.+?)\s*(?:·|$)"


def parse_task_header(text):
    """Extracts (complexity, primary_package) from a task file's header
    line. Either value is None if the field is missing or doesn't match the
    expected `**Field:** value ·` shape - callers must treat None as
    "couldn't determine" and fall back, never guess."""
    complexity = None
    complexity_match = re.search(
        TASK_HEADER_FIELD_RE.format(field="Complexity"), text
    )
    if complexity_match:
        candidate = complexity_match.group(1).strip()
        if candidate in COMPLEXITY_EFFORT:
            complexity = candidate

    primary_package = None
    package_match = re.search(
        TASK_HEADER_FIELD_RE.format(field="Primary package"), text
    )
    if package_match:
        primary_package = package_match.group(1).strip()

    return complexity, primary_package


def is_security_floor_package(primary_package):
    if not primary_package:
        return False
    return any(
        re.search(pattern, primary_package)
        for pattern in SECURITY_FLOOR_PACKAGE_PATTERNS
    )


def effort_for_task(complexity, primary_package):
    """Maps a task's Complexity (S/M/L) to a Claude --effort value, with a
    floor of `medium` for security/boundary-sensitive primary packages
    regardless of stated Complexity. Falls back to DEFAULT_EFFORT whenever
    complexity is None (missing/malformed field or no task selected) -
    never raises, never blocks the loop."""
    effort = COMPLEXITY_EFFORT.get(complexity, DEFAULT_EFFORT)
    if effort == "low" and is_security_floor_package(primary_package):
        effort = "medium"
    return effort


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
# PREFLIGHT (run once, before the loop starts)
# =========================================================
#
# Each check raises on failure - preflight is meant to fail loudly and stop
# before spawning a single Claude invocation, not to warn and continue.
# Handing an unattended, bypassPermissions loop a wrong-branch or dirty
# working tree is worse than refusing to start.

def check_required_commands():
    missing = [cmd for cmd in REQUIRED_COMMANDS if shutil.which(cmd) is None]
    if missing:
        raise Exception(
            f"Missing required command(s) on PATH: {', '.join(missing)}. "
            "Install them before starting the supervisor."
        )


def _run_git(*args):
    return subprocess.run(
        ["git", *args], cwd=PROJECT_DIR, capture_output=True, text=True
    )


def check_git_repo():
    result = _run_git("rev-parse", "--is-inside-work-tree")
    if result.returncode != 0 or result.stdout.strip() != "true":
        raise Exception(f"{PROJECT_DIR} is not a git repository.")


def check_git_branch():
    result = _run_git("rev-parse", "--abbrev-ref", "HEAD")
    if result.returncode != 0:
        raise Exception("Could not determine the current git branch.")
    branch = result.stdout.strip()
    if branch != REQUIRED_START_BRANCH:
        raise Exception(
            f"Expected to start from '{REQUIRED_START_BRANCH}', currently on "
            f"'{branch}'. `git checkout {REQUIRED_START_BRANCH}` first - every "
            "task branch the loop creates is based on whatever's checked out now."
        )


def check_git_clean():
    result = _run_git("status", "--porcelain")
    if result.returncode != 0:
        raise Exception(f"git status failed:\n{result.stderr}")
    dirty = [
        line for line in result.stdout.splitlines()
        if not line[3:].startswith(SUPERVISOR_OWN_PATH_PREFIX)
    ]
    if dirty:
        raise Exception(
            "Working tree has uncommitted changes outside "
            f"{SUPERVISOR_OWN_PATH_PREFIX} - commit, stash, or discard them "
            "before starting an unattended loop:\n" + "\n".join(dirty)
        )


def sync_with_remote_main():
    """Fetches and fast-forwards so the loop starts from the real current
    tip of origin/main, not whatever happened to be checked out when the
    terminal was opened. Fails loudly rather than silently working from a
    stale or diverged base."""
    log(f"🔄 Syncing with origin/{REQUIRED_START_BRANCH}...")
    fetch = _run_git("fetch", "origin", REQUIRED_START_BRANCH)
    if fetch.returncode != 0:
        raise Exception(f"git fetch origin {REQUIRED_START_BRANCH} failed:\n{fetch.stderr}")

    merge = _run_git("merge", "--ff-only", f"origin/{REQUIRED_START_BRANCH}")
    if merge.returncode != 0:
        raise Exception(
            f"Local {REQUIRED_START_BRANCH} could not fast-forward to "
            f"origin/{REQUIRED_START_BRANCH} (has it diverged with unpushed "
            f"commits?):\n{merge.stderr}"
        )
    log(f"✅ {REQUIRED_START_BRANCH} is up to date ({git_head()})")


def preflight():
    log("🔎 Running preflight checks...")
    check_required_commands()
    check_git_repo()
    check_git_branch()
    check_git_clean()
    sync_with_remote_main()
    log("✅ Preflight checks passed - starting the task loop.")


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


def wait_for_reset(state, prompt, effort, timeout):
    """Re-probe with a real request every TOKEN_POLL_INTERVAL_SECONDS instead of
    blindly sleeping for the full duration implied by the fixed reset-time table
    (that table is only a guess and the actual usage window can reopen sooner).
    Probes re-run the same call (prompt/effort/timeout) that hit the limit."""
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

        exit_code, output = run_claude(state, prompt, effort, timeout)

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


def run_claude(state, prompt, effort, timeout):
    log(f"🚀 Launching Claude (non-interactive print mode, effort={effort})...")

    try:
        proc = subprocess.run(
            [
                "claude",
                "-p", prompt,
                "--output-format", "json",
                "--permission-mode", "bypassPermissions",
                "--effort", effort,
            ],
            cwd=PROJECT_DIR,
            capture_output=True,
            text=True,
            timeout=timeout,
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
        log(f"❌ Claude run timed out after {timeout}s")
        timed_out_output = (e.stdout or "") + (e.stderr or "")
        return 1, timed_out_output

    except Exception as e:
        log(f"❌ Claude execution failure: {e}")
        return 1, str(e)


def run_with_token_handling(state, prompt, effort, timeout, log_suffix):
    """Runs one claude -p call and transparently waits out a token-limit hit
    via wait_for_reset. Returns (exit_code, output) once resolved, or None
    if the safety cap was hit without a clean probe - callers should treat
    None as "abandon this iteration attempt, let the outer loop restart
    fresh" (same semantics the single-call loop already had)."""
    exit_code, output = run_claude(state, prompt, effort, timeout)

    with open(os.path.join(LOG_DIR, f"run-{state['runs']}-{log_suffix}.log"), "w") as f:
        f.write(output or "")

    log(f"Claude exit code ({log_suffix}): {exit_code}")

    if not is_token_limit(output):
        return exit_code, output

    state["token_hits"] += 1
    save_state(state)

    result = wait_for_reset(state, prompt, effort, timeout)
    if result is None:
        return None

    exit_code, output = result
    log(f"Claude exit code ({log_suffix}, post-reset): {exit_code}")
    return exit_code, output


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


def resolve_effort_for_claim(inprogress_before):
    """Figures out which task the just-finished SELECT call claimed - the
    file that's new in tasks/in-progress/ since before the call - and maps
    its Complexity to an effort level. Falls back to DEFAULT_EFFORT (with a
    placeholder label) whenever the claim can't be uniquely identified or
    read; this must never raise or block the loop."""
    inprogress_after = set(list_tasks("in-progress"))
    newly_claimed = inprogress_after - inprogress_before

    if len(newly_claimed) != 1:
        log(
            f"⚠️ Could not uniquely identify the claimed task "
            f"({len(newly_claimed)} new file(s) in tasks/in-progress/) - "
            f"falling back to effort={DEFAULT_EFFORT}"
        )
        return DEFAULT_EFFORT, "unknown"

    task_file = next(iter(newly_claimed))
    task_path = os.path.join(TASKS_DIR, "in-progress", task_file)
    try:
        with open(task_path) as f:
            text = f.read()
    except OSError as e:
        log(
            f"⚠️ Could not read claimed task {task_file}: {e} - "
            f"falling back to effort={DEFAULT_EFFORT}"
        )
        return DEFAULT_EFFORT, task_file

    complexity, primary_package = parse_task_header(text)
    effort = effort_for_task(complexity, primary_package)
    log(
        f"📋 Claimed {task_file}: complexity={complexity or '?'} "
        f"primary_package={primary_package or '?'} -> effort={effort}"
    )
    return effort, task_file


# =========================================================
# MAIN LOOP
# =========================================================

def main():
    ensure_dirs()
    validate_project()

    log("===================================")
    log(" Vaultform Claude Supervisor ")
    log("===================================")

    preflight()

    state = load_state()
    state.setdefault("runs", 0)
    state.setdefault("token_hits", 0)
    state.setdefault("consecutive_no_op_runs", 0)
    state.setdefault("consecutive_failures", 0)

    while True:
        state["runs"] += 1
        save_state(state)

        head_before = git_head()
        inprogress_before = set(list_tasks("in-progress"))

        # -----------------------------
        # SELECT (claim a task, nothing else)
        # -----------------------------
        select_result = run_with_token_handling(
            state, SELECT_PROMPT, "low", SELECT_RUN_TIMEOUT_SECONDS, "select"
        )
        if select_result is None:
            continue
        select_exit, select_output = select_result

        head_after_select = git_head()
        selected_a_task = (
            select_exit == 0
            and bool(head_after_select)
            and head_after_select != head_before
        )

        if not selected_a_task:
            # No commit means no task was claimed - either a legitimately
            # empty/blocked backlog (SELECT_PROMPT's "exit immediately" path)
            # or a failed selection attempt. Same no-op/failure classification
            # as the old single-call loop; no work call to make.
            sleep_seconds = record_outcome(state, select_exit, head_before, head_after_select)
            if sleep_seconds is None:
                return
            time.sleep(sleep_seconds)
            continue

        # -----------------------------
        # Resolve effort from the claimed task's Complexity, then WORK
        # -----------------------------
        effort, task_label = resolve_effort_for_claim(inprogress_before)

        work_result = run_with_token_handling(
            state, WORK_PROMPT, effort, CLAUDE_RUN_TIMEOUT_SECONDS, "work"
        )
        if work_result is None:
            continue
        work_exit, work_output = work_result

        sleep_seconds = record_outcome(state, work_exit, head_before, git_head())
        if sleep_seconds is None:
            return
        time.sleep(sleep_seconds)


if __name__ == "__main__":
    main()