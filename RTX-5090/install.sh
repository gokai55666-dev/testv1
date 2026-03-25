cat > /workspace/install.sh << 'EOF'
#!/bin/bash
set -e
cd /workspace

echo "=== GIRL BOT AI - COMPLETE INSTALL ==="

# 1. Create all directories on volume disk
mkdir -p {ollama,logs,system,girlbot/workflows,ComfyUI/models/checkpoints,cache/pip}

# 2. Set environment variables
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434
export PIP_CACHE_DIR=/workspace/cache/pip

cat >> ~/.bashrc << 'EOF'
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434
export PIP_CACHE_DIR=/workspace/cache/pip
EOF

# 3. Install Python packages
pip install streamlit requests --cache-dir /workspace/cache/pip --break-system-packages

# 4. Start Ollama (if not already running)
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    pkill ollama 2>/dev/null || true
    nohup ollama serve > /workspace/logs/ollama.log 2>&1 &
    sleep 5
fi

# 5. Pull model if missing
if ! ollama list | grep -q dolphin-llama3; then
    ollama pull dolphin-llama3:8b
fi

# 6. Start ComfyUI (if not already running)
if ! curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
    cd /workspace/ComfyUI
    nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
    cd /workspace
    sleep 10
fi

# 7. Create system config
cat > /workspace/system/config.json << 'CONFIGEOF'
{
  "hardware": {"gpu": "RTX 5090", "cuda": "12.1"},
  "services": {
    "ollama": {"url": "http://localhost:11434"},
    "comfyui": {"url": "http://localhost:8188"}
  },
  "storage": {"workflows": "/workspace/girlbot/workflows"},
  "model": {"default": "dolphin-llama3:8b"}
}
CONFIGEOF

# 8. Create workflow templates
cat > /workspace/girlbot/workflows/text2img_basic.json << 'WFEOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"text, watermark, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":20,"cfg":8.0,"sampler_name":"euler","scheduler":"normal","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot","images":["6",0]},"class_type":"SaveImage"}}
WFEOF

cat > /workspace/girlbot/workflows/text2img_hq.json << 'WFEOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"masterpiece, best quality, highly detailed","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"worst quality, lowres, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":1024,"height":1024,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":35,"cfg":7.0,"sampler_name":"dpmpp_2m","scheduler":"karras","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot_HQ","images":["6",0]},"class_type":"SaveImage"}}
WFEOF

# 9. Create the Streamlit app
cat > /workspace/girlbot/app.py << 'APPEOF'
import streamlit as st
import requests
import json
import random
import os

st.set_page_config(page_title="GIRL BOT AI", page_icon="🤖", layout="wide")

with open("/workspace/system/config.json") as f:
    CFG = json.load(f)

OLLAMA_URL = CFG["services"]["ollama"]["url"]
COMFY_URL = CFG["services"]["comfyui"]["url"]
WORKFLOW_DIR = CFG["storage"]["workflows"]

if "messages" not in st.session_state:
    st.session_state.messages = []
if "personality" not in st.session_state:
    st.session_state.personality = "Helpful Assistant"

def chat(prompt, personality):
    system = f"You are GIRL BOT AI. Personality: {personality}."
    try:
        r = requests.post(f"{OLLAMA_URL}/api/generate", json={
            "model": CFG["model"]["default"],
            "prompt": f"{system}\n\nUser: {prompt}\nAI:",
            "stream": False
        }, timeout=60)
        return r.json().get("response", "Error")
    except Exception as e:
        return f"Error: {e}"

def draw(prompt, quality):
    path = os.path.join(WORKFLOW_DIR, f"text2img_{quality}.json")
    try:
        with open(path) as f:
            wf = json.load(f)
        wf["2"]["inputs"]["text"] = prompt
        wf["5"]["inputs"]["seed"] = random.randint(1, 999999)
        r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": wf}, timeout=30)
        if r.status_code == 200:
            return f"✅ Started! ID: {r.json().get('prompt_id')}"
        return f"❌ Error: {r.status_code}"
    except Exception as e:
        return f"❌ Error: {e}"

with st.sidebar:
    st.title("⚙️")
    c1, c2 = st.columns(2)
    try:
        requests.get(f"{OLLAMA_URL}/api/tags", timeout=2)
        c1.success("Ollama")
    except:
        c1.error("Ollama")
    try:
        requests.get(f"{COMFY_URL}/system_stats", timeout=2)
        c2.success("ComfyUI")
    except:
        c2.error("ComfyUI")
    st.session_state.personality = st.selectbox("Personality", ["Helpful Assistant", "Creative Director", "Strict Coder"])
    mode = st.selectbox("Quality", ["basic", "hq"])

st.title("🤖 GIRL BOT AI")
st.caption(f"RTX 5090 | {CFG['model']['default']}")

for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

if prompt := st.chat_input("Ask or type 'draw: [description]'"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    with st.chat_message("assistant"):
        if prompt.lower().startswith(("draw:", "generate:", "image:")):
            p = prompt.split(":", 1)[1].strip()
            response = draw(p, mode)
        else:
            response = chat(prompt, st.session_state.personality)
        st.markdown(response)
    st.session_state.messages.append({"role": "assistant", "content": response})

st.link_button("Open ComfyUI", COMFY_URL)
APPEOF

# 10. Verify and start
echo "=== VERIFYING SERVICES ==="
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats > /dev/null && echo "✅ ComfyUI" || echo "❌ ComfyUI"

echo "=== STARTING STREAMLIT ==="
pkill -f streamlit 2>/dev/null || true
nohup streamlit run /workspace/girlbot/app.py --server.port 8501 --server.address 0.0.0.0 --server.headless true > /workspace/logs/streamlit.log 2>&1 &

sleep 5
curl -s http://localhost:8501 | head -3 && echo "✅ Streamlit running on port 8501" || echo "❌ Streamlit failed"

echo ""
echo "=== INSTALL COMPLETE ==="
echo "1. Go to RunPod HTTP Services"
echo "2. Click the link for port 8501"
echo "3. Your GIRL BOT AI is ready!"
EOF