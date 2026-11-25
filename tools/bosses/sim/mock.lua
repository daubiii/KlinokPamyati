local REAL_PRINT = print
-- Мини-эмуляция API Roblox для прогонов клиентских модулей без Studio.
local SIM = { now = 1000, clock = 500, queue = {}, errors = {}, unknown = {}, sfx = {}, nan = {}, frame = 0 }
local realTypeof = typeof
local TYPES = {}
local function typeof(v)
	local mt = getmetatable(v)
	if mt and TYPES[mt] then
		return TYPES[mt]
	end
	return realTypeof(v)
end
local function simError(msg)
	if #SIM.errors < 60 then
		table.insert(SIM.errors, msg)
	end
end
local function isNaN(x)
	return x ~= x or x == math.huge or x == -math.huge
end

-- ===== Vector3 =====
local V3mt = {}
TYPES[V3mt] = "Vector3"
local function v3(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3mt)
end
local V3methods = {}
function V3methods.Dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function V3methods.Cross(a, b) return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
function V3methods.Lerp(a, b, t)
	if typeof(b) ~= "Vector3" then error("Vector3:Lerp: не Vector3", 2) end
	return v3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
end
function V3methods.Abs(a) return v3(math.abs(a.x), math.abs(a.y), math.abs(a.z)) end
function V3methods.Max(a, b) return v3(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z)) end
function V3methods.Min(a, b) return v3(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)) end
function V3methods.FuzzyEq(a, b, e) e = e or 1e-5 return math.abs(a.x - b.x) < e and math.abs(a.y - b.y) < e and math.abs(a.z - b.z) < e end
function V3methods.Angle(a, b) local d = a:Dot(b) / math.max(a.Magnitude * b.Magnitude, 1e-9) return math.acos(math.clamp(d, -1, 1)) end
V3mt.__index = function(v, k)
	if k == "X" then return rawget(v, "x") end
	if k == "Y" then return rawget(v, "y") end
	if k == "Z" then return rawget(v, "z") end
	if k == "Magnitude" then return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
	if k == "Unit" then
		local m = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(v.x / m, v.y / m, v.z / m)
	end
	local m = V3methods[k]
	if m then return m end
	error("Vector3: нет поля " .. tostring(k), 2)
end
V3mt.__newindex = function() error("Vector3 неизменяем", 2) end
V3mt.__add = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then error("Vector3 + " .. typeof(a) .. "/" .. typeof(b), 2) end
	return v3(a.x + b.x, a.y + b.y, a.z + b.z)
end
V3mt.__sub = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then error("Vector3 - " .. typeof(a) .. "/" .. typeof(b), 2) end
	return v3(a.x - b.x, a.y - b.y, a.z - b.z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.x, a * b.y, a * b.z) end
	if type(b) == "number" then return v3(a.x * b, a.y * b, a.z * b) end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then return v3(a.x * b.x, a.y * b.y, a.z * b.z) end
	error("Vector3 * " .. typeof(a) .. "/" .. typeof(b), 2)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.x / b, a.y / b, a.z / b) end
	if typeof(b) == "Vector3" then return v3(a.x / b.x, a.y / b.y, a.z / b.z) end
	error("Vector3 / " .. typeof(b), 2)
end
V3mt.__unm = function(a) return v3(-a.x, -a.y, -a.z) end
V3mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
V3mt.__tostring = function(a) return ("%.2f, %.2f, %.2f"):format(a.x, a.y, a.z) end
local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), xAxis = v3(1, 0, 0), yAxis = v3(0, 1, 0), zAxis = v3(0, 0, 1) }
local function v3NaN(v) return isNaN(v.x) or isNaN(v.y) or isNaN(v.z) end

-- ===== CFrame =====
local CFmt = {}
TYPES[CFmt] = "CFrame"
-- r, u, b — столбцы (X, Y, Z) матрицы поворота.
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b }, CFmt)
end
local function rot(c, v) return c.r * v.x + c.u * v.y + c.b * v.z end
local CFmethods = {}
function CFmethods.Inverse(c)
	-- транспонированная матрица
	local r = v3(c.r.x, c.u.x, c.b.x)
	local u = v3(c.r.y, c.u.y, c.b.y)
	local b = v3(c.r.z, c.u.z, c.b.z)
	local inv = cf(v3(0, 0, 0), r, u, b)
	return cf(-rot(inv, c.p), r, u, b)
end
function CFmethods.PointToWorldSpace(c, v) return c.p + rot(c, v) end
function CFmethods.VectorToWorldSpace(c, v) return rot(c, v) end
function CFmethods.PointToObjectSpace(c, v) return c:Inverse() * v end
function CFmethods.VectorToObjectSpace(c, v) local i = c:Inverse() return rot(i, v) end
function CFmethods.ToObjectSpace(c, o) return c:Inverse() * o end
function CFmethods.ToWorldSpace(c, o) return c * o end
function CFmethods.Lerp(a, b, t)
	local r = a.r:Lerp(b.r, t).Unit
	local u = a.u:Lerp(b.u, t)
	u = (u - r * u:Dot(r)).Unit
	return cf(a.p:Lerp(b.p, t), r, u, r:Cross(u))
end
function CFmethods.ToEulerAnglesYXZ(c)
	local x = math.asin(math.clamp(-c.b.y, -1, 1))
	local y = math.atan2(c.b.x, c.b.z)
	local z = math.atan2(c.r.y, c.u.y)
	return x, y, z
end
function CFmethods.ToEulerAnglesXYZ(c)
	return CFmethods.ToEulerAnglesYXZ(c)
end
function CFmethods.ToOrientation(c) return CFmethods.ToEulerAnglesYXZ(c) end
function CFmethods.GetComponents(c)
	return c.p.x, c.p.y, c.p.z, c.r.x, c.u.x, c.b.x, c.r.y, c.u.y, c.b.y, c.r.z, c.u.z, c.b.z
end
function CFmethods.Orthonormalize(c) return c end
CFmt.__index = function(c, k)
	if k == "Position" then return rawget(c, "p") end
	if k == "X" then return c.p.x end
	if k == "Y" then return c.p.y end
	if k == "Z" then return c.p.z end
	if k == "LookVector" then return -c.b end
	if k == "RightVector" or k == "XVector" then return c.r end
	if k == "UpVector" or k == "YVector" then return c.u end
	if k == "ZVector" then return c.b end
	if k == "Rotation" then return cf(v3(0, 0, 0), c.r, c.u, c.b) end
	local m = CFmethods[k]
	if m then return m end
	error("CFrame: нет поля " .. tostring(k), 2)
end
CFmt.__newindex = function() error("CFrame неизменяем", 2) end
CFmt.__mul = function(a, b)
	if typeof(a) ~= "CFrame" then error("CFrame * : слева " .. typeof(a), 2) end
	if typeof(b) == "CFrame" then
		return cf(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
	elseif typeof(b) == "Vector3" then
		return a.p + rot(a, b)
	end
	error("CFrame * " .. typeof(b), 2)
end
CFmt.__add = function(a, b)
	if typeof(b) ~= "Vector3" then error("CFrame + " .. typeof(b), 2) end
	return cf(a.p + b, a.r, a.u, a.b)
end
CFmt.__sub = function(a, b)
	if typeof(b) ~= "Vector3" then error("CFrame - " .. typeof(b), 2) end
	return cf(a.p - b, a.r, a.u, a.b)
end
CFmt.__tostring = function(c) return "CFrame(" .. tostring(c.p) .. ")" end
local X, Y, Z = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
local function lookAt(pos, target, up)
	if typeof(pos) ~= "Vector3" or typeof(target) ~= "Vector3" then error("CFrame.lookAt: не Vector3", 2) end
	up = up or Y
	local f = target - pos
	if f.Magnitude < 1e-9 then
		return cf(pos, X, Y, Z)
	end
	f = f.Unit
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then
		r = f:Cross(v3(0, 0, 1))
		if r.Magnitude < 1e-6 then r = v3(1, 0, 0) end
	end
	r = r.Unit
	local u = r:Cross(f)
	return cf(pos, r, u, -f)
end
local function rx(a) local c, s = math.cos(a), math.sin(a) return cf(v3(0, 0, 0), X, v3(0, c, s), v3(0, -s, c)) end
local function ry(a) local c, s = math.cos(a), math.sin(a) return cf(v3(0, 0, 0), v3(c, 0, -s), Y, v3(s, 0, c)) end
local function rz(a) local c, s = math.cos(a), math.sin(a) return cf(v3(0, 0, 0), v3(c, s, 0), v3(-s, c, 0), Z) end
local CFrame = {}
CFrame.identity = cf(v3(0, 0, 0), X, Y, Z)
function CFrame.new(a, b, c, ...)
	if a == nil then return CFrame.identity end
	if typeof(a) == "Vector3" then
		if typeof(b) == "Vector3" then return lookAt(a, b) end
		return cf(a, X, Y, Z)
	end
	if type(a) ~= "number" or type(b) ~= "number" or type(c) ~= "number" then error("CFrame.new: аргументы " .. typeof(a), 2) end
	local rest = { ... }
	if #rest == 9 then
		return cf(v3(a, b, c), v3(rest[1], rest[4], rest[7]), v3(rest[2], rest[5], rest[8]), v3(rest[3], rest[6], rest[9]))
	end
	return cf(v3(a, b, c), X, Y, Z)
end
CFrame.lookAt = lookAt
function CFrame.fromMatrix(pos, vx, vy, vz)
	if typeof(pos) ~= "Vector3" or typeof(vx) ~= "Vector3" or typeof(vy) ~= "Vector3" then error("CFrame.fromMatrix: не Vector3", 2) end
	vz = vz or vx:Cross(vy).Unit
	return cf(pos, vx, vy, vz)
end
function CFrame.Angles(a, b, c) return rx(a or 0) * ry(b or 0) * rz(c or 0) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(a, b, c) return ry(b or 0) * rx(a or 0) * rz(c or 0) end
function CFrame.fromOrientation(a, b, c) return CFrame.fromEulerAnglesYXZ(a, b, c) end
function CFrame.fromAxisAngle(axis, angle)
	local k = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local function rotv(v) return v * c + k:Cross(v) * s + k * (k:Dot(v) * (1 - c)) end
	return cf(v3(0, 0, 0), rotv(X), rotv(Y), rotv(Z))
end
local function cfNaN(c) return v3NaN(c.p) or v3NaN(c.r) or v3NaN(c.u) or v3NaN(c.b) end

-- ===== Прочие типы =====
local C3mt = {}
TYPES[C3mt] = "Color3"
local function c3(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt) end
C3mt.__index = {
	Lerp = function(a, b, t)
		if typeof(b) ~= "Color3" then error("Color3:Lerp: не Color3", 2) end
		return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end,
	ToHSV = function(a) return 0, 0, math.max(a.R, a.G, a.B) end,
	ToHex = function(a) return "ffffff" end,
}
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
local Color3 = {
	new = c3,
	fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
	fromHSV = function(h, s, v) return c3(v, v, v) end,
	fromHex = function(hex)
		hex = hex:gsub("#", "")
		return c3(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255)
	end,
}
local function plain(typeName, fields)
	local mt = { __index = fields or {} }
	TYPES[mt] = typeName
	return mt
end
local V2mt = plain("Vector2")
V2mt.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y }, V2mt) end
V2mt.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, V2mt) end
V2mt.__mul = function(a, b)
	if type(b) == "number" then return setmetatable({ X = a.X * b, Y = a.Y * b }, V2mt) end
	return setmetatable({ X = a * b.X, Y = a * b.Y }, V2mt)
end
local Vector2 = { new = function(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2mt) end }
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
local UDim2mt = plain("UDim2")
local UDim2 = {
	new = function(a, b, c, d) return setmetatable({ X = { Scale = a or 0, Offset = b or 0 }, Y = { Scale = c or 0, Offset = d or 0 } }, UDim2mt) end,
}
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
local UDim = { new = function(s, o) return setmetatable({ Scale = s, Offset = o }, plain("UDim")) end }
local NSmt = plain("NumberSequence")
local NumberSequence = { new = function(a, b) return setmetatable({ Keypoints = type(a) == "table" and a or { a, b } }, NSmt) end }
local NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end }
local CSmt = plain("ColorSequence")
local ColorSequence = { new = function(a, b) return setmetatable({ Keypoints = type(a) == "table" and getmetatable(a) ~= C3mt and a or { a, b or a } }, CSmt) end }
local ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
local NumberRange = { new = function(a, b) return setmetatable({ Min = a, Max = b or a }, plain("NumberRange")) end }
local TweenInfo = { new = function(t, s, d, r, rev, delay) return { Time = t or 1, EasingStyle = s, EasingDirection = d, DelayTime = delay or 0 } end }
local Font = { new = function(f, w, s) return { Family = f, Weight = w } end, fromEnum = function(e) return { Family = tostring(e) } end }
local PhysicalProperties = { new = function(...) return { ... } end }
local Rect = { new = function(...) return { ... } end }
local Ray = { new = function(o, d) return { Origin = o, Direction = d } end }
local OverlapParams = { new = function() return { FilterDescendantsInstances = {} } end }
local RaycastParams = { new = function() return { FilterDescendantsInstances = {}, FilterType = nil, IgnoreWater = false } end }
local DateTime = { now = function() return { UnixTimestamp = 0, UnixTimestampMillis = 0 } end }

local Randmt = {}
Randmt.__index = {
	NextNumber = function(self, a, b)
		self.s = (self.s * 1103515245 + 12345) % 2147483648
		local k = self.s / 2147483648
		a, b = a or 0, b or 1
		return a + (b - a) * k
	end,
	NextInteger = function(self, a, b)
		self.s = (self.s * 1103515245 + 12345) % 2147483648
		return a + (self.s % (b - a + 1))
	end,
	NextUnitVector = function(self) return v3(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1)).Unit end,
}
TYPES[Randmt] = "Random"
local Random = { new = function(seed) return setmetatable({ s = (seed or 12345) % 2147483648 }, Randmt) end }

-- ===== Enum =====
local EnumItemMt = { __tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end }
TYPES[EnumItemMt] = "EnumItem"
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = enumCache[enumName]
		if not items then
			items = setmetatable({}, {
				__index = function(t, name)
					local item = setmetatable({ Name = name, EnumType = enumName, Value = 200 }, EnumItemMt)
					rawset(t, name, item)
					return item
				end,
			})
			enumCache[enumName] = items
		end
		return items
	end,
})

-- ===== Планировщик =====
local function resume(co, ...)
	local ok, res = coroutine.resume(co, ...)
	if not ok then
		simError("корутина: " .. tostring(res) .. "\n" .. debug.traceback(co))
		return
	end
	if coroutine.status(co) == "suspended" then
		table.insert(SIM.queue, { at = SIM.clock + (tonumber(res) or 0), co = co, args = {} })
	end
end
local task = {}
function task.spawn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	resume(co, ...)
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	table.insert(SIM.queue, { at = SIM.clock + (t or 0), co = co, args = table.pack(...) })
	return co
end
function task.defer(fn, ...) return task.delay(0, fn, ...) end
function task.wait(t)
	if not coroutine.isyieldable() then
		error("task.wait вне корутины", 2)
	end
	coroutine.yield(t or 0)
	return t or 0
end
function task.cancel(co)
	for i = #SIM.queue, 1, -1 do
		if SIM.queue[i].co == co then table.remove(SIM.queue, i) end
	end
end
local function runQueue()
	local guard = 0
	while true do
		guard += 1
		if guard > 10000 then simError("планировщик: зацикливание") return end
		local bestI
		for i, e in ipairs(SIM.queue) do
			if e.at <= SIM.clock and (not bestI or e.at < SIM.queue[bestI].at) then bestI = i end
		end
		if not bestI then return end
		local e = table.remove(SIM.queue, bestI)
		resume(e.co, table.unpack(e.args, 1, e.args.n or #e.args))
	end
end
local wait = function(t) return task.wait(t) end
local delay = task.delay
local spawn = task.spawn
local os = setmetatable({ clock = function() return SIM.clock end, time = function() return SIM.now end }, { __index = os })
local tick = function() return SIM.clock end
local time = function() return SIM.clock end

-- ===== Сигналы =====
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local h = { fn = fn, connected = true }
		table.insert(self.handlers, h)
		return { Disconnect = function() h.connected = false end, Connected = true }
	end
	s.connect = s.Connect
	function s:Once(fn)
		local c
		c = self:Connect(function(...) c.Disconnect() fn(...) end)
		return c
	end
	function s:Fire(...)
		for _, h in ipairs(self.handlers) do
			if h.connected then
				local ok, err = pcall(h.fn, ...)
				if not ok then simError("сигнал: " .. tostring(err)) end
			end
		end
	end
	function s:Wait() return task.wait(0) end
	return s
end

-- ===== Экземпляры =====
local D = setmetatable({}, { __mode = "k" })
local Inst = {}
TYPES[Inst] = "Instance"
local BASEPART = { Part = true, MeshPart = true, WedgePart = true, TrussPart = true, SpawnLocation = true, CornerWedgePart = true, UnionOperation = true }
local GUIOBJ = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, CanvasGroup = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true }
local DEFAULTS = {
	Size = v3(4, 1, 2), CFrame = CFrame.identity, Transparency = 0, Color = c3(0.64, 0.64, 0.64), Anchored = false, CanCollide = true,
	CanQuery = true, CanTouch = true, CastShadow = true, Material = Enum.Material.Plastic, Reflectance = 0, LocalTransparencyModifier = 0,
	Enabled = true, Rate = 0, Brightness = 1, Range = 8, Shadows = false, Visible = true, Text = "", TextTransparency = 0,
	BackgroundTransparency = 0, MaxVisibleGraphemes = -1, Scale = 1, GroupTransparency = 0, FillTransparency = 0.5,
	OutlineTransparency = 0, Thickness = 1, Rotation = 0, ZIndex = 1, TextSize = 14, Volume = 0.5, PlaybackSpeed = 1, Playing = false,
	TimePosition = 0, IsPlaying = false, Contrast = 0, Saturation = 0, TintColor = c3(1, 1, 1), FieldOfView = 70,
	ViewportSize = Vector2.new(1920, 1080), AbsoluteSize = Vector2.new(1000, 100), AbsolutePosition = Vector2.new(0, 0),
	Position = nil, Orientation = v3(0, 0, 0), Shape = Enum.PartType.Block, Adornee = nil, PrimaryPart = nil, Health = 100, MaxHealth = 100,
	WalkSpeed = 16, JumpPower = 50, AutoRotate = true, LightEmission = 0, LightInfluence = 1, Archivable = true, BackgroundColor3 = c3(1, 1, 1),
	TextColor3 = c3(0, 0, 0), ImageTransparency = 0, ImageColor3 = c3(1, 1, 1), Image = "", Value = nil, Texture = "", Face = Enum.NormalId.Front,
	Width0 = 1, Width1 = 1, TextureLength = 1, TextureSpeed = 1, Lifetime = NumberRange.new(1, 1), Speed = NumberRange.new(5, 5),
	Attachment0 = nil, Attachment1 = nil, WorldPosition = v3(0, 0, 0), Density = 0, Offset = 0, Haze = 0, Glare = 0, Decay = c3(1, 1, 1),
	Intensity = 0, DisplayOrder = 0, ResetOnSpawn = true, Massless = false, AssemblyLinearVelocity = v3(0, 0, 0),
	CurrentCamera = nil, FillColor = c3(1, 1, 1), OutlineColor = c3(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	Font = Enum.Font.Gotham, LineHeight = 1, TextWrapped = false, TextScaled = false, RichText = false, AnchorPoint = Vector2.new(0, 0),
	ClipsDescendants = false, Active = false, AutoButtonColor = true, Selectable = false, BorderSizePixel = 1, LayoutOrder = 0,
	StudsOffset = v3(0, 0, 0), AlwaysOnTop = false, LightInfluence_ = 0, MaxDistance = 0, Drag = 0, Acceleration = v3(0, 0, 0),
	SpreadAngle = Vector2.new(0, 0), LockedToPart = false, EmissionDirection = Enum.NormalId.Top, Squash = nil, ZOffset = 0,
	TimeScale = 1, VelocityInheritance = 0, CornerRadius = UDim.new(0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	LineJoinMode = Enum.LineJoinMode.Round, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
	TextStrokeTransparency = 1, TextStrokeColor3 = c3(0, 0, 0), ImageRectOffset = Vector2.new(0, 0), ImageRectSize = Vector2.new(0, 0),
	ScaleType = Enum.ScaleType.Stretch, SizeConstraint = Enum.SizeConstraint.RelativeXY, AutomaticSize = Enum.AutomaticSize.None,
	MeshId = "", TextureID = "", Parent = nil,
}
local function newInstance(class)
	local obj = setmetatable({}, Inst)
	D[obj] = { ClassName = class, Name = class, props = {}, children = {}, attributes = {}, parent = nil, signals = {} }
	return obj
end
local function isA(class, want)
	if want == class or want == "Instance" then return true end
	if want == "BasePart" or want == "PVInstance" then return BASEPART[class] == true or (want == "PVInstance" and class == "Model") end
	if want == "GuiObject" or want == "GuiBase2d" then return GUIOBJ[class] == true end
	if want == "LayerCollector" then return class == "ScreenGui" or class == "BillboardGui" or class == "SurfaceGui" end
	if want == "Light" then return class == "PointLight" or class == "SpotLight" or class == "SurfaceLight" end
	if want == "PostEffect" then return class == "ColorCorrectionEffect" or class == "BlurEffect" or class == "BloomEffect" end
	if want == "LuaSourceContainer" then return class == "ModuleScript" or class == "LocalScript" or class == "Script" end
	if want == "GuiButton" then return class == "TextButton" or class == "ImageButton" end
	return false
end
local methods = {}
local classMethods = {}
local function setParent(obj, parent)
	local d = D[obj]
	if d.destroyed and parent ~= nil then
		error("Parent у уничтоженного " .. d.Name, 3)
	end
	if d.parent then
		local list = D[d.parent].children
		for i, c in ipairs(list) do
			if c == obj then table.remove(list, i) break end
		end
	end
	d.parent = parent
	if parent then
		table.insert(D[parent].children, obj)
	end
end
Inst.__index = function(obj, k)
	local d = D[obj]
	if k == "Parent" then return d.parent end
	if k == "ClassName" then return d.ClassName end
	if k == "Name" then return d.Name end
	local v = d.props[k]
	if v ~= nil then return v end
	local cm = classMethods[d.ClassName]
	if cm and cm[k] then return cm[k] end
	if methods[k] then return methods[k] end
	if k == "Position" and (BASEPART[d.ClassName] or d.ClassName == "Camera") then
		return (d.props.CFrame or CFrame.identity).Position
	end
	if k == "Position" and d.ClassName == "Attachment" then return v3(0, 0, 0) end
	if k == "WorldPosition" or k == "WorldCFrame" then
		local parent = d.parent
		local base = parent and D[parent].props.CFrame or CFrame.identity
		local own = d.props.CFrame or CFrame.new(d.props.Position or v3(0, 0, 0))
		return k == "WorldPosition" and (base * own).Position or base * own
	end
	for _, c in ipairs(d.children) do
		if D[c].Name == k then return c end
	end
	if k:match("Changed$") or k == "Touched" or k == "ChildAdded" or k == "DescendantAdded" or k == "AncestryChanged" or k == "Destroying"
		or k == "Completed" or k == "Ended" or k == "Died" or k == "MouseButton1Click" or k == "Activated" or k == "MouseEnter" or k == "MouseLeave"
		or k == "InputBegan" or k == "InputEnded" or k == "CharacterAdded" or k == "PlayerAdded" or k == "PlayerRemoving" or k == "OnClientEvent"
		or k == "OnServerEvent" or k == "Event" or k == "Heartbeat" or k == "RenderStepped" or k == "Stepped" or k == "InputChanged" then
		local s = d.signals[k]
		if not s then s = signal() d.signals[k] = s end
		return s
	end
	if DEFAULTS[k] ~= nil then return DEFAULTS[k] end
	local key = d.ClassName .. "." .. k
	if not SIM.unknown[key] then
		SIM.unknown[key] = true
	end
	return nil
end
local CHECK = { CFrame = "CFrame", Size = "Vector3", Position = "Vector3", Color = "Color3", Transparency = "number", BackgroundColor3 = "Color3", TextColor3 = "Color3", FillColor = "Color3" }
Inst.__newindex = function(obj, k, v)
	local d = D[obj]
	if k == "Parent" then
		if v ~= nil and typeof(v) ~= "Instance" then error("Parent: не экземпляр", 2) end
		setParent(obj, v)
		return
	end
	if k == "Name" then d.Name = tostring(v) return end
	local want = CHECK[k]
	if not BASEPART[d.ClassName] and k ~= "CFrame" then
		want = nil
	end
	if want and typeof(v) ~= want then
		error(("%s.%s = %s (нужен %s)"):format(d.ClassName, k, typeof(v), want), 2)
	end
	if want == "CFrame" and cfNaN(v) or want == "Vector3" and v3NaN(v) or want == "number" and isNaN(v) then
		local key = d.ClassName .. "." .. d.Name .. "." .. k
		if not SIM.nan[key] then
			SIM.nan[key] = debug.traceback("NaN " .. key, 2)
		end
	end
	if k == "Position" and BASEPART[d.ClassName] then
		local old = d.props.CFrame or CFrame.identity
		d.props.CFrame = cf(v, old.r, old.u, old.b)
		return
	end
	d.props[k] = v
	local s = d.signals[k .. "Changed"]
end
Inst.__tostring = function(obj) return D[obj].Name end
function methods.IsA(obj, want) return isA(D[obj].ClassName, want) end
function methods.FindFirstChild(obj, name, recursive)
	for _, c in ipairs(D[obj].children) do
		if D[c].Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(D[obj].children) do
			local found = methods.FindFirstChild(c, name, true)
			if found then return found end
		end
	end
	return nil
end
function methods.WaitForChild(obj, name)
	local c = methods.FindFirstChild(obj, name)
	if not c then error("WaitForChild: нет " .. name .. " у " .. D[obj].Name, 2) end
	return c
end
function methods.FindFirstChildOfClass(obj, class)
	for _, c in ipairs(D[obj].children) do
		if D[c].ClassName == class then return c end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(obj, class, recursive)
	for _, c in ipairs(D[obj].children) do
		if isA(D[c].ClassName, class) then return c end
	end
	if recursive then
		for _, c in ipairs(D[obj].children) do
			local f = methods.FindFirstChildWhichIsA(c, class, true)
			if f then return f end
		end
	end
	return nil
end
function methods.FindFirstAncestor(obj, name)
	local p = D[obj].parent
	while p do
		if D[p].Name == name then return p end
		p = D[p].parent
	end
	return nil
end
function methods.FindFirstAncestorOfClass(obj, class)
	local p = D[obj].parent
	while p do
		if D[p].ClassName == class then return p end
		p = D[p].parent
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(obj, class)
	local p = D[obj].parent
	while p do
		if isA(D[p].ClassName, class) then return p end
		p = D[p].parent
	end
	return nil
end
function methods.IsDescendantOf(obj, anc)
	local p = D[obj].parent
	while p do
		if p == anc then return true end
		p = D[p].parent
	end
	return false
end
function methods.GetChildren(obj) return table.clone(D[obj].children) end
function methods.GetDescendants(obj)
	local out = {}
	local function walk(o)
		for _, c in ipairs(D[o].children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(obj)
	return out
end
function methods.Destroy(obj)
	local d = D[obj]
	if d.destroyed then return end
	for _, c in ipairs(table.clone(d.children)) do methods.Destroy(c) end
	setParent(obj, nil)
	d.destroyed = true
end
function methods.Remove(obj) methods.Destroy(obj) end
function methods.ClearAllChildren(obj)
	for _, c in ipairs(table.clone(D[obj].children)) do methods.Destroy(c) end
end
function methods.Clone(obj)
	local d = D[obj]
	local copy = newInstance(d.ClassName)
	local cd = D[copy]
	cd.Name = d.Name
	for k, v in pairs(d.props) do cd.props[k] = v end
	for k, v in pairs(d.attributes) do cd.attributes[k] = v end
	for _, c in ipairs(d.children) do
		local cc = methods.Clone(c)
		setParent(cc, copy)
	end
	return copy
end
function methods.GetAttribute(obj, name) return D[obj].attributes[name] end
function methods.SetAttribute(obj, name, value) D[obj].attributes[name] = value end
function methods.GetAttributes(obj) return table.clone(D[obj].attributes) end
function methods.GetPropertyChangedSignal(obj, name)
	local d = D[obj]
	local s = d.signals["prop:" .. name]
	if not s then s = signal() d.signals["prop:" .. name] = s end
	return s
end
function methods.GetAttributeChangedSignal(obj, name) return methods.GetPropertyChangedSignal(obj, "attr:" .. name) end
function methods.Emit(obj, n) D[obj].emitted = (D[obj].emitted or 0) + (n or 1) end
function methods.Clear(obj) end
function methods.Play(obj) D[obj].props.IsPlaying = true end
function methods.Stop(obj) D[obj].props.IsPlaying = false end
function methods.Pause(obj) end
function methods.Resume(obj) end
function methods.AdjustSpeed(obj) end
function methods.AdjustWeight(obj) end
function methods.GetPivot(obj)
	local d = D[obj]
	if d.props.CFrame then return d.props.CFrame end
	local primary = d.props.PrimaryPart
	if primary then return primary.CFrame end
	for _, c in ipairs(methods.GetDescendants(obj)) do
		if BASEPART[D[c].ClassName] then return c.CFrame end
	end
	return CFrame.identity
end
function methods.PivotTo(obj, target)
	local d = D[obj]
	if BASEPART[d.ClassName] then obj.CFrame = target return end
	local pivot = methods.GetPivot(obj)
	local delta = target * pivot:Inverse()
	for _, c in ipairs(methods.GetDescendants(obj)) do
		if BASEPART[D[c].ClassName] then c.CFrame = delta * c.CFrame end
	end
end
function methods.GetBoundingBox(obj) return methods.GetPivot(obj), v3(4, 6, 2) end
function methods.GetExtentsSize(obj) return v3(4, 6, 2) end
function methods.ScaleTo(obj) end
function methods.GetScale(obj) return 1 end
function methods.LoadAnimation(obj) local t = newInstance("AnimationTrack") return t end
function methods.GetPlayingAnimationTracks(obj) return {} end
function methods.ApplyImpulse(obj) end
function methods.SetNetworkOwner(obj) end
function methods.BreakJoints(obj) end
function methods.Fire(obj, ...) end
function methods.FireServer(obj, ...) end
function methods.FireClient(obj, ...) end
function methods.InvokeServer(obj, ...) return nil end
function methods.TweenSize(obj) end
function methods.TweenPosition(obj) end
function methods.ChangeState(obj) end
function methods.GetState(obj) return Enum.HumanoidStateType.Running end
function methods.MoveTo(obj) end
function methods.GetFullName(obj)
	local parts = {}
	local o = obj
	while o do table.insert(parts, 1, D[o].Name) o = D[o].parent end
	return table.concat(parts, ".")
end

local Instance = { new = function(class, parent)
	local obj = newInstance(class)
	if class == "Model" then D[obj].props.WorldPivot = CFrame.identity end
	if parent then obj.Parent = parent end
	return obj
end }

-- ===== Службы =====
local game = newInstance("DataModel")
D[game].Name = "Game"
local services = {}
local function service(name)
	local s = services[name]
	if not s then
		s = newInstance(name)
		D[s].Name = name
		setParent(s, game)
		services[name] = s
	end
	return s
end
classMethods.DataModel = {
	GetService = function(_, name) return service(name) end,
	FindService = function(_, name) return service(name) end,
	IsLoaded = function() return true end,
}
local workspace = service("Workspace")
SIM.rayHook = nil
classMethods.Workspace = {
	Raycast = function(_, origin, direction, params)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then error("Raycast: не Vector3", 2) end
		if v3NaN(origin) or v3NaN(direction) then simError("Raycast: NaN " .. debug.traceback()) end
		if SIM.rayHook then return SIM.rayHook(origin, direction, params) end
		return nil
	end,
	BulkMoveTo = function(_, parts, cframes)
		if #parts ~= #cframes then error("BulkMoveTo: разное число", 2) end
		for i, p in ipairs(parts) do p.CFrame = cframes[i] end
	end,
	GetServerTimeNow = function() return SIM.now end,
	GetPartBoundsInRadius = function() return {} end,
	GetPartBoundsInBox = function() return {} end,
	GetPartsInPart = function() return {} end,
	Spherecast = function() return nil end,
	Blockcast = function() return nil end,
}
local camera = newInstance("Camera")
setParent(camera, workspace)
D[workspace].props.CurrentCamera = camera
camera.CFrame = CFrame.new(0, 10, 20)
SIM.renderBinds = {}
local runService = service("RunService")
classMethods.RunService = {
	IsStudio = function() return true end,
	IsClient = function() return true end,
	IsServer = function() return false end,
	IsRunning = function() return true end,
	BindToRenderStep = function(_, name, prio, fn)
		SIM.renderBinds[name] = { prio = prio, fn = fn }
	end,
	UnbindFromRenderStep = function(_, name)
		SIM.renderBinds[name] = nil
	end,
}
classMethods.TweenService = {
	Create = function(_, inst, info, goal)
		if typeof(inst) ~= "Instance" then error("TweenService:Create: не экземпляр", 2) end
		for k, v in pairs(goal) do
			local want = CHECK[k]
			if not BASEPART[D[inst].ClassName] and k ~= "CFrame" then want = nil end
			if want and typeof(v) ~= want then error("Tween " .. k .. " = " .. typeof(v), 2) end
		end
		local tw = { Completed = signal(), PlaybackState = Enum.PlaybackState.Begin }
		function tw:Play()
			task.delay(info.Time or 0, function()
				if tw.cancelled then return end
				for k, v in pairs(goal) do
					if not D[inst].destroyed then inst[k] = v end
				end
				tw.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function tw:Cancel() tw.cancelled = true end
		function tw:Pause() end
		function tw:Destroy() end
		return tw
	end,
	GetValue = function(_, a) return a end,
}
classMethods.Debris = {
	AddItem = function(_, inst, t)
		task.delay(t or 10, function()
			if inst and D[inst] then methods.Destroy(inst) end
		end)
	end,
}
local players = service("Players")
local localPlayer = newInstance("Player")
D[localPlayer].Name = "Artem"
setParent(localPlayer, players)
local playerGui = newInstance("PlayerGui")
D[playerGui].Name = "PlayerGui"
setParent(playerGui, localPlayer)
local playerScripts = newInstance("PlayerScripts")
D[playerScripts].Name = "PlayerScripts"
setParent(playerScripts, localPlayer)
D[players].props.LocalPlayer = localPlayer
D[localPlayer].props.UserId = 1
classMethods.Players = {
	GetPlayers = function() return { localPlayer } end,
	GetPlayerFromCharacter = function(_, ch) return ch == localPlayer.Character and localPlayer or nil end,
}
classMethods.Player = {
	GetMouse = function() return newInstance("Mouse") end,
	Kick = function() end,
}
classMethods.UserInputService = {
	IsKeyDown = function() return false end,
	IsMouseButtonPressed = function() return false end,
	GetMouseLocation = function() return Vector2.new(960, 540) end,
	GetMouseDelta = function() return Vector2.new(0, 0) end,
	GetLastInputType = function() return Enum.UserInputType.Keyboard end,
}
classMethods.GuiService = { GetGuiInset = function() return Vector2.new(0, 36), Vector2.new(0, 0) end }
classMethods.TextService = { GetTextSize = function(_, text, size) return Vector2.new(#text * size * 0.6, size) end }
classMethods.SoundService = { PlayLocalSound = function() end }
classMethods.ContentProvider = { PreloadAsync = function() end }
classMethods.HttpService = {
	JSONEncode = function() return "{}" end,
	JSONDecode = function() return {} end,
	GenerateGUID = function() return "guid" end,
}
local function makeCharacter(position)
	local ch = Instance.new("Model")
	ch.Name = "Artem"
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = CFrame.new(position)
	hrp.Parent = ch
	local hum = Instance.new("Humanoid")
	hum.Parent = ch
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(position + v3(0, 1.5, 0))
	head.Parent = ch
	ch.Parent = workspace
	D[localPlayer].props.Character = ch
	return ch
end
