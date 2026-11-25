--!nonstrict
-- EnvironmentController (клиент)
-- Оживляет этаж, который сервер построил неподвижным (FloorProps):
--   KlinokFloat — парящие кубики медленно покачиваются и вращаются;
--   KlinokFlame — воксельный огонь дрожит и «дышит»;
--   KlinokRise  — кубики распада отрываются от кромки, поднимаются и гаснут
--                 (раздел 19: «распад мира»);
--   KlinokHover — кубики над руинами плавно поднимаются на 1–2 стада и
--                 опускаются (Sine, 2–4 с);
--   KlinokRune  — рунная печать арены пульсирует, во второй фазе босса
--                 разгорается красным.
-- Только локальные сдвиги CFrame через BulkMoveTo и только рядом с камерой:
-- сервер и сеть не нагружаются.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)

local EnvironmentController = {}

local NEAR = 240 -- дальше этого кубики не анимируем
local entries = { float = {}, flame = {}, rise = {}, rune = {}, hover = {} }

local function register(kind: string, part: BasePart)
	if entries[kind][part] then
		return
	end
	entries[kind][part] = {
		base = part.CFrame,
		seed = part:GetAttribute("Seed") or math.random() * 100,
		amp = part:GetAttribute("Amp") or 1,
		period = part:GetAttribute("Period") or 7,
		lift = part:GetAttribute("Lift") or 8,
		transparency = part.Transparency,
		color = part.Color,
	}
end

local function watch(tag: string, kind: string)
	for _, part in ipairs(CollectionService:GetTagged(tag)) do
		if part:IsA("BasePart") then
			register(kind, part)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
		if part:IsA("BasePart") then
			register(kind, part)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
		entries[kind][part] = nil
	end)
end

-- Есть ли на арене босс во второй фазе.
local function bossEnraged(): boolean
	local floor = Workspace:FindFirstChild("Floor")
	if not floor then
		return false
	end
	for _, room in ipairs(floor:GetChildren()) do
		if room.Name:find("boss") then
			for _, child in ipairs(room:GetChildren()) do
				if child:IsA("Model") and child:GetAttribute("EnemyIsBoss") and (child:GetAttribute("BossPhase") or 1) >= 2 then
					return (child:GetAttribute("EnemyHealth") or 0) > 0
				end
			end
		end
	end
	return false
end

local runeHeat = 0
local enragedCheck = 0
local enraged = false

local parts = {}
local cframes = {}

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	table.clear(parts)
	table.clear(cframes)

	for part, e in pairs(entries.float) do
		local p = e.base.Position
		if (p - eye).Magnitude < NEAR then
			local s = e.seed
			local bob = math.sin(t * 0.6 + s) * e.amp
			local spin = CFrame.Angles(math.sin(t * 0.3 + s) * 0.3, t * 0.2 + s, 0)
			table.insert(parts, part)
			table.insert(cframes, CFrame.new(p + Vector3.new(0, bob, 0)) * (e.base - p) * spin)
		end
	end

	for part, e in pairs(entries.hover) do
		local p = e.base.Position
		if (p - eye).Magnitude < NEAR then
			-- Sine «туда-обратно»: 0 → amp → 0 за два периода твина.
			local u = (1 - math.cos((t + e.seed) / e.period * math.pi)) / 2
			table.insert(parts, part)
			table.insert(cframes, e.base + Vector3.new(0, u * e.amp, 0))
		end
	end

	for part, e in pairs(entries.flame) do
		local p = e.base.Position
		if (p - eye).Magnitude < NEAR then
			local s = e.seed
			local jitter = Vector3.new(math.noise(t * 4, s) * 0.12, math.abs(math.noise(t * 5, s + 3)) * 0.25, math.noise(t * 4, s + 7) * 0.12)
			table.insert(parts, part)
			table.insert(cframes, CFrame.new(p + jitter) * CFrame.Angles(0, t * 1.5 + s, 0))
		end
	end

	for part, e in pairs(entries.rise) do
		local p = e.base.Position
		if (p - eye).Magnitude < NEAR then
			local phase = ((t + e.seed) % e.period) / e.period
			local lift = e.lift * phase
			table.insert(parts, part)
			table.insert(cframes, CFrame.new(p + Vector3.new(0, lift, 0)) * CFrame.Angles(phase * 2, phase * 3 + e.seed, 0))
			part.Transparency = math.clamp((phase - 0.6) / 0.4, 0, 1)
		end
	end

	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Рунная печать арены.
	enragedCheck -= dt
	if enragedCheck <= 0 then
		enragedCheck = 0.5
		enraged = bossEnraged()
	end
	runeHeat += ((enraged and 1 or 0) - runeHeat) * math.min(dt * 2, 1)
	local pulse = 0.5 + 0.5 * math.sin(t * (2 + runeHeat * 4))
	for part, e in pairs(entries.rune) do
		-- Печать тлеет, а не горит: не должна спорить с красными зонами атак.
		part.Transparency = math.clamp(0.72 - pulse * 0.22 - runeHeat * 0.3, 0, 1)
		part.Color = e.color:Lerp(Palette.UI.danger, runeHeat)
	end
end

-- ===== Живой огонь и угольки карты этажа =====
-- У каждого источника света Floor1Map.<зона>.Lights (факелы, жаровни,
-- костры пакета карты) — огонь частицами из шаблона FX.Env.Fire.
-- Неоновые кубики-угольки в мешах карты (цвет EMBER_COLOR) прячутся, на их
-- место — парящие угольки FX.Env.Embers. Эмиттеры включены только у
-- огней ближе FIRE_NEAR к камере.

local FIRE_NEAR = 110
local EMBER_COLOR = "c98b4a"
local fires = {} -- { position, items }
local fireCheck = 0

local function buildFires()
	local FxKit = require(script.Parent.Parent.Lib.FxKit)
	local map = Workspace:FindFirstChild("Floor1Map")
	if not map or not FxKit.template("Env/Fire") then
		return
	end
	for _, zone in ipairs(map:GetChildren()) do
		local lights = zone:FindFirstChild("Lights")
		if lights then
			for _, source in ipairs(lights:GetChildren()) do
				if source:IsA("BasePart") then
					local point = Instance.new("Attachment")
					point.Name = "Fire"
					point.Parent = source
					local handle = FxKit.attach("Env/Fire", point)
					if handle then
						table.insert(fires, { position = source.Position, items = handle.items, on = true })
					end
				end
			end
		end
		local visual = zone:FindFirstChild("Visual")
		local template = FxKit.template("Env/Embers")
		if visual and template then
			for _, mesh in ipairs(visual:GetChildren()) do
				if mesh:IsA("MeshPart") and mesh.Material == Enum.Material.Neon and mesh.Color:ToHex() == EMBER_COLOR then
					mesh.LocalTransparencyModifier = 1
					local handle = FxKit.spawn("Env/Embers", mesh.CFrame, { size = mesh.Size })
					if handle then
						local volume = mesh.Size.X * mesh.Size.Y * mesh.Size.Z
						local rate = math.clamp(volume * (template:GetAttribute("RatePerVolume") or 0.03), 1, 25)
						local items = {}
						for _, d in ipairs(handle.root:GetDescendants()) do
							if d:IsA("ParticleEmitter") then
								d.Rate = rate
								table.insert(items, d)
							end
						end
						table.insert(fires, { position = mesh.Position, items = items, on = true })
					end
				end
			end
		end
	end
end

local function stepFires(dt: number, eye: Vector3)
	fireCheck -= dt
	if fireCheck > 0 then
		return
	end
	fireCheck = 0.5
	for _, fire in ipairs(fires) do
		local near = (fire.position - eye).Magnitude < FIRE_NEAR
		if near ~= fire.on then
			fire.on = near
			for _, item in ipairs(fire.items) do
				if item:IsA("ParticleEmitter") then
					item.Enabled = near
				end
			end
		end
	end
end

function EnvironmentController.start()
	task.spawn(buildFires)
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if camera then
			stepFires(dt, camera.CFrame.Position)
		end
	end)
	watch("KlinokFloat", "float")
	watch("KlinokFlame", "flame")
	watch("KlinokRise", "rise")
	watch("KlinokRune", "rune")
	watch("KlinokHover", "hover")
	RunService.RenderStepped:Connect(step)
	print("[EnvironmentController] кубики, огонь и руны оживают")
end

return EnvironmentController
