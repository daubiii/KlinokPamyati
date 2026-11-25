--!nonstrict
-- Мини-движок Roblox для прогона клиентских эффектов без Studio (tools/fxsim).
-- Виртуальное время, task/Debris/TweenService/RenderStepped, Instance с проверкой типов
-- ключевых свойств, CFrame/Vector3/Color3/последовательности. Не рендерит — считает.

local OUT = _G.print
local VT = 0
local FRAME = 1 / 60
local LOG = { warns = {}, errors = {}, prints = 0 }
local SIM = { hitStops = {}, sfx = {}, fov = {}, shake = {} }

local function fail(msg)
	error(msg, 3)
end

local function isnan(x)
	return x ~= x or x == math.huge or x == -math.huge
end

-- ===== typeof =====
local rawtypeof = typeof
local function mytypeof(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__type") then
			return rawget(mt, "__type")
		end
	end
	return rawtypeof(v)
end
local typeof = mytypeof

-- ===== Vector3 =====
local V3MT = { __type = "Vector3" }
local Vector3 = {}
local function v3(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	if isnan(x) or isnan(y) or isnan(z) then
		fail("Vector3 с NaN/inf")
	end
	return setmetatable({ X = x, Y = y, Z = z }, V3MT)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
local V3M = {}
function V3M.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function V3M.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V3M.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function V3M.Abs(a) return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end
function V3M.Min(a, b) return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
function V3M.Max(a, b) return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
function V3M.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
function V3M.Angle(a, b) return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)) end
V3MT.__index = function(v, k)
	if k == "Magnitude" or k == "magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" or k == "unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m < 1e-12 then
			return v3(0, 0, 0) -- в Roblox Unit нулевого вектора = NaN; считаем это ошибкой ниже
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then return rawget(v, "X")
	elseif k == "y" then return rawget(v, "Y")
	elseif k == "z" then return rawget(v, "Z")
	end
	return V3M[k]
end
V3MT.__add = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then fail("Vector3 + " .. typeof(a) .. "/" .. typeof(b)) end
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3MT.__sub = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then fail("Vector3 - " .. typeof(a) .. "/" .. typeof(b)) end
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3MT.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
	fail("Vector3 * " .. typeof(a) .. "/" .. typeof(b))
end
V3MT.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	if typeof(b) == "Vector3" then return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
	fail("Vector3 / " .. typeof(b))
end
V3MT.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3MT.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3MT.__tostring = function(v) return string.format("%.2f, %.2f, %.2f", v.X, v.Y, v.Z) end

-- ===== Vector2 / UDim / UDim2 =====
local V2MT = { __type = "Vector2" }
local Vector2 = {}
function Vector2.new(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2MT) end
Vector2.zero = Vector2.new(0, 0)
V2MT.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2) end
	if k == "Lerp" then return function(a, b, t) return Vector2.new(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end end
end
V2MT.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
V2MT.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2MT.__mul = function(a, b)
	if type(a) == "number" then return Vector2.new(b.X * a, b.Y * a) end
	if type(b) == "number" then return Vector2.new(a.X * b, a.Y * b) end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end

local UDMT = { __type = "UDim" }
local UDim = {}
function UDim.new(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDMT) end
local UD2MT = { __type = "UDim2" }
local UDim2 = {}
function UDim2.new(sx, ox, sy, oy)
	if typeof(sx) == "UDim" then
		return setmetatable({ X = sx, Y = ox }, UD2MT)
	end
	return setmetatable({ X = UDim.new(sx, ox), Y = UDim.new(sy, oy) }, UD2MT)
end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
UD2MT.__index = function(u, k)
	if k == "Lerp" then
		return function(a, b, t)
			return UDim2.new(a.X.Scale + (b.X.Scale - a.X.Scale) * t, a.X.Offset + (b.X.Offset - a.X.Offset) * t,
				a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t, a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t)
		end
	end
	if k == "Width" then return rawget(u, "X") end
	if k == "Height" then return rawget(u, "Y") end
end
UD2MT.__add = function(a, b) return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end

-- ===== CFrame =====
local CFMT = { __type = "CFrame" }
local CFrame = {}
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	local c = setmetatable({ x = x, y = y, z = z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, CFMT)
	for i = 1, 9 do
		if isnan(c[i]) then fail("CFrame с NaN") end
	end
	if isnan(x) or isnan(y) or isnan(z) then fail("CFrame с NaN") end
	return c
end
local function cfFromBasis(p, rx, uy, bz)
	return cf(p.X, p.Y, p.Z, rx.X, uy.X, bz.X, rx.Y, uy.Y, bz.Y, rx.Z, uy.Z, bz.Z)
end
function CFrame.new(a, b, c, ...)
	if a == nil then
		return cf(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	if typeof(a) == "Vector3" then
		if typeof(b) == "Vector3" then
			return CFrame.lookAt(a, b)
		end
		return cf(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	local rest = { ... }
	if #rest == 9 then
		return cf(a, b, c, table.unpack(rest))
	end
	if type(a) ~= "number" then fail("CFrame.new(" .. typeof(a) .. ")") end
	return cf(a, b or 0, c or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end
CFrame.identity = CFrame.new()
function CFrame.lookAt(at, target, up)
	if typeof(at) ~= "Vector3" or typeof(target) ~= "Vector3" then fail("CFrame.lookAt: не Vector3") end
	up = up or Vector3.yAxis
	local d = target - at
	if d.Magnitude < 1e-9 then
		return CFrame.new(at)
	end
	local look = d.Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.zAxis)
		if right.Magnitude < 1e-6 then right = Vector3.xAxis end
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return cfFromBasis(at, right, up2, -look)
end
function CFrame.fromMatrix(p, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return cfFromBasis(p, vx, vy, vz)
end
local function rotX(a) local c, s = math.cos(a), math.sin(a) return cf(0, 0, 0, 1, 0, 0, 0, c, -s, 0, s, c) end
local function rotY(a) local c, s = math.cos(a), math.sin(a) return cf(0, 0, 0, c, 0, s, 0, 1, 0, -s, 0, c) end
local function rotZ(a) local c, s = math.cos(a), math.sin(a) return cf(0, 0, 0, c, -s, 0, s, c, 0, 0, 0, 1) end
function CFrame.Angles(rx, ry, rz)
	return rotX(rx or 0) * rotY(ry or 0) * rotZ(rz or 0)
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromOrientation(rx, ry, rz)
	return rotY(ry or 0) * rotX(rx or 0) * rotZ(rz or 0)
end
CFrame.fromEulerAnglesYXZ = CFrame.fromOrientation
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0,
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c)
end
local function rotV(c, v)
	return v3(c[1] * v.X + c[2] * v.Y + c[3] * v.Z, c[4] * v.X + c[5] * v.Y + c[6] * v.Z, c[7] * v.X + c[8] * v.Y + c[9] * v.Z)
end
local function rotTV(c, v)
	return v3(c[1] * v.X + c[4] * v.Y + c[7] * v.Z, c[2] * v.X + c[5] * v.Y + c[8] * v.Z, c[3] * v.X + c[6] * v.Y + c[9] * v.Z)
end
local function cfMul(a, b)
	local p = rotV(a, v3(b.x, b.y, b.z))
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local sum = 0
			for k = 0, 2 do
				sum += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = sum
		end
	end
	return cf(a.x + p.X, a.y + p.Y, a.z + p.Z, table.unpack(r))
end
local function cfInverse(c)
	local p = rotTV(c, v3(-c.x, -c.y, -c.z))
	return cf(p.X, p.Y, p.Z, c[1], c[4], c[7], c[2], c[5], c[8], c[3], c[6], c[9])
end
local CFM = {}
function CFM.Inverse(c) return cfInverse(c) end
function CFM.Lerp(a, b, t)
	local p = v3(a.x, a.y, a.z):Lerp(v3(b.x, b.y, b.z), t)
	local rx = v3(a[1], a[4], a[7]):Lerp(v3(b[1], b[4], b[7]), t)
	local uy = v3(a[2], a[5], a[8]):Lerp(v3(b[2], b[5], b[8]), t)
	if rx.Magnitude < 1e-6 or uy.Magnitude < 1e-6 then
		return t < 0.5 and a or b
	end
	rx = rx.Unit
	local bz = rx:Cross(uy)
	if bz.Magnitude < 1e-6 then return t < 0.5 and a or b end
	bz = bz.Unit
	uy = bz:Cross(rx)
	return cfFromBasis(p, rx, uy, bz)
end
function CFM.VectorToWorldSpace(c, v) return rotV(c, v) end
function CFM.VectorToObjectSpace(c, v) return rotTV(c, v) end
function CFM.PointToWorldSpace(c, v) return c * v end
function CFM.PointToObjectSpace(c, v) return rotTV(c, v - v3(c.x, c.y, c.z)) end
function CFM.ToWorldSpace(c, o) return c * o end
function CFM.ToObjectSpace(c, o) return cfInverse(c) * o end
function CFM.GetComponents(c) return c.x, c.y, c.z, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9] end
CFM.components = CFM.GetComponents
function CFM.ToEulerAnglesXYZ(c)
	local ry = math.asin(math.clamp(c[3], -1, 1))
	local rx = math.atan2(-c[6], c[9])
	local rz = math.atan2(-c[2], c[1])
	return rx, ry, rz
end
function CFM.ToOrientation(c)
	local rx = math.asin(math.clamp(-c[6], -1, 1))
	local ry = math.atan2(c[3], c[9])
	local rz = math.atan2(c[4], c[5])
	return rx, ry, rz
end
function CFM.ToAxisAngle(c)
	return Vector3.yAxis, 0
end
function CFM.Orthonormalize(c) return c end
CFMT.__index = function(c, k)
	if k == "Position" or k == "p" then return v3(rawget(c, "x"), rawget(c, "y"), rawget(c, "z")) end
	if k == "X" then return rawget(c, "x") end
	if k == "Y" then return rawget(c, "y") end
	if k == "Z" then return rawget(c, "z") end
	if k == "LookVector" or k == "lookVector" then return v3(-c[3], -c[6], -c[9]) end
	if k == "RightVector" or k == "XVector" then return v3(c[1], c[4], c[7]) end
	if k == "UpVector" or k == "YVector" then return v3(c[2], c[5], c[8]) end
	if k == "ZVector" then return v3(c[3], c[6], c[9]) end
	if k == "Rotation" then return cf(0, 0, 0, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9]) end
	return CFM[k]
end
CFMT.__mul = function(a, b)
	if typeof(a) ~= "CFrame" then fail("CFrame * : левый " .. typeof(a)) end
	if typeof(b) == "CFrame" then return cfMul(a, b) end
	if typeof(b) == "Vector3" then return rotV(a, b) + v3(a.x, a.y, a.z) end
	fail("CFrame * " .. typeof(b))
end
CFMT.__add = function(a, b)
	if typeof(b) ~= "Vector3" then fail("CFrame + " .. typeof(b)) end
	return cf(a.x + b.X, a.y + b.Y, a.z + b.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
end
CFMT.__sub = function(a, b)
	if typeof(b) ~= "Vector3" then fail("CFrame - " .. typeof(b)) end
	return cf(a.x - b.X, a.y - b.Y, a.z - b.Z, a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9])
end

-- ===== Color3 =====
local C3MT = { __type = "Color3" }
local Color3 = {}
local function c3(r, g, b)
	r, g, b = r or 0, g or 0, b or 0
	if isnan(r) or isnan(g) or isnan(b) then fail("Color3 с NaN") end
	return setmetatable({ R = r, G = g, B = b }, C3MT)
end
Color3.new = c3
function Color3.fromRGB(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(hex)
	if type(hex) ~= "string" then error("fromHex: не строка") end
	local h = hex:gsub("#", "")
	if #h ~= 6 or not h:match("^%x+$") then error("Unable to convert hex " .. hex) end
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
	elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) end
	return c3(v, p, q)
end
local C3M = {}
function C3M.Lerp(a, b, t)
	if typeof(b) ~= "Color3" then fail("Color3:Lerp(" .. typeof(b) .. ")") end
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3M.ToHSV(c)
	local mx, mn = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = mx - mn
	local h = 0
	if d > 0 then
		if mx == c.R then h = ((c.G - c.B) / d) % 6 elseif mx == c.G then h = (c.B - c.R) / d + 2 else h = (c.R - c.G) / d + 4 end
		h /= 6
	end
	return h, mx > 0 and d / mx or 0, mx
end
function C3M.ToHex(c) return string.format("%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255) end
C3MT.__index = function(c, k)
	if k == "r" then return rawget(c, "R") elseif k == "g" then return rawget(c, "G") elseif k == "b" then return rawget(c, "B") end
	return C3M[k]
end
C3MT.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end

-- ===== Последовательности и диапазоны =====
local NSKMT = { __type = "NumberSequenceKeypoint" }
local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(t, v, e)
	if type(t) ~= "number" or type(v) ~= "number" then fail("NumberSequenceKeypoint: не числа") end
	return setmetatable({ Time = t, Value = v, Envelope = e or 0 }, NSKMT)
end
local NSMT = { __type = "NumberSequence" }
local NumberSequence = {}
function NumberSequence.new(a, b)
	local points
	if type(a) == "number" then
		points = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) }
	elseif type(a) == "table" then
		points = a
	else
		fail("NumberSequence.new(" .. typeof(a) .. ")")
	end
	if #points < 2 or #points > 20 then fail("NumberSequence: точек " .. #points) end
	if points[1].Time ~= 0 or math.abs(points[#points].Time - 1) > 1e-9 then fail("NumberSequence: время не от 0 до 1") end
	for i = 2, #points do
		if points[i].Time < points[i - 1].Time then fail("NumberSequence: время убывает") end
	end
	for _, p in ipairs(points) do
		if isnan(p.Value) then fail("NumberSequence: NaN") end
	end
	return setmetatable({ Keypoints = points }, NSMT)
end
local CSKMT = { __type = "ColorSequenceKeypoint" }
local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, c)
	if typeof(c) ~= "Color3" then fail("ColorSequenceKeypoint: не Color3, а " .. typeof(c)) end
	return setmetatable({ Time = t, Value = c }, CSKMT)
end
local CSMT = { __type = "ColorSequence" }
local ColorSequence = {}
function ColorSequence.new(a, b)
	local points
	if typeof(a) == "Color3" then
		if b ~= nil and typeof(b) ~= "Color3" then fail("ColorSequence.new(Color3, " .. typeof(b) .. ")") end
		points = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) }
	elseif type(a) == "table" and getmetatable(a) == nil then
		points = a
	else
		fail("ColorSequence.new(" .. typeof(a) .. ")")
	end
	if #points < 2 or #points > 20 then fail("ColorSequence: точек " .. #points) end
	if points[1].Time ~= 0 or math.abs(points[#points].Time - 1) > 1e-9 then fail("ColorSequence: время не от 0 до 1") end
	return setmetatable({ Keypoints = points }, CSMT)
end
local NRMT = { __type = "NumberRange" }
local NumberRange = {}
function NumberRange.new(a, b)
	b = b or a
	if type(a) ~= "number" or type(b) ~= "number" then fail("NumberRange: не числа") end
	if b < a then fail(("NumberRange: max < min (%s, %s)"):format(a, b)) end
	return setmetatable({ Min = a, Max = b }, NRMT)
end

-- ===== Enum =====
local enumCache = {}
local EIMT = { __type = "EnumItem" }
EIMT.__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end
local Enum = setmetatable({}, {
	__index = function(_, typeName)
		local cache = enumCache[typeName]
		if not cache then
			cache = setmetatable({}, {
				__index = function(t, itemName)
					local item = setmetatable({ EnumType = typeName, Name = itemName, Value = 0 }, EIMT)
					rawset(t, itemName, item)
					return item
				end,
			})
			enumCache[typeName] = cache
		end
		return cache
	end,
})

-- ===== Прочее =====
local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return { Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0 }
end
local RaycastParams = {}
function RaycastParams.new() return { FilterType = nil, FilterDescendantsInstances = {}, RespectCanCollide = false } end
local OverlapParams = RaycastParams
local RNGMT = {}
RNGMT.__index = {
	NextNumber = function(_, a, b)
		a, b = a or 0, b or 1
		return a + (b - a) * math.random()
	end,
	NextInteger = function(_, a, b) return math.random(a, b) end,
}
local Random = {}
function Random.new() return setmetatable({}, RNGMT) end

-- ===== Планировщик =====
local queue = {}
local function schedule(t, fn, args)
	table.insert(queue, { t = t, fn = fn, args = args, seq = #queue })
end
local function runFn(fn, ...)
	local co = type(fn) == "thread" and fn or coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(LOG.errors, ("[t=%.2f] %s"):format(VT, tostring(err)))
	end
	return co
end
local task = {}
function task.spawn(fn, ...)
	return runFn(fn, ...)
end
function task.defer(fn, ...)
	schedule(VT, fn, { ... })
end
function task.delay(d, fn, ...)
	schedule(VT + math.max(d or 0, 0), fn, { ... })
end
function task.wait(d)
	local co = coroutine.running()
	schedule(VT + math.max(d or FRAME, FRAME), co, {})
	coroutine.yield()
	return d or FRAME
end
function task.cancel() end
local os = setmetatable({ clock = function() return VT end, time = function() return 1e6 + VT end }, { __index = _G.os })
local function tick() return VT end
local function time() return VT end
local function delay(d, fn) task.delay(d, fn) end
local function spawn(fn) task.spawn(fn) end
local function wait(d) return task.wait(d) end

-- ===== Сигналы =====
local function Signal()
	local s = { list = {} }
	function s:Connect(fn)
		local conn = { Connected = true }
		function conn.Disconnect()
			conn.Connected = false
			for i, item in ipairs(s.list) do
				if item == conn then
					table.remove(s.list, i)
					break
				end
			end
		end
		conn.fn = fn
		table.insert(s.list, conn)
		return conn
	end
	function s:Once(fn)
		local conn
		conn = s:Connect(function(...)
			conn.Disconnect()
			fn(...)
		end)
		return conn
	end
	function s:Wait()
		local co = coroutine.running()
		s:Once(function(...)
			task.spawn(co, ...)
		end)
		return coroutine.yield()
	end
	function s:Fire(...)
		local copy = table.clone(s.list)
		for _, conn in ipairs(copy) do
			if conn.Connected then
				local ok, err = pcall(conn.fn, ...)
				if not ok then
					table.insert(LOG.errors, ("[t=%.2f] signal: %s"):format(VT, tostring(err)))
				end
			end
		end
	end
	return s
end

-- ===== Instance =====
local ISA = {
	Part = { "BasePart", "PVInstance" }, MeshPart = { "BasePart", "PVInstance" }, WedgePart = { "BasePart", "PVInstance" },
	Model = { "PVInstance" }, Workspace = { "Model", "PVInstance" },
	Frame = { "GuiObject", "GuiBase2d" }, ImageLabel = { "GuiObject", "GuiBase2d" }, TextLabel = { "GuiObject", "GuiBase2d" },
	ScreenGui = { "LayerCollector", "GuiBase2d" }, SurfaceGui = { "LayerCollector", "SurfaceGuiBase", "GuiBase2d" },
	BillboardGui = { "LayerCollector", "GuiBase2d" },
	PointLight = { "Light" }, SpotLight = { "Light" },
	ColorCorrectionEffect = { "PostEffect" }, BloomEffect = { "PostEffect" },
	SpecialMesh = { "DataModelMesh", "FileMesh" },
	Script = { "BaseScript", "LuaSourceContainer" }, LocalScript = { "BaseScript", "LuaSourceContainer" }, ModuleScript = { "LuaSourceContainer" },
}
local TYPES = {
	ParticleEmitter = { Color = "ColorSequence", Size = "NumberSequence", Transparency = "NumberSequence", Lifetime = "NumberRange", Speed = "NumberRange",
		Rate = "number", Rotation = "NumberRange", RotSpeed = "NumberRange", Acceleration = "Vector3", SpreadAngle = "Vector2", Squash = "NumberSequence",
		Texture = "string", LightEmission = "number", LightInfluence = "number", Drag = "number", Brightness = "number", ZOffset = "number",
		EmissionDirection = "EnumItem", Shape = "EnumItem", ShapeStyle = "EnumItem", ShapeInOut = "EnumItem", Orientation = "EnumItem",
		Enabled = "boolean", LockedToPart = "boolean", TimeScale = "number", VelocityInheritance = "number" },
	Part = { Size = "Vector3", CFrame = "CFrame", Position = "Vector3", Color = "Color3", Transparency = "number", Material = "EnumItem",
		Anchored = "boolean", CanCollide = "boolean", Shape = "EnumItem", Reflectance = "number", Orientation = "Vector3" },
	Beam = { Color = "ColorSequence", Transparency = "NumberSequence", Width0 = "number", Width1 = "number", Brightness = "number", Texture = "string",
		TextureSpeed = "number", TextureLength = "number", Segments = "number", CurveSize0 = "number", CurveSize1 = "number" },
	Trail = { Color = "ColorSequence", Transparency = "NumberSequence", WidthScale = "NumberSequence", Lifetime = "number", Brightness = "number" },
	PointLight = { Brightness = "number", Range = "number", Color = "Color3" },
	Frame = { Size = "UDim2", Position = "UDim2", BackgroundTransparency = "number", BackgroundColor3 = "Color3", Rotation = "number", AnchorPoint = "Vector2" },
	ImageLabel = { Size = "UDim2", Position = "UDim2", ImageTransparency = "number", ImageColor3 = "Color3", Rotation = "number", Image = "string", BackgroundTransparency = "number" },
	TextLabel = { Size = "UDim2", Position = "UDim2", TextTransparency = "number", TextColor3 = "Color3", Text = "string", TextStrokeTransparency = "number",
		TextStrokeColor3 = "Color3", Rotation = "number", BackgroundTransparency = "number", Font = "EnumItem" },
	BillboardGui = { Size = "UDim2", StudsOffset = "Vector3", Brightness = "number", LightInfluence = "number" },
	SurfaceGui = { CanvasSize = "Vector2", Brightness = "number", LightInfluence = "number" },
	ColorCorrectionEffect = { TintColor = "Color3", Brightness = "number", Contrast = "number", Saturation = "number" },
	UIStroke = { Thickness = "number", Transparency = "number", Color = "Color3" },
	Attachment = { Position = "Vector3", CFrame = "CFrame" },
	SpecialMesh = { Scale = "Vector3", MeshType = "EnumItem" },
}
TYPES.MeshPart = TYPES.Part
TYPES.WedgePart = TYPES.Part
local DEFAULTS = {
	Part = { Size = v3(4, 1, 2), Color = c3(0.64, 0.64, 0.64), Transparency = 0, CFrame = nil, Anchored = false, Material = Enum.Material.Plastic },
	ParticleEmitter = { Rate = 5, Enabled = true },
	PointLight = { Brightness = 1, Range = 8, Color = c3(1, 1, 1) },
	Frame = { BackgroundTransparency = 0, Rotation = 0 },
	ImageLabel = { ImageTransparency = 0, BackgroundTransparency = 0, Rotation = 0 },
	TextLabel = { TextTransparency = 0, TextStrokeTransparency = 1, BackgroundTransparency = 0, Rotation = 0, Text = "Label" },
	UIStroke = { Transparency = 0, Thickness = 1 },
	Beam = { Width0 = 1, Width1 = 1, Brightness = 1 },
	Trail = { Lifetime = 2, Brightness = 1 },
	ColorCorrectionEffect = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = c3(1, 1, 1) },
	Sound = { Volume = 0.5, PlaybackSpeed = 1, TimePosition = 0 },
	Attachment = { Position = v3(0, 0, 0) },
	Model = {},
}
DEFAULTS.MeshPart = DEFAULTS.Part
DEFAULTS.WedgePart = DEFAULTS.Part
local EVENTS = { Ended = true, Completed = true, Changed = true, Touched = true, ChildAdded = true, ChildRemoved = true, AncestryChanged = true,
	Died = true, Destroying = true, DescendantAdded = true, DescendantRemoving = true, Activated = true, MouseButton1Click = true }

local ALL = {} -- все живые экземпляры
local INST = {}
local IMT = { __type = "Instance" }
local Instance = {}

local function clsOf(inst) return rawget(inst, "_p").ClassName end
local function isA(inst, name)
	local cls = clsOf(inst)
	if cls == name or name == "Instance" then return true end
	for _, base in ipairs(ISA[cls] or {}) do
		if base == name then return true end
	end
	return false
end

local function children(inst) return rawget(inst, "_c") end

local function removeChild(parent, child)
	local list = children(parent)
	for i, c in ipairs(list) do
		if c == child then
			table.remove(list, i)
			return
		end
	end
end

local function descendants(inst, out)
	out = out or {}
	for _, c in ipairs(children(inst)) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local function destroy(inst)
	local p = rawget(inst, "_p")
	if rawget(inst, "_dead") then return end
	for _, c in ipairs(table.clone(children(inst))) do
		destroy(c)
	end
	if p.Parent then
		removeChild(p.Parent, inst)
	end
	p.Parent = nil
	rawset(inst, "_dead", true)
	ALL[inst] = nil
	local sigs = rawget(inst, "_s")
	for _, s in pairs(sigs) do
		s.list = {}
	end
end

local function findChild(inst, name, recursive)
	for _, c in ipairs(children(inst)) do
		if rawget(c, "_p").Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(children(inst)) do
			local f = findChild(c, name, true)
			if f then return f end
		end
	end
	return nil
end

local function signalOf(inst, key)
	local sigs = rawget(inst, "_s")
	sigs[key] = sigs[key] or Signal()
	return sigs[key]
end

function INST.Destroy(self) destroy(self) end
function INST.Remove(self) destroy(self) end
function INST.ClearAllChildren(self)
	for _, c in ipairs(table.clone(children(self))) do destroy(c) end
end
function INST.IsA(self, name) return isA(self, name) end
function INST.FindFirstChild(self, name, recursive) return findChild(self, name, recursive) end
function INST.WaitForChild(self, name)
	local c = findChild(self, name)
	if not c then error("WaitForChild: нет " .. tostring(name) .. " в " .. tostring(rawget(self, "_p").Name), 2) end
	return c
end
function INST.FindFirstChildOfClass(self, cls)
	for _, c in ipairs(children(self)) do
		if clsOf(c) == cls then return c end
	end
	return nil
end
function INST.FindFirstChildWhichIsA(self, cls, recursive)
	for _, c in ipairs(children(self)) do
		if isA(c, cls) then return c end
	end
	if recursive then
		for _, c in ipairs(children(self)) do
			local f = INST.FindFirstChildWhichIsA(c, cls, true)
			if f then return f end
		end
	end
	return nil
end
function INST.FindFirstAncestor(self, name)
	local p = rawget(self, "_p").Parent
	while p do
		if rawget(p, "_p").Name == name then return p end
		p = rawget(p, "_p").Parent
	end
	return nil
end
function INST.FindFirstAncestorWhichIsA(self, cls)
	local p = rawget(self, "_p").Parent
	while p do
		if isA(p, cls) then return p end
		p = rawget(p, "_p").Parent
	end
	return nil
end
INST.FindFirstAncestorOfClass = INST.FindFirstAncestorWhichIsA
function INST.IsDescendantOf(self, other)
	local p = rawget(self, "_p").Parent
	while p do
		if p == other then return true end
		p = rawget(p, "_p").Parent
	end
	return false
end
function INST.GetChildren(self) return table.clone(children(self)) end
function INST.GetDescendants(self) return descendants(self) end
function INST.GetFullName(self) return tostring(rawget(self, "_p").Name) end
function INST.SetAttribute(self, k, v) rawget(self, "_a")[k] = v; signalOf(self, "attr:" .. k):Fire() end
function INST.GetAttribute(self, k) return rawget(self, "_a")[k] end
function INST.GetAttributes(self) return table.clone(rawget(self, "_a")) end
function INST.GetAttributeChangedSignal(self, k) return signalOf(self, "attr:" .. k) end
function INST.GetPropertyChangedSignal(self, k) return signalOf(self, "prop:" .. k) end
function INST.AddTag() end
function INST.HasTag() return false end
function INST.RemoveTag() end
function INST.Emit(self, n)
	if type(n) ~= "number" then fail("Emit: не число") end
	SIM.emitted = (SIM.emitted or 0) + n
end
function INST.Clear() end
function INST.Play(self)
	rawget(self, "_p").IsPlaying = true
	rawget(self, "_p").Playing = true
end
function INST.Stop(self)
	rawget(self, "_p").IsPlaying = false
end
function INST.Pause(self) rawget(self, "_p").IsPlaying = false end
function INST.Resume(self) rawget(self, "_p").IsPlaying = true end
function INST.GetPivot(self)
	local p = rawget(self, "_p")
	if p.WorldPivot then return p.WorldPivot end
	if p.CFrame then return p.CFrame end
	local primary = p.PrimaryPart
	if primary then return primary.CFrame end
	return CFrame.new()
end
function INST.PivotTo(self, c)
	if typeof(c) ~= "CFrame" then fail("PivotTo: не CFrame") end
	local p = rawget(self, "_p")
	if isA(self, "BasePart") then
		self.CFrame = c
		return
	end
	local old = INST.GetPivot(self)
	local delta = c * old:Inverse()
	for _, d in ipairs(descendants(self)) do
		if isA(d, "BasePart") and rawget(d, "_p").CFrame then
			d.CFrame = delta * rawget(d, "_p").CFrame
		end
	end
	p.WorldPivot = c
end
function INST.GetBoundingBox(self) return INST.GetPivot(self), v3(2, 4, 2) end
function INST.GetExtentsSize() return v3(2, 4, 2) end
function INST.ScaleTo() end
function INST.GetScale() return 1 end
function INST.SetPrimaryPartCFrame(self, c) INST.PivotTo(self, c) end
function INST.GetMass() return 1 end
function INST.ApplyImpulse() end
function INST.SetNetworkOwner() end
function INST.BreakJoints() end
function INST.LoadAnimation() return { Play = function() end, Stop = function() end, AdjustSpeed = function() end } end
function INST.Clone(self)
	local copy = Instance.new(clsOf(self))
	for k, v in pairs(rawget(self, "_p")) do
		if k ~= "Parent" then rawget(copy, "_p")[k] = v end
	end
	for k, v in pairs(rawget(self, "_a")) do rawget(copy, "_a")[k] = v end
	for _, c in ipairs(children(self)) do
		local cc = INST.Clone(c)
		cc.Parent = copy
	end
	return copy
end

IMT.__index = function(self, k)
	local p = rawget(self, "_p")
	local v = p[k]
	if v ~= nil then return v end
	local m = INST[k]
	if m then return m end
	if EVENTS[k] then return signalOf(self, k) end
	if k == "Parent" then return nil end
	if k == "Position" and isA(self, "BasePart") then
		return p.CFrame and p.CFrame.Position or v3(0, 0, 0)
	end
	if k == "CFrame" and isA(self, "BasePart") then
		return CFrame.new()
	end
	if k == "WorldPosition" and p.ClassName == "Attachment" then
		local parent = p.Parent
		local base = parent and rawget(parent, "_p").CFrame or CFrame.new()
		return base * (p.Position or v3(0, 0, 0))
	end
	if k == "WorldCFrame" and p.ClassName == "Attachment" then
		local parent = p.Parent
		local base = parent and rawget(parent, "_p").CFrame or CFrame.new()
		return base * CFrame.new(p.Position or v3(0, 0, 0))
	end
	local c = findChild(self, k)
	if c then return c end
	local d = DEFAULTS[p.ClassName]
	if d and d[k] ~= nil then return d[k] end
	return nil
end

IMT.__newindex = function(self, k, v)
	local p = rawget(self, "_p")
	if k == "Parent" then
		if rawget(self, "_dead") then
			fail("The Parent property of " .. tostring(p.Name) .. " is locked (уже удалён)")
		end
		if v ~= nil and (typeof(v) ~= "Instance") then fail("Parent = " .. typeof(v)) end
		if p.Parent then removeChild(p.Parent, self) end
		p.Parent = v
		if v then table.insert(children(v), self) end
		return
	end
	local t = TYPES[p.ClassName]
	local want = t and t[k]
	if want and v ~= nil then
		local got = typeof(v)
		if got ~= want and not (want == "number" and type(v) == "number") then
			fail(("%s.%s = %s (нужен %s)"):format(p.ClassName, k, got, want))
		end
		if want == "number" and isnan(v) then fail(p.ClassName .. "." .. k .. " = NaN") end
	end
	if k == "CFrame" and isA(self, "BasePart") then
		p.CFrame = v
		return
	end
	if k == "Position" and isA(self, "BasePart") then
		local old = p.CFrame or CFrame.new()
		p.CFrame = CFrame.new(v) * old.Rotation
		return
	end
	p[k] = v
	local sigs = rawget(self, "_s")
	if sigs["prop:" .. k] then sigs["prop:" .. k]:Fire() end
end
IMT.__tostring = function(self) return tostring(rawget(self, "_p").Name) end

local created = 0
function Instance.new(cls, parent)
	if type(cls) ~= "string" then fail("Instance.new: класс " .. typeof(cls)) end
	local inst = setmetatable({ _p = { ClassName = cls, Name = cls }, _c = {}, _a = {}, _s = {} }, IMT)
	ALL[inst] = true
	created += 1
	if parent then inst.Parent = parent end
	return inst
end

-- ===== Сервисы =====
local services = {}
local game = Instance.new("DataModel")
local function service(name, cls)
	local s = Instance.new(cls or name)
	s.Name = name
	s.Parent = game
	services[name] = s
	return s
end
local Workspace = service("Workspace")
local Players = service("Players")
local Lighting = service("Lighting")
local ReplicatedStorage = service("ReplicatedStorage")
local SoundService = service("SoundService")
local StarterPlayer = service("StarterPlayer")
local RunServiceInst = service("RunService")
local DebrisInst = service("Debris")
local TweenServiceInst = service("TweenService")
local UIS = service("UserInputService")
local CollectionService = service("CollectionService")
local HttpService = service("HttpService")
local GuiService = service("GuiService")
local ContentProvider = service("ContentProvider")

function INST.GetService(self, name)
	local s = services[name]
	if not s then s = service(name) end
	return s
end

local camera = Instance.new("Camera")
camera.Name = "Camera"
camera.CFrame = CFrame.lookAt(v3(0, 12, 22), v3(0, 0, -8))
camera.FieldOfView = 70
camera.Parent = Workspace
Workspace.CurrentCamera = camera
Workspace.Gravity = 196.2
rawget(Workspace, "_p").Raycast = function() return nil end
rawget(Workspace, "_p").GetServerTimeNow = function() return 1000 + VT end
rawget(Workspace, "_p").GetPartBoundsInRadius = function() return {} end
rawget(Workspace, "_p").GetPartBoundsInBox = function() return {} end
rawget(Workspace, "_p").Blockcast = function() return nil end
rawget(Workspace, "_p").Spherecast = function() return nil end

-- Игрок и персонаж
local localPlayer = Instance.new("Player")
localPlayer.Name = "Tester"
localPlayer.UserId = 1
localPlayer.Parent = Players
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
local character = Instance.new("Model")
character.Name = "Tester"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.CFrame = CFrame.new(0, 3, 0)
root.Parent = character
local hand = Instance.new("Part")
hand.Name = "RightHand"
hand.CFrame = CFrame.new(1, 3, 0)
hand.Parent = character
local humanoid = Instance.new("Humanoid")
humanoid.Name = "Humanoid"
humanoid.Parent = character
rawget(character, "_p").PrimaryPart = root
character.Parent = Workspace
localPlayer.Character = character
Players.LocalPlayer = localPlayer
rawget(Players, "_p").GetPlayers = function() return { localPlayer } end
rawget(Players, "_p").GetPlayerFromCharacter = function(_, m) return m == character and localPlayer or nil end
Players.PlayerRemoving = Signal()
Players.PlayerAdded = Signal()
rawget(localPlayer, "_p").CharacterAdded = Signal()

-- RunService
local renderStepped = Signal()
local heartbeat = Signal()
local stepped = Signal()
RunServiceInst.RenderStepped = renderStepped
RunServiceInst.Heartbeat = heartbeat
RunServiceInst.Stepped = stepped
RunServiceInst.PreRender = renderStepped
rawget(RunServiceInst, "_p").IsStudio = function() return true end
rawget(RunServiceInst, "_p").IsClient = function() return true end
rawget(RunServiceInst, "_p").IsServer = function() return false end
rawget(RunServiceInst, "_p").BindToRenderStep = function(_, _, _, fn) renderStepped:Connect(fn) end
rawget(RunServiceInst, "_p").UnbindFromRenderStep = function() end

-- Debris
local debrisList = {}
rawget(DebrisInst, "_p").AddItem = function(_, inst, life)
	if typeof(inst) ~= "Instance" then fail("Debris:AddItem: не Instance") end
	table.insert(debrisList, { inst = inst, t = VT + (life or 10) })
end

-- TweenService
local tweens = {}
local function lerpValue(a, b, k)
	local ta = typeof(a)
	if ta == "number" then return a + (b - a) * k end
	if ta == "Vector3" or ta == "Color3" or ta == "CFrame" or ta == "UDim2" or ta == "Vector2" then return a:Lerp(b, k) end
	return k >= 1 and b or a
end
local function easeK(k, style, dir)
	local name = style and style.Name or "Quad"
	local d = dir and dir.Name or "Out"
	local function base(x)
		if name == "Linear" then return x end
		if name == "Quad" then return x * x end
		if name == "Cubic" then return x ^ 3 end
		if name == "Quart" then return x ^ 4 end
		if name == "Quint" then return x ^ 5 end
		if name == "Sine" then return 1 - math.cos(x * math.pi / 2) end
		if name == "Exponential" then return x == 0 and 0 or 2 ^ (10 * x - 10) end
		if name == "Back" then return 2.70158 * x ^ 3 - 1.70158 * x ^ 2 end
		return x * x
	end
	if d == "In" then return base(k) end
	if d == "Out" then return 1 - base(1 - k) end
	return k < 0.5 and base(k * 2) / 2 or 1 - base((1 - k) * 2) / 2
end
rawget(TweenServiceInst, "_p").Create = function(_, inst, info, goal)
	if typeof(inst) ~= "Instance" then fail("TweenService:Create: не Instance") end
	if type(info) ~= "table" or info.Time == nil then fail("TweenService:Create: не TweenInfo") end
	for k, v in pairs(goal) do
		local cur = inst[k]
		if cur ~= nil and typeof(cur) ~= typeof(v) and not (type(cur) == "number" and type(v) == "number") then
			fail(("Tween %s.%s: %s → %s"):format(clsOf(inst), k, typeof(cur), typeof(v)))
		end
	end
	local tw = { inst = inst, info = info, goal = goal, Completed = Signal(), PlaybackState = Enum.PlaybackState.Begin }
	function tw:Play()
		self.start = VT
		self.from = {}
		for k in pairs(self.goal) do self.from[k] = self.inst[k] end
		self.PlaybackState = Enum.PlaybackState.Playing
		tweens[self] = true
	end
	function tw:Cancel()
		tweens[self] = nil
		self.PlaybackState = Enum.PlaybackState.Cancelled
	end
	tw.Pause = tw.Cancel
	function tw:Destroy() tweens[self] = nil end
	return tw
end
rawget(TweenServiceInst, "_p").GetValue = function(_, k, style, dir) return easeK(k, style, dir) end

local function stepTweens()
	for tw in pairs(table.clone(tweens)) do
		local inst = tw.inst
		if rawget(inst, "_dead") then
			tweens[tw] = nil
		else
			local time = math.max(tw.info.Time, 1e-6)
			local k = math.clamp((VT - tw.start - (tw.info.DelayTime or 0)) / time, 0, 1)
			local e = easeK(k, tw.info.EasingStyle, tw.info.EasingDirection)
			for key, to in pairs(tw.goal) do
				local from = tw.from[key]
				if from ~= nil then
					inst[key] = lerpValue(from, to, e)
				else
					inst[key] = to
				end
			end
			if k >= 1 then
				tweens[tw] = nil
				tw.PlaybackState = Enum.PlaybackState.Completed
				tw.Completed:Fire(Enum.PlaybackState.Completed)
			end
		end
	end
end

local function stepFrame()
	VT += FRAME
	-- Задачи по времени (по порядку).
	local guard = 0
	while true do
		guard += 1
		if guard > 100000 then error("планировщик: зацикливание") end
		local best, bestI = nil, nil
		for i, item in ipairs(queue) do
			if item.t <= VT + 1e-9 and (not best or item.t < best.t or (item.t == best.t and item.seq < best.seq)) then
				best, bestI = item, i
			end
		end
		if not best then break end
		table.remove(queue, bestI)
		if type(best.fn) == "thread" then
			if coroutine.status(best.fn) == "suspended" then
				runFn(best.fn, table.unpack(best.args))
			end
		else
			runFn(best.fn, table.unpack(best.args))
		end
	end
	stepped:Fire(VT, FRAME)
	renderStepped:Fire(FRAME)
	heartbeat:Fire(FRAME)
	stepTweens()
	local keep = {}
	for _, d in ipairs(debrisList) do
		if d.t <= VT then
			destroy(d.inst)
		else
			table.insert(keep, d)
		end
	end
	debrisList = keep
end

local function liveCount(root, filter)
	local n = 0
	for _, d in ipairs(descendants(root)) do
		if not filter or filter(d) then n += 1 end
	end
	return n
end

-- ===== Модули: require по дереву экземпляров =====
local MODULES = {}
local LOADED = {}
local function REGISTER(key, fn)
	MODULES[key] = fn
end
local function mount(parent, name, key)
	local m = Instance.new("ModuleScript")
	m.Name = name
	rawget(m, "_p").__key = key
	m.Parent = parent
	return m
end
local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function require(inst)
	if typeof(inst) ~= "Instance" then error("require: не Instance (" .. typeof(inst) .. ")", 2) end
	local key = rawget(inst, "_p").__key
	if not key then error("require: модуль без исходника: " .. tostring(rawget(inst, "_p").Name), 2) end
	if LOADED[key] ~= nil then
		return LOADED[key]
	end
	local fn = MODULES[key]
	if not fn then error("require: нет модуля " .. key, 2) end
	local result = fn(inst)
	LOADED[key] = result
	return result
end

local function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
	table.insert(LOG.warns, ("[t=%.2f] %s"):format(VT, table.concat(parts, " ")))
end
local function print(...)
	LOG.prints += 1
end
local workspace = Workspace
