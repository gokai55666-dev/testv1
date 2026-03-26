import os
import subprocess

os.environ["STREAMLIT_SERVER_ADDRESS"] = "0.0.0.0"

subprocess.run([
    "streamlit", "run", "app.py",
    "--server.address", "0.0.0.0",
    "--server.port", "8501"
])