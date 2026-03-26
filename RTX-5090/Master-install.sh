#!/bin/bash

set -e

echo "===== MASTER INSTALL START ====="

mkdir -p /workspace/{logs,ollama}

echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

apt update && apt install -y git python3-pip curl

pip install --upgrade pip
pip install streamlit requests

# ---- OLLAMA ----
curl -fsSL https://ollama.ai/install.sh | sh

ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5
ollama pull dolphin-llama3:8b

# ---- COMFYUI ----
cd /workspace
git clone https://github.com/comfyanonymous/ComfyUI.git

cd ComfyUI
pip install -r requirements.txt

# ---- CREATE START SCRIPT ----
cat << 'EOF' > /workspace/start-services.sh
#!/bin/bash

export OLLAMA_MODELS=/workspace/ollama

pkill -f ollama
pkill -f streamlit
pkill -f main.py

sleep 2

ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
sleep 5

cd /workspace
streamlit run app.py --server.address 0.0.0.0 --server.port 8501 > /workspace/logs/streamlit.log 2>&1 &
EOF

chmod +x /workspace/start-services.sh

echo "===== INSTALL COMPLETE ====="
echo "SET RUNPOD START COMMAND:"
echo "bash /workspace/start-services.sh"