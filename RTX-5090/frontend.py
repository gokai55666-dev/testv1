cat > /workspace/frontend.py << 'EOF'
import http.server
import socketserver
import json
import requests
import os

PORT = 8501
OLLAMA_URL = "http://localhost:11434/api/generate"
COMFY_URL = "http://localhost:8188/prompt"

HTML = '''<!DOCTYPE html>
<html>
<head><title>GIRL BOT AI</title>
<style>
body{background:#0f0f1a;color:white;font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px}
.chat{height:400px;overflow-y:auto;border:1px solid #333;padding:10px;margin-bottom:10px;background:#1a1a2a}
.user{background:#0066ff;padding:8px;border-radius:8px;margin:5px 0;text-align:right}
.bot{background:#2a2a3a;padding:8px;border-radius:8px;margin:5px 0}
input{width:80%;padding:10px;border-radius:8px;border:none}
button{padding:10px 20px;margin-left:10px;background:#0066ff;color:white;border:none;border-radius:8px}
.status{font-size:12px;margin:5px 0;padding:5px;border-radius:4px}
.ok{background:#2e7d32}
.err{background:#c62828}
</style>
</head>
<body>
<h1>🤖 GIRL BOT AI</h1>
<div id="status-ollama" class="status">Checking Ollama...</div>
<div id="status-comfy" class="status">Checking ComfyUI...</div>
<div class="chat" id="chat"><div class="bot">Hello! Type "draw: a cat" to generate images.</div></div>
<input id="input" placeholder="Ask anything..." onkeypress="if(event.keyCode==13)send()">
<button onclick="send()">Send</button>
<script>
async function check(){fetch('/api/ollama').then(r=>r.ok?document.getElementById('status-ollama').innerHTML='✅ Ollama':document.getElementById('status-ollama').innerHTML='❌ Ollama').catch(e=>document.getElementById('status-ollama').innerHTML='❌ Ollama');fetch('/api/comfy').then(r=>r.ok?document.getElementById('status-comfy').innerHTML='✅ ComfyUI':document.getElementById('status-comfy').innerHTML='❌ ComfyUI').catch(e=>document.getElementById('status-comfy').innerHTML='❌ ComfyUI')}
setInterval(check,30000);check();
async function send(){let msg=document.getElementById('input').value;if(!msg)return;let chat=document.getElementById('chat');chat.innerHTML+=`<div class="user">${msg}</div>`;document.getElementById('input').value='';chat.innerHTML+=`<div class="bot">🤔...</div>`;chat.scrollTop=chat.scrollHeight;let res=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({msg})});let data=await res.json();chat.lastChild.remove();chat.innerHTML+=`<div class="bot">${data.response}</div>`;chat.scrollTop=chat.scrollHeight;}
</script>
</body>
</html>'''

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML.encode())
        elif self.path == '/api/ollama':
            try:
                requests.get("http://localhost:11434/api/tags", timeout=2)
                self.send_response(200)
            except:
                self.send_response(500)
            self.end_headers()
        elif self.path == '/api/comfy':
            try:
                requests.get("http://localhost:8188/system_stats", timeout=2)
                self.send_response(200)
            except:
                self.send_response(500)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path == '/api/chat':
            length = int(self.headers['Content-Length'])
            data = json.loads(self.rfile.read(length))
            try:
                r = requests.post(OLLAMA_URL, json={"model": "dolphin-llama3:8b", "prompt": data['msg'], "stream": False}, timeout=60)
                resp = r.json().get('response', 'Error')
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'response': resp}).encode())
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(json.dumps({'response': f'Error: {e}'}).encode())

print("Starting GIRL BOT AI at http://0.0.0.0:8501")
httpd = socketserver.TCPServer(("0.0.0.0", PORT), Handler)
httpd.serve_forever()
EOF