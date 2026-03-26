#!/bin/bash
set -e

echo "=== Master Install: Start ==="

# 1️⃣ Install Python packages
pip install --upgrade pip
pip install -r requirements.txt

# 2️⃣ Ensure folders
mkdir -p /workspace/{logs,ollama,ComfyUI,system}

# 3️⃣ Prevent re-clone of ComfyUI
if [ ! -d "/workspace/ComfyUI" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
  echo "ComfyUI already exists, skipping clone."
fi

# 4️⃣ Ollama persistence
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

# 5️⃣ Run install.sh (optional dependencies)
if [ -f "/workspace/install.sh" ]; then
  bash /workspace/install.sh
fi

echo "=== Master Install: Done ==="