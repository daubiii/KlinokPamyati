--!nonstrict
-- export_prefab_layout.lua — раскладка префабов врагов для
-- tools/enemy-armor/render_preview.py (превью мешей без Studio).
-- POSE = nil — поза покоя R15; имя анимации (например "Idle") — первый кадр
-- этой анимации у каждого врага (через EnemyAnimator.jointCFrame, как в игре).
-- Возвращает JSON: { <typeId> = { scale, hrp, parts = { { name, folder, cf,
-- size, color, transparency, neon } } } }, cf — от HumanoidRootPart.
-- Запуск (Edit):
--   node C:\Users\artem\.dsh-roblox\s.js exec tools/lua/export_prefab_layout.lua Edit > tools/enemy-armor/prefab_layout.json

local POSE = "Idle"

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Свежие копии модулей (require в Studio кэширует).
local original = ReplicatedStorage.Shared
original.Name = "Shared_orig"
local shared = original:Clone()
shared.Name = "Shared"
shared.Parent = ReplicatedStorage
local animatorModule = StarterPlayer.StarterPlayerScripts.Controllers.EnemyAnimator:Clone()
animatorModule.Parent = workspace

local ok, result = pcall(function()
	local Anim = require(shared.Util.Anim)
	local Resolve = require(shared.Anim.Resolve)
	local EnemyVisuals = require(shared.Config.EnemyVisuals)
	local EnemyAnimator = require(animatorModule)
	local codeOf = {}
	for code, name in pairs(EnemyAnimator.MOTORS) do
		codeOf[name] = code
	end

	local out = {}
	for _, prefab in ipairs(ReplicatedStorage.EnemyPrefabs:GetChildren()) do
		local scale = prefab:GetScale()
		local pose = {}
		if POSE then
			local set = Resolve.forSet(EnemyVisuals.Types[prefab.Name].set)
			local anim = set[POSE]
			Anim.sample(anim.frames, 0, pose)
		end
		-- Позиции частей по суставам (как в превью: без записи в модель).
		local root = prefab.PrimaryPart
		local targets = { [root] = root.CFrame }
		local motors, welds = {}, {}
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("Motor6D") then
				table.insert(motors, d)
			elseif d:IsA("WeldConstraint") then
				table.insert(welds, { d.Part0, d.Part1, d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame) })
			end
		end
		for _ = 1, 64 do
			local changed = false
			for _, m in ipairs(motors) do
				if not targets[m.Part1] and targets[m.Part0] then
					local code = codeOf[m.Name]
					local t = code and EnemyAnimator.jointCFrame(pose, code, scale) or CFrame.identity
					targets[m.Part1] = targets[m.Part0] * m.C0 * t * m.C1:Inverse()
					changed = true
				end
			end
			for _, w in ipairs(welds) do
				if not targets[w[2]] and targets[w[1]] then
					targets[w[2]] = targets[w[1]] * w[3]
					changed = true
				end
			end
			if not changed then
				break
			end
		end
		local parts = {}
		for _, d in ipairs(prefab:GetDescendants()) do
			if d:IsA("BasePart") and d ~= root then
				local cf = root.CFrame:ToObjectSpace(targets[d] or d.CFrame)
				table.insert(parts, {
					name = d.Name,
					folder = d.Parent.Name,
					cf = { cf:GetComponents() },
					size = { d.Size.X, d.Size.Y, d.Size.Z },
					color = d.Color:ToHex(),
					transparency = d.Transparency,
					neon = d.Material == Enum.Material.Neon,
				})
			end
		end
		out[prefab.Name] = { scale = scale, hrp = root.Size.Y, pose = POSE or "rest", parts = parts }
	end
	return HttpService:JSONEncode(out)
end)

animatorModule:Destroy()
shared:Destroy()
original.Name = "Shared"
if not ok then
	error(result)
end
return result
