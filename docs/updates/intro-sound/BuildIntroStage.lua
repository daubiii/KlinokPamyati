--[[
  BuildIntroStage v3 — строит сцену ролика из блоков и расставляет точки камеры.

  КАК ЗАПУСТИТЬ: Roblox Studio -> View -> Command Bar -> вставить весь файл -> Enter.
  Создаёт папки IntroStage (декорации) и IntroCam (точки камеры).
  Сцена строится далеко от карты (ORIGIN), игровую карту не трогает.
  Можно запускать повторно: старые IntroStage/IntroCam удаляются.

  ВСЁ из плоских блоков SmoothPlastic и Neon. Текстурные материалы
  (Brick, Concrete, Slate, Metal, Wood и т.д.) НЕ используются, mk() их запрещает.

  STORE_IN_REPLICATED = true: сцена лежит в ReplicatedStorage, катсцена клонирует её
  в Workspace только на время ролика (для игры с StreamingEnabled и чтобы не
  гонять сцену всем игрокам). Для записи ролика оставьте false.
]]

local CHS = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---------------------------------------------------------------- НАСТРОЙКИ
local ORIGIN = Vector3.new(1500, 800, 1500)   -- можно сменить, если место занято
-- true: сцена лежит в ReplicatedStorage и катсцена клонирует её локально —
-- так ролик виден при включённом StreamingEnabled, где бы игрок ни был.
local STORE_IN_REPLICATED = true
math.randomseed(42)
-- 1 ≈ 130k треугольников, 2 ≈ 350k (по умолчанию), 3 ≈ 800k. Для слабых ПК/мобильных берите 1.
local QUALITY = 2
local MQ = ({ 1, 12, 28 })[QUALITY]

local rad = math.rad
local HOME = STORE_IN_REPLICATED and ReplicatedStorage or workspace

for _, n in ipairs({ "IntroStage", "IntroCam" }) do
	for _, root in ipairs({ workspace, ReplicatedStorage }) do
		local o = root:FindFirstChild(n)
		if o then o:Destroy() end
	end
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or HOME
	return f
end
-- Корни сцены — Model с Persistent: при StreamingEnabled дальние от персонажа детали
-- выгружаются из клиента, и катсцена оставалась бы слепой (чёрный экран).
-- Persistent держит сцену на клиенте целиком всё время ролика.
local function rootContainer(name)
	local m = Instance.new("Model")
	m.Name = name
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	m.Parent = HOME
	return m
end
local stage = rootContainer("IntroStage")
local cam = rootContainer("IntroCam")
local decor = folder("Decor", stage)
local bladesF = folder("Blades", stage)

local function W(x, y, z) return ORIGIN + Vector3.new(x, y, z) end
local function rnd(a, b) return a + math.random() * (b - a) end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

-- Единственные два материала в сцене: плоский и светящийся.
local FLAT = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local function mk(parent, name, size, cf, color, glow, tr)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = glow and NEON or FLAT
	p.Reflectance = 0
	p.CastShadow = not glow
	p.Transparency = tr or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function neon(parent, name, size, cf, color, tr)
	return mk(parent, name, size, cf, color, true, tr)
end
local function shade(c, k)
	return Color3.new(clamp(c.R * k, 0, 1), clamp(c.G * k, 0, 1), clamp(c.B * k, 0, 1))
end
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
local FLOOR = Color3.fromRGB(44, 46, 62)
local RUST = Color3.fromRGB(122, 68, 40)
local WOOD = Color3.fromRGB(96, 66, 46)
local IRON = Color3.fromRGB(58, 60, 74)
local CYAN = Color3.fromHex("6FE3FF")
local PALE = Color3.fromRGB(205, 242, 255)
local WHITE = Color3.fromRGB(235, 252, 255)
local EMBER = Color3.fromRGB(255, 120, 40)

-- каменный воксель с неровностями (края «крошатся»)
local function stone(parent, x, y, z, size)
	local s = size * rnd(0.86, 1.04)
	local cf = CFrame.new(W(x + rnd(-0.4, 0.4), y + rnd(-0.4, 0.4), z + rnd(-0.4, 0.4)))
		* CFrame.Angles(rad(rnd(-5, 5)), rad(rnd(-8, 8)), rad(rnd(-5, 5)))
	return mk(parent, "Stone", Vector3.new(s, s, s), cf, shade(STONE, rnd(0.72, 1.2)))
end

-- плиты-«пиксели» пола/платформ: каждая плита чуть другого оттенка, между ними тёмные швы
local function slabTiles(parent, x0, x1, z0, z1, y0, y1, tile, base)
	local h = y1 - y0
	mk(parent, "Underlay", Vector3.new(x1 - x0, h * 0.5, z1 - z0),
		CFrame.new(W((x0 + x1) / 2, y0 + h * 0.25, (z0 + z1) / 2)), shade(base, 0.35))
	local nx = math.ceil((x1 - x0) / tile - 0.001)
	local nz = math.ceil((z1 - z0) / tile - 0.001)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local tx0 = x0 + i * tile
			local tz0 = z0 + j * tile
			local w = math.min(tile, x1 - tx0)
			local d = math.min(tile, z1 - tz0)
			local th = h - rnd(0, 0.07)
			mk(parent, "Tile", Vector3.new(w - 0.12, th, d - 0.12),
				CFrame.new(W(tx0 + w / 2, y0 + th / 2, tz0 + d / 2)), shade(base, rnd(0.82, 1.2)))
		end
	end
end

local function crystal(x, y, z, s)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	m.Parent = decor
	local a = neon(m, "C1", Vector3.new(s * 0.5, s * 1.5, s * 0.5), CFrame.new(W(x, y + s * 0.75, z)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-8, 8))), CYAN, 0.45)
	neon(m, "C2", Vector3.new(s * 0.4, s * 0.95, s * 0.4), CFrame.new(W(x + s * 0.5, y + s * 0.45, z + s * 0.2)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-14, 14))), CYAN, 0.1)
	neon(m, "C3", Vector3.new(s * 0.35, s * 0.7, s * 0.35), CFrame.new(W(x - s * 0.4, y + s * 0.35, z - s * 0.2)) * CFrame.Angles(0, rad(rnd(0, 90)), rad(rnd(-14, 14))), CYAN, 0.1)
	-- как на референсе: прозрачная голубая оболочка + белое «горячее» ядро
	neon(m, "Core", Vector3.new(s * 0.26, s * 1.55, s * 0.26), a.CFrame, WHITE, 0)
	light(a, CYAN, 3.2, 20)
end

local function rustHeap(x, z)
	local m = Instance.new("Model")
	m.Name = "RustArmor"
	m.Parent = decor
	local yaw = rad(rnd(0, 360))
	local base = CFrame.new(W(x, 0, z)) * CFrame.Angles(0, yaw, 0)
	mk(m, "Chest", Vector3.new(2.4, 1.6, 1.4), base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, rad(rnd(-12, 12))), RUST)
	mk(m, "Helmet", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(2, 0.7, 0.6), shade(RUST, 0.85))
	mk(m, "Visor", Vector3.new(1.1, 0.25, 0.1), base * CFrame.new(2, 0.8, 1.3), Color3.fromRGB(15, 15, 20))
	mk(m, "Shield", Vector3.new(1.8, 1.8, 0.3), base * CFrame.new(-2, 0.9, 0.4) * CFrame.Angles(rad(70), 0, 0), shade(RUST, 1.1))
	mk(m, "Piece", Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0.8, 0.25, 1.8), RUST)
end

local function deadTorch(x, y, z)
	mk(decor, "TorchStick", Vector3.new(0.5, 2.2, 0.5), CFrame.new(W(x, y, z)) * CFrame.Angles(0, 0, rad(x < 0 and -10 or 10)), WOOD)
	mk(decor, "TorchTop", Vector3.new(0.9, 0.8, 0.9), CFrame.new(W(x + (x < 0 and 0.2 or -0.2), y + 1.4, z)), Color3.fromRGB(24, 22, 22))
end

local function claws(x, y, z)
	local dir = x < 0 and 1 or -1
	for i = 0, 2 do
		mk(decor, "Claw", Vector3.new(0.12, 3, 0.25), CFrame.new(W(x + 0.05 * dir, y, z + i * 0.7)) * CFrame.Angles(rad(25), 0, 0), Color3.fromRGB(14, 14, 20))
	end
end

---------------------------------------------------------------- КОРИДОР
slabTiles(decor, -9, 9, -72, 11, -1, 0, 6, FLOOR)
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
	mk(decor, "Rubble", Vector3.new(s, s, s), CFrame.new(W(rnd(-6.5, 6.5), s / 2, rnd(6, -66))) * CFrame.Angles(0, rad(rnd(0, 90)), 0), shade(STONE, rnd(0.7, 1)))
end
for i, z in ipairs({ -10, -26, -42, -58 }) do
	rustHeap((i % 2 == 0) and -4.5 or 4.5, z)   -- слева и справа по очереди
end
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
slabTiles(decor, -44, 44, -184, -70, -1, 0, 8, FLOOR)
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
	mk(decor, "Rubble", Vector3.new(s, s, s), CFrame.new(W(rnd(-38, 38), s / 2, rnd(-76, -178))) * CFrame.Angles(0, rad(rnd(0, 90)), 0), shade(STONE, rnd(0.65, 1)))
end
for _, c in ipairs({ { -36, -80 }, { 36, -84 }, { -37, -140 }, { 37, -150 }, { -20, -172 }, { 22, -170 } }) do
	crystal(c[1], 0, c[2], rnd(2, 3))
end
rustHeap(-14, -100)
rustHeap(15, -98)

---------------------------------------------------------------- КУЗНЯ
local forge = folder("Forge", stage)

-- платформа с наковальней (ступени из плит)
slabTiles(forge, -8, 8, -129, -115, 0, 1.2, 4, shade(STONE, 0.9))
slabTiles(forge, -6, 6, -127, -117, 1.2, 2.0, 4, shade(STONE, 1.0))
---------------------------------------------------------------- ПОМОЩНИКИ ДЛЯ ДЕТАЛЕЙ
local STEEL = Color3.fromRGB(86, 90, 108)
local DARKMETAL = Color3.fromRGB(34, 36, 48)

-- бочка: 8 досок в 3 яруса (с «пузом»), три железных обруча, крышка
local function barrel(parent, x, z, scale, y0, rotY)
	scale = scale or 1
	y0 = y0 or 0
	local base = CFrame.new(W(x, y0, z)) * CFrame.Angles(0, rad(rotY or 0), 0)
	local R, H, n = 1.0 * scale, 2.4 * scale, 8
	local radii = { 0.9, 1.0, 0.9 }
	local wood = Color3.fromRGB(104, 72, 50)
	for tier = 1, 3 do
		local rr = R * radii[tier]
		local tw = 2 * rr * math.tan(math.pi / n) * 1.04
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2
			mk(parent, "Stave", Vector3.new(0.2 * scale, H / 3 - 0.02, tw),
				base * CFrame.new(math.cos(a) * rr, (tier - 0.5) * H / 3, math.sin(a) * rr) * CFrame.Angles(0, -a, 0),
				shade(wood, rnd(0.75, 1.15)))
		end
	end
	for _, hy in ipairs({ 0.15, 0.5, 0.85 }) do
		local rr = R * (hy == 0.5 and 1.0 or 0.92) + 0.12 * scale
		local tw = 2 * rr * math.tan(math.pi / n) * 1.06
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * math.pi * 2
			mk(parent, "Hoop", Vector3.new(0.12 * scale, 0.14 * scale, tw),
				base * CFrame.new(math.cos(a) * rr, hy * H, math.sin(a) * rr) * CFrame.Angles(0, -a, 0), DARKMETAL)
		end
	end
	mk(parent, "Lid1", Vector3.new(1.55 * scale, 0.12 * scale, 1.55 * scale), base * CFrame.new(0, H, 0), shade(wood, 0.9))
	mk(parent, "Lid2", Vector3.new(1.55 * scale, 0.12 * scale, 1.55 * scale), base * CFrame.new(0, H, 0) * CFrame.Angles(0, rad(45), 0), shade(wood, 1.0))
end

-- ящик: доски по граням, угловые стойки, железные уголки
local function crate(parent, x, z, s, y0, rotY)
	y0 = y0 or 0
	local base = CFrame.new(W(x, y0, z)) * CFrame.Angles(0, rad(rotY or 0), 0)
	local wood = Color3.fromRGB(98, 70, 50)
	local h = s / 3
	for i = 0, 2 do
		local y = (i + 0.5) * h
		local col = shade(wood, rnd(0.8, 1.1))
		mk(parent, "Plank", Vector3.new(s, h - 0.05, 0.14), base * CFrame.new(0, y, s / 2), col)
		mk(parent, "Plank", Vector3.new(s, h - 0.05, 0.14), base * CFrame.new(0, y, -s / 2), col)
		mk(parent, "Plank", Vector3.new(0.14, h - 0.05, s), base * CFrame.new(s / 2, y, 0), col)
		mk(parent, "Plank", Vector3.new(0.14, h - 0.05, s), base * CFrame.new(-s / 2, y, 0), col)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk(parent, "Post", Vector3.new(0.22, s, 0.22), base * CFrame.new(sx * s / 2, s / 2, sz * s / 2), shade(wood, 0.7))
			mk(parent, "Stud", Vector3.new(0.3, 0.3, 0.3), base * CFrame.new(sx * s / 2, s - 0.1, sz * s / 2), STEEL)
		end
	end
	mk(parent, "Lid", Vector3.new(s + 0.05, 0.12, s + 0.05), base * CFrame.new(0, s, 0), shade(wood, 0.95))
end

-- цепь: звенья чередуются плоскостями
local function chain(parent, x, z, yTop, yBottom)
	local y, i = yTop, 0
	while y > yBottom do
		local rot = (i % 2 == 0) and 0 or 90
		local cf = CFrame.new(W(x, y, z)) * CFrame.Angles(0, rad(rot), 0)
		mk(parent, "Link", Vector3.new(0.12, 0.62, 0.34), cf, DARKMETAL)
		mk(parent, "LinkBar", Vector3.new(0.12, 0.14, 0.34), cf * CFrame.new(0, 0.22, 0), STEEL)
		y = y - 0.42
		i = i + 1
	end
	return y
end

-- подвесной фонарь с голубым огнём
local function lantern(parent, x, y, z, withLight)
	local cf = CFrame.new(W(x, y, z))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk(parent, "LanternPost", Vector3.new(0.1, 1.1, 0.1), cf * CFrame.new(sx * 0.4, 0, sz * 0.4), DARKMETAL)
		end
	end
	mk(parent, "LanternTop", Vector3.new(1.1, 0.16, 1.1), cf * CFrame.new(0, 0.62, 0), DARKMETAL)
	mk(parent, "LanternTop2", Vector3.new(0.6, 0.2, 0.6), cf * CFrame.new(0, 0.8, 0), STEEL)
	mk(parent, "LanternBottom", Vector3.new(1.0, 0.14, 1.0), cf * CFrame.new(0, -0.6, 0), DARKMETAL)
	local core_ = neon(parent, "LanternCore", Vector3.new(0.55, 0.7, 0.55), cf, CYAN, 0.1)
	neon(parent, "LanternHeart", Vector3.new(0.25, 0.35, 0.25), cf, WHITE)
	if withLight then light(core_, CYAN, 2.2, 22) end
end

-- знамя на штанге: полотно из блоков с рваным низом и голубым мечом
local function banner(parent, cx, yTop, cz)
	local cloth = Color3.fromRGB(46, 36, 92)
	mk(parent, "BannerRod", Vector3.new(4.0, 0.22, 0.22), CFrame.new(W(cx, yTop + 0.3, cz)), WOOD)
	for _, sx in ipairs({ -1, 1 }) do
		mk(parent, "BannerBracket", Vector3.new(0.2, 0.2, 0.8), CFrame.new(W(cx + sx * 1.9, yTop + 0.3, cz - 0.4)), DARKMETAL)
	end
	local rows = 14
	for r = 1, rows do
		for c = -1, 1 do
			local torn = r > rows - 4 and math.random() < (r - (rows - 4)) * 0.22
			if not torn then
				local y = yTop - (r - 0.5) * 0.5
				local isBlade = (c == 0 and r >= 3 and r <= 11) or (r == 5 and true)
				local col = shade(cloth, rnd(0.8, 1.15))
				if isBlade then
					neon(parent, "BannerSword", Vector3.new(c == 0 and 0.5 or 0.9, 0.46, 0.12), CFrame.new(W(cx + c * 1.0, y, cz)), c == 0 and CYAN or PALE, 0.15)
				else
					mk(parent, "BannerCloth", Vector3.new(0.96, 0.46, 0.12 + rnd(0, 0.04)), CFrame.new(W(cx + c * 1.0, y, cz + rnd(-0.04, 0.04))), col)
				end
			end
		end
	end
end

local function rack(parent, rx, rz, kind)
	mk(parent, "PostA", Vector3.new(0.4, 4.4, 0.4), CFrame.new(W(rx - 1.9, 2.2, rz)), WOOD)
	mk(parent, "PostB", Vector3.new(0.4, 4.4, 0.4), CFrame.new(W(rx + 1.9, 2.2, rz)), WOOD)
	mk(parent, "Bar", Vector3.new(4.4, 0.4, 0.4), CFrame.new(W(rx, 4.0, rz)), WOOD)
	mk(parent, "BarLow", Vector3.new(4.4, 0.3, 0.3), CFrame.new(W(rx, 1.2, rz)), WOOD)
	for i = -1, 1 do
		local hx = rx + i * 1.2
		if kind == "hammer" then
			mk(parent, "HammerHandle", Vector3.new(0.3, 1.8, 0.3), CFrame.new(W(hx, 2.9, rz + 0.4)), WOOD)
			mk(parent, "HammerHead", Vector3.new(0.95, 0.6, 0.6), CFrame.new(W(hx, 1.85, rz + 0.4)), IRON)
		else
			mk(parent, "SwordBlade", Vector3.new(0.22, 2.6, 0.08), CFrame.new(W(hx, 2.5, rz + 0.35)), STEEL)
			mk(parent, "SwordTip", Vector3.new(0.14, 0.4, 0.08), CFrame.new(W(hx, 3.95, rz + 0.35)), STEEL)
			mk(parent, "SwordGuard", Vector3.new(0.8, 0.14, 0.2), CFrame.new(W(hx, 1.15, rz + 0.35)), IRON)
			mk(parent, "SwordGrip", Vector3.new(0.18, 0.7, 0.18), CFrame.new(W(hx, 0.78, rz + 0.35)), WOOD)
		end
	end
end

---------------------------------------------------------------- НАКОВАЛЬНЯ
local ANVIL_Z = -122
local anvilF = folder("Anvil", forge)
do
	local function ab(name, sx, sy, sz, x, y, z, color, rotY, parent)
		return mk(parent or anvilF, name, Vector3.new(sx, sy, sz),
			CFrame.new(W(x, y, ANVIL_Z + z)) * CFrame.Angles(0, rad(rotY or 0), 0), color)
	end
	ab("Plinth", 3.6, 0.5, 2.5, 0, 2.25, 0, shade(IRON, 0.7))
	ab("Foot", 0.8, 0.3, 0.8, -1.5, 2.15, -1.0, shade(IRON, 0.6)); ab("Foot", 0.8, 0.3, 0.8, 1.5, 2.15, 1.0, shade(IRON, 0.6))
	ab("WaistLow", 2.7, 0.8, 1.9, 0, 2.9, 0, shade(IRON, 0.85))
	ab("Waist", 1.8, 1.2, 1.4, 0, 3.9, 0, IRON)
	ab("WaistFlare", 2.7, 0.5, 1.9, 0, 4.75, 0, shade(IRON, 0.95))
	ab("AnvilTop", 5.0, 1.0, 2.0, 0, 5.5, 0, shade(IRON, 1.05), 0, forge)
	ab("FacePlate", 3.4, 0.12, 1.9, -0.2, 6.06, 0, STEEL)
	ab("Horn1", 1.6, 0.8, 1.5, 3.3, 5.55, 0, IRON)
	ab("Horn2", 1.2, 0.6, 1.1, 4.3, 5.45, 0, shade(IRON, 1.05))
	ab("Horn3", 0.8, 0.45, 0.8, 5.1, 5.4, 0, shade(IRON, 1.1))
	ab("Horn4", 0.5, 0.3, 0.5, 5.7, 5.35, 0, shade(IRON, 1.15))
	ab("Heel1", 1.2, 0.7, 1.8, -3.0, 5.35, 0, IRON)
	ab("Heel2", 0.7, 0.5, 1.6, -3.7, 5.25, 0, shade(IRON, 0.9))
	ab("Hardy", 0.35, 0.14, 0.35, -1.5, 6.14, 0.3, Color3.fromRGB(10, 10, 14))
	ab("Pritchel", 0.2, 0.14, 0.2, -0.9, 6.14, -0.4, Color3.fromRGB(10, 10, 14))
	for i = 1, 8 do
		ab("Chip", rnd(0.1, 0.25), rnd(0.08, 0.2), rnd(0.1, 0.25), rnd(-2.4, 2.4), 6.1, rnd(-0.95, 0.95), shade(STEEL, rnd(0.7, 1.2)), rnd(0, 90))
	end
	-- раскалённая заготовка
	local hot = neon(anvilF, "HotIron", Vector3.new(2.2, 0.2, 0.5), CFrame.new(W(-0.6, 6.22, ANVIL_Z)) * CFrame.Angles(0, rad(12), 0), Color3.fromRGB(255, 150, 60))
	neon(anvilF, "HotIronTip", Vector3.new(0.5, 0.16, 0.36), CFrame.new(W(0.55, 6.21, ANVIL_Z - 0.12)) * CFrame.Angles(0, rad(12), 0), Color3.fromRGB(255, 220, 140))
	local hl = light(hot, Color3.fromRGB(255, 140, 60), 1.8, 14)
	hl.Shadows = true
	-- молот и клещи
	ab("HammerHandle", 2.2, 0.16, 0.16, 1.5, 6.2, 0.55, WOOD, 20, anvilF)
	ab("HammerHead", 0.55, 0.42, 0.42, 2.5, 6.3, 0.2, IRON, 20, anvilF)
	ab("TongsA", 2.0, 0.1, 0.12, -1.9, 6.15, -0.55, IRON, 8, anvilF)
	ab("TongsB", 2.0, 0.1, 0.12, -1.9, 6.19, -0.5, shade(IRON, 1.2), -8, anvilF)
end
-- слитки с раскалёнными торцами рядом с наковальней
for i = 0, 2 do
	local ix = -5.2 + (i % 2) * 0.15
	mk(forge, "Ingot", Vector3.new(1.3, 0.3, 0.6), CFrame.new(W(ix, 2.15 + i * 0.32, -118.6)) * CFrame.Angles(0, rad(rnd(-8, 8)), 0), STEEL)
	if i < 2 then
		neon(forge, "IngotHot", Vector3.new(0.14, 0.26, 0.5), CFrame.new(W(ix + 0.68, 2.15 + i * 0.32, -118.6)), Color3.fromRGB(255, 120, 40))
	end
end

---------------------------------------------------------------- ПЕЧЬ: кладка из мелких кирпичей, настоящая арка
local CORE = Color3.fromRGB(20, 18, 34)
local BRICK = Color3.fromRGB(74, 70, 102)
local SOOT = Color3.fromRGB(32, 28, 44)
local WARM = Color3.fromRGB(168, 92, 66)
local GAP = 0.08
local ARC_C, ARC_R = 3.4, 3.5     -- центр и радиус свода зева

-- Плоскость из кирпичей. cf: низ-центр стены, локальный +Z наружу, +X вправо, +Y вверх.
-- Ряды «в перевязку»; jit даёт неровность: кирпичи выступают на разную глубину и чуть наклонены.
local function brickPlane(parent, cf, width, height, bw, bh, thick, colorFn, skipFn, jit)
	local rows = math.floor(height / bh + 0.5)
	for r = 1, rows do
		local y = (r - 0.5) * bh
		local shift = (r % 2 == 0) and bw / 2 or 0
		local segs = {}
		local cx = -width / 2
		if shift > 0 then
			table.insert(segs, { cx, cx + shift })
			cx = cx + shift
		end
		while cx < width / 2 - 0.001 do
			local ex = math.min(cx + bw, width / 2)
			table.insert(segs, { cx, ex })
			cx = ex
		end
		for _, sg in ipairs(segs) do
			local w = sg[2] - sg[1]
			local mx = (sg[1] + sg[2]) / 2
			if w > 0.25 and not (skipFn and skipFn(sg[1], sg[2], y)) then
				local j = jit or 0
				local off = j > 0 and rnd(0, j) or 0
				local rot = j > 0 and CFrame.Angles(rnd(-j, j) * 0.3, rnd(-j, j) * 0.3, rnd(-j, j) * 0.2) or CFrame.new()
				mk(parent, "Brick", Vector3.new(w - GAP, bh - GAP, thick),
					cf * CFrame.new(mx, y, thick / 2 + off) * rot, colorFn(mx, y, r))
			end
		end
	end
end

local function core(name, x0, x1, y0, y1, z0, z1)
	return mk(forge, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame.new(W((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), CORE)
end

-- ядро печи: тёмное, виден как «раствор» между кирпичами; зев вырезан круглым сводом
core("CoreL", -6.4, -3.5, 0, 10.0, -135, -131.6)
core("CoreR", 3.5, 6.4, 0, 10.0, -135, -131.6)
core("CoreBottom", -3.5, 3.5, 0, 0.8, -135, -131.6)
core("CoreBack", -3.5, 3.5, 0.8, 7.2, -135, -134.2)
core("CoreTop", -3.5, 3.5, 7.2, 10.0, -135, -131.6)
for i = -7, 6 do
	local x0 = i * 0.5
	local xc = x0 + 0.25
	local yc = ARC_C + math.sqrt(math.max(0, ARC_R * ARC_R - xc * xc))
	core("Spandrel", x0, x0 + 0.5, yc, 7.2, -134.2, -131.6)
end

local function inMouth(x0, x1, y)
	local cx = (x0 + x1) / 2
	if y > 0.75 and y <= ARC_C then return math.abs(cx) < 3.45 end
	if y > ARC_C then return cx * cx + (y - ARC_C) ^ 2 < 3.4 * 3.4 end
	return false
end
-- чем ближе к зеву, тем кирпичи теплее от огня; редкие светлые сколы и тёмные закопчённые
local function frontColor(x, y)
	local d = math.sqrt((x / 8) ^ 2 + ((y - ARC_C) / 8) ^ 2)
	local heat = clamp(1 - d * 1.5, 0, 1)
	local c = shade(BRICK, rnd(0.65, 1.12))
	local r = math.random()
	if r < 0.1 then c = shade(c, 1.35) elseif r < 0.2 then c = shade(c, 0.6) end
	return c:Lerp(WARM, heat * rnd(0.25, 0.85))
end
local function sideColor() return shade(BRICK, rnd(0.55, 1.0)) end

brickPlane(forge, CFrame.new(W(0, 0, -131.6)), 14, 9.9, 0.9, 0.45, 0.6, frontColor, inMouth, 0.09)
brickPlane(forge, CFrame.new(W(6.4, 0, -133.3)) * CFrame.Angles(0, rad(90), 0), 3.4, 9.9, 0.85, 0.45, 0.6, sideColor, nil, 0.07)
brickPlane(forge, CFrame.new(W(-6.4, 0, -133.3)) * CFrame.Angles(0, rad(-90), 0), 3.4, 9.9, 0.85, 0.45, 0.6, sideColor, nil, 0.07)
brickPlane(forge, CFrame.new(W(0, 0, -135)) * CFrame.Angles(0, rad(180), 0), 13.6, 9.9, 1.1, 0.5, 0.4, sideColor, nil, 0.05)

-- арка зева из клиновидных блоков по полукругу + замковый камень
do
	local zc = -130.75
	for i = 0, 14 do
		local a = rad(6 + i * 12)
		local rr = 4.05
		local key = (i == 7)
		local sz = key and Vector3.new(1.5, 1.7, 1.25) or Vector3.new(0.98, 1.1, 1.1 + rnd(0, 0.12))
		mk(forge, key and "Keystone" or "Voussoir", sz,
			CFrame.new(W(rr * math.cos(a), ARC_C + rr * math.sin(a), zc)) * CFrame.Angles(0, 0, a - rad(90)),
			shade(STONE, key and 1.25 or rnd(0.95, 1.25)))
	end
	neon(forge, "KeystoneRune", Vector3.new(0.32, 0.32, 0.12), CFrame.new(W(0, ARC_C + 4.45, -130.1)), CYAN)
	neon(forge, "KeystoneRune", Vector3.new(0.12, 0.7, 0.12), CFrame.new(W(0, ARC_C + 4.45, -130.1)), CYAN)
	-- косяки зева: поочерёдно широкие и узкие блоки
	for k = 0, 5 do
		for _, sx in ipairs({ -1, 1 }) do
			local wide = (k % 2 == 0)
			mk(forge, "Jamb", Vector3.new(wide and 1.1 or 0.8, 0.52, 1.0),
				CFrame.new(W(sx * (wide and 4.0 or 3.85), 0.95 + k * 0.5, -130.8)), shade(STONE, rnd(0.95, 1.25)))
		end
	end
	mk(forge, "Threshold", Vector3.new(7.6, 0.3, 1.0), CFrame.new(W(0, 0.55, -130.7)), shade(STONE, 1.1))
end

-- внутренность зева: футеровка свода и стен, тёплая от огня
do
	for i = 0, 18 do
		local a = rad(5 + i * 10)
		local rr = ARC_R - 0.15
		mk(forge, "Vault", Vector3.new(0.62, 0.35, 2.6),
			CFrame.new(W(rr * math.cos(a), ARC_C + rr * math.sin(a), -132.9)) * CFrame.Angles(0, 0, a - rad(90)),
			shade(WARM, rnd(0.45, 0.9)))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for r = 0, 5 do
			for c = 0, 2 do
				mk(forge, "Lining", Vector3.new(0.2, 0.42, 0.84),
					CFrame.new(W(sx * 3.4, 1.0 + r * 0.45, -131.9 - c * 0.9 - ((r % 2) * 0.4))), shade(WARM, rnd(0.4, 0.85)))
			end
		end
	end
end

-- светящаяся задняя стенка ступенчатой аркой и свет
local glowCol = Color3.fromRGB(255, 110, 35)
local glow = neon(forge, "FurnaceGlow", Vector3.new(6.8, 2.6, 0.15), CFrame.new(W(0, 2.2, -134.12)), glowCol, 0.1)
neon(forge, "FurnaceGlow2", Vector3.new(6.0, 1.4, 0.15), CFrame.new(W(0, 4.2, -134.12)), Color3.fromRGB(255, 90, 30), 0.15)
neon(forge, "FurnaceGlow3", Vector3.new(4.2, 1.2, 0.15), CFrame.new(W(0, 5.5, -134.12)), Color3.fromRGB(230, 70, 30), 0.25)
neon(forge, "FurnaceGlow4", Vector3.new(2.2, 0.7, 0.15), CFrame.new(W(0, 6.45, -134.12)), Color3.fromRGB(200, 50, 30), 0.35)
local fl = light(glow, Color3.fromRGB(255, 130, 60), 3, 30)
fl.Shadows = true
local frontGlow = mk(forge, "FrontGlow", Vector3.new(1, 1, 1), CFrame.new(W(0, 2.5, -129.0)), Color3.new(0, 0, 0), false, 1)
light(frontGlow, Color3.fromRGB(255, 140, 70), 2.2, 26)

-- поленья, угли и висящие в воздухе искры
for i = 1, 3 do
	local lc = CFrame.new(W(rnd(-1.6, 1.6), 1.15 + i * 0.12, -132.6 - rnd(0, 0.8))) * CFrame.Angles(rad(rnd(-8, 8)), rad(rnd(-40, 40)), rad(rnd(-6, 6)))
	mk(forge, "Log", Vector3.new(3.0, 0.5, 0.5), lc, Color3.fromRGB(44, 30, 28))
	neon(forge, "LogGlow", Vector3.new(0.16, 0.42, 0.42), lc * CFrame.new(1.55, 0, 0), Color3.fromRGB(255, 120, 40))
end
for i = 1, 45 do
	local s = rnd(0.3, 0.8)
	local pos = W(rnd(-3.2, 3.2), 0.8 + s / 2, rnd(-133.9, -131.9))
	local cf = CFrame.new(pos) * CFrame.Angles(0, rad(rnd(0, 90)), 0)
	if math.random() < 0.45 then
		neon(forge, "Coal", Vector3.new(s, s, s), cf, Color3.fromRGB(255, 90 + math.random(0, 60), 30))
	else
		mk(forge, "Coal", Vector3.new(s, s, s), cf, Color3.fromRGB(46, 20, 20))
	end
end
for i = 1, 24 do
	neon(forge, "Spark", Vector3.new(0.1, 0.1, 0.1) * rnd(0.8, 1.6), CFrame.new(W(rnd(-3, 3), rnd(1.2, 6), rnd(-133.8, -131.8))) * CFrame.Angles(rnd(0, 3), rnd(0, 3), 0),
		math.random() < 0.5 and Color3.fromRGB(255, 190, 80) or Color3.fromRGB(255, 120, 40))
end

-- пламя: четыре слоя на колонну (красный сзади, белое ядро спереди), мерцает в катсцене
local fire = folder("Fire", forge)
for i = 0, 8 do
	local fx = -3.0 + i * 0.75
	local h = 2.0 + 2.4 * (1 - (fx / 3.4) ^ 2) + rnd(-0.3, 0.3)
	neon(fire, "FlameRed", Vector3.new(0.8, h, 0.5), CFrame.new(W(fx, 0.8 + h / 2, -133.3)), Color3.fromRGB(230, 60, 40))
	neon(fire, "FlameOrange", Vector3.new(0.6, h * 0.75, 0.4), CFrame.new(W(fx, 0.8 + h * 0.375, -132.9)), Color3.fromRGB(255, 140, 40))
	neon(fire, "FlameYellow", Vector3.new(0.4, h * 0.45, 0.3), CFrame.new(W(fx, 0.8 + h * 0.225, -132.5)), Color3.fromRGB(255, 225, 90))
	neon(fire, "FlameWhite", Vector3.new(0.24, h * 0.22, 0.24), CFrame.new(W(fx, 0.8 + h * 0.11, -132.2)), Color3.fromRGB(255, 250, 210))
end

-- угловые пилястры из чередующихся блоков, железные пояса с заклёпками
for _, sx in ipairs({ -1, 1 }) do
	for k = 0, 10 do
		local wide = (k % 2 == 0)
		mk(forge, "Pilaster", Vector3.new(wide and 1.55 or 1.3, 0.9, wide and 1.55 or 1.3),
			CFrame.new(W(sx * 7.1, 0.45 + k * 0.9, -131.3)) * CFrame.Angles(0, rad(rnd(-3, 3)), 0), shade(STONE, rnd(0.9, 1.25)))
	end
	mk(forge, "PilasterBase", Vector3.new(2.0, 0.6, 2.0), CFrame.new(W(sx * 7.1, 0.3, -131.3)), shade(STONE, 0.9))
	mk(forge, "PilasterCap", Vector3.new(2.0, 0.45, 2.0), CFrame.new(W(sx * 7.1, 10.2, -131.3)), shade(STONE, 1.1))
end
local function band(y, x0, x1)
	local len = x1 - x0
	mk(forge, "IronBand", Vector3.new(len, 0.3, 0.14), CFrame.new(W((x0 + x1) / 2, y, -130.93)), DARKMETAL)
	local n = math.floor(len / 0.9)
	for i = 0, n do
		mk(forge, "Rivet", Vector3.new(0.2, 0.2, 0.1), CFrame.new(W(x0 + 0.2 + i * 0.9, y, -130.85)), shade(STEEL, 1.1))
	end
end
band(2.2, -6.2, -4.3); band(2.2, 4.3, 6.2)
band(8.7, -6.2, -2.2); band(8.7, 2.2, 6.2)
for _, sx in ipairs({ -5.2, 5.2 }) do
	mk(forge, "IronStrap", Vector3.new(0.32, 9.0, 0.12), CFrame.new(W(sx, 5.0, -130.93)), DARKMETAL)
	for k = 0, 8 do
		mk(forge, "Rivet", Vector3.new(0.18, 0.18, 0.1), CFrame.new(W(sx, 0.7 + k * 1.0, -130.85)), shade(STEEL, 1.1))
	end
end

-- «жилки душ»: тонкие голубые трещины в кладке
for i = 1, 36 do
	local vx, vy = rnd(-6.7, 6.7), rnd(0.8, 9.6)
	if not inMouth(vx - 0.1, vx + 0.1, vy) and not (math.abs(vx) < 4.7 and vy > 2.5 and vy < 8.1) then
		neon(forge, "SoulVein", Vector3.new(rnd(0.05, 0.09), rnd(0.25, 0.8), 0.05),
			CFrame.new(W(vx, vy, -130.96)) * CFrame.Angles(0, 0, rad(rnd(-35, 35))), CYAN, 0.15)
	end
end

-- карниз и крышка печи ступенями, консоли под карнизом
mk(forge, "Plinth", Vector3.new(15.4, 0.6, 5.8), CFrame.new(W(0, 0.3, -133.2)), shade(STONE, 0.75))
mk(forge, "Cap1", Vector3.new(14.8, 0.35, 5.4), CFrame.new(W(0, 10.18, -133.1)), shade(STONE, 0.9))
mk(forge, "Cap2", Vector3.new(15.4, 0.35, 5.9), CFrame.new(W(0, 10.53, -133.1)), shade(STONE, 1.0))
mk(forge, "Cap3", Vector3.new(15.9, 0.3, 6.2), CFrame.new(W(0, 10.85, -133.1)), shade(STONE, 1.1))
for i = -5, 5 do
	mk(forge, "Corbel", Vector3.new(0.9, 0.55, 0.9), CFrame.new(W(i * 1.35, 9.85, -131.0)), shade(STONE, rnd(0.85, 1.15)))
end
mk(forge, "Apron", Vector3.new(14, 0.5, 2.4), CFrame.new(W(0, 0.25, -130.0)), shade(STONE, 0.6))
for i = 1, 14 do
	mk(forge, "Ash", Vector3.new(rnd(0.2, 0.6), 0.1, rnd(0.2, 0.6)), CFrame.new(W(rnd(-5, 5), 0.55, rnd(-130.9, -129.2))) * CFrame.Angles(0, rad(rnd(0, 90)), 0), Color3.fromRGB(26, 24, 30))
end

-- балка-полка над аркой с «огоньками душ» и подвесными фонарями на цепях
for i = -3, 3 do
	mk(forge, "Mantel", Vector3.new(1.45, 0.75, 1.5), CFrame.new(W(i * 1.5, 8.55, -130.5)) * CFrame.Angles(0, rad(rnd(-2, 2)), 0), shade(STONE, rnd(1.0, 1.3)))
end
for i = -3, 3 do
	local big = (i == 0)
	local c = neon(forge, "SoulPixel", Vector3.new(big and 0.55 or 0.36, big and 0.55 or 0.36, 0.16),
		CFrame.new(W(i * 1.5, 8.55, -129.7)), big and WHITE or CYAN)
	if big then light(c, CYAN, 1.6, 12) end
end
for _, sx in ipairs({ -1, 1 }) do
	local yEnd = chain(forge, sx * 5.4, -129.9, 8.2, 5.8)
	lantern(forge, sx * 5.4, yEnd - 0.5, -129.9, true)
end

-- дымоход: три ступени, карниз, шапка
local CH0 = 11.0
core("ChimLow", -2.8, 2.8, CH0, CH0 + 4, -134.7, -131.9)
core("ChimUp", -2.0, 2.0, CH0 + 4.3, CH0 + 8, -134.4, -132.2)
core("ChimNeck", -1.4, 1.4, CH0 + 8, CH0 + 9.2, -134.0, -132.6)
local function sootColor(y0)
	return function(x, y) return shade(BRICK, rnd(0.5, 0.95)):Lerp(SOOT, clamp((y0 + y) / 9, 0, 1) * 0.8) end
end
brickPlane(forge, CFrame.new(W(0, CH0, -131.9)), 6.2, 4, 0.8, 0.4, 0.3, sootColor(0), nil, 0.05)
brickPlane(forge, CFrame.new(W(2.8, CH0, -133.3)) * CFrame.Angles(0, rad(90), 0), 2.8, 4, 0.8, 0.4, 0.3, sootColor(0), nil, 0.04)
brickPlane(forge, CFrame.new(W(-2.8, CH0, -133.3)) * CFrame.Angles(0, rad(-90), 0), 2.8, 4, 0.8, 0.4, 0.3, sootColor(0), nil, 0.04)
mk(forge, "ChimLedge", Vector3.new(6.6, 0.3, 3.6), CFrame.new(W(0, CH0 + 4.15, -133.3)), shade(STONE, 0.8))
brickPlane(forge, CFrame.new(W(0, CH0 + 4.3, -132.2)), 4.6, 3.6, 0.8, 0.4, 0.3, sootColor(4), nil, 0.05)
brickPlane(forge, CFrame.new(W(2.0, CH0 + 4.3, -133.3)) * CFrame.Angles(0, rad(90), 0), 2.2, 3.6, 0.8, 0.4, 0.3, sootColor(4), nil, 0.04)
brickPlane(forge, CFrame.new(W(-2.0, CH0 + 4.3, -133.3)) * CFrame.Angles(0, rad(-90), 0), 2.2, 3.6, 0.8, 0.4, 0.3, sootColor(4), nil, 0.04)
brickPlane(forge, CFrame.new(W(0, CH0 + 8, -132.6)), 3.4, 1.2, 0.7, 0.4, 0.3, sootColor(8), nil, 0.04)
mk(forge, "ChimCap1", Vector3.new(4.6, 0.4, 3.4), CFrame.new(W(0, CH0 + 9.4, -133.3)), shade(STONE, 0.75))
mk(forge, "ChimCap2", Vector3.new(5.2, 0.35, 3.9), CFrame.new(W(0, CH0 + 9.78, -133.3)), shade(STONE, 0.85))
neon(forge, "ChimneyGlow", Vector3.new(2.6, 0.1, 1.5), CFrame.new(W(0, CH0 + 9.99, -133.3)), Color3.fromRGB(255, 140, 50), 0.25)
mk(stage, "ForgeEmber", Vector3.new(1, 1, 1), CFrame.new(W(0, CH0 + 10.6, -133.3)), Color3.new(0, 0, 0), false, 1)

---------------------------------------------------------------- ПРИСТРОЙКИ И РЕКВИЗИТ
-- меха слева от печи
do
	local m = folder("Bellows", forge)
	local bx, bz = -11, -132.5
	local LEATHER = Color3.fromRGB(58, 40, 44)
	mk(m, "LegA", Vector3.new(0.5, 0.75, 1.6), CFrame.new(W(bx - 1.3, 0.375, bz)), WOOD)
	mk(m, "LegB", Vector3.new(0.5, 0.75, 1.6), CFrame.new(W(bx + 1.3, 0.375, bz)), WOOD)
	mk(m, "Board", Vector3.new(3.4, 0.4, 1.8), CFrame.new(W(bx, 0.95, bz)), WOOD)
	for i = 0, 5 do
		local wide = (i % 2 == 0)
		mk(m, "Pleat", Vector3.new(wide and 3.0 or 2.6, 0.3, wide and 1.5 or 1.4), CFrame.new(W(bx, 1.3 + i * 0.3, bz)), LEATHER)
	end
	mk(m, "TopBoard", Vector3.new(3.4, 0.4, 1.8), CFrame.new(W(bx, 3.2, bz)), WOOD)
	mk(m, "HandleStick", Vector3.new(0.3, 2.0, 0.3), CFrame.new(W(bx - 1.4, 4.4, bz)), WOOD)
	mk(m, "HandleBar", Vector3.new(0.3, 0.3, 1.2), CFrame.new(W(bx - 1.4, 5.5, bz)), WOOD)
	mk(m, "Nozzle", Vector3.new(2.6, 0.45, 0.45), CFrame.new(W(bx + 3.0, 1.5, bz)), IRON)
	mk(m, "NozzleRing", Vector3.new(0.4, 0.7, 0.7), CFrame.new(W(bx + 1.9, 1.5, bz)), shade(IRON, 1.2))
	for i = 0, 3 do
		mk(m, "Stud", Vector3.new(0.14, 0.14, 0.14), CFrame.new(W(bx - 1.5 + i * 1.0, 3.42, bz + 0.92)), STEEL)
	end
end
-- корыто с водой справа
do
	local m = folder("Trough", forge)
	local tx, tz = 11.2, -132.5
	local ST = shade(STONE, 0.95)
	mk(m, "Bottom", Vector3.new(4.6, 0.4, 2.6), CFrame.new(W(tx, 0.2, tz)), ST)
	for k = 0, 3 do
		mk(m, "Front", Vector3.new(1.14, 1.4, 0.4), CFrame.new(W(tx - 1.7 + k * 1.15, 1.1, tz + 1.1)), shade(ST, rnd(0.85, 1.15)))
		mk(m, "Back", Vector3.new(1.14, 1.4, 0.4), CFrame.new(W(tx - 1.7 + k * 1.15, 1.1, tz - 1.1)), shade(ST, rnd(0.85, 1.15)))
	end
	mk(m, "SideL", Vector3.new(0.4, 1.4, 1.8), CFrame.new(W(tx - 2.1, 1.1, tz)), ST)
	mk(m, "SideR", Vector3.new(0.4, 1.4, 1.8), CFrame.new(W(tx + 2.1, 1.1, tz)), ST)
	mk(m, "Water", Vector3.new(3.8, 0.1, 1.8), CFrame.new(W(tx, 1.45, tz)), Color3.fromRGB(60, 140, 210), false, 0.25)
	neon(m, "WaterGlint", Vector3.new(0.5, 0.04, 0.2), CFrame.new(W(tx - 0.6, 1.51, tz + 0.2)), PALE, 0.3)
end
-- куча угля у правой стены печи
for i = 1, 28 do
	local s = rnd(0.35, 1.0)
	local layer = math.floor((i - 1) / 9)
	local c = CFrame.new(W(rnd(-1.5, 1.5) + 8.9, s / 2 + layer * 0.55, rnd(-1.1, 1.1) - 129.6)) * CFrame.Angles(0, rad(rnd(0, 90)), 0)
	if i % 6 == 0 then
		neon(forge, "CoalHot", Vector3.new(s * 0.7, s * 0.7, s * 0.7), c, Color3.fromRGB(255, 100, 35))
	else
		mk(forge, "CoalPile", Vector3.new(s, s, s), c, Color3.fromRGB(34, 24, 30))
	end
end
-- стойки с молотами и мечами
do
	rack(folder("HammerRack", forge), -13.5, -128.5, "hammer")
	rack(folder("SwordRack", forge), 14.5, -128.0, "sword")
end
-- бочки, ящики, ведро для закалки
barrel(folder("Barrels", forge), -14.2, -124.0, 1.0, 0, 10)
barrel(forge, -15.8, -126.2, 1.0, 0, 40)
barrel(forge, 13.0, -124.5, 1.0, 0, 70)
barrel(forge, 16.6, -125.5, 1.1, 0, 20)
barrel(forge, 5.0, -118.8, 0.55, 2.0, 0)
crate(folder("Crates", forge), -16.8, -121.4, 1.6, 0, 15)
crate(forge, -15.0, -121.0, 1.2, 0, -10)
crate(forge, -16.2, -121.6, 1.1, 1.6, 30)
crate(forge, 15.8, -121.0, 1.5, 0, -20)

-- рунический круг на полу вокруг платформы: голубые плиты и пиксельные глифы
do
	local ringF = folder("RuneRing", forge)
	local props = { { -11, -132.5 }, { 11.2, -132.5 }, { -13.5, -128.5 }, { 14.5, -128 }, { 8.9, -129.6 }, { -14.2, -124 }, { -15.8, -126.2 }, { 13, -124.5 }, { 16.6, -125.5 } }
	local function free(x, z)
		if z < -128.2 and math.abs(x) < 9 then return false end
		for _, p in ipairs(props) do
			if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < 12 then return false end
		end
		return true
	end
	local R = 12.0
	local glyphs = {
		{ "X.X", ".X.", "XXX" }, { "XXX", "X.X", ".X." }, { ".X.", "XXX", "X.X" }, { "X..", "XXX", "..X" },
		{ "XX.", ".XX", "X.X" }, { "X.X", "XXX", ".X." }, { ".XX", "X..", "XXX" }, { "XXX", ".X.", "X.X" },
	}
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local x, z = math.cos(a) * R, ANVIL_Z + math.sin(a) * R
		if free(x, z) then
			neon(ringF, "RuneSeg", Vector3.new(0.45, 0.1, 1.3), CFrame.new(W(x, 0.06, z)) * CFrame.Angles(0, -a + math.pi / 2, 0), CYAN, 0.2)
		end
	end
	for g = 0, 7 do
		local a = (g + 0.5) / 8 * math.pi * 2
		local gx, gz = math.cos(a) * (R + 1.4), ANVIL_Z + math.sin(a) * (R + 1.4)
		if free(gx, gz) then
			local pat = glyphs[g + 1]
			for r = 1, 3 do
				for c = 1, 3 do
					if pat[r]:sub(c, c) == "X" then
						neon(ringF, "Glyph", Vector3.new(0.34, 0.1, 0.34),
							CFrame.new(W(gx, 0.07, gz)) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new((c - 2) * 0.42, 0, (r - 2) * 0.42), WHITE, 0.1)
					end
				end
			end
		end
	end
	local rl = mk(ringF, "RuneLight", Vector3.new(1, 1, 1), CFrame.new(W(0, 0.6, -108)), Color3.new(0, 0, 0), false, 1)
	light(rl, CYAN, 1.2, 28)
end

---------------------------------------------------------------- ЗНАМЁНА, ЦЕПИ И ФОНАРИ ЗАЛА
do
	local hang = folder("Hangings", stage)
	for _, c in ipairs({ { -30, -90 }, { 30, -90 }, { -30, -125 }, { 30, -125 }, { -30, -160 }, { 30, -160 } }) do
		banner(hang, c[1], 36, c[2] + 3.0)
		-- основание и капитель колонны
		mk(hang, "ColBase", Vector3.new(5.8, 0.8, 5.8), CFrame.new(W(c[1], 0.4, c[2])), shade(STONE, 0.9))
		mk(hang, "ColBase2", Vector3.new(5.2, 0.6, 5.2), CFrame.new(W(c[1], 1.1, c[2])), shade(STONE, 1.0))
		mk(hang, "ColCap1", Vector3.new(5.6, 0.7, 5.6), CFrame.new(W(c[1], 40.6, c[2])), shade(STONE, 1.05))
		mk(hang, "ColCap2", Vector3.new(6.6, 0.7, 6.6), CFrame.new(W(c[1], 41.3, c[2])), shade(STONE, 1.15))
	end
	for _, c in ipairs({ { -34, -95 }, { 34, -95 }, { -34, -125 }, { 34, -125 }, { -34, -155 }, { 34, -155 }, { -20, -168 }, { 20, -168 } }) do
		local yEnd = chain(hang, c[1], c[2], 43.2, 30.5)
		lantern(hang, c[1], yEnd - 0.6, c[2], true)
	end
end

---------------------------------------------------------------- МИКРОДЕТАЛИ (папка Detail)
-- Тысячи мелких блоков: кладка стен, потолочные сосульки-сталактиты, щебень.
-- QUALITY задаётся в начале файла. Катсцена может убрать Detail на слабых устройствах.
do
	local det = folder("Detail", stage)
	local made = 0
	local function micro(parent, x, y, z, sx, sy, sz, base, k0, k1)
		mk(parent, "Mb", Vector3.new(sx, sy, sz),
			CFrame.new(W(x, y, z)) * CFrame.Angles(rad(rnd(-6, 6)), rad(rnd(-6, 6)), rad(rnd(-6, 6))),
			shade(base, rnd(k0 or 0.55, k1 or 1.2)))
		made = made + 1
		if made % 2500 == 0 then task.wait() end
	end
	local wallF = folder("Walls", det)
	-- коридор: стены x=±7 (внутренняя грань), z от 10 до -70, y 0..14.5
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 200 * MQ do
			local s = rnd(0.45, 1.3)
			micro(wallF, side * (6.9 - rnd(0, 0.5)), rnd(0.3, 14.3), rnd(10, -70), rnd(0.4, 0.9), s * rnd(0.6, 1), s, STONE)
		end
	end
	-- зал: боковые стены (внутренняя грань x=±40)
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 600 * MQ do
			local s = rnd(0.6, 1.7)
			micro(wallF, side * (39.7 - rnd(0, 0.6)), rnd(0.3, 42.5), rnd(-72, -181), rnd(0.5, 1.1), s * rnd(0.6, 1), s, STONE)
		end
	end
	-- зал: задняя стена (z=-180) и передняя вокруг входа
	for i = 1, 250 * MQ do
		local s = rnd(0.6, 1.7)
		micro(wallF, rnd(-39, 39), rnd(0.3, 42.5), -179.7 + rnd(0, 0.6), s, s * rnd(0.6, 1), rnd(0.5, 1.1), STONE)
	end
	for i = 1, 60 * MQ do
		local s = rnd(0.6, 1.5)
		local x = rnd(9.5, 39)
		if math.random() < 0.5 then x = -x end
		micro(wallF, x, rnd(0.3, 42.5), -70.2 - rnd(0, 0.6), s, s * rnd(0.6, 1), rnd(0.5, 1.1), STONE)
	end
	-- потолки
	for i = 1, 70 * MQ do
		local s = rnd(0.6, 1.6)
		micro(wallF, rnd(-39, 39), 43.4 - rnd(0, 0.6), rnd(-72, -180), s, rnd(0.4, 1.0), s * rnd(0.6, 1), STONE, 0.4, 0.9)
	end
	for i = 1, 40 * MQ do
		local s = rnd(0.5, 1.3)
		micro(wallF, rnd(-6.5, 6.5), 14.9 - rnd(0, 0.5), rnd(10, -70), s, rnd(0.4, 0.9), s * rnd(0.6, 1), STONE, 0.4, 0.9)
	end
	-- сталактиты из стопки уменьшающихся кубов
	local stal = folder("Stalactites", det)
	local function stalactite(x, yTop, z, s0)
		local y, s = yTop, s0
		for k = 1, math.random(3, 5) do
			micro(stal, x + rnd(-0.1, 0.1), y - s / 2, z + rnd(-0.1, 0.1), s, s, s, STONE, 0.5, 1.0)
			y = y - s
			s = s * rnd(0.62, 0.78)
		end
	end
	for i = 1, 60 * MQ do stalactite(rnd(-39, 39), 43.4, rnd(-74, -179), rnd(1.0, 2.0)) end
	for i = 1, 20 * MQ do stalactite(rnd(-6.5, 6.5), 14.9, rnd(8, -69), rnd(0.8, 1.4)) end
	-- щебень, камешки, трещины пола
	local deb = folder("Debris", det)
	for i = 1, 90 * MQ do
		local s = rnd(0.15, 0.7)
		micro(deb, rnd(-6.5, 6.5), s / 2, rnd(9, -69), s, s, s, STONE, 0.6, 1.0)
	end
	for i = 1, 160 * MQ do
		local s = rnd(0.2, 1.0)
		local x, z = rnd(-39, 39), rnd(-74, -179)
		if not (math.abs(x) < 18 and z < -112 and z > -136) then
			micro(deb, x, s / 2, z, s, s, s, STONE, 0.6, 1.0)
		end
	end
	for i = 1, 14 * MQ do
		local x, z = rnd(-38, 38), rnd(-76, -178)
		if not (math.abs(x) < 18 and z < -110 and z > -136) then
			neon(deb, "FloorCrack", Vector3.new(rnd(0.08, 0.14), 0.05, rnd(0.8, 2.6)),
				CFrame.new(W(x, 0.03, z)) * CFrame.Angles(0, rad(rnd(0, 180)), 0), CYAN, 0.35)
		end
	end
	print("[BuildIntroStage] микродеталей: " .. made)
end

---------------------------------------------------------------- СВЕТОВОЙ СТОЛБ ПАМЯТИ
-- справа от входа в зал: виден с первого кадра в конце коридора
local beamF = folder("SoulBeam", stage)
neon(beamF, "BeamShell", Vector3.new(3.4, 44, 3.4), CFrame.new(W(7, 22, -88)), CYAN, 0.78)
neon(beamF, "BeamCore", Vector3.new(1.2, 44, 1.2), CFrame.new(W(7, 22, -88)), WHITE, 0.3)
local beamLightSrc = mk(beamF, "BeamLightSrc", Vector3.new(1, 1, 1), CFrame.new(W(7, 3, -88)), Color3.new(0, 0, 0), false, 1)
light(beamLightSrc, CYAN, 4, 30)
for i = 0, 11 do
	local a = i / 12 * math.pi * 2
	neon(beamF, "PadCube", Vector3.new(1.1, 0.35, 1.1), CFrame.new(W(7 + math.cos(a) * 4, 0.2, -88 + math.sin(a) * 4)) * CFrame.Angles(0, a, 0), CYAN, 0.1)
end
neon(beamF, "PadFloor", Vector3.new(7.5, 0.25, 7.5), CFrame.new(W(7, 0.12, -88)), Color3.fromRGB(70, 190, 235), 0.55)
mk(stage, "BeamBase", Vector3.new(1, 1, 1), CFrame.new(W(7, 0.8, -88)), Color3.new(0, 0, 0), false, 1)

---------------------------------------------------------------- ЛЮДИ-СИЛУЭТЫ И КЛИНКИ
local function human(parent, cf, s, d)
	local m = Instance.new("Model")
	m.Name = "Silhouette"
	m.Parent = parent
	local function p(name, size, off, rot, tr)
		-- голова и шея белые, туловище бледное, конечности голубее: человек читается на фоне синего стекла
		local col = PALE
		if name:find("Head") or name == "Neck" then col = Color3.new(1, 1, 1)
		elseif name:find("Arm") or name:find("Leg") or name:find("Hand") or name:find("Foot") then col = Color3.fromRGB(150, 226, 255) end
		return neon(m, name, size * s, cf * CFrame.new(off * s) * (rot or CFrame.new()), col, tr or 0.3)
	end
	p("LegL", Vector3.new(0.42, 1.55, 0.5), Vector3.new(-0.4, 0.85, 0))
	p("LegR", Vector3.new(0.42, 1.55, 0.5), Vector3.new(0.4, 0.85, 0))
	p("FootL", Vector3.new(0.5, 0.2, 0.8), Vector3.new(-0.42, 0.1, 0.15))
	p("FootR", Vector3.new(0.5, 0.2, 0.8), Vector3.new(0.42, 0.1, 0.15))
	p("Torso", Vector3.new(0.95, 1.5, 0.6), Vector3.new(0, 2.45, 0))
	p("Neck", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0, 3.35, 0))
	p("ArmL", Vector3.new(0.34, 1.5, 0.4), Vector3.new(-1.1, 2.35, 0), CFrame.Angles(0, 0, rad(-11)))
	p("ArmR", Vector3.new(0.34, 1.5, 0.4), Vector3.new(1.1, 2.35, 0), CFrame.Angles(0, 0, rad(11)))
	p("HandL", Vector3.new(0.34, 0.34, 0.34), Vector3.new(-1.25, 1.55, 0))
	p("HandR", Vector3.new(0.34, 0.34, 0.34), Vector3.new(1.25, 1.55, 0))
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
		neon(m, "Dust" .. i, Vector3.new(sz, sz, sz),
			cf * CFrame.new(rnd(-1.4, 1.4) * s, rnd(0, 4.6) * s, rnd(-0.8, 0.8) * s) * CFrame.Angles(rnd(0, 3), rnd(0, 3), 0),
			col, 0.1)
	end
	return m
end

local function glassBlade(name, cf, len, d, brightness)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = bladesF
	local bw = math.max(1.6, len / 9 * 2.9)   -- корпус достаточно широк, чтобы силуэт был внутри стекла
	local GLASS = Color3.fromRGB(46, 128, 210)
	local body = neon(m, "Body", Vector3.new(bw, len, 0.45), cf, GLASS, 0.5)
	local h = len / 2
	neon(m, "Tip1", Vector3.new(bw * 0.62, 0.8, 0.4), cf * CFrame.new(0, -(h + 0.4), 0), GLASS, 0.5)
	neon(m, "Tip2", Vector3.new(bw * 0.31, 0.7, 0.35), cf * CFrame.new(0, -(h + 1.1), 0), GLASS, 0.5)
	mk(m, "Guard", Vector3.new(bw + 1.4, 0.5, 0.9), cf * CFrame.new(0, h + 0.25, 0), shade(IRON, 0.9))
	mk(m, "Handle", Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(0, h + 1.3, 0), WOOD)
	mk(m, "Pommel", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, h + 2.3, 0), shade(IRON, 0.9))
	human(m, cf * CFrame.new(0, -len * 0.3, 0), len / 9, d)
	local l = light(body, CYAN, brightness or 1.6, 16)
	l.Name = "Light"
	m.PrimaryPart = body
	m:SetAttribute("Phase", rnd(0, 6.28))
	return m
end

-- кольцо парящих клинков вокруг наковальни; те, что попали бы в печь и её пристройки, уводим дальше
local d_pattern = { 0, 1, 0, 2, 0, 3, 1, 0 }
local idx = 0
for i = 1, 18 do
	local ang = i / 18 * math.pi * 2
	local r = 13 + (i % 3) * 3.5
	local x, z = math.cos(ang) * r * 1.3, ANVIL_Z + math.sin(ang) * r
	if z < -113 then
		idx = idx + 1
		if math.abs(x) < 17 and z > -146 and z < -124 then z = -146 end
		local y = 8 + (i % 4) * 3
		local cf = CFrame.new(W(x, y, z)) * CFrame.Angles(rad(rnd(-6, 6)), rad(rnd(0, 360)), rad(rnd(-6, 6)))
		glassBlade("Blade" .. i, cf, 8 + (i % 3), d_pattern[(idx - 1) % #d_pattern + 1], 1.4)
	end
end
-- обречённый клинок (шот 4): силуэт гаснет и рассыпается
glassBlade("DoomedBlade", CFrame.new(W(-4.4, 6.6, -108)), 8, 0, 3.5)

---------------------------------------------------------------- ПУСТОЙ КЛИНОК
local FLOOR_CF = CFrame.new(W(4, 0.55, -108)) * CFrame.Angles(0, 0, rad(90))
local blade = Instance.new("Model")
blade.Name = "EmptyBlade"
blade.Parent = stage
-- Клинок в локальных координатах (ось Y вдоль меча, начало в центре рукояти):
--   навершие y=-1.65, рукоять -1.35..1.35 (две ладони), гарда 1.55, лезвие 1.75..5.25, остриё до 5.9
do
	local cf = FLOOR_CF
	local STEEL_D = Color3.fromRGB(104, 98, 96)
	local handle = mk(blade, "Handle", Vector3.new(0.5, 2.7, 0.5), cf, WOOD)
	for i = -3, 3 do
		mk(blade, "Wrap", Vector3.new(0.58, 0.16, 0.58), cf * CFrame.new(0, i * 0.38, 0), shade(WOOD, 0.55))
	end
	mk(blade, "Pommel", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, -1.75, 0), Color3.fromRGB(70, 66, 66))
	mk(blade, "PommelCap", Vector3.new(0.45, 0.3, 0.45), cf * CFrame.new(0, -2.3, 0), Color3.fromRGB(88, 82, 80))
	mk(blade, "Guard", Vector3.new(2.4, 0.4, 0.9), cf * CFrame.new(0, 1.55, 0), Color3.fromRGB(80, 74, 72))
	for _, sx in ipairs({ -1, 1 }) do
		mk(blade, "GuardTip", Vector3.new(0.4, 0.7, 0.9), cf * CFrame.new(sx * 1.1, 1.75, 0), Color3.fromRGB(88, 82, 80))
	end
	mk(blade, "Blade", Vector3.new(0.85, 3.5, 0.34), cf * CFrame.new(0, 3.5, 0), STEEL_D)
	mk(blade, "Tip", Vector3.new(0.55, 0.5, 0.3), cf * CFrame.new(0, 5.5, 0), STEEL_D)
	mk(blade, "Tip2", Vector3.new(0.3, 0.3, 0.26), cf * CFrame.new(0, 5.9, 0), STEEL_D)
	for i = 1, 8 do
		mk(blade, "Rust", Vector3.new(0.3, 0.3, 0.38), cf * CFrame.new(rnd(-0.3, 0.3), rnd(1.9, 5.1), 0), RUST)
	end
	local g = neon(blade, "BladeGlow", Vector3.new(0.2, 3.4, 0.42), cf * CFrame.new(0, 3.5, 0), CYAN, 1)
	local l = light(g, CYAN, 0, 20)
	l.Name = "BladeLight"
	blade.PrimaryPart = handle
end

-- Герой («Пробуждённый») строится катсценой в момент показа: у него живой скелет (IK рук и ног).

---------------------------------------------------------------- ТОЧКИ КАМЕРЫ
-- Шоты идут цепочкой: конец одного = начало следующего, кроме жёсткой склейки на 5A.
local function shot(name, pos, target)
	return mk(cam, name, Vector3.new(1, 1, 2), CFrame.lookAt(W(pos[1], pos[2], pos[3]), W(target[1], target[2], target[3])), Color3.new(1, 0, 1), false, 1)
end
local function marker(name, cf)
	return mk(cam, name, Vector3.new(1, 1, 1), cf, Color3.new(0, 1, 1), false, 1)
end

shot("Shot1", { 0, 3.5, 4 }, { 0, 3, -60 })          -- чёрный экран, виден лишь свет в конце коридора
shot("Shot2A", { 0, 3.5, 4 }, { 0, 3, -60 })         -- полёт по коридору
shot("Shot2B", { 0, 3.5, -64 }, { 0, 6, -100 })
shot("Shot3B", { -10, 9, -100 }, { 0, 7.5, -124 })   -- выход в зал: кузня и парящие клинки
shot("Shot4B", { 0.6, 5.0, -99.2 }, { 0.4, 5.0, -108 })  -- обречённый клинок и пустой клинок на полу в одном кадре
shot("Shot4C", { 3.6, 2.2, -101.6 }, { 2.4, 1.0, -108 })    -- ближе к пустому клинку: он наполняется светом
shot("Shot5A", { 8.6, 2.8, -99.8 }, { 4.4, 2.4, -109 })   -- пустой клинок на полу, рука тянется к рукояти
shot("Shot5B", { 5.2, 7.2, -102.0 }, { 4.2, 7.1, -110 })     -- подъём к лицу героя
shot("Shot6A", { 3.2, 5.0, -97 }, { 4, 8.4, -108 })           -- клинок в центре кадра
shot("Shot6B", { 0.2, 6.2, -78 }, { 3.9, 9.2, -108 })            -- отъезд

marker("BladeFloor", FLOOR_CF)
marker("BladeRaised", CFrame.new(W(5.3, 4.3, -108.9)) * CFrame.Angles(0, 0, rad(-6)))
marker("BladeCenter", CFrame.new(W(4, 9.6, -107.8)))
marker("CrumbleSource", CFrame.new(W(-4.4, 6.2, -108)))

CHS:SetWaypoint("BuildIntroStage")
print(("[BuildIntroStage] готово: %d деталей в сцене, %d точек камеры. Сцена в точке %s."):format(
	#stage:GetDescendants(), #cam:GetChildren(), tostring(ORIGIN)))
