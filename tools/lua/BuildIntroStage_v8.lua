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
local STORE_IN_REPLICATED = false
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
local stage = folder("IntroStage")
local cam = folder("IntroCam")
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
local RUST = Color3.fromRGB(94, 80, 114)   -- потускневшее холодное железо: тёплая ржавчина под голубым светом зеленеет, поэтому тон сдвинут в сине-фиолетовый
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


---------------------------------------------------------------- ПАЛИТРА v7
-- глубокое сине-фиолетовое железо и камень, свет — только холодный (голубой/белый), капля тёплого золота у горнила
local IRON_D  = Color3.fromRGB(20, 22, 38)
local IRON_M  = Color3.fromRGB(33, 36, 60)
local IRON_L  = Color3.fromRGB(54, 60, 94)
local STONE_D = Color3.fromRGB(36, 38, 58)
local GOLD    = Color3.fromRGB(255, 190, 110)
local GOLD_W  = Color3.fromRGB(255, 232, 190)
local DEEP    = Color3.fromRGB(46, 140, 232)
local VIOLET  = Color3.fromRGB(150, 124, 255)
local STEEL = Color3.fromRGB(86, 90, 108)
local DARKMETAL = Color3.fromRGB(34, 36, 48)

local function bx(parent, name, sx, sy, sz, cf, color, glow, tr)
	return mk(parent, name, Vector3.new(sx, sy, sz), cf, color, glow, tr)
end
-- ромб-остриё: квадрат, повёрнутый на 45° вокруг оси Z (из блоков остриё иначе не собрать)
local function diamond(parent, name, size, thick, cf, color, glow, tr)
	return mk(parent, name, Vector3.new(size, size, thick), cf * CFrame.Angles(0, 0, rad(45)), color, glow, tr)
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

---------------------------------------------------------------- ЗАЛ ГОРНИЛА (над ним открытое небо)
local HX = 44                          -- полуширина зала
local ZF, Z1 = -72, -140               -- вход в зал и подножие зиккурата
local hall = folder("Hall", stage)
slabTiles(hall, -HX, HX, Z1, ZF, -1, 0, 8, FLOOR)

-- руины боковых стен: стопки камней разной высоты, края «обкусаны»
for _, side in ipairs({ -1, 1 }) do
	for z = -74, -146, -6 do
		local top = 12 + 16 * math.abs(math.sin(z * 0.37 + side)) + rnd(0, 7)
		for y = 3, top, 6 do
			if math.random() > 0.05 then stone(hall, side * (HX + 3), y, z, 6) end
		end
	end
end
for x = -42, 42, 6 do
	if math.abs(x) >= 12 then
		local top = 10 + 14 * math.abs(math.sin(x * 0.29)) + rnd(0, 6)
		for y = 3, top, 6 do stone(hall, x, y, ZF - 1, 6) end
	end
end

-- колонны: каждая сломана на своей высоте, обломки лежат у подножия
local function column(x, z, h)
	bx(hall, "ColBase", 7.6, 1.0, 7.6, CFrame.new(W(x, 0.5, z)), shade(STONE_D, 1.1))
	bx(hall, "ColBase2", 6.4, 0.9, 6.4, CFrame.new(W(x, 1.45, z)), shade(STONE_D, 1.3))
	local y, seg = 1.9, 4.2
	while y + seg * 0.5 < h do
		local cf = CFrame.new(W(x + rnd(-0.08, 0.08), y + seg / 2, z + rnd(-0.08, 0.08))) * CFrame.Angles(0, rad(rnd(-2, 2)), 0)
		bx(hall, "Shaft", 4.6, seg, 4.6, cf, shade(STONE_D, rnd(0.95, 1.3)))
		for _, o in ipairs({ { 2.4, 0 }, { -2.4, 0 }, { 0, 2.4 }, { 0, -2.4 } }) do
			bx(hall, "Flute", o[1] == 0 and 1.3 or 0.5, seg * 0.94, o[2] == 0 and 1.3 or 0.5,
				CFrame.new(W(x + o[1], y + seg / 2, z + o[2])), shade(STONE_D, 1.55))
		end
		y = y + seg
	end
	if h > 36 then
		bx(hall, "ColCap", 6.2, 0.8, 6.2, CFrame.new(W(x, y + 0.4, z)), shade(STONE_D, 1.4))
		bx(hall, "ColCap2", 7.6, 0.9, 7.6, CFrame.new(W(x, y + 1.25, z)), shade(STONE_D, 1.2))
	end
	for i = 1, 5 do
		local s = rnd(0.8, 2.2)
		bx(hall, "Fallen", s, s * rnd(0.6, 1), s, CFrame.new(W(x + rnd(-5, 5), s / 2, z + rnd(-5, 5))) * CFrame.Angles(rad(rnd(-10, 10)), rad(rnd(0, 90)), 0), shade(STONE_D, rnd(0.8, 1.3)))
	end
end
column(-31, -92, 41)
column(31, -92, 29)
column(-31, -122, 24)
column(31, -122, 41)
for _, c in ipairs({ { -36, -80 }, { 36, -84 }, { -37, -134 }, { 37, -132 } }) do
	crystal(c[1], 0, c[2], rnd(2, 3))
end
rustHeap(-14, -100)
rustHeap(15, -98)
rustHeap(-22, -126)
rustHeap(24, -118)

-- мягкий заполняющий свет зала: в Roblox нет GI, поэтому «отражённый» свет рисуем слабыми лампами
do
	local f = folder("Fill", hall)
	for _, x in ipairs({ -32, -12, 12, 32 }) do
		for _, z in ipairs({ -86, -112, -132 }) do
			local p = mk(f, "FillLamp", Vector3.new(1, 1, 1), CFrame.new(W(x, 15, z)), Color3.new(0, 0, 0), false, 1)
			light(p, Color3.fromRGB(86, 128, 255), 0.75, 44)
		end
	end
end

---------------------------------------------------------------- ГОРНИЛО ПЕРВОГО КУЗНЕЦА
-- Колоссальная чаша жидкой памяти на зиккурате. Подвешена в раме-кардане (ось качания идёт по X),
-- наклонена к залу: из переднего края льётся водопад душ, жилы света по полу сходятся к алтарю.
local cruc = folder("Crucible", stage)
local zig = folder("Ziggurat", stage)

-- Зиккурат: три яруса. Лицевые грани ярусов — каскад.
local TIERS = {
	{ x = 40, z0 = -182, z1 = -140, y0 = 0, y1 = 5 },
	{ x = 30, z0 = -182, z1 = -150, y0 = 5, y1 = 10 },
	{ x = 20, z0 = -182, z1 = -158, y0 = 10, y1 = 15 },
}
for i, t in ipairs(TIERS) do
	slabTiles(zig, -t.x, t.x, t.z0, t.z1, t.y0, t.y1, 6, shade(STONE_D, 0.9 + i * 0.12))
	-- карниз по краю яруса и светящиеся швы на лицевой грани
	bx(zig, "Cornice", t.x * 2 + 1.2, 0.5, 1.4, CFrame.new(W(0, t.y1 + 0.15, t.z1 + 0.1)), shade(IRON_L, 1.0))
	for x = -t.x + 3, t.x - 3, 6 do
		if math.random() < 0.55 and math.abs(x) > 6 then
			neon(zig, "FaceSeam", Vector3.new(0.22, (t.y1 - t.y0) * rnd(0.5, 0.95), 0.2),
				CFrame.new(W(x + 3, t.y0 + (t.y1 - t.y0) * 0.5, t.z1 + 0.08)), CYAN, 0.3)
		end
	end
end

-- Чаша
local CRUC_C = { 0, 42, -170 }
local TILT = 50
local CR = CFrame.new(W(CRUC_C[1], CRUC_C[2], CRUC_C[3])) * CFrame.Angles(rad(TILT), 0, 0)
local RIM_R, DEPTH = 24, 16
local RS = (RIM_R ^ 2 + DEPTH ^ 2) / (2 * DEPTH)
local YC = RS - DEPTH
local AMAX = math.asin(RIM_R / RS)
local THK = 1.8
local bowlF = folder("Bowl", cruc)
local NR = 9
for k = 0, NR - 1 do
	local a0, a1 = AMAX * k / NR, AMAX * (k + 1) / NR
	local am = (a0 + a1) / 2
	local rmid = (RS - THK / 2) * math.sin(am)
	local ymid = YC - (RS - THK / 2) * math.cos(am)
	local arc = RS * (a1 - a0) * 1.12
	local n = math.max(5, math.ceil(2 * math.pi * rmid / 3.4))
	for i = 0, n - 1 do
		local b = (i + (k % 2) * 0.5) / n * 2 * math.pi
		local w = 2 * math.pi * math.max(rmid, 0.6) / n * 1.06
		local cf = CR * CFrame.Angles(0, -b, 0) * CFrame.new(rmid, ymid, 0) * CFrame.Angles(0, 0, am - math.pi / 2)
		bx(bowlF, "Plate", THK, arc, w, cf, shade(IRON_M, rnd(0.75, 1.3)))
	end
end
-- железные пояса и светящиеся трещины: Горнило трескается — память прорывается наружу
for _, k in ipairs({ 2, 5, 7 }) do
	local am = AMAX * (k + 0.5) / NR
	local rb = (RS + 0.5) * math.sin(am)
	local yb = YC - (RS + 0.5) * math.cos(am)
	local n = math.ceil(2 * math.pi * rb / 4)
	for i = 0, n - 1 do
		local b = i / n * 2 * math.pi
		local cf = CR * CFrame.Angles(0, -b, 0) * CFrame.new(rb, yb, 0) * CFrame.Angles(0, 0, am - math.pi / 2)
		bx(bowlF, "Belt", 1.2, 1.6, 2 * math.pi * rb / n * 1.02, cf, shade(IRON_L, rnd(0.85, 1.2)))
		if i % 3 == 0 then bx(bowlF, "Rivet", 0.5, 0.5, 0.5, cf * CFrame.new(0.7, 0, 0), shade(IRON_L, 1.5)) end
	end
end
for c = 1, 9 do
	local b = rnd(0, 2 * math.pi)
	local a = AMAX * rnd(0.2, 0.9)
	for s = 1, math.random(4, 7) do
		local am = a + s * 0.045 + rnd(-0.02, 0.02)
		b = b + rnd(-0.07, 0.07)
		local rr, yy = (RS + 0.15) * math.sin(am), YC - (RS + 0.15) * math.cos(am)
		neon(bowlF, "Crack", Vector3.new(0.35, 1.6 * rnd(0.8, 1.4), 0.5),
			CR * CFrame.Angles(0, -b, 0) * CFrame.new(rr, yy, 0) * CFrame.Angles(0, 0, am - math.pi / 2 + rnd(-0.5, 0.5)), (s % 2 == 0) and WHITE or CYAN, 0.1)
	end
end

-- Расплав памяти: пиксельная гладь с вихрем (катсцена колышет кубики по высоте)
local liqF = folder("Liquid", cruc)
local YL = -1.6
local RL = math.sqrt((RS - THK) ^ 2 - (YL - YC) ^ 2) - 0.4
local CELL = 2.0
local nl = 0
for gx = -RL, RL, CELL do
	for gz = -RL, RL, CELL do
		local rr = math.sqrt(gx * gx + gz * gz)
		if rr < RL - 0.2 then
			local ang = math.atan2(gz, gx)
			local sw = math.sin(ang * 3 + rr * 0.3) + 0.55 * math.sin(rr * 0.85 - ang * 2) + rnd(-0.25, 0.25)
			local col, up
			if rr < 3.2 or sw > 1.2 then col, up = WHITE, 0.55
			elseif sw > 0.55 then col, up = PALE, 0.35
			elseif sw > -0.15 then col, up = CYAN, 0.2
			else col, up = DEEP, 0.05 end
			local c = neon(liqF, "Liq", Vector3.new(CELL - 0.06, 0.8, CELL - 0.06),
				CR * CFrame.new(gx, YL + up * rnd(0.4, 1), gz), col)
			c:SetAttribute("ph", rnd(0, 6.28)); c:SetAttribute("up", up); c:SetAttribute("gx", gx); c:SetAttribute("gz", gz)
			nl = nl + 1
		end
	end
end
-- «пузыри» — крупные яркие кубы, всплывающие над гладью
for i = 1, 22 do
	local a, r = rnd(0, 6.28), rnd(0, RL - 3)
	local s = rnd(1.2, 2.4)
	neon(liqF, "Bubble", Vector3.new(s, s, s), CR * CFrame.new(math.cos(a) * r, YL + 1.2 + s / 2, math.sin(a) * r) * CFrame.Angles(rnd(0, 1), rnd(0, 1), rnd(0, 1)), (i % 2 == 0) and WHITE or PALE)
end

-- Устье: железное кольцо с раскалённой золотой кромкой; спереди — разрыв-носик, откуда льётся
local rimF = folder("Rim", cruc)
local nRim = 48
for i = 0, nRim - 1 do
	local b = i / nRim * 2 * math.pi
	local isSpout = (b > rad(72) and b < rad(108))
	local w = 2 * math.pi * RIM_R / nRim * 1.04
	local base = CR * CFrame.Angles(0, -b, 0)
	if not isSpout then
		bx(rimF, "RimPlate", 4.2, 1.7, w, base * CFrame.new(RIM_R + 0.4, -0.2, 0), shade(IRON_L, rnd(0.8, 1.2)))
		neon(rimF, "RimGold", Vector3.new(0.7, 0.55, w * 0.94), base * CFrame.new(RIM_R - 1.9, 0.5, 0), (i % 5 == 0) and GOLD_W or GOLD)
		if i % 2 == 0 then bx(rimF, "RimStud", 1.0, 0.6, w * 0.5, base * CFrame.new(RIM_R + 1.2, 0.85, 0), shade(IRON_L, 1.6)) end
	else
		bx(rimF, "SpoutPlate", 4.2, 1.0, w, base * CFrame.new(RIM_R + 0.4, -1.2, 0), shade(IRON_L, 1.0))
		neon(rimF, "SpoutGold", Vector3.new(0.7, 0.4, w * 0.94), base * CFrame.new(RIM_R - 1.9, -0.5, 0), GOLD_W)
	end
end
-- мечи павших, воткнутые в обод (клинок вверх и чуть наружу)
local function bigSword(parent, cf, len, w)
	bx(parent, "Blade", w, len, 0.55, cf * CFrame.new(0, len / 2 + 0.7, 0), shade(IRON_L, 1.25))
	bx(parent, "Edge", w * 0.12, len * 0.92, 0.62, cf * CFrame.new(0, len / 2 + 0.8, 0), CYAN, true, 0.2)
	diamond(parent, "Tip", w * 0.7, 0.5, cf * CFrame.new(0, len + 0.7 + w * 0.12, 0), shade(IRON_L, 1.25))
	bx(parent, "Guard", w * 2.4, 0.9, 1.1, cf * CFrame.new(0, 0.2, 0), IRON_M)
	bx(parent, "GuardEnd", 0.9, 1.5, 1.1, cf * CFrame.new(w * 1.2, 0.5, 0), IRON_M)
	bx(parent, "GuardEnd", 0.9, 1.5, 1.1, cf * CFrame.new(-w * 1.2, 0.5, 0), IRON_M)
	bx(parent, "Grip", 0.6, 2.2, 0.6, cf * CFrame.new(0, -1.2, 0), WOOD)
end
local swF = folder("RimSwords", cruc)
for i = 0, 15 do
	local b = (i + 0.5) / 16 * 2 * math.pi
	if not (b > rad(60) and b < rad(120)) then
		local ln = rnd(9, 15)
		bigSword(swF, CR * CFrame.Angles(0, -b, 0) * CFrame.new(RIM_R + 1.9, 1.2, 0) * CFrame.Angles(0, 0, -rad(rnd(10, 24))) * CFrame.Angles(0, rad(90), 0), ln, 1.6)
	end
end

-- Кардан: две башни по бокам, цапфы идут по оси X через центр чаши
for _, sx in ipairs({ -1, 1 }) do
	local px = sx * 34
	local secs = { { 11, 6 }, { 9.4, 12 }, { 8, 12 }, { 6.8, 10 }, { 5.6, 8 } }
	local y = 15
	for i, s in ipairs(secs) do
		bx(zig, "Pylon", s[1], s[2], s[1], CFrame.new(W(px, y + s[2] / 2, -170)), shade(IRON_M, 0.85 + i * 0.07))
		bx(zig, "PylonBand", s[1] + 0.8, 0.9, s[1] + 0.8, CFrame.new(W(px, y + s[2], -170)), IRON_L)
		neon(zig, "PylonSeam", Vector3.new(0.3, s[2] * 0.8, 0.3), CFrame.new(W(px - sx * (s[1] / 2 + 0.05), y + s[2] / 2, -170 + s[1] / 2 - 0.4)), CYAN, 0.25)
		neon(zig, "PylonSeam", Vector3.new(0.3, s[2] * 0.8, 0.3), CFrame.new(W(px - sx * (s[1] / 2 + 0.05), y + s[2] / 2, -170 - s[1] / 2 + 0.4)), CYAN, 0.25)
		y = y + s[2]
	end
	-- цапфа: массивный вал от башни к чаше + кольцо с огнём
	bx(zig, "Trunnion", 9, 5.2, 5.2, CFrame.new(W(sx * 29.5, CRUC_C[2], -170)), IRON_L)
	bx(zig, "TrunnionHub", 3.2, 8, 8, CFrame.new(W(sx * 25.6, CRUC_C[2], -170)), shade(IRON_L, 1.2))
	neon(zig, "TrunnionGlow", Vector3.new(0.5, 6, 6), CFrame.new(W(sx * 24.2, CRUC_C[2], -170)), CYAN, 0.2)
	neon(zig, "TrunnionCore", Vector3.new(0.6, 2.6, 2.6), CFrame.new(W(sx * 24.0, CRUC_C[2], -170)), WHITE)
end

-- Цепи, уходящие в небо (звенья чередуются плоскостями)
local function bigChain(parent, p0, p1, linkLen, w)
	local d = p1 - p0
	local n = math.floor(d.Magnitude / linkLen)
	local dir = d.Unit
	local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(p0, p0 + dir, up)
	for i = 0, n do
		local cf = base * CFrame.new(0, 0, -i * linkLen) * CFrame.Angles(0, 0, (i % 2) * math.pi / 2)
		bx(parent, "Link", w * 0.28, w, linkLen * 1.28, cf, shade(IRON_L, 0.8))
		bx(parent, "LinkBar", w * 0.28, w * 0.9, linkLen * 0.3, cf * CFrame.new(0, 0, linkLen * 0.45), IRON_M)
	end
end
local chF = folder("Chains", cruc)
for _, sx in ipairs({ -1, 1 }) do
	bigChain(chF, W(sx * 34, 70, -170), W(sx * 46, 190, -205), 3.4, 2.4)
	bigChain(chF, W(sx * 30, 70, -178), W(sx * 20, 190, -230), 3.4, 2.4)
end

---------------------------------------------------------------- КАСКАД ДУШ, ЖИЛЫ ПАМЯТИ, АЛТАРЬ
-- Каскад: из носика чаши по ярусам зиккурата. Светящиеся полотна + катсцена роняет сверху кубики.
local casF = folder("Cascade", cruc)
local lip = (CR * CFrame.new(0, -0.9, RIM_R + 0.6)).Position - ORIGIN
local function sheetV(name, x, w, yTop, yBot, z)
	local h = yTop - yBot
	neon(casF, name, Vector3.new(w, h, 0.5), CFrame.new(W(x, yBot + h / 2, z)), CYAN, 0.45)
	neon(casF, name .. "Mid", Vector3.new(w * 0.62, h, 0.62), CFrame.new(W(x, yBot + h / 2, z + 0.06)), PALE, 0.28)
	neon(casF, name .. "Core", Vector3.new(w * 0.26, h, 0.72), CFrame.new(W(x, yBot + h / 2, z + 0.1)), WHITE, 0.12)
end
local function sheetH(name, w, z0, z1, y)
	local d = math.abs(z1 - z0)
	local zc = (z0 + z1) / 2
	neon(casF, name, Vector3.new(w, 0.3, d), CFrame.new(W(0, y, zc)), CYAN, 0.4)
	neon(casF, name .. "Core", Vector3.new(w * 0.4, 0.4, d), CFrame.new(W(0, y + 0.05, zc)), WHITE, 0.2)
end
sheetV("Fall1", 0, 9, lip.Y, 10.05, lip.Z + 0.35)
sheetH("Flow2", 11, lip.Z, -149.9, 10.1)
sheetV("Fall2", 0, 12, 10, 5.05, -149.7)
sheetH("Flow1", 14, -149.7, -139.9, 5.1)
sheetV("Fall3", 0, 16, 5, 0.05, -139.7)
sheetH("Pool", 20, -139.7, -131, 0.08)
-- боковые «стенки» русла
for _, sx in ipairs({ -1, 1 }) do
	bx(casF, "Bank", 1.2, 5, 10, CFrame.new(W(sx * 8.5, 7.5, -144.9)), IRON_L)
	bx(casF, "Bank", 1.2, 5, 9.4, CFrame.new(W(sx * 10.4, 2.5, -135)), IRON_L)
end
-- источники света у каскада и в чаше (PointLight; Neon сам соседей не освещает)
local function lampAt(name, x, y, z, color, br, rg)
	local p = mk(casF, name, Vector3.new(1, 1, 1), CFrame.new(W(x, y, z)), Color3.new(0, 0, 0), false, 1)
	light(p, color, br, rg)
	return p
end
lampAt("LampPool", 0, 3.5, -134, CYAN, 3.2, 52)
lampAt("LampFall", 0, 9, -146, CYAN, 3.0, 44)
lampAt("LampLip", 0, lip.Y + 2, lip.Z + 3, WHITE, 2.4, 55)
lampAt("LampBowl", 0, CRUC_C[2] + 6, CRUC_C[3] - 3, CYAN, 3.2, 60)
lampAt("LampRimL", -22, CRUC_C[2] + 6, CRUC_C[3] + 4, GOLD, 1.0, 30)
lampAt("LampRimR", 22, CRUC_C[2] + 6, CRUC_C[3] + 4, GOLD, 1.0, 30)

-- Алтарь и жилы: свет течёт по полу от каскада к пустому клинку
local DAIS = { 0, -108 }
local veinF = folder("Veins", stage)
local function vein(x0, z0, x1, z1, bend, wd)
	local n = 16
	local px, pz
	local mx, mz = (x0 + x1) / 2 + bend, (z0 + z1) / 2
	for i = 0, n do
		local t = i / n
		local x = (1 - t) ^ 2 * x0 + 2 * (1 - t) * t * mx + t ^ 2 * x1
		local z = (1 - t) ^ 2 * z0 + 2 * (1 - t) * t * mz + t ^ 2 * z1
		if px then
			local dx, dz = x - px, z - pz
			local len = math.sqrt(dx * dx + dz * dz)
			local flick = math.random() < 0.2
			neon(veinF, "Vein", Vector3.new(wd, 0.08, len + 0.15), CFrame.lookAt(W((x + px) / 2, 0.05, (z + pz) / 2), W(x, 0.05, z)), flick and WHITE or CYAN, 0.15)
		end
		px, pz = x, z
	end
end
vein(0, -131, 0, -120, 0, 1.0)
for k = 1, 5 do
	local sx = (k - 3) * 3.6
	local a = rad(-90 + (k - 3) * 17)
	vein(sx, -131, DAIS[1] + math.cos(a + math.pi) * 0 + (k - 3) * 4.0, -121 + math.abs(k - 3) * 0.8, (k - 3) * 6, 0.55)
end
-- руническое кольцо вокруг алтаря
do
	local ringF = folder("RuneRing", stage)
	local R = 12.5
	local glyphs = {
		{ "X.X", ".X.", "XXX" }, { "XXX", "X.X", ".X." }, { ".X.", "XXX", "X.X" }, { "X..", "XXX", "..X" },
		{ "XX.", ".XX", "X.X" }, { "X.X", "XXX", ".X." }, { ".XX", "X..", "XXX" }, { "XXX", ".X.", "X.X" },
	}
	for i = 0, 63 do
		local a = i / 64 * math.pi * 2
		neon(ringF, "RuneSeg", Vector3.new(0.5, 0.1, 1.2), CFrame.new(W(DAIS[1] + math.cos(a) * R, 0.06, DAIS[2] + math.sin(a) * R)) * CFrame.Angles(0, -a + math.pi / 2, 0), CYAN, 0.25)
	end
	for i = 0, 39 do
		local a = i / 40 * math.pi * 2
		neon(ringF, "RuneSeg2", Vector3.new(0.3, 0.1, 0.9), CFrame.new(W(DAIS[1] + math.cos(a) * (R - 2.2), 0.06, DAIS[2] + math.sin(a) * (R - 2.2))) * CFrame.Angles(0, -a + math.pi / 2, 0), DEEP, 0.2)
	end
	for g = 0, 7 do
		local a = (g + 0.5) / 8 * math.pi * 2
		local gx, gz = DAIS[1] + math.cos(a) * (R + 1.5), DAIS[2] + math.sin(a) * (R + 1.5)
		local pat = glyphs[g + 1]
		for r = 1, 3 do
			for c = 1, 3 do
				if pat[r]:sub(c, c) == "X" then
					neon(ringF, "Glyph", Vector3.new(0.36, 0.1, 0.36), CFrame.new(W(gx, 0.07, gz)) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new((c - 2) * 0.45, 0, (r - 2) * 0.45), WHITE, 0.1)
				end
			end
		end
	end
	local rl = mk(ringF, "RuneLight", Vector3.new(1, 1, 1), CFrame.new(W(DAIS[1], 0.6, DAIS[2])), Color3.new(0, 0, 0), false, 1)
	light(rl, CYAN, 0.8, 26)
	-- контровой свет героя: две лампы за спиной (из глубины зала), чтобы он читался силуэтом с ободком света
	for _, sx in ipairs({ -1, 1 }) do
		local hr = mk(ringF, "HeroRim", Vector3.new(1, 1, 1), CFrame.new(W(4 + sx * 7, 8.5, -117)), Color3.new(0, 0, 0), false, 1)
		light(hr, Color3.fromRGB(150, 225, 255), 1.5, 24)
	end
end
-- плита-ложе под пустой клинок: врезана в пол (верх ниже ножен гарды), по краям светятся желобки
do
	local pl = folder("BladeBed", stage)
	bx(pl, "BedBase", 11.4, 0.12, 3.6, CFrame.new(W(2.2, 0.06, -108)), IRON_D)
	bx(pl, "BedPlate", 10.6, 0.14, 2.9, CFrame.new(W(2.2, 0.07, -108)), shade(IRON_M, 1.1))
	for _, sz in ipairs({ -1, 1 }) do
		neon(pl, "BedEdge", Vector3.new(10.6, 0.06, 0.12), CFrame.new(W(2.2, 0.15, -108 + sz * 1.5)), CYAN, 0.35)
	end
	neon(pl, "BedEdgeEnd", Vector3.new(0.12, 0.06, 2.9), CFrame.new(W(-3.1, 0.15, -108)), CYAN, 0.35)
	neon(pl, "BedEdgeEnd", Vector3.new(0.12, 0.06, 2.9), CFrame.new(W(7.5, 0.15, -108)), CYAN, 0.35)
end

---------------------------------------------------------------- СТОЛБ СВЕТА, КОЛЕСО КЛИНКОВ, ЗВЁЗДЫ, ОБЛОМКИ МИРА
local skyF = folder("Sky", stage)
-- Столб света из чаши в небо (катсцена роняет в него кубики; имя SoulBeam оставлено для совместимости)
local beamF = folder("SoulBeam", stage)
neon(beamF, "BeamShell", Vector3.new(15, 230, 15), CFrame.new(W(0, 41 + 115, -171)), CYAN, 0.9)
neon(beamF, "BeamMid", Vector3.new(7, 230, 7), CFrame.new(W(0, 41 + 115, -171)), PALE, 0.75)
neon(beamF, "BeamCore", Vector3.new(2.6, 230, 2.6), CFrame.new(W(0, 41 + 115, -171)), WHITE, 0.3)
mk(stage, "BeamBase", Vector3.new(1, 1, 1), CFrame.new(W(0, 43, -170)), Color3.new(0, 0, 0), false, 1)

-- Колесо Клинков: два кольца, вращаются вокруг центра чаши (в катсцене). Центр — невидимая деталь-ось.
local function glassSword(parent, cf, len, w, col)
	col = col or Color3.fromRGB(70, 150, 235)
	neon(parent, "Body", Vector3.new(w, len, 0.5), cf * CFrame.new(0, len / 2 + 0.8, 0), col, 0.35)
	neon(parent, "Fuller", Vector3.new(w * 0.16, len * 0.9, 0.58), cf * CFrame.new(0, len / 2 + 0.9, 0), WHITE, 0.25)
	diamond(parent, "Tip", w * 0.7, 0.46, cf * CFrame.new(0, len + 0.8 + w * 0.1, 0), col, true, 0.35)
	bx(parent, "Guard", w * 2.2, 0.9, 1.0, cf * CFrame.new(0, 0.4, 0), IRON_M)
	bx(parent, "Grip", 0.6, 2.2, 0.6, cf * CFrame.new(0, -1.0, 0), IRON_D)
end
local wheelF = folder("Wheel", stage)
local function wheel(name, center, tiltX, tiltZ, r0, count, len, w)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = wheelF
	local base = CFrame.new(W(center[1], center[2], center[3])) * CFrame.Angles(rad(tiltX), 0, rad(tiltZ))
	local pivot = mk(m, "Pivot", Vector3.new(1, 1, 1), base, Color3.new(0, 0, 0), false, 1)
	m.PrimaryPart = pivot
	for i = 0, count - 1 do
		local a = i / count * 2 * math.pi
		-- кольцо лежит в плоскости XY (нормаль Z); клинки смотрят остриём наружу
		local cf = base * CFrame.Angles(0, 0, a) * CFrame.new(0, r0, 0)
		glassSword(m, cf, len * rnd(0.85, 1.15), w)
	end
	-- обод кольца
	for i = 0, count * 2 - 1 do
		local a = (i + 0.5) / (count * 2) * 2 * math.pi
		bx(m, "Rim", 2.4, 1.6, 2 * math.pi * r0 / (count * 2) * 1.05, base * CFrame.Angles(0, 0, a) * CFrame.new(0, r0 - 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0), IRON_M)
	end
	return m
end
wheel("WheelA", { 0, 46, -186 }, 0, 0, 40, 30, 20, 3.4)
wheel("WheelB", { 0, 46, -176 }, 0, 0, 30, 20, 11, 2.2)

-- Звёзды: россыпь неоновых кубиков купола; чем дальше, тем крупнее (в тумане дальние глохнут)
local starF = folder("Stars", skyF)
local STAR_COLS = { WHITE, WHITE, CYAN, CYAN, VIOLET, PALE, GOLD_W }
for i = 1, 1900 do
	local az = rnd(0, 2 * math.pi)
	local el = math.asin(rnd(0.07, 1) ^ 0.8)
	local R = rnd(120, 250)
	local x, y, z = math.cos(el) * math.cos(az) * R, math.sin(el) * R - 6, -130 + math.cos(el) * math.sin(az) * R
	local s = (0.25 + math.random() ^ 3 * 1.5) * R / 140
	neon(starF, "Star", Vector3.new(s, s, s), CFrame.new(W(x, y, z)) * CFrame.Angles(rnd(0, 3), rnd(0, 3), rnd(0, 3)), STAR_COLS[math.random(#STAR_COLS)])
end
-- Обломки мира: куски зала плавают вокруг платформы (мы — на острове в пустоте)
local chunkF = folder("Chunks", skyF)
for i = 1, 70 do
	local side = (math.random() < 0.5) and -1 or 1
	local x = side * rnd(52, 150)
	local y = rnd(-40, 70)
	local z = rnd(-60, -230)
	local s = rnd(3, 13)
	local cf = CFrame.new(W(x, y, z)) * CFrame.Angles(rnd(0, 3), rnd(0, 3), rnd(0, 3))
	bx(chunkF, "Chunk", s, s * rnd(0.5, 1), s * rnd(0.6, 1), cf, shade(STONE_D, rnd(0.7, 1.3)))
	if math.random() < 0.4 then
		neon(chunkF, "ChunkVein", Vector3.new(s * 0.12, s * 0.7, 0.3), cf * CFrame.new(0, 0, s * 0.35), CYAN, 0.3)
	end
end

---------------------------------------------------------------- МИКРОДЕТАЛИ (папка Detail)
-- Тысячи мелких блоков: кладка стен, сталактиты коридора, щебень.
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
	-- зал: боковые стены (внутренняя грань x=±44); выше обрушенной кромки кладку не рисуем
	local function wallTop(side, z)
		local zi = -74 - math.floor((-74 - z) / 6 + 0.5) * 6
		return 12 + 16 * math.abs(math.sin(zi * 0.37 + side))
	end
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 520 * MQ do
			local z = rnd(-72, -146)
			local top = wallTop(side, z)
			local s = rnd(0.6, 1.7)
			micro(wallF, side * (43.7 - rnd(0, 0.6)), rnd(0.3, top), z, rnd(0.5, 1.1), s * rnd(0.6, 1), s, STONE)
		end
	end
	-- вход в зал: передняя стена вокруг проёма коридора
	for i = 1, 70 * MQ do
		local s = rnd(0.6, 1.5)
		local x = rnd(9.5, 43)
		if math.random() < 0.5 then x = -x end
		local top = 10 + 14 * math.abs(math.sin(math.floor(x / 6 + 0.5) * 6 * 0.29))
		micro(wallF, x, rnd(0.3, top), -70.2 - rnd(0, 0.6), s, s * rnd(0.6, 1), rnd(0.5, 1.1), STONE)
	end
	-- потолок коридора и сталактиты (зал без потолка: над ним небо)
	for i = 1, 40 * MQ do
		local s = rnd(0.5, 1.3)
		micro(wallF, rnd(-6.5, 6.5), 14.9 - rnd(0, 0.5), rnd(10, -70), s, rnd(0.4, 0.9), s * rnd(0.6, 1), STONE, 0.4, 0.9)
	end
	local stal = folder("Stalactites", det)
	local function stalactite(x, yTop, z, s0)
		local y, s = yTop, s0
		for k = 1, math.random(3, 5) do
			micro(stal, x + rnd(-0.1, 0.1), y - s / 2, z + rnd(-0.1, 0.1), s, s, s, STONE, 0.5, 1.0)
			y = y - s
			s = s * rnd(0.62, 0.78)
		end
	end
	for i = 1, 20 * MQ do stalactite(rnd(-6.5, 6.5), 14.9, rnd(8, -69), rnd(0.8, 1.4)) end
	-- щебень и трещины пола; дорожку света и алтарь не загромождаем
	local deb = folder("Debris", det)
	for i = 1, 90 * MQ do
		local s = rnd(0.15, 0.7)
		micro(deb, rnd(-6.5, 6.5), s / 2, rnd(9, -69), s, s, s, STONE, 0.6, 1.0)
	end
	for i = 1, 170 * MQ do
		local s = rnd(0.2, 1.0)
		local x, z = rnd(-43, 43), rnd(-74, -139)
		if not (math.abs(x) < 17 and z < -92) then
			micro(deb, x, s / 2, z, s, s, s, STONE, 0.6, 1.0)
		end
	end
	for i = 1, 14 * MQ do
		local x, z = rnd(-42, 42), rnd(-76, -138)
		if not (math.abs(x) < 17 and z < -92) then
			neon(deb, "FloorCrack", Vector3.new(rnd(0.08, 0.14), 0.05, rnd(0.8, 2.6)),
				CFrame.new(W(x, 0.03, z)) * CFrame.Angles(0, rad(rnd(0, 180)), 0), CYAN, 0.35)
		end
	end
	print("[BuildIntroStage] микродеталей: " .. made)
end
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
	-- остриё: ромб, как у настоящего клинка (а не две ступеньки)
	diamond(m, "Tip1", bw * 0.98, 0.4, cf * CFrame.new(0, -(h + bw * 0.2), 0), GLASS, true, 0.5)
	-- железная рама по бокам и по рёбрам: стекло — это сосуд, а не плита
	for _, sx in ipairs({ -1, 1 }) do
		bx(m, "Rail", 0.2, len + 0.2, 0.6, cf * CFrame.new(sx * (bw / 2 + 0.06), 0, 0), IRON_L)
		bx(m, "RailEdge", 0.08, len * 0.96, 0.66, cf * CFrame.new(sx * (bw / 2 + 0.17), 0, 0), shade(IRON_L, 1.6))
	end
	for i = -1, 1 do
		bx(m, "Rib", bw + 0.3, 0.14, 0.5, cf * CFrame.new(0, i * len * 0.27, 0), IRON_M)
	end
	-- гарда: центральный брусок и два «крыла», загнутых к острию
	bx(m, "Guard", bw + 0.5, 0.42, 0.9, cf * CFrame.new(0, h + 0.2, 0), IRON_M)
	for _, sx in ipairs({ -1, 1 }) do
		bx(m, "Wing", 0.9, 0.3, 0.8, cf * CFrame.new(sx * (bw / 2 + 0.7), h + 0.45, 0) * CFrame.Angles(0, 0, sx * rad(24)), IRON_L)
		neon(m, "WingGem", Vector3.new(0.16, 0.16, 0.2), cf * CFrame.new(sx * (bw / 2 + 0.95), h + 0.6, 0), CYAN)
	end
	bx(m, "Handle", 0.5, 1.7, 0.5, cf * CFrame.new(0, h + 1.35, 0), IRON_D)
	for i = 0, 3 do
		bx(m, "Wrap", 0.58, 0.14, 0.58, cf * CFrame.new(0, h + 0.75 + i * 0.42, 0), IRON_L)
	end
	bx(m, "Pommel", 0.8, 0.6, 0.8, cf * CFrame.new(0, h + 2.4, 0), IRON_M)
	neon(m, "PommelGem", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0, h + 2.4, 0.4), CYAN)
	human(m, cf * CFrame.new(0, -len * 0.3, 0), len / 9, d)
	local l = light(body, CYAN, brightness or 1.6, 16)
	l.Name = "Light"
	m.PrimaryPart = body
	m:SetAttribute("Phase", rnd(0, 6.28))
	return m
end

-- процессия парящих клинков: две колонны по бокам от осевой дорожки тянутся к Горнилу (души ждут переплавки)
local d_pattern = { 0, 1, 0, 2, 0, 3, 1, 0 }
for i = 0, 15 do
	local side = (i % 2 == 0) and -1 or 1
	local row = math.floor(i / 2)
	local x = side * (15 + (row % 3) * 3.4) + rnd(-1, 1)
	local z = -84 - row * 7.2
	local y = 12 + ((row * 3) % 5) * 2.4
	local cf = CFrame.new(W(x, y, z)) * CFrame.Angles(rad(rnd(-5, 5)), rad(rnd(-35, 35)) + (side < 0 and 0 or 0), rad(rnd(-5, 5)))
	glassBlade("Blade" .. (i + 1), cf, 6 + (i % 3) * 0.8, d_pattern[i % #d_pattern + 1], 0.9)
end
-- обречённый клинок (шот 4): силуэт гаснет и рассыпается
glassBlade("DoomedBlade", CFrame.new(W(-4.4, 6.6, -108)), 8, 0, 3.5)

---------------------------------------------------------------- ПУСТОЙ КЛИНОК
-- Клинок — сосуд. Лезвие собрано из двух стальных направляющих и ПУСТОГО жёлоба между ними:
-- пока в клинке нет душ, сквозь жёлоб виден пол; душа заполняет жёлоб светом от гарды к острию.
-- У клинков с душами (стеклянные, на Колесе) жёлоб уже полон.
-- клинок лежит плашмя (широкой гранью вверх), остриём к -X: так он виден сверху и красиво наполняется
local FLOOR_CF = CFrame.new(W(4, 0.55, -108)) * CFrame.Angles(0, 0, rad(90)) * CFrame.Angles(0, rad(90), 0)
local blade = Instance.new("Model")
blade.Name = "EmptyBlade"
blade.Parent = stage
-- Локальные координаты (ось Y вдоль меча, начало — центр рукояти):
--   навершие y=-1.9, рукоять -1.35..1.35 (две ладони), гарда 1.55, жёлоб/лезвие 1.75..5.25, остриё до 5.95
do
	local cf = FLOOR_CF
	local STEEL_D = Color3.fromRGB(70, 76, 104)       -- тёмная сталь (не серая: в тон ночи)
	local STEEL_E = Color3.fromRGB(122, 134, 176)     -- светлая фаска: ловит свет, рисует форму
	local LEATHER = Color3.fromRGB(30, 26, 36)
	local WRAP = Color3.fromRGB(66, 56, 72)
	local INLAY = Color3.fromRGB(176, 138, 86)        -- тусклое золото
	local handle = mk(blade, "Handle", Vector3.new(0.5, 2.7, 0.5), cf, LEATHER)
	for i = -4, 4 do
		mk(blade, "Wrap", Vector3.new(0.58, 0.15, 0.58), cf * CFrame.new(0, i * 0.3, 0) * CFrame.Angles(0, 0, rad(i % 2 == 0 and 8 or -8)), WRAP)
	end
	-- навершие: кольцо с тёмным камнем; в катсцене камень разгорается вместе с клинком
	mk(blade, "Pommel", Vector3.new(0.84, 0.42, 0.84), cf * CFrame.new(0, -1.62, 0), STEEL_D)
	mk(blade, "PommelCrown", Vector3.new(0.56, 0.3, 0.56), cf * CFrame.new(0, -1.95, 0), shade(STEEL_D, 0.85))
	local gem = neon(blade, "PommelGem", Vector3.new(0.26, 0.26, 0.58), cf * CFrame.new(0, -1.62, 0), Color3.fromRGB(26, 62, 86))
	gem.Name = "PommelGem"
	-- гарда: тело + два крыла, загнутых к острию, золотая насечка
	mk(blade, "Guard", Vector3.new(1.0, 0.36, 0.86), cf * CFrame.new(0, 1.52, 0), STEEL_D)
	mk(blade, "GuardInlay", Vector3.new(0.5, 0.06, 0.9), cf * CFrame.new(0, 1.72, 0), INLAY)
	for _, sx in ipairs({ -1, 1 }) do
		mk(blade, "GuardWing", Vector3.new(0.98, 0.28, 0.78), cf * CFrame.new(sx * 0.9, 1.6, 0) * CFrame.Angles(0, 0, sx * rad(24)), STEEL_D)
		mk(blade, "GuardTip", Vector3.new(0.32, 0.5, 0.7), cf * CFrame.new(sx * 1.32, 1.84, 0) * CFrame.Angles(0, 0, sx * rad(24)), shade(STEEL_D, 1.2))
		mk(blade, "GuardEdge", Vector3.new(0.9, 0.06, 0.82), cf * CFrame.new(sx * 0.88, 1.73, 0) * CFrame.Angles(0, 0, sx * rad(24)), STEEL_E)
	end
	-- лезвие: две направляющие, фаски, поперечные рёбра, сужающееся остриё
	for _, sx in ipairs({ -1, 1 }) do
		mk(blade, "Rail", Vector3.new(0.22, 3.5, 0.34), cf * CFrame.new(sx * 0.315, 3.5, 0), STEEL_D)
		mk(blade, "Bevel", Vector3.new(0.07, 3.46, 0.2), cf * CFrame.new(sx * 0.455, 3.5, 0), STEEL_E)
		for i = 0, 5 do
			mk(blade, "Rune", Vector3.new(0.08, 0.16, 0.36), cf * CFrame.new(sx * 0.315, 2.1 + i * 0.55, 0), INLAY)
		end
		mk(blade, "TipRail", Vector3.new(0.2, 0.86, 0.32), cf * CFrame.new(sx * 0.17, 5.68, 0) * CFrame.Angles(0, 0, sx * rad(-14)), STEEL_D)
	end
	for i = 0, 5 do
		mk(blade, "Rib", Vector3.new(0.6, 0.1, 0.28), cf * CFrame.new(0, 2.1 + i * 0.6, 0), STEEL_D)
	end
	mk(blade, "TipCap", Vector3.new(0.34, 0.5, 0.3), cf * CFrame.new(0, 5.98, 0), STEEL_E)
	mk(blade, "Blade", Vector3.new(0.3, 3.4, 0.2), cf * CFrame.new(0, 3.5, 0), STEEL_D, false, 1)   -- невидимый центр лезвия: сюда летят души и «сидит» гул
	-- сколы и трещины: клинок давно пуст
	mk(blade, "Chip", Vector3.new(0.14, 0.3, 0.38), cf * CFrame.new(0.43, 4.2, 0), Color3.fromRGB(14, 14, 22))
	mk(blade, "Chip", Vector3.new(0.12, 0.24, 0.38), cf * CFrame.new(-0.43, 2.9, 0), Color3.fromRGB(14, 14, 22))
	mk(blade, "Crack", Vector3.new(0.05, 0.6, 0.36), cf * CFrame.new(0.3, 3.3, 0) * CFrame.Angles(0, 0, rad(24)), Color3.fromRGB(12, 12, 20))
	-- свечение жёлоба: невидимо, пока клинок пуст; катсцена открывает его по мере наполнения
	local g = neon(blade, "BladeGlow", Vector3.new(0.36, 3.4, 0.24), cf * CFrame.new(0, 3.5, 0), CYAN, 1)
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
shot("Shot3B", { -9, 15, -104 }, { 0, 27, -168 })    -- выход в зал: взгляд вверх, на Горнило и Колесо Клинков
shot("Shot4A", { -1.6, 7.0, -96.0 }, { -4.4, 6.3, -108 })     -- стеклянный клинок в анфас: силуэт крупно, пока память гниёт
shot("Shot4B", { 1.4, 5.8, -99.0 }, { 0.8, 3.2, -108 })  -- обречённый клинок и пустой клинок на полу в одном кадре
shot("Shot4C", { 3.2, 4.2, -103.2 }, { 2.0, 0.6, -108 })    -- сверху на пустой клинок: жёлоб наполняется светом
shot("Shot5A", { 8.6, 3.4, -100.2 }, { 4.4, 2.2, -109 })   -- пустой клинок на полу, рука тянется к рукояти
shot("Shot5B", { 5.2, 7.2, -102.0 }, { 4.2, 7.1, -110 })     -- подъём к лицу героя
shot("Shot6A", { 3.2, 5.0, -97 }, { 4, 8.4, -108 })           -- клинок в центре кадра
shot("Shot6B", { 0.2, 6.2, -78 }, { 3.9, 9.2, -108 })            -- отъезд

marker("BladeFloor", FLOOR_CF)
marker("BladeRaised", CFrame.new(W(5.3, 4.3, -108.9)) * CFrame.Angles(0, 0, rad(-6)))
marker("BladeCenter", CFrame.new(W(4, 9.6, -107.8)))
marker("CrumbleSource", CFrame.new(W(-4.4, 6.2, -108)))

-- мелочь (кирпичики стен, щебень, звёзды) не отбрасывает тень: на глаз это незаметно, а теневой проход дешевле на треть
do
	local lit = 0
	for _, o in ipairs(stage:GetDescendants()) do
		if o:IsA("BasePart") and o.CastShadow then
			local sz = o.Size
			if math.max(sz.X, sz.Y, sz.Z) < 1.0 then
				o.CastShadow = false
			else
				lit = lit + 1
			end
		end
	end
	print(("[BuildIntroStage] деталей, отбрасывающих тень: %d"):format(lit))
end

CHS:SetWaypoint("BuildIntroStage")
print(("[BuildIntroStage] готово: %d деталей в сцене, %d точек камеры. Сцена в точке %s."):format(
	#stage:GetDescendants(), #cam:GetChildren(), tostring(ORIGIN)))
