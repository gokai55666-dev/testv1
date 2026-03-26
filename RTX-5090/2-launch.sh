#!/bin/bash
# ============================================================
# GIRL BOT AI - RTX 5090 LAUNCH (2-launch.sh)
# Run after setup. Also safe to re-run at any time.
# ============================================================

echo "=== GIRL BOT AI - LAUNCHING SERVICES ==="
cd /workspace

# --- Critical env vars (always set, even on re-run) ---
export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

# --- Kill any stale services ---
echo "Cleaning up old processes..."
pkill -9 -f "ollama serve" 2>/dev/null || true
pkill -9 -f "streamlit" 2>/dev/null || true
pkill -9 -f "python.*main.py" 2>/dev/null || true
sleep 3

# ============================================================
# SERVICE 1: OLLAMA
# ============================================================
echo ""
echo "[1/3] Starting Ollama..."
OLLAMA_MODELS=/workspace/ollama OLLAMA_HOST=0.0.0.0:11434 \
    nohup ollama serve > /workspace/logs/ollama.log 2>&1 &
OLLAMA_PID=$!

# Health loop - wait up to 40s
echo "  Waiting for Ollama..."
for i in $(seq 1 20); do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "  ✅ Ollama ready (${i}x2s)"
        break
    fi
    sleep 2
    if [ $i -eq 20 ]; then
        echo "  ❌ Ollama failed to start! Check: tail -20 /workspace/logs/ollama.log"
        exit 1
    fi
done

# Pull model only if not already present
if ! OLLAMA_MODELS=/workspace/ollama ollama list 2>/dev/null | grep -q "dolphin-llama3"; then
    echo "  Pulling dolphin-llama3:8b (first time, ~4GB)..."
    OLLAMA_MODELS=/workspace/ollama ollama pull dolphin-llama3:8b
    # Update config to mark model as pulled
    python3 -c "
import json
with open('/workspace/system/config.json', 'r') as f: c = json.load(f)
c['model']['pulled'] = True
with open('/workspace/system/config.json', 'w') as f: json.dump(c, f, indent=2)
" 2>/dev/null || true
else
    echo "  ✅ Model already pulled, skipping download"
fi

# ============================================================
# SERVICE 2: COMFYUI
# ============================================================
echo ""
echo "[2/3] Starting ComfyUI..."

if [ ! -f "/workspace/ComfyUI/main.py" ]; then
    echo "  ❌ ComfyUI not found! Run 1-setup.sh first."
    exit 1
fi

cd /workspace/ComfyUI
nohup python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --highvram \
    > /workspace/logs/comfyui.log 2>&1 &
COMFY_PID=$!
cd /workspace

# Health loop - ComfyUI takes longer on cold GPU, wait up to 90s
echo "  Waiting for ComfyUI (can take 30-60s on first load)..."
for i in $(seq 1 45); do
    if curl -s http://localhost:8188/system_stats >/dev/null 2>&1; then
        echo "  ✅ ComfyUI ready (${i}x2s)"
        break
    fi
    sleep 2
    if [ $i -eq 45 ]; then
        echo "  ❌ ComfyUI failed! Check: tail -30 /workspace/logs/comfyui.log"
        exit 1
    fi
done

# ============================================================
# SERVICE 3: STREAMLIT FRONTEND
# ============================================================
echo ""
echo "[3/3] Starting Girl Bot AI Frontend..."

APP_PATH="/workspace/girlbot/app.py"
if [ ! -f "$APP_PATH" ]; then
    echo "  ❌ app.py not found at $APP_PATH!"
    echo "  Run: cp /workspace/testv1/RTX-5090/app.py /workspace/girlbot/app.py"
    exit 1
fi

# Install streamlit if missing
if ! python3 -c "import streamlit" 2>/dev/null; then
    pip install -q streamlit requests --break-system-packages
fi

nohup streamlit run "$APP_PATH" \
    --server.address 0.0.0.0 \
    --server.port 8501 \
    --server.headless true \
    > /workspace/logs/streamlit.log 2>&1 &
STREAMLIT_PID=$!

# Health loop
echo "  Waiting for Streamlit..."
for i in $(seq 1 15); do
    if curl -s http://localhost:8501 >/dev/null 2>&1; then
        echo "  ✅ Streamlit ready (${i}x2s)"
        break
    fi
    sleep 2
    if [ $i -eq 15 ]; then
        echo "  ❌ Streamlit failed! Check: tail -20 /workspace/logs/streamlit.log"
        exit 1
    fi
done

# ============================================================
# FINAL STATUS
# ============================================================
echo ""
echo "========================================"
echo "=== ALL SERVICES RUNNING ==="
echo "========================================"
echo ""
curl -s http://localhost:11434/api/tags >/dev/null && echo "✅ Ollama   → :11434" || echo "❌ Ollama   → :11434 FAILED"
curl -s http://localhost:8188/system_stats >/dev/null && echo "✅ ComfyUI  → :8188"  || echo "❌ ComfyUI  → :8188 FAILED"
curl -s http://localhost:8501 >/dev/null && echo "✅ Frontend → :8501"  || echo "❌ Frontend → :8501 FAILED"
echo ""
echo "PIDs: Ollama=$OLLAMA_PID | ComfyUI=$COMFY_PID | Streamlit=$STREAMLIT_PID"
echo ""
echo "⚠️  MAKE SURE these ports are exposed in RunPod HTTP Services:"
echo "    11434 (Ollama) | 8188 (ComfyUI) | 8501 (Frontend)"
echo ""
echo "Logs: /workspace/logs/{ollama,comfyui,streamlit}.log"
