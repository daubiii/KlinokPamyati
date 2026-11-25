--!nonstrict
-- GateWindow — Врата Печатей v2: пиксельная карта острова Хранилища.
-- Этаж = регион с плашкой; закрытые этажи под туманом (открыт 1-й, дальше —
-- после «Ненормального» предыдущего). Наведение подсвечивает этаж, клик по
-- открытому — меню этажа (GateFloorView: описание, летопись, сундуки, сложность,
-- «ВОЙТИ»), клик по сундуку — меню сундука (GateChestView: лут с шансами,
-- карточки оружия). Backspace закрывает меню по одному (GateWindow.back).
-- Этаж открылся с прошлого раза (за сессию) — туман над ним рассеивается.
-- Вход: голубая вспышка, затемнение, дальше — существующий переход на этаж.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local WorldMap = require(Shared.Config.WorldMap)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local UiMotion = require(Lib.UiMotion)
local WindowBase = require(Lib.WindowBase)
local WorldMapView = require(Lib.WorldMapView)
local GateFloorView = require(script.Parent.GateFloorView)
local GateChestView = require(script.Parent.GateChestView)

local GateWindow = {}

local C = UiAssets.Colors
local MAP_POS = Vector2.new(34, 120)
local FRAME_PAD = 10

local win, ctx, map, floorView, chestView
local refs: any = {}
local state: any = { data = nil }
-- Память сессии: что было открыто при прошлом открытии окна, выбранные сложности, класс витрины.
local memory: any = { seenOpen = nil, difficulty = {}, chestClass = nil }

local function worldOf(k: number)
	return state.data and state.data.worlds and state.data.worlds[k]
end

local function setHint(text: string, color: Color3?)
	if refs.hint then
		refs.hint.Text = text
		refs.hint.TextColor3 = color or C.grey
	end
end

local function hintFor(k: number?)
	local world = k and worldOf(k)
	if not world then
		setHint(WorldMap.Hint)
		return
	end
	local text = WorldMap.get(k) or {}
	if world.state == "locked" then
		if world.hidden or world.name == WorldMap.HiddenName then
			setHint(("%s · ??? — печать держит. Сначала открой предыдущий этаж."):format(world.numeral or k), C.grey)
		else
			setHint(("%s · %s — %s"):format(world.numeral or k, world.name, world.sub or WorldMap.LockedHint), Color3.fromRGB(220, 200, 170))
		end
		return
	end
	setHint(("%s · %s — хранитель: %s. Нажми, чтобы открыть."):format(world.numeral or k, world.name, text.keeper or world.keeper or "?"), C.mem)
end

local function openChest(k: number, grade: string)
	if chestView or not win then
		return
	end
	chestView = GateChestView.new(win.canvas, {
		k = k,
		grade = grade,
		world = worldOf(k),
		data = state.data,
		className = memory.chestClass or state.data.className,
		onClass = function(id)
			memory.chestClass = id
		end,
		onClose = function()
			chestView = nil
		end,
	})
end

local function openFloor(k: number)
	if floorView or not win then
		return
	end
	map:setSelected(k)
	map:setBlocked(true)
	floorView = GateFloorView.new(win.canvas, {
		k = k,
		world = worldOf(k),
		data = state.data,
		difficulty = memory.difficulty[k],
		onDifficulty = function(id)
			memory.difficulty[k] = id
		end,
		onEnter = function(worldId, difficultyId, button)
			GateWindow.enter(worldId, difficultyId, button)
		end,
		onChest = function(grade)
			openChest(k, grade)
		end,
		onClose = function()
			floorView = nil
			if map then
				map:setSelected(nil)
				map:setBlocked(false)
			end
			hintFor(nil)
		end,
	})
end

local function pick(k: number)
	if floorView then
		return
	end
	local world = worldOf(k)
	if not world or world.state == "locked" then
		if map then
			map:deny(k)
		end
		hintFor(k)
		if refs.hint then
			PixelUi.nudge(refs.hint)
		end
		return
	end
	UiSound.play("floor_pick")
	openFloor(k)
end

function GateWindow.enter(worldId: number, difficultyId: string, button)
	local k = tonumber(worldId) or worldId
	local world = worldOf(k)
	if not world or world.state == "locked" or not difficultyId then
		return
	end
	if button then
		button:setEnabled(false)
		UiMotion.punch(button.holder, 0.15, 0.3)
	end
	UiSound.play("gate_rumble")
	UiSound.play("echo_absorb")
	UiFx.flash(C.mem, 0.6, 0.7)
	UiFx.shake(0.4, 0.3)
	memory.difficulty[k] = difficultyId
	local result = ctx.api.gate.enter(world.id or k, difficultyId)
	if result and result.ok then
		ctx.close()
	else
		if button then
			button:setEnabled(true)
		end
		if result and result.reason and result.reason ~= "mock" then
			UiSound.play("error")
		end
	end
end

-- Backspace: сначала закрыть меню сундука, потом меню этажа. true — окно ещё нужно.
function GateWindow.back(): boolean
	if chestView then
		chestView:close()
		return true
	end
	if floorView then
		floorView:close()
		return true
	end
	return false
end

function GateWindow.open(context)
	ctx = context
	refs = {}
	floorView, chestView = nil, nil
	win = WindowBase.new("KlinokGate", { title = WorldMap.Title, sub = WorldMap.Sub, onClose = context.close, wallet = { { "coin", "Gold" }, { "ingot", "IronCount" } } })
	state.data = context.api.gate.get() or { worlds = {} }
	local worlds = state.data.worlds or {}
	UiSound.play("gate_rumble", { pitch = 1.25, volume = 0.6 })

	-- рамка карты: карта лежит внутри оправы, уголки — поверх её краёв
	local size = WorldMapView.Size
	local frame = PixelUi.panel(win.canvas, UDim2.fromOffset(MAP_POS.X, MAP_POS.Y), UDim2.fromOffset(size.X + FRAME_PAD * 2, size.Y + FRAME_PAD * 2), { z = 2 })
	refs.frame = frame
	map = WorldMapView.new(frame, UDim2.fromOffset(FRAME_PAD, FRAME_PAD), worlds, {
		onPick = pick,
		onHover = function(k)
			if not floorView then
				hintFor(k)
			end
		end,
	})
	refs.hint = PixelUi.label(win.canvas, WorldMap.Hint, 16, C.grey, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(800, MAP_POS.Y + size.Y + FRAME_PAD * 2 + 10),
		Size = UDim2.fromOffset(1500, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
	})
	PixelUi.slideIn(frame, 0, 0.05)

	-- плашки этажей проступают по очереди, с каменным «тиком»
	local plaques = {}
	for k, r in ipairs(map.regions) do
		table.insert(plaques, r.plaque)
		task.delay(0.25 + k * 0.07, function()
			if r.plaque.Parent then
				UiSound.play("stone_tick", { pitch = 0.9 + k * 0.07, gap = 0 })
			end
		end)
	end
	UiMotion.cascade(plaques, Vector2.new(0, -18), 0.07, 0.25, 0.28)

	-- туман над этажом, открывшимся с прошлого раза, рассеивается
	local seen = memory.seenOpen
	local now = {}
	for k, world in ipairs(worlds) do
		now[k] = world.state ~= "locked"
		if seen and now[k] and seen[k] == false then
			map:reveal(k)
			task.delay(0.5, function()
				setHint(("Печать %s открыта: %s"):format(world.numeral or k, world.name or ""), C.mem)
			end)
		end
	end
	memory.seenOpen = now
	return win
end

function GateWindow.close()
	-- меню гаснут вместе с окном (они на его холсте)
	chestView, floorView = nil, nil
	if map then
		map:stop()
		map = nil
	end
	if win then
		win:destroy()
		win = nil
	end
end

return GateWindow
