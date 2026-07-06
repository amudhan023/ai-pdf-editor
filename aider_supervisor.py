#!/usr/bin/env python3

import os
import subprocess
import time
import json
from datetime import datetime

# =========================================================
# PROJECT ROOT & ISOLATED STATE
# =========================================================
PROJECT_DIR = os.getcwd()

SUPERVISOR_DIR = os.path.join(PROJECT_DIR, ".aider-supervisor")
LOG_DIR = os.path.join(SUPERVISOR_DIR, "logs")
STATE_FILE = os.path.join(SUPERVISOR_DIR, "state.json")

TASKS_DIR = os.path.join(PROJECT_DIR, "tasks")

# Explicit network environment configuration for Aider -> Ubuntu routing
env_context = os.environ.copy()
env_context["PYTHONWARNINGS"] = "ignore"
env_context["OLLAMA_API_BASE"] = "http://192.168.4.25:11434"

# =========================================================
# BOOTSTRAP PROMPT (Vaultform-native, routed via aider.md)
# =========================================================
BOOTSTRAP_PROMPT = """
Read aider.md.

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
AIDER_RUN_TIMEOUT_SECONDS = 900

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

def validate_project():
    required = ["aider.md", "tasks"]
    for f in required:
        if not os.path.exists(os.path.join(PROJECT_DIR, f)):
            raise Exception(f"Missing required path: {f}")

# =========================================================
# AIDER MICRO-LOOP EXECUTION
# =========================================================
def run_aider(state):
    log("🚀 Launching Aider (headless autonomous agent mode)...")
    try:
        # Fixed: Added `env=env_context` so the script uses your network configurations
        proc = subprocess.run(
            [
                "aider",
                "--no-show-model-warnings",
                "--message", BOOTSTRAP_PROMPT,
                "tasks",
            ],
            cwd=PROJECT_DIR,
            env=env_context,
            capture_output=True,
            text=True,
            timeout=AIDER_RUN_TIMEOUT_SECONDS,
        )

        output = proc.stdout + proc.stderr
        is_error = proc.returncode != 0
        
        return (1 if is_error else 0), output

    except subprocess.TimeoutExpired as e:
        log(f"❌ Aider execution timed out after {AIDER_RUN_TIMEOUT_SECONDS}s")
        timed_out_output = (e.stdout or "") + (e.stderr or "")
        return 1, timed_out_output
    except Exception as e:
        log(f"❌ Aider execution failure: {e}")
        return 1, str(e)

# =========================================================
# MAIN LOOP
# =========================================================
def main():
    ensure_dirs()
    validate_project()

    log("===================================")
    log(" Vaultform Aider Supervisor Engine ")
    log("===================================")

    state = load_state()
    state.setdefault("runs", 0)

    while True:
        state["runs"] += 1
        save_state(state)

        exit_code, output = run_aider(state)

        with open(os.path.join(LOG_DIR, f"run-{state['runs']}.log"), "w") as f:
            f.write(output or "")

        log(f"Aider process exit code: {exit_code}")

        if exit_code == 0:
            log("✅ Task completed (single-task contract fulfilled)")
            time.sleep(SUCCESS_DELAY_SECONDS)
            continue

        log("⚠️ Failure detected, cycling loop for self-healing pass...")
        time.sleep(RETRY_DELAY_SECONDS)

if __name__ == "__main__":
    main()