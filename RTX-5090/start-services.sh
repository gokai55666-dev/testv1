#!/bin/bash
# ============================================================
# GIRL BOT AI - QUICK RESTART (start-services.sh)
# Use this for fast restarts when setup is already done.
# For fresh install: run 1-setup.sh first.
# ============================================================

echo "=== QUICK START: GIRL BOT AI SERVICES ==="
cd /workspace

export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

# Kill stale services (no set -e so this never aborts)
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "streamlit" 2>/dev/null || true
pkill -f "python.*main.py" 2>/dev/null || true
sleep 2

# Ollama
echo "Starting Ollama..."
OLLAMA_MODELS=/workspace/ollama OLLAMA_HOST=0.0.0.0:11434 \
    nohup ollama serve > /workspace/logs/ollama.log 2>&1 &
for i in $(seq 1 20); do
    curl -s http://localhost:11434/api/tags >/dev/null 2>&1 && break
    sleep 2
done
curl -s http://localhost:11434/api/tags >/dev/null 2>&1 \
    && echo "✅ Ollama up" \
    || { echo "❌ Ollama failed! tail /workspace/logs/ollama.log"; exit 1; }

# Pull model if missing (fast check)
OLLAMA_MODELS=/workspace/ollama ollama list 2>/dev/null | grep -q "dolphin-llama3" \
    || (echo "Pulling model..." && OLLAMA_MODELS=/workspace/ollama ollama pull dolphin-llama3:8b)

# ComfyUI
echo "Starting ComfyUI..."
cd /workspace/ComfyUI
nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram \
    > /workspace/logs/comfyui.log 2>&1 &
cd /workspace
for i in $(seq 1 40); do
    curl -s http://localhost:8188/system_stats >/dev/null 2>&1 && break
    sleep 2
done
curl -s http://localhost:8188/system_stats >/dev/null 2>&1 \
    && echo "✅ ComfyUI up" \
    || { echo "❌ ComfyUI failed! tail /workspace/logs/comfyui.log"; exit 1; }

# Streamlit
echo "Starting Streamlit..."
nohup streamlit run /workspace/girlbot/app.py \
    --server.address 0.0.0.0 \
    --server.port 8501 \
    --server.headless true \
    > /workspace/logs/streamlit.log 2>&1 &
for i in $(seq 1 12); do
    curl -s http://localhost:8501 >/dev/null 2>&1 && break
    sleep 2
done
curl -s http://localhost:8501 >/dev/null 2>&1 \
    && echo "✅ Streamlit up" \
    || { echo "❌ Streamlit failed! tail /workspace/logs/streamlit.log"; exit 1; }

echo ""
echo "=== ALL SERVICES RUNNING ==="
echo "Ports: 11434 (Ollama) | 8188 (ComfyUI) | 8501 (Frontend)"
