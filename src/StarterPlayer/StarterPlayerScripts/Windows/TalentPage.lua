--!nonstrict
-- TalentPage — вкладка «Древо» книги героя (CharacterWindow, клавиша T).
-- Игрок видит ОДНО древо — своего класса («Древо воина», «Древо мага»; заголовок
-- ленты — TalentPage.title). Приложение В плана, v2:
--
-- Слева тёмный лист (фон класса: печать с фирменным предметом — шлем воина, шляпа
-- колдуна мага, клинок ассасина) и три пути класса. У каждого пути шапка (имя,
-- описание, «вложено / 34») и 22 узла снизу вверх: малые (кружок с глифом, 1 очко),
-- узлы (кольцо с иконкой, 1 очко) и ключевые (восьмигранник, 5 очков, ромб цены).
-- Снизу корень — печать класса; от неё пунктир ко входу каждого пути.
-- Подписей под узлами нет: имя и описание — в карточке справа.
-- Всё одним цветом: изучено — золото, можно изучить — кость (дышит свечение),
-- не хватает очков — пепел, закрыто — тёмный. Пунктир: тёмный — закрыто,
-- кость — следующий шаг открыт, золото — путь изучен.
-- Справа бумажный лист: свободные очки, карточка узла (наведение — предпросмотр,
-- клик — выбор, второй клик или «Изучить» — изучить), «Сбросить древо» (повторный клик за 3 с).
--
-- Арт: Config/TalentArt (×2, Pixelated) и Config/TalentAtlas — оттенки серого, цвет
-- задаёт ImageColor3. Без загруженного атласа — заглушки (UICorner/UIStroke и буквы).
-- Данные: StationApi.talents.get / learn / reset (TalentService на сервере).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Talents = require(Shared.Config.Talents)
local TalentArt = require(Shared.Config.TalentArt)
local TalentAtlas = require(Shared.Config.TalentAtlas)
local Classes = require(Shared.Config.Classes)

local Lib = script.Parent.Parent.Lib
local PaperUi = require(Lib.PaperUi)
local PixelUi = require(Lib.PixelUi)
local UiFx = require(Lib.UiFx)
local UiSound = require(Lib.UiSound)
local UiMotion = require(Lib.UiMotion)

local TalentPage = {}

local P = PaperUi.colors
local player = Players.LocalPlayer
local SCALE = TalentArt.Scale

-- Раскладка (дизайн-пиксели холста 1600 × 900). Те же числа — tools/talents/preview_talents.py.
local TREE = { x = 40, y = 118, w = 1120, h = 748 }
local SIDE = { x = 1176, y = 118, w = 384, h = 748 }
local PATH_X = { 200, 560, 920 } -- центры путей на листе
local STEP = 105 -- шаг Talents.Layout[slot].x
local SIZE = { minor = 26, normal = 46, key = 58 }
local ICON = { minor = 14, normal = 32, key = 32 }
local ROOT_POS = Vector2.new(560, 712)
local ROOT_SIZE = 46
local DASH, DASH_STEP = 4, 8
local FRAMES = {
	minor = { "frame_m_base", "frame_m_ring" },
	normal = { "frame_n_base", "frame_n_ring" },
	key = { "frame_k_base", "frame_k_ring" },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
-- Тона одноцветного древа: кольцо и иконка.
local TONE = {
	learned = { ring = rgb(214, 160, 72), icon = rgb(238, 206, 142) },
	available = { ring = rgb(184, 172, 152), icon = rgb(222, 212, 194) },
	short = { ring = rgb(112, 104, 94), icon = rgb(128, 120, 110) },
	locked = { ring = rgb(66, 60, 55), icon = rgb(76, 69, 64) },
}
local LINE = { locked = rgb(58, 52, 48), open = rgb(150, 140, 124), learned = rgb(204, 152, 70) }
local TEXT = { name = rgb(206, 192, 166), dim = rgb(124, 113, 99), gold = rgb(226, 180, 96) }
local SHEET = rgb(20, 17, 16)
local SHEET_EDGE = rgb(62, 54, 47)
local LOCKED_BASE = rgb(160, 160, 160)
local WHITE = Color3.new(1, 1, 1)

local view: any = {}
local lastSelected = nil -- выбранный узел между открытиями книги

local function hasAtlas(): boolean
	return TalentArt.has(TalentArt.Atlas)
end

-- Заголовок ленты книги: «ДРЕВО ВОИНА» / «ДРЕВО МАГА» (по классу игрока).
function TalentPage.title(classId: string?): string
	local tree = Talents.tree(classId or player:GetAttribute("ClassName") or "")
	return tree and tree.title or "ДРЕВО ТАЛАНТОВ"
end

-- ===== арт и заглушки =====

-- Кусок TalentAtlas ×SCALE (или ×scale). Без атласа — пустой ImageLabel (заглушки ниже).
local function art(parent, name: string, props, scale: number?)
	local rect = TalentAtlas.Pieces[name]
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ZIndex = 10
	local w, h = rect and rect.w or 16, rect and rect.h or 16
	label.Size = UDim2.fromOffset(w * (scale or SCALE), h * (scale or SCALE))
	if rect and hasAtlas() then
		label.Image = TalentArt.Atlas
		label.ImageRectOffset = Vector2.new(rect.x, rect.y)
		label.ImageRectSize = Vector2.new(rect.w, rect.h)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
	end
	label.Parent = parent
	return PaperUi.apply(label, props)
end

local function corner(parent, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function stroke(parent, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Рамка узла (подложка + кольцо). Заглушка: тёмный кружок (ключевой — скруглённый
-- квадрат) с обводкой-кольцом.
local function frameArt(parent, kind: string, center: UDim2, scale: number?, z: number?)
	local names = FRAMES[kind]
	local base = art(parent, names[1], { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = z or 10 }, scale)
	local ring = art(parent, names[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = (z or 10) + 1 }, scale)
	local fallback = nil
	if not hasAtlas() then
		local px = base.Size.X.Offset
		base.Size = UDim2.fromOffset(px - 4, px - 4)
		base.BackgroundTransparency = 0
		base.BackgroundColor3 = rgb(30, 26, 24)
		corner(base, kind == "key" and UDim.new(0.3, 0) or UDim.new(1, 0))
		fallback = stroke(base, TONE.locked.ring, kind == "minor" and 2 or 3)
		ring.Visible = false
	end
	return base, ring, fallback
end

-- Иконка узла: картинка или первая буква названия.
local function iconArt(parent, node, size: number, props)
	if hasAtlas() then
		local label = art(parent, node.icon, props)
		label.Size = UDim2.fromOffset(size, size)
		return label
	end
	local letter = node.kind == "minor" and "·" or (utf8.char(utf8.codepoint(node.name, 1)) or "?")
	local label = PaperUi.bold(parent, letter, math.floor(size * 0.62), WHITE, props)
	label.Size = UDim2.fromOffset(size, size)
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

local function setIcon(icon, color: Color3)
	if icon:IsA("ImageLabel") then
		icon.ImageColor3 = color
	else
		icon.TextColor3 = color
	end
end

-- ===== состояние =====

local function offlineState()
	local classId = player:GetAttribute("ClassName")
	if not Talents.tree(classId or "") then
		classId = "warrior"
	end
	local level = player:GetAttribute("Level") or 1
	local points = Talents.pointsAt(level)
	local classData = Classes.get(classId)
	return {
		classId = classId, className = classData and classData.name or classId, level = level,
		points = points, spent = 0, free = points, byBranch = {}, learned = {}, resets = 0,
		resetCost = 0, canReset = false, hubOnly = true, offline = true,
	}
end

local function bonusOf(st): number
	return math.max(0, (st.points or 0) - Talents.pointsAt(st.level))
end

-- learned | available | short (путь открыт, не хватает очков) | locked
local function statusOf(node, st)
	if st.learned[node.id] then
		return "learned", nil
	end
	local ok, reason = Talents.canLearn(st.classId, st.learned, node.id, st.level, bonusOf(st))
	if ok then
		return "available", nil
	end
	if reason == "points" then
		return "short", reason
	end
	return "locked", reason
end

local function nodePos(node): Vector2
	local layout = Talents.Layout[node.slot]
	return Vector2.new(PATH_X[node.branchIndex] + layout.x * STEP, layout.y)
end

local function pointsWord(n: number): string
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then
		return "очко"
	elseif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then
		return "очка"
	end
	return "очков"
end

-- ===== узел =====

local function buildNode(parent, node)
	local kind = node.kind
	local size = SIZE[kind]
	local pos = nodePos(node)
	local w: any = { node = node, size = size, pos = pos }

	local holder = Instance.new("Frame")
	holder.Name = "Node_" .. node.id
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(pos.X, pos.Y)
	holder.Size = UDim2.fromOffset(size, size)
	holder.ZIndex = 10
	holder.Parent = parent
	w.holder = holder

	local center = UDim2.fromScale(0.5, 0.5)
	w.glow = art(holder, "glow", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = center,
		Size = UDim2.fromOffset(size + 32, size + 32), ImageTransparency = 1, ZIndex = 9,
	})
	if not hasAtlas() then
		w.glow.BackgroundColor3 = TONE.available.ring
		w.glow.BackgroundTransparency = 1
		w.glow.Size = UDim2.fromOffset(size + 10, size + 10)
		corner(w.glow, UDim.new(1, 0))
	end
	w.base, w.ring, w.stroke = frameArt(holder, kind, center)
	w.icon = iconArt(holder, node, ICON[kind], { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = 12 })

	-- цена — только у ключевых (5 очков): ромб под рамкой
	if kind == "key" then
		w.badge = art(holder, "badge", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(22, 22), ZIndex = 13,
		})
		if not hasAtlas() then
			w.badge.BackgroundTransparency = 0
			w.badge.BackgroundColor3 = rgb(36, 31, 29)
			w.badge.Rotation = 45
			w.badge.Size = UDim2.fromOffset(15, 15)
		end
		w.cost = PaperUi.bold(holder, tostring(node.cost), 13, TEXT.name, {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 1), Size = UDim2.fromOffset(22, 22),
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 14,
		})
	end

	-- зона клика: у малых узлов шире самого кружка
	local hitSize = math.max(size, 34)
	local hitFrame = Instance.new("Frame")
	hitFrame.Name = "HitArea"
	hitFrame.BackgroundTransparency = 1
	hitFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	hitFrame.Position = center
	hitFrame.Size = UDim2.fromOffset(hitSize, hitSize)
	hitFrame.ZIndex = 16
	hitFrame.Parent = holder
	local hit = PaperUi.hit(hitFrame, 16)
	hit.MouseEnter:Connect(function()
		view.hover = node.id
		UiSound.play("list_tick")
		TalentPage.showCard(node.id)
	end)
	hit.MouseLeave:Connect(function()
		if view.hover == node.id then
			view.hover = nil
			TalentPage.showCard(view.selected)
		end
	end)
	hit.Activated:Connect(function()
		if view.selected == node.id then
			TalentPage.learn(node.id)
			return
		end
		local previous = view.selected
		view.selected = node.id
		lastSelected = node.id
		UiSound.play("tab_select")
		UiMotion.punch(holder, 0.08, 0.16)
		if previous and view.widgets[previous] then
			TalentPage.paintNode(view.widgets[previous], view.state)
		end
		TalentPage.paintNode(w, view.state)
		TalentPage.showCard(view.hover or view.selected)
	end)
	return w
end

local function setRing(w, color: Color3)
	if w.stroke then
		w.stroke.Color = color
	else
		w.ring.ImageColor3 = color
	end
end

function TalentPage.paintNode(w, st)
	if not w or not st then
		return
	end
	local status = statusOf(w.node, st)
	w.status = status
	if w.stopGlow then
		w.stopGlow()
		w.stopGlow = nil
	end
	local glowProp = w.stroke and "BackgroundTransparency" or "ImageTransparency"
	w.glow[glowProp] = 1
	local tone = TONE[status]
	setRing(w, tone.ring)
	setIcon(w.icon, tone.icon)
	w.base.ImageColor3 = status == "locked" and LOCKED_BASE or WHITE
	if status == "learned" then
		if w.node.kind == "key" then
			w.glow.ImageColor3 = tone.ring
			w.glow.BackgroundColor3 = tone.ring
			w.glow[glowProp] = 0.45
		end
	elseif status == "available" then
		w.glow.ImageColor3 = tone.ring
		w.glow.BackgroundColor3 = tone.ring
		w.stopGlow = UiMotion.breathe(w.glow, glowProp, 0.45, 0.9, 1.1)
	end
	if w.badge then
		w.badge.Visible = status ~= "learned"
		w.cost.Visible = status ~= "learned"
		w.badge.ImageColor3 = status == "available" and TONE.available.ring or status == "short" and TONE.short.ring or TONE.locked.ring
		w.cost.TextColor3 = status == "available" and TEXT.name or TEXT.dim
	end
	-- выбранный узел: четыре уголка (один кусок атласа, повёрнутый)
	local selected = view.selected == w.node.id
	if selected and not w.corners then
		w.corners = {}
		local half = w.size / 2 + 7
		for i, rot in ipairs({ 0, 90, 180, 270 }) do
			local sx = (i == 2 or i == 3) and 1 or -1
			local sy = (i == 3 or i == 4) and 1 or -1
			local c = art(w.holder, "sel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, sx * (half - 3), 0.5, sy * (half - 3)),
				Size = UDim2.fromOffset(12, 12), Rotation = rot, ImageColor3 = TONE.learned.icon, ZIndex = 15,
			})
			if not hasAtlas() then
				c.BackgroundTransparency = 0
				c.BackgroundColor3 = TONE.learned.icon
				c.Size = UDim2.fromOffset(5, 5)
			end
			w.corners[i] = c
		end
	end
	if w.corners then
		for _, c in ipairs(w.corners) do
			c.Visible = selected
		end
	end
end

-- ===== связи =====

-- Пунктир по ломаной points (дизайн-px листа), отступ start от первой точки и stop от последней.
local function buildDashes(parent, points, start: number, stop: number)
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	local dots = {}
	local d = start
	while d <= total - stop do
		local acc = 0
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude
			if d <= acc + length and length > 0 then
				local p = a + (b - a) * ((d - acc) / length)
				local dot = Instance.new("Frame")
				dot.Name = "Dash"
				dot.BorderSizePixel = 0
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromOffset(math.floor(p.X + 0.5), math.floor(p.Y + 0.5))
				dot.Size = UDim2.fromOffset(DASH, DASH)
				dot.ZIndex = 7
				dot.Parent = parent
				table.insert(dots, dot)
				break
			end
			acc += length
		end
		d += DASH_STEP
	end
	return dots
end

local function buildLine(parent, fromW, toW)
	local dots = buildDashes(parent, { fromW.pos, toW.pos }, fromW.size / 2 + 4, toW.size / 2 + 4)
	return { from = fromW.node.id, to = toW.node.id, dots = dots }
end

-- Корень (печать класса) → вход пути: вбок по низу листа, потом вверх.
local function buildRootLine(parent, toW)
	local a1 = toW.pos
	local points = math.abs(a1.X - ROOT_POS.X) < 1 and { ROOT_POS, a1 }
		or { ROOT_POS, Vector2.new(a1.X, ROOT_POS.Y), a1 }
	local dots = buildDashes(parent, points, ROOT_SIZE / 2 + 4, toW.size / 2 + 4)
	return { root = true, to = toW.node.id, dots = dots }
end

local function paintLine(line, st)
	local color = LINE.locked
	if line.root then
		color = st.learned[line.to] and LINE.learned or LINE.open
	elseif st.learned[line.from] and st.learned[line.to] then
		color = LINE.learned
	elseif st.learned[line.from] then
		color = LINE.open
	end
	for _, dot in ipairs(line.dots) do
		dot.BackgroundColor3 = color
	end
end

-- ===== лист древа =====

local function buildHeader(body, branch, index)
	local cx = PATH_X[index]
	local h: any = { branch = branch, cost = Talents.branchCost(branch) }
	PaperUi.bold(body, string.upper(branch.name), 22, TEXT.name, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 24), Size = UDim2.fromOffset(300, 28),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
	})
	PaperUi.italic(body, branch.text, 14, TEXT.dim, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 54), Size = UDim2.fromOffset(320, 20),
		TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
	})
	h.count = PaperUi.bold(body, "0 / " .. h.cost, 15, TEXT.dim, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, 76), Size = UDim2.fromOffset(120, 20),
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8,
	})
	return h
end

local function paintHeader(h, st)
	local spent = st.byBranch[h.branch.id] or 0
	h.count.Text = ("%d / %d"):format(spent, h.cost)
	h.count.TextColor3 = spent > 0 and TEXT.gold or TEXT.dim
end

local function buildRoot(body, tree)
	local holder = Instance.new("Frame")
	holder.Name = "Root"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(ROOT_POS.X, ROOT_POS.Y)
	holder.Size = UDim2.fromOffset(ROOT_SIZE, ROOT_SIZE)
	holder.ZIndex = 10
	holder.Parent = body
	local center = UDim2.fromScale(0.5, 0.5)
	local r: any = { holder = holder }
	r.base = art(holder, "root_base", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = 10 })
	r.ring = art(holder, "root_ring", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = 11 })
	r.icon = art(holder, "cls_" .. (tree.item or "helm"), { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = 12 })
	if not hasAtlas() then
		r.base.BackgroundTransparency = 0
		r.base.BackgroundColor3 = rgb(30, 26, 24)
		r.base.Size = UDim2.fromOffset(ROOT_SIZE - 4, ROOT_SIZE - 4)
		corner(r.base, UDim.new(1, 0))
		r.stroke = stroke(r.base, TONE.available.ring, 3)
		r.ring.Visible = false
		r.icon.Visible = false
	end
	return r
end

local function paintRoot(r, st)
	local tone = st.spent > 0 and TONE.learned or TONE.available
	if r.stroke then
		r.stroke.Color = tone.ring
	end
	r.ring.ImageColor3 = tone.ring
	r.icon.ImageColor3 = tone.icon
end

local function buildTree(page, st, animate: boolean)
	local tree = Talents.tree(st.classId)
	local sheet = Instance.new("Frame")
	sheet.Name = "TreeSheet"
	sheet.BackgroundColor3 = SHEET
	sheet.BorderSizePixel = 0
	sheet.Position = UDim2.fromOffset(TREE.x, TREE.y)
	sheet.Size = UDim2.fromOffset(TREE.w, TREE.h)
	sheet.ZIndex = 4
	sheet.Parent = page
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = rgb(18, 14, 10)
	shadow.BackgroundTransparency = 0.25
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(6, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 3
	shadow.Parent = sheet
	if animate then
		PaperUi.drop(sheet, 0)
	end

	local bg = TalentArt.background(tree.background)
	if bg then
		local image = Instance.new("ImageLabel")
		image.Name = "TreeArt"
		image.BackgroundTransparency = 1
		image.Image = bg
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Size = UDim2.fromOffset(TalentArt.BgSize.w * SCALE, TalentArt.BgSize.h * SCALE)
		image.ZIndex = 5
		image.Parent = sheet
	else
		stroke(sheet, SHEET_EDGE, 3)
	end

	local body = Instance.new("Frame")
	body.Name = "Tree"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 6
	body.Parent = sheet
	view.treeBody = body

	view.headers, view.widgets, view.lines = {}, {}, {}
	view.root = buildRoot(body, tree)
	for index, branch in ipairs(tree.branches) do
		view.headers[index] = buildHeader(body, branch, index)
		for _, node in ipairs(branch.nodes) do
			view.widgets[node.id] = buildNode(body, node)
		end
	end
	for _, branch in ipairs(tree.branches) do
		table.insert(view.lines, buildRootLine(body, view.widgets[branch.nodes[1].id]))
		for _, node in ipairs(branch.nodes) do
			for _, need in ipairs(node.needs) do
				table.insert(view.lines, buildLine(body, view.widgets[need], view.widgets[node.id]))
			end
		end
	end
	return sheet
end

-- ===== правый лист =====

local function buildSide(page, animate: boolean)
	local sheet = PaperUi.sheet(page, UDim2.fromOffset(SIDE.x, SIDE.y), UDim2.fromOffset(SIDE.w, SIDE.h), { kind = "sheetAlt", z = 3, tilt = 1.4 })
	if animate then
		PaperUi.drop(sheet, 0.06)
	end
	local b = Instance.new("Frame")
	b.Name = "Body"
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromScale(1, 1)
	b.ZIndex = 6
	b.Parent = sheet
	local s: any = {}
	local function centered(text, size, color, y, font, props)
		local label = (font or PaperUi.text)(b, text, size, color, {
			Position = UDim2.fromOffset(20, y), Size = UDim2.new(1, -40, 0, size + 8), TextXAlignment = Enum.TextXAlignment.Center,
		})
		return PaperUi.apply(label, props)
	end
	centered("ОЧКИ ДРЕВА", 22, P.green, 18, PaperUi.bold)
	s.ring = PaperUi.image(b, "ring80", { Position = UDim2.fromOffset(152, 50), Size = UDim2.fromOffset(80, 80), ZIndex = 7 }, { noSlice = true })
	s.free = PaperUi.bold(b, "0", 34, P.ink, {
		Position = UDim2.fromOffset(152, 50), Size = UDim2.fromOffset(80, 76), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 9,
	})
	s.freeWord = centered("свободно", 16, P.ink2, 132, PaperUi.italic)
	s.summary = centered("", 16, P.ink2, 156, PaperUi.text)
	PaperUi.divider(b, UDim2.fromOffset(24, 188), 336, 7)

	-- карточка узла (рамка и иконка пересоздаются под вид узла в showCard)
	s.card = nil
	s.name = centered("", 25, P.ink, 300, PaperUi.bold)
	s.kind = centered("", 16, P.ink2, 332, PaperUi.italic)
	s.text = PaperUi.text(b, "", 18, P.ink, {
		Position = UDim2.fromOffset(28, 362), Size = UDim2.fromOffset(328, 84),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	})
	s.status = centered("", 16, P.green, 450, PaperUi.bold)
	s.learn = PaperUi.button(b, UDim2.fromOffset(42, 484), UDim2.fromOffset(300, 58), "Изучить", function()
		if view.selected then
			TalentPage.learn(view.selected)
		end
	end, { textSize = 21, z = 8 })
	PaperUi.divider(b, UDim2.fromOffset(24, 562), 336, 7)
	s.reset = PaperUi.button(b, UDim2.fromOffset(42, 582), UDim2.fromOffset(300, 54), "Сбросить древо", function()
		TalentPage.reset()
	end, { textSize = 19, tone = "red", z = 8, sound = "confirm" })
	s.resetHint = PaperUi.italic(b, "", 15, P.ink2, {
		Position = UDim2.fromOffset(28, 642), Size = UDim2.fromOffset(328, 42),
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
	})
	s.hint = centered("Клик — выбрать, второй клик — изучить", 14, P.faint, 694, PaperUi.italic)
	view.side = s
	view.sideBody = b
	return sheet
end

-- Карточка: наведённый или выбранный узел.
function TalentPage.showCard(id: string?)
	local s = view.side
	local st = view.state
	if not s or not st then
		return
	end
	local node = id and Talents.Nodes[id]
	if s.card then
		s.card:Destroy()
		s.card = nil
	end
	if not node or node.classId ~= st.classId then
		s.name.Text = "Выберите узел"
		s.kind.Text = ""
		s.text.Text = "Наведите на узел древа, чтобы прочитать его. Очко даётся за каждый уровень."
		s.status.Text = ""
		s.learn:setText("Изучить")
		s.learn:setDisabled(true)
		return
	end
	local branch = Talents.tree(st.classId).branches[node.branchIndex]
	local status, reason = statusOf(node, st)
	local tone = TONE[status]
	-- крупная рамка узла: ×3, малый узел ×4
	local scale = node.kind == "minor" and 4 or 3
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromOffset(192, 252)
	card.Size = UDim2.fromOffset(90, 90)
	card.ZIndex = 8
	card.Parent = view.sideBody
	s.card = card
	local center = UDim2.fromScale(0.5, 0.5)
	local _, ring, fallback = frameArt(card, node.kind, center, scale, 8)
	ring.ImageColor3 = tone.ring
	if fallback then
		fallback.Color = tone.ring
	end
	local rect = TalentAtlas.Pieces[node.icon]
	local icon = iconArt(card, node, (rect and rect.w or 16) * scale, { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, ZIndex = 10 })
	setIcon(icon, tone.icon)
	s.name.Text = node.name
	s.name.TextColor3 = P.ink
	s.kind.Text = ("%s · %d %s · %s"):format(Talents.Kinds[node.kind] or "Узел", node.cost, pointsWord(node.cost), branch.name)
	s.kind.TextColor3 = P.gold
	s.text.Text = node.text
	local learnable = false
	if st.offline then
		s.status.Text = "Нет связи с сервером"
		s.status.TextColor3 = P.red
	elseif status == "learned" then
		s.status.Text = "✓ Изучено"
		s.status.TextColor3 = P.green
	elseif status == "available" then
		s.status.Text = "Можно изучить"
		s.status.TextColor3 = P.green
		learnable = true
	elseif reason == "points" then
		s.status.Text = ("Не хватает очков: нужно %d, свободно %d"):format(node.cost, st.free)
		s.status.TextColor3 = P.red
	else
		local names = {}
		for _, need in ipairs(node.needs) do
			table.insert(names, "«" .. Talents.Nodes[need].name .. "»")
		end
		s.status.Text = "Сначала: " .. table.concat(names, " или ")
		s.status.TextColor3 = P.red
	end
	s.learn:setText(status == "learned" and "Изучено" or ("Изучить · %d %s"):format(node.cost, pointsWord(node.cost)))
	s.learn:setDisabled(not learnable or view.busy == true)
end

local function paintSide(st)
	local s = view.side
	s.free.Text = tostring(st.free)
	s.free.TextColor3 = st.free > 0 and P.green or P.ink
	s.freeWord.Text = st.free > 0 and ("%s свободно"):format(pointsWord(st.free)) or "все очки вложены"
	s.summary.Text = ("Уровень %d · всего %d · вложено %d"):format(st.level, st.points, st.spent)
	-- после 30-го уровень даёт только очко древа (Config/Classes.StatLevel)
	s.hint.Text = (st.level or 1) >= Classes.StatLevel and ("После %d-го уровня — только очки древа"):format(Classes.StatLevel)
		or "Клик — выбрать, второй клик — изучить"
	-- сброс
	local confirming = view.confirmUntil and os.clock() < view.confirmUntil
	if st.offline then
		s.reset:setText("Сбросить древо")
		s.reset:setDisabled(true)
		s.resetHint.Text = "Древо недоступно: сервер не прислал данные (TalentService)."
	elseif st.spent <= 0 then
		s.reset:setText("Сбросить древо")
		s.reset:setDisabled(true)
		s.resetHint.Text = "Древо пустое. Сброс возвращает все очки — первый раз бесплатно."
	elseif not st.canReset then
		s.reset:setText("Сбросить древо")
		s.reset:setDisabled(true)
		s.resetHint.Text = "Сбросить древо можно только в долине (у врат Хранилища)."
	else
		local price = st.resetCost > 0 and ("%d золота"):format(st.resetCost) or "бесплатно"
		s.reset:setText(confirming and ("Точно? Сброс — %s"):format(price) or "Сбросить древо")
		s.reset:setDisabled(false)
		s.resetHint.Text = st.resetCost > 0
			and ("Вернёт %d %s · цена %s (25 за очко)"):format(st.spent, pointsWord(st.spent), price)
			or ("Первый сброс бесплатно · вернёт %d %s"):format(st.spent, pointsWord(st.spent))
	end
end

-- Перекрасить всё по view.state.
function TalentPage.paint()
	local st = view.state
	if not st or not view.widgets then
		return
	end
	for _, w in pairs(view.widgets) do
		TalentPage.paintNode(w, st)
	end
	for _, line in ipairs(view.lines) do
		paintLine(line, st)
	end
	for _, h in ipairs(view.headers) do
		paintHeader(h, st)
	end
	paintRoot(view.root, st)
	paintSide(st)
	TalentPage.showCard(view.hover or view.selected)
end

-- ===== действия =====

local function canvasPos(w): Vector2
	return Vector2.new(TREE.x + w.pos.X, TREE.y + w.pos.Y)
end

local function say(text: string, color: Color3?)
	if view.opts and view.opts.toast then
		view.opts.toast(text, color)
	end
end

local function celebrate(id: string)
	local w = view.widgets and view.widgets[id]
	if not w then
		return
	end
	local key = w.node.kind == "key"
	local minorNode = w.node.kind == "minor"
	local at = canvasPos(w)
	local gold = TONE.learned.ring
	if view.opts.fx then
		UiFx.burst(view.opts.fx, at, { gold, TONE.learned.icon, TEXT.name }, key and 30 or minorNode and 8 or 16, key and 110 or minorNode and 44 or 70)
		UiFx.floatText(view.opts.fx, "+ " .. w.node.name, at - Vector2.new(0, w.size / 2 + 26), TONE.learned.icon, key and 26 or minorNode and 18 or 22)
	end
	UiMotion.punch(w.holder, key and 0.3 or 0.2, 0.28)
	UiSound.play(key and "forge_reveal" or "star_on")
	-- пунктир к узлу «наливается» золотом
	for _, line in ipairs(view.lines) do
		if line.to == id then
			for i, dot in ipairs(line.dots) do
				local size = dot.Size
				dot.Size = UDim2.fromOffset(1, 1)
				task.delay(0.03 * i, function()
					if dot.Parent then
						PixelUi.tween(dot, 0.14, { Size = size }, Enum.EasingStyle.Back)
					end
				end)
			end
		end
	end
end

local function apply(result)
	if result and type(result.state) == "table" then
		view.state = result.state
		if view.opts.onChanged then
			view.opts.onChanged(view.state)
		end
	end
end

function TalentPage.learn(id: string)
	local st = view.state
	local node = Talents.Nodes[id]
	local w = view.widgets and view.widgets[id]
	if not st or not node or not w or view.busy then
		return
	end
	local status, reason = statusOf(node, st)
	if st.offline or status ~= "available" then
		UiSound.play("error")
		PixelUi.nudge(w.holder)
		if status ~= "learned" then
			say(st.offline and "Нет связи с сервером" or Talents.Reasons[reason or "locked"] or "Нельзя", P.red)
		end
		return
	end
	view.busy = true
	TalentPage.showCard(view.hover or view.selected)
	local page = view.page
	task.spawn(function()
		local result = view.opts.api.talents.learn(id)
		if view.page ~= page or not page.Parent then
			return
		end
		view.busy = false
		apply(result)
		TalentPage.paint()
		if result and result.ok then
			celebrate(id)
		else
			UiSound.play("error")
			say(result and result.text or "Сервер не ответил", P.red)
		end
	end)
end

function TalentPage.reset()
	local st = view.state
	if not st or view.busy or st.offline or st.spent <= 0 or not st.canReset then
		return
	end
	if not (view.confirmUntil and os.clock() < view.confirmUntil) then
		view.confirmUntil = os.clock() + 3
		paintSide(st)
		PixelUi.nudge(view.side.reset.holder)
		local token = view.confirmUntil
		task.delay(3.05, function()
			if view.confirmUntil == token and view.state then
				view.confirmUntil = nil
				paintSide(view.state)
			end
		end)
		return
	end
	view.confirmUntil = nil
	view.busy = true
	local page = view.page
	task.spawn(function()
		local result = view.opts.api.talents.reset()
		if view.page ~= page or not page.Parent then
			return
		end
		view.busy = false
		apply(result)
		TalentPage.paint()
		if result and result.ok then
			UiSound.play("stamp")
			say(("Древо сброшено: +%d %s"):format(result.refunded or 0, pointsWord(result.refunded or 0)), P.green)
			for _, w in pairs(view.widgets) do
				UiMotion.punch(w.holder, 0.06, 0.2)
			end
		else
			UiSound.play("error")
			say(result and result.text or "Сервер не ответил", P.red)
		end
	end)
end

-- ===== вход =====

-- Первый доступный узел (или вход первого пути) — выбран при открытии.
local function defaultSelection(st)
	local tree = Talents.tree(st.classId)
	for _, branch in ipairs(tree.branches) do
		for _, node in ipairs(branch.nodes) do
			if statusOf(node, st) == "available" then
				return node.id
			end
		end
	end
	return tree.branches[1].nodes[1].id
end

-- opts: api (StationApi), fx (слой эффектов холста), toast(text, color), onChanged(state), animate.
function TalentPage.render(page, opts)
	opts = opts or {}
	for _, child in ipairs(page:GetChildren()) do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
	view = { page = page, opts = opts, selected = lastSelected }
	local st = opts.api and opts.api.talents and opts.api.talents.get()
	if type(st) ~= "table" or not Talents.tree(st.classId or "") then
		st = offlineState()
	end
	view.state = st
	buildTree(page, st, opts.animate ~= false)
	buildSide(page, opts.animate ~= false)
	if not (view.selected and Talents.Nodes[view.selected] and Talents.Nodes[view.selected].classId == st.classId) then
		view.selected = defaultSelection(st)
	end
	TalentPage.paint()
	return view
end

function TalentPage.close()
	lastSelected = view.selected
	view = {}
end

return TalentPage
