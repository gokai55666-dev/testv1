"""
run-app.py - Streamlit launcher for Girl Bot AI
Ensures correct path and headless mode for RunPod proxy.
"""
import os
import subprocess
import sys

APP_PATH = "/workspace/girlbot/app.py"

if not os.path.exists(APP_PATH):
    print(f"ERROR: app.py not found at {APP_PATH}")
    print("Copy it with: cp /workspace/testv1/RTX-5090/app.py /workspace/girlbot/app.py")
    sys.exit(1)

print(f"Starting Streamlit: {APP_PATH}")
subprocess.run([
    "streamlit", "run", APP_PATH,
    "--server.address",  "0.0.0.0",
    "--server.port",     "8501",
    "--server.headless", "true",   # REQUIRED for RunPod proxy
])
