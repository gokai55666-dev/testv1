#!/bin/bash
# ============================================================
# GIRL BOT AI - WATCHDOG MONITOR (monitor.sh)
# Runs in background, auto-restarts crashed services.
# Usage: nohup bash /workspace/testv1/RTX-5090/monitor.sh > /workspace/logs/monitor.log 2>&1 &
# ============================================================

export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

INTERVAL=30   # Check every 30s
MAX_RETRIES=3 # Max restarts per service before giving up
LOG=/workspace/logs/monitor.log

declare -A FAILURES=( [ollama]=0 [comfyui]=0 [streamlit]=0 )

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

restart_ollama() {
    log "Restarting Ollama..."
    pkill -f "ollama serve" 2>/dev/null || true
    sleep 2
    OLLAMA_MODELS=/workspace/ollama OLLAMA_HOST=0.0.0.0:11434 \
        nohup ollama serve >> /workspace/logs/ollama.log 2>&1 &
    sleep 8
}

restart_comfyui() {
    log "Restarting ComfyUI..."
    pkill -f "python.*main.py" 2>/dev/null || true
    sleep 2
    cd /workspace/ComfyUI
    nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram \
        >> /workspace/logs/comfyui.log 2>&1 &
    cd /workspace
    sleep 20
}

restart_streamlit() {
    log "Restarting Streamlit..."
    pkill -f streamlit 2>/dev/null || true
    sleep 2
    nohup streamlit run /workspace/girlbot/app.py \
        --server.address 0.0.0.0 --server.port 8501 --server.headless true \
        >> /workspace/logs/streamlit.log 2>&1 &
    sleep 6
}

log "=== WATCHDOG STARTED (interval=${INTERVAL}s) ==="

while true; do
    # Check Ollama
    if ! curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1; then
        FAILURES[ollama]=$((${FAILURES[ollama]}+1))
        if [ ${FAILURES[ollama]} -le $MAX_RETRIES ]; then
            log "⚠️ Ollama down (attempt ${FAILURES[ollama]}/$MAX_RETRIES) — restarting..."
            restart_ollama
            curl -s http://localhost:11434/api/tags >/dev/null 2>&1 \
                && log "✅ Ollama recovered" \
                || log "❌ Ollama still down"
        else
            log "🚨 Ollama exceeded max retries. Manual intervention needed."
        fi
    else
        FAILURES[ollama]=0
    fi

    # Check ComfyUI
    if ! curl -s --max-time 3 http://localhost:8188/system_stats >/dev/null 2>&1; then
        FAILURES[comfyui]=$((${FAILURES[comfyui]}+1))
        if [ ${FAILURES[comfyui]} -le $MAX_RETRIES ]; then
            log "⚠️ ComfyUI down (attempt ${FAILURES[comfyui]}/$MAX_RETRIES) — restarting..."
            restart_comfyui
            curl -s http://localhost:8188/system_stats >/dev/null 2>&1 \
                && log "✅ ComfyUI recovered" \
                || log "❌ ComfyUI still down"
        else
            log "🚨 ComfyUI exceeded max retries. Manual intervention needed."
        fi
    else
        FAILURES[comfyui]=0
    fi

    # Check Streamlit
    if ! curl -s --max-time 3 http://localhost:8501 >/dev/null 2>&1; then
        FAILURES[streamlit]=$((${FAILURES[streamlit]}+1))
        if [ ${FAILURES[streamlit]} -le $MAX_RETRIES ]; then
            log "⚠️ Streamlit down (attempt ${FAILURES[streamlit]}/$MAX_RETRIES) — restarting..."
            restart_streamlit
            curl -s http://localhost:8501 >/dev/null 2>&1 \
                && log "✅ Streamlit recovered" \
                || log "❌ Streamlit still down"
        else
            log "🚨 Streamlit exceeded max retries. Manual intervention needed."
        fi
    else
        FAILURES[streamlit]=0
    fi

    sleep $INTERVAL
done
