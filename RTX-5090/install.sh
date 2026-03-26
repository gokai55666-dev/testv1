cat > /workspace/testv1/RTX-5090/install.sh << 'EOF'
#!/bin/bash
set -e

echo "Creating folders..."
mkdir -p /workspace/{logs,ollama,ComfyUI,girlbot}

echo "Setting Ollama path..."
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

echo "Installing system deps..."
apt update && apt install -y git python3-pip curl

echo "Installing Python deps..."
pip install --upgrade pip
pip install streamlit requests

echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

echo "Starting Ollama..."
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

echo "Pulling model..."
ollama pull dolphin-llama3:8b

echo "Installing ComfyUI..."
cd /workspace
if [ ! -d "ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi
cd ComfyUI
pip install -r requirements.txt

echo "INSTALL COMPLETE"
EOF