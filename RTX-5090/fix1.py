"""
fix1.py - Quick HTTP service check for Girl Bot AI
Run with: python3 /workspace/testv1/RTX-5090/fix1.py
"""
import requests
import subprocess

# GPU check
try:
    result = subprocess.run(
        ["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu",
         "--format=csv,noheader"],
        capture_output=True, text=True, timeout=5
    )
    if result.returncode == 0:
        print(f"GPU: {result.stdout.strip()}")
    else:
        print("GPU: nvidia-smi failed")
except Exception as e:
    print(f"GPU: {e}")

print("")

# Service HTTP checks
services = {
    "Ollama   :11434": "http://localhost:11434/api/tags",
    "ComfyUI  :8188 ": "http://localhost:8188/system_stats",
    "Streamlit:8501 ": "http://localhost:8501",
}

all_ok = True
for name, url in services.items():
    try:
        r = requests.get(url, timeout=3)
        status = "✅ OK" if r.status_code < 500 else f"⚠️  HTTP {r.status_code}"
    except requests.exceptions.ConnectionError:
        status = "❌ UNREACHABLE"
        all_ok = False
    except Exception as e:
        status = f"❌ {e}"
        all_ok = False
    print(f"{name}: {status}")

print("")
if all_ok:
    print("All services are up!")
else:
    print("Some services are down. Run: bash /workspace/testv1/RTX-5090/start-services.sh")
