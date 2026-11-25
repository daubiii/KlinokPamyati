--!nonstrict
-- AppearanceService (сервер)
-- Облик Пробуждённого (раздел 6): воксельный воин вместо аватара Roblox.
-- Аксессуары, одежда и лицо снимаются, округлые части тела R15 прячутся,
-- а поверх каждой кладётся блок — персонаж становится «кубическим», как
-- весь мир. Сверху — надетая броня (ArmorService): шлем собирается по
-- стилю шлема, корпус, наплечники, плащ и поножи — по стилю доспеха
-- (Config/Armor.Styles). Глаза в визоре всегда голубые: герой сам и есть
-- воспоминание.
--
-- Читаемость силуэта (правка «вялые текстуры»): у каждой крупной пластины
-- есть тёмная кромка-фаска, у металла — свой материал и лёгкий блеск, у
-- ткани и кожи — свои материалы. Так доспех читается и на закате, и в тени.
--
-- Маг (комплекты Хронистов, Config/Armor class = "mage"): шляпа и лёгкая
-- накидка с плащом — из мешей (MageArmorMeshData), а без мешей — запасной
-- облик из Part'ов (mageHat/mageRobe). Ноги, кисти и почти все руки открыты:
-- виден основной облик героя (цвета body комплекта).
--
-- Всё приваривается к частям тела WeldConstraint'ами, без массы и коллизий:
-- штатные анимации и наши процедурные позы двигают доспех вместе с телом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)
local Armor = require(Shared.Config.Armor)

local heroOk, HeroArmorBuilder = pcall(function()
	return require(Shared:WaitForChild("Voxel"):WaitForChild("HeroArmorBuilder", 5))
end)
if not heroOk or type(HeroArmorBuilder) ~= "table" then
	warn("[AppearanceService] HeroArmorBuilder недоступен, броня из Part'ов: " .. tostring(HeroArmorBuilder))
	HeroArmorBuilder = nil
end

local AppearanceService = {}

-- Подставляет ArmorService: player -> { helm = setId, armor = setId }.
AppearanceService.lookProvider = nil

local Env = Palette.Env
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local FOLDER = "VoxelBody"

-- Материал по имени с запасным вариантом: в старых сборках Studio
-- некоторых материалов (Leather) может не быть.
local function material(name: string, fallback: Enum.Material): Enum.Material
	local ok, value = pcall(function()
		return Enum.Material[name]
	end)
	return ok and value or fallback
end

local MAT = {
	metal = Enum.Material.Metal,
	metalWorn = Enum.Material.DiamondPlate,
	cloth = Enum.Material.Fabric,
	leather = material("Leather", Enum.Material.Fabric),
	plain = Enum.Material.SmoothPlastic,
	glow = Enum.Material.Neon,
}

local function styleOf(setId: string?)
	return Armor.Styles[setId or ""] or Armor.Styles[Armor.StarterSet]
end

local function piece(holder, target: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?, reflect: number?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = target.CFrame * offset
	part.Color = color
	part.Material = mat or MAT.plain
	part.Reflectance = reflect or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = size.Magnitude > 0.6
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = holder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = target
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Металлическая пластина с тёмной кромкой снизу: даёт объём без текстур.
local function plate(holder, target, name, size, offset, look, colorKey)
	local color = look[colorKey or "steel"]
	piece(holder, target, name, size, offset, color, MAT.metal, 0.06)
	piece(holder, target, name .. "Edge", V3(size.X * 1.02, math.min(size.Y * 0.14, 0.12), size.Z * 1.02),
		offset * CF(0, -size.Y / 2, 0), look.steelDark, MAT.metal, 0.02)
end

local SIGILS = {
	memory = { "00100", "01110", "10101", "01110", "00100" },
	anvil = { "10001", "11011", "01110", "11111", "00100" },
	gate = { "11111", "10001", "10101", "10101", "10101" },
	shard = { "00100", "01110", "11111", "01110", "00100" },
	key = { "01110", "01000", "01100", "01000", "11100" },
}

local function voxelSigil(holder, target, size, look)
	local pattern = SIGILS[look.sigil]
	if not pattern then
		return
	end
	local cell = math.min(size.X * 0.055, size.Y * 0.055, 0.11)
	local front = -size.Z * 0.52 - 0.17
	piece(holder, target, "SigilPlate", V3(cell * 5.4, cell * 5.4, 0.07),
		CF(0, -size.Y * 0.13, front), look.steelDark, MAT.metal)
	for row, line in ipairs(pattern) do
		for column = 1, #line do
			if line:sub(column, column) ~= "0" then
				local x = (column - 3) * cell
				local y = -size.Y * 0.13 + (3 - row) * cell
				piece(holder, target, "SigilPixel", V3(cell * 0.78, cell * 0.78, 0.08),
					CF(x, y, front - 0.06), look.accent or look.trim, MAT.metal, 0.08)
			end
		end
	end
end

-- Снять всё «аватарное»: аксессуары, одежду, лицо, меши R6.
local function strip(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
	local head = character:FindFirstChild("Head")
	if head then
		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
end

local BODY = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- Базовый блок на месте части тела: ткань поддоспешника, кожа, сталь.
local function baseColor(name: string, look, meshBody)
	if meshBody then
		if name == "Head" then
			return meshBody.skin, MAT.plain
		elseif name:match("Hand$") or name:match("Foot$") or name:match("LowerArm$") then
			return meshBody.leather, MAT.leather
		end
		return meshBody.cloth, MAT.cloth
	end
	if name == "Head" then
		return Env.bone:Lerp(Env.sand, 0.5), MAT.plain
	elseif name:match("Hand$") or name:match("Foot$") or name:match("LowerArm$") then
		return look.leather, MAT.leather
	elseif name:match("LowerLeg$") then
		return look.steelDark, MAT.metal
	end
	return look.cloth, MAT.cloth
end

-- ===== Шлемы =====
local Helms = {}

-- Общая основа: закрытый шлем, визор-щель и голубые глаза.
local function helmBase(holder, head, h, look)
	plate(holder, head, "Helm", V3(h * 1.08, h * 1.04, h * 1.08), CF(0, h * 0.02, 0), look)
	piece(holder, head, "HelmBrow", V3(h * 1.14, h * 0.18, h * 1.14), CF(0, h * 0.2, 0), look.steelDark, MAT.metal, 0.03)
	piece(holder, head, "HelmChin", V3(h * 0.7, h * 0.3, 0.1), CF(0, -h * 0.3, -h * 0.55), look.steelDark, MAT.metal)
	piece(holder, head, "Visor", V3(h * 0.78, h * 0.15, 0.08), CF(0, h * 0.02, -h * 0.55), Env.void)
	for _, sx in ipairs({ -1, 1 }) do
		local eye = piece(holder, head, "Eye", V3(h * 0.17, h * 0.1, 0.06), CF(sx * h * 0.19, h * 0.02, -h * 0.59), look.eye, MAT.glow)
		-- Мягкое свечение глаз: видно героя в тёмной комнате.
		if sx == 1 then
			local light = Instance.new("PointLight")
			light.Color = look.eye
			light.Brightness = 0.6
			light.Range = 4
			light.Shadows = false
			light.Parent = eye
		end
	end
end

Helms.open = function(holder, head, h, look)
	helmBase(holder, head, h, look)
	piece(holder, head, "HelmCrest", V3(h * 0.16, h * 0.28, h * 1.0), CF(0, h * 0.6, 0.02), look.trim, MAT.metal, 0.1)
	piece(holder, head, "Plume", V3(h * 0.14, h * 0.75, h * 0.14), CF(0, h * 0.35, h * 0.6) * ANG(math.rad(-25), 0, 0), look.clothLight, MAT.cloth)
end

-- Шишак с полями: ржавый страж.
Helms.kettle = function(holder, head, h, look)
	helmBase(holder, head, h, look)
	plate(holder, head, "Brim", V3(h * 1.5, h * 0.1, h * 1.5), CF(0, h * 0.42, 0), look)
	piece(holder, head, "Dome", V3(h * 0.8, h * 0.22, h * 0.8), CF(0, h * 0.62, 0), look.steel, MAT.metalWorn)
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, head, "Rivet", V3(0.09, 0.09, 0.09), CF(sx * h * 0.45, h * 0.3, -h * 0.55), look.trim, MAT.metal, 0.1)
	end
end

-- Шлем стражи ворот: высокий гребень цвета янтаря.
Helms.crested = function(holder, head, h, look)
	helmBase(holder, head, h, look)
	piece(holder, head, "CrestBase", V3(h * 0.22, h * 0.14, h * 1.1), CF(0, h * 0.56, 0), look.steelDark, MAT.metal)
	for index = 0, 4 do
		local z = -h * 0.42 + index * h * 0.22
		piece(holder, head, "Crest", V3(h * 0.12, h * (0.36 + 0.08 * math.sin(index)), h * 0.2), CF(0, h * 0.78, z), look.clothLight, MAT.cloth)
	end
	for _, sx in ipairs({ -1, 1 }) do
		plate(holder, head, "Cheek", V3(0.1, h * 0.55, h * 0.5), CF(sx * h * 0.58, -h * 0.12, -h * 0.2), look)
	end
end

-- Рогатый шлем тени.
Helms.horned = function(holder, head, h, look)
	helmBase(holder, head, h, look)
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, head, "HornBase", V3(h * 0.22, h * 0.22, h * 0.22), CF(sx * h * 0.6, h * 0.34, 0), look.trim, MAT.metal, 0.08)
		piece(holder, head, "Horn", V3(h * 0.14, h * 0.5, h * 0.14), CF(sx * h * 0.78, h * 0.62, 0.05) * ANG(0, 0, -sx * math.rad(28)), look.trim, MAT.metal, 0.08)
		piece(holder, head, "HornTip", V3(h * 0.08, h * 0.26, h * 0.08), CF(sx * h * 0.82, h * 0.95, 0.12) * ANG(math.rad(-15), 0, sx * math.rad(10)), look.steelDark, MAT.metal)
	end
	piece(holder, head, "Spine", V3(h * 0.1, h * 0.2, h * 0.9), CF(0, h * 0.62, 0.05), look.steelDark, MAT.metal)
end

-- Венец Привратника: зубцы короны и замочная скважина во лбу.
Helms.crown = function(holder, head, h, look)
	helmBase(holder, head, h, look)
	piece(holder, head, "CrownBand", V3(h * 1.18, h * 0.16, h * 1.18), CF(0, h * 0.46, 0), look.trim, MAT.metal, 0.15)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local tall = index % 2 == 0 and 0.3 or 0.18
		piece(holder, head, "CrownTooth", V3(h * 0.16, h * tall, h * 0.08),
			CF(math.sin(angle) * h * 0.56, h * (0.54 + tall / 2), math.cos(angle) * h * 0.56) * ANG(0, angle, 0), look.trim, MAT.metal, 0.15)
	end
	piece(holder, head, "Keyhole", V3(h * 0.12, h * 0.2, 0.06), CF(0, h * 0.34, -h * 0.6), Env.void)
end

-- ===== Корпус =====
local Chests = {}

local function chestBase(holder, upper, size, look)
	plate(holder, upper, "Breastplate", V3(size.X * 0.9, size.Y * 0.62, 0.22), CF(0, size.Y * 0.12, -size.Z * 0.52), look)
	piece(holder, upper, "Backplate", V3(size.X * 0.84, size.Y * 0.56, 0.14), CF(0, size.Y * 0.12, size.Z * 0.5), look.steelDark, MAT.metal)
	-- Шарф вокруг шеи.
	piece(holder, upper, "Scarf", V3(size.X * 0.82, size.Y * 0.2, size.Z * 1.15), CF(0, size.Y * 0.44, 0), look.clothLight, MAT.cloth)
end

Chests.plate = function(holder, upper, size, look)
	chestBase(holder, upper, size, look)
	piece(holder, upper, "BreastTrim", V3(size.X * 0.14, size.Y * 0.5, 0.1), CF(0, size.Y * 0.1, -size.Z * 0.66), look.trim, MAT.metal, 0.1)
	piece(holder, upper, "ScarfTail", V3(size.X * 0.2, size.Y * 0.7, 0.12), CF(size.X * 0.18, size.Y * 0.05, size.Z * 0.6) * ANG(math.rad(10), 0, math.rad(-6)), look.clothLight, MAT.cloth)
end

Chests.riveted = function(holder, upper, size, look)
	chestBase(holder, upper, size, look)
	for row = 0, 1 do
		for col = -1, 1 do
			piece(holder, upper, "Rivet", V3(0.1, 0.1, 0.08), CF(col * size.X * 0.3, size.Y * (0.34 - row * 0.36), -size.Z * 0.66), look.trim, MAT.metal, 0.12)
		end
	end
	piece(holder, upper, "Strap", V3(size.X * 0.16, size.Y * 0.95, 0.06), CF(-size.X * 0.2, size.Y * 0.05, -size.Z * 0.65) * ANG(0, 0, math.rad(-30)), look.leather, MAT.leather)
end

Chests.tabard = function(holder, upper, size, look)
	chestBase(holder, upper, size, look)
	piece(holder, upper, "Tabard", V3(size.X * 0.5, size.Y * 1.25, 0.06), CF(0, -size.Y * 0.18, -size.Z * 0.66), look.clothLight, MAT.cloth)
	piece(holder, upper, "TabardBand", V3(size.X * 0.52, size.Y * 0.08, 0.07), CF(0, size.Y * 0.1, -size.Z * 0.68), look.trim, MAT.metal, 0.1)
	piece(holder, upper, "Gorget", V3(size.X * 0.7, size.Y * 0.16, size.Z * 1.05), CF(0, size.Y * 0.5, 0), look.steel, MAT.metal, 0.06)
end

Chests.spiked = function(holder, upper, size, look)
	chestBase(holder, upper, size, look)
	piece(holder, upper, "Ridge", V3(size.X * 0.1, size.Y * 0.56, 0.12), CF(0, size.Y * 0.12, -size.Z * 0.68), look.trim, MAT.metal, 0.08)
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, upper, "Rib", V3(size.X * 0.3, 0.08, 0.08), CF(sx * size.X * 0.22, size.Y * 0.0, -size.Z * 0.66) * ANG(0, 0, sx * math.rad(15)), look.trim, MAT.metal)
	end
end

Chests.keyhole = function(holder, upper, size, look)
	chestBase(holder, upper, size, look)
	piece(holder, upper, "Lock", V3(size.X * 0.42, size.Y * 0.42, 0.1), CF(0, size.Y * 0.14, -size.Z * 0.66), look.trim, MAT.metal, 0.18)
	piece(holder, upper, "KeyholeTop", V3(size.X * 0.1, size.Y * 0.1, 0.06), CF(0, size.Y * 0.2, -size.Z * 0.72), Env.void)
	piece(holder, upper, "KeyholeSlot", V3(size.X * 0.05, size.Y * 0.16, 0.06), CF(0, size.Y * 0.08, -size.Z * 0.72), Env.void)
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, upper, "Chain", V3(size.X * 0.06, size.Y * 0.06, size.Z * 1.2), CF(sx * size.X * 0.32, size.Y * 0.38, 0), look.steelDark, MAT.metal, 0.05)
	end
	for index = -1, 1 do
		piece(holder, upper, "LockRivet", V3(0.07, 0.07, 0.06), CF(index * size.X * 0.28, size.Y * 0.14, -size.Z * 0.69), look.accent or look.trim, MAT.metal, 0.12)
	end
end

-- ===== Плащ =====
local function cape(holder, upper, size, look, kind: string)
	if kind == "none" then
		return
	end
	local base = kind == "long" and 2.2 or kind == "short" and 1.3 or 1.9
	for index = -2, 2 do
		local ragged = kind == "tattered" and ((index * 5) % 3) * 0.12 or 0
		local length = size.Y * (base - math.abs(index) * 0.18 + ragged)
		local color = index % 2 == 0 and look.clothLight or look.clothLight:Lerp(look.cloth, 0.35)
		local offset = CF(index * size.X * 0.19, size.Y * 0.42 - length / 2, size.Z * 0.6) * ANG(math.rad(6), 0, 0)
		piece(holder, upper, "Cape", V3(size.X * 0.2, length, 0.1),
			offset, color, MAT.cloth)
		piece(holder, upper, "CapeHem", V3(size.X * 0.2, 0.1, 0.12),
			offset * CF(0, -length * 0.46, -0.015), look.accent or look.trim, MAT.cloth)
	end
	-- Застёжки плаща.
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, upper, "Clasp", V3(0.16, 0.16, 0.12), CF(sx * size.X * 0.36, size.Y * 0.4, -size.Z * 0.5), look.trim, MAT.metal, 0.15)
	end
end

-- ===== Маг: запасной облик из Part'ов =====
-- Шляпа: поля, лента, тулья из 4 ступеней с изломом назад, тень полей на лице
-- и светящиеся глаза под ними.
local function mageHat(holder, head, h, look)
	piece(holder, head, "HatShade", V3(h * 0.94, h * 0.3, 0.06), CF(0, h * 0.2, -h * 0.52), Env.void, MAT.plain)
	for _, sx in ipairs({ -1, 1 }) do
		piece(holder, head, "Eye", V3(h * 0.12, h * 0.09, 0.05), CF(sx * h * 0.17, h * 0.1, -h * 0.56), look.eye, MAT.glow)
	end
	piece(holder, head, "HairL", V3(0.1, h * 0.55, h * 0.9), CF(-h * 0.53, h * 0.12, 0.04), Env.void:Lerp(Env.woodDark, 0.4), MAT.cloth)
	piece(holder, head, "HairR", V3(0.1, h * 0.55, h * 0.9), CF(h * 0.53, h * 0.12, 0.04), Env.void:Lerp(Env.woodDark, 0.4), MAT.cloth)
	local ragged = look.hat == "ragged"
	local brim = ragged and 2.1 or look.hat == "tall" and 1.75 or 1.9
	local brimTilt = ragged and ANG(math.rad(-6), 0, math.rad(3)) or ANG(math.rad(-3), 0, 0)
	piece(holder, head, "HatBrim", V3(h * brim, h * 0.1, h * brim), CF(0, h * 0.44, 0) * brimTilt, look.hatColor, MAT.cloth)
	piece(holder, head, "HatBrimEdge", V3(h * (brim + 0.06), h * 0.05, h * (brim + 0.06)), CF(0, h * 0.39, 0) * brimTilt, look.hatColor:Lerp(Env.void, 0.45), MAT.cloth)
	piece(holder, head, "HatBand", V3(h * 1.2, h * 0.16, h * 1.2), CF(0, h * 0.56, 0), look.band, MAT.cloth)
	local height = h * (look.hatHeight or 1)
	local steps = 4
	local y = h * 0.64
	for index = 1, steps do
		local t = (index - 1) / steps
		local w = h * (1.12 - 0.82 * t)
		local stepH = height / steps
		local bend = (t * t) * h * 0.35
		local tilt = ANG(math.rad(-10 * t), 0, math.rad(6 * t))
		piece(holder, head, "HatCrown" .. index, V3(w, stepH * 1.05, w), CF(0, y + stepH / 2, bend) * tilt, look.hatColor, MAT.cloth)
		y += stepH * 0.95
	end
	piece(holder, head, "HatTip", V3(h * 0.22, h * 0.36, h * 0.22), CF(h * 0.08, y + h * 0.08, h * 0.42) * ANG(math.rad(-55), 0, math.rad(-12)), look.hatColor, MAT.cloth)
	if look.hat == "star" or look.hat == "archive" or ragged then
		for index = 1, 5 do
			local a = index * 2.4
			piece(holder, head, "HatStar", V3(0.08, 0.08, 0.05), CF(math.cos(a) * h * 0.4, h * 0.75 + index * height * 0.12, -math.abs(math.sin(a)) * h * 0.36 - 0.05),
				look.glow or look.trim, MAT.glow)
		end
	end
	if look.hat == "archive" then
		piece(holder, head, "HatGem", V3(h * 0.2, h * 0.2, 0.1), CF(0, h * 0.56, -h * 0.62), look.glow or look.trim, MAT.glow)
		piece(holder, head, "HatFinial", V3(h * 0.14, h * 0.3, h * 0.14), CF(0, y + h * 0.1, 0), look.trim, MAT.metal, 0.15)
	end
	if look.hat == "tall" then
		piece(holder, head, "HatFeather", V3(0.08, h * 0.7, h * 0.18), CF(-h * 0.58, h * 0.85, h * 0.1) * ANG(math.rad(20), 0, math.rad(12)), Env.bone, MAT.cloth)
	end
end

-- Накидка: пелерина на плечах, наплечная ткань, обшлага, кушак, плащ сзади.
local function mageRobe(holder, parts, look)
	local upper = parts.UpperTorso
	if upper then
		local size = upper.Size
		piece(holder, upper, "Mantle", V3(size.X * 1.12, size.Y * 0.36, size.Z * 1.2), CF(0, size.Y * 0.33, 0), look.mantle, MAT.cloth)
		piece(holder, upper, "MantleTrim", V3(size.X * 1.14, size.Y * 0.06, size.Z * 1.22), CF(0, size.Y * 0.14, 0), look.trim, MAT.cloth)
		piece(holder, upper, "Collar", V3(size.X * 0.62, size.Y * 0.16, size.Z * 1.05), CF(0, size.Y * 0.54, 0.02), look.mantle:Lerp(Env.void, 0.25), MAT.cloth)
		piece(holder, upper, "Clasp", V3(0.2, 0.2, 0.1), CF(0, size.Y * 0.3, -size.Z * 0.62), look.glow or look.trim, look.glow and MAT.glow or MAT.metal, 0.12)
		local length = size.Y * (look.capeLength or 1.2)
		for index = -2, 2 do
			local ragged = look.hat == "ragged" and ((index * 7) % 3) * 0.1 or 0
			local segLength = length * (1 - math.abs(index) * 0.06 - ragged)
			local offset = CF(index * size.X * 0.19, size.Y * 0.38 - segLength / 2, size.Z * 0.62) * ANG(math.rad(5), 0, 0)
			local shade = index % 2 == 0 and look.capeColor or look.capeColor:Lerp(Env.void, 0.2)
			piece(holder, upper, "Cape", V3(size.X * 0.2, segLength, 0.1), offset, shade, MAT.cloth)
			piece(holder, upper, "CapeHem", V3(size.X * 0.2, 0.08, 0.12), offset * CF(0, -segLength * 0.47, -0.015), look.trim, MAT.cloth)
		end
	end
	local lower = parts.LowerTorso
	if lower then
		local size = lower.Size
		piece(holder, lower, "Sash", V3(size.X * 1.08, size.Y * 0.62, size.Z * 1.1), CF(0, 0, 0), look.band, MAT.cloth)
		piece(holder, lower, "SashKnot", V3(0.22, 0.2, 0.12), CF(size.X * 0.28, 0, -size.Z * 0.58), look.trim, MAT.cloth)
		piece(holder, lower, "SashTail", V3(0.12, size.Y * 1.6, 0.06), CF(size.X * 0.3, -size.Y * 0.9, -size.Z * 0.6) * ANG(0, 0, math.rad(-6)), look.band, MAT.cloth)
		piece(holder, lower, "Pouch", V3(0.3, 0.34, 0.24), CF(-size.X * 0.56, -size.Y * 0.4, 0), Env.wood, MAT.leather)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local sx = side == "Left" and -1 or 1
		local upperArm = parts[side .. "UpperArm"]
		if upperArm then
			local size = upperArm.Size
			piece(holder, upperArm, "Drape", V3(size.X * 1.22, size.Y * 0.32, size.Z * 1.22), CF(sx * 0.03, size.Y * 0.35, 0), look.mantle, MAT.cloth)
			piece(holder, upperArm, "DrapeTrim", V3(size.X * 1.24, size.Y * 0.06, size.Z * 1.24), CF(sx * 0.03, size.Y * 0.18, 0), look.trim, MAT.cloth)
		end
		local lowerArm = parts[side .. "LowerArm"]
		if lowerArm then
			local size = lowerArm.Size
			piece(holder, lowerArm, "Cuff", V3(size.X * 1.16, size.Y * 0.26, size.Z * 1.16), CF(0, -size.Y * 0.26, 0), look.mantle, MAT.cloth)
			piece(holder, lowerArm, "CuffTrim", V3(size.X * 1.18, size.Y * 0.06, size.Z * 1.18), CF(0, -size.Y * 0.4, 0), look.trim, MAT.cloth)
		end
	end
end

local function build(character, lookIds)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = FOLDER
	holder.Parent = character

	lookIds = lookIds or {}
	local helmLook = styleOf(lookIds.helm)
	local look = styleOf(lookIds.armor)
	local helmId = lookIds.helm or Armor.StarterSet
	local armorId = lookIds.armor or Armor.StarterSet
	local meshHelm = HeroArmorBuilder ~= nil and HeroArmorBuilder.available(helmId, "helm")
	local meshArmor = HeroArmorBuilder ~= nil and HeroArmorBuilder.available(armorId, "armor")
	local meshBody = meshArmor and HeroArmorBuilder.bodyColors(armorId) or nil
	-- Маг: основной облик героя открыт — цвета тела из комплекта и без мешей.
	if not meshBody and look.mage and HeroArmorBuilder ~= nil then
		meshBody = HeroArmorBuilder.bodyColors(armorId)
	end

	local parts = {}
	for _, name in ipairs(BODY) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			parts[name] = part
			part.Transparency = 1
			-- Блок на месте части тела, чуть шире, чтобы стыки не светились.
			local size = part.Size
			local scale = name == "Head" and V3(1.0, 1.0, 1.0) or V3(1.04, 1.0, 1.04)
			if name == "Head" then
				size = V3(1.15, 1.15, 1.15) * (size.Y / 1.2)
			end
			local color, mat = baseColor(name, look, meshBody)
			piece(holder, part, "Body_" .. name, size * scale, CFrame.identity, color, mat)
		end
	end

	-- ===== Шлем =====
	local head = parts.Head
	if head then
		if not (meshHelm and HeroArmorBuilder.buildSlot(holder, parts, helmId, "helm")) then
			local h = 1.15 * (head.Size.Y / 1.2)
			if helmLook.mage then
				mageHat(holder, head, h, helmLook)
			else
				local builder = Helms[helmLook.helm] or Helms.open
				builder(holder, head, h, helmLook)
			end
		end
	end

	local robeDone = meshArmor and HeroArmorBuilder.buildSlot(holder, parts, armorId, "armor")
	if not robeDone and look.mage then
		mageRobe(holder, parts, look)
		robeDone = true
	end
	if not robeDone then
		-- ===== Корпус =====
		local upper = parts.UpperTorso
		if upper then
			local size = upper.Size
			local builder = Chests[look.chest] or Chests.plate
			builder(holder, upper, size, look)
			voxelSigil(holder, upper, size, look)
			cape(holder, upper, size, look, look.cape or "tattered")
		end
		local lower = parts.LowerTorso
		if lower then
			local size = lower.Size
			piece(holder, lower, "Belt", V3(size.X * 1.08, size.Y * 0.7, size.Z * 1.1), CF(0, 0, 0), look.leather, MAT.leather)
			piece(holder, lower, "Buckle", V3(size.X * 0.22, size.Y * 0.6, 0.1), CF(0, 0, -size.Z * 0.58), look.trim, MAT.metal, 0.15)
			for _, sx in ipairs({ -1, 1 }) do
				plate(holder, lower, "Tasset", V3(size.X * 0.38, size.Y * 1.5, 0.15), CF(sx * size.X * 0.24, -size.Y * 0.9, -size.Z * 0.5), look, "steelDark")
				piece(holder, lower, "TassetStripe", V3(size.X * 0.08, size.Y * 0.82, 0.06),
					CF(sx * size.X * 0.24, -size.Y * 0.9, -size.Z * 0.58), look.accent or look.trim, MAT.metal, 0.08)
			end
			piece(holder, lower, "BeltCharm", V3(0.12, 0.2, 0.08), CF(size.X * 0.34, -size.Y * 0.18, -size.Z * 0.58), look.accent or look.trim, MAT.metal, 0.08)
		end

		-- ===== Руки =====
		local p = look.pauldron or 1
		for _, side in ipairs({ "Left", "Right" }) do
			local sx = side == "Left" and -1 or 1
			local upperArm = parts[side .. "UpperArm"]
			if upperArm then
				local size = upperArm.Size
				plate(holder, upperArm, "Pauldron", V3(size.X * 1.45 * p, size.Y * 0.42, size.Z * 1.45 * p), CF(sx * 0.05 * p, size.Y * 0.32, 0), look)
				plate(holder, upperArm, "PauldronShell", V3(size.X * 1.08 * p, size.Y * 0.22, size.Z * 0.55 * p),
					CF(sx * 0.05 * p, size.Y * 0.4, -size.Z * 0.45), look, "steelDark")
				piece(holder, upperArm, "PauldronTop", V3(size.X * 1.2 * p, size.Y * 0.18, size.Z * 1.2 * p), CF(sx * 0.05 * p, size.Y * 0.58, 0), look.steelDark, MAT.metal)
				piece(holder, upperArm, "PauldronTrim", V3(size.X * 1.5 * p, size.Y * 0.08, size.Z * 1.5 * p), CF(sx * 0.05 * p, size.Y * 0.1, 0), look.trim, MAT.metal, 0.12)
				for index = -1, 1 do
					piece(holder, upperArm, "PauldronStud", V3(0.08, 0.08, 0.08),
						CF(sx * size.X * 0.05 * p, size.Y * 0.31, index * size.Z * 0.38), look.accent or look.trim, MAT.metal, 0.1)
				end
				if look.chest == "spiked" then
					piece(holder, upperArm, "Spike", V3(0.14, size.Y * 0.4, 0.14), CF(sx * size.X * 0.55, size.Y * 0.72, 0) * ANG(0, 0, -sx * math.rad(25)), look.trim, MAT.metal, 0.08)
					piece(holder, upperArm, "SpikeSmall", V3(0.1, size.Y * 0.28, 0.1), CF(sx * size.X * 0.42, size.Y * 0.67, size.Z * 0.35) * ANG(0, 0, -sx * math.rad(18)), look.accent or look.trim, MAT.metal, 0.08)
				end
			end
			local lowerArm = parts[side .. "LowerArm"]
			if lowerArm then
				local size = lowerArm.Size
				piece(holder, lowerArm, "Bracer", V3(size.X * 1.15, size.Y * 0.6, size.Z * 1.15), CF(0, -size.Y * 0.1, 0), look.leatherLight, MAT.leather)
				piece(holder, lowerArm, "BracerBand", V3(size.X * 1.2, size.Y * 0.12, size.Z * 1.2), CF(0, size.Y * 0.15, 0), look.steelDark, MAT.metal, 0.05)
				piece(holder, lowerArm, "BracerPlate", V3(size.X * 0.78, size.Y * 0.48, size.Z * 0.12),
					CF(0, -size.Y * 0.08, -size.Z * 0.56), look.steel, MAT.metal, 0.05)
				for index = -1, 1 do
					piece(holder, lowerArm, "BracerRivet", V3(0.07, 0.07, 0.06),
						CF(index * size.X * 0.24, -size.Y * 0.08, -size.Z * 0.64), look.accent or look.trim, MAT.metal, 0.1)
				end
			end
		end

		-- ===== Ноги =====
		for _, side in ipairs({ "Left", "Right" }) do
			local lowerLeg = parts[side .. "LowerLeg"]
			if lowerLeg then
				local size = lowerLeg.Size
				plate(holder, lowerLeg, "Greave", V3(size.X * 1.12, size.Y * 0.75, size.Z * 1.12), CF(0, -size.Y * 0.05, 0), look)
				piece(holder, lowerLeg, "Knee", V3(size.X * 1.18, size.Y * 0.22, size.Z * 1.25), CF(0, size.Y * 0.4, -0.05), look.steelDark, MAT.metal, 0.05)
				piece(holder, lowerLeg, "KneeBadge", V3(size.X * 0.32, size.Y * 0.16, 0.08),
					CF(0, size.Y * 0.4, -size.Z * 0.69), look.accent or look.trim, MAT.metal, 0.08)
				piece(holder, lowerLeg, "GreaveRidge", V3(size.X * 0.14, size.Y * 0.48, 0.08),
					CF(0, -size.Y * 0.05, -size.Z * 0.59), look.steel, MAT.metal, 0.04)
			end
			local foot = parts[side .. "Foot"]
			if foot then
				local size = foot.Size
				piece(holder, foot, "Boot", V3(size.X * 1.12, size.Y * 1.3, size.Z * 1.15), CF(0, size.Y * 0.1, -0.05), look.leather, MAT.leather)
				piece(holder, foot, "BootCuff", V3(size.X * 1.18, size.Y * 0.3, size.Z * 1.2), CF(0, size.Y * 0.6, 0), look.leatherLight, MAT.leather)
			end
		end
	end

	character:SetAttribute("VoxelBody", true)
	character:SetAttribute("ArmorLook", ("%s/%s"):format(lookIds.helm or "-", lookIds.armor or "-"))
	character:SetAttribute("ArmorMeshes", ("%s/%s"):format(meshHelm and "mesh" or "parts", meshArmor and "mesh" or "parts"))
end

local function lookFor(character)
	local player = Players:GetPlayerFromCharacter(character)
	if player and AppearanceService.lookProvider then
		local ok, look = pcall(AppearanceService.lookProvider, player)
		if ok and type(look) == "table" then
			return look
		end
	end
	return { helm = Armor.StarterSet, armor = Armor.StarterSet }
end

local function apply(character, look)
	strip(character)
	build(character, look or lookFor(character))
	-- Аксессуары аватара могут догрузиться позже: снимаем и их.
	if not character:GetAttribute("StripHooked") then
		character:SetAttribute("StripHooked", true)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") then
				task.defer(function()
					child:Destroy()
				end)
			end
		end)
	end
end

function AppearanceService.apply(character)
	apply(character)
end

-- Пересобрать облик (сменили броню). look = { helm = setId, armor = setId }.
function AppearanceService.refresh(character, look)
	if character and character.Parent and character:FindFirstChild("UpperTorso") then
		apply(character, look)
	end
end

function AppearanceService.start()
	-- Аватарную внешность не грузим вовсе: облик задаёт игра.
	StarterPlayer.LoadCharacterAppearance = false

	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			character:WaitForChild("UpperTorso", 5)
			task.wait(0.05)
			apply(character)
		end)
		if player.Character then
			task.spawn(apply, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	print("[AppearanceService] облик Пробуждённого по надетой броне")
end

return AppearanceService
