#!/bin/bash
cd /workspace
export OLLAMA_MODELS=/workspace/ollama

# Kill old
pkill -9 -f "ollama|streamlit|main.py" 2>/dev/null || true
sleep 2

# Start Ollama
echo "Starting Ollama..."
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5
ollama pull dolphin-llama3:8b 2>/dev/null || true

# Start ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
cd /workspace
sleep 10

# Start Streamlit
echo "Starting Streamlit..."
streamlit run /workspace/girlbot/app.py --server.address 0.0.0.0 --server.port 8501 --server.headless true > /workspace/logs/streamlit.log 2>&1 &

sleep 5
echo "=== STATUS ==="
curl -s http://localhost:11434/api/tags >/dev/null && echo "✅ Ollama:11434" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats >/dev/null && echo "✅ ComfyUI:8188" || echo "❌ ComfyUI"
curl -s http://localhost:8501 >/dev/null && echo "✅ Streamlit:8501" || echo "❌ Streamlit"
