"""Подбор позы хвата: python fx/pose_test.py "rs_x,rs_y,rs_z,re_x,rw_x" [смещение камеры x,y,z]"""
import json, sys, time, urllib.request
def call(name, **a):
    r = urllib.request.Request("http://127.0.0.1:8799/tool", data=json.dumps({"name": name, "arguments": a}).encode(), method="POST", headers={"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=60).read())
sid = json.loads(call("list_roblox_studios")["text"])["studios"][0]["id"]
cam = sys.argv[2] if len(sys.argv) > 2 else "7,2.5,-3"
code = 'local p = game.Players:GetPlayers()[1] p:SetAttribute("DebugHold", "%s") p:SetAttribute("DebugCam", Vector3.new(%s)) return "ok"' % (sys.argv[1], cam)
print(call("execute_luau", studio_id=sid, datamodel_type="Server", code=code)["text"])
time.sleep(1.2)
print(call("screen_capture", studio_id=sid, capture_id="pose")["images"][0])
