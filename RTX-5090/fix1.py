import requests

services = {
    "Ollama": "http://localhost:11434",
    "ComfyUI": "http://localhost:8188",
    "Streamlit": "http://localhost:8501"
}

for name, url in services.items():
    try:
        r = requests.get(url, timeout=3)
        print(f"{name}: OK ({r.status_code})")
    except Exception as e:
        print(f"{name}: FAIL ({e})")