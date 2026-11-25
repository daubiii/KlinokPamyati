--!nonstrict
-- ForgeWindow — Кузня Эха (окно-сцена в комнате «Горнило»), бумажный стиль
-- «Книги героя» (PaperUi) поверх живой сцены: в центре наковальня и Отзвук.
--
--   слева   — «Оружейная»: все клинки строками (★, полоска эха, «ГОТОВО»);
--   справа  — карточка клинка и три режима-плитки:
--             1 Вплавить эхо (сокеты, прибавки «сейчас → после», цена, УДАРИТЬ!),
--             2 Душа босса (гнездо с ★3), 3 Расплавить (в Пыль эха, с подтверждением);
--   сверху  — лента «КУЗНЯ ЭХА», облачко Отзвука (печатается), кошелёк, крестик;
--   снизу   — подсказка клавиш и три метки ударов.
--
-- Ковка: эхо из сокетов летит к наковальне → горн разгорается → три удара
-- (метки I-II-III, тряска, искры, звон) → вспышка, лента «КОВКА УДАЛАСЬ!»,
-- карточка-итог: звёзды зажигаются по одной, прибавки набегают числами,
-- печать «ГНЕЗДО ОТКРЫТО», кнопка «ДАЛЬШЕ».
-- Клавиши: 1–3 режим, ↑/↓ (W/S) клинок, Пробел/Enter — главное действие.
--
-- Данные: StationApi.forge.get/upgrade/melt (EchoService). Реплики — SmithLines.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)
local EchoSmith = require(Lib.EchoSmith)

local ForgeWindow = {}

local P = PaperUi.colors
local C = UiAssets.Colors
local player = Players.LocalPlayer

local win, smith, ctx
local state: any = { tab = 1, selectedKey = nil, data = nil, busy = false }
local refs: any = {}

local TABS = {
	{ title = "Вплавить", icon = "it_soul", say = nil },
	{ title = "Душа", icon = "it_amuletRed", say = "soulTab" },
	{ title = "Плавка", icon = "it_dust", say = "meltTab" },
}

-- Геометрия холста 1600×900.
local LEFT = { x = 24, y = 104, w = 400, h = 772 }
local RIGHT = { x = 1176, y = 104, w = 400, h = 772 }
local ROW = { h = 92, gap = 10 }
local HOT = Color3.fromRGB(255, 168, 86) -- раскалённая сталь
local STAR_OFF = Color3.fromRGB(196, 178, 140)

-- ===== мелочи =====

local function clear(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

local function layer(parent, name: string, z: number?)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z or 5
	frame.Parent = parent
	return frame
end

local function centered(parent, text: string, size: number, color: Color3, y: number, props, font)
	local label = (font or PaperUi.text)(parent, text, size, color, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, size + 8),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return PaperUi.apply(label, props or {})
end

-- «★★★» золотом + оставшиеся бледно (RichText).
local function starText(level: number, max: number): string
	local on = string.rep("★", math.max(level, 0))
	local off = string.rep("★", math.max(max - level, 0))
	return ('<font color="#%s">%s</font><font color="#%s">%s</font>'):format(P.gold:ToHex(), on, STAR_OFF:ToHex(), off)
end

local function soulName(soul): string?
	if type(soul) == "table" then
		return tostring(soul.name or soul.id or "Душа")
	end
	return soul
end

local function weaponIcon(item): string
	if item.kind == "armor" then
		return "armor"
	end
	return UiAssets.WeaponIcon[item.typeId] or "sword"
end

-- Комплекту брони кроме эха нужен материал его этажа (cost.materials).
local function hasMaterials(item): boolean
	return item.kind ~= "armor" or not item.cost or (item.materialHave or 0) >= (item.cost.materials or 0)
end

local function isReady(item): boolean
	return item.cost ~= nil and item.echoes >= item.cost.echoes and hasMaterials(item)
end

local function gold(): number
	return player:GetAttribute("Gold") or (state.data and state.data.gold) or 0
end

local function items()
	return state.data and state.data.items or {}
end

local function selectedIndex(): number
	for i, item in ipairs(items()) do
		if item.key == state.selectedKey then
			return i
		end
	end
	return 1
end

local function selectedItem()
	local list = items()
	return list[selectedIndex()]
end

-- Центр объекта в координатах корня окна (для эффектов UiFx).
local function rootPoint(object): Vector2
	local scale = win.root:FindFirstChildOfClass("UIScale")
	local p = object.AbsolutePosition + object.AbsoluteSize / 2 - win.root.AbsolutePosition
	return p / (scale and scale.Scale or 1)
end

-- ===== Отзвук =====

local function say(key: string, vars)
	local text = EchoSmith.line(key, vars)
	if text == "" then
		return
	end
	if smith then
		smith:talk(text)
	end
	local bubble = refs.bubble
	if not bubble then
		return
	end
	if refs.sayJob then
		refs.sayJob.cancel()
	end
	UiMotion.punch(bubble.holder, 0.05, 0.18)
	refs.sayJob = UiMotion.typewriter(bubble.text, text, { speed = 52 })
end

local function buildBubble(canvas)
	local holder = Instance.new("Frame")
	holder.Name = "SmithBubble"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromOffset(800, 112)
	holder.Size = UDim2.fromOffset(520, 96)
	holder.ZIndex = 8
	holder.Parent = canvas
	PaperUi.image(holder, "sheetPlain", { Size = UDim2.fromScale(1, 1), ZIndex = 8 }, { scale = 1 })
	PaperUi.image(holder, "chevronD", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 9,
	}, { noSlice = true })
	PaperUi.bold(holder, "ОТЗВУК", 15, P.green, {
		Position = UDim2.fromOffset(22, 8), Size = UDim2.fromOffset(200, 20), ZIndex = 10,
	})
	local text = PaperUi.italic(holder, "", 20, P.ink, {
		Position = UDim2.fromOffset(22, 30), Size = UDim2.new(1, -44, 1, -38),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 10,
	})
	return { holder = holder, text = text }
end

-- ===== оружейная (слева) =====

local renderCard -- forward

local function rowSelected(row, on: boolean)
	if row.brackets then
		for _, b in ipairs(row.brackets) do
			b:Destroy()
		end
		row.brackets = nil
	end
	row.face.Visible = not on
	row.faceOn.Visible = on
	if not on then
		return
	end
	row.brackets = {}
	for _, spec in ipairs({ { "hlTL", 0, 0 }, { "hlTR", 1, 0 }, { "hlBR", 1, 1 }, { "hlBL", 0, 1 } }) do
		local b = PaperUi.image(row.holder, spec[1], {
			AnchorPoint = Vector2.new(spec[2], spec[3]),
			Position = UDim2.new(spec[2], spec[2] == 0 and -5 or 5, spec[3], spec[3] == 0 and -5 or 5),
			Size = UDim2.fromOffset(24, 24),
			ZIndex = 14,
		}, { noSlice = true })
		local base = b.Position
		local out = UDim2.new(base.X.Scale, base.X.Offset + (spec[2] == 0 and -2 or 2), base.Y.Scale, base.Y.Offset + (spec[3] == 0 and -2 or 2))
		game:GetService("TweenService"):Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = out }):Play()
		table.insert(row.brackets, b)
	end
end

local function selectKey(key, quiet: boolean?)
	if state.busy or key == state.selectedKey then
		return
	end
	local old = refs.rows and refs.rows[state.selectedKey]
	if old then
		rowSelected(old, false)
	end
	state.selectedKey = key
	state.confirmMelt = nil
	local row = refs.rows and refs.rows[key]
	if row then
		rowSelected(row, true)
		UiMotion.punch(row.holder, 0.04, 0.16)
		-- прокрутить, чтобы строка была видна (CanvasPosition — в экранных пикселях)
		local list = refs.list
		local rootScale = win.root:FindFirstChildOfClass("UIScale")
		local s = rootScale and rootScale.Scale or 1
		local top = row.holder.Position.Y.Offset * s
		local bottom = (row.holder.Position.Y.Offset + ROW.h + 6) * s
		if top < list.CanvasPosition.Y then
			UiMotion.tween(list, 0.15, { CanvasPosition = Vector2.new(0, top) })
		elseif bottom > list.CanvasPosition.Y + list.AbsoluteWindowSize.Y then
			UiMotion.tween(list, 0.15, { CanvasPosition = Vector2.new(0, bottom - list.AbsoluteWindowSize.Y) })
		end
	end
	renderCard(true)
	if quiet then
		return
	end
	local item = selectedItem()
	if item and state.tab == 1 then
		if not item.cost then
			say("max")
		elseif isReady(item) then
			say("ready", { item = item.name })
		else
			say("noEcho", { n = item.cost.echoes - item.echoes })
		end
	end
end

local function buildRow(parent, item, y: number)
	local holder = Instance.new("Frame")
	holder.Name = "Row_" .. tostring(item.key)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(6, y)
	holder.Size = UDim2.new(1, -18, 0, ROW.h)
	holder.ZIndex = 8
	holder.Parent = parent
	local face = PaperUi.image(holder, "square", { Size = UDim2.fromScale(1, 1), ZIndex = 8 }, { scale = 2 })
	local faceOn = PaperUi.image(holder, "plate", { Size = UDim2.fromScale(1, 1), ZIndex = 8, Visible = false }, { scale = 2 })
	local row: any = { holder = holder, face = face, faceOn = faceOn }
	local slot = PaperUi.slot(holder, UDim2.fromOffset(10, 11), 70, { pixelIcon = weaponIcon(item), rarityId = item.rarityId, z = 9 })
	row.slot = slot
	local nameInk = PaperUi.rarityInk[item.rarityId] or P.ink
	PaperUi.bold(holder, item.name or "Клинок", 19, nameInk, {
		Position = UDim2.fromOffset(92, 8), Size = UDim2.new(1, -170, 0, 24),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})
	PaperUi.text(holder, starText(item.level, item.maxLevel), 17, P.gold, {
		Position = UDim2.fromOffset(92, 32), Size = UDim2.fromOffset(200, 22), RichText = true, ZIndex = 10,
	})
	local need = item.cost and item.cost.echoes or 0
	PaperUi.bar(holder, UDim2.fromOffset(92, 60), UDim2.fromOffset(150, 20),
		item.cost and math.clamp(item.echoes / math.max(need, 1), 0, 1) or 1, "xp", 10)
	PaperUi.image(holder, "it_soul", { Position = UDim2.fromOffset(248, 58), Size = UDim2.fromOffset(24, 24), ZIndex = 10 }, { noSlice = true })
	PaperUi.bold(holder, item.cost and ("%d/%d"):format(item.echoes, need) or tostring(item.echoes), 15, P.ink2, {
		Position = UDim2.fromOffset(274, 58), Size = UDim2.fromOffset(60, 24), ZIndex = 10,
	})
	-- справа: статус
	local tag, tagColor
	if not item.cost then
		tag, tagColor = "ПРЕДЕЛ", P.gold
	elseif isReady(item) then
		tag, tagColor = "ГОТОВО", P.green
	end
	if tag then
		local label = PaperUi.bold(holder, tag, 15, tagColor, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, 44),
			Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 11,
		})
		if tag == "ГОТОВО" then
			UiMotion.breathe(label, "TextTransparency", 0, 0.45, 0.7)
		end
	end
	if item.equipped then
		PaperUi.image(holder, "icCheck", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(32, 32), ZIndex = 11,
		}, { noSlice = true })
	elseif item.isNew then
		PaperUi.image(holder, "dot", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
			Size = UDim2.fromOffset(14, 14), ImageColor3 = Color3.fromRGB(220, 70, 60), ZIndex = 11,
		}, { noSlice = true })
	end
	local hit = PaperUi.hit(holder, 16)
	hit.MouseEnter:Connect(function()
		UiSound.play("list_tick")
		if slot.icon then
			UiMotion.punch(slot.icon, 0.12, 0.18)
		end
	end)
	hit.Activated:Connect(function()
		if state.busy then
			return
		end
		UiSound.play("ui_click")
		selectKey(item.key)
	end)
	return row
end

local function renderList(animate: boolean?)
	local list = refs.list
	clear(list)
	refs.rows = {}
	local all = items()
	local ready = 0
	local holders = {}
	for i, item in ipairs(all) do
		local row = buildRow(list, item, 6 + (i - 1) * (ROW.h + ROW.gap))
		refs.rows[item.key] = row
		table.insert(holders, row.holder)
		if isReady(item) then
			ready += 1
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, 12 + #all * (ROW.h + ROW.gap))
	if #all == 0 then
		centered(list, "Клинков нет. Принеси добычу из-за хребта.", 18, P.ink2, 200, { TextWrapped = true, Size = UDim2.new(1, 0, 0, 60) }, PaperUi.italic)
	end
	refs.count.Text = ready > 0 and ("Снаряжения: %d · готово к ковке: %d"):format(#all, ready) or ("Снаряжения: %d"):format(#all)
	local row = refs.rows[state.selectedKey]
	if row then
		rowSelected(row, true)
	end
	if animate then
		UiMotion.cascade(holders, Vector2.new(-40, 0), 0.04, 0.12, 0.3)
	end
end

-- ===== карточка (справа) =====

local function statRows(body, item, y: number): number
	local nowS, nextS = item.now or {}, item.next
	local rows = {
		{ "Урон", nowS.damage or 0, nextS and nextS.damage, "%d" },
		{ "Крит", nowS.crit or 0, nextS and nextS.crit, "%d%%" },
	}
	if item.kind == "armor" then
		rows = {
			{ "Здоровье", nowS.health or 0, nextS and nextS.health, "%d" },
			{ "Снижение урона", nowS.reduction or 0, nextS and nextS.reduction, "%d%%" },
			{ "Броня", nowS.armor or 0, nextS and nextS.armor, "%d" },
		}
		if nowS.mana then
			table.insert(rows, 2, { "Мана", nowS.mana or 0, nextS and nextS.mana, "%d" })
		end
	end
	if item.ability then
		table.insert(rows, { "Способность", nowS.ability or 0, nextS and nextS.ability, "+%d%%" })
	end
	PaperUi.bold(body, nextS and "СЕЙЧАС  ›  ПОСЛЕ" or "СЕЙЧАС", 14, P.faint, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, y), Size = UDim2.fromOffset(260, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	y += 22
	for i, r in ipairs(rows) do
		local ry = y + (i - 1) * 34
		if i % 2 == 1 then
			local stripe = Instance.new("Frame")
			stripe.BorderSizePixel = 0
			stripe.BackgroundColor3 = P.paperDark
			stripe.BackgroundTransparency = 0.6
			stripe.Position = UDim2.fromOffset(20, ry)
			stripe.Size = UDim2.new(1, -40, 0, 32)
			stripe.ZIndex = 6
			stripe.Parent = body
		end
		PaperUi.text(body, r[1], 19, P.ink2, { Position = UDim2.fromOffset(30, ry + 2), Size = UDim2.fromOffset(150, 28) })
		local nowText = (r[1] == "Способность" and r[2] <= 0) and "—" or r[4]:format(r[2])
		if r[3] then
			PaperUi.bold(body, nowText, 19, P.ink, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -168, 0, ry + 2), Size = UDim2.fromOffset(80, 28),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			PaperUi.text(body, "›", 20, P.faint, {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -150, 0, ry + 2), Size = UDim2.fromOffset(20, 28),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local gain = r[3] - r[2]
			PaperUi.bold(body, r[4]:format(r[3]), 19, gain > 0 and P.green or P.ink, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -76, 0, ry + 2), Size = UDim2.fromOffset(60, 28),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			if gain > 0 then
				PaperUi.bold(body, (r[4] == "%d" and "+%d" or "+%d%%"):format(gain), 15, P.greenLight, {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, ry + 5), Size = UDim2.fromOffset(48, 22),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
		else
			PaperUi.bold(body, nowText, 19, P.ink, {
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -30, 0, ry + 2), Size = UDim2.fromOffset(120, 28),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		end
	end
	return y + #rows * 34
end

-- Записка на булавке: что откроет следующий удар.
local function note(body, y: number, icon: string, text: string, color: Color3?)
	local box = PaperUi.image(body, "plateC", {
		Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, 62), ZIndex = 7, Rotation = -0.6,
	}, { scale = 2 })
	PaperUi.image(box, "pin", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(64, 32), ZIndex = 9,
	}, { noSlice = true })
	PaperUi.image(box, icon, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(32, 32), ZIndex = 9,
	}, { noSlice = true })
	PaperUi.italic(box, text, 17, color or P.gold, {
		Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -66, 1, -12),
		TextWrapped = true, ZIndex = 9,
	})
	return box
end

local function header(body, item)
	local ring = PaperUi.image(body, "ring80", {
		Position = UDim2.fromOffset(20, 112), Size = UDim2.fromOffset(84, 84), ZIndex = 7,
	}, { noSlice = true })
	refs.cardIcon = PixelUi.icon(ring, weaponIcon(item), UDim2.new(0.5, -26, 0.5, -28), 52, { ZIndex = 8 })
	PaperUi.bold(body, item.name or "Клинок", 22, PaperUi.rarityInk[item.rarityId] or P.ink, {
		Position = UDim2.fromOffset(116, 112), Size = UDim2.new(1, -136, 0, 52),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	})
	PaperUi.italic(body, ("%s · %s"):format(item.rarityName or UiAssets.RarityName[item.rarityId] or "", item.typeName or "Оружие"), 16, P.ink2, {
		Position = UDim2.fromOffset(116, 164), Size = UDim2.new(1, -136, 0, 20),
	})
	PaperUi.text(body, starText(item.level, item.maxLevel), 22, P.gold, {
		Position = UDim2.fromOffset(116, 184), Size = UDim2.new(1, -136, 0, 26), RichText = true,
	})
	PaperUi.divider(body, UDim2.fromOffset(20, 216), RIGHT.w - 40)
	if item.equipped then
		PaperUi.image(body, "icCheck", {
			Position = UDim2.fromOffset(76, 112), Size = UDim2.fromOffset(32, 32), ZIndex = 9,
		}, { noSlice = true })
	end
end

local function mainButton(body, text: string, tone: string?, disabled: boolean, onClick)
	local button = PaperUi.button(body, UDim2.fromOffset(20, 652), UDim2.new(1, -40, 0, 68), text, onClick, {
		tone = tone, textSize = 28, disabled = disabled, z = 9,
	})
	refs.action = button
	return button
end

local function renderUpgrade(body, item)
	local cost = item.cost
	local need = cost and cost.echoes or 0
	PaperUi.bold(body, "ЭХО", 16, P.faint, { Position = UDim2.fromOffset(24, 230), Size = UDim2.fromOffset(100, 20) })
	PaperUi.bold(body, cost and ("%d / %d"):format(item.echoes, need) or ("%d"):format(item.echoes), 17, (cost and item.echoes >= need) and P.green or P.ink2, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 230), Size = UDim2.fromOffset(120, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	-- сокеты
	refs.sockets = {}
	local shown = math.clamp(math.max(need, 1), 1, 6)
	local size, gap = 50, 8
	local x0 = (RIGHT.w - (shown * size + (shown - 1) * gap)) / 2
	for i = 1, shown do
		local filled = i <= item.echoes
		local socket = PaperUi.image(body, "ring64", {
			Position = UDim2.fromOffset(x0 + (i - 1) * (size + gap), 256), Size = UDim2.fromOffset(size, size), ZIndex = 7,
			ImageTransparency = filled and 0 or 0.35,
		}, { noSlice = true })
		local icon
		if filled then
			icon = PaperUi.image(socket, "it_soul", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), ZIndex = 8,
			}, { noSlice = true })
			if cost and item.echoes >= need then
				UiMotion.breathe(icon, "ImageTransparency", 0, 0.3, 0.6 + i * 0.05)
			end
		end
		refs.sockets[i] = { holder = socket, icon = icon }
	end
	if cost then
		local bar = PaperUi.bar(body, UDim2.fromOffset(20, 318), UDim2.new(1, -40, 0, 26), 0, "xp", 7)
		local barText = isReady(item) and "ГОТОВО К КОВКЕ"
			or (item.echoes < need and ("до ★%d — ещё %d эха"):format(item.level + 1, need - item.echoes))
			or ("до ★%d — ещё %d: %s"):format(item.level + 1, (cost.materials or 0) - (item.materialHave or 0), cost.materialName or "материал")
		bar:set(math.clamp(item.echoes / math.max(need, 1), 0, 1), barText, true)
		bar.label.TextSize = 15
	else
		centered(body, "Клинок на пределе редкости", 18, P.gold, 318, nil, PaperUi.italic)
	end
	local y = statRows(body, item, 356)
	-- зацепка: что откроет следующий уровень
	local nextLevel = item.level + 1
	if item.kind == "armor" then
		local text = item.passive and ("Пассивка «%s»: %s"):format(item.passive.name or "", item.passive.description or "")
			or ("Повторка этого комплекта — эхо. %s — с этажа %d."):format(cost and cost.materialName or "Материал", item.floor or 1)
		note(body, y + 16, item.passive and "it_star" or "it_ingot", text, item.passive and P.gold or P.ink2)
	elseif cost and nextLevel == (item.socketLevel or 3) then
		note(body, y + 16, "it_amuletRed", ("На ★%d откроется гнездо души босса!"):format(nextLevel), P.red)
	elseif cost and (nextLevel == 4 or nextLevel == 8) then
		note(body, y + 16, "it_star", ("На ★%d перезарядка способности −10%%!"):format(nextLevel))
	elseif cost then
		note(body, y + 16, "it_star", ("Потолок редкости — ★%d. Эхо сверх него станет пылью."):format(item.maxLevel), P.ink2)
	else
		note(body, y + 16, "it_dust", "Лишнее эхо Отзвук переплавит в Пыль эха.", P.ink2)
	end
	-- цена
	if cost then
		PaperUi.bold(body, "ЦЕНА", 16, P.faint, { Position = UDim2.fromOffset(24, 610), Size = UDim2.fromOffset(80, 28) })
		PaperUi.image(body, "it_soul", { Position = UDim2.fromOffset(150, 608), Size = UDim2.fromOffset(32, 32) }, { noSlice = true })
		PaperUi.bold(body, "×" .. tostring(cost.echoes), 19, item.echoes >= cost.echoes and P.ink or P.red, {
			Position = UDim2.fromOffset(186, 610), Size = UDim2.fromOffset(60, 28),
		})
		if item.kind == "armor" then
			-- Броня: материал этажа комплекта вместо золота.
			PaperUi.image(body, "it_ingot", { Position = UDim2.fromOffset(250, 608), Size = UDim2.fromOffset(32, 32) }, { noSlice = true })
			PaperUi.bold(body, ("%d/%d"):format(item.materialHave or 0, cost.materials or 0), 19, hasMaterials(item) and P.ink or P.red, {
				Position = UDim2.fromOffset(286, 610), Size = UDim2.fromOffset(120, 28),
			})
		else
			PaperUi.image(body, "it_coinStack", { Position = UDim2.fromOffset(250, 608), Size = UDim2.fromOffset(32, 32) }, { noSlice = true })
			PaperUi.bold(body, tostring(cost.gold), 19, gold() >= cost.gold and P.ink or P.red, {
				Position = UDim2.fromOffset(286, 610), Size = UDim2.fromOffset(90, 28),
			})
		end
	end
	local ready = isReady(item)
	local button = mainButton(body, cost and "УДАРИТЬ!" or "ПРЕДЕЛ", nil, not ready, function()
		ForgeWindow.upgrade()
	end)
	if ready then
		-- кнопка «дышит», пока есть что ковать
		local scale = Instance.new("UIScale")
		scale.Parent = button.holder
		game:GetService("TweenService"):Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.03 }):Play()
	end
	centered(body, cost and "Пробел — ударить" or "Выбери другой клинок", 15, P.faint, 726, nil, PaperUi.italic)
end

local function renderSoul(body, item)
	local socketLevel = item.socketLevel or 3
	local locked = item.level < socketLevel
	local name = soulName(item.soul)
	local ring = PaperUi.image(body, "ring224", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.fromOffset(196, 196), ZIndex = 7,
		ImageTransparency = locked and 0.3 or 0,
	}, { noSlice = true })
	if locked then
		PaperUi.image(ring, "icLock", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), ZIndex = 8,
		}, { noSlice = true })
		centered(body, "Гнездо закрыто", 24, P.ink, 446, nil, PaperUi.bold)
		centered(body, ("Откроется на ★%d"):format(socketLevel), 18, P.gold, 480, nil, PaperUi.italic)
		local bar = PaperUi.bar(body, UDim2.fromOffset(40, 520), UDim2.new(1, -80, 0, 26), 0, "xp", 7)
		bar:set(math.clamp(item.level / socketLevel, 0, 1), ("★%d из ★%d"):format(item.level, socketLevel), true)
		mainButton(body, "К ВПЛАВЛЕНИЮ", nil, false, function()
			ForgeWindow.setTab(1)
		end)
	else
		local icon = PaperUi.image(ring, name and "it_amuletRed" or "it_soul", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(96, 96), ZIndex = 8,
			ImageTransparency = name and 0 or 0.55,
		}, { noSlice = true })
		if name then
			UiMotion.bob(icon, 4, 1.4)
		end
		centered(body, name or "Гнездо пустое", 24, name and P.red or P.ink, 446, nil, PaperUi.bold)
		centered(body, "Души хранителей даёт победа", 17, P.ink2, 486, nil, PaperUi.italic)
		centered(body, "над боссом этажа.", 17, P.ink2, 508, nil, PaperUi.italic)
		if name then
			PaperUi.seal(body, UDim2.new(0.5, 110, 0, 270), 64, "ВПЛАВЛЕНА", P.green, 12)
		end
		mainButton(body, name and "ДУША НА МЕСТЕ" or "ЖДЁТ ДУШУ", nil, true, nil)
	end
	centered(body, ("Гнездо души открывается на ★%d"):format(socketLevel), 15, P.faint, 726, nil, PaperUi.italic)
end

local function renderMelt(body, item)
	local ring = PaperUi.image(body, "ring224", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.fromOffset(176, 176), ZIndex = 7,
	}, { noSlice = true })
	local dust = PaperUi.image(ring, "it_dust", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(80, 80), ZIndex = 8,
	}, { noSlice = true })
	UiMotion.bob(dust, 3, 1.2)
	refs.meltValue = centered(body, ("+%d пыли"):format(item.dustValue or 0), 36, P.green, 424, nil, PaperUi.bold)
	centered(body, "Пыль эха — валюта Лавки:", 17, P.ink2, 474, nil, PaperUi.italic)
	centered(body, "души, броня и редкости.", 17, P.ink2, 496, nil, PaperUi.italic)
	if item.equipped then
		centered(body, "Клинок в руке — сначала смени оружие.", 17, P.red, 540, { TextWrapped = true }, PaperUi.italic)
		mainButton(body, "В РУКЕ", "red", true, nil)
	else
		if item.level > 1 or item.echoes > 0 then
			centered(body, ("★%d и вплавленное эхо уйдут в пыль."):format(item.level), 17, P.red, 540, nil, PaperUi.italic)
		end
		local confirming = state.confirmMelt == item.key
		mainButton(body, confirming and "ТОЧНО? ЕЩЁ РАЗ" or "РАСПЛАВИТЬ", "red", false, function()
			ForgeWindow.melt()
		end)
	end
	centered(body, "Пробел — расплавить", 15, P.faint, 726, nil, PaperUi.italic)
end

local function renderTabs()
	for i, tile in ipairs(refs.tabs or {}) do
		local on = i == state.tab
		tile.face.Visible = not on
		tile.faceOn.Visible = on
		tile.label.TextColor3 = on and P.red or P.ink
		tile.icon.ImageTransparency = on and 0 or 0.25
	end
end

renderCard = function(animate: boolean?)
	local body = refs.card
	clear(body)
	refs.action = nil
	refs.sockets = nil
	local item = selectedItem()
	if not item then
		centered(body, "Нет клинков", 24, P.ink2, 320, nil, PaperUi.italic)
		return
	end
	header(body, item)
	if item.kind == "armor" and state.tab ~= 1 then
		centered(body, state.tab == 2 and "У брони нет гнезда души." or "Броню не плавят — повторки идут в эхо.", 20, P.ink2, 320,
			{ TextWrapped = true, Size = UDim2.new(1, -60, 0, 60), Position = UDim2.fromOffset(30, 320) }, PaperUi.italic)
	elseif state.tab == 1 then
		renderUpgrade(body, item)
	elseif state.tab == 2 then
		renderSoul(body, item)
	else
		renderMelt(body, item)
	end
	if animate then
		UiMotion.fadeIn(body, 0.16)
		body.Position = UDim2.fromOffset(14, 0)
		UiMotion.tween(body, 0.22, { Position = UDim2.new() }, Enum.EasingStyle.Back)
		UiSound.play("paper_slide")
	end
end

-- ===== вкладки-режимы =====

local function buildTabs(sheet)
	refs.tabs = {}
	for i, spec in ipairs(TABS) do
		local holder = Instance.new("Frame")
		holder.Name = "Mode" .. i
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(20 + (i - 1) * 124, 22)
		holder.Size = UDim2.fromOffset(112, 74)
		holder.ZIndex = 8
		holder.Parent = sheet
		local face = PaperUi.image(holder, "square", { Size = UDim2.fromScale(1, 1), ZIndex = 8 }, { scale = 2 })
		local faceOn = PaperUi.image(holder, "plate", { Size = UDim2.fromScale(1, 1), ZIndex = 8, Visible = false }, { scale = 2 })
		local icon = PaperUi.image(holder, spec.icon, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(32, 32), ZIndex = 10,
		}, { noSlice = true })
		local label = PaperUi.bold(holder, spec.title, 17, P.ink, {
			Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 10,
		})
		PaperUi.bold(holder, tostring(i), 13, P.faint, {
			Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 10,
		})
		local hit = PaperUi.hit(holder, 12)
		hit.MouseEnter:Connect(function()
			UiSound.play("ui_hover")
			UiMotion.punch(icon, 0.15, 0.18)
		end)
		hit.Activated:Connect(function()
			ForgeWindow.setTab(i)
		end)
		refs.tabs[i] = { holder = holder, face = face, faceOn = faceOn, icon = icon, label = label }
	end
end

function ForgeWindow.setTab(index: number)
	if state.busy or state.tab == index or not TABS[index] then
		return
	end
	state.tab = index
	state.confirmMelt = nil
	renderTabs()
	UiMotion.punch(refs.tabs[index].holder, 0.08, 0.2)
	UiSound.play("tab_select")
	renderCard(true)
	local item = selectedItem()
	if index == 2 then
		if item and item.level < (item.socketLevel or 3) then
			say("soulLocked", { n = item.socketLevel or 3 })
		else
			say("soulTab")
		end
	elseif index == 3 then
		say("meltTab")
	end
end

-- ===== ковка =====

local function anvilPoint(): Vector2
	local scene = ctx and ctx.scene
	if scene then
		for _, d in ipairs(scene:GetDescendants()) do
			if d:IsA("Attachment") and d.Name == "AnvilTop" then
				local p = win:toRoot(d.WorldPosition)
				if p then
					return p
				end
			end
		end
	end
	return win:canvasToRoot(Vector2.new(800, 520))
end

local function refuse(key: string, vars)
	say(key, vars)
	if smith then
		smith:no()
	end
	UiSound.play("error")
	if refs.action then
		PixelUi.nudge(refs.action.holder)
	end
end

local function setPips(count: number)
	for i, pip in ipairs(refs.pips or {}) do
		local on = i <= count
		pip.ImageColor3 = on and HOT or Color3.new(1, 1, 1)
		pip.ImageTransparency = (count == 0) and 0.5 or 0
		if on and i == count then
			UiMotion.punch(pip, 0.6, 0.25)
		end
	end
	refs.pipsHolder.Visible = count > 0
end

function ForgeWindow.upgrade()
	local item = selectedItem()
	if state.busy or not item then
		return
	end
	if not item.cost then
		refuse("max")
		return
	end
	if item.echoes < item.cost.echoes then
		refuse("noEcho", { n = item.cost.echoes - item.echoes })
		return
	end
	if not hasMaterials(item) then
		refuse("noMaterial", { n = (item.cost.materials or 0) - (item.materialHave or 0), item = item.cost.materialName or "материала" })
		return
	end
	if gold() < (item.cost.gold or 0) then
		refuse("noGold")
		return
	end
	state.busy = true
	if refs.action then
		refs.action:setDisabled(true)
		refs.action:setText("КУЁМ…")
	end
	refs.hint.Visible = false

	-- 1) эхо летит из сокетов к наковальне
	local target = anvilPoint()
	for i, socket in ipairs(refs.sockets or {}) do
		if i <= item.cost.echoes and socket.icon then
			local from = rootPoint(socket.holder)
			task.delay((i - 1) * 0.09, function()
				UiSound.play("echo_socket", { pitch = 1 + i * 0.06, gap = 0 })
				if socket.icon then
					socket.icon:Destroy()
					socket.icon = nil
				end
				UiMotion.punch(socket.holder, 0.25, 0.2)
				UiFx.flyIcon(win.root, "soul", from, target, 0.55, function()
					UiFx.burst(win.root, target, { C.mem, Color3.fromRGB(200, 248, 255) }, 8, 50)
				end)
			end)
		end
	end
	task.wait(0.55 + item.cost.echoes * 0.09)

	-- 2) горн разгорается: клинок на карточке раскаляется
	UiSound.play("forge_heat")
	UiFx.flash(HOT, 0.4, 0.18)
	if refs.cardIcon then
		UiMotion.tween(refs.cardIcon, 0.5, { ImageColor3 = HOT })
	end
	local result
	task.spawn(function()
		result = ctx.api.forge.upgrade(item.key)
	end)
	task.wait(0.35)

	-- 3) три удара
	for hit = 1, 3 do
		local done = false
		local function impact()
			UiSound.play("forge_anvil", { pitch = 0.94 + hit * 0.05, gap = 0 })
			task.delay(0.05, function()
				UiSound.play("forge_spark", { gap = 0 })
			end)
			UiFx.shake(0.3 + hit * 0.12, 0.16)
			UiFx.burst(win.root, target, { HOT, C.gold, Color3.fromRGB(255, 240, 200), C.mem }, 16 + hit * 8, 100 + hit * 34)
			setPips(hit)
			if refs.cardIcon then
				UiMotion.punch(refs.cardIcon, 0.2, 0.14)
			end
			done = true
		end
		if smith then
			smith:strike(impact)
		else
			impact()
		end
		local waited = 0
		while not done and waited < 1 do
			waited += task.wait()
		end
		task.wait(0.42)
	end
	local waited = 0
	while result == nil and waited < 5 do
		waited += task.wait(0.05)
	end
	if not win then
		return
	end
	if refs.cardIcon then
		UiMotion.tween(refs.cardIcon, 0.4, { ImageColor3 = Color3.new(1, 1, 1) })
	end
	if result and result.ok then
		ForgeWindow.success(item, result)
	else
		local reason = result and result.reason
		if reason == "material" then
			say("noMaterial", { n = result.need or 0, item = result.materialName or "материала" })
		else
			say(reason == "gold" and "noGold" or (reason == "max" and "max" or "noEcho"), { n = item.cost.echoes - item.echoes })
		end
		UiSound.play("forge_fail")
		if smith then
			smith:no()
		end
		setPips(0)
		refs.hint.Visible = true
		state.busy = false
		ForgeWindow.refresh()
	end
end

-- Итог ковки: лента, карточка-итог, звёзды по одной, прибавки числами.
function ForgeWindow.success(item, result)
	UiSound.play("forge_reveal")
	UiFx.flash(Color3.fromRGB(255, 236, 190), 0.55, 0.6)
	UiFx.shake(0.6, 0.25)
	if smith then
		smith:joy()
	end
	local socketOpened = result.unlocked and table.find(result.unlocked, "socket")
	say(socketOpened and "socket" or "success")

	-- листы уходят со стола
	for _, spec in ipairs({ { refs.left, -1 }, { refs.right, 1 } }) do
		local sheet, side = spec[1], spec[2]
		UiMotion.tween(sheet, 0.28, { Position = UiMotion.home(sheet).pos + UDim2.fromOffset(side * 470, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end

	local overlay = layer(win.canvas, "Success", 30)
	refs.overlay = overlay
	local before = result.levelBefore or item.level
	local after = result.levelAfter or (item.level + 1)

	local ribbon = PaperUi.ribbon(overlay, UDim2.fromOffset(800, 236), 620, "КОВКА УДАЛАСЬ!", { height = 88, textSize = 36, z = 34, anchor = Vector2.new(0.5, 0) })
	UiMotion.popIn(ribbon, 0.05, 0.3)

	local card = PaperUi.sheet(overlay, UDim2.fromOffset(530, 300), UDim2.fromOffset(540, 480), { kind = "sheet", z = 31, tilt = 1.4 })
	PaperUi.drop(card, 0.1)
	local ring = PaperUi.image(card, "ring112", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(104, 104), ZIndex = 33,
	}, { noSlice = true })
	PixelUi.icon(ring, weaponIcon(item), UDim2.new(0.5, -32, 0.5, -34), 64, { ZIndex = 34 })
	centered(card, item.name or "Клинок", 26, PaperUi.rarityInk[item.rarityId] or P.ink, 156, { ZIndex = 34 }, PaperUi.bold)
	-- звёзды отдельными метками, чтобы зажигать по одной
	local stars = {}
	local starSize = 34
	local total = item.maxLevel
	local x0 = 270 - (total * starSize) / 2
	for i = 1, total do
		local star = PaperUi.bold(card, "★", starSize, i <= before and P.gold or STAR_OFF, {
			Position = UDim2.fromOffset(x0 + (i - 1) * starSize, 192), Size = UDim2.fromOffset(starSize, starSize + 6),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 34,
		})
		stars[i] = star
	end
	PaperUi.divider(card, UDim2.fromOffset(40, 244), 460, 33)

	local gains = {}
	if item.kind == "armor" and item.next and item.now then
		table.insert(gains, { "Здоровье", item.now.health or 0, item.next.health or 0, "%d" })
		table.insert(gains, { "Снижение урона", item.now.reduction or 0, item.next.reduction or 0, "%d%%" })
		if item.now.mana then
			table.insert(gains, { "Мана", item.now.mana or 0, item.next.mana or 0, "%d" })
		end
	elseif item.next and item.now then
		table.insert(gains, { "Урон", item.now.damage or 0, item.next.damage or 0, "%d" })
		if (item.next.crit or 0) > (item.now.crit or 0) then
			table.insert(gains, { "Шанс крита", item.now.crit or 0, item.next.crit, "%d%%" })
		end
		if item.ability and (item.next.ability or 0) > (item.now.ability or 0) then
			table.insert(gains, { "Способность", item.now.ability or 0, item.next.ability, "+%d%%" })
		end
	end
	for i, g in ipairs(gains) do
		local y = 260 + (i - 1) * 38
		PaperUi.text(card, g[1], 20, P.ink2, { Position = UDim2.fromOffset(60, y), Size = UDim2.fromOffset(200, 30), ZIndex = 34 })
		local value = PaperUi.bold(card, g[4]:format(g[2]), 22, P.green, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, y), Size = UDim2.fromOffset(160, 30),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 34,
		})
		task.delay(0.6 + i * 0.18, function()
			if value.Parent then
				UiFx.countUp(value, g[2], g[3], 0.6, g[4])
				UiSound.play("list_tick", { gap = 0 })
				UiMotion.punch(value, 0.12, 0.2)
			end
		end)
	end
	if socketOpened then
		task.delay(1.2, function()
			if card.Parent then
				PaperUi.stamp(card, UDim2.new(1, -86, 0, 92), 84, "ГНЕЗДО ОТКРЫТО", P.red, 36)
				UiSound.play("stamp")
			end
		end)
	end

	-- новые звёзды зажигаются по одной
	task.delay(0.55, function()
		for i = before + 1, after do
			local star = stars[i]
			if star and star.Parent then
				star.TextColor3 = P.gold
				UiMotion.punch(star, 0.8, 0.3)
				UiSound.play("star_on", { pitch = 1 + i * 0.05, gap = 0 })
				UiFx.burst(win.root, rootPoint(star), { C.gold, Color3.fromRGB(255, 246, 200) }, 14, 60)
			end
			task.wait(0.28)
		end
	end)

	local function finish()
		if not refs.overlay then
			return
		end
		refs.overlay = nil
		UiSound.play("page_back")
		UiMotion.fadeOut(overlay, 0.18)
		task.delay(0.2, function()
			overlay:Destroy()
		end)
		for _, sheet in ipairs({ refs.left, refs.right }) do
			UiMotion.tween(sheet, 0.36, { Position = UiMotion.home(sheet).pos }, Enum.EasingStyle.Back)
		end
		setPips(0)
		refs.hint.Visible = true
		state.busy = false
		ForgeWindow.refresh()
	end
	refs.finishSuccess = finish
	local nextButton = PaperUi.button(card, UDim2.fromOffset(120, 394), UDim2.fromOffset(300, 60), "ДАЛЬШЕ", finish, { textSize = 24, z = 36 })
	UiMotion.popIn(nextButton.holder, 0.9, 0.5)
end

function ForgeWindow.melt()
	local item = selectedItem()
	if state.busy or not item then
		return
	end
	if item.kind == "armor" then
		refuse("armorMelt")
		return
	end
	if item.equipped then
		refuse("meltEquipped")
		return
	end
	-- двойное нажатие: первое — «точно?»
	if state.confirmMelt ~= item.key then
		state.confirmMelt = item.key
		UiSound.play("confirm")
		if refs.action then
			refs.action:setText("ТОЧНО? ЕЩЁ РАЗ")
			UiMotion.punch(refs.action.holder, 0.06, 0.2)
		end
		local key = item.key
		task.delay(3, function()
			if state.confirmMelt == key and not state.busy and win then
				state.confirmMelt = nil
				if refs.action and state.tab == 3 then
					refs.action:setText("РАСПЛАВИТЬ")
				end
			end
		end)
		return
	end
	state.confirmMelt = nil
	state.busy = true
	if refs.action then
		refs.action:setDisabled(true)
	end
	local target = anvilPoint()
	if refs.cardIcon then
		UiMotion.tween(refs.cardIcon, 0.35, { ImageColor3 = HOT })
	end
	UiSound.play("forge_heat", { pitch = 1.2 })
	if smith then
		smith:strike(function()
			UiSound.play("forge_anvil", { pitch = 0.8, gap = 0 })
			UiFx.shake(0.4, 0.2)
			UiFx.burst(win.root, target, { C.mem, Color3.fromRGB(150, 200, 230), HOT }, 30, 160)
		end)
	end
	task.wait(0.6)
	local result = ctx.api.forge.melt(item.key)
	if not win then
		return
	end
	if result and result.ok then
		UiSound.play("forge_quench")
		UiFx.floatText(win.root, ("+%d пыли"):format(result.dust or 0), target - Vector2.new(0, 60), C.mem, 32)
		if refs.wallet and refs.wallet.dust then
			UiMotion.punch(refs.wallet.dust, 0.3, 0.3)
		end
		say("melted")
		state.selectedKey = nil
	else
		UiSound.play("error")
	end
	state.busy = false
	ForgeWindow.refresh(true)
end

function ForgeWindow.refresh(animate: boolean?)
	state.data = ctx.api.forge.get() or { items = {} }
	local list = items()
	local found = false
	for _, item in ipairs(list) do
		if item.key == state.selectedKey then
			found = true
		end
	end
	if not found then
		state.selectedKey = list[1] and list[1].key or nil
	end
	renderList(animate)
	renderCard(false)
	if refs.wallet then
		refs.wallet.refresh()
	end
end

-- ===== кошелёк =====

local function buildWallet(canvas)
	PaperUi.image(canvas, "plate", {
		Position = UDim2.fromOffset(1196, 24), Size = UDim2.fromOffset(290, 60), ZIndex = 8,
	}, { scale = 2 })
	local wallet: any = {}
	for index, spec in ipairs({ { "it_coinStack", "Gold", "gold" }, { "it_dust", "EchoDust", "dust" } }) do
		local x = 1212 + (index - 1) * 140
		PaperUi.image(canvas, spec[1], { Position = UDim2.fromOffset(x, 38), Size = UDim2.fromOffset(32, 32), ZIndex = 10 }, { noSlice = true })
		local value = PaperUi.bold(canvas, "0", 22, P.ink, {
			Position = UDim2.fromOffset(x + 40, 38), Size = UDim2.fromOffset(90, 30), ZIndex = 10,
		})
		wallet[spec[3]] = value
		local connection = player:GetAttributeChangedSignal(spec[2]):Connect(function()
			local before = tonumber(value.Text) or 0
			local after = player:GetAttribute(spec[2]) or 0
			UiFx.countUp(value, before, after, 0.5, "%d")
		end)
		win:onCleanup(function()
			connection:Disconnect()
		end)
	end
	function wallet.refresh()
		local data = state.data or {}
		wallet.gold.Text = tostring(player:GetAttribute("Gold") or data.gold or 0)
		wallet.dust.Text = tostring(player:GetAttribute("EchoDust") or data.dust or 0)
	end
	return wallet
end

-- ===== клавиши =====

local function bindKeys()
	local keys = {
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
		Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.W, Enum.KeyCode.S,
		Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.ButtonA,
		Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown,
	}
	ContextActionService:BindActionAtPriority("KlinokForgeKeys", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or not win then
			return Enum.ContextActionResult.Pass
		end
		local k = input.KeyCode
		if refs.overlay then
			if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
				if refs.finishSuccess then
					UiSound.play("ui_click")
					refs.finishSuccess()
				end
			end
			return Enum.ContextActionResult.Sink
		end
		if k == Enum.KeyCode.One then
			ForgeWindow.setTab(1)
		elseif k == Enum.KeyCode.Two then
			ForgeWindow.setTab(2)
		elseif k == Enum.KeyCode.Three then
			ForgeWindow.setTab(3)
		elseif k == Enum.KeyCode.Up or k == Enum.KeyCode.W or k == Enum.KeyCode.DPadUp or k == Enum.KeyCode.Down or k == Enum.KeyCode.S or k == Enum.KeyCode.DPadDown then
			local list = items()
			if #list > 0 then
				local step = (k == Enum.KeyCode.Up or k == Enum.KeyCode.W or k == Enum.KeyCode.DPadUp) and -1 or 1
				local index = (selectedIndex() - 1 + step) % #list + 1
				UiSound.play("list_tick")
				selectKey(list[index].key)
			end
		elseif k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA then
			if state.busy then
				return Enum.ContextActionResult.Sink
			end
			if refs.action then
				UiMotion.punch(refs.action.holder, 0.06, 0.15)
			end
			if state.tab == 1 then
				task.spawn(ForgeWindow.upgrade)
			elseif state.tab == 3 then
				task.spawn(ForgeWindow.melt)
			else
				ForgeWindow.setTab(1)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 150, table.unpack(keys))
	win:onCleanup(function()
		ContextActionService:UnbindAction("KlinokForgeKeys")
	end)
end

-- ===== открыть / закрыть =====

function ForgeWindow.open(context)
	ctx = context
	state.tab, state.busy, state.confirmMelt = 1, false, nil
	refs = {}
	win = WindowBase.new("KlinokForge", { onClose = context.close, wallet = false, order = 30 })
	win.vignette.BackgroundTransparency = 0.5
	win.closeButton.Visible = false
	local canvas = win.canvas
	smith = EchoSmith.attach(context.scene)

	-- заголовок
	local ribbon = PaperUi.ribbon(canvas, UDim2.fromOffset(800, 10), 440, "КУЗНЯ ЭХА", { height = 76, textSize = 30, z = 10, anchor = Vector2.new(0.5, 0) })
	UiMotion.popIn(ribbon, 0.05, 0.6)
	refs.bubble = buildBubble(canvas)
	UiMotion.popIn(refs.bubble.holder, 0.3, 0.5)
	refs.wallet = buildWallet(canvas)
	PaperUi.roundButton(canvas, UDim2.fromOffset(1508, 22), 64, "icClose", context.close, { z = 12 })

	-- слева: оружейная
	local left = PaperUi.sheet(canvas, UDim2.fromOffset(LEFT.x, LEFT.y), UDim2.fromOffset(LEFT.w, LEFT.h), { kind = "sheet", z = 3 })
	refs.left = left
	UiMotion.home(left)
	centered(left, "ОРУЖЕЙНАЯ", 26, P.green, 16, { ZIndex = 8 }, PaperUi.bold)
	refs.count = centered(left, "", 17, P.ink2, 50, { ZIndex = 8 }, PaperUi.italic)
	PaperUi.divider(left, UDim2.fromOffset(20, 80), LEFT.w - 40, 8)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(16, 98)
	list.Size = UDim2.new(1, -24, 1, -116)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = P.ink2
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 7
	list.Parent = left
	refs.list = list

	-- справа: карточка
	local right = PaperUi.sheet(canvas, UDim2.fromOffset(RIGHT.x, RIGHT.y), UDim2.fromOffset(RIGHT.w, RIGHT.h), { kind = "sheetAlt", z = 3, tilt = 1.2 })
	refs.right = right
	UiMotion.home(right)
	buildTabs(right)
	refs.card = layer(right, "Card", 6)

	-- снизу: метки ударов и подсказка
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.AnchorPoint = Vector2.new(0.5, 0)
	pips.Position = UDim2.fromOffset(800, 792)
	pips.Size = UDim2.fromOffset(160, 40)
	pips.Visible = false
	pips.ZIndex = 9
	pips.Parent = canvas
	refs.pipsHolder = pips
	refs.pips = {}
	for i = 1, 3 do
		refs.pips[i] = PaperUi.image(pips, "dot32", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28 + (i - 1) * 52, 20), Size = UDim2.fromOffset(32, 32), ZIndex = 10,
		}, { noSlice = true })
	end
	refs.hint = PaperUi.italic(canvas, "1–3 режим · W/S клинок · Пробел — действие", 17, P.paper, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(800, 850), Size = UDim2.fromOffset(600, 24),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, TextStrokeColor3 = P.woodDark, ZIndex = 9,
	})

	-- появление: листы въезжают с боков, строки — каскадом
	PaperUi.drop(left, 0.02)
	PaperUi.drop(right, 0.08)
	left.Position = UiMotion.home(left).pos + UDim2.fromOffset(-60, 26)
	right.Position = UiMotion.home(right).pos + UDim2.fromOffset(60, 26)
	UiSound.play("paper_slide")

	state.selectedKey = nil
	renderTabs()
	ForgeWindow.refresh(true)
	bindKeys()

	local first = not player:GetAttribute("SmithMet")
	if first then
		player:SetAttribute("SmithMet", true)
	end
	task.delay(0.45, function()
		if not win then
			return
		end
		local item = selectedItem()
		if first then
			say("firstOpen")
		elseif item and isReady(item) then
			say("ready", { item = item.name })
		else
			say("open")
		end
	end)
	-- реплика от скуки
	task.spawn(function()
		local my = win
		while my.alive do
			task.wait(25 + math.random() * 15)
			if my.alive and not state.busy then
				say("idle")
			end
		end
	end)
	return win
end

function ForgeWindow.close()
	if refs.sayJob then
		refs.sayJob.cancel()
	end
	if smith then
		smith:destroy()
		smith = nil
	end
	if win then
		local closing = win
		win = nil
		UiSound.play("page_back")
		UiMotion.fadeOut(closing.canvas, 0.14)
		closing:destroy()
	end
	refs = {}
end

return ForgeWindow
