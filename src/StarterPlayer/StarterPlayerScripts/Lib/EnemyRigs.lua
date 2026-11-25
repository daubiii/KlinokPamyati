--!nonstrict
-- EnemyRigs (клиент)
-- Внешний вид врагов — воксельные модели, восстановленные по 8-ракурсным
-- спрайтам из assets (Shared/Data/MobVoxels, генерирует
-- tools/sprites/voxelize.py). Сервер про внешний вид не знает: у врага есть
-- только невидимая Root-часть, всё остальное рисует клиент.
--
-- Риг — иерархия узлов (суставов):
--   hips → torso → head, armR (→ handR), armL (→ handL);  hips → legR, legL
-- Узел поворачивается вокруг своей точки pivot; воксели приварены к
-- невидимой «кости» узла, поэтому в кадре двигаются только кости.
--
-- Система координат: начало — центр ступней, +Y вверх, враг смотрит в −Z.
-- Рука висит вниз; +X поднимает её вперёд.
--
-- Роли вокселей (EnemyVisualController знает, что с ними делать):
--   eye    глаза: тлеют, на замахе вспыхивают (первый — со светом)
--   weapon руки и оружие: на замахе светятся цветом подсказки
--   crack  лавовые трещины Треснувшего: разгораются к взрыву
--   rune   руна на щите Латника: пульсирует

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- По модулю на моба (Studio ограничивает длину скрипта), грузятся по требованию.
local MobVoxelsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("MobVoxels")
local MobVoxels = setmetatable({}, {
	__index = function(cache, kind)
		local module = MobVoxelsFolder:FindFirstChild(kind)
		local data = module and require(module) or false
		rawset(cache, kind, data)
		return data
	end,
})

local EnemyRigs = {}

local V3 = Vector3.new

-- Узлы и их родители. Порядок важен: родитель раньше потомка.
EnemyRigs.nodeOrder = { "hips", "torso", "head", "armR", "armL", "legR", "legL", "handR", "handL" }
EnemyRigs.parentOf = {
	hips = nil,
	torso = "hips",
	head = "torso",
	armR = "torso",
	armL = "torso",
	legR = "hips",
	legL = "hips",
	handR = "armR",
	handL = "armL",
}

-- Светящиеся роли — неон.
local GLOW = { eye = true, crack = true, rune = true }

-- Стойка вида (небольшой постоянный наклон поверх анимации).
local STANCE = {
	shade = { torso = V3(0.15, 0, 0) },
	archer = { armL = V3(0.25, 0, 0) },
}

local layouts = {}

-- Пропорции рига по данным модели.
local function layout(kind: string, data)
	local cached = layouts[kind]
	if cached then
		return cached
	end
	local legs, torso, head, core = data.legs, data.torso, data.head, data.core
	local armDrop = torso * 0.15
	local armLen = torso * 0.9
	local L = {
		H = legs + torso + head,
		legLen = legs,
		torsoH = torso,
		headS = head,
		armLen = armLen,
		bodyW = core * 2,
		stance = STANCE[kind] or {},
	}
	-- Точки суставов относительно родителя.
	L.pivot = {
		hips = V3(0, legs, 0),
		torso = V3(0, 0, 0),
		head = V3(0, torso, 0),
		armR = V3(core, torso - armDrop, 0),
		armL = V3(-core, torso - armDrop, 0),
		legR = V3(core * 0.5, 0, 0),
		legL = V3(-core * 0.5, 0, 0),
		handR = V3(0, -armLen, 0),
		handL = V3(0, -armLen, 0),
	}
	-- Те же точки в осях модели (поза покоя): от них считаются смещения вокселей.
	local absolute = {}
	for _, name in ipairs(EnemyRigs.nodeOrder) do
		local parent = EnemyRigs.parentOf[name]
		absolute[name] = (parent and absolute[parent] or Vector3.zero) + L.pivot[name]
	end
	L.absolute = absolute
	layouts[kind] = L
	return L
end

-- Описание рига: { parts, L }. Часть: node, size, offset (от кости узла),
-- color, material, role, light.
function EnemyRigs.describe(stats)
	local kind = stats.look and stats.look.kind or "guard"
	local data = MobVoxels[kind] or MobVoxels.guard
	local L = layout(kind, data)
	local parts = {}
	local litEye = false
	for _, box in ipairs(data.boxes) do
		local node = box[1]
		local center = V3(box[2], box[3], box[4])
		local role = box[9]
		local part = {
			node = node,
			size = V3(box[5], box[6], box[7]),
			offset = CFrame.new(center - L.absolute[node]),
			color = Color3.fromHex(box[8]),
			material = GLOW[role] and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			role = role,
		}
		if role == "eye" and not litEye then
			part.light = true
			litEye = true
		end
		table.insert(parts, part)
	end
	return parts, L
end

return EnemyRigs
