-- ===== фаза 2: выбор класса v3 (решение владельца 17.11: красного,
-- понятные предметы — летопись и свиток, а не «просто страницы») =====
-- Воин = ЛЕТОПИСЬ: красный переплёт с золотыми стежками, восковая печать,
-- красная лента-закладка снизу. Маг = СВИТОК: валы сверху/снизу, лиловая
-- лента перевязи, подвесная печать. Баннер заголовка — красная лента.
-- Кнопки «ВЫБРАТЬ» — красные (воск/печать). Головы классов — без рамок.
local PIXEL = PaperUi.Font
local Classes = require(Shared.Config.Classes)
local UiAtlas = require(Shared.Config.UiAtlas)
local selectRemote = ReplicatedStorage:WaitForChild("RequestClassSelect", 30)
local selectShown = false

local selectGui = Instance.new("ScreenGui")
selectGui.Name = "KlinokClassSelect"
selectGui.ResetOnSpawn = false
selectGui.IgnoreGuiInset = true
selectGui.DisplayOrder = 55
selectGui.Enabled = false
selectGui.Parent = player:WaitForChild("PlayerGui")

local selectDim = Instance.new("Frame")
selectDim.Size = UDim2.fromScale(1, 1)
selectDim.BackgroundColor3 = Color3.new(0, 0, 0)
selectDim.BackgroundTransparency = 0.45
selectDim.BorderSizePixel = 0
selectDim.ZIndex = 1
selectDim.Active = true
selectDim.Parent = selectGui

local selectPanel = Instance.new("Frame")
selectPanel.Name = "Panel"
selectPanel.AnchorPoint = Vector2.new(0.5, 0.5)
selectPanel.Position = UDim2.fromScale(0.5, 0.5)
selectPanel.Size = UDim2.fromOffset(860, 580)
selectPanel.BackgroundColor3 = P.paper
selectPanel.BorderSizePixel = 0
selectPanel.ZIndex = 2
selectPanel.Parent = selectDim
do
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.red
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = selectPanel
end

-- Красный баннер заголовка.
local banner = PaperUi.image(selectPanel, "stripRed", {
	Position = UDim2.fromOffset(180, 12),
	Size = UDim2.fromOffset(500, 56),
	ZIndex = 4,
}, { scale = 56 / 32 })
PaperUi.bold(banner, "ВЫБОР ПУТИ", 24, P.paper, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -3),
	Size = UDim2.fromOffset(360, 30),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 6,
})

local CLASS_CARDS = {
	{
		id = "warrior",
		name = "ВОИН",
		head = ART.warriorHead,
		tilt = -1.3,
		weapon = "sword",
		armorIcon = "armor",
		lore = "Клинок помнит строй. Ты — щит долины: тяжёлая броня, щедрое окно парирования, удар в упор.",
		mech = "1 заряд рывка · ближний бой · крепкая броня",
		accent = P.red,
	},
	{
		id = "mage",
		name = "МАГ",
		head = ART.mageHead,
		tilt = 1.3,
		weapon = "staff",
		armorIcon = "helm",
		lore = "Эхо отвечает слогам, а не силе. Посох бьёт издалека — мана дороже брони, зато заклинания этажей твои.",
		mech = "100 маны · дальние снаряды · заклинания этажа",
		accent = Color3.fromRGB(118, 62, 184),
	},
}

local function statsRows(id: string): { string }
	local s = Classes.statsAtLevel(id, 1)
	if not s then
		return {}
	end
	local rows = {
		("Здоровье %d · Броня %g · Урон %g"):format(s.maxHealth, s.armor, s.weaponDamage),
		("Атака %g/с · Бег %g · Парирование %gс · Рывки %d"):format(s.attackSpeed, s.walkSpeed, s.parryWindow or 0, s.dodgeCharges or 1),
	}
	if s.mana and s.mana > 0 then
		rows[2] = rows[2] .. " · Мана " .. s.mana
	end
	return rows
end

local sheets = {}

for cardIndex, card in ipairs(CLASS_CARDS) do
	local sheet = PaperUi.sheet(selectPanel, UDim2.fromOffset(74 + (cardIndex - 1) * 398, 66), UDim2.fromOffset(344, 470), {
		name = "ClassSheet_" .. card.id,
		tilt = card.tilt * 0.6,
		z = 3,
	})
	sheets[cardIndex] = sheet
	local face = sheet:FindFirstChild("Face")
	local baseZ = 4

	local head = Instance.new("ImageLabel")
	head.Name = "Head"
	head.Position = UDim2.fromOffset(82, 26)
	head.Size = UDim2.fromOffset(180, 180)
	head.BackgroundTransparency = 1
	head.Image = card.head
	head.ZIndex = baseZ + 1
	head.Parent = sheet
	pcall(function()
		head.ResampleMode = Enum.ResampleMode.Pixel
	end)

	PaperUi.bold(face, card.name, 20, P.red, {
		Name = "Name",
		Position = UDim2.fromOffset(0, 210),
		Size = UDim2.fromOffset(344, 26),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = baseZ + 2,
	})

	-- Оружие и броня класса: иконки 44×44 с тенью-подложкой, без кругов.
	local iconPairs = { card.weapon, card.armorIcon }
	for m, iconName in ipairs(iconPairs) do
		local rect = UiAtlas.Icons[iconName] or UiAtlas.Icons.sword
		local shadow = Instance.new("ImageLabel")
		shadow.Name = "IconShadow" .. m
		shadow.AnchorPoint = Vector2.new(0.5, 0)
		shadow.Position = UDim2.new(0.5, (m == 1 and -26 or 26) + 2, 0, 250)
		shadow.Size = UDim2.fromOffset(44, 44)
		shadow.BackgroundTransparency = 1
		shadow.Image = UiAssets.Icons
		shadow.ImageRectOffset = Vector2.new(rect.x, rect.y)
		shadow.ImageRectSize = Vector2.new(rect.w, rect.h)
		shadow.ImageColor3 = Color3.fromRGB(26, 16, 10)
		shadow.ImageTransparency = 0.55
		shadow.ZIndex = baseZ + 2
		shadow.Parent = sheet
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon" .. m
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, (m == 1 and -26 or 26), 0, 248)
		icon.Size = UDim2.fromOffset(44, 44)
		icon.BackgroundTransparency = 1
		icon.Image = UiAssets.Icons
		icon.ImageRectOffset = Vector2.new(rect.x, rect.y)
		icon.ImageRectSize = Vector2.new(rect.w, rect.h)
		icon.ZIndex = baseZ + 3
		icon.Parent = sheet
		pcall(function()
			icon.ResampleMode = Enum.ResampleMode.Pixel
		end)
	end

	PaperUi.text(face, card.lore, 12, P.ink, {
		Name = "Lore",
		Position = UDim2.fromOffset(24, 296),
		Size = UDim2.fromOffset(296, 58),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = baseZ + 2,
	})

	PaperUi.text(face, card.mech, 11, P.ink2, {
		Name = "Mech",
		Position = UDim2.fromOffset(24, 358),
		Size = UDim2.fromOffset(296, 30),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = baseZ + 2,
	})

	local rows = statsRows(card.id)
	PaperUi.text(face, rows[1] or "", 12, P.ink, {
		Name = "Stats1",
		Position = UDim2.fromOffset(24, 392),
		Size = UDim2.fromOffset(296, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = baseZ + 2,
	})
	PaperUi.text(face, rows[2] or "", 11, P.ink2, {
		Name = "Stats2",
		Position = UDim2.fromOffset(24, 412),
		Size = UDim2.fromOffset(296, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = baseZ + 2,
	})

	local chooseButton = PaperUi.button(sheet, UDim2.new(0.5, 0, 1, -12), UDim2.fromOffset(180, 40), "ВЫБРАТЬ", nil, {
		anchor = Vector2.new(0.5, 1),
		tone = "red",
		z = baseZ + 6,
		textSize = 17,
	})
	chooseButton.hit.Activated:Connect(function()
		local ok, res = pcall(function()
			return selectRemote:InvokeServer(card.id)
		end)
		if ok and type(res) == "table" and res.ok then
			UiSound.play("paper_slide", { volume = 0.7 })
			selectGui.Enabled = false
			selectShown = false
		else
			UiSound.play("error", { volume = 0.4 })
			if res and res.err then
				local note = PaperUi.text(sheet, res.err, 12, P.red, {
					Name = "Err",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 1, -64),
					Size = UDim2.fromOffset(300, 18),
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = baseZ + 8,
				})
				task.delay(2.5, function()
					if note.Parent then
						note:Destroy()
					end
				end)
			end
		end
	end)

	-- Наведение: лист выпрыгивает чуть вперёд.
	sheet.MouseEnter:Connect(function()
		PixelUi.tween(sheet, 0.12, { Size = UDim2.fromOffset(356, 486) }, Enum.EasingStyle.Quad)
	end)
	sheet.MouseLeave:Connect(function()
		PixelUi.tween(sheet, 0.12, { Size = UDim2.fromOffset(344, 470) }, Enum.EasingStyle.Quad)
	end)

	-- ===== предметные детали =====
	if card.id == "warrior" then
		-- ЛЕТОПИСЬ: красный переплёт слева, золотые стежки, восковая печать,
		-- красная лента-закладка снизу (свисает из-под листа).
		local spine = Instance.new("Frame")
		spine.Name = "Spine"
		spine.Size = UDim2.fromOffset(16, 470)
		spine.Position = UDim2.fromOffset(0, 0)
		spine.BackgroundColor3 = Color3.fromRGB(108, 32, 28)
		spine.BorderSizePixel = 0
		spine.ZIndex = baseZ + 1
		spine.Parent = sheet
		for dot = 1, 3 do
			local stitch = Instance.new("Frame")
			stitch.Size = UDim2.fromOffset(6, 6)
			stitch.Position = UDim2.fromOffset(5, 60 + (dot - 1) * 170)
			stitch.BackgroundColor3 = Color3.fromRGB(255, 204, 84)
			stitch.BorderSizePixel = 0
			stitch.ZIndex = baseZ + 2
			stitch.Parent = spine
			local stitchCorner = Instance.new("UICorner")
			stitchCorner.CornerRadius = UDim.new(1, 0)
			stitchCorner.Parent = stitch
		end
		PaperUi.image(sheet, "stampMark", {
			Name = "Seal",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 1, -18),
			Size = UDim2.fromOffset(60, 60),
			ImageColor3 = P.red,
			Rotation = -12,
			ZIndex = baseZ + 5,
		}, { noSlice = true })
		local bookmark = Instance.new("Frame")
		bookmark.Name = "Bookmark"
		bookmark.AnchorPoint = Vector2.new(0.5, 0)
		bookmark.Position = UDim2.new(0.5, 0, 1, -2)
		bookmark.Size = UDim2.fromOffset(22, 44)
		bookmark.BackgroundColor3 = P.red
		bookmark.BorderSizePixel = 0
		bookmark.ZIndex = 2 -- за листом: свисает из-под нижнего края
		bookmark.Parent = sheet
		local notch = Instance.new("Frame")
		notch.AnchorPoint = Vector2.new(0.5, 0)
		notch.Position = UDim2.new(0.5, 0, 1, 0)
		notch.Size = UDim2.fromOffset(22, 20)
		notch.Rotation = 45
		notch.BackgroundColor3 = P.red
		notch.BorderSizePixel = 0
		notch.ZIndex = 2
		notch.Parent = bookmark
	elseif card.id == "mage" then
		-- СВИТОК: валы сверху и снизу, лиловая лента перевязи, печать-подвеска.
		for _, rollName in ipairs({ "RollTop", "RollBottom" }) do
			local isTop = rollName == "RollTop"
			local roll = Instance.new("Frame")
			roll.Name = rollName
			roll.Size = UDim2.new(1, 16, 0, 14)
			roll.Position = UDim2.new(0, -8, isTop and 0 or 1, isTop and 0 or -14)
			roll.BackgroundColor3 = Color3.fromRGB(172, 152, 116)
			roll.BorderSizePixel = 0
			roll.ZIndex = baseZ + 1
			roll.Parent = sheet
			local rollCorner = Instance.new("UICorner")
			rollCorner.CornerRadius = UDim.new(1, 0)
			rollCorner.Parent = roll
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(Color3.fromRGB(120, 104, 78), Color3.fromRGB(224, 204, 164), Color3.fromRGB(120, 104, 78))
			gradient.Rotation = 90
			gradient.Parent = roll
		end
		local band = Instance.new("Frame")
		band.Name = "TieBand"
		band.AnchorPoint = Vector2.new(0.5, 0)
		band.Position = UDim2.new(0.5, 0, 0, 0)
		band.Size = UDim2.fromOffset(12, 470)
		band.BackgroundColor3 = Color3.fromRGB(118, 62, 184)
		band.BorderSizePixel = 0
		band.ZIndex = baseZ
		band.Parent = sheet
		PaperUi.image(sheet, "stampMark", {
			Name = "Seal",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -24),
			Size = UDim2.fromOffset(56, 56),
			ImageColor3 = Color3.fromRGB(118, 62, 184),
			Rotation = 10,
			ZIndex = baseZ + 5,
		}, { noSlice = true })
	end
end

local function syncSelect()
	local film = player:GetAttribute("FilmPlaying") == true
	local want = player:GetAttribute("ShowClassSelect") == true
	if film or not want or selectShown then
		if film then
			selectGui.Enabled = false
		end
		return
	end
	selectShown = true
	selectGui.Enabled = true
	UiSound.play("paper_slide", { volume = 0.8 })
	PaperUi.drop(sheets[1], 0)
	PaperUi.drop(sheets[2], 0.08)
end

player:GetAttributeChangedSignal("ShowClassSelect"):Connect(syncSelect)
player:GetAttributeChangedSignal("FilmPlaying"):Connect(syncSelect)
syncSelect()
