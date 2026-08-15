#!/usr/bin/env python3
import os
import sys

# Ensure the parent directory (project root) is on sys.path so 'backend' package is importable
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from backend.app.startup_tasks import run_startup_tasks


if __name__ == "__main__":
    result = run_startup_tasks()
    print("startup_tasks result:", result)
