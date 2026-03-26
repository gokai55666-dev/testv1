#!/bin/bash
echo "=== Checking Services ==="

curl -s http://localhost:11434 > /dev/null && echo "Ollama OK" || echo "Ollama FAIL"
curl -s http://localhost:8188 > /dev/null && echo "ComfyUI OK" || echo "ComfyUI FAIL"
curl -s http://localhost:8501 > /dev/null && echo "Streamlit OK" || echo "Streamlit FAIL"