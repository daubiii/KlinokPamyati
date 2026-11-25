--!nonstrict
-- preview_enemy_prefabs.lua — превью префабов врагов в режиме Edit.
-- Кладёт в Workspace.AssetLab.EnemyPreview (x ≈ 3000) шесть врагов в два ряда:
-- ближний — Idle, дальний — последний кадр замаха основной атаки. В Edit
-- суставы не шагают, поэтому поза «запекается»: CFrame частей считаются по
-- Motor6D (Part0 · C0 · Transform · C1⁻¹), затем суставы снимаются, части
-- закрепляются. Удалить перед Ctrl+S (запуск с CLEAN = true).
-- Камера для снимка: из (3015, 6, -26) на (3015, 3.5, 6).

local CLEAN = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local lab = workspace:FindFirstChild("AssetLab")
if lab and lab:FindFirstChild("EnemyPreview") then
	lab.EnemyPreview:Destroy()
end
if CLEAN then
	return "убрано"
end

local original = ReplicatedStorage.Shared
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local animatorModule = StarterPlayer.StarterPlayerScripts.Controllers.EnemyAnimator:Clone()
animatorModule.Parent = workspace

local ROWS = {
	{ guard = "Idle", shade = "Idle", knight = "Idle", archer = "Idle", martyr = "Idle", gatekeeper = "Idle" },
	{ guard = "Slash_Windup", shade = "Dash_Windup", knight = "Slam_Windup", archer = "Shot_Windup", martyr = "Explode_Windup", gatekeeper = "Chains_Windup" },
}
local ORDER = { "guard", "shade", "knight", "archer", "martyr", "gatekeeper" }

local ok, err = pcall(function()
	local Anim = require(shared.Util.Anim)
	local Resolve = require(shared.Anim.Resolve)
	local EnemyVisuals = require(shared.Config.EnemyVisuals)
	local EnemyAnimator = require(animatorModule)
	if not lab then
		lab = Instance.new("Folder")
		lab.Name = "AssetLab"
		lab.Parent = workspace
	end
	local holder = Instance.new("Folder")
	holder.Name = "EnemyPreview"
	holder.Parent = lab

	local function bake(model: Model, pose)
		local scale = model:GetScale()
		local motors = {}
		local welds = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				table.insert(motors, d)
			elseif d:IsA("WeldConstraint") then
				table.insert(welds, { weld = d, offset = d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame) })
			end
		end
		local codeOf = {}
		for code, name in pairs(EnemyAnimator.MOTORS) do
			codeOf[name] = code
		end
		-- Считаем всё в таблицу: в Edit установка CFrame одной части тянет
		-- за собой всю сборку. Обход от корня: Part1 — когда Part0 готов.
		local targets = { [model.PrimaryPart] = model.PrimaryPart.CFrame }
		local pending = #motors + #welds
		local guard = 0
		while pending > 0 and guard < 64 do
			guard += 1
			for _, motor in ipairs(motors) do
				if not targets[motor.Part1] and targets[motor.Part0] then
					local code = codeOf[motor.Name]
					local t = code and EnemyAnimator.jointCFrame(pose, code, scale) or CFrame.identity
					targets[motor.Part1] = targets[motor.Part0] * motor.C0 * t * motor.C1:Inverse()
					pending -= 1
				end
			end
			for _, entry in ipairs(welds) do
				local weld = entry.weld
				if not targets[weld.Part1] and targets[weld.Part0] then
					targets[weld.Part1] = targets[weld.Part0] * entry.offset
					pending -= 1
				end
			end
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
		for part, cf in pairs(targets) do
			part.Anchored = true
			part.CFrame = cf
		end
	end

	for row, names in ipairs(ROWS) do
		local x = 3000
		for _, typeId in ipairs(ORDER) do
			local set = Resolve.forSet(EnemyVisuals.Types[typeId].set)
			local anim = set[names[typeId]]
			local pose = {}
			Anim.sample(anim.frames, anim.length, pose)
			local model = ReplicatedStorage.EnemyPrefabs[typeId]:Clone()
			local width = typeId == "gatekeeper" and 10 or 5.5
			x += width / 2
			model:PivotTo(CFrame.new(x, 2.6 * model:GetScale(), (row - 1) * 14))
			model.Parent = holder
			bake(model, pose)
			x += width / 2 + 1
		end
	end
end)

animatorModule:Destroy()
shared:Destroy()
original.Name = "Shared"
if not ok then
	return "ОШИБКА: " .. tostring(err)
end
return "превью: Workspace.AssetLab.EnemyPreview"
