#!/bin/bash
while true; do
  pgrep -f "ollama serve" > /dev/null || bash /workspace/start-services.sh
  pgrep -f "main.py" > /dev/null || bash /workspace/start-services.sh
  pgrep -f "streamlit" > /dev/null || bash /workspace/start-services.sh
  sleep 15
done