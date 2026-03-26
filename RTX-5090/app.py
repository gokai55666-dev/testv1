import streamlit as st
import requests
import os

# ---- FORCE BIND ----
os.environ["STREAMLIT_SERVER_ADDRESS"] = "0.0.0.0"

# ---- CONFIG ----
OLLAMA_URL = "http://localhost:11434/api/generate"
COMFYUI_URL = "http://localhost:8188/prompt"
MODEL = "dolphin-llama3:8b"

st.set_page_config(page_title="AI Studio", layout="wide")

# ---- SESSION STATE ----
if "messages" not in st.session_state:
    st.session_state.messages = []

# ---- SERVICE CHECK ----
def check(url):
    try:
        requests.get(url, timeout=2)
        return True
    except:
        return False

ollama_ok = check("http://localhost:11434")
comfy_ok = check("http://localhost:8188")

# ---- SIDEBAR ----
st.sidebar.title("System Status")
st.sidebar.write(f"Ollama: {'✅' if ollama_ok else '❌'}")
st.sidebar.write(f"ComfyUI: {'✅' if comfy_ok else '❌'}")

# ---- CHAT ----
st.title("AI Studio")

user_input = st.chat_input("Message...")

if user_input:
    st.session_state.messages.append({"role": "user", "content": user_input})

    if not ollama_ok:
        reply = "❌ Ollama not running"
    else:
        try:
            res = requests.post(
                OLLAMA_URL,
                json={"model": MODEL, "prompt": user_input, "stream": False},
                timeout=60
            )

            if res.status_code == 200:
                reply = res.json().get("response", "No response")
            else:
                reply = f"Error {res.status_code}"

        except Exception as e:
            reply = str(e)

    st.session_state.messages.append({"role": "assistant", "content": reply})

for m in st.session_state.messages:
    with st.chat_message(m["role"]):
        st.write(m["content"])

# ---- IMAGE ----
st.divider()
prompt = st.text_input("Image prompt")

if st.button("Generate"):
    if not comfy_ok:
        st.error("ComfyUI not running")
    else:
        try:
            r = requests.post(COMFYUI_URL, json={"prompt": prompt}, timeout=60)
            st.success("Request sent" if r.status_code == 200 else "Error")
        except Exception as e:
            st.error(str(e))