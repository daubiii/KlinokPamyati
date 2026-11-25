--[[
  BuildIntroStage — строит всю сцену ролика из блоков и расставляет точки камеры.
  КАК ЗАПУСТИТЬ: Roblox Studio -> View -> Command Bar -> вставить весь файл -> Enter.
  Создаёт в Workspace: папки IntroStage (декорации) и IntroCam (точки камеры).
  Сцена строится далеко от карты (ORIGIN), игровую карту не трогает.
  Можно запускать повторно: старые IntroStage/IntroCam удаляются и строятся заново.
  Всё из кубов/параллелепипедов (Part Block) — других форм нет.
]]

local CHS = game:GetService("ChangeHistoryService")
local ORIGIN = Vector3.new(1500, 800, 1500)   -- можно сменить, если место занято
math.randomseed(42)

for _, n in ipairs({ "IntroStage", "IntroCam" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end

local function folder(name, parent)
	local f = Instance.new((name == "IntroStage" or name == "IntroCam") and "Model" or "Folder")
	f.Name = name
	if f:IsA("Model") then
		f.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	f.Parent = parent or workspace
	return f
end
local stage = folder("IntroStage")
local cam = folder("IntroCam")
local decor = folder("Decor", stage)
local bladesF = folder("Blades", stage)

local function W(x, y, z) return ORIGIN + Vector3.new(x, y, z) end
local rad = math.rad
local function rnd(a, b) return a + math.random() * (b - a) end
local madeParts = 0

local function mk(parent, name, size, cf, color, mat, tr)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	madeParts += 1
	if madeParts % 80 == 0 then
		task.wait()
	end
	return p
end
local function shade(c, k) return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1)) end
local function light(parent, color, brightness, range)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

local STONE = Color3.fromRGB(62, 64, 84)
local FLOOR = Color3.fromRGB(38, 40, 54)
local RUST = Color3.fromRGB(122, 68, 40)
local WOOD = Color3.fromRGB(80, 56, 40)
local CYAN = Color3.fromHex("6FE3FF")
local PALE = Color3.fromRGB(205, 242, 255)

-- каменный воксель с неровностями (края «крошатся»)
local function stone(parent, x, y, z, size)
	local s = size * rnd(0.86, 1.04)
	local cf = CFrame.new(W(x + rnd(-0.4, 0.4), y + rnd(-0.4, 0.4), z + rnd(-0.4, 0.4)))
		* CFrame.Angles(rad(rnd(-5, 5)), rad(rnd(-8, 8)), rad(rnd(-5, 5)))
	return mk(parent, "Stone", Vector3.new(s, s, s), cf, shade(STONE, rnd(0.72, 1.2)), Enum.Material.Concrete)
end

local function crystal(x, y, z, s)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	m.Parent = decor
	local a = mk(m, "C1", Vector3.new(s * 0.5, s * 1.5, s * 0.5), CFrame.new(W(x, y + s * 0.75, z)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-8, 8))), CYAN, Enum.Material.Neon, 0.05)
	mk(m, "C2", Vector3.new(s * 0.4, s * 0.95, s * 0.4), CFrame.new(W(x + s * 0.5, y + s * 0.45, z + s * 0.2)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-14, 14))), CYAN, Enum.Material.Neon, 0.1)
	mk(m, "C3", Vector3.new(s * 0.35, s * 0.7, s * 0.35), CFrame.new(W(x - s * 0.4, y + s * 0.35, z - s * 0.2)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-14, 14))), CYAN, Enum.Material.Neon, 0.1)
	-- как на референсе: прозрачная голубая оболочка + белое «горячее» ядро
	a.Transparency = 0.45
	mk(m, "Core", Vector3.new(s * 0.26, s * 1.55, s * 0.26), a.CFrame, Color3.fromRGB(235, 252, 255), Enum.Material.Neon, 0)
	light(a, CYAN, 3.2, 20)
end

local function rustHeap(x, z)
	local m = Instance.new("Model")
	m.Name = "RustArmor"
	m.Parent = decor
	local yaw = rad(rnd(0, 360))
	local base = CFrame.new(W(x, 0, z)) * CFrame.Angles(0, yaw, 0)
	mk(m, "Chest", Vector3.new(2.4, 1.6, 1.4), base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, rad(rnd(-12, 12))), RUST, Enum.Material.Metal)
	mk(m, "Helmet", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(2, 0.7, 0.6), shade(RUST, 0.85), Enum.Material.Metal)
	mk(m, "Visor", Vector3.new(1.1, 0.25, 0.1), base * CFrame.new(2, 0.8, 1.3), Color3.fromRGB(15, 15, 20))
	mk(m, "Shield", Vector3.new(1.8, 1.8, 0.3), base * CFrame.new(-2, 0.9, 0.4) * CFrame.Angles(rad(70), 0, 0), shade(RUST, 1.1), Enum.Material.Metal)
	mk(m, "Piece", Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0.8, 0.25, 1.8), RUST, Enum.Material.Metal)
end

local function deadTorch(x, y, z)
	mk(decor, "TorchStick", Vector3.new(0.5, 2.2, 0.5), CFrame.new(W(x, y, z)) * CFrame.Angles(0, 0, rad(x < 0 and -10 or 10)), WOOD, Enum.Material.Wood)
	mk(decor, "TorchTop", Vector3.new(0.9, 0.8, 0.9), CFrame.new(W(x + (x < 0 and 0.2 or -0.2), y + 1.4, z)), Color3.fromRGB(24, 22, 22), Enum.Material.Slate)
end

local function claws(x, y, z)
	local dir = x < 0 and 1 or -1
	for i = 0, 2 do
		mk(decor, "Claw", Vector3.new(0.12, 3, 0.25), CFrame.new(W(x + 0.05 * dir, y, z + i * 0.7)) * CFrame.Angles(rad(25), 0, 0), Color3.fromRGB(14, 14, 20))
	end
end

---------------------------------------------------------------- КОРИДОР
mk(decor, "CorridorFloor", Vector3.new(18, 1, 82), CFrame.new(W(0, -0.5, -30)), FLOOR, Enum.Material.Slate)
mk(decor, "CorridorRoof", Vector3.new(22, 1, 84), CFrame.new(W(0, 15.5, -30)), Color3.fromRGB(18, 16, 38))
for z = 8, -70, -4 do
	for _, side in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 2, 6, 10 }) do
			if math.random() > 0.05 then stone(decor, side * 9, y, z, 4) end
		end
	end
	for _, x in ipairs({ -6, -2, 2, 6 }) do
		if math.random() > 0.18 then stone(decor, x, 14, z, 4) end
	end
end
-- осыпавшиеся кубики на полу
for i = 1, 40 do
	local s = rnd(0.4, 1.1)
	mk(decor, "Rubble", Vector3.new(s, s, s), CFrame.new(W(rnd(-6.5, 6.5), s / 2, rnd(6, -66))) * CFrame.Angles(0, rad(rnd(0, 90)), 0), shade(STONE, rnd(0.7, 1)), Enum.Material.Concrete)
end
for _, z in ipairs({ -10, -26, -42, -58 }) do rustHeap((z % 8 == 0) and -4.5 or 4.5, z) end
for _, z in ipairs({ -6, -18, -30, -44, -56 }) do
	deadTorch(-6.6, 6, z)
	deadTorch(6.6, 6, z - 6)
end
claws(-6.9, 5, -14)
claws(6.9, 4, -34)
claws(-6.9, 6, -50)
crystal(-5.5, 0, -8, 1.6)
crystal(5.5, 0, -24, 1.3)
crystal(-5.8, 0, -40, 1.8)
crystal(5.4, 0, -54, 1.5)
crystal(-5.2, 0, -64, 2.0)

---------------------------------------------------------------- ЗАЛ
mk(decor, "HallFloor", Vector3.new(88, 1, 114), CFrame.new(W(0, -0.5, -127)), FLOOR, Enum.Material.Slate)
mk(decor, "HallRoof", Vector3.new(100, 1, 130), CFrame.new(W(0, 44, -125)), Color3.fromRGB(18, 16, 38))
for z = -72, -180, -6 do
	for y = 3, 39, 6 do
		for _, side in ipairs({ -1, 1 }) do
			if math.random() > 0.04 then stone(decor, side * 43, y, z, 6) end
		end
	end
end
for x = -42, 42, 6 do
	for y = 3, 39, 6 do
		stone(decor, x, y, -183, 6)
		if math.abs(x) >= 9 then stone(decor, x, y, -73, 6) end
	end
end
-- колонны
for _, p in ipairs({ { -30, -90 }, { 30, -90 }, { -30, -125 }, { 30, -125 }, { -30, -160 }, { 30, -160 } }) do
	for y = 2, 38, 4 do
		stone(decor, p[1], y, p[2], 4.4)
	end
end
for i = 1, 70 do
	local s = rnd(0.5, 1.6)
	mk(decor, "Rubble", Vector3.new(s, s, s), CFrame.new(W(rnd(-38, 38), s / 2, rnd(-76, -178))) * CFrame.Angles(0, rad(rnd(0, 90)), 0), shade(STONE, rnd(0.65, 1)), Enum.Material.Concrete)
end
for _, c in ipairs({ { -36, -80 }, { 36, -84 }, { -37, -140 }, { 37, -150 }, { -20, -172 }, { 22, -170 } }) do
	crystal(c[1], 0, c[2], rnd(2, 3))
end
rustHeap(-14, -100)
rustHeap(15, -98)

---------------------------------------------------------------- КУЗНЯ
local forge = folder("Forge", stage)
mk(forge, "Platform", Vector3.new(16, 1.2, 14), CFrame.new(W(0, 0.6, -124)), shade(STONE, 0.9), Enum.Material.Concrete)
mk(forge, "Platform2", Vector3.new(12, 0.8, 10), CFrame.new(W(0, 1.6, -124)), shade(STONE, 1.0), Enum.Material.Concrete)
-- наковальня из блоков
mk(forge, "AnvilBase", Vector3.new(3, 1.6, 2.2), CFrame.new(W(0, 2.8, -124)), Color3.fromRGB(46, 48, 58), Enum.Material.Metal)
mk(forge, "AnvilWaist", Vector3.new(1.6, 1.2, 1.4), CFrame.new(W(0, 4.2, -124)), Color3.fromRGB(52, 54, 64), Enum.Material.Metal)
mk(forge, "AnvilTop", Vector3.new(5.2, 1.2, 2), CFrame.new(W(0, 5.4, -124)), Color3.fromRGB(62, 64, 76), Enum.Material.Metal)
mk(forge, "AnvilHorn", Vector3.new(1.6, 0.7, 1.2), CFrame.new(W(3.2, 5.5, -124)), Color3.fromRGB(62, 64, 76), Enum.Material.Metal)
-- горн
mk(forge, "Furnace", Vector3.new(12, 9, 4), CFrame.new(W(0, 4.5, -133)), shade(STONE, 0.8), Enum.Material.Brick)
mk(forge, "Chimney", Vector3.new(3.4, 10, 3.4), CFrame.new(W(0, 14, -133)), shade(STONE, 0.7), Enum.Material.Brick)
local glow = mk(forge, "FurnaceGlow", Vector3.new(4.4, 3.2, 0.4), CFrame.new(W(0, 2.6, -130.9)), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
light(glow, Color3.fromRGB(255, 130, 60), 2.2, 22)
local ember = mk(stage, "ForgeEmber", Vector3.new(1, 1, 1), CFrame.new(W(0, 19.5, -133)), Color3.new(0, 0, 0), nil, 1)

-- пиксельное пламя в горне (слои красный/оранжевый/жёлтый, мерцает в катсцене)
local fire = folder("Fire", forge)
for _, fx in ipairs({ -1.6, -0.5, 0.6, 1.7 }) do
	mk(fire, "FlameRed", Vector3.new(0.9, 1.5, 0.5), CFrame.new(W(fx, 2.05, -130.4)), Color3.fromRGB(230, 60, 40), Enum.Material.Neon)
	mk(fire, "FlameOrange", Vector3.new(0.75, 1.1, 0.45), CFrame.new(W(fx, 3.35, -130.4)), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	mk(fire, "FlameYellow", Vector3.new(0.5, 0.8, 0.4), CFrame.new(W(fx, 4.3, -130.4)), Color3.fromRGB(255, 225, 90), Enum.Material.Neon)
end

-- световой столб памяти справа от входа в зал: виден с самого первого кадра в конце коридора
local beamF = folder("SoulBeam", stage)
mk(beamF, "BeamShell", Vector3.new(3.4, 44, 3.4), CFrame.new(W(7, 22, -88)), CYAN, Enum.Material.Neon, 0.78)
mk(beamF, "BeamCore", Vector3.new(1.2, 44, 1.2), CFrame.new(W(7, 22, -88)), Color3.fromRGB(235, 252, 255), Enum.Material.Neon, 0.3)
local beamLightSrc = mk(beamF, "BeamLightSrc", Vector3.new(1, 1, 1), CFrame.new(W(7, 3, -88)), Color3.new(0, 0, 0), nil, 1)
light(beamLightSrc, CYAN, 4, 30)
for i = 0, 11 do
	local a = i / 12 * math.pi * 2
	mk(beamF, "PadCube", Vector3.new(1.1, 0.35, 1.1), CFrame.new(W(7 + math.cos(a) * 4, 0.2, -88 + math.sin(a) * 4)) * CFrame.Angles(0, a, 0), CYAN, Enum.Material.Neon, 0.1)
end
mk(beamF, "PadFloor", Vector3.new(7.5, 0.25, 7.5), CFrame.new(W(7, 0.12, -88)), Color3.fromRGB(70, 190, 235), Enum.Material.Neon, 0.55)
mk(stage, "BeamBase", Vector3.new(1, 1, 1), CFrame.new(W(7, 0.8, -88)), Color3.new(0, 0, 0), nil, 1)

---------------------------------------------------------------- ЛЮДИ-СИЛУЭТЫ И КЛИНКИ
local function human(parent, cf, s, d)
	local m = Instance.new("Model")
	m.Name = "Silhouette"
	m.Parent = parent
	local function p(name, size, off, rot, tr)
		local r = math.random()
		local col = (r < 0.22) and Color3.new(1, 1, 1) or ((r < 0.45) and Color3.fromRGB(70, 190, 235) or PALE)
		return mk(m, name, size * s, cf * CFrame.new(off * s) * (rot or CFrame.new()), col, Enum.Material.Neon, tr or 0.3)
	end
	p("LegL", Vector3.new(0.5, 1.6, 0.5), Vector3.new(-0.3, 0.8, 0))
	p("LegR", Vector3.new(0.5, 1.6, 0.5), Vector3.new(0.3, 0.8, 0))
	p("Torso", Vector3.new(1.1, 1.6, 0.6), Vector3.new(0, 2.4, 0))
	p("ArmL", Vector3.new(0.4, 1.5, 0.4), Vector3.new(-0.85, 2.4, 0))
	p("ArmR", Vector3.new(0.4, 1.5, 0.4), Vector3.new(0.85, 2.4, 0))
	if d == 0 then
		p("Head", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 3.65, 0))
	elseif d == 1 then
		p("Head", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0.3, 3.7, 0), CFrame.Angles(0, 0, rad(22)))
	elseif d == 2 then
		p("Head", Vector3.new(1.3, 1.1, 1.1), Vector3.new(0, 3.8, 0), CFrame.Angles(0, 0, rad(-10)))
		p("ArmL2", Vector3.new(0.35, 1.4, 0.35), Vector3.new(-1.3, 2.0, 0.2), CFrame.Angles(0, 0, rad(25)))
		p("ArmR2", Vector3.new(0.35, 1.4, 0.35), Vector3.new(1.3, 2.0, -0.2), CFrame.Angles(0, 0, rad(-25)))
		p("TorsoStretch", Vector3.new(0.9, 1.2, 0.5), Vector3.new(0, 3.3, 0))
	else
		for i = 1, 14 do
			local sz = rnd(0.3, 0.9)
			p("Chaos" .. i, Vector3.new(sz, sz * rnd(1, 2.2), sz), Vector3.new(rnd(-1.2, 1.2), rnd(0.4, 4.3), rnd(-0.5, 0.5)), CFrame.Angles(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)))
		end
		p("Head1", Vector3.new(0.8, 0.8, 0.8), Vector3.new(-0.5, 3.8, 0))
		p("Head2", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.6, 4.0, 0))
	end
	-- россыпь кубиков вокруг силуэта: он расплывается, как дух на референсе «Ковка удалась»
	local n = (d >= 3) and 22 or (d == 2 and 14 or (d == 1 and 9 or 5))
	for i = 1, n do
		local sz = rnd(0.12, 0.4) * s
		local col = (math.random() < 0.3) and Color3.new(1, 1, 1) or CYAN
		mk(m, "Dust" .. i, Vector3.new(sz, sz, sz),
			cf * CFrame.new(rnd(-1.4, 1.4) * s, rnd(0, 4.6) * s, rnd(-0.8, 0.8) * s) * CFrame.Angles(rnd(0, 3), rnd(0, 3), 0),
			col, Enum.Material.Neon, 0.1)
	end
	return m
end

local function glassBlade(name, cf, len, d, brightness)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = bladesF
	local body = mk(m, "Body", Vector3.new(1.6, len, 0.45), cf, CYAN, Enum.Material.Neon, 0.55)
	local h = len / 2
	mk(m, "Tip1", Vector3.new(1.0, 0.8, 0.4), cf * CFrame.new(0, -(h + 0.4), 0), CYAN, Enum.Material.Neon, 0.55)
	mk(m, "Tip2", Vector3.new(0.5, 0.7, 0.35), cf * CFrame.new(0, -(h + 1.1), 0), CYAN, Enum.Material.Neon, 0.55)
	mk(m, "Guard", Vector3.new(3.0, 0.5, 0.9), cf * CFrame.new(0, h + 0.25, 0), Color3.fromRGB(50, 52, 66), Enum.Material.Metal)
	mk(m, "Handle", Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(0, h + 1.3, 0), WOOD, Enum.Material.Wood)
	mk(m, "Pommel", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, h + 2.3, 0), Color3.fromRGB(50, 52, 66), Enum.Material.Metal)
	human(m, cf * CFrame.new(0, -len * 0.3, 0), len / 9, d)
	local l = light(body, CYAN, brightness or 1.6, 16)
	l.Name = "Light"
	m.PrimaryPart = body
	m:SetAttribute("BaseCF", m:GetPivot())
	m:SetAttribute("Phase", rnd(0, 6.28))
	return m
end

-- кольцо парящих клинков над наковальней
local d_pattern = { 0, 1, 0, 2, 0, 3, 1, 0 }
local idx = 0
for i = 1, 18 do
	local ang = i / 18 * math.pi * 2
	local r = 13 + (i % 3) * 3.5
	local x, z = math.cos(ang) * r * 1.3, -122 + math.sin(ang) * r
	if z < -113 then
		idx += 1
		local y = 8 + (i % 4) * 3
		local cf = CFrame.new(W(x, y, z)) * CFrame.Angles(rad(rnd(-6, 6)), rad(rnd(0, 360)), rad(rnd(-6, 6)))
		glassBlade("Blade" .. i, cf, 8 + (i % 3), d_pattern[(idx - 1) % #d_pattern + 1], 1.4)
	end
end
-- обречённый клинок (шот 4): силуэт гаснет и рассыпается
local doomed = glassBlade("DoomedBlade", CFrame.new(W(1.5, 6, -108)), 6, 0, 3.5)
doomed:SetAttribute("BaseCF", doomed:GetPivot())

---------------------------------------------------------------- ПУСТОЙ КЛИНОК
local FLOOR_CF = CFrame.new(W(4, 0.55, -108)) * CFrame.Angles(0, 0, rad(90))
local blade = Instance.new("Model")
blade.Name = "EmptyBlade"
blade.Parent = stage
do
	local cf = FLOOR_CF
	local handle = mk(blade, "Handle", Vector3.new(0.45, 1.3, 0.45), cf, WOOD, Enum.Material.Wood)
	mk(blade, "Pommel", Vector3.new(0.7, 0.5, 0.7), cf * CFrame.new(0, -0.9, 0), Color3.fromRGB(70, 66, 66), Enum.Material.Metal)
	mk(blade, "Guard", Vector3.new(2.0, 0.4, 0.8), cf * CFrame.new(0, 0.85, 0), Color3.fromRGB(80, 74, 72), Enum.Material.Metal)
	local b = mk(blade, "Blade", Vector3.new(0.8, 4.0, 0.32), cf * CFrame.new(0, 3.05, 0), Color3.fromRGB(104, 98, 96), Enum.Material.Metal)
	mk(blade, "Tip", Vector3.new(0.5, 0.5, 0.28), cf * CFrame.new(0, 5.3, 0), Color3.fromRGB(104, 98, 96), Enum.Material.Metal)
	for i = 1, 6 do
		mk(blade, "Rust", Vector3.new(0.3, 0.3, 0.36), cf * CFrame.new(rnd(-0.25, 0.25), rnd(1.3, 4.8), 0), RUST, Enum.Material.Metal)
	end
	local g = mk(blade, "BladeGlow", Vector3.new(0.18, 3.4, 0.36), cf * CFrame.new(0, 3.0, 0), CYAN, Enum.Material.Neon, 1)
	local l = light(g, CYAN, 0, 20)
	l.Name = "BladeLight"
	blade.PrimaryPart = handle
end

---------------------------------------------------------------- ГЕРОЙ (Пробуждённый), на коленях, лицо пустое
local hero = Instance.new("Model")
hero.Name = "Hero"
hero.Parent = stage
do
	local SKIN = Color3.fromRGB(190, 196, 212)
	local CLOTH = Color3.fromRGB(44, 47, 66)
	local function hp(name, size, cf, color, mat, t0)
		local p = mk(hero, name, size, cf, color, mat or Enum.Material.SmoothPlastic, 1)
		p:SetAttribute("T0", t0 or 0)
		return p
	end
	hp("LowerLegL", Vector3.new(1.1, 1, 2.4), CFrame.new(W(3.2, 0.5, -112)), CLOTH)
	hp("LowerLegR", Vector3.new(1.1, 1, 2.4), CFrame.new(W(4.8, 0.5, -112)), CLOTH)
	hp("ThighL", Vector3.new(1.1, 2.2, 1.2), CFrame.new(W(3.2, 1.8, -111)), CLOTH)
	hp("ThighR", Vector3.new(1.1, 2.2, 1.2), CFrame.new(W(4.8, 1.8, -111)), CLOTH)
	hp("Torso", Vector3.new(2.4, 3, 1.4), CFrame.new(W(4, 4.2, -110.6)) * CFrame.Angles(rad(12), 0, 0), CLOTH)
	hp("ArmL", Vector3.new(0.9, 2.6, 0.9), CFrame.new(W(2.6, 3.5, -110)), CLOTH)
	hp("Head", Vector3.new(1.8, 1.8, 1.8), CFrame.new(W(4, 6.3, -109.9)), SKIN)
	hp("Hair", Vector3.new(1.9, 0.5, 1.9), CFrame.new(W(4, 7.35, -110)), Color3.fromRGB(26, 26, 36))
	hp("EyeL", Vector3.new(0.35, 0.35, 0.12), CFrame.new(W(3.5, 6.45, -108.95)), Color3.new(1, 1, 1), Enum.Material.Neon, 1)
	hp("EyeR", Vector3.new(0.35, 0.35, 0.12), CFrame.new(W(4.5, 6.45, -108.95)), Color3.new(1, 1, 1), Enum.Material.Neon, 1)
	hp("ShoulderPoint", Vector3.new(0.5, 0.5, 0.5), CFrame.new(W(5.5, 5.0, -110.4)), CLOTH, nil, 1)
	hp("HeroArm", Vector3.new(0.8, 0.8, 3), CFrame.new(W(5, 3, -109)), CLOTH)
	hp("HeroFist", Vector3.new(1, 1, 1), CFrame.new(W(4, 0.55, -108)), SKIN)
end

---------------------------------------------------------------- ТОЧКИ КАМЕРЫ
local function shot(name, pos, target)
	local p = mk(cam, name, Vector3.new(1, 1, 2), CFrame.lookAt(W(pos[1], pos[2], pos[3]), W(target[1], target[2], target[3])), Color3.new(1, 0, 1), nil, 1)
	return p
end
local function marker(name, cf)
	return mk(cam, name, Vector3.new(1, 1, 1), cf, Color3.new(0, 1, 1), nil, 1)
end

shot("Shot1", { 0, 3.5, 4 }, { 0, 3, -60 })
shot("Shot2A", { 0, 3.5, 4 }, { 0, 3, -60 })
shot("Shot2B", { 0, 3.5, -64 }, { 0, 6, -100 })
shot("Shot3A", { 0, 3.5, -64 }, { 0, 8, -110 })
shot("Shot3B", { -8, 9, -98 }, { -2, 8, -112 })
shot("Shot4A", { -8, 9, -98 }, { 1.5, 6, -108 })
shot("Shot4B", { 1.5, 3.5, -96 }, { 1.5, 4.5, -108 })
shot("Shot5A", { 6.5, 1.2, -104 }, { 4, 0.9, -108 })
shot("Shot5B", { 4.8, 6.4, -104.5 }, { 4, 6.4, -110 })
shot("Shot6A", { 4, 6.5, -103 }, { 4, 6.4, -108 })
shot("Shot6B", { 4, 7, -90 }, { 4, 6.4, -108 })

marker("BladeFloor", FLOOR_CF)
marker("BladeRaised", CFrame.new(W(5.6, 3.6, -108.2)) * CFrame.Angles(0, 0, rad(-6)))
marker("BladeCenter", CFrame.new(W(4, 4.3, -107.5)))
marker("AbsorbTarget", CFrame.new(W(4, 0.8, -108)))
marker("CrumbleSource", CFrame.new(W(1.5, 6, -108)))

CHS:SetWaypoint("BuildIntroStage")
print(("[BuildIntroStage] готово: %d деталей. Сцена в точке %s."):format(#stage:GetDescendants() + #cam:GetChildren(), tostring(ORIGIN)))
