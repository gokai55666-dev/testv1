#!/bin/bash
set -e
export OLLAMA_MODELS=/workspace/ollama

echo "=== Starting Services ==="

# Kill stuck services
pkill -f ollama || true
pkill -f streamlit || true
pkill -f main.py || true
sleep 2

# Start Ollama
echo "Starting Ollama..."
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

# Pull model if missing
if ! ollama list | grep -q dolphin-llama3; then
    ollama pull dolphin-llama3:8b
fi

# Start ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
cd /workspace
sleep 5

# Start Streamlit
echo "Starting Streamlit..."
streamlit run /workspace/girlbot/app.py --server.address 0.0.0.0 --server.port 8501 > /workspace/logs/streamlit.log 2>&1 &

echo "=== All Services Started ==="