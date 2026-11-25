"""Прогнать Lua-файл в Studio через мост MCP (tools/studio-bridge.js, порт 8799).

    python fx/run_in_studio.py <файл.lua> [Edit|Server|Client] [--rebuild]

--rebuild: для BuildFx.lua — собрать шаблоны заново (REBUILD = true).
"""
import json
import sys
import urllib.request

path = sys.argv[1]
args = [a for a in sys.argv[2:] if not a.startswith("--")]
dm = args[0] if args else "Edit"
code = open(path, encoding="utf-8").read()
if "--rebuild" in sys.argv:
    code = code.replace("local REBUILD = false", "local REBUILD = true", 1)
req = urllib.request.Request("http://127.0.0.1:8799/tool", method="POST", headers={"Content-Type": "application/json"})
studios = json.loads(urllib.request.urlopen(urllib.request.Request("http://127.0.0.1:8799/tool", data=json.dumps({"name": "list_roblox_studios", "arguments": {}}).encode(), method="POST", headers={"Content-Type": "application/json"})).read())
text = studios.get("text") or ""
sid = json.loads(text)["studios"][0]["id"] if text.startswith("{") else None
body = {"name": "execute_luau", "arguments": {"studio_id": sid, "datamodel_type": dm, "code": code}}
out = json.loads(urllib.request.urlopen(req, data=json.dumps(body).encode()).read())
sys.stdout.reconfigure(encoding="utf-8")
print(out.get("text"))
