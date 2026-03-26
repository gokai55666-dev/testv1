#!/bin/bash
set -e
cd /workspace
echo "=== GIRL BOT AI - RTX 5090 SETUP ==="

# Volume check
if df -h /workspace | grep -q "mfs"; then
    echo "❌ Volume not mounted! Stop pod & reattach volume."
    exit 1
fi
echo "✅ Volume OK"

# Kill old processes
pkill -9 -f "ollama|streamlit|main.py" 2>/dev/null || true
sleep 2

# Install deps
apt update -qq && apt install -y -qq git curl tmux
pip install -q --upgrade pip --break-system-packages
pip install -q streamlit requests torch --break-system-packages --extra-index-url https://download.pytorch.org/whl/cu128

# Install Ollama
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi

# Setup dirs
mkdir -p /workspace/{logs,ollama,ComfyUI,girlbot/workflows,system}

# Set env
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

# Install ComfyUI
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi
cd /workspace/ComfyUI && pip install -q -r requirements.txt --break-system-packages

echo "✅ Setup complete. Run part 2."
