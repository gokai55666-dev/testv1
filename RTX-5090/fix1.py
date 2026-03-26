#!/bin/bash
set -e

echo "=== GIRL BOT AI - CLEAN START ==="

# Kill all old services (no zombies)
pkill -9 ollama 2>/dev/null || true
pkill -f "python3 main.py" 2>/dev/null || true
pkill -f streamlit 2>/dev/null || true

# Wait for processes to fully die
sleep 2

# Ensure directories exist
mkdir -p /workspace/logs /workspace/ollama

# ============================================
# 1. START OLLAMA
# ============================================
echo ""
echo "[1/3] Starting Ollama..."
export OLLAMA_MODELS=/workspace/ollama
nohup ollama serve > /workspace/logs/ollama.log 2>&1 &
OLLAMA_PID=$!
sleep 5

if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅ Ollama is running (PID: $OLLAMA_PID)"
else
    echo "❌ Ollama failed to start"
    tail -5 /workspace/logs/ollama.log
fi

# ============================================
# 2. START COMFYUI
# ============================================
echo ""
echo "[2/3] Starting ComfyUI..."
cd /workspace/ComfyUI
nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &
COMFY_PID=$!
cd /workspace
sleep 10

if curl -s http://localhost:8188/system_stats > /dev/null 2>&1; then
    echo "✅ ComfyUI is running (PID: $COMFY_PID)"
else
    echo "❌ ComfyUI failed to start"
    tail -5 /workspace/logs/comfyui.log
fi

# ============================================
# 3. START STREAMLIT
# ============================================
echo ""
echo "[3/3] Starting Streamlit..."
nohup streamlit run /workspace/girlbot/app.py \
    --server.port 8501 \
    --server.address 0.0.0.0 \
    --server.headless true \
    > /workspace/logs/streamlit.log 2>&1 &
STREAMLIT_PID=$!
sleep 5

if curl -s http://localhost:8501 > /dev/null 2>&1; then
    echo "✅ Streamlit is running (PID: $STREAMLIT_PID)"
else
    echo "❌ Streamlit failed to start"
    tail -5 /workspace/logs/streamlit.log
fi

# ============================================
# FINAL STATUS
# ============================================
echo ""
echo "=== FINAL STATUS ==="
curl -s http://localhost:11434/api/tags > /dev/null 2>&1 && echo "✅ Ollama (port 11434)" || echo "❌ Ollama"
curl -s http://localhost:8188/system_stats > /dev/null 2>&1 && echo "✅ ComfyUI (port 8188)" || echo "❌ ComfyUI"
curl -s http://localhost:8501 > /dev/null 2>&1 && echo "✅ Streamlit (port 8501)" || echo "❌ Streamlit"

echo ""
echo "=== PIDS (for monitoring) ==="
echo "Ollama: $OLLAMA_PID"
echo "ComfyUI: $COMFY_PID"
echo "Streamlit: $STREAMLIT_PID"

echo ""
echo "✅ If all three are ✅, go to RunPod Connect tab and click port 8501"