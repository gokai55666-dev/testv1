#!/bin/bash
# ============================================================
# GIRL BOT AI - RTX 5090 SETUP (1-setup.sh)
# Run ONCE on fresh pod. Then run 2-launch.sh to start services.
# ============================================================
set -e

echo "=== GIRL BOT AI - RTX 5090 SETUP ==="
cd /workspace

# --- Volume check (correct method) ---
if ! mountpoint -q /workspace 2>/dev/null && [ ! -w /workspace ]; then
    echo "❌ /workspace not writable! Stop pod & reattach your volume."
    exit 1
fi
echo "✅ Volume OK ($(df -h /workspace | awk 'NR==2{print $4}') free)"

# --- Kill any stale processes ---
pkill -9 -f "ollama serve|streamlit|main.py" 2>/dev/null || true
sleep 2

# --- System deps ---
apt-get update -qq && apt-get install -y -qq git curl tmux wget lsof

# --- Python deps (split installs to avoid conflicts) ---
pip install -q --upgrade pip --break-system-packages

# PyTorch cu128 for RTX 5090 (Blackwell architecture requires CUDA 12.8+)
pip install -q torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    --break-system-packages

# App dependencies separately
pip install -q streamlit requests accelerate \
    --break-system-packages

# Verify GPU is visible
echo "--- GPU Check ---"
python3 -c "import torch; print('CUDA:', torch.cuda.is_available(), '| Device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"

# --- Ollama install ---
if ! command -v ollama &>/dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "✅ Ollama already installed: $(ollama --version)"
fi

# --- Directory structure (all in /workspace - NEVER /root) ---
mkdir -p /workspace/{logs,ollama,girlbot/workflows,girlbot/config,system,ComfyUI/models/checkpoints}

# --- Persist env vars across restarts ---
grep -q "OLLAMA_MODELS" ~/.bashrc || echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
grep -q "OLLAMA_HOST" ~/.bashrc || echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

# --- ComfyUI install ---
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    echo "Cloning ComfyUI..."
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
    echo "✅ ComfyUI already cloned"
fi

cd /workspace/ComfyUI
pip install -q -r requirements.txt --break-system-packages
cd /workspace

# --- Write system config (machine-readable for Emergent AI) ---
cat > /workspace/system/config.json <<'EOF'
{
  "hardware": {
    "gpu": "RTX 5090",
    "cuda": "12.8",
    "vram_optimization": "highvram",
    "vram_gb": 32
  },
  "storage": {
    "root": "/workspace",
    "ollama_models": "/workspace/ollama",
    "comfyui": "/workspace/ComfyUI",
    "workflows": "/workspace/girlbot/workflows",
    "output": "/workspace/ComfyUI/output",
    "logs": "/workspace/logs"
  },
  "services": {
    "ollama": {"host": "0.0.0.0", "port": 11434, "url": "http://localhost:11434"},
    "comfyui": {"host": "0.0.0.0", "port": 8188, "url": "http://localhost:8188"},
    "frontend": {"host": "0.0.0.0", "port": 8501, "url": "http://localhost:8501"}
  },
  "model": {
    "default": "dolphin-llama3:8b",
    "pulled": false
  },
  "notes": "OLLAMA uses env var OLLAMA_MODELS. NO SYMLINKS. ComfyUI uses --highvram."
}
EOF

# --- Workflow templates ---
cat > /workspace/girlbot/workflows/text2img_basic.json <<'EOF'
{
  "1": {"inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"}, "class_type": "CheckpointLoaderSimple"},
  "2": {"inputs": {"text": "", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "3": {"inputs": {"text": "text, watermark, blurry, low quality", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "4": {"inputs": {"width": 512, "height": 512, "batch_size": 1}, "class_type": "EmptyLatentImage"},
  "5": {"inputs": {"seed": 0, "steps": 20, "cfg": 8.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}, "class_type": "KSampler"},
  "6": {"inputs": {"samples": ["5", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
  "7": {"inputs": {"filename_prefix": "GirlBot", "images": ["6", 0]}, "class_type": "SaveImage"}
}
EOF

cat > /workspace/girlbot/workflows/text2img_hq.json <<'EOF'
{
  "1": {"inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"}, "class_type": "CheckpointLoaderSimple"},
  "2": {"inputs": {"text": "masterpiece, best quality, highly detailed, ", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "3": {"inputs": {"text": "worst quality, lowres, blurry, watermark", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "4": {"inputs": {"width": 1024, "height": 1024, "batch_size": 1}, "class_type": "EmptyLatentImage"},
  "5": {"inputs": {"seed": 0, "steps": 35, "cfg": 7.0, "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}, "class_type": "KSampler"},
  "6": {"inputs": {"samples": ["5", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
  "7": {"inputs": {"filename_prefix": "GirlBot_HQ", "images": ["6", 0]}, "class_type": "SaveImage"}
}
EOF

# --- Copy app.py if it exists in repo ---
if [ -f "/workspace/testv1/RTX-5090/app.py" ]; then
    cp /workspace/testv1/RTX-5090/app.py /workspace/girlbot/app.py
    echo "✅ app.py copied from testv1"
fi

echo ""
echo "=== SETUP COMPLETE ==="
echo "Next step: run bash /workspace/testv1/RTX-5090/2-launch.sh"
echo ""
echo "Expose these ports in RunPod HTTP Services:"
echo "  11434 → Ollama API"
echo "  8188  → ComfyUI"
echo "  8501  → Girl Bot AI Frontend"
