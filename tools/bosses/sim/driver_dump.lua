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


local function num(x) return ("%.3f"):format(x) end
local function cfStr(c)
	local t = { c:GetComponents() }
	for i, v in ipairs(t) do t[i] = num(v) end
	return table.concat(t, ",")
end
local function jstr(s) return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
local function colorStr(c) return num(c.R) .. "," .. num(c.G) .. "," .. num(c.B) end
local function shapeOf(p)
	local ok, shape = pcall(function() return p.Shape end)
	if p.ClassName ~= "Part" then return "Block" end
	return shape and shape.Name or "Block"
end
local function dumpFrame(typeId, tau, cf, fov, visual)
	local parts = {}
	local function add(p, tint, tintA)
		local tr = math.max(p.Transparency, p.LocalTransparencyModifier)
		if tr >= 0.98 then return end
		local col = p.Color
		if tint then col = col:Lerp(tint, tintA) end
		local neon = p.Material == Enum.Material.Neon and 1 or 0
		if tint and tintA > 0.5 then neon = 1 end
		table.insert(parts, "[" .. jstr(shapeOf(p)) .. "," .. num(p.Size.X) .. "," .. num(p.Size.Y) .. "," .. num(p.Size.Z) .. "," .. cfStr(p.CFrame) .. "," .. colorStr(col) .. "," .. num(tr) .. "," .. neon .. "]")
	end
	for _, p in ipairs(Kit.folder():GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Fx" then add(p) end
	end
	local hl = visual:FindFirstChildOfClass("Highlight")
	local tint, tintA
	if hl and hl.Enabled ~= false then tint, tintA = hl.FillColor, 1 - hl.FillTransparency end
	for _, p in ipairs(visual:GetDescendants()) do
		if p:IsA("BasePart") then add(p, tint, tintA or 0) end
	end
	-- интерфейс
	local gui = playerGui:FindFirstChild("KlinokBossIntro")
	local bars, name, title, quote, nameColor, titleColor, lineColor = false, "", "", "", "1,1,1", "1,1,1", "1,1,1"
	local flash = 1
	if gui then
		for _, g in ipairs(gui:GetDescendants()) do
			if g.ClassName == "Frame" and g.Size and g.Size.Y and g.Size.Y.Offset == 110 and g.Position.Y.Scale == 0 and g.Position.Y.Offset == 0 then bars = true end
			if g.ClassName == "Frame" and g.ZIndex == 5 then flash = g.BackgroundTransparency end
			if g.ClassName == "TextLabel" then
				if g.TextSize == 54 and g.ZIndex == 6 and g.TextTransparency < 0.5 then name = g.Text nameColor = colorStr(g.TextColor3) end
				if g.TextSize == 20 and g.TextTransparency < 0.5 then title = g.Text titleColor = colorStr(g.TextColor3) end
				if g.TextSize == 22 and g.TextTransparency < 0.5 then
					local n = g.MaxVisibleGraphemes
					local text = g.Text
					if n >= 0 then
						local cut = utf8.offset(text, n + 1)
						text = cut and text:sub(1, cut - 1) or text
					end
					quote = text
				end
			end
			if g.ClassName == "Frame" and g.Size and g.Size.Y and g.Size.Y.Offset == 6 and g.Size.X.Offset > 10 then lineColor = colorStr(g.BackgroundColor3) end
		end
	end
	REAL_PRINT("{" .. '"boss":' .. jstr(typeId) .. ',"tau":' .. num(tau) .. ',"cam":[' .. cfStr(cf) .. '],"fov":' .. num(fov) .. ',"B":[' .. num(rigs.B.X) .. "," .. num(rigs.B.Y) .. "," .. num(rigs.B.Z) .. '],"bars":' .. tostring(bars) .. ',"name":' .. jstr(name) .. ',"title":' .. jstr(title) .. ',"quote":' .. jstr(quote) .. ',"nameColor":[' .. nameColor .. '],"titleColor":[' .. titleColor .. '],"lineColor":[' .. lineColor .. '],"parts":[' .. table.concat(parts, ",") .. "]}")
end

local function humanoid(H, B)
	local m = Instance.new("Model")
	m.Name = "BossVisual"
	local s = H / 10
	local function part(name, pos, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.CFrame = CFrame.new(B + pos * s)
		p.Color = color
		p.Parent = m
		return p
	end
	local body = Color3.fromRGB(110, 100, 120)
	local dark = Color3.fromRGB(70, 64, 80)
	part("LeftFoot", Vector3.new(-1, 0.3, 0), Vector3.new(1.2, 0.6, 1.8), dark)
	part("RightFoot", Vector3.new(1, 0.3, 0), Vector3.new(1.2, 0.6, 1.8), dark)
	part("LeftLeg", Vector3.new(-1, 2.6, 0), Vector3.new(1.1, 4.0, 1.1), dark)
	part("RightLeg", Vector3.new(1, 2.6, 0), Vector3.new(1.1, 4.0, 1.1), dark)
	part("LowerTorso", Vector3.new(0, 4.9, 0), Vector3.new(3.0, 1.2, 1.6), dark)
	part("UpperTorso", Vector3.new(0, 6.6, 0), Vector3.new(3.8, 2.6, 1.9), body)
	part("LeftArm", Vector3.new(-2.5, 5.9, 0), Vector3.new(1.0, 3.8, 1.0), body)
	part("RightArm", Vector3.new(2.5, 5.9, 0), Vector3.new(1.0, 3.8, 1.0), body)
	part("HumanoidRootPart", Vector3.new(0, 5.0, 0), Vector3.new(0.1, 0.1, 0.1), body).Transparency = 1
	local head = part("Head", Vector3.new(0, 8.7, 0), Vector3.new(1.8, 1.8, 1.8), body)
	for _, x in ipairs({ -0.4, 0.4 }) do
		local eye = part("Eye", Vector3.new(x, 8.8, 0.92), Vector3.new(0.35, 0.2, 0.1), Color3.fromRGB(255, 220, 120))
		eye.Material = Enum.Material.Neon
	end
	m.Parent = workspace
	return m
end

local SAMPLES = { 0.4, 1.3, 2.3, 3.1, 3.7, 4.4, 5.0, 5.6, 6.2, 6.6, 7.0, 7.8 }
local only = SIM_ONLY
for _, typeId in ipairs({ "gatekeeper", "rosewarden", "royal_huntsman", "elder_founder", "chief_chronicler" }) do
	if only and only ~= typeId then continue end
	local cfg = BossIntros.get(typeId)
	local scene = Scenes.get(typeId)
	local B = Vector3.new(0, 0, 0)
	local server = Instance.new("Model")
	server.Name = typeId
	server:SetAttribute("EnemyState", "spawning")
	server:SetAttribute("EnemyStateAt", SIM.now)
	server.Parent = workspace
	local sceneStart = SIM.now
	local visual = humanoid(scene.H, B)
	-- взгляд босса +Z (к игроку): поворачиваем модель
	local rig = { model = visual, pos = B, facing = Vector3.new(0, 0, 1), fx = {}, server = server, stats = { height = scene.H } }
	rigs[server] = rig
	rigs.B = B
	local ch = makeCharacter(B + Vector3.new(0, 3, 22))
	local names = { gatekeeper = "Привратник", rosewarden = "Садовница", royal_huntsman = "Королевский ловчий", elder_founder = "Старший литейщик", chief_chronicler = "Главный хронист" }
	local titles = { gatekeeper = "Страж ворот Хранилища", rosewarden = "Хозяйка Затопленных садов", royal_huntsman = "Хозяин королевской охоты", elder_founder = "Хозяин Великого горна", chief_chronicler = "Тот, кто записал всё" }
	Bus.emit("bossIntro", { kind = "bossIntro", name = names[typeId], title = titles[typeId], duration = cfg.full, short = false, skip = 0, model = server, position = B + Vector3.new(0, 3, 0), typeId = typeId })
	local si = 1
	-- имитация сдвига модели (introOffset) по ходу сцены
	local base = {}
	for _, p in ipairs(visual:GetDescendants()) do if p:IsA("BasePart") then base[p] = p.CFrame end end
	while SIM.now - sceneStart < cfg.full + 0.1 do
		local cf, fov = stepFrame()
		local off = rig.introOffset or Vector3.zero
		for p, c in pairs(base) do p.CFrame = c + off end
		local tau = SIM.now - sceneStart
		if SAMPLES[si] and tau >= SAMPLES[si] and cf then
			dumpFrame(typeId, tau, cf, fov, visual)
			si += 1
		end
	end
	for _ = 1, 90 do stepFrame() end
	ch:Destroy()
	server:Destroy()
	visual:Destroy()
end
