--!nonstrict
-- FxBuilder345 (общий)
-- Собирает шаблоны эффектов оружия этажей 3–5 из декларативной таблицы FxWeapons345
-- в ReplicatedStorage.FX (Hunt/*, Forge/*, Chron/*, Weapon/<id>). Соглашения — как у FxKit:
--   деталь: BaseRadius, ScalePart; эмиттер: Emit, EmitDelay, Pattern, ScaleSize, ScaleSpeed, MatchLife;
--   PointLight: Fade; Trail: Width (расстояние между Attachment, ставит клиент).
-- build()                    — только недостающие (правки, сохранённые в месте, не трогаются);
-- build({ rebuild = true })  — пересоздать всё по таблице.
-- Вызывается сервером при старте (Bootstrap) и Studio-скриптом tools/fx/BuildFxWeapons345.lua.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(script.Parent.FxWeapons345)

local FxBuilder345 = {}

local function hex(value): Color3
	if typeof(value) == "Color3" then
		return value
	end
	return Color3.fromHex(value)
end

-- "#hex" | { "#a", "#b", … } (равномерно) | { { t, "#hex" }, … }
local function colorSeq(spec): ColorSequence
	if spec == nil then
		return ColorSequence.new(Color3.new(1, 1, 1))
	end
	if type(spec) ~= "table" then
		return ColorSequence.new(hex(spec))
	end
	if #spec == 1 then
		return ColorSequence.new(hex(type(spec[1]) == "table" and spec[1][2] or spec[1]))
	end
	local points = {}
	if type(spec[1]) == "table" then
		for _, p in ipairs(spec) do
			table.insert(points, ColorSequenceKeypoint.new(p[1], hex(p[2])))
		end
	else
		for i, c in ipairs(spec) do
			table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#spec - 1), hex(c)))
		end
	end
	return ColorSequence.new(points)
end
FxBuilder345.colorSeq = colorSeq

-- число | { a, b } (от a к b) | { { t, v }, … }
local function numberSeq(spec, default: number?): NumberSequence
	if spec == nil then
		return NumberSequence.new(default or 0)
	end
	if type(spec) == "number" then
		return NumberSequence.new(spec)
	end
	if type(spec[1]) == "number" then
		return NumberSequence.new(spec[1], spec[2] or spec[1])
	end
	local points = {}
	for _, p in ipairs(spec) do
		table.insert(points, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(points)
end
FxBuilder345.numberSeq = numberSeq

local function range(spec, default: number?): NumberRange
	if spec == nil then
		return NumberRange.new(default or 0)
	end
	if type(spec) == "number" then
		return NumberRange.new(spec)
	end
	return NumberRange.new(spec[1], spec[2] or spec[1])
end

-- Имя текстуры → asset id: своя (NEW, если id вписан) → FALLBACK из TEX → TEX → как есть.
local function texture(name: string?): string
	if not name then
		return Spec.TEX.glow
	end
	local own = Spec.NEW[name]
	if own and own ~= "" then
		own = tostring(own)
		return string.find(own, "://") and own or ("rbxassetid://" .. own)
	end
	if Spec.FALLBACK[name] then
		return Spec.TEX[Spec.FALLBACK[name]]
	end
	return Spec.TEX[name] or name
end
FxBuilder345.texture = texture

-- Своя ли текстура вписана (NEW с id): только тогда у эмиттера включается флипбук —
-- запасная картинка из TEX одна, «сетка кадров» порезала бы её на четвертинки.
local function ownTexture(name: string?): boolean
	local own = name and Spec.NEW[name]
	return own ~= nil and own ~= ""
end
FxBuilder345.ownTexture = ownTexture

local function enum(kind, value)
	if value == nil then
		return nil
	end
	return Enum[kind][value]
end

local function emitter(e): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Name = e.name or "Emitter"
	p.Texture = texture(e.tex)
	p.Color = colorSeq(e.color)
	p.Size = numberSeq(e.size, 1)
	p.Transparency = numberSeq(e.transparency, 0)
	p.Lifetime = range(e.life, 1)
	p.Speed = range(e.speed, 0)
	if e.spread then
		p.SpreadAngle = Vector2.new(e.spread[1], e.spread[2] or e.spread[1])
	end
	p.Rate = e.rate or 0
	if e.accel then
		p.Acceleration = Vector3.new(e.accel[1], e.accel[2], e.accel[3])
	end
	p.Drag = e.drag or 0
	p.Rotation = range(e.rot, 0)
	p.RotSpeed = range(e.spin, 0)
	p.LightEmission = e.light or 0
	p.LightInfluence = e.influence or (e.light and e.light > 0 and 0 or 1)
	p.Brightness = e.bright or 1
	p.ZOffset = e.z or 0
	if e.shape then
		p.Shape = enum("ParticleEmitterShape", e.shape)
	end
	if e.style then
		p.ShapeStyle = enum("ParticleEmitterShapeStyle", e.style)
	end
	if e.inout then
		p.ShapeInOut = enum("ParticleEmitterShapeInOut", e.inout)
	end
	if e.dir then
		p.EmissionDirection = enum("NormalId", e.dir)
	end
	if e.orient then
		p.Orientation = enum("ParticleOrientation", e.orient)
	end
	if e.squash then
		p.Squash = numberSeq(e.squash)
	end
	p.LockedToPart = e.locked == true
	p.TimeScale = e.timeScale or 1
	-- Флипбук (листы из tools/flipbooks, pixelfx): flip = 4 | 8 — сетка кадров,
	-- flipMode — OneShot (по умолчанию: кадры за жизнь частицы) | Loop | PingPong.
	if e.flip and ownTexture(e.tex) then
		local okLayout, layout = pcall(function()
			return Enum.ParticleFlipbookLayout["Grid" .. e.flip .. "x" .. e.flip]
		end)
		if okLayout and layout then
			-- у листа свои цвета: тинт белый (keepColor — оставить тинт из таблицы)
			if not e.keepColor then
				p.Color = ColorSequence.new(Color3.new(1, 1, 1))
			end
			p.FlipbookLayout = layout
			p.FlipbookMode = enum("ParticleFlipbookMode", e.flipMode or "OneShot")
			if e.flipFps then
				p.FlipbookFramerate = range(e.flipFps)
			end
			p.FlipbookStartRandom = e.flipRandom == true
		end
	end
	p.Enabled = false
	if type(e.emit) == "number" then
		p:SetAttribute("Emit", e.emit)
	end
	if e.delay then
		p:SetAttribute("EmitDelay", e.delay)
	end
	if e.pattern then
		p:SetAttribute("Pattern", e.pattern)
	end
	if e.scaleSize then
		p:SetAttribute("ScaleSize", true)
	end
	if e.scaleSpeed then
		p:SetAttribute("ScaleSpeed", true)
	end
	if e.matchLife then
		p:SetAttribute("MatchLife", true)
	end
	if e.flare then
		-- Вспышка ауры: столько частиц выпускает клиентский WeaponPresence раз в несколько секунд.
		p:SetAttribute("Flare", e.flare)
	end
	return p
end
FxBuilder345.emitter = emitter

local function light(spec): PointLight
	local l = Instance.new("PointLight")
	l.Color = hex(spec.color or "#FFFFFF")
	l.Brightness = spec.brightness or 1
	l.Range = spec.range or 8
	l.Shadows = false
	if spec.fade then
		l:SetAttribute("Fade", spec.fade)
	end
	return l
end

local function trail(name: string, spec): Trail
	local t = Instance.new("Trail")
	t.Name = name
	t.Texture = texture(spec.tex or "trail")
	t.TextureMode = Enum.TextureMode.Stretch
	t.Color = colorSeq(spec.color)
	t.Lifetime = spec.lifetime or 0.3
	t.Transparency = numberSeq(spec.transparency, 0)
	t.WidthScale = numberSeq(spec.widthScale or { { 0, 1 }, { 1, 0.15 } })
	t.LightEmission = 1
	t.LightInfluence = 0
	t.FaceCamera = spec.faceCamera ~= false
	t.MinLength = 0.05
	t.Enabled = false
	t:SetAttribute("Width", spec.width or 1)
	return t
end

-- Подпись текстур шаблона: меняется, когда в NEW вписали id — тогда шаблон пересобирается
-- (иначе сохранённый в месте шаблон так и остался бы с запасной картинкой).
local function texSig(spec): string
	local parts = {}
	for _, e in ipairs(spec.emitters or {}) do
		table.insert(parts, texture(e.tex))
	end
	return table.concat(parts, "|")
end

local function build(path: string, spec)
	local name = string.match(path, "([^/]+)$")
	if spec.kind == "trail" then
		return trail(name, spec)
	end
	local root
	if spec.kind == "part" then
		local r = spec.radius or 1
		root = Instance.new("Part")
		root.Name = name
		root.Size = spec.size or Vector3.new(r * 2, 0.2, r * 2)
		root.Shape = spec.shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Block
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.CastShadow = false
		root.Locked = true
		root:SetAttribute("BaseRadius", r)
		if spec.scalePart then
			root:SetAttribute("ScalePart", true)
		end
	else
		root = Instance.new("Folder")
		root.Name = name
	end
	for _, e in ipairs(spec.emitters or {}) do
		emitter(e).Parent = root
	end
	if spec.light then
		light(spec.light).Parent = root
	end
	if spec.version then
		root:SetAttribute("FxVersion", spec.version)
	end
	if spec.texSig then
		root:SetAttribute("TexSig", texSig(spec))
	end
	if spec.trail then
		local tspec = Spec.Templates[spec.trail]
		if tspec then
			trail("Trail", tspec).Parent = root
		end
	end
	return root
end
FxBuilder345.buildOne = build

local function group(parent: Instance, name: string): Instance
	local node = parent:FindFirstChild(name)
	if not node then
		node = Instance.new("Folder")
		node.Name = name
		node.Parent = parent
	end
	return node
end

-- Возвращает (создано, всего).
function FxBuilder345.build(opts)
	opts = opts or {}
	local fx = ReplicatedStorage:FindFirstChild("FX")
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = "FX"
		fx.Parent = ReplicatedStorage
	end
	local made, total = 0, 0
	local paths = {}
	for path in pairs(Spec.Templates) do
		table.insert(paths, path)
	end
	table.sort(paths)
	for _, path in ipairs(paths) do
		total += 1
		local parent = fx
		local parts = string.split(path, "/")
		for i = 1, #parts - 1 do
			parent = group(parent, parts[i])
		end
		local old = parent:FindFirstChild(parts[#parts])
		-- Шаблон из старой версии таблицы (FxVersion меньше нового version) пересобирается сам:
		-- так обновлённые ауры оружия доходят до места без REBUILD.
		local version = Spec.Templates[path].version
		if old and version and (old:GetAttribute("FxVersion") or 0) < version then
			old:Destroy()
			old = nil
		end
		if old and Spec.Templates[path].texSig and old:GetAttribute("TexSig") ~= texSig(Spec.Templates[path]) then
			old:Destroy()
			old = nil
		end
		if old and opts.rebuild then
			old:Destroy()
			old = nil
		end
		if not old then
			local ok, item = pcall(build, path, Spec.Templates[path])
			if ok then
				item.Parent = parent
				made += 1
			else
				warn("[FxBuilder345] " .. path .. ": " .. tostring(item))
			end
		end
	end
	return made, total
end

return FxBuilder345
