#!/bin/bash
set -e

echo "=== GIRL BOT AI – RTX-5090 FULL INSTALL ==="

# -----------------------------
# 0. Install tmux (persistent sessions)
# -----------------------------
if ! command -v tmux &> /dev/null
then
    echo "Installing tmux..."
    apt update && apt install -y tmux git python3-pip curl wget
fi

# -----------------------------
# 1. Create required folders
# -----------------------------
echo "Creating workspace folders..."
mkdir -p /workspace/{logs,ollama,ComfyUI,girlbot,testv1/RTX-5090}

# -----------------------------
# 2. Set environment variables
# -----------------------------
echo 'export OLLAMA_MODELS=/workspace/ollama' >> ~/.bashrc
export OLLAMA_MODELS=/workspace/ollama

# -----------------------------
# 3. Install Python dependencies
# -----------------------------
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install streamlit requests pillow numpy torch --extra-index-url https://download.pytorch.org/whl/cu121

# -----------------------------
# 4. Install Ollama
# -----------------------------
if ! command -v ollama &> /dev/null
then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# -----------------------------
# 5. Clone ComfyUI if missing
# -----------------------------
if [ ! -d "/workspace/ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
fi

cd /workspace/ComfyUI
pip install -r requirements.txt

# -----------------------------
# 6. Pull default model if missing
# -----------------------------
if ! ollama list | grep -q dolphin-llama3; then
    echo "Pulling dolphin-llama3 model..."
    ollama pull dolphin-llama3:8b
fi

# -----------------------------
# 7. Create a persistent tmux session for services
# -----------------------------
SESSION="ai"

tmux kill-session -t $SESSION 2>/dev/null
tmux new-session -d -s $SESSION

# -----------------------------
# 8. Start Ollama (tmux window 0)
# -----------------------------
tmux send-keys -t $SESSION "
echo 'Starting Ollama...'
ollama serve > /workspace/logs/ollama.log 2>&1
" C-m
sleep 5

# -----------------------------
# 9. Start ComfyUI (tmux window 1)
# -----------------------------
tmux new-window -t $SESSION
tmux send-keys -t $SESSION:1 "
echo 'Starting ComfyUI...'
cd /workspace/ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1
" C-m
sleep 5

# -----------------------------
# 10. Start Streamlit (tmux window 2)
# -----------------------------
tmux new-window -t $SESSION
tmux send-keys -t $SESSION:2 "
echo 'Starting Streamlit...'
streamlit run /workspace/girlbot/app.py \
--server.address 0.0.0.0 \
--server.port 8501 \
--server.headless true \
--server.enableCORS true \
--server.enableXsrfProtection false \
--browser.gatherUsageStats false \
> /workspace/logs/streamlit.log 2>&1
" C-m
sleep 5

# -----------------------------
# 11. Verification
# -----------------------------
echo ""
echo "=== SERVICE VERIFICATION ==="
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama running (11434)" || echo "❌ Ollama failed"
curl -s http://localhost:8188/system_stats > /dev/null && echo "✅ ComfyUI running (8188)" || echo "❌ ComfyUI failed"
curl -s http://localhost:8501 > /dev/null && echo "✅ Streamlit running (8501)" || echo "❌ Streamlit failed"

# -----------------------------
# 12. Access instructions
# -----------------------------
echo ""
echo "=== ACCESS INFO ==="
echo "RunPod HTTP Service (port 8501) or fallback:"
echo "http://<YOUR-POD-IP>:8501"
echo ""
echo "Attach to services anytime with:"
echo "tmux attach -t $SESSION"
echo ""
echo "Use CTRL+B then D to detach safely"
echo "All services now run persistently even if terminal closes!"