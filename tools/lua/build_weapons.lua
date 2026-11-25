--!nonstrict
-- build_weapons.lua — разовый скрипт первой сессии.
-- Запускается из моста (execute_luau, Edit): собирает набор оружия,
-- прогоняет самопроверку чисел из приложения Б и ставит витрину в Workspace.
-- Возвращает текстовый отчёт.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local VoxelWeaponBuilder = require(Shared.Voxel.VoxelWeaponBuilder)
local Weapons = require(Config.Weapons)
local Rarities = require(Config.Rarities)
local Palette = require(Config.Palette)

local report = {}
local failures = 0

local function check(label, actual, expected)
	local ok
	if type(expected) == "number" then
		ok = math.abs(actual - expected) < 1e-6
	else
		ok = actual == expected
	end
	if not ok then
		failures += 1
	end
	table.insert(report, ("  %s %-46s факт=%s ожидание=%s"):format(ok and "OK  " or "FAIL", label, tostring(actual), tostring(expected)))
end

table.insert(report, "1. Числа из приложения Б (эталонный воин, 1 этаж, уровень 5, урон класса 26)")
check("меч, обычное, без заточки", Weapons.damage(26, "sword", "common"), 26)
check("кинжал, обычное", Weapons.damage(26, "dagger", "common"), 18.2)
check("молот, обычное", Weapons.damage(26, "hammer", "common"), 41.6)
check("меч, легендарное", Weapons.damage(26, "sword", "legendary"), 30.68)
check("меч, обычное, заточка 10", Weapons.damage(26, "sword", "common", 10), 33.8)
check("заточенное обычное бьёт сильнее легендарного", Weapons.damage(26, "sword", "common", 10) > Weapons.damage(26, "sword", "legendary"), true)
check("секретное, множитель 1.25", Rarities.get("secret").damageMultiplier, 1.25)
check("цена заточки, шаг 1", Weapons.sharpeningCost(1), 60)
check("цена заточки, шаг 10", Weapons.sharpeningCost(10), 894)
local total = 0
for level = 1, 10 do
	total += Weapons.sharpeningCost(level)
end
check("вся лестница заточки", total, 3275)
check("кинжал быстрее меча", Weapons.attackInterval(1, "dagger") < Weapons.attackInterval(1, "sword"), true)
check("молот медленнее меча", Weapons.attackInterval(1, "hammer") > Weapons.attackInterval(1, "sword"), true)
check("редкость epic >= epic", Rarities.atLeast("epic", "epic"), true)
check("редкость rare < epic", Rarities.atLeast("rare", "epic"), false)
check("у эпического есть способность оружия", Rarities.get("epic").hasWeaponAbility, true)
check("у обычного нет способности оружия", Rarities.get("common").hasWeaponAbility, false)
check("голубой памяти = #6FE3FF", Palette.Memory, Color3.fromHex("#6FE3FF"))
check("этажей в палитре", #Palette.Floors, 5)

table.insert(report, "\n2. Воксельные модели")
local expectedVoxels = { sword = 33, dagger = 20, hammer = 37 }
for kind, expected in pairs(expectedVoxels) do
	local voxels = VoxelWeaponBuilder.voxelsFor(kind)
	check(("%s: вокселей"):format(kind), #voxels, expected)
end

local folder, built = VoxelWeaponBuilder.buildSet(ServerStorage)
table.insert(report, ("  %s: %s"):format(folder:GetFullName(), table.concat((function()
	local names = {}
	for _, model in pairs(built) do
		table.insert(names, ("%s (%d вокселей, %d детей)"):format(model.Name, model:GetAttribute("VoxelCount"), #model:GetChildren()))
	end
	table.sort(names)
	return names
end)(), ", ")))

table.insert(report, "\n3. Витрина в Workspace")
local showcase = Workspace:FindFirstChild("WeaponShowcase")
if showcase then
	showcase:Destroy()
end
showcase = Instance.new("Folder")
showcase.Name = "WeaponShowcase"
showcase.Parent = Workspace

local positions = {
	sword = Vector3.new(-3, 2, 0),
	dagger = Vector3.new(0, 2, 0),
	hammer = Vector3.new(3, 2, 0),
}
for kind, model in pairs(built) do
	local copy = model:Clone()
	copy.Name = "Showcase_" .. kind
	-- Сначала анкорим все части, только потом двигаем: PivotTo на модели со
	-- свободными (связанными weld'ом) частями двигает только Root, а остальные
	-- части подтягиваются физикой с задержкой.
	for _, descendant in ipairs(copy:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	copy:PivotTo(CFrame.new(positions[kind]) * CFrame.Angles(0, math.rad(-20), math.rad(8)))
	copy.Parent = showcase
end

-- Подставка, чтобы модельки читались на белом фоне.
local base = Instance.new("Part")
base.Name = "ShowcaseBase"
base.Anchored = true
base.Size = Vector3.new(16, 0.5, 8)
base.Position = Vector3.new(0, 0.25, 0)
base.Color = Palette.UI.panel
base.Material = Enum.Material.SmoothPlastic
base.Parent = showcase

table.insert(report, ("  витрина: %d объектов"):format(#showcase:GetChildren()))

table.insert(report, ("\nИТОГО: %s"):format(failures == 0 and "все проверки пройдены" or (failures .. " провалов")))
return table.concat(report, "\n")
