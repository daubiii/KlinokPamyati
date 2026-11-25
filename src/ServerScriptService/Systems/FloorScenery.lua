--!nonstrict
-- FloorScenery (сервер)
-- Небо и дальний план этажа 1: закатный свет, облака, дымка, парящие
-- острова-руины и башня Хранилища на горизонте (раздел 6: «башня из слоёв
-- памяти»). Голубые окна башни — единственный голубой на этаже: это память.
--
-- Комнаты — острова в небе, поэтому за кромкой высоких стен видно небо, а не
-- пустоту. Всё здесь декорация: без коллизий и без запросов лучей.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared.Config.Palette)

local Props = require(script.Parent.FloorProps)

local FloorScenery = {}

local Env = Palette.Env
local V3 = Vector3.new
local CF = CFrame.new

-- ===== Свет и небо =====

local function replace(parent, className: string, name: string)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

function FloorScenery.setupLighting()
	local colors = Palette.Floors[1].colors

	-- Спецификация владельца (21.10.2026): пыльный закат, дымка прячет небо.
	-- ClockTime 17.5, Ambient #3A2E2A, OutdoorAmbient #7A5C48, Brightness 1.5.
	Lighting.ClockTime = 17.5
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 1.5
	Lighting.Ambient = colors[1]
	Lighting.OutdoorAmbient = colors[2]
	Lighting.ColorShift_Top = colors[4]:Lerp(Color3.new(1, 1, 1), 0.2)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ExposureCompensation = 0
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	for _, name in ipairs({ "KlinokAtmosphere", "KlinokBloom", "KlinokColor", "KlinokSunRays", "KlinokSky" }) do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- Эффекты, оставшиеся в файле места: при двух Atmosphere движок берёт
	-- первую, и дымка этажа не работала. Оставляем только свои.
	for _, child in ipairs(Lighting:GetChildren()) do
		if (child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("ColorCorrectionEffect"))
			and child.Name:sub(1, 6) ~= "Klinok" then
			child:Destroy()
		end
	end

	-- Пустыня вокруг замка (28.10.2026): песчаная мгла прячет даль и хаб,
	-- горизонт растворяется в пыльном закате. Буря — SandstormController.
	local atmosphere = replace(Lighting, "Atmosphere", "KlinokAtmosphere")
	atmosphere.Density = 0.4
	atmosphere.Offset = 0.3
	atmosphere.Color = Color3.fromHex("#B98C64")
	atmosphere.Decay = Color3.fromHex("#6E4636")
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.7

	local bloom = replace(Lighting, "BloomEffect", "KlinokBloom")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6

	local grade = replace(Lighting, "ColorCorrectionEffect", "KlinokColor")
	grade.Saturation = -0.15
	grade.Contrast = 0.1
	grade.Brightness = 0
	grade.TintColor = Palette.Ruin.tint

	local rays = replace(Lighting, "SunRaysEffect", "KlinokSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.7

	-- Небо: штатный небосвод на закате + облака терраина.
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "KlinokSky"
		sky.SunAngularSize = 14
		sky.MoonAngularSize = 8
		sky.StarCount = 1500
		sky.Parent = Lighting
	end

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		-- Песок пустыни (tools/desert): приглушённый, иначе закат его выжигает.
		terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromHex("#5C4D42"))
		terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromHex("#4E3B30"))
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.6
		clouds.Density = 0.55
		clouds.Color = colors[4]:Lerp(colors[3], 0.25)
		clouds.Enabled = true
		clouds.Parent = terrain
	end
end

-- ===== Дальний план =====

-- Парящий остров: верхняя плита, ступенчатое «дно» и россыпь кубиков.
local function island(parent, center: Vector3, width: number, rng, opts)
	local top = Props.pick(rng, { { Env.sand, 3 }, { Env.stoneLight, 2 }, { Env.grassDry, 1 } })
	Props.part(parent, "IslandTop", V3(width, 2, width * (0.7 + rng:NextNumber() * 0.4)), CF(center), Props.vary(top, rng, 0.06), nil, { shadow = false })
	local w = width
	local y = center.Y - 1
	for layer = 1, 4 do
		w *= 0.7
		local h = 3 + layer * 1.5
		Props.part(parent, "IslandRock", V3(w, h, w * 0.85), CF(center.X + (rng:NextNumber() - 0.5) * 2, y - h / 2, center.Z + (rng:NextNumber() - 0.5) * 2),
			Props.vary(layer < 3 and Env.stone or Env.stoneDark, rng, 0.06), nil, { shadow = false })
		y -= h
	end
	for _ = 1, 5 do
		local size = 1 + rng:NextNumber() * 3
		Props.floatCube(parent, center + V3((rng:NextNumber() - 0.5) * width * 1.3, -4 - rng:NextNumber() * 14, (rng:NextNumber() - 0.5) * width * 1.3), size, Props.vary(Env.stone, rng), rng)
	end
	if opts and opts.ruin then
		-- Обломок колонны или арки на острове.
		local h = 6 + rng:NextNumber() * 10
		Props.part(parent, "IslandRuin", V3(3, h, 3), CF(center + V3(width * 0.2, 1 + h / 2, 0)), Props.vary(Env.stoneLight, rng), nil, { shadow = false })
		Props.part(parent, "IslandRuin", V3(4, 1, 4), CF(center + V3(width * 0.2, 1 + h, 0)) * CFrame.Angles(0, 0, 0.2), Env.sandLight, nil, { shadow = false })
	end
	if opts and opts.tree then
		Props.deadTree(parent, center + V3(-width * 0.2, 1, 0), rng, 1.3)
	end
end

-- Башня Хранилища: слои памяти один на другом, верх рассыпается.
local function vaultTower(parent, base: Vector3, rng)
	local y = base.Y
	local width = 70
	for layer = 1, 16 do
		local h = 26 + rng:NextNumber() * 10
		local twist = (rng:NextNumber() - 0.5) * 0.25
		local color = Props.vary(layer % 2 == 0 and Env.stoneLight or Env.stone, rng, 0.05)
		local frame = CF(base.X, y + h / 2, base.Z) * CFrame.Angles(0, twist + layer * 0.08, 0)
		Props.part(parent, "TowerLayer", V3(width, h, width), frame, color, nil, { shadow = false })
		-- Карниз слоя.
		Props.part(parent, "TowerLedge", V3(width + 6, 3, width + 6), frame * CF(0, h / 2, 0), Env.sandLight, nil, { shadow = false })
		-- Окна памяти: голубое свечение.
		if layer % 3 ~= 1 then
			for side = 0, 3 do
				local face = frame * CFrame.Angles(0, side * math.pi / 2, 0)
				for column = -1, 1 do
					if rng:NextNumber() < 0.6 then
						Props.part(parent, "TowerWindow", V3(4, 8, 1), face * CF(column * 18, -2, -width / 2 - 0.3), Palette.Memory, Enum.Material.Neon, { shadow = false })
					end
				end
			end
		end
		y += h + 3
		width *= 0.93
	end
	-- Вершина рассыпается на кубики, которые висят над башней.
	for _ = 1, 26 do
		local size = 3 + rng:NextNumber() * 8
		Props.floatCube(parent, V3(base.X + (rng:NextNumber() - 0.5) * 90, y + rng:NextNumber() * 120, base.Z + (rng:NextNumber() - 0.5) * 90), size,
			Props.vary(Env.stoneLight, rng, 0.08), rng)
	end
	-- Остров-основание.
	island(parent, V3(base.X, base.Y - 2, base.Z), 160, rng)
end

-- Построить дальний план вокруг этажа длиной floorLength (уходит к −Z).
function FloorScenery.build(parent, floorLength: number)
	local old = parent:FindFirstChild("Scenery")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"

	local rng = Random.new(1337)

	-- Башня — впереди по ходу движения, за ареной босса, чуть в стороне.
	vaultTower(folder, V3(220, -40, -floorLength - 520), rng)

	-- Острова по обе стороны цепочки комнат, на разной высоте и дистанции.
	local count = 22
	for index = 1, count do
		local side = index % 2 == 0 and 1 or -1
		local along = -((index - 1) / (count - 1)) * (floorLength + 500) + 160
		local distance = 110 + rng:NextNumber() * 260
		local center = V3(side * distance, -50 + rng:NextNumber() * 90, along + (rng:NextNumber() - 0.5) * 60)
		island(folder, center, 18 + rng:NextNumber() * 40, rng, {
			ruin = rng:NextNumber() < 0.5,
			-- Деревья на дальних островах почти не видны в дымке, а деталей
			-- стоят много: только на ближних.
			tree = distance < 160 and rng:NextNumber() < 0.5,
		})
	end

	-- Облако кубиков под этажом: «мир рассыпается на квадраты».
	for _ = 1, 60 do
		local size = 1.5 + rng:NextNumber() * 5
		Props.floatCube(folder, V3((rng:NextNumber() - 0.5) * 160, -30 - rng:NextNumber() * 60, -rng:NextNumber() * floorLength), size,
			Props.vary(Props.pick(rng, { { Env.stone, 3 }, { Env.stoneDark, 2 }, { Env.sand, 1 } }), rng), rng)
	end

	folder.Parent = parent
	return folder
end

return FloorScenery
