--!nonstrict
-- build_arena.lua — разовая сборка тестовой арены этапа 2.
-- Пол 40×40, стены, спавн. Запускается из моста, не входит в src/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local existing = Workspace:FindFirstChild("TestArena")
if existing then
	existing:Destroy()
end

local arena = Instance.new("Folder")
arena.Name = "TestArena"
arena.Parent = Workspace

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(40, 1, 40)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Color = Palette.Floors[1].colors[1]
floor.Material = Enum.Material.Slate
floor.Parent = arena

local wallColor = Palette.Floors[1].colors[2]
local walls = {
	{ Vector3.new(0, 2, -20), Vector3.new(40, 6, 1) },
	{ Vector3.new(0, 2, 20), Vector3.new(40, 6, 1) },
	{ Vector3.new(-20, 2, 0), Vector3.new(1, 6, 40) },
	{ Vector3.new(20, 2, 0), Vector3.new(1, 6, 40) },
}
for index, wall in ipairs(walls) do
	local part = Instance.new("Part")
	part.Name = "Wall" .. index
	part.Anchored = true
	part.Size = wall[2]
	part.Position = wall[1]
	part.Color = wallColor
	part.Material = Enum.Material.Slate
	part.Parent = arena
end

-- Витрина оружия уезжает в сторону, чтобы не мешать спавну.
local showcase = Workspace:FindFirstChild("WeaponShowcase")
if showcase then
	for _, model in ipairs(showcase:GetChildren()) do
		if model:IsA("Model") then
			model:PivotTo(model:GetPivot() + Vector3.new(0, 0, 32))
		end
	end
end

-- Спавн в центр арены.
local spawnLocation = Workspace:FindFirstChildOfClass("SpawnLocation")
if spawnLocation then
	spawnLocation.Position = Vector3.new(0, 0.5, 0)
	spawnLocation.Anchored = true
end

return ("арена собрана: %d частей, спавн на %s"):format(#arena:GetChildren(), tostring(spawnLocation and spawnLocation.Position))
