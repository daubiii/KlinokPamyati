--!nonstrict
-- BoardWindow — Доска заданий гильдии. Слева вкладки и прокручиваемый список:
-- сюжетные главы с заголовками, все задания видны сразу — доступные с печатью
-- «ВЗЯТЬ», недоступные под замком, достижения с живым прогрессом. Справа
-- выбранное задание: слова заказчика, шаги, награда, «Следить», сургучная
-- печать «СДАТЬ» (у не взятого — «ВЗЯТЬ», у закрытого — «ЗАКРЫТО»).
-- Достижения (q.category == "achv") выполняются сами: у них вместо печати —
-- кубок, следить не нужно.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiMotion = require(Lib.UiMotion)
local UiSound = require(Lib.UiSound)
local WindowBase = require(Lib.WindowBase)

local BoardWindow = {}

local C = UiAssets.Colors
local win, ctx
local refs: any = {}
local state: any = { tab = "story", selected = 1, data = nil }
-- Вкладки: сюжет по главам, достижения тирами, готовые. «Поручения» вернутся
-- вместе с ежедневными/еженедельными (GDD раздел 9) — вкладку вернём тогда.
-- Вкладки: сюжет по главам, достижения тирами, поручения (ежедневные и
-- еженедельные). Сданные видны на своих местах (галочки и кубки) —
-- отдельная вкладка «Готово» больше не нужна.
local TABS = { { "story", "Сюжет", 112 }, { "achv", "Достижения", 168 }, { "tasks", "Поручения", 140 } }

local ROW_H, HEAD_H, GAP = 64, 30, 6

local renderDetail

-- Названия цепочек достижений для заголовков-разделителей.
local ACHV_CHAINS = {
	parries = "Парирования",
	damageDealt = "Урон врагам",
	enemiesKilled = "Победы над врагами",
}

-- Раздел текущего задания: глава сюжета, цепочка достижений или тип поручения.
local function sectionOf(q): string?
	if state.tab == "story" then
		return q.chapter
	elseif state.tab == "achv" then
		return q.stat and ACHV_CHAINS[q.stat] or q.chapter
	elseif state.tab == "tasks" then
		return q.section
	end
	return nil
end

-- Подсветка выбранной строки: рисуем на позиции строки в списке.
local function rowPositions()
	local positions, y = {}, 0
	local lastSection = nil
	for _, q in ipairs(state.data.quests or {}) do
		local section = sectionOf(q)
		if section and section ~= lastSection then
			y += HEAD_H
			lastSection = section
		end
		table.insert(positions, y)
		y += ROW_H + GAP
	end
	return positions
end

local function renderList(animate: boolean?)
	local list = refs.list
	for _, c in ipairs(list:GetChildren()) do
		c:Destroy()
	end
	local positions = rowPositions()
	-- подсветка выбранной строки — под записками, поэтому рисуется первой
	local onY = positions[state.selected]
	if onY then
		PixelUi.glow(list, UDim2.fromOffset(214, onY + ROW_H / 2), UDim2.fromOffset(500, ROW_H + 60), C.gold, 0.55)
	end
	local lastSection = nil
	for i, q in ipairs(state.data.quests) do
		-- заголовок раздела (глава / цепочка) — в отведённой ему полосе СПЕЦИФИКАЦИИ
		-- позиций, а не на месте прошлой строки: раньше наезжал на записку
		local section = sectionOf(q)
		if section and section ~= lastSection then
			PixelUi.label(list, section, 16, C.green, {
				Position = UDim2.fromOffset(0, positions[i] - HEAD_H + 4),
				Size = UDim2.fromOffset(428, HEAD_H - 8),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			lastSection = section
		end
		local y = positions[i]
		local locked = q.state == "locked"
		local done = q.state == "done"
		local note = PixelUi.parch(list, UDim2.fromOffset(0, y), UDim2.fromOffset(428, ROW_H))
		note.BackgroundTransparency = (locked and 0.45) or 0
		local titleColor = locked and C.grey or C.ink
		PixelUi.text(note, q.title, 16, titleColor, { Position = UDim2.fromOffset(18, 6), Size = UDim2.fromOffset(250, 20), ZIndex = 5 })
		local ratio = q.goal > 0 and math.min(q.progress / q.goal, 1) or 0
		local barColor = (q.state == "ready" and C.gold) or (done and C.grey) or C.green
		-- дорожка на пергаменте — полупрозрачная с контуром, а не чёрная плашка
		PixelUi.progress(note, UDim2.fromOffset(18, 32), UDim2.fromOffset(180, 14), ratio, barColor, {
			track = C.ink,
			trackTransparency = 0.72,
			trackStroke = C.ink2,
		})
		PixelUi.text(note, ("%d/%d"):format(q.progress, q.goal), 16, locked and C.grey or C.ink, { Position = UDim2.fromOffset(204, 28), Size = UDim2.fromOffset(100, 20), ZIndex = 5 })
		PixelUi.icon(note, q.rewardIcon or "coin", UDim2.fromOffset(306, 16), 32, { ZIndex = 5 })
		-- состояние справа: печать, замок, галочка или кубок достижений
		if q.state == "ready" then
			local stamp = Instance.new("Frame")
			stamp.BackgroundTransparency = 1
			stamp.Position = UDim2.fromOffset(340, 14)
			stamp.Size = UDim2.fromOffset(80, 36)
			stamp.ZIndex = 6
			stamp.Parent = note
			local st = Instance.new("UIStroke")
			st.Color = Color3.fromRGB(190, 50, 40)
			st.Thickness = 3
			st.Parent = stamp
			PixelUi.text(stamp, "ВЗЯТЬ!", 16, Color3.fromRGB(190, 50, 40), { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
		elseif q.category == "achv" then
			local trophy = PixelUi.icon(note, "trophy", UDim2.fromOffset(348, 12), 40, { ZIndex = 6 })
			trophy.ImageColor3 = done and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(120, 112, 104)
		elseif locked then
			PixelUi.icon(note, "lock", UDim2.fromOffset(350, 14), 36, { ZIndex = 6 })
		elseif done then
			PixelUi.piece(note, "check", { Position = UDim2.fromOffset(350, 16), Size = UDim2.fromOffset(32, 32), ZIndex = 6 })
		end
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 12
		hit.Parent = note
		-- бумажка чуть поворачивается под курсором
		local tilt = (i % 2 == 0) and 1.2 or -1.2
		hit.MouseEnter:Connect(function()
			UiSound.play("choice_hover", { volume = 0.5 })
			if not locked then
				UiMotion.tween(note, 0.12, { Rotation = tilt })
			end
		end)
		hit.MouseLeave:Connect(function()
			UiMotion.tween(note, 0.14, { Rotation = 0 })
		end)
		hit.Activated:Connect(function()
			if state.selected == i then
				UiMotion.punch(note, 0.03)
				return
			end
			if locked then
				UiSound.play("error")
				UiMotion.punch(note, 0.05)
				return -- замок: не выбираем, детали не меняются
			end
			UiSound.play("paper_slide", { volume = 0.7 })
			state.selected = i
			renderList(false)
			renderDetail(true)
		end)
		if animate ~= false and not locked then
			PixelUi.slideIn(note, -1, 0.03 * i)
			task.delay(0.05 + 0.05 * i, function()
				if note.Parent then
					UiSound.play("list_tick", { pitch = 0.9 + (i % 8) * 0.06, volume = 0.4, gap = 0 })
				end
			end)
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, (positions[#positions] or 0) + ROW_H + GAP)
	if #state.data.quests == 0 then
		PixelUi.label(list, "Заданий нет", 24, C.grey, { Position = UDim2.fromOffset(0, 200), Size = UDim2.fromOffset(428, 30), TextXAlignment = Enum.TextXAlignment.Center })
	end
end

renderDetail = function(animate: boolean?)
	local body = refs.detail
	for _, c in ipairs(body:GetChildren()) do
		c:Destroy()
	end
	local q = state.data.quests[state.selected]
	if not q then
		return
	end
	local locked = q.state == "locked"
	local done = q.state == "done"
	PixelUi.label(body, q.title, 24, locked and C.grey or C.gold, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center })
	PixelUi.label(body, q.chapter or "", 16, C.grey, { Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
	local quote = PixelUi.parch(body, UDim2.fromOffset(20, 96), UDim2.new(1, -40, 0, 30 + #(q.quote or {}) * 30))
	for i, l in ipairs(q.quote or {}) do
		PixelUi.text(quote, l, 16, C.ink, { Position = UDim2.fromOffset(20, 14 + (i - 1) * 30), Size = UDim2.fromOffset(400, 24), ZIndex = 5 })
	end
	if q.giver then
		PixelUi.text(quote, "— " .. q.giver, 16, C.ink2, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -8), Size = UDim2.fromOffset(240, 24), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	end
	local y = 96 + 30 + #(q.quote or {}) * 30 + 24
	for i, step in ipairs(q.steps or {}) do
		PixelUi.piece(body, step.done and "check" or "checkOff", { Position = UDim2.fromOffset(26, y + (i - 1) * 40), Size = UDim2.fromOffset(28, 28), ZIndex = 6 })
		PixelUi.label(body, step.text, 16, step.done and C.bone or C.grey, { Position = UDim2.fromOffset(70, y + (i - 1) * 40 + 2), Size = UDim2.fromOffset(340, 24) })
	end
	local ry = 536
	PixelUi.label(body, "Награда", 16, C.bone, { Position = UDim2.fromOffset(26, ry), Size = UDim2.fromOffset(200, 24) })
	for i, r in ipairs(q.rewards or {}) do
		PixelUi.icon(body, r.icon, UDim2.fromOffset(26 + (i - 1) * 170, ry + 30), 40)
		PixelUi.label(body, r.text, 16, i == 1 and C.gold or C.bone, { Position = UDim2.fromOffset(74 + (i - 1) * 170, ry + 38), Size = UDim2.fromOffset(120, 24) })
	end
	-- «Следить» — только у активного сюжетного задания (достижения идут сами).
	if not (q.category == "achv") and (q.tracked or q.state == "active") then
		PixelUi.button(body, "gold", UDim2.fromOffset(20, 640), UDim2.fromOffset(220, 56), "Слежу", function()
			UiSound.play("list_tick")
			ctx.api.board.track(q.id)
			for _, other in ipairs(state.data.quests) do
				other.tracked = other == q
			end
			renderDetail(false)
		end, { textSize = 16 })
	end
	-- сургучная печать: ВЗЯТЬ / СДАТЬ; у закрытых — «ЗАКРЫТО», у достижений — кубок.
	if q.category == "achv" then
		local trophy = PixelUi.piece(body, "seal", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -86, 0, 664), Size = UDim2.fromOffset(104, 104), ZIndex = 8 })
		trophy.ImageColor3 = done and Color3.new(1, 1, 1) or Color3.fromRGB(110, 100, 100)
		PixelUi.label(trophy, done and "ЕСТЬ" or "В ПУТИ", 16, done and Color3.fromRGB(255, 236, 226) or C.grey, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
		if done then
			PixelUi.glow(body, UDim2.new(1, -86, 0, 664), UDim2.fromOffset(200, 200), C.gold, 0.5)
		end
	else
		local ready = q.state == "ready"
		local seal = PixelUi.piece(body, "seal", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -86, 0, 664), Size = UDim2.fromOffset(104, 104), ZIndex = 8 })
		seal.ImageColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(110, 100, 100)
		if ready then
			PixelUi.glow(body, UDim2.new(1, -86, 0, 664), UDim2.fromOffset(200, 200), C.red, 0.55)
		end
		PixelUi.label(seal, ready and (q.action == "take" and "ВЗЯТЬ" or "СДАТЬ") or (locked and "ЗАКРЫТО" or "ИДЁТ"), 16, ready and Color3.fromRGB(255, 236, 226) or C.grey, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9 })
		local hit = Instance.new("TextButton")
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 12
		hit.Parent = seal
		hit.Activated:Connect(function()
			if not ready then
				UiSound.play("error")
				PixelUi.nudge(seal)
				return
			end
			local result = ctx.api.board.turnIn(q.id)
			if result and result.ok then
				UiSound.play("stamp")
				UiSound.play("confirm", { gap = 0 })
				UiMotion.punch(seal, 0.25, 0.3)
				UiFx.shake(0.2, 0.12)
				local scale = win.root:FindFirstChildOfClass("UIScale")
				local s = scale and scale.Scale or 1
				local p = (seal.AbsolutePosition + seal.AbsoluteSize / 2) / s
				UiFx.burst(win.root, p, { C.red, C.gold }, 30, 140)
				for i, r in ipairs(result.rewards or q.rewards or {}) do
					task.delay(0.2 * i, function()
						UiSound.play("reward_pop")
						UiFx.floatText(win.root, r.text, p - Vector2.new(0, 60 + i * 30), C.gold, 24)
					end)
				end
				task.delay(0.8, function()
					state.data = ctx.api.board.get(state.tab) or state.data
					state.selected = 1
					renderList()
					renderDetail()
				end)
			else
				UiSound.play("error")
			end
		end)
	end
	-- лист задания: строки проступают сверху вниз, печать прихлопывается
	if animate ~= false then
		local items = {}
		for _, c in ipairs(body:GetChildren()) do
			if c:IsA("GuiObject") and not (c:IsA("ImageLabel") and c.Name == "seal") then
				table.insert(items, c)
			end
		end
		table.sort(items, function(a, b)
			return a.Position.Y.Offset < b.Position.Y.Offset
		end)
		UiMotion.cascade(items, Vector2.new(18, 0), 0.025, 0.04, 0.24)
	end
end

local function load(tab: string, silent: boolean?)
	if not silent and state.tab ~= tab then
		UiSound.play("page_turn", { volume = 0.8 })
	end
	state.tab = tab
	state.selected = 1
	state.data = ctx.api.board.get(tab) or { quests = {} }
	-- первый доступный: чтобы список открывался на действии, а не на замке
	for i, q in ipairs(state.data.quests or {}) do
		if q.state == "ready" or q.state == "active" or q.state == "tracking" then
			state.selected = i
			break
		end
	end
	renderList()
	renderDetail()
end

function BoardWindow.open(context)
	ctx = context
	refs = {}
	win = WindowBase.new("KlinokBoard", { title = "Доска заданий", sub = "Гильдия искателей", onClose = context.close })
	local left = PixelUi.panel(win.canvas, UDim2.fromOffset(24, 144), UDim2.fromOffset(468, 728))
	PixelUi.slideIn(left, -1, 0)
	refs.tabs = {}
	local x = 20
	for i, tab in ipairs(TABS) do
		refs.tabs[i] = PixelUi.button(left, i == 1 and "gold" or "off", UDim2.fromOffset(x, 20), UDim2.fromOffset(tab[3] - 8, 44), tab[2], function()
			for k, b in ipairs(refs.tabs) do
				b:setKind(k == i and "gold" or "off")
			end
			load(tab[1])
		end)
		x += tab[3]
	end
	-- список прокручивается: все главы и достижения видны сразу
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(20, 92)
	list.Size = UDim2.fromOffset(428, 620)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = C.grey
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = 4
	list.Parent = left
	refs.list = list
	local right = PixelUi.panel(win.canvas, UDim2.fromOffset(1112, 144), UDim2.fromOffset(464, 728))
	PixelUi.slideIn(right, 1, 0.05)
	local detail = Instance.new("Frame")
	detail.BackgroundTransparency = 1
	detail.Size = UDim2.fromScale(1, 1)
	detail.ZIndex = 4
	detail.Parent = right
	refs.detail = detail
	load("story", true)
	return win
end

function BoardWindow.close()
	if win then
		win:destroy()
		win = nil
	end
end

return BoardWindow
