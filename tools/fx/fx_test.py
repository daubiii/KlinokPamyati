"""Прогон способности в Play с серией кадров (мост MCP, порт 8799).

    python fx/fx_test.py "<команды через ;>" [кадров] [задержка_мс] [--start]

Пример: python fx/fx_test.py "give vortex;god on;nocd on;spawn 6;cam side" 5 150 --start
Кадры сохраняет мост в tools/shots, пути печатаются.
"""
import json
import sys
import time
import urllib.request

B = "http://127.0.0.1:8799/tool"


def call(name, **arguments):
    body = json.dumps({"name": name, "arguments": arguments}).encode()
    req = urllib.request.Request(B, data=body, method="POST", headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=120).read())


sys.stdout.reconfigure(encoding="utf-8")
sid = json.loads(call("list_roblox_studios")["text"])["studios"][0]["id"]
args = [a for a in sys.argv[1:] if not a.startswith("--")]
commands = [c.strip() for c in (args[0] if args else "").split(";") if c.strip()]
frames = int(args[1]) if len(args) > 1 else 4
delay = int(args[2]) if len(args) > 2 else 0

if "--start" in sys.argv:
    print(call("start_stop_play", studio_id=sid, is_start=True)["text"])
    time.sleep(5)
if commands:
    lua = "local C = game.ServerStorage.KlinokDebug:WaitForChild('Cmd', 10)\nlocal out = {}\n"
    for c in commands:
        lua += "table.insert(out, C:Invoke(%s))\n" % json.dumps(c)
    lua += "return table.concat(out, ' | ')"
    print(call("execute_luau", studio_id=sid, datamodel_type="Server", code=lua)["text"])
    time.sleep(1.5)
if frames > 0:
    call("user_keyboard_input", studio_id=sid, datamodel_type="Client",
         actions=[{"action": "keyPress", "key_code": "One"}, {"action": "wait", "wait_time_ms": max(delay, 0)}])
    for i in range(frames):
        print(call("screen_capture", studio_id=sid, capture_id="fx%d" % i)["images"][0])
