import subprocess
import socket

def port_open(port):
    s = socket.socket()
    try:
        s.settimeout(2)
        s.connect(("127.0.0.1", port))
        return True
    except:
        return False
    finally:
        s.close()

services = {
    "Ollama": (11434, "ollama"),
    "ComfyUI": (8188, "main.py"),
    "Streamlit": (8501, "streamlit")
}

for name, (port, process) in services.items():
    proc = subprocess.run(["pgrep", "-f", process], capture_output=True)
    running = proc.returncode == 0
    port_status = port_open(port)

    print(f"{name}: Process={'YES' if running else 'NO'}, Port={'OPEN' if port_status else 'CLOSED'}")