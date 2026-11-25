-- fixlib — общие функции правок коллизий Floor1Map (вставляется в начало скриптов fix_*.lua).

-- Вычитает из осевой детали part коробку (min, max): деталь заменяется кусками вокруг выреза.
local function cutBox(part: BasePart, bmin: Vector3, bmax: Vector3): number
	local cf = part.CFrame
	assert(cf.RightVector:FuzzyEq(Vector3.xAxis, 1e-3) and cf.UpVector:FuzzyEq(Vector3.yAxis, 1e-3), "cutBox: деталь повёрнута")
	local pmin = part.Position - part.Size / 2
	local pmax = part.Position + part.Size / 2
	local cmin = pmin:Max(bmin)
	local cmax = pmax:Min(bmax)
	if cmin.X >= cmax.X or cmin.Y >= cmax.Y or cmin.Z >= cmax.Z then
		return 0
	end
	local pieces = {
		{ Vector3.new(pmin.X, pmin.Y, pmin.Z), Vector3.new(cmin.X, pmax.Y, pmax.Z) },
		{ Vector3.new(cmax.X, pmin.Y, pmin.Z), Vector3.new(pmax.X, pmax.Y, pmax.Z) },
		{ Vector3.new(cmin.X, pmin.Y, pmin.Z), Vector3.new(cmax.X, cmin.Y, pmax.Z) },
		{ Vector3.new(cmin.X, cmax.Y, pmin.Z), Vector3.new(cmax.X, pmax.Y, pmax.Z) },
		{ Vector3.new(cmin.X, cmin.Y, pmin.Z), Vector3.new(cmax.X, cmax.Y, cmin.Z) },
		{ Vector3.new(cmin.X, cmin.Y, cmax.Z), Vector3.new(cmax.X, cmax.Y, pmax.Z) },
	}
	local n = 0
	for _, pc in ipairs(pieces) do
		local size = pc[2] - pc[1]
		if size.X > 0.05 and size.Y > 0.05 and size.Z > 0.05 then
			local p = part:Clone()
			p.Size = size
			p.CFrame = CFrame.new((pc[1] + pc[2]) / 2)
			p.Parent = part.Parent
			n += 1
		end
	end
	part:Destroy()
	return n
end

-- Невидимая твёрдая деталь коллизии.
local function solid(parent: Instance, name: string, cf: CFrame, size: Vector3, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Все детали папки, пересекающие коробку.
local function partsIn(folder: Instance, bmin: Vector3, bmax: Vector3): { BasePart }
	local res = {}
	for _, p in ipairs(folder:GetChildren()) do
		if p:IsA("BasePart") then
			local a = p.Position - p.Size / 2
			local b = p.Position + p.Size / 2
			if a.X < bmax.X and b.X > bmin.X and a.Y < bmax.Y and b.Y > bmin.Y and a.Z < bmax.Z and b.Z > bmin.Z then
				table.insert(res, p)
			end
		end
	end
	return res
end
