#!/bin/bash
# ============================================================
# GIRL BOT AI - FIX SCRIPT (fix.sh)
# Run this if ComfyUI can't generate images (missing model)
# or if workflows are broken.
# Safe to re-run. Does NOT overwrite app.py.
# ============================================================

cd /workspace
echo "=== GIRL BOT AI FIX SCRIPT ==="

# ── 1. Download SD 1.5 model (REQUIRED for ComfyUI generation) ──────────────
mkdir -p /workspace/ComfyUI/models/checkpoints

MODEL_PATH="/workspace/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors"
if [ ! -f "$MODEL_PATH" ]; then
    echo "[1/3] Downloading SD 1.5 model (~4GB, this will take a few minutes)..."
    wget --show-progress -O "$MODEL_PATH" \
        "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
    echo "  ✅ Model downloaded"
else
    echo "[1/3] ✅ SD 1.5 model already present ($(du -sh "$MODEL_PATH" | cut -f1))"
fi

# ── 2. Fix/recreate workflow templates (correct filenames!) ─────────────────
# NOTE: app.py looks for text2img_basic.json and text2img_hq.json
# The old fix.sh created sd_basic.json (WRONG) - this is the corrected version

echo "[2/3] Writing workflow templates..."
mkdir -p /workspace/girlbot/workflows

cat > /workspace/girlbot/workflows/text2img_basic.json << 'EOF'
{
  "1": {"inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"}, "class_type": "CheckpointLoaderSimple"},
  "2": {"inputs": {"text": "", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "3": {"inputs": {"text": "text, watermark, blurry, low quality, ugly", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "4": {"inputs": {"width": 512, "height": 512, "batch_size": 1}, "class_type": "EmptyLatentImage"},
  "5": {"inputs": {"seed": 0, "steps": 20, "cfg": 8.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}, "class_type": "KSampler"},
  "6": {"inputs": {"samples": ["5", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
  "7": {"inputs": {"filename_prefix": "GirlBot", "images": ["6", 0]}, "class_type": "SaveImage"}
}
EOF

cat > /workspace/girlbot/workflows/text2img_hq.json << 'EOF'
{
  "1": {"inputs": {"ckpt_name": "v1-5-pruned-emaonly.safetensors"}, "class_type": "CheckpointLoaderSimple"},
  "2": {"inputs": {"text": "masterpiece, best quality, highly detailed, ", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "3": {"inputs": {"text": "worst quality, lowres, blurry, watermark, ugly", "clip": ["1", 1]}, "class_type": "CLIPTextEncode"},
  "4": {"inputs": {"width": 1024, "height": 1024, "batch_size": 1}, "class_type": "EmptyLatentImage"},
  "5": {"inputs": {"seed": 0, "steps": 35, "cfg": 7.0, "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}, "class_type": "KSampler"},
  "6": {"inputs": {"samples": ["5", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
  "7": {"inputs": {"filename_prefix": "GirlBot_HQ", "images": ["6", 0]}, "class_type": "SaveImage"}
}
EOF

echo "  ✅ Workflows written: text2img_basic.json + text2img_hq.json"

# ── 3. Verify ComfyUI can see the model ─────────────────────────────────────
echo "[3/3] Verifying ComfyUI model detection..."
if curl -s http://localhost:8188/object_info/CheckpointLoaderSimple 2>/dev/null | grep -q "v1-5"; then
    echo "  ✅ ComfyUI can see the SD 1.5 model"
elif curl -s http://localhost:8188/system_stats >/dev/null 2>&1; then
    echo "  ⚠️  ComfyUI is running but may need a restart to detect new model."
    echo "  Run: bash /workspace/testv1/RTX-5090/start-services.sh"
else
    echo "  ⚠️  ComfyUI not running. Start it with:"
    echo "  bash /workspace/testv1/RTX-5090/start-services.sh"
fi

echo ""
echo "=== FIX COMPLETE ==="
echo "If image generation still fails, run: bash /workspace/testv1/RTX-5090/start-services.sh"
