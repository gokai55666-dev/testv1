#!/bin/bash
# ============================================================
# GIRL BOT AI - MASTER INSTALL (Master-install.sh)
# ONE COMMAND to rule them all.
# Safe to re-run. Never touches /root for models.
# ============================================================

set -e
echo "========================================================"
echo "  GIRL BOT AI STUDIO - RTX 5090 MASTER INSTALL"
echo "========================================================"
cd /workspace

# ── Pre-flight checks ─────────────────────────────────────
echo ""
echo "[0/6] PRE-FLIGHT"
[ -w /workspace ] || { echo "❌ /workspace not writable!"; exit 1; }
nvidia-smi >/dev/null 2>&1 || { echo "❌ GPU not found!"; exit 1; }
echo "  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
echo "  Free: $(df -h /workspace | awk 'NR==2{print $4}') on /workspace"

# Kill stale processes
pkill -f "ollama serve|streamlit|python.*main.py" 2>/dev/null || true
sleep 2

# ── System packages ──────────────────────────────────────
echo ""
echo "[1/6] SYSTEM PACKAGES"
apt-get update -qq && apt-get install -y -qq git curl tmux wget lsof

# ── Python packages ──────────────────────────────────────
echo ""
echo "[2/6] PYTHON PACKAGES"
pip install -q --upgrade pip --break-system-packages

# PyTorch: cu128 for RTX 5090 Blackwell architecture
if ! python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    echo "  Installing PyTorch CUDA 12.8..."
    pip install -q torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu128 \
        --break-system-packages
else
    echo "  ✅ PyTorch already installed: $(python3 -c 'import torch; print(torch.__version__)')"
fi

pip install -q streamlit requests accelerate --break-system-packages

python3 -c "import torch; print('  CUDA:', torch.cuda.is_available(), '|', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

# ── Directories (all in /workspace) ──────────────────────
echo ""
echo "[3/6] DIRECTORIES"
mkdir -p /workspace/{logs,ollama,system,girlbot/workflows,girlbot/config,ComfyUI/models/checkpoints}
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434
grep -q "OLLAMA_MODELS" ~/.bashrc || echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
grep -q "OLLAMA_HOST"   ~/.bashrc || echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.bashrc
echo "  ✅ Directories created"

# ── Ollama ────────────────────────────────────────────────
echo ""
echo "[4/6] OLLAMA + MODEL"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi
echo "  Ollama: $(ollama --version)"

OLLAMA_MODELS=/workspace/ollama OLLAMA_HOST=0.0.0.0:11434 \
    nohup ollama serve > /workspace/logs/ollama.log 2>&1 &

echo "  Waiting for Ollama..."
for i in $(seq 1 25); do
    curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && break
    sleep 2
    [ $i -eq 25 ] && { echo "  ❌ Ollama failed! tail /workspace/logs/ollama.log"; exit 1; }
done
echo "  ✅ Ollama ready"

if ! OLLAMA_MODELS=/workspace/ollama ollama list 2>/dev/null | grep -q "dolphin-llama3"; then
    echo "  Pulling dolphin-llama3:8b..."
    OLLAMA_MODELS=/workspace/ollama ollama pull dolphin-llama3:8b
fi
echo "  ✅ Model ready"

# ── ComfyUI ───────────────────────────────────────────────
echo ""
echo "[5/6] COMFYUI"
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi
cd /workspace/ComfyUI
pip install -q -r requirements.txt --break-system-packages
nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram \
    > /workspace/logs/comfyui.log 2>&1 &
cd /workspace

echo "  Waiting for ComfyUI (up to 90s)..."
for i in $(seq 1 45); do
    curl -s http://localhost:8188/system_stats >/dev/null 2>&1 && break
    sleep 2
    [ $i -eq 45 ] && { echo "  ❌ ComfyUI failed! tail /workspace/logs/comfyui.log"; exit 1; }
done
echo "  ✅ ComfyUI ready"

# ── Frontend + Workflows ──────────────────────────────────
echo ""
echo "[6/6] FRONTEND + WORKFLOWS"

# System config
cat > /workspace/system/config.json <<'EOF'
{
  "hardware": {"gpu": "RTX 5090", "cuda": "12.8", "vram_optimization": "highvram", "vram_gb": 32},
  "storage": {
    "root": "/workspace",
    "ollama_models": "/workspace/ollama",
    "comfyui": "/workspace/ComfyUI",
    "workflows": "/workspace/girlbot/workflows",
    "output": "/workspace/ComfyUI/output",
    "logs": "/workspace/logs"
  },
  "services": {
    "ollama":   {"host": "0.0.0.0", "port": 11434, "url": "http://localhost:11434"},
    "comfyui":  {"host": "0.0.0.0", "port": 8188,  "url": "http://localhost:8188"},
    "frontend": {"host": "0.0.0.0", "port": 8501,  "url": "http://localhost:8501"}
  },
  "model": {"default": "dolphin-llama3:8b", "pulled": true}
}
EOF

# Workflow templates
cat > /workspace/girlbot/workflows/text2img_basic.json <<'EOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"text, watermark, blurry, low quality","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":512,"height":512,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":20,"cfg":8.0,"sampler_name":"euler","scheduler":"normal","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot","images":["6",0]},"class_type":"SaveImage"}}
EOF

cat > /workspace/girlbot/workflows/text2img_hq.json <<'EOF'
{"1":{"inputs":{"ckpt_name":"v1-5-pruned-emaonly.safetensors"},"class_type":"CheckpointLoaderSimple"},"2":{"inputs":{"text":"masterpiece, best quality, highly detailed, ","clip":["1",1]},"class_type":"CLIPTextEncode"},"3":{"inputs":{"text":"worst quality, lowres, blurry, watermark","clip":["1",1]},"class_type":"CLIPTextEncode"},"4":{"inputs":{"width":1024,"height":1024,"batch_size":1},"class_type":"EmptyLatentImage"},"5":{"inputs":{"seed":0,"steps":35,"cfg":7.0,"sampler_name":"dpmpp_2m","scheduler":"karras","denoise":1.0,"model":["1",0],"positive":["2",0],"negative":["3",0],"latent_image":["4",0]},"class_type":"KSampler"},"6":{"inputs":{"samples":["5",0],"vae":["1",2]},"class_type":"VAEDecode"},"7":{"inputs":{"filename_prefix":"GirlBot_HQ","images":["6",0]},"class_type":"SaveImage"}}
EOF

# Copy app.py from repo to girlbot
if [ -f "/workspace/testv1/RTX-5090/app.py" ]; then
    cp /workspace/testv1/RTX-5090/app.py /workspace/girlbot/app.py
    echo "  ✅ app.py copied from repo"
fi

# Launch Streamlit
nohup streamlit run /workspace/girlbot/app.py \
    --server.address 0.0.0.0 --server.port 8501 --server.headless true \
    > /workspace/logs/streamlit.log 2>&1 &

for i in $(seq 1 15); do
    curl -s http://localhost:8501 >/dev/null 2>&1 && break
    sleep 2
    [ $i -eq 15 ] && { echo "  ❌ Streamlit failed! tail /workspace/logs/streamlit.log"; exit 1; }
done
echo "  ✅ Frontend ready"

# Start watchdog
nohup bash /workspace/testv1/RTX-5090/monitor.sh > /workspace/logs/monitor.log 2>&1 &
echo "  ✅ Watchdog started"

# ── Final summary ─────────────────────────────────────────
echo ""
echo "========================================================"
echo "  INSTALL COMPLETE"
echo "========================================================"
echo ""
curl -s http://localhost:11434/api/tags   >/dev/null && echo "✅ Ollama   → :11434" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats>/dev/null && echo "✅ ComfyUI  → :8188"  || echo "❌ ComfyUI"
curl -s http://localhost:8501            >/dev/null && echo "✅ Frontend → :8501"  || echo "❌ Frontend"
echo ""
echo "⚠️  EXPOSE THESE IN RUNPOD HTTP SERVICES:"
echo "   11434  →  Ollama API"
echo "   8188   →  ComfyUI"
echo "   8501   →  Girl Bot AI Frontend"
echo ""
echo "Type 'draw: <anything>' in the chat to generate images."
echo "Logs: /workspace/logs/"
