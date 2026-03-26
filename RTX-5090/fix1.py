#!/bin/bash
echo "=== FIXING GIRL BOT AI SERVICES ==="

# Kill all old services
pkill -9 ollama 2>/dev/null
pkill -f main.py 2>/dev/null
pkill -f streamlit 2>/dev/null

# Make sure directories exist
mkdir -p /workspace/logs /workspace/ollama

# Start Ollama
export OLLAMA_MODELS=/workspace/ollama
ollama serve > /workspace/logs/ollama.log 2>&1 &
sleep 5

# Check Ollama
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama failed to start"
fi

# Start ComfyUI
cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
cd /workspace
sleep 10

# Check ComfyUI
if curl -s http://localhost:8188/system_stats > /dev/null; then
    echo "✅ ComfyUI is running"
else
    echo "❌ ComfyUI failed to start"
fi

# Start Streamlit
streamlit run /workspace/girlbot/app.py --server.port 8501 --server.address 0.0.0.0 --server.headless true > /workspace/logs/streamlit.log 2>&1 &
sleep 5

# Check Streamlit
if curl -s http://localhost:8501 > /dev/null; then
    echo "✅ Streamlit is running"
else
    echo "❌ Streamlit failed to start"
fi

echo ""
echo "=== FINAL STATUS ==="
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama (port 11434)" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats > /dev/null && echo "✅ ComfyUI (port 8188)" || echo "❌ ComfyUI"
curl -s http://localhost:8501 > /dev/null && echo "✅ Streamlit (port 8501)" || echo "❌ Streamlit"
echo ""
echo "If all three are ✅, go to RunPod Connect tab and click port 8501"