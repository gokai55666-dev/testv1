import subprocess

services = ["ollama", "streamlit", "python"]

for s in services:
    result = subprocess.run(["pgrep", "-f", s], capture_output=True)
    print(f"{s} running:", result.returncode == 0)