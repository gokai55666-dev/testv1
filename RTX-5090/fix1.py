import requests

def check(url):
    try:
        r = requests.get(url, timeout=3)
        return r.status_code
    except:
        return None

print("Ollama:", check("http://localhost:11434"))
print("ComfyUI:", check("http://localhost:8188"))
print("Streamlit:", check("http://localhost:8501"))