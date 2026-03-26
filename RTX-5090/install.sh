#!/bin/bash
# ============================================================
# GIRL BOT AI - INSTALL (install.sh)
# Lightweight install-only script (no service startup).
# For full install + launch use Master-install.sh instead.
# ============================================================
set -e

echo "=== GIRL BOT AI - INSTALL ==="
cd /workspace

# Dirs
mkdir -p /workspace/{logs,ollama,ComfyUI/models/checkpoints,girlbot/workflows,girlbot/config,system}

# Env vars
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434
grep -q "OLLAMA_MODELS" ~/.bashrc || echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
grep -q "OLLAMA_HOST"   ~/.bashrc || echo 'export OLLAMA_HOST=0.0.0.0:11434'   >> ~/.bashrc

# System packages
apt-get update -qq && apt-get install -y -qq git curl wget tmux lsof

# Python: torch cu128 for RTX 5090 Blackwell
pip install -q --upgrade pip --break-system-packages
pip install -q torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    --break-system-packages
pip install -q -r /workspace/testv1/RTX-5090/requirements.txt --break-system-packages

# Ollama
command -v ollama &>/dev/null || curl -fsSL https://ollama.com/install.sh | sh
echo "  Ollama: $(ollama --version)"

# ComfyUI
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi
cd /workspace/ComfyUI
pip install -q -r requirements.txt --break-system-packages
cd /workspace

echo ""
echo "✅ Install complete."
echo "Next: bash /workspace/testv1/RTX-5090/fix.sh   (download SD model)"
echo "Then: bash /workspace/testv1/RTX-5090/2-launch.sh  (start all services)"
