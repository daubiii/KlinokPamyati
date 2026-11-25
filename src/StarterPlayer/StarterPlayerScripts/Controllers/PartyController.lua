--!nonstrict
-- PartyController (клиент)
-- Меню отряда в бумажном стиле (как «Свиток памяти»): HUD-кнопка «ОТРЯД»,
-- лист пергамента со слотами отряда, приглашениями (в этом сервере и из
-- другого — «Перейти к отряду») и списком друзей онлайн для приглашения.
-- Всю логику решает сервер (PartyService): окно только рисует состояние.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net.Net)

local PartyState = Net.get("PartyState")
local PartyRequest = Net.get("PartyRequest")

local Lib = script.Parent.Parent.Lib
local PixelUi = require(Lib.PixelUi)
local PaperUi = require(Lib.PaperUi)
local UiSound = require(Lib.UiSound)
local P = PaperUi.colors

local PartyController = {}

-- Вся сборка — в start(): модуль требует Bootstrap (как остальные контроллеры).
function PartyController.start()

-- ===== экран и HUD-кнопка =====
local gui, root = PixelUi.screen("KlinokParty", 45)
local canvas = PixelUi.canvas(root)
canvas.Visible = false

local partyButton = PixelUi.button(root, "wood", UDim2.new(1, -20, 0, 118), UDim2.fromOffset(150, 44), "ОТРЯД", nil, {
	anchor = Vector2.new(1, 0),
	z = 8,
	textSize = 16,
})

-- ===== окно отряда =====
PixelUi.shadow(canvas, UDim2.fromOffset(394, 196), UDim2.fromOffset(812, 556), 2)
local sheet = PaperUi.sheet(canvas, UDim2.fromOffset(410, 180), UDim2.fromOffset(780, 540), { name = "PartySheet", tilt = -1.4 })
local ribbonLabel
do
	local ribbon, label = PaperUi.ribbon(sheet, UDim2.fromOffset(190, -24), 400, "ОТРЯД", { height = 60, z = 11, textSize = 22 })
	ribbonLabel = label
end

-- Динамическая часть окна: пересобирается на каждое состояние отряда.
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(36, 44)
content.Size = UDim2.fromOffset(708, 470)
content.ZIndex = 8
content.Parent = sheet

local toastLabel = PaperUi.text(sheet, "", 15, P.red, {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.fromOffset(700, 22),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 12,
})

local toastUntil = 0
local function toast(text: string)
	toastLabel.Text = text
	toastUntil = os.clock() + 4
	task.delay(4.05, function()
		if os.clock() > toastUntil then
			toastLabel.Text = ""
		end
	end)
end

local function request(payload)
	local ok, res = pcall(function()
		return PartyRequest:InvokeServer(payload)
	end)
	if not ok or type(res) ~= "table" then
		toast("Сеть не отвечает, попробуй ещё раз")
		return { ok = false }
	end
	if not res.ok and res.reason then
		toast(res.reason)
	end
	return res
end

-- ===== друзья (список ведёт клиент, приглашает сервер) =====
local friendsCache = nil

local function fetchFriends()
	local list = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if ok and pages then
		for _, friend in ipairs(pages:GetCurrentPages()) do
			table.insert(list, {
				userId = friend.Id,
				name = friend.DisplayName or friend.Username or friend.Name or ("Игрок " .. tostring(friend.Id)),
				online = friend.isOnline == true,
			})
		end
	end
	table.sort(list, function(a, b)
		return (a.online and 0 or 1) < (b.online and 0 or 1)
	end)
	friendsCache = list
	return list
end

-- ===== отрисовка состояния =====
local state = nil -- последний PartyState

local function memberText(member)
	local place = (member.zone == "Floor") and ("этаж " .. tostring(member.floorId or "?")) or "долина"
	return (member.leader and "★ " or "") .. member.name .. "  ·  " .. place
end

local function renderInvite(box, invite)
	-- Плашка-приглашение: зов в этот сервер или «Перейти к отряду» (другой сервер).
	PaperUi.image(box, "stripRed", { Size = UDim2.fromScale(1, 1), ZIndex = 9 }, { scale = 84 / 32 })
	PaperUi.bold(box, invite.cross and ("★ " .. invite.leaderName .. " зовёт в отряд (другой сервер)") or ("★ " .. invite.leaderName .. " зовёт в отряд"), 16, P.red, {
		Position = UDim2.fromOffset(30, 8),
		Size = UDim2.fromOffset(440, 24),
		ZIndex = 11,
	})
	local main = PaperUi.button(box, UDim2.fromOffset(498, 6), UDim2.fromOffset(190, 34), invite.cross and "К ОТРЯДУ" or "ПРИНЯТЬ", nil, {
		tone = "green",
		z = 12,
		textSize = 15,
	})
	main.hit.Activated:Connect(function()
		local res = request({ action = invite.cross and "crossJoin" or "accept" })
		if res.ok and invite.cross then
			canvas.Visible = false
		end
	end)
	local decline = PaperUi.button(box, UDim2.fromOffset(498, 44), UDim2.fromOffset(190, 34), "ОТКЛОНИТЬ", nil, {
		tone = "red",
		z = 12,
		textSize = 15,
	})
	decline.hit.Activated:Connect(function()
		request({ action = "decline" })
	end)
end

local function renderMembers(box, data, top)
	local members = data.members
	for i = 1, (data.max or 3) do
		local y = top + (i - 1) * 50
		local member = members[i]
		if member then
			local strip = PaperUi.strip(box, UDim2.fromOffset(0, y), UDim2.fromOffset(708, 44), {
				text = memberText(member),
				z = 9,
			})
			strip.label.TextSize = 17
		else
			local strip = PaperUi.strip(box, UDim2.fromOffset(0, y), UDim2.fromOffset(708, 44), {
				text = "пустой слот",
				z = 9,
				kind = "stripBack",
			})
			strip.label.TextColor3 = P.faint
			strip.label.TextSize = 15
		end
	end
	return top + 3 * 50 + 14
end

local function renderFriends(box, data, top)
	local isLeader = false
	local memberIds = {}
	for _, member in ipairs(data.members) do
		memberIds[member.userId] = true
		if member.userId == player.UserId then
			isLeader = member.leader
		end
	end
	if not isLeader then
		return top
	end
	PaperUi.bold(box, "ДРУЗЬЯ ОНЛАЙН", 16, P.ink2, {
		Position = UDim2.fromOffset(6, top),
		Size = UDim2.fromOffset(300, 22),
		ZIndex = 9,
	})
	local y = top + 26
	local list = friendsCache or {}
	local shown = 0
	for _, friend in ipairs(list) do
		if shown >= 5 or y > 470 - 46 then
			break
		end
		if friend.online and not memberIds[friend.userId] then
			local row = PaperUi.strip(box, UDim2.fromOffset(0, y), UDim2.fromOffset(708, 40), {
				text = friend.name,
				z = 9,
				kind = "stripSoft",
			})
			row.label.TextSize = 15
			local btn = PaperUi.button(box, UDim2.fromOffset(560, y + 3), UDim2.fromOffset(130, 34), "пригл.", nil, {
				tone = "green",
				z = 10,
				textSize = 14,
			})
			local friendId = friend.userId
			btn.hit.Activated:Connect(function()
				local res = request({ action = "invite", userId = friendId })
				if res.ok then
					toast("Зов ушёл: " .. friend.name .. " увидит приглашение")
				end
			end)
			y += 44
			shown += 1
		end
	end
	if shown == 0 then
		PaperUi.text(box, friendsCache and "друзья офлайн — позови позже" or "загружаем друзей…", 14, P.faint, {
			Position = UDim2.fromOffset(6, y + 4),
			Size = UDim2.fromOffset(500, 20),
			ZIndex = 9,
		})
		y += 26
	end
	return y
end

local function render()
	-- Очистить контейнер.
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
	if not state then
		PaperUi.bold(content, "Ты пока один в долине.", 18, P.ink, {
			Position = UDim2.fromOffset(6, 60),
			Size = UDim2.fromOffset(690, 26),
			ZIndex = 9,
		})
		PaperUi.text(content, "Отряд: до 3 игроков. Этажи проходятся вместе — враги\nстановятся сильнее, добыча и квесты у каждого свои.", 16, P.ink2, {
			Position = UDim2.fromOffset(6, 96),
			Size = UDim2.fromOffset(690, 70),
			ZIndex = 9,
		})
		local create = PaperUi.button(content, UDim2.fromOffset(250, 200), UDim2.fromOffset(210, 52), "СОЗДАТЬ ОТРЯД", nil, {
			tone = "green",
			z = 10,
			textSize = 17,
		})
		create.hit.Activated:Connect(function()
			request({ action = "create" })
		end)
		return
	end

	local top = 0
	if state.invite then
		local box = Instance.new("Frame")
		box.Name = "Invite"
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(0, 0)
		box.Size = UDim2.fromOffset(708, 84)
		box.ZIndex = 9
		box.Parent = content
		renderInvite(box, state.invite)
		top = 98
	end

	top = renderMembers(content, state, top)

	-- Выход из отряда (лидеру — пометка о роспуске).
	local isLeader = false
	for _, member in ipairs(state.members) do
		if member.userId == player.UserId and member.leader then
			isLeader = true
		end
	end
	local leave = PaperUi.button(content, UDim2.fromOffset(498, top), UDim2.fromOffset(210, 44), isLeader and "РАСПУСТИТЬ" or "ВЫЙТИ ИЗ ОТРЯДА", nil, {
		tone = "red",
		z = 10,
		textSize = 14,
	})
	leave.hit.Activated:Connect(function()
		request({ action = "leave" })
	end)
	top += 58

	renderFriends(content, state, top)
end

-- ===== открытие/закрытие и обновление =====
local function openWindow()
	if player:GetAttribute("FilmPlaying") == true then
		return
	end
	canvas.Visible = true
	UiSound.play("paper_slide", { volume = 0.6 })
	PaperUi.drop(sheet, 0)
	if not friendsCache then
		task.spawn(function()
			fetchFriends()
			if canvas.Visible then
				render()
			end
		end)
	end
	render()
end

local function closeWindow()
	canvas.Visible = false
	UiSound.play("paper_slide", { volume = 0.5 })
end

local function toggleWindow()
	if canvas.Visible then
		closeWindow()
	else
		openWindow()
	end
end

partyButton.hit.Activated:Connect(function()
	toggleWindow()
end)

PartyState.OnClientEvent:Connect(function(data)
	state = data
	-- HUD-кнопка: состав отряда и зов в отряд.
	if data and data.invite then
		partyButton:setKind("gold")
		partyButton:set("★ В ОТРЯД?")
	elseif data and #data.members > 1 then
		partyButton:setKind("wood")
		partyButton:set("ОТРЯД · " .. #data.members)
	else
		partyButton:setKind("wood")
		partyButton:set("ОТРЯД")
	end
	if canvas.Visible then
		render()
	end
end)

print("[PartyController] окно отряда готово")
end

return PartyController
