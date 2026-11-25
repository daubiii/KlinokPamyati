#!/usr/bin/env python3
# Офлайн-прогон сцен появления боссов (без Studio): эмуляция Roblox API
# (mock.lua) + модули проекта (фабрики) + сценарий (driver.lua / driver_dump.lua).
# Обычно запускается через run.sh.
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..", "..", "src")
OUT = os.path.join(HERE, "out")
os.makedirs(OUT, exist_ok=True)
out = []
out.append(open(os.path.join(HERE, "mock.lua"), encoding="utf-8").read())
out.append("""
local FACTORIES, STUBS, LOADED = {}, {}, {}
local LOGS = {}
local warn = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end table.insert(LOGS, "WARN " .. table.concat(t, " ")) end
local print = function(...) end
local function require(node)
	if typeof(node) ~= "Instance" then error("require: не экземпляр " .. typeof(node), 2) end
	local path = D[node].modulePath
	if not path then error("require: не модуль " .. methods.GetFullName(node), 2) end
	if LOADED[path] ~= nil then return LOADED[path] end
	if STUBS[path] ~= nil then LOADED[path] = STUBS[path] return STUBS[path] end
	local f = FACTORIES[path]
	if not f then error("require: нет фабрики " .. path, 2) end
	local value = f(node)
	LOADED[path] = value
	return value
end
local function moduleNode(root, path, parts)
	local node = root
	for i, name in ipairs(parts) do
		local child = methods.FindFirstChild(node, name)
		if not child then
			child = newInstance(i == #parts and "ModuleScript" or "Folder")
			D[child].Name = name
			setParent(child, node)
		end
		node = child
	end
	D[node].modulePath = path
	return node
end
""")
roots = [
    ("ReplicatedStorage/Shared", os.path.join(ROOT, "ReplicatedStorage/Shared"), 'service("ReplicatedStorage")', ["Shared"]),
    ("PlayerScripts/Lib", os.path.join(ROOT, "StarterPlayer/StarterPlayerScripts/Lib"), "playerScripts", ["Lib"]),
    ("PlayerScripts/Controllers", os.path.join(ROOT, "StarterPlayer/StarterPlayerScripts/Controllers"), "playerScripts", ["Controllers"]),
]
want_controllers = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
for prefix, base, rootExpr, rootParts in roots:
    for dirpath, _, files in os.walk(base):
        for fn in sorted(files):
            if not fn.endswith(".lua"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), base)[:-4]
            parts = rel.split(os.sep)
            path = prefix + "/" + "/".join(parts)
            nodeParts = rootParts + parts
            lua_parts = ", ".join('"%s"' % p for p in nodeParts)
            out.append('moduleNode(%s, "%s", { %s })' % (rootExpr, path, lua_parts))
            if prefix == "PlayerScripts/Controllers" and want_controllers is not None and parts[-1] not in want_controllers:
                continue
            src = open(os.path.join(dirpath, fn), encoding="utf-8").read()
            out.append('FACTORIES["%s"] = function(script)\n%s\nend' % (path, src))
prefix = os.environ.get("SIM_PRELUDE", "")
out.append(prefix + open(os.path.join(HERE, sys.argv[2] if len(sys.argv) > 2 else "driver.lua"), encoding="utf-8").read())
open(os.path.join(OUT, "sim.lua"), "w", encoding="utf-8").write("\n".join(out))
print("ok", sum(len(x) for x in out))
