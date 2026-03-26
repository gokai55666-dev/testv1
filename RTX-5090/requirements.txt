# Girl Bot AI - Python dependencies
# Install with:
#   pip install -r requirements.txt --break-system-packages
#
# NOTE: PyTorch (torch) is installed separately with the cu128 index:
#   pip install torch torchvision torchaudio \
#       --index-url https://download.pytorch.org/whl/cu128 \
#       --break-system-packages
#
# This avoids torch being pulled from PyPI (CPU-only version).

streamlit>=1.32.0
requests>=2.31.0
accelerate>=0.27.0

