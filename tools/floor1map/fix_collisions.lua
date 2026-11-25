--[[
	fix_collisions.lua — правки коллизий Floor1Map (этаж 1 v2) после вставки Floor1Map.rbxmx.
	Запуск: node C:\Users\artem\.dsh-roblox\s.js exec tools/floor1map/fix_collisions.lua Edit
	(fixlib.lua склеивается впереди: см. run_fix.sh) или Command Bar.

	Каждый шаг выполняется один раз: id выполненных шагов хранятся в атрибуте
	Floor1Map.CollisionFixes. Повторный запуск безопасен.
]]
local map = workspace:FindFirstChild("Floor1Map")
assert(map, "нет Workspace.Floor1Map")
-- Карта v3 (08.11.2026) уже собрана с этими правками, а невидимые стены bounds ей не нужны.
if map:GetAttribute("MapVersion") == "v3" then
	print("[fix_collisions] Floor1Map v3 — правки уже внутри, ничего не делаю")
	return
end
local done = {}
for id in string.gmatch(map:GetAttribute("CollisionFixes") or "", "[^,]+") do
	done[id] = true
end
local log = {}
local function step(id: string, fn: () -> string?)
	if done[id] then
		return
	end
	local msg = fn()
	done[id] = true
	table.insert(log, id .. ": " .. (msg or "ok"))
end

local BARRICADE_R = 13.6 -- радиус центра баррикады на пандусе башни (центр башни 0, −290)

local function col(zone: string): Folder
	return map[zone].Collision
end

-- 1. Insert from File поднял модель на +2 по Y: коллизии, огни и динамика выше видимого пола.
step("shiftY", function()
	local first = map.intro.Collision:GetChildren()[1] :: BasePart
	-- в rbxmx пол входа стоит на −0.66
	local off = -0.66 - first.Position.Y
	if math.abs(off) < 0.01 then
		return "сдвига нет"
	end
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d.Parent.Name ~= "Visual" then
			d.CFrame = CFrame.new(0, off, 0) * d.CFrame
		elseif d:IsA("Model") and not d.PrimaryPart then
			d.WorldPivot = CFrame.new(0, off, 0) * d.WorldPivot
		end
	end
	return ("сдвинуто на %.2f"):format(off)
end)

-- 2. Башня: лестница с вершины на мост к залу была сплошным блоком 6 стад — клин.
step("towerStairs", function()
	for _, p in ipairs(partsIn(col("tower"), Vector3.new(5.1, 18.1, -293), Vector3.new(9.9, 23.9, -287))) do
		if math.abs(p.Size.Y - 6) < 0.01 then
			p:Destroy()
		end
	end
	-- ступени x 4..11 (до начала моста), y 18..24
	local pos = Vector3.new(7.5, 21, -290)
	solid(col("tower"), "Fix_StairsTop", CFrame.lookAt(pos, pos - Vector3.xAxis), Vector3.new(7, 6, 7), "WedgePart")
end)

-- 3. Башня: квадратная плита вершины углами нависала над 3-м витком пандуса (4.2 стада высоты).
step("towerSlab", function()
	for _, p in ipairs(partsIn(col("tower"), Vector3.new(-1, 17, -291), Vector3.new(1, 18, -289))) do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and math.abs(p.Size.X - 22.4) < 0.01 then
			p:Destroy()
		end
	end
end)

-- 4. Башня: парапет вершины сплошным кольцом 3.2 стада — проход там, где кончается пандус.
step("towerParapet", function()
	local n = 0
	for _, p in ipairs(col("tower"):GetChildren()) do
		if p:IsA("BasePart") then
			local dx, dz = p.Position.X, p.Position.Z + 290
			local r = math.sqrt(dx * dx + dz * dz)
			local ang = math.deg(math.atan2(dz, dx))
			if r > 10.5 and r < 13.5 and ang > 72 and ang < 108 and p.Position.Y - p.Size.Y / 2 > 17.3 then
				p:Destroy()
				n += 1
			end
		end
	end
	return n .. " деталей"
end)

-- 5. Зал лебёдки: западная стена без проёма под решёткой Gate_HallIn.
step("hallDoor", function()
	local bmin, bmax = Vector3.new(45, 23.98, -293), Vector3.new(48.5, 29.6, -287)
	local n = 0
	for _, p in ipairs(partsIn(col("hall"), bmin, bmax)) do
		n += cutBox(p, bmin, bmax)
	end
	return n .. " кусков"
end)

-- 6. Башня: баррикады стояли посреди пандуса (щели 1.6 и 1.75 стада) — к внутреннему краю,
-- со стороны стрелка: укрытие остаётся, снаружи проход ~3 стада. Точки BARRICADE_n в Floor1Points сдвинуты так же.
step("towerBarricades", function()
	local o = {}
	for i = 1, 6 do
		local m = map.tower.Dynamic:FindFirstChild("Barricade_" .. i)
		if m then
			local c = m:GetBoundingBox().Position
			local rel = Vector3.new(c.X, 0, c.Z + 290)
			local shift = rel.Unit * (BARRICADE_R - rel.Magnitude)
			m:PivotTo(m:GetPivot() + shift)
			table.insert(o, ("%d: %.2f"):format(i, shift.Magnitude))
		end
	end
	return table.concat(o, " ")
end)

-- 7. Часовня: помост у алтаря (верх 1.9) без коллизии — игрок проходил сквозь него.
step("chapelDais", function()
	solid(col("chapel"), "Fix_Dais", CFrame.new(128.5, 0.95, -290), Vector3.new(5.5, 1.9, 10.5))
end)

-- 8. Невидимые стены там, где с пола зоны можно выйти на тёмную плиту за стенами
-- (южный проём входа, щели в стыках проходов, верх стен). Данные — bounds_data.lua.
-- Шаг пересобирается при каждом запуске: старые Fix_Bound удаляются.
done.bounds = nil
step("bounds", function()
	for _, d in ipairs(map:GetDescendants()) do
		if d.Name == "Fix_Bound" then
			d:Destroy()
		end
	end
	for _, b in ipairs(BOUNDS) do
		local zone, x0, z0, x1, z1, y = table.unpack(b)
		local y0, y1 = y - 0.5, y + 12
		solid(col(zone), "Fix_Bound", CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0))
	end
	return #BOUNDS .. " стен"
end)

map:SetAttribute("CollisionFixes", table.concat((function()
	local ids = {}
	for id in pairs(done) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end)(), ","))
return #log == 0 and "нечего делать" or table.concat(log, "\n")
