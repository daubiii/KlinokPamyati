--!nonstrict
-- Floor3Fx (клиент)
-- Картинка и звук этажа 3 «Псарни охоты» по событиям Floor3World (FloorEvent,
-- kind f3*). Логики нет. Подсветка трофеев, огонь жаровен, капканы и тень люстры
-- уже стоят на сервере — здесь только вспышки, пыль, щепки и баннеры.
--
--   трофеи      столб света над постаментом, когда трофей можно взять; баннер
--               «Трофей n/3», искры у жаровни донжона; «Ворота ристалища открыты»
--   тайники     щепки и пыль от ветхой стены, баннер «Тайник»
--   ловушки     капкан (щелчок), колокольца растяжки, самострел (вспышка у ложа),
--               пролёт моста (пыль, обломки), люстра (тень, удар), телега (грохот)
--   ловчий      пыль при прыжке на вышку и приземлении
--
-- Временные детали — в Workspace.Floor3Fx; дальше 140 стад эффекты не рисуются.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local Bus = require(script.Parent.Parent.Lib.Bus)
local TEX = require(script.Parent.Parent.Lib.FxTex)

local Floor3Fx = {}

local V3 = Vector3.new
local hex = Color3.fromHex
local FAR = 140

local C = {
	gold = hex("#D9A441"),
	bone = hex("#E8DCC0"),
	blood = hex("#8C3B2E"),
	wine = hex("#3B1E1E"),
	ember = hex("#FF7A2A"),
	flame = hex("#FFB347"),
	dust = hex("#B89A78"),
	wood = hex("#6A4A36"),
	woodLight = hex("#9A7452"),
	hay = hex("#B99648"),
	hayLight = hex("#D2B56A"),
	iron = hex("#6E6660"),
	warn = hex("#C8442E"),
}

local player = Players.LocalPlayer

local function sfx(name: string, position: Vector3?)
	Bus.emit("sfx", { name = name, position = position })
end

local function banner(top: string?, text: string)
	Bus.emit("banner", { top = top, text = text })
end

local folderRef
local function folder()
	if folderRef and folderRef.Parent then
		return folderRef
	end
	folderRef = Workspace:FindFirstChild("Floor3Fx")
	if not folderRef then
		folderRef = Instance.new("Folder")
		folderRef.Name = "Floor3Fx"
		folderRef.Parent = Workspace
	end
	return folderRef
end

local function near(position: Vector3?): boolean
	if not position then
		return false
	end
	local camera = Workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude <= FAR
end

local function cseq(a: Color3, b: Color3?)
	return b and ColorSequence.new(a, b) or ColorSequence.new(a)
end

local function nseq(points)
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

-- Разовая вспышка частиц в точке. o: tex, color, emit, rate (+ life эффекта), box,
-- size, transp, life {a, b}, speed {a, b}, spread, accel, drag, light, dir.
local function emitter(position: Vector3, o, duration: number?)
	local anchor = Instance.new("Part")
	anchor.Name = "Fx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = o.box or V3(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = folder()
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.tex or TEX.smoke
	e.Color = o.color or cseq(C.dust)
	e.LightEmission = o.light or 0
	e.LightInfluence = (o.light or 0) > 0.5 and 0 or 1
	e.Size = o.size or nseq({ { 0, 1 }, { 1, 2 } })
	e.Transparency = o.transp or nseq({ { 0, 0.3 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(o.life and o.life[1] or 0.6, o.life and o.life[2] or 1.2)
	e.Speed = NumberRange.new(o.speed and o.speed[1] or 2, o.speed and o.speed[2] or 6)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.Acceleration = o.accel or V3(0, 0, 0)
	e.Drag = o.drag or 0
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = o.rate or 0
	e.Parent = anchor
	if o.emit then
		e:Emit(o.emit)
	end
	local life = (duration or 0) + (o.life and o.life[2] or 1.2) + 0.2
	if duration and o.rate then
		task.delay(duration, function()
			e.Enabled = false
		end)
	end
	Debris:AddItem(anchor, life)
	return anchor
end

local function dust(position: Vector3, scale: number)
	emitter(position, {
		tex = TEX.smoke, color = cseq(C.dust, C.wood), emit = math.floor(16 * scale), box = V3(3 * scale, 0.5, 3 * scale),
		size = nseq({ { 0, 1.2 * scale }, { 1, 3.4 * scale } }), transp = nseq({ { 0, 0.35 }, { 1, 1 } }),
		life = { 0.8, 1.6 }, speed = { 3 * scale, 8 * scale }, spread = 70, accel = V3(0, -4, 0), drag = 2,
	})
end

local function splinters(position: Vector3, count: number, colors)
	for k = 1, count do
		local chip = Instance.new("Part")
		chip.Anchored = false
		chip.CanCollide = true
		chip.CanQuery = false
		chip.CanTouch = false
		chip.Size = V3(0.25, 0.25, math.random(5, 12) / 10)
		chip.Color = colors[(k % #colors) + 1]
		chip.CFrame = CFrame.new(position + V3(math.random(-15, 15) / 10, math.random(0, 30) / 10, math.random(-15, 15) / 10))
			* CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		chip.Parent = folder()
		chip.AssemblyLinearVelocity = V3(math.random(-12, 12), math.random(6, 16), math.random(-12, 12))
		Debris:AddItem(chip, 2.5)
	end
end

local function glowColumn(position: Vector3, color: Color3)
	local anchor = emitter(position, {
		tex = TEX.glow, color = cseq(color, Color3.new(1, 1, 1)), rate = 10, box = V3(1.5, 0.2, 1.5),
		size = nseq({ { 0, 0.4 }, { 0.5, 0.7 }, { 1, 0 } }), transp = nseq({ { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } }),
		life = { 1.6, 2.4 }, speed = { 3, 5 }, spread = 4, light = 1,
	}, 3600)
	anchor.Name = "TrophyBeacon"
	return anchor
end

-- Столбы света над трофеями, которые можно взять: [id] = anchor.
local beacons = {}
local function clearBeacon(id)
	if beacons[id] then
		beacons[id]:Destroy()
		beacons[id] = nil
	end
end
local function clearBeacons()
	for id in pairs(beacons) do
		clearBeacon(id)
	end
end

local function onMapEvent(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" or payload.kind:sub(1, 2) ~= "f3" then
		return
	end
	if (player:GetAttribute("FloorId") or 1) ~= 3 then
		return
	end
	local kind = payload.kind
	local pos = typeof(payload.position) == "Vector3" and payload.position or nil
	if kind == "f3trophyReady" then
		if pos then
			clearBeacon(payload.id)
			beacons[payload.id] = glowColumn(pos + V3(0, 0.5, 0), C.gold)
			sfx("valveReady", pos)
		end
		banner("Трофей ждёт", (payload.name or "Трофей") .. " — удерживайте E у постамента")
	elseif kind == "f3trophy" then
		clearBeacon(payload.id)
		if pos then
			emitter(pos + V3(0, 1.5, 0), {
				tex = TEX.star, color = cseq(C.gold, C.bone), emit = 30, size = nseq({ { 0, 0.7 }, { 1, 0 } }),
				transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.8, 1.6 }, speed = { 3, 9 }, drag = 1.5, light = 1,
			})
			sfx("magicChime", pos)
		end
		local brazier = typeof(payload.brazier) == "Vector3" and payload.brazier or nil
		if brazier then
			task.delay(1.2, function()
				emitter(brazier, {
					tex = TEX.spark, color = cseq(C.flame, C.ember), emit = 60, box = V3(4, 1, 4), size = nseq({ { 0, 0.5 }, { 1, 0.1 } }),
					transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 1.0, 2.0 }, speed = { 8, 18 }, spread = 30, accel = V3(0, -6, 0), light = 1,
				})
			end)
		end
		local count, total = payload.count or 0, payload.total or 3
		if count >= total then
			banner(("Трофей %d/%d · %s"):format(count, total, payload.name or ""), "Все жаровни донжона горят")
		else
			banner(("Трофей %d/%d"):format(count, total), (payload.name or "") .. " — жаровня донжона зажглась")
		end
	elseif kind == "f3gate" then
		if pos then
			dust(pos, 1.6)
		end
		sfx("securityGate", pos)
		banner("Трофейные ворота", "Ворота ристалища открыты")
	elseif kind == "f3signal" then
		if pos then
			emitter(pos, {
				tex = TEX.spark, color = cseq(C.flame, C.ember), emit = 40, box = V3(3, 1, 3), size = nseq({ { 0, 0.5 }, { 1, 0.1 } }),
				transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 1.0, 2.0 }, speed = { 6, 14 }, spread = 30, light = 1,
			})
		end
		banner("Вышка егерей", "Сигнальный костёр горит")
	elseif kind == "f3secret" then
		if pos then
			splinters(pos + V3(0, 2, 0), 14, { C.wood, C.woodLight, C.blood })
			dust(pos + V3(0, 1, 0), 1.2)
			sfx("secretFound", pos)
		end
		banner("Тайник", payload.name or "Тайная комната")
	elseif kind == "f3prop" and pos and near(pos) then
		local broken = payload.broken == true
		local hay = payload.propKind == "hay"
		local colors = hay and { C.hay, C.hayLight } or { C.wood, C.woodLight }
		if broken then
			splinters(pos, hay and 10 or 14, colors)
			dust(pos, hay and 0.7 or 1.0)
			sfx("propBreak", pos)
		else
			splinters(pos, hay and 3 or 4, colors)
			dust(pos, 0.35)
			sfx("propHit", pos)
		end
	elseif kind == "f3cage" and near(pos) then
		sfx("gateCreak", pos)
		dust(pos, 0.6)
	elseif kind == "f3bear" and near(pos) then
		sfx("snap", pos)
		emitter(pos + V3(0, 0.4, 0), {
			tex = TEX.spark, color = cseq(C.bone, C.iron), emit = 12, size = nseq({ { 0, 0.25 }, { 1, 0 } }),
			transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.2, 0.4 }, speed = { 6, 12 }, spread = 70, light = 1,
		})
	elseif kind == "f3trip" and near(pos) then
		sfx("chimes" .. math.random(1, 5), pos)
	elseif kind == "f3xbow" and near(pos) then
		if payload.phase == "warn" then
			sfx("bowDraw", pos)
			emitter(pos, { tex = TEX.glow, color = cseq(C.warn), emit = 1, size = NumberSequence.new(2.4), transp = nseq({ { 0, 0.2 }, { 1, 1 } }), life = { 0.35, 0.35 }, speed = { 0, 0 }, light = 1 })
		else
			sfx("bowRelease", pos)
		end
	elseif kind == "f3span" and pos then
		if payload.phase == "crack" then
			sfx("spanCrack", pos)
			emitter(pos, {
				tex = TEX.smoke, color = cseq(C.dust), rate = 16, box = V3(12, 0.4, 8), size = nseq({ { 0, 0.5 }, { 1, 1.6 } }),
				transp = nseq({ { 0, 0.4 }, { 1, 1 } }), life = { 0.8, 1.4 }, speed = { 1, 3 }, accel = V3(0, -6, 0), dir = Enum.NormalId.Bottom,
			}, payload.duration or 1)
		elseif payload.phase == "fall" then
			sfx("spanFall", pos)
			splinters(pos, 20, { C.wood, C.woodLight })
			dust(pos, 1.8)
		end
	elseif kind == "f3chandelier" and pos then
		if payload.phase == "warn" then
			sfx("chainRattle", pos)
		else
			sfx("slam", pos)
			dust(pos, 1.5)
			emitter(pos + V3(0, 1, 0), {
				tex = TEX.spark, color = cseq(C.flame, C.ember), emit = 30, box = V3(4, 1, 4), size = nseq({ { 0, 0.4 }, { 1, 0.05 } }),
				transp = nseq({ { 0, 0 }, { 1, 1 } }), life = { 0.4, 0.9 }, speed = { 8, 16 }, spread = 80, accel = V3(0, -30, 0), light = 1,
			})
		end
	elseif kind == "f3cart" and pos then
		if payload.phase == "warn" then
			sfx("chainRattle", pos)
			Bus.emit("notify", { kind = "warn", text = "Телега сорвалась — с дороги!" })
		elseif payload.phase == "roll" then
			sfx("bossCharge", pos)
		elseif payload.phase == "crash" then
			sfx("rockCrunch", pos)
			splinters(pos + V3(0, 1, 0), 16, { C.wood, C.woodLight, C.iron })
			dust(pos, 1.6)
		end
	elseif kind == "f3perch" and pos then
		if payload.phase == "jump" then
			sfx("airWhoosh", pos)
			dust(pos, 1.2)
		else
			sfx("slam", pos)
			dust(pos, 1.6)
		end
	elseif kind == "f3spear" and pos then
		sfx("unsheath", pos)
	end
end

function Floor3Fx.start()
	folder()
	local remote = Net.get("FloorEvent")
	if remote then
		remote.OnClientEvent:Connect(onMapEvent)
	end
	player:GetAttributeChangedSignal("FloorId"):Connect(function()
		if player:GetAttribute("FloorId") ~= 3 then
			clearBeacons()
		end
	end)
	print("[Floor3Fx] трофеи, тайники и ловушки этажа 3")
end

return Floor3Fx
