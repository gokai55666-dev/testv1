"""
GIRL BOT AI Studio - RTX 5090 Edition
Dynamic ComfyUI workflow construction + Ollama LLM + Self-healing status
"""
import streamlit as st
import requests
import json
import os
import random
import time
from datetime import datetime

# ── Page config ─────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="GIRL BOT AI Studio",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ── Load system config ───────────────────────────────────────────────────────
CONFIG_PATH = "/workspace/system/config.json"
try:
    with open(CONFIG_PATH) as f:
        CFG = json.load(f)
except Exception:
    CFG = {
        "hardware": {"gpu": "RTX 5090", "cuda": "12.8"},
        "services": {
            "ollama":  {"url": "http://localhost:11434"},
            "comfyui": {"url": "http://localhost:8188"},
            "frontend":{"url": "http://localhost:8501"}
        },
        "storage": {
            "workflows": "/workspace/girlbot/workflows",
            "output":    "/workspace/ComfyUI/output",
            "logs":      "/workspace/logs"
        },
        "model": {"default": "dolphin-llama3:8b"}
    }

OLLAMA_URL    = CFG["services"]["ollama"]["url"]
COMFY_URL     = CFG["services"]["comfyui"]["url"]
WORKFLOW_DIR  = CFG["storage"]["workflows"]
OUTPUT_DIR    = CFG["storage"].get("output", "/workspace/ComfyUI/output")
DEFAULT_MODEL = CFG["model"]["default"]

# ── Session state ────────────────────────────────────────────────────────────
for key, default in [
    ("messages", []),
    ("personality", "Helpful Assistant"),
    ("gen_mode", "basic"),
    ("last_prompt_id", None),
]:
    if key not in st.session_state:
        st.session_state[key] = default

# ── Service helpers ──────────────────────────────────────────────────────────
def check_service(url: str, timeout: float = 1.5) -> bool:
    try:
        r = requests.get(url, timeout=timeout)
        return r.status_code < 500
    except Exception:
        return False

def restart_service(name: str):
    """Attempt service restart via shell (best-effort)."""
    cmds = {
        "ollama":   "OLLAMA_MODELS=/workspace/ollama OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve > /workspace/logs/ollama.log 2>&1 &",
        "comfyui":  "cd /workspace/ComfyUI && nohup python3 main.py --listen 0.0.0.0 --port 8188 --highvram > /workspace/logs/comfyui.log 2>&1 &",
        "streamlit":"nohup streamlit run /workspace/girlbot/app.py --server.address 0.0.0.0 --server.port 8501 --server.headless true > /workspace/logs/streamlit.log 2>&1 &",
    }
    if name in cmds:
        os.system(cmds[name])
        time.sleep(5)
        return True
    return False

# ── Dynamic workflow construction ─────────────────────────────────────────────
def construct_workflow(prompt: str, mode: str = "basic", seed: int = None) -> dict:
    """
    Builds a ComfyUI workflow JSON dynamically from a user prompt.
    Reads base template, then modifies nodes based on intent.
    """
    if seed is None:
        seed = random.randint(1, 2**31)

    # Load base template
    template = os.path.join(WORKFLOW_DIR, f"text2img_{mode}.json")
    if not os.path.exists(template):
        template = os.path.join(WORKFLOW_DIR, "text2img_basic.json")

    with open(template) as f:
        wf = json.load(f)

    prompt_lower = prompt.lower()

    # --- Detect intent and modify workflow dynamically ---
    # Quality boost keywords
    if any(k in prompt_lower for k in ["detailed", "high quality", "hq", "4k", "realistic", "photo"]):
        mode = "hq"
        template_hq = os.path.join(WORKFLOW_DIR, "text2img_hq.json")
        if os.path.exists(template_hq):
            with open(template_hq) as f:
                wf = json.load(f)

    # Anime/illustration style
    if any(k in prompt_lower for k in ["anime", "manga", "cartoon", "illustration", "drawing"]):
        prefix = "anime style, illustration, "
    # Photorealistic style
    elif any(k in prompt_lower for k in ["photo", "realistic", "real", "photograph"]):
        prefix = "photorealistic, DSLR, 8k, sharp focus, "
    # Artistic
    elif any(k in prompt_lower for k in ["painting", "art", "artistic", "watercolor", "oil"]):
        prefix = "masterpiece painting, highly detailed, artistic, "
    else:
        prefix = ""

    # Find & update positive prompt node
    for node_id, node in wf.items():
        if node.get("class_type") == "CLIPTextEncode" and node_id == "2":
            existing = node["inputs"].get("text", "")
            # Prepend existing quality prefixes + user prompt
            node["inputs"]["text"] = f"{prefix}{existing}{prompt}".strip(", ")

    # Find & update KSampler seed
    for node_id, node in wf.items():
        if node.get("class_type") == "KSampler":
            node["inputs"]["seed"] = seed
            # Boost steps for portrait/face keywords
            if any(k in prompt_lower for k in ["portrait", "face", "person", "woman", "man", "girl", "boy"]):
                node["inputs"]["steps"] = max(node["inputs"].get("steps", 20), 30)
                node["inputs"]["cfg"] = 7.5

    # Auto-upscale resolution for high quality
    for node_id, node in wf.items():
        if node.get("class_type") == "EmptyLatentImage":
            if mode == "hq" or any(k in prompt_lower for k in ["4k", "high res", "detailed"]):
                node["inputs"]["width"]  = 1024
                node["inputs"]["height"] = 1024

    return wf, seed

def generate_image(prompt: str, mode: str = "basic"):
    """Submit dynamic workflow to ComfyUI and return result."""
    try:
        wf, seed = construct_workflow(prompt, mode)
        r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": wf}, timeout=10)
        r.raise_for_status()
        prompt_id = r.json().get("prompt_id", "unknown")
        st.session_state.last_prompt_id = prompt_id
        return f"✅ Generation submitted!\n- Prompt ID: `{prompt_id}`\n- Seed: `{seed}`\n- Mode: `{mode}`\n\nCheck ComfyUI or the output folder when done."
    except requests.exceptions.ConnectionError:
        return "❌ ComfyUI unreachable. Try restarting from the sidebar."
    except Exception as e:
        return f"❌ Error: {e}"

def poll_image_result(prompt_id: str):
    """Check if a generation is done and return the image path."""
    try:
        r = requests.get(f"{COMFY_URL}/history/{prompt_id}", timeout=5)
        history = r.json()
        if prompt_id in history:
            outputs = history[prompt_id].get("outputs", {})
            for node_output in outputs.values():
                if "images" in node_output:
                    for img in node_output["images"]:
                        path = os.path.join(OUTPUT_DIR, img["filename"])
                        if os.path.exists(path):
                            return path
    except Exception:
        pass
    return None

# ── Ollama chat ───────────────────────────────────────────────────────────────
PERSONALITIES = {
    "Helpful Assistant":   "You are GIRL BOT AI, a helpful and friendly assistant. Be concise and clear.",
    "Creative Director":   "You are GIRL BOT AI in Creative Director mode. Think visually, suggest bold ideas, be imaginative.",
    "Strict Coder":        "You are GIRL BOT AI in Coder mode. Be precise, technical, and efficient. Show code examples.",
    "Philosopher":         "You are GIRL BOT AI in Philosopher mode. Think deeply, question assumptions, be thought-provoking.",
}

def chat_ollama(prompt: str, personality: str) -> str:
    system = PERSONALITIES.get(personality, PERSONALITIES["Helpful Assistant"])
    try:
        r = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model":  DEFAULT_MODEL,
                "prompt": f"{system}\n\nUser: {prompt}\nAI:",
                "stream": False
            },
            timeout=120
        )
        r.raise_for_status()
        return r.json().get("response", "No response from model.")
    except requests.exceptions.ConnectionError:
        return "❌ Cannot reach Ollama. Is it running on port 11434?"
    except requests.exceptions.Timeout:
        return "⏳ Ollama timed out. The model may still be loading — try again in 10s."
    except Exception as e:
        return f"❌ Error: {e}"

# ── SIDEBAR ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("⚙️ GIRL BOT AI")
    st.caption(f"{CFG['hardware']['gpu']} · CUDA {CFG['hardware']['cuda']}")

    st.divider()
    st.subheader("🟢 Service Status")

    col1, col2 = st.columns(2)
    ollama_ok  = check_service(f"{OLLAMA_URL}/api/tags")
    comfy_ok   = check_service(f"{COMFY_URL}/system_stats")

    col1.metric("Ollama",  "✅ Up" if ollama_ok  else "❌ Down")
    col2.metric("ComfyUI", "✅ Up" if comfy_ok   else "❌ Down")

    if not ollama_ok:
        if st.button("🔄 Restart Ollama"):
            restart_service("ollama")
            st.rerun()

    if not comfy_ok:
        if st.button("🔄 Restart ComfyUI"):
            restart_service("comfyui")
            st.rerun()

    st.divider()
    st.subheader("🤖 Personality")
    st.session_state.personality = st.selectbox(
        "Mode",
        list(PERSONALITIES.keys()),
        index=list(PERSONALITIES.keys()).index(st.session_state.personality)
    )

    st.divider()
    st.subheader("🎨 Image Settings")
    st.session_state.gen_mode = st.selectbox("Quality", ["basic", "hq"], index=0)

    # Check last generation
    if st.session_state.last_prompt_id:
        st.caption(f"Last ID: `{st.session_state.last_prompt_id[:8]}...`")
        if st.button("🖼 Check Result"):
            img_path = poll_image_result(st.session_state.last_prompt_id)
            if img_path:
                st.image(img_path, caption="Latest generation")
            else:
                st.info("Still generating or not found yet.")

    st.divider()
    st.subheader("🔧 Tools")
    if st.button("📋 System Config"):
        st.code(json.dumps(CFG, indent=2), language="json")

    if st.button("📁 Show Workflows"):
        wfs = [f for f in os.listdir(WORKFLOW_DIR) if f.endswith(".json")] if os.path.exists(WORKFLOW_DIR) else []
        st.write(wfs)

    disk = os.popen("df -h /workspace 2>/dev/null | awk 'NR==2{print $3\"/\"$2\" (\"$5\" used)\"}' ").read().strip()
    if disk:
        st.caption(f"💾 {disk}")

    st.link_button("Open ComfyUI", COMFY_URL)

# ── MAIN CHAT INTERFACE ───────────────────────────────────────────────────────
st.title("🤖 GIRL BOT AI Studio")
st.caption("RTX 5090 · Ollama + ComfyUI · Type `draw: <prompt>` to generate images")

# Warn if services are down
if not ollama_ok:
    st.warning("⚠️ Ollama is not running. Chat will fail. Use sidebar to restart.")
if not comfy_ok:
    st.warning("⚠️ ComfyUI is not running. Image generation will fail. Use sidebar to restart.")

# Chat history
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

# Chat input
if user_input := st.chat_input("Ask anything or type 'draw: your description'..."):
    st.session_state.messages.append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)

    with st.chat_message("assistant"):
        inp_lower = user_input.lower()

        # --- Image generation ---
        if inp_lower.startswith(("draw:", "generate:", "image:", "create:")):
            gen_prompt = user_input.split(":", 1)[1].strip()
            with st.spinner(f"🎨 Building workflow for: {gen_prompt}..."):
                response = generate_image(gen_prompt, st.session_state.gen_mode)
            st.markdown(response)

        # --- Show current workflow structure ---
        elif "workflow" in inp_lower and ("show" in inp_lower or "json" in inp_lower):
            wf, seed = construct_workflow("example prompt", st.session_state.gen_mode)
            st.code(json.dumps(wf, indent=2), language="json")
            response = "Above is the current dynamic workflow. Modify via the quality dropdown."

        # --- Self-check ---
        elif any(k in inp_lower for k in ["status", "health", "running", "check services"]):
            lines = [
                f"- Ollama: {'✅ Running' if ollama_ok else '❌ Down'}",
                f"- ComfyUI: {'✅ Running' if comfy_ok else '❌ Down'}",
                f"- GPU: {CFG['hardware']['gpu']} ({CFG['hardware']['cuda']})",
                f"- Model: {DEFAULT_MODEL}",
                f"- Workflows: {', '.join(os.listdir(WORKFLOW_DIR)) if os.path.exists(WORKFLOW_DIR) else 'None'}",
            ]
            response = "**System Status:**\n" + "\n".join(lines)
            st.markdown(response)

        # --- General Ollama chat ---
        else:
            with st.spinner("Thinking..."):
                response = chat_ollama(user_input, st.session_state.personality)
            st.markdown(response)

    st.session_state.messages.append({"role": "assistant", "content": response})
