#!/bin/bash
# ============================================================
# GIRL BOT AI - HEALTH CHECK (health.sh)
# Quick status of all services + logs tail on failure
# ============================================================

export OLLAMA_MODELS=/workspace/ollama
export OLLAMA_HOST=0.0.0.0:11434

echo "=== GIRL BOT AI HEALTH CHECK === $(date)"
echo ""

PASS=0
FAIL=0

check() {
    local name="$1"
    local url="$2"
    local log="$3"
    if curl -s --max-time 3 "$url" >/dev/null 2>&1; then
        echo "✅ $name"
        PASS=$((PASS+1))
    else
        echo "❌ $name — FAILED"
        FAIL=$((FAIL+1))
        if [ -n "$log" ] && [ -f "$log" ]; then
            echo "   Last log lines:"
            tail -5 "$log" | sed 's/^/   /'
        fi
    fi
}

check "Ollama   :11434" "http://localhost:11434/api/tags"  "/workspace/logs/ollama.log"
check "ComfyUI  :8188"  "http://localhost:8188/system_stats" "/workspace/logs/comfyui.log"
check "Frontend :8501"  "http://localhost:8501"            "/workspace/logs/streamlit.log"

echo ""
echo "--- Processes ---"
ps aux | grep -E "ollama serve|python.*main.py|streamlit" | grep -v grep | awk '{print $1, $11, $12}' || echo "(none found)"

echo ""
echo "--- Disk ---"
df -h /workspace | awk 'NR<=2'
echo "  /workspace/ollama: $(du -sh /workspace/ollama 2>/dev/null | cut -f1 || echo 'N/A')"
echo "  /workspace/ComfyUI: $(du -sh /workspace/ComfyUI 2>/dev/null | cut -f1 || echo 'N/A')"

echo ""
if [ $FAIL -gt 0 ]; then
    echo "⚠️  $FAIL service(s) down. Run: bash /workspace/testv1/RTX-5090/start-services.sh"
else
    echo "✅ All $PASS services healthy."
fi
