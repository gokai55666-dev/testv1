"""
check_fix1.py - Deep process + port + model check for Girl Bot AI
Run with: python3 /workspace/testv1/RTX-5090/check_fix1.py
"""
import subprocess
import socket
import os
import json

def port_open(port: int) -> bool:
    s = socket.socket()
    try:
        s.settimeout(2)
        s.connect(("127.0.0.1", port))
        return True
    except Exception:
        return False
    finally:
        s.close()

def proc_running(pattern: str) -> bool:
    r = subprocess.run(["pgrep", "-f", pattern], capture_output=True)
    return r.returncode == 0

def check_ollama_model() -> str:
    try:
        import requests
        r = requests.get("http://localhost:11434/api/tags", timeout=2)
        models = r.json().get("models", [])
        names = [m["name"] for m in models]
        return f"Models: {', '.join(names)}" if names else "No models pulled"
    except Exception:
        return "Cannot query (Ollama down?)"

print("=== GIRL BOT AI DEEP CHECK ===")
print("")

# Services
services = [
    ("Ollama",     11434, "ollama serve"),
    ("ComfyUI",    8188,  "main.py"),
    ("Streamlit",  8501,  "streamlit"),
]

all_ok = True
for name, port, proc_pattern in services:
    proc   = proc_running(proc_pattern)
    port_s = port_open(port)
    ok     = proc and port_s
    if not ok:
        all_ok = False
    icon = "✅" if ok else ("⚠️ " if proc != port_s else "❌")
    print(f"{icon} {name:12} Process={'YES' if proc else 'NO ':3}  Port={port} {'OPEN' if port_s else 'CLOSED'}")

print("")

# Ollama model check
print(f"   Ollama: {check_ollama_model()}")

# SD model check
model_path = "/workspace/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors"
if os.path.exists(model_path):
    size = os.path.getsize(model_path) / (1024**3)
    print(f"   SD1.5 model: ✅ Present ({size:.1f}GB)")
else:
    print(f"   SD1.5 model: ❌ MISSING — run fix.sh to download it!")
    all_ok = False

# Workflow check
wf_dir = "/workspace/girlbot/workflows"
if os.path.exists(wf_dir):
    wfs = [f for f in os.listdir(wf_dir) if f.endswith(".json")]
    print(f"   Workflows: {', '.join(wfs) if wfs else '❌ NONE - run fix.sh!'}")
else:
    print("   Workflows: ❌ Directory missing - run fix.sh!")
    all_ok = False

print("")
if all_ok:
    print("✅ Everything looks good!")
else:
    print("⚠️  Issues found. Recommended fix:")
    print("   bash /workspace/testv1/RTX-5090/fix.sh")
    print("   bash /workspace/testv1/RTX-5090/start-services.sh")
