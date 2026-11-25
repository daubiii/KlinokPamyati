-- ===== Прогон сцен появления пяти боссов =====
local RS = service("ReplicatedStorage")
local Lighting = service("Lighting")
local rigs = {}
STUBS["PlayerScripts/Controllers/EnemyFx"] = {
	eyesOn = function(rig) rig.eyesLit = true end,
	eyesOff = function(rig) rig.eyesLit = false end,
	start = function() end,
}
STUBS["PlayerScripts/Controllers/EnemyVisualController"] = { rigOf = function(m) return m and rigs[m] or nil end, start = function() end }
local cam = { override = nil, released = 0 }
STUBS["PlayerScripts/Controllers/CameraController"] = {
	setOverride = function(fn) cam.override = fn end,
	release = function(t, look) cam.override = nil cam.released += 1 cam.look = look end,
	state = function() return {} end,
}
local Bus = require(methods.FindFirstChild(playerScripts, "Lib").Bus)
local sfxLog = {}
Bus.on("sfx", function(data) table.insert(sfxLog, data.name) end)
local hudLog = {}
Bus.on("hud", function(data) table.insert(hudLog, data.visible) end)
local Kit = require(methods.FindFirstChild(playerScripts, "Lib").BossFxKit)
Kit.start()
local ClientState = require(RS.Shared.Util.ClientState)
local BossIntros = require(RS.Shared.Config.BossIntros)
local Sfx = require(RS.Shared.Config.Sfx)
local Controller = require(methods.FindFirstChild(playerScripts, "Controllers").BossIntroController)
Controller.start()
local Scenes = require(methods.FindFirstChild(playerScripts, "Controllers").BossIntroScenes)

local function sfxKnown(name)
	if Sfx[name] ~= nil then return true end
	if type(Sfx.get) == "function" then
		local ok, v = pcall(Sfx.get, name)
		return ok and v ~= nil
	end
	for _, key in ipairs({ "Sounds", "List", "Defs", "sounds" }) do
		if type(Sfx[key]) == "table" and Sfx[key][name] ~= nil then return true end
	end
	return false
end

local function bossModel(H, B)
	local m = Instance.new("Model")
	m.Name = "BossVisual"
	local function part(name, y, size)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(B + Vector3.new(0, y, 0))
		p.Parent = m
		return p
	end
	local head = part("Head", H * 0.9, Vector3.new(2, 2, 2))
	local face = Instance.new("Decal")
	face.Parent = head
	part("UpperTorso", H * 0.62, Vector3.new(4, 3, 2))
	part("LowerTorso", H * 0.45, Vector3.new(3, 1.5, 2))
	part("HumanoidRootPart", H * 0.5, Vector3.new(2, 2, 1))
	part("LeftFoot", 0.3, Vector3.new(1, 0.6, 1.5))
	part("RightFoot", 0.3, Vector3.new(1, 0.6, 1.5))
	part("LeftHand", H * 0.45, Vector3.new(1, 1, 1))
	part("RightHand", H * 0.45, Vector3.new(1, 1, 1))
	m.Parent = workspace
	return m
end

local report = {}
local fails = 0
local function check(ok, msg)
	if not ok then
		fails += 1
		table.insert(report, "  ПРОВАЛ: " .. msg)
	end
end

local frameDt = 1 / 30
local function stepFrame()
	SIM.now += frameDt
	SIM.clock += frameDt
	SIM.frame += 1
	runQueue()
	local binds = {}
	for name, b in pairs(SIM.renderBinds) do table.insert(binds, b) end
	table.sort(binds, function(a, b) return a.prio < b.prio end)
	for _, b in ipairs(binds) do
		local ok, err = pcall(b.fn, frameDt)
		if not ok then simError("renderStep: " .. tostring(err)) end
	end
	local camCf, fov
	if cam.override then
		local ok, a, b = pcall(cam.override)
		if not ok then simError("override: " .. tostring(a)) else camCf, fov = a, b end
	end
	D[runService].signals.Heartbeat = D[runService].signals.Heartbeat or signal()
	runService.Heartbeat:Fire(frameDt)
	runService.RenderStepped:Fire(frameDt)
	return camCf, fov
end

local order = { "gatekeeper", "rosewarden", "royal_huntsman", "elder_founder", "chief_chronicler" }
for _, typeId in ipairs(order) do
	for _, mode in ipairs({ "full", "short", "late" }) do
		local cfg = BossIntros.get(typeId)
		local scene = Scenes.get(typeId)
		check(cfg ~= nil and scene ~= nil, typeId .. ": нет сцены")
		if not (cfg and scene) then continue end
		local short = mode == "short"
		local skip = BossIntros.skip(typeId, short)
		if mode == "late" then skip = 2.5 end
		local B = Vector3.new(40 * #report, 0, 0)
		local server = Instance.new("Model")
		server.Name = typeId
		server:SetAttribute("EnemyState", "spawning")
		server:SetAttribute("EnemyStateAt", SIM.now - skip)
		server.Parent = workspace
		local visual = bossModel(scene.H, B)
		local rig = { model = visual, pos = B, facing = Vector3.new(0, 0, -1), fx = {}, server = server, stats = { height = scene.H } }
		rigs[server] = rig
		local ch = makeCharacter(B + Vector3.new(0, 3, 22))
		SIM.errors = {}
		SIM.nan = {}
		LOGS = {}
		table.clear(sfxLog)
		Bus.emit("bossIntro", { kind = "bossIntro", name = "Тест", title = "Титул", duration = BossIntros.duration(typeId, short), short = short, skip = skip, model = server, position = B + Vector3.new(0, 3, 0), typeId = typeId })
		local frames, camFrames, maxDist, hiddenSeen = 0, 0, 0, false
		local beforeEnd = math.ceil((cfg.full - skip) / frameDt)
		local partsPeak = 0
		for i = 1, beforeEnd + 120 do
			local cf, fov = stepFrame()
			frames += 1
			if cf then
				camFrames += 1
				check(typeof(cf) == "CFrame", typeId .. " " .. mode .. ": кадр не CFrame")
				if typeof(cf) == "CFrame" then
					local d = (cf.Position - B).Magnitude
					maxDist = math.max(maxDist, d)
					if cfNaN(cf) then simError("NaN кадр камеры") end
				end
				check(type(fov) == "number" and fov >= 20 and fov <= 90, typeId .. " " .. mode .. ": fov " .. tostring(fov))
			end
			if visual.Head.LocalTransparencyModifier >= 1 then hiddenSeen = true end
			partsPeak = math.max(partsPeak, #Kit.folder():GetDescendants())
			if i == beforeEnd - 3 then
				check(ClientState.isLocked("cutscene"), typeId .. " " .. mode .. ": ввод не заблокирован в сцене")
			end
		end
		local leftovers = #Kit.folder():GetChildren()
		if leftovers > 2 then
			local names = {}
			for _, c in ipairs(Kit.folder():GetChildren()) do table.insert(names, c.Name .. "(" .. #c:GetChildren() .. ")") end
			table.insert(report, "  остались: " .. table.concat(names, ", "))
		end
		local uniq = {}
		for _, n in ipairs(sfxLog) do uniq[n] = (uniq[n] or 0) + 1 end
		local sl = {}
		for n, c in pairs(uniq) do table.insert(sl, n .. "×" .. c) end
		table.sort(sl)
		table.insert(report, "  звуки: " .. table.concat(sl, " "))
		local line = ("%s/%s: кадров %d, камера %d, max дальность %.1f, деталей пик %d, осталось %d, звуков %d"):format(typeId, mode, frames, camFrames, maxDist, partsPeak, leftovers, #sfxLog)
		table.insert(report, line)
		check(cam.override == nil, typeId .. " " .. mode .. ": камера не отпущена")
		check(not ClientState.isLocked("cutscene"), typeId .. " " .. mode .. ": ввод не разблокирован")
		check(camFrames >= beforeEnd - 30, typeId .. " " .. mode .. ": мало кадров камеры " .. camFrames)
		check(maxDist < 45, typeId .. " " .. mode .. ": камера улетела " .. maxDist)
		check(leftovers <= 2, typeId .. " " .. mode .. ": не убрано деталей " .. leftovers)
		check(rig.introOffset == nil and rig.introFacing == nil, typeId .. " " .. mode .. ": introOffset/introFacing не сброшены")
		check(rig.eyesLit == true, typeId .. " " .. mode .. ": глаза не зажглись")
		for _, d in ipairs(visual:GetDescendants()) do
			if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 0 then
				check(false, typeId .. " " .. mode .. ": деталь осталась скрытой " .. d.Name)
				break
			end
		end
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("BasePart") and d.LocalTransparencyModifier ~= 0 then
				check(false, typeId .. " " .. mode .. ": персонаж остался скрытым")
				break
			end
		end
		check(Lighting:FindFirstChild("BossIntroTint") == nil, typeId .. " " .. mode .. ": оттенок не убран")
		if typeId == "elder_founder" or typeId == "chief_chronicler" then
			if mode == "full" then check(hiddenSeen, typeId .. ": модель не скрывалась") end
		end
		for _, name in ipairs(sfxLog) do
			check(sfxKnown(name), typeId .. " " .. mode .. ": неизвестный звук " .. tostring(name))
		end
		for _, e in ipairs(SIM.errors) do check(false, typeId .. " " .. mode .. ": " .. e) end
		for key, tb in pairs(SIM.nan) do check(false, typeId .. " " .. mode .. ": " .. tb) end
		for _, w in ipairs(LOGS) do check(false, typeId .. " " .. mode .. ": " .. w) end
		ch:Destroy()
		server:Destroy()
		visual:Destroy()
		for _ = 1, 60 do stepFrame() end
	end
end
local unknown = {}
for key in pairs(SIM.unknown) do table.insert(unknown, key) end
table.sort(unknown)
print_report = table.concat(report, "\n") .. "\nнеизвестные свойства: " .. table.concat(unknown, ", ") .. ("\nИТОГО: %d провалов"):format(fails)
REAL_PRINT(print_report)
