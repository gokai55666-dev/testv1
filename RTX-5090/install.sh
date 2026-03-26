#!/bin/bash

set -e

echo "Creating folders..."
mkdir -p /workspace/{logs,ollama,ComfyUI}

echo "Setting Ollama path..."
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

echo "Installing system deps..."
apt update && apt install -y git python3-pip curl

echo "Installing Python deps..."
pip install --upgrade pip
pip install streamlit requests

echo "Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

echo "Pulling model..."
ollama serve &
sleep 5
ollama pull dolphin-llama3:8b
pkill ollama

echo "Installing ComfyUI..."
cd /workspace
git clone https://github.com/comfyanonymous/ComfyUI.git

cd ComfyUI
pip install -r requirements.txt

echo "INSTALL COMPLETE"