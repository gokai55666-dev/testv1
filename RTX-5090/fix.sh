#!/bin/bash
cd /workspace

# 1. Download SD 1.5 model (REQUIRED - ComfyUI fails without this)
mkdir -p /workspace/ComfyUI/models/checkpoints
if [ ! -f "/workspace/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors" ]; then
    echo "Downloading SD 1.5 model..."
    wget -q --show-progress -O /workspace/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors \
    "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
fi

# 2. Fix the broken workflow JSON (quotes were missing)
cat > /workspace/girlbot/workflows/sd_basic.json << 'EOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"text, watermark, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":20,"cfg":8,"sampler_name":"euler","scheduler":"normal","denoise":1,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot","images":["6",0]},"class_type":"SaveImage"}}
EOF

# 3. Fix app.py (remove suicide button, fix paths, add error handling)
cat > /workspace/girlbot/app.py << 'APPEOF'
import streamlit as st
import requests
import json
import random
import os

st.set_page_config(page_title="Girl Bot AI", page_icon="🤖", layout="wide")

CFG = {
    "ollama": "http://localhost:11434",
    "comfy": "http://localhost:8188",
    "model": "dolphin-llama3:8b",
    "workflow_dir": "/workspace/girlbot/workflows"
}

if "messages" not in st.session_state:
    st.session_state.update({"messages": [], "personality": "Helpful"})

def check(url, port):
    try:
        requests.get(f"{url}:{port}", timeout=2)
        return True
    except:
        return False

def chat(prompt, personality):
    try:
        r = requests.post(f"{CFG['ollama']}/api/generate", json={
            "model": CFG['model'],
            "prompt": f"You are {personality}. User: {prompt}\nAI:",
            "stream": False
        }, timeout=60)
        return r.json().get("response", "Error")
    except Exception as e:
        return f"❌ {e}"

def draw(prompt):
    try:
        with open(f"{CFG['workflow_dir']}/sd_basic.json") as f:
            wf = json.load(f)
        wf["2"]["inputs"]["text"] = prompt
        wf["5"]["inputs"]["seed"] = random.randint(1, 999999)
        r = requests.post(f"{CFG['comfy']}/prompt", json={"prompt": wf}, timeout=30)
        return f"✅ Job ID: {r.json().get('prompt_id', 'N/A')}" if r.status_code == 200 else f"❌ {r.status_code}"
    except Exception as e:
        return f"❌ {e}"

# UI
with st.sidebar:
    st.title("⚙️ Status")
    o = check(CFG['ollama'], 11434)
    c = check(CFG['comfy'], 8188)
    st.write(f"Ollama: {'🟢' if o else '🔴'}")
    st.write(f"ComfyUI: {'🟢' if c else '🔴'}")
    st.session_state.personality = st.selectbox("Mode", ["Helpful", "Creative", "Coder"])

st.title("🤖 Girl Bot AI")
st.caption(f"RTX 5090 | {CFG['model']}")

for m in st.session_state.messages:
    with st.chat_message(m["role"]):
        st.markdown(m["content"])

if p := st.chat_input("Ask anything or type 'draw: ...'"):
    st.session_state.messages.append({"role": "user", "content": p})
    with st.chat_message("user"):
        st.markdown(p)
    with st.chat_message("assistant"):
        if p.lower().startswith(("draw:", "img:", "image:")):
            r = draw(p.split(":", 1)[1].strip())
        else:
            r = chat(p, st.session_state.personality)
        st.markdown(r)
    st.session_state.messages.append({"role": "assistant", "content": r})
APPEOF

echo "✅ Fixes applied. Now run: bash /workspace/2-launch.sh"
