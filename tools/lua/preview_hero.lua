-- Превью героя в режиме редактирования: манекен R15 в облике Пробуждённого
-- и все восемь видов оружия этажа 1 рядом (Workspace.HeroPreview).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local original = RS:FindFirstChild("Shared")
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = RS
local appearance = game.ServerScriptService.Systems.AppearanceService:Clone()
appearance.Parent = workspace

local ok, result = pcall(function()
	local old = workspace:FindFirstChild("HeroPreview")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeroPreview"
	folder.Parent = workspace

	local rig = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Name = "Hero"
	rig:PivotTo(CFrame.lookAt(Vector3.new(0, 3, -20), Vector3.new(0, 3, -10)))
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
		end
	end
	rig.Parent = folder
	require(appearance).apply(rig)

	local Builder = require(shared.Voxel.VoxelWeaponBuilder)
	local hand = rig:FindFirstChild("RightHand")
	local held = Builder.build("sword", {
		name = "EquippedWeapon",
		weaponId = "rusty_sword",
		baseCFrame = CFrame.fromMatrix(hand.Position, hand.CFrame.RightVector, (hand.CFrame.LookVector + Vector3.new(0, 0.35, 0)).Unit),
		weldTarget = hand,
		parent = folder,
	})
	held.PrimaryPart.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = held.PrimaryPart
	weld.Parent = held.PrimaryPart

	local ids = { "rusty_sword", "iron_falchion", "forge_hammer", "guard_blade", "guard_hammer", "vortex_blade", "shattered_hammer", "gatekeeper_key" }
	local counts = {}
	for index, id in ipairs(ids) do
		local x = -15 + (index - 1) * 4.3
		local model = Builder.build(id:find("hammer") and "hammer" or "sword", {
			weaponId = id,
			anchored = true,
			parent = folder,
			baseCFrame = CFrame.new(x, 1.5, -14) * CFrame.Angles(0, math.pi, 0),
			rarityId = (index >= 8 and "legendary") or (index >= 6 and "epic") or nil,
		})
		model.Name = id
		table.insert(counts, id .. "=" .. model:GetAttribute("PartCount"))
	end
	return table.concat(counts, ", ")
end)

shared:Destroy()
original.Name = "Shared"
appearance:Destroy()
return ok and result or ("ERROR: " .. tostring(result))
