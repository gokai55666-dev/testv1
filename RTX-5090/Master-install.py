#!/bin/bash
set -e
echo "=========================================="
echo "  GIRL BOT AI - RTX 5090 MASTER SETUP"
echo "=========================================="

# -----------------------------
# 0. Ensure we're on persistent volume
# -----------------------------
cd /workspace
echo "✅ Working from: $(pwd)"

# -----------------------------
# 1. Install tmux for persistence
# -----------------------------
if ! command -v tmux &> /dev/null; then
    echo "📦 Installing tmux..."
    apt update && apt install -y tmux
fi

# -----------------------------
# 2. Kill all old processes
# -----------------------------
echo "🧹 Cleaning old processes..."
pkill -9 ollama 2>/dev/null || true
pkill -f "python3 main.py" 2>/dev/null || true
pkill -f streamlit 2>/dev/null || true
sleep 2

# -----------------------------
# 3. Create ALL directories on /workspace
# -----------------------------
echo "📁 Creating directories..."
mkdir -p {ollama,logs,system,girlbot/workflows,ComfyUI/models/checkpoints,cache/pip}

# -----------------------------
# 4. Install PyTorch with CUDA 12.1 (RTX 5090)
# -----------------------------
echo "🔥 Installing PyTorch CUDA 12.1..."
if ! python3 -c "import torch; print(torch.cuda.is_available())" 2>/dev/null | grep -q "True"; then
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 --break-system-packages
fi

# -----------------------------
# 5. Install Ollama (persistent with env var)
# -----------------------------
echo "🦙 Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

# -----------------------------
# 6. Start Ollama and pull model
# -----------------------------
echo "🚀 Starting Ollama..."
nohup ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama running"
else
    echo "❌ Ollama failed"
    tail -5 /workspace/logs/ollama.log
    exit 1
fi

if ! ollama list 2>/dev/null | grep -q dolphin-llama3; then
    echo "📥 Pulling dolphin-llama3:8b..."
    ollama pull dolphin-llama3:8b
fi

# -----------------------------
# 7. Install ComfyUI
# -----------------------------
echo "🎨 Setting up ComfyUI..."
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi

cd /workspace/ComfyUI
pip install -r requirements.txt --break-system-packages
pip install accelerate --break-system-packages

# Download SD 1.5 model if missing
if [ ! -f "models/checkpoints/v1-5-pruned-emaonly.safetensors" ]; then
    echo "📥 Downloading SD 1.5 model (4GB)..."
    wget -O models/checkpoints/v1-5-pruned-emaonly.safetensors \
        "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
fi

cd /workspace

# -----------------------------
# 8. Start ComfyUI
# -----------------------------
echo "🚀 Starting ComfyUI..."
cd /workspace/ComfyUI
nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
cd /workspace
sleep 10

if curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
    echo "✅ ComfyUI running"
else
    echo "❌ ComfyUI failed"
    tail -5 /workspace/logs/comfyui.log
fi

# -----------------------------
# 9. Install Streamlit
# -----------------------------
echo "📊 Installing Streamlit..."
pip install streamlit requests --break-system-packages

# -----------------------------
# 10. Create system config
# -----------------------------
cat > /workspace/system/config.json << 'CONFIGEOF'
{
  "hardware": {"gpu": "RTX 5090", "cuda": "12.1", "vram_optimization": "highvram"},
  "storage": {
    "ollama_models": "/workspace/ollama",
    "comfyui": "/workspace/ComfyUI",
    "workflows": "/workspace/girlbot/workflows",
    "logs": "/workspace/logs",
    "output": "/workspace/ComfyUI/output"
  },
  "services": {
    "ollama": {"port": 11434, "url": "http://localhost:11434"},
    "comfyui": {"port": 8188, "url": "http://localhost:8188"},
    "frontend": {"port": 8501, "url": "http://localhost:8501"}
  },
  "model": {"default": "dolphin-llama3:8b"}
}
CONFIGEOF

# -----------------------------
# 11. Create workflow templates
# -----------------------------
cat > /workspace/girlbot/workflows/text2img_basic.json << 'WFEOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"text, watermark, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":20,"cfg":8.0,"sampler_name":"euler","scheduler":"normal","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot","images":["6",0]},"class_type":"SaveImage"}}
WFEOF

cat > /workspace/girlbot/workflows/text2img_hq.json << 'WFEOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"masterpiece, best quality, highly detailed","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"worst quality, lowres, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":1024,"height":1024,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":35,"cfg":7.0,"sampler_name":"dpmpp_2m","scheduler":"karras","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot_HQ","images":["6",0]},"class_type":"SaveImage"}}
WFEOF

# -----------------------------
# 12. Create the Streamlit app
# -----------------------------
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

# -----------------------------
# 13. Start tmux session with all services
# -----------------------------
echo "🖥️ Starting tmux session..."
SESSION="girlbot"
tmux kill-session -t $SESSION 2>/dev/null || true
tmux new-session -d -s $SESSION -n "ollama"
tmux send-keys -t $SESSION:0 " export OLLAMA_HOST=0.0.0.0 OLLAMA_MODELS=/workspace/ollama && ollama serve > /workspace/logs/ollama.log 2>&1" C-m

tmux new-window -t $SESSION -n "comfyui"
tmux send-keys -t $SESSION:1 " cd /workspace/ComfyUI && python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1" C-m
sleep 5

tmux new-window -t $SESSION -n "streamlit"
tmux send-keys -t $SESSION:2 " streamlit run /workspace/girlbot/app.py --server.port 8501 --server.address 0.0.0.0 --server.headless true --server.enableCORS true --server.enableXsrfProtection false > /workspace/logs/streamlit.log 2>&1" C-m

# -----------------------------
# 14. Final verification
# -----------------------------
echo ""
echo "=========================================="
echo "  VERIFICATION"
echo "=========================================="
sleep 10

curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama (port 11434)" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats > /dev/null && echo "✅ ComfyUI (port 8188)" || echo "❌ ComfyUI"
curl -s http://localhost:8501 > /dev/null && echo "✅ Streamlit (port 8501)" || echo "❌ Streamlit"

echo ""
echo "=========================================="
echo "  ACCESS YOUR GIRL BOT AI"
echo "=========================================="
echo ""
echo "🌐 Streamlit UI: https://e0g0d2n1s5cnri-8501.proxy.runpod.net"
echo "🎨 ComfyUI:      https://e0g0d2n1s5cnri-8188.proxy.runpod.net"
echo ""
echo "📋 Commands:"
echo "   Attach to tmux:  tmux attach -t girlbot"
echo "   Check logs:      tail -f /workspace/logs/streamlit.log"
echo "   Verify services: curl -s http://localhost:8501 | head -5"
echo ""
echo "=========================================="
echo "  SETUP COMPLETE!"
echo "=========================================="