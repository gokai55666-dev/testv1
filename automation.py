# automation.py
import json
import os
from datetime import datetime
from openai import OpenAI

# -----------------------------
# Configuration
# -----------------------------
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")  # make sure to set your key
OUTPUT_DIR = "assets"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Load prompts
with open("prompt_templates.json", "r") as f:
    prompts = json.load(f)

# Initialize client
client = OpenAI(api_key=OPENAI_API_KEY)

# -----------------------------
# Core functions
# -----------------------------
def run_text_prompt(prompt):
    """Run text-based prompt via OpenAI"""
    response = client.responses.create(
        model="gpt-4.1",
        input=prompt
    )
    return response.output_text

def generate_image(description, filename=None):
    """Generate image via DALL·E"""
    if filename is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{OUTPUT_DIR}/image_{timestamp}.png"

    result = client.images.generate(
        model="gpt-image-1",
        prompt=description,
        size="1024x1024"
    )
    image_data = result.data[0].b64_json

    import base64
    with open(filename, "wb") as f:
        f.write(base64.b64decode(image_data))

    return filename

# -----------------------------
# Workflow functions
# -----------------------------
def workflow_cycle():
    # 1. Signal
    signal_prompt = prompts["signal"]
    print("Running Signal Detection...")
    signals = run_text_prompt(signal_prompt)
    print(f"Signals detected:\n{signals}\n")

    # 2. Filter / Analysis
    filter_prompt = f"{prompts['filter']}\nSignals:\n{signals}"
    print("Running Analysis & Ranking...")
    filtered = run_text_prompt(filter_prompt)
    print(f"Filtered Output:\n{filtered}\n")

    # 3. Validate / Deep Dive
    validate_prompt = f"{prompts['validate']}\nTop filtered:\n{filtered}"
    print("Running Validation / Risk Analysis...")
    validated = run_text_prompt(validate_prompt)
    print(f"Validation:\n{validated}\n")

    # 4. Strategy / Content Generation
    strategy_prompt = f"{prompts['strategy']}\nValidated info:\n{validated}"
    print("Generating Content / Strategy...")
    content = run_text_prompt(strategy_prompt)
    print(f"Generated Content:\n{content}\n")

    # Save content
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    content_file = f"{OUTPUT_DIR}/content_{timestamp}.txt"
    with open(content_file, "w", encoding="utf-8") as f:
        f.write(content)

    # 5. Image Generation (optional)
    if "image" in prompts:
        image_desc = f"{prompts['image']}\nBased on content:\n{content}"
        print("Generating Image...")
        image_file = generate_image(image_desc)
        print(f"Image saved to {image_file}\n")

    # 6. Critique / Feedback loop
    critic_prompt = f"{prompts['critic']}\nStrategy & content:\n{content}"
    print("Running Critique / Improvement...")
    improved = run_text_prompt(critic_prompt)
    improved_file = f"{OUTPUT_DIR}/improved_{timestamp}.txt"
    with open(improved_file, "w", encoding="utf-8") as f:
        f.write(improved)
    print(f"Improved version saved to {improved_file}\n")

# -----------------------------
# Main execution
# -----------------------------
if __name__ == "__main__":
    print("=== Starting AI Workflow Cycle ===\n")
    workflow_cycle()
    print("\n=== Workflow Complete ===")
