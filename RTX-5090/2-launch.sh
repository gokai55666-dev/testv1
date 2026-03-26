#!/bin/bash
cd /workspace
export OLLAMA_MODELS=/workspace/ollama

# Create workflow templates
cat > /workspace/girlbot/workflows/sd_basic.json << 'WFEOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"masterpiece, best quality","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"worst quality, blurry","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":20,"cfg":8,"sampler_name":"euler","scheduler":"normal","denoise":1,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot","images":["6",0]},"class_type":"SaveImage"}}
WFEOF

# Create optimized Streamlit app
cat > /workspace/girlbot/app.py << 'APPEOF'
import streamlit as st, requests, json, random, os, sys
sys.path.insert(0, '/workspace/ComfyUI')

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
    if st.button("🔄 Restart Services"):
        os.system("bash /workspace/2-launch.sh &")
        st.rerun()

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

# Start services with tmux
SESSION="girlbot"
tmux kill-session -t $SESSION 2>/dev/null || true

# Window 0: Ollama
tmux new-session -d -s $SESSION
tmux send-keys -t $SESSION "ollama serve > /workspace/logs/ollama.log 2>&1" C-m
sleep 6
ollama pull dolphin-llama3:8b 2>/dev/null || true

# Window 1: ComfyUI
tmux new-window -t $SESSION
tmux send-keys -t $SESSION:1 "cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188 --highvram --cuda-device 0 > /workspace/logs/comfyui.log 2>&1" C-m
sleep 8

# Window 2: Streamlit
tmux new-window -t $SESSION
tmux send-keys -t $SESSION:2 "streamlit run /workspace/girlbot/app.py --server.address 0.0.0.0 --server.port 8501 --server.headless true --server.enableCORS true > /workspace/logs/streamlit.log 2>&1" C-m
sleep 5

# Verify
echo "=== STATUS ==="
curl -s http://localhost:11434/api/tags >/dev/null && echo "✅ Ollama:11434" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats >/dev/null && echo "✅ ComfyUI:8188" || echo "❌ ComfyUI"
curl -s http://localhost:8501 >/dev/null && echo "✅ Streamlit:8501" || echo "❌ Streamlit"
echo ""
echo "Access: RunPod HTTP Service on port 8501"
echo "Logs: tail -f /workspace/logs/*.log"
echo "Attach: tmux attach -t girlbot (Ctrl+B then D to detach)"
