-- Превью врагов в режиме редактирования: все типы в ряд в стойке покоя.
-- Модели кладутся в Workspace.EnemyPreview (удалить перед сохранением).
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local original = RS:FindFirstChild("Shared")
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = RS
local rigsModule = SP.StarterPlayerScripts.Lib.EnemyRigs:Clone()
rigsModule.Parent = workspace

local ok, result = pcall(function()
	local Enemies = require(shared.Config.Enemies)
	local EnemyRigs = require(rigsModule)
	local old = workspace:FindFirstChild("EnemyPreview")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "EnemyPreview"
	folder.Parent = workspace

	local order = { "guard", "shade", "knight", "archer", "martyr", "gatekeeper" }
	local x = -22
	local counts = {}
	for _, typeId in ipairs(order) do
		local stats = Enemies.stats(typeId, "normal")
		local parts, L = EnemyRigs.describe(stats)
		local model = Instance.new("Model")
		model.Name = typeId
		local base = CFrame.lookAt(Vector3.new(x, 0, -30), Vector3.new(x, 0, -10))
		local nodes = {}
		for _, name in ipairs(EnemyRigs.nodeOrder) do
			local parentName = EnemyRigs.parentOf[name]
			local parentCF = parentName and nodes[parentName] or base
			local rotation = (L.stance and L.stance[name]) or Vector3.zero
			if name == "armR" or name == "armL" then
				rotation += Vector3.new(0, 0, name == "armR" and 0.06 or -0.06)
			end
			nodes[name] = parentCF * CFrame.new(L.pivot[name]) * CFrame.Angles(0, rotation.Y, 0) * CFrame.Angles(rotation.X, 0, rotation.Z)
		end
		for _, d in ipairs(parts) do
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = d.size
			part.Color = d.color
			part.Material = d.material
			part.Transparency = d.hidden and 1 or (d.transparency or 0)
			part.CFrame = nodes[d.node] * d.offset
			part.Parent = model
		end
		model.Parent = folder
		table.insert(counts, typeId .. "=" .. #parts)
		x += typeId == "martyr" and 14 or 8
	end
	return table.concat(counts, ", ")
end)

shared:Destroy()
original.Name = "Shared"
rigsModule:Destroy()
return ok and result or ("ERROR: " .. tostring(result))
