--!nonstrict
-- HeroArmorBuilder (общий: сервер и превью в Studio)
-- Броня героя-воина из мешей (tools/hero-armor, map/hero_armor.glb).
-- По комплекту и слоту клонирует MeshPart из ReplicatedStorage.HeroArmorMeshes
-- и приваривает к частям тела R15:
--   helm  — шлем (Head);
--   armor — всё остальное и плащ.
-- Плащ — цепочка сегментов: UpperTorso → Cape1 → Cape2 … на Motor6D с именами
-- "CapeJoint1".."CapeJointN" (атрибут CapeIndex). Их Transform каждый кадр
-- пишет CapeController на клиенте; сервер оставляет плащ в позе покоя.
--
-- Нет папки или хотя бы одного меша слота → available() = false, и
-- AppearanceService строит этот слот по-старому из Part'ов.
-- Размер частей тела: всё масштабируется по Part.Size.Y / refY из
-- HeroArmorMeshData, так что броня садится и на увеличенного героя.
-- Атрибут папки ImportYaw = 180 — поправка, если Import 3D развернул меши.
-- У отдельного меша свой атрибут ImportYaw главнее папкиного (меши мага
-- из mage_armor.glb уже повёрнуты при экспорте, AssembleMageArmor ставит 0).
--
-- Маг: комплекты Хронистов (шляпа = helm, накидка = armor) лежат в
-- Config/MageArmorMeshData и подмешиваются к комплектам воина; меши —
-- в той же папке HeroArmorMeshes (имена HA_<набор>_… не пересекаются).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DATA = require(Shared.Config.HeroArmorMeshData)

-- Комплекты мага: необязательный модуль (без него — только воин).
do
	local mageModule = Shared.Config:FindFirstChild("MageArmorMeshData")
	local ok, mage = false, nil
	if mageModule then
		ok, mage = pcall(require, mageModule)
	end
	if ok and type(mage) == "table" and type(mage.sets) == "table" then
		for setId, set in pairs(mage.sets) do
			if DATA.sets[setId] == nil then
				set.class = "mage"
				DATA.sets[setId] = set
			end
		end
	end
end

-- Комплекты этажей 2–5 (воин и маг, tools/armor-floors): тоже необязательный
-- модуль. Меши — в той же папке HeroArmorMeshes (AssembleArmorFloors.lua).
-- Пока меши этажа не импортированы, available() = false и облик собирается
-- из Part'ов по Config/ArmorFloors (style).
do
	local floorsModule = Shared.Config:FindFirstChild("ArmorFloorsMeshData")
	local ok, floors = false, nil
	if floorsModule then
		ok, floors = pcall(require, floorsModule)
	end
	if ok and type(floors) == "table" and type(floors.sets) == "table" then
		for setId, set in pairs(floors.sets) do
			if DATA.sets[setId] == nil then
				DATA.sets[setId] = set
			end
		end
	end
end

local HeroArmorBuilder = {}

HeroArmorBuilder.FolderName = "HeroArmorMeshes"
HeroArmorBuilder.Data = DATA

local function meshFolder()
	return ReplicatedStorage:FindFirstChild(HeroArmorBuilder.FolderName)
end

local function has(folder, name: string): boolean
	local found = folder:FindFirstChild(name)
	return found ~= nil and found:IsA("MeshPart")
end

-- Все меши слота на месте? Для armor проверяется и плащ.
function HeroArmorBuilder.available(setId: string?, slot: string): boolean
	local folder = meshFolder()
	local set = setId and DATA.sets[setId]
	if not folder or not set then
		return false
	end
	for _, object in ipairs(set[slot] or {}) do
		if not has(folder, object.name) then
			return false
		end
	end
	if slot == "armor" then
		for _, segment in ipairs(set.cape or {}) do
			if not has(folder, segment.name) then
				return false
			end
			for _, glow in ipairs(segment.glows) do
				if not has(folder, glow.name) then
					return false
				end
			end
		end
	end
	return true
end

-- Комплект мага (шляпа и накидка Хронистов)?
function HeroArmorBuilder.isMage(setId: string?): boolean
	local set = setId and DATA.sets[setId]
	return set ~= nil and set.class == "mage"
end

-- Цвета базовых блоков тела под броней (ткань, кожа, лицо) — как на рендерах комплекта.
function HeroArmorBuilder.bodyColors(setId: string?)
	local set = setId and DATA.sets[setId]
	return set and set.body or nil
end

local function scaleOf(part: BasePart): number
	local ref = DATA.refY[part.Name]
	if not ref or ref <= 0 then
		return 1
	end
	return part.Size.Y / ref
end

local function importFix(folder): CFrame
	return CFrame.Angles(0, math.rad(folder:GetAttribute("ImportYaw") or 0), 0)
end

local function place(folder, object, target: BasePart, scale: number, fix: CFrame, holder): MeshPart
	local source = folder[object.name]
	local ownYaw = source:GetAttribute("ImportYaw")
	if ownYaw ~= nil then
		fix = CFrame.Angles(0, math.rad(ownYaw), 0)
	end
	local part = source:Clone()
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	part.Name = object.name
	part.Size = object.size * scale
	part.CFrame = target.CFrame * CFrame.new(object.offset * scale) * fix
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	if object.glow then
		part.TextureID = ""
		part.Material = Enum.Material.Neon
		part.Color = object.glow
		part.CastShadow = false
	else
		part.Material = Enum.Material.SmoothPlastic
		part.CastShadow = object.size.Magnitude * scale > 0.6
	end
	part:SetAttribute("HeroArmor", true)
	part.Parent = holder
	return part
end

local function weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part1
end

-- Плащ: сегменты сверху вниз, каждый на Motor6D к предыдущему. C0/C1 — шарнир
-- у верхней кромки сегмента в осях UpperTorso (поворот шарнира — вокруг его X).
local function buildCape(folder, holder, upper: BasePart, cape, fix: CFrame)
	local scale = scaleOf(upper)
	local previous: BasePart = upper
	for index, segment in ipairs(cape) do
		local part = place(folder, segment, upper, scale, fix, holder)
		part:SetAttribute("CapeSegment", index)
		local hinge = upper.CFrame * CFrame.new(segment.hinge * scale)
		local joint = Instance.new("Motor6D")
		joint.Name = "CapeJoint" .. index
		joint.Part0 = previous
		joint.Part1 = part
		joint.C0 = previous.CFrame:ToObjectSpace(hinge)
		joint.C1 = part.CFrame:ToObjectSpace(hinge)
		joint:SetAttribute("CapeIndex", index)
		joint.Parent = part
		for _, glow in ipairs(segment.glows) do
			local glowPart = place(folder, glow, upper, scale, fix, holder)
			weld(part, glowPart)
		end
		previous = part
	end
	holder:SetAttribute("CapeSegments", #cape)
end

-- Собрать слот из мешей. parts: имя части R15 → BasePart. true — собрано.
function HeroArmorBuilder.buildSlot(holder, parts, setId: string?, slot: string): boolean
	if not HeroArmorBuilder.available(setId, slot) then
		return false
	end
	local folder = meshFolder()
	local set = DATA.sets[setId]
	local fix = importFix(folder)
	for _, object in ipairs(set[slot]) do
		local target = parts[object.part]
		if target then
			local part = place(folder, object, target, scaleOf(target), fix, holder)
			weld(target, part)
		end
	end
	if slot == "armor" and parts.UpperTorso and set.cape and #set.cape > 0 then
		buildCape(folder, holder, parts.UpperTorso, set.cape, fix)
	end
	return true
end

return HeroArmorBuilder
