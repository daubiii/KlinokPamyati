--!nonstrict
-- FloorUiController (клиент)
-- Экраны вокруг прохождения этажа, в стиле HUD (Pixel Blade):
--   * заголовок комнаты: пиксельные буквы, золотая черта, подзаголовок;
--   * короткие сообщения (уровень, душа, костёр, подсказки);
--   * полоса босса сверху: сегменты, череп по центру, отметка второй фазы;
--   * экран гибели и итог этажа с кнопкой «В долину» (возврат в хаб).
-- Читаемость: крупный пиксельный шрифт с толстой обводкой и тенью. Тёмная полоса
-- во всю ширину и плашки под сообщениями убраны (08.11.2026) — мешали в бою;
-- сообщения ушли из центра экрана наверх, в бою они мельче и короче.
-- Данные приходят событиями FloorEvent / Notify и локальной шиной Bus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientState = require(Shared.Util.ClientState)
local Net = require(Shared.Net.Net)
local Chests = require(Shared.Config.Chests)
local Palette = require(Shared.Config.Palette)
local Rarities = require(Shared.Config.Rarities)

local Bus = require(script.Parent.Parent.Lib.Bus)
local Ui = require(script.Parent.Parent.Lib.Ui)
local EnemyVisualController = require(script.Parent.EnemyVisualController)

local FloorUiController = {}

local player = Players.LocalPlayer
local ui: any = {}
local boss = nil -- { model, name }
local pendingSummary = nil

local ROMAN = { "I", "II", "III", "IV" }
-- Пороги фаз Привратника на полосе босса (Config.Enemies, phases).
local PHASE_MARKS = { 0.6, 0.3 }

-- ===== Сообщения =====

local toastCount = 0

local function fadeText(label, goal: number, time: number)
	Ui.tween(label, time, { TextTransparency = goal })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		Ui.tween(stroke, time, { Transparency = goal })
	end
end

local toastLive = {} -- { label, text, born }

-- Идёт бой: рядом живой враг. Подсказки в бою — короче и мельче (правка 08.11.2026:
-- надписи с тёмными полосами закрывали бой).
local COMBAT_RANGE = 45
local function inCombat(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for model in pairs(EnemyVisualController.all()) do
		if model.Parent and (model:GetAttribute("EnemyHealth") or 0) > 0 then
			local part = model.PrimaryPart or model:FindFirstChild("Root") or model:FindFirstChildWhichIsA("BasePart")
			if part and (part.Position - root.Position).Magnitude <= COMBAT_RANGE then
				return true
			end
		end
	end
	return false
end

-- Тень под текстом: та же надпись тёмным со сдвигом — читается на любом фоне без плашки.
-- Тень — соседний элемент (в режиме Sibling ребёнок рисуется поверх родителя),
-- ссылка на неё — в таблице shadows.
local shadows = setmetatable({}, { __mode = "k" })
local function shadowOf(label, offset: number)
	local shadow = label:Clone()
	shadow.Name = label.Name .. "Shadow"
	for _, child in ipairs(shadow:GetChildren()) do
		if not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	shadow.TextColor3 = Palette.Env.void
	shadow.Position = label.Position + UDim2.fromOffset(offset, offset)
	shadow.ZIndex = math.max(label.ZIndex - 1, 1)
	local stroke = shadow:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Palette.Env.void
	end
	shadow.Parent = label.Parent
	shadows[label] = shadow
	label.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end

local function fadeWithShadow(label, goal: number, time: number)
	fadeText(label, goal, time)
	local shadow = shadows[label]
	if shadow then
		-- тень полупрозрачная: 0 → 0.45
		Ui.tween(shadow, time, { TextTransparency = goal >= 1 and 1 or 0.45 })
		local stroke = shadow:FindFirstChildOfClass("UIStroke")
		if stroke then
			Ui.tween(stroke, time, { Transparency = goal >= 1 and 1 or 0.6 })
		end
	end
end

-- Короткое сообщение: сверху под заголовком комнаты, без плашки — обводка и тень.
-- Повтор той же строки не плодит новую, а «толкает» старую. Видно не больше трёх.
local function toast(text: string, color: Color3?, big: boolean?)
	if text == "" then
		return
	end
	local now = os.clock()
	for _, entry in ipairs(toastLive) do
		if entry.text == text and entry.label.Parent and now - entry.born < 2 then
			entry.born = now
			entry.token += 1
			local scale = entry.row:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 1.15
				Ui.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			local token = entry.token
			task.delay(entry.life, function()
				if entry.token == token then
					entry.close()
				end
			end)
			return
		end
	end
	local combat = inCombat()
	toastCount += 1
	local row = Instance.new("Frame")
	row.Name = "Toast"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, big and 32 or 28)
	row.LayoutOrder = toastCount
	row.Parent = ui.toasts
	local label = (big and Ui.pixel or Ui.text)(row, {
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextSize = big and (combat and 18 or 20) or (combat and 19 or 21),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color or Ui.colors.text,
		TextTransparency = 1,
		ZIndex = 3,
		stroke = big and 4 or 3,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end
	local shadow = shadowOf(label, 2)
	shadow.TextTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Scale = big and 1.25 or 1.1
	scale.Parent = row
	fadeWithShadow(label, 0, 0.12)
	Ui.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	local entry: any = { row = row, label = label, text = text, born = now, token = 1, life = combat and 1.8 or 2.4 }
	local closed = false
	function entry.close()
		if closed then
			return
		end
		closed = true
		fadeWithShadow(label, 1, 0.4)
		task.delay(0.45, function()
			row:Destroy()
		end)
		for i, other in ipairs(toastLive) do
			if other == entry then
				table.remove(toastLive, i)
				break
			end
		end
	end
	table.insert(toastLive, entry)
	-- не больше трёх строк: старые уходят сразу
	while #toastLive > 3 do
		toastLive[1].close()
	end
	task.delay(entry.life, function()
		if entry.token == 1 then
			entry.close()
		end
	end)
end

-- Крупный заголовок (комната, зачистка): вверху по центру, без тёмной полосы во всю
-- ширину — толстая обводка и тень. В бою — мельче, без подзаголовка и быстрее гаснет.
local function banner(title: string, subtitle: string?, color: Color3?)
	local combat = inCombat()
	ui.bannerTitle.Text = title:upper()
	ui.bannerTitle.TextColor3 = color or Ui.colors.text
	ui.bannerSub.Text = (not combat and subtitle) or ""
	for _, label in ipairs({ ui.bannerTitle, ui.bannerSub }) do
		label.TextTransparency = 1
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
		local shadow = shadows[label]
		if shadow then
			shadow.Text = label.Text
			shadow.TextTransparency = 1
		end
	end
	ui.bannerLine.Size = UDim2.fromOffset(0, 5)
	ui.bannerLine.BackgroundTransparency = 0
	ui.bannerLine.Visible = true
	ui.bannerLine.BackgroundColor3 = color or Ui.colors.gold
	local rest = combat and 0.78 or 1
	ui.bannerScale.Scale = rest * 1.2
	fadeWithShadow(ui.bannerTitle, 0, 0.22)
	fadeWithShadow(ui.bannerSub, 0, 0.35)
	Ui.tween(ui.bannerScale, 0.3, { Scale = rest }, Enum.EasingStyle.Back)
	Ui.tween(ui.bannerLine, 0.4, { Size = UDim2.fromOffset(combat and 260 or 380, 5) })
	local token = (ui.bannerToken or 0) + 1
	ui.bannerToken = token
	task.delay(combat and 1.6 or 2.6, function()
		if ui.bannerToken == token then
			fadeWithShadow(ui.bannerTitle, 1, 0.5)
			fadeWithShadow(ui.bannerSub, 1, 0.5)
			Ui.tween(ui.bannerLine, 0.5, { BackgroundTransparency = 1 })
			-- Обводка черты сама не гаснет: прячем черту целиком.
			task.delay(0.5, function()
				if ui.bannerToken == token then
					ui.bannerLine.Visible = false
				end
			end)
		end
	end)
end

-- ===== Полоса босса =====

local function showBossBar(model, name: string)
	boss = { model = model, name = name }
	ui.bossName.Text = name:upper()
	ui.boss.Visible = true
	ui.boss.GroupTransparency = 1
	ui.bossScale.Scale = 0.8
	Ui.tween(ui.boss, 0.5, { GroupTransparency = 0 })
	Ui.tween(ui.bossScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function hideBossBar()
	boss = nil
	if ui.boss.Visible then
		Ui.tween(ui.boss, 0.6, { GroupTransparency = 1 })
		task.delay(0.65, function()
			if not boss then
				ui.boss.Visible = false
			end
		end)
	end
end

local function updateBoss(dt: number)
	if not boss then
		return
	end
	local model = boss.model
	if not model or not model.Parent then
		hideBossBar()
		return
	end
	local health = model:GetAttribute("EnemyHealth") or 0
	local maxHealth = math.max(model:GetAttribute("EnemyMaxHealth") or 1, 1)
	ui.bossBar.set(health / maxHealth, dt)
	local phase = model:GetAttribute("BossPhase") or 1
	local enraged = phase >= 2
	ui.bossBar.color(enraged and Ui.colors.danger:Lerp(Palette.Env.flame, 0.5 + 0.5 * math.sin(os.clock() * (phase >= 3 and 10 or 6))) or Ui.colors.danger)
	local phaseName = model:GetAttribute("BossPhaseName")
	ui.bossPhase.Text = enraged and ("ФАЗА %s — %s"):format(ROMAN[phase] or tostring(phase), (phaseName or ""):upper()) or "ФАЗА I"
	ui.bossPhase.TextColor3 = enraged and Palette.Env.flame or Ui.colors.textMuted
	if health <= 0 then
		task.delay(1.2, hideBossBar)
	end
end

-- ===== Гибель и итог =====

local function showDeath()
	ui.death.Visible = true
	ui.death.BackgroundTransparency = 1
	ui.deathScale.Scale = 1.4
	for _, label in ipairs({ ui.deathTitle, ui.deathSub }) do
		label.TextTransparency = 1
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end
	Ui.tween(ui.death, 0.9, { BackgroundTransparency = 0.3 })
	fadeText(ui.deathTitle, 0, 0.6)
	Ui.tween(ui.deathScale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
	fadeText(ui.deathSub, 0, 1.2)
end

local function hideDeath()
	if ui.death.Visible then
		Ui.tween(ui.death, 0.5, { BackgroundTransparency = 1 })
		fadeText(ui.deathTitle, 1, 0.4)
		fadeText(ui.deathSub, 1, 0.4)
		task.delay(0.55, function()
			ui.death.Visible = false
		end)
	end
end

local function statRow(parent, order: number, icon: string, title: string)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.LayoutOrder = order
	row.Parent = parent
	Ui.icon(row, icon, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(0, 4), ZIndex = 14 })
	Ui.text(row, {
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(0.6, -36, 1, 0),
		Text = title,
		TextSize = 16,
		ZIndex = 14,
	})
	return Ui.pixel(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 14,
	})
end

local function floorInfo(floorId)
	return Chests.Floors[Chests.clampFloor(floorId or player:GetAttribute("FloorId") or 1)]
end

local function showSummary(data)
	local info = floorInfo(data.floorId)
	ui.sumSub.Text = ("%s · %s"):format(data.floorName or info.name, data.bossDefeated or info.bossDefeated)
	-- сундуки этажа v3 уже в сумке: сколько и какие
	local chests = data.chests or {}
	local golden = 0
	for _, chest in ipairs(chests) do
		if chest.grade == "gold" then
			golden += 1
		end
	end
	ui.sumChests.Text = golden > 0 and ("%d (★%d)"):format(#chests, golden) or tostring(#chests)
	ui.sumChestsHint.Visible = #chests > 0
	ui.sumTime.Text = Ui.clock(data.seconds or 0)
	ui.sumKills.Text = tostring(data.kills or 0)
	ui.sumDeaths.Text = tostring(data.deaths or 0)
	ui.sumLevel.Text = tostring(data.level or 1)
	ui.sumGold.Text = tostring(data.gold or 0)
	ui.summary.Visible = true
	ClientState.lockInput("ui", true)
	ClientState.lockInput("summary", true)
	ui.summaryCard.Position = UDim2.new(0.5, 0, 0.62, 0)
	Ui.tween(ui.summaryCard, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
end

-- Итог этажа ведёт в хаб: новый забег начинается вратами Хранилища.
local function returnToHub()
	local net = ReplicatedStorage:FindFirstChild("KlinokHubNet")
	local remote = net and net:FindFirstChild("RequestReturnHub")
	if not remote then
		return
	end
	local ok, response = pcall(function()
		return remote:InvokeServer()
	end)
	if ok and type(response) == "table" and response.ok then
		ui.summary.Visible = false
		ClientState.lockInput("ui", false)
		ClientState.lockInput("summary", false)
	end
end

-- ===== События =====

local function onFloorEvent(payload)
	if type(payload) ~= "table" then
		return
	end
	local kind = payload.kind
	if kind == "room" then
		if payload.roomKind == "rest" then
			banner(payload.name, "Костёр: зажми E, чтобы отдохнуть", Palette.Env.ember)
		elseif payload.roomKind == "courtyard" then
			banner(payload.name, "Главные ворота башни впереди", Palette.Ruin.beacon)
		elseif payload.roomKind == "intro" then
			banner(payload.name, "Привратный двор — путь к Хранилищу", Palette.Ruin.beacon)
		elseif payload.roomKind == "miniboss" then
			banner(payload.name, "Хозяин ключа ждёт", Ui.colors.gold)
		elseif payload.roomKind == "branch" then
			banner(payload.name, "Ответвление: зачисти — получишь сундук")
		elseif payload.roomKind == "hold" then
			banner(payload.name, "Запусти лебёдку и продержись")
		elseif payload.roomKind == "street" then
			banner(payload.name, "Осторожно: засады")
		elseif payload.roomKind == "boss" then
			-- Заголовок даёт сцена босса.
		else
			-- Двор — комната 0, поэтому номер боевой комнаты на 1 меньше индекса.
			banner(payload.name, ("Комната %d из %d"):format(payload.room - 1, payload.total - 1))
		end
	elseif kind == "wave" then
		if payload.waves and payload.waves > 1 then
			toast(("ВОЛНА %d/%d"):format(payload.wave, payload.waves), Ui.colors.gold, true)
		end
	elseif kind == "roomCleared" then
		if payload.name and payload.room and payload.room > 1 then
			task.delay(0.3, function()
				if payload.roomKind == "boss" then
					banner(floorInfo().bossDefeated, "Золотой сундук летит в сумку — откроешь в долине", Ui.colors.gold)
				elseif payload.roomKind == "miniboss" then
					banner("Мини-босс повержен", "Подбери ключ — он нужен у ворот Хранилища", Ui.colors.gold)
				elseif payload.roomKind == "street" or payload.roomKind == "rest" or payload.roomKind == "intro" then
					-- проходные зоны: без баннера
				else
					banner("Комната зачищена", "Двери открыты — путь дальше свободен", Ui.colors.gold)
				end
			end)
		end
	elseif kind == "roomReset" then
		toast("Комната начинается заново", Ui.colors.textMuted)
	elseif kind == "door" then
		Bus.emit("sfx", { name = "door", position = payload.position })
		Bus.emit("shake", { amount = 0.12, time = 0.3 })
	elseif kind == "chestReady" then
		-- v3: сундук сам летит в сумку (ChestFlyController, лента «ПОЛУЧЕН СУНДУК»)
		if not payload.granted then
			toast("ПОЯВИЛСЯ СУНДУК", Ui.colors.gold, true)
		end
	elseif kind == "playerDied" then
		hideBossBar()
		showDeath()
	elseif kind == "bossIntro" then
		Bus.emit("bossIntro", payload)
		task.delay(payload.duration or 4, function()
			if payload.model and payload.model.Parent then
				showBossBar(payload.model, payload.name or "Босс")
			end
		end)
	elseif kind == "floorSummary" then
		if payload.chests then
			-- v3: сундук не открывают на этаже — итог сразу после полёта сундука
			task.delay(0.2, function()
				showSummary(payload)
			end)
		else
			pendingSummary = payload
		end
	elseif kind == "newRun" then
		hideBossBar()
		hideDeath()
		ui.summary.Visible = false
	end
end

local function onNotify(payload)
	if type(payload) ~= "table" then
		return
	end
	local color = Ui.colors.text
	local big = false
	if payload.kind == "levelUp" then
		color = Ui.colors.gold
		big = true
		Bus.emit("sfx", { name = "levelUp" })
	elseif payload.kind == "soul" then
		color = Palette.Memory
		big = true
		Bus.emit("sfx", { name = "soul" })
	elseif payload.kind == "soulHint" then
		color = Palette.Memory
	elseif payload.kind == "campfire" then
		color = Ui.colors.heal
		Bus.emit("sfx", { name = "heal" })
	elseif payload.kind == "warn" then
		-- без плашки серый терялся на светлом полу — подсказки светлым тёплым
		color = Palette.Env.bone
	elseif payload.kind == "danger" then
		-- «ЗАСАДА!», «Ворота опустились!»: крупно и красным, но наверху и коротко
		color = Ui.colors.danger
		big = true
	elseif payload.kind == "talent" then
		-- Древо талантов: новое очко за уровень, сработавшие узлы («Несгибаемый»).
		color = Ui.colors.gold
	elseif payload.kind == "armor" or payload.kind == "armorSet" then
		big = payload.kind == "armorSet" or (payload.rarity ~= nil and Rarities.atLeast(payload.rarity, "epic"))
		Bus.emit("sfx", { name = "armorEquip" })
	end
	if payload.rarity then
		color = payload.kind == "soul" and Palette.Memory or Rarities.color(payload.rarity)
	end
	toast(payload.text or "", color, big)
end

local function build()
	local gui = Ui.screen("KlinokFloorUi", 3, true)

	-- Сообщения — сверху, под заголовком комнаты: центр экрана свободен для боя.
	ui.toasts = Instance.new("Frame")
	ui.toasts.BackgroundTransparency = 1
	ui.toasts.AnchorPoint = Vector2.new(0.5, 0)
	ui.toasts.Position = UDim2.new(0.5, 0, 0.255, 0)
	ui.toasts.Size = UDim2.fromOffset(900, 110)
	ui.toasts.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.Parent = ui.toasts

	-- Заголовок комнаты.
	local bannerHolder = Instance.new("Frame")
	bannerHolder.BackgroundTransparency = 1
	bannerHolder.AnchorPoint = Vector2.new(0.5, 0)
	bannerHolder.Position = UDim2.new(0.5, 0, 0.115, 0)
	bannerHolder.Size = UDim2.fromOffset(900, 110)
	bannerHolder.Parent = gui
	ui.bannerScale = Instance.new("UIScale")
	ui.bannerScale.Parent = bannerHolder
	ui.bannerTitle = Ui.pixel(bannerHolder, {
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 3,
		stroke = 5,
	})
	shadowOf(ui.bannerTitle, 3).TextTransparency = 1
	ui.bannerLine = Ui.frame(bannerHolder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Ui.colors.gold,
		BackgroundTransparency = 1,
		Visible = false,
	})
	Ui.outline(ui.bannerLine, 2)
	ui.bannerSub = Ui.text(bannerHolder, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.colors.text,
		TextTransparency = 1,
		ZIndex = 3,
		stroke = 3,
	})
	shadowOf(ui.bannerSub, 2).TextTransparency = 1

	-- Полоса босса: имя, череп, сегменты, отметка фазы.
	ui.boss = Instance.new("CanvasGroup")
	ui.boss.BackgroundTransparency = 1
	ui.boss.AnchorPoint = Vector2.new(0.5, 0)
	ui.boss.Position = UDim2.new(0.5, 0, 0, 10)
	ui.boss.Size = UDim2.fromOffset(700, 92)
	ui.boss.Visible = false
	ui.boss.Parent = gui
	ui.bossScale = Instance.new("UIScale")
	ui.bossScale.Parent = ui.boss
	ui.bossName = Ui.pixel(ui.boss, {
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Ui.colors.text,
	})
	ui.bossBar = Ui.bar(ui.boss, {
		Position = UDim2.fromOffset(30, 40),
		Size = UDim2.new(1, -60, 0, 24),
	}, { segments = 20, color = Ui.colors.danger })
	-- Отметки порогов фаз.
	for _, mark in ipairs(PHASE_MARKS) do
		local marker = Ui.frame(ui.bossBar.frame, {
			Position = UDim2.new(mark, -2, 0, 0),
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = Ui.colors.gold,
			ZIndex = 30,
		})
		Ui.outline(marker, 1)
	end
	-- Наконечники полосы.
	for _, side in ipairs({ 0, 1 }) do
		local cap = Ui.frame(ui.boss, {
			AnchorPoint = Vector2.new(side, 0.5),
			Position = UDim2.new(side, 0, 0, 52),
			Size = UDim2.fromOffset(30, 34),
			BackgroundColor3 = Ui.colors.accentBorder,
			ZIndex = 5,
		})
		Ui.outline(cap, 3)
		Ui.frame(cap, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			BackgroundColor3 = Ui.colors.gold,
			ZIndex = 6,
		})
	end
	local skullHolder = Ui.frame(ui.boss, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Ui.colors.outline,
		ZIndex = 40,
	})
	Ui.outline(skullHolder, 2, Ui.colors.gold)
	Ui.icon(skullHolder, "skull", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 41,
	})
	ui.bossPhase = Ui.pixel(ui.boss, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "",
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Center,
		stroke = 2,
	})

	-- Экран гибели.
	ui.death = Ui.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.Env.void,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	})
	local deathHolder = Instance.new("Frame")
	deathHolder.BackgroundTransparency = 1
	deathHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	deathHolder.Position = UDim2.fromScale(0.5, 0.46)
	deathHolder.Size = UDim2.fromOffset(800, 140)
	deathHolder.ZIndex = 11
	deathHolder.Parent = ui.death
	ui.deathScale = Instance.new("UIScale")
	ui.deathScale.Parent = deathHolder
	ui.deathTitle = Ui.pixel(deathHolder, {
		Size = UDim2.new(1, 0, 0, 70),
		Text = "ВЫ ПАЛИ",
		TextSize = 48,
		TextColor3 = Ui.colors.danger,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 11,
		stroke = 5,
	})
	ui.deathSub = Ui.text(deathHolder, {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Эхо возвращает тебя к Вратам Печатей. Души рассеялись",
		TextSize = 19,
		TextColor3 = Ui.colors.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 11,
	})

	-- Итог этажа.
	ui.summary = Ui.frame(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.Env.void,
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 12,
	})
	ui.summaryCard = Ui.panel(ui.summary, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 520),
		ZIndex = 13,
	})
	Ui.pixel(ui.summaryCard, {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 34),
		Text = "ЭТАЖ ПРОЙДЕН",
		TextSize = 24,
		TextColor3 = Ui.colors.gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 14,
		stroke = 4,
	})
	ui.sumSub = Ui.text(ui.summaryCard, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "Привратный двор · Привратник повержен",
		TextSize = 15,
		TextColor3 = Ui.colors.textMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 14,
	})
	local stats = Instance.new("Frame")
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromOffset(50, 112)
	stats.Size = UDim2.new(1, -100, 0, 240)
	stats.ZIndex = 14
	stats.Parent = ui.summaryCard
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 6)
	statsLayout.Parent = stats
	ui.sumTime = statRow(stats, 1, "dash", "Время")
	ui.sumKills = statRow(stats, 2, "sword", "Повержено врагов")
	ui.sumDeaths = statRow(stats, 3, "skull", "Падений")
	ui.sumLevel = statRow(stats, 4, "helm", "Уровень")
	ui.sumGold = statRow(stats, 5, "coin", "Золото")
	ui.sumChests = statRow(stats, 6, "chest", "Сундуки в сумке")
	ui.sumChestsHint = Ui.text(ui.summaryCard, {
		Position = UDim2.fromOffset(0, 362),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Откроешь в долине: сумка → «Сундуки»",
		TextSize = 14,
		TextColor3 = Palette.Memory,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 14,
		Visible = false,
	})
	local again = Ui.button(ui.summaryCard, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		Size = UDim2.fromOffset(300, 64),
		Text = "В ДОЛИНУ",
		TextSize = 16,
		ZIndex = 15,
	})
	again.Activated:Connect(function()
		Bus.emit("sfx", { name = "ui" })
		returnToHub()
	end)
end

function FloorUiController.start()
	build()

	local floorRemote = Net.get("FloorEvent")
	if floorRemote then
		floorRemote.OnClientEvent:Connect(onFloorEvent)
	end
	local notifyRemote = Net.get("Notify")
	if notifyRemote then
		notifyRemote.OnClientEvent:Connect(onNotify)
	end
	Bus.on("notify", onNotify)
	Bus.on("bossPhase", function(data)
		banner(("Фаза %s"):format(ROMAN[data.phase] or tostring(data.phase)), data.name or "", Ui.colors.danger)
	end)
	Bus.on("chestClosed", function()
		if pendingSummary then
			local data = pendingSummary
			pendingSummary = nil
			task.delay(0.4, function()
				showSummary(data)
			end)
		end
	end)

	player.CharacterAdded:Connect(hideDeath)
	RunService.RenderStepped:Connect(updateBoss)
	print("[FloorUiController] экраны этажа")
end

return FloorUiController
