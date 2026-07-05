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

TOKEN_RESET_TIMES = ["02:00", "06:00", "14:00", "18:00", "23:00"]

TOKEN_ERROR_PATTERNS = [
    "token limit",
    "usage limit",
    "rate limit",
    "quota exceeded",
    "try again later",
    "too many requests",
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


def wait_for_reset():
    seconds = next_reset_seconds()
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)

    log(f"⛔ Token limit hit. Sleeping {hours}h {minutes}m")
    time.sleep(seconds)
    log("✅ Token window resumed")


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

    while True:
        state["runs"] += 1
        save_state(state)

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
            wait_for_reset()
            continue

        # -----------------------------
        # SUCCESS PATH
        # -----------------------------
        if exit_code == 0:
            log("✅ Task completed (single-task contract fulfilled)")
            time.sleep(SUCCESS_DELAY_SECONDS)
            continue

        # -----------------------------
        # FAILURE PATH
        # -----------------------------
        log("⚠️ Failure detected, retrying...")
        time.sleep(RETRY_DELAY_SECONDS)


if __name__ == "__main__":
    main()