#!/bin/bash

set -e

echo "===== MASTER INSTALL START ====="

# ---- FOLDERS ----
mkdir -p /workspace/{logs,ollama}

# ---- ENV ----
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

# ---- SYSTEM DEPS ----
apt update && apt install -y git python3-pip curl

# ---- PYTHON ----
pip install --upgrade pip

# ---- REQUIREMENTS FILE ----
cat << 'EOF' > /workspace/requirements.txt
streamlit
requests
EOF

pip install -r /workspace/requirements.txt

# ---- OLLAMA ----
if ! command -v ollama &> /dev/null; then
  curl -fsSL https://ollama.ai/install.sh | sh
fi

# TEMP start for model pull ONLY
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5
ollama pull dolphin-llama3:8b || true
pkill ollama || true

# ---- COMFYUI ----
cd /workspace
if [ ! -d "/workspace/ComfyUI" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git
fi

cd /workspace/ComfyUI
pip install -r requirements.txt

# ---- START SCRIPT ----
cat << 'EOF' > /workspace/start-services.sh
#!/bin/bash

export OLLAMA_MODELS=/workspace/ollama

echo "Starting services..."

pkill -f ollama || true
pkill -f streamlit || true
pkill -f main.py || true

sleep 2

# Ollama
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

# ComfyUI
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
sleep 5

# Streamlit
cd /workspace
streamlit run app.py --server.address 0.0.0.0 --server.port 8501 > /workspace/logs/streamlit.log 2>&1 &

echo "Services started"
EOF

chmod +x /workspace/start-services.sh

# ---- HEALTH CHECK ----
cat << 'EOF' > /workspace/health.sh
#!/bin/bash

echo "Checking services..."

curl -s http://localhost:11434 > /dev/null && echo "Ollama OK" || echo "Ollama FAIL"
curl -s http://localhost:8188 > /dev/null && echo "ComfyUI OK" || echo "ComfyUI FAIL"
curl -s http://localhost:8501 > /dev/null && echo "Streamlit OK" || echo "Streamlit FAIL"
EOF

chmod +x /workspace/health.sh

# ---- MONITOR (AUTO-RESTART) ----
cat << 'EOF' > /workspace/monitor.sh
#!/bin/bash

while true; do
  pgrep -f "ollama serve" > /dev/null || bash /workspace/start-services.sh
  sleep 15
done
EOF

chmod +x /workspace/monitor.sh

echo "===== INSTALL COMPLETE ====="
echo ""
echo "IMPORTANT:"
echo "Set RunPod Start Command to:"
echo "bash /workspace/start-services.sh"