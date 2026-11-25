--!nonstrict
-- LootService (сервер)
-- Сундуки этажей: оружие, золото и материал выбираются по FloorId игрока.
-- Первые два сундука аккаунта дают обычное оружие. Находка попадает в
-- инвентарь (в руке остаётся прежнее), клиент получает данные для карточки
-- находки с кнопкой «Надеть».
--
-- Сундуки этажей v3 (04.11.2026) на этаже не открываются: ChestService кладёт
-- их в сумку, а открывает в долине через LootService.rollContents.
-- Старый путь — ProximityPrompt сундука-модели (FloorBuilder) — остался для
-- отладки: работает с клавиатуры, геймпада и касанием, дистанцию проверяем.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)

local DataService = require(script.Parent.DataService)
local FloorBuilder = require(script.Parent.FloorBuilder)
local ArmorService = require(script.Parent.ArmorService)
local ArmorPreviewService = require(script.Parent.ArmorPreviewService)
local InventoryService = require(script.Parent.InventoryService)

local LootService = {}

-- Подставляется Bootstrap'ом (иначе циклическая зависимость с FloorService).
LootService.runStats = nil

local MAX_DISTANCE = 14

local function weaponLabel(item): string
	local rarity = Rarities.get(item.rarityId)
	return ("%s %s"):format(rarity and rarity.name or item.rarityId, item.name or item.typeId)
end

-- Содержимое сундука без мира: оружие, золото, материал, броня, припасы.
-- Общая часть для сундука на этаже (openChest, старые карты) и сундука из сумки
-- (ChestService.open — сундуки этажей v3 открываются в долине).
-- isBoss — «сундук босса» (золотой): броня всегда, больше припасов, аксессуар чаще.
function LootService.rollContents(player, floorId: number?, isBoss: boolean?, opts)
	opts = opts or {}
	local profile = DataService.get(player)
	floorId = floorId or player:GetAttribute("FloorId") or 1
	-- Оружие под класс: магу — посохи, воину — мечи и молоты (Loot.poolFor).
	-- opts.tier — гарантия сундука ответвления / мини-босса (minRarity, epicChance).
	local roll = Loot.rollChest(profile.stats.chestsOpened, nil, floorId, profile.className, opts.tier)

	local weapon = DataService.addWeapon(player, roll.weapon)
	DataService.addGold(player, roll.gold)
	DataService.addMaterial(player, roll.materialId or Loot.IronMaterial, roll.materialCount or roll.iron)
	profile.stats.chestsOpened += 1

	local equipped = profile.equippedWeapon
	local better = Weapons.rating(weapon.typeId, weapon.rarityId, weapon.sharpening, weapon.id)
		> Weapons.rating(equipped.typeId, equipped.rarityId, equipped.sharpening, equipped.id)
	local weaponType = Weapons.Types[weapon.typeId]
	local ability = Loot.abilityOf(weapon)

	-- Броня: в каждом сундуке, редкость — свой бросок, независимо от оружия
	-- (решение 06.11.2026: два сундука объединены в один). Config/Armor.
	local armorOk, armorDrop = pcall(ArmorService.rollChest, player, floorId, isBoss)
	if not armorOk then
		warn("[LootService] броня не выпала: " .. tostring(armorDrop))
		armorDrop = nil
	end
	-- Модель комплекта для карточки сундука (собирается фоном, пока идёт сцена).
	if armorDrop then
		ArmorPreviewService.ensure(armorDrop.setId)
	end
	-- Сумка: припасы и (иногда) аксессуар (Config/Items, InventoryService).
	local itemsOk, itemDrops = pcall(InventoryService.rollChest, player, floorId, isBoss)
	if not itemsOk then
		warn("[LootService] припасы не выпали: " .. tostring(itemDrops))
		itemDrops = nil
	end
	-- Свечение — по самой редкой находке.
	local topRarity = weapon.rarityId
	if armorDrop and Rarities.atLeast(armorDrop.rarityId, topRarity) then
		topRarity = armorDrop.rarityId
	end
	for _, drop in ipairs(itemDrops or {}) do
		if drop.accessory and Rarities.atLeast(drop.rarityId, topRarity) then
			topRarity = drop.rarityId
		end
	end

	local payload = {
		id = weapon.id,
		typeId = weapon.typeId,
		name = weapon.name,
		label = weaponLabel(weapon),
		typeName = weaponType and weaponType.name or weapon.typeId,
		rarityId = weapon.rarityId,
		rarityName = Rarities.get(weapon.rarityId).name,
		ability = ability and ability.name or nil,
		gold = roll.gold,
		iron = roll.iron,
		materialId = roll.materialId or Loot.IronMaterial,
		materialName = roll.materialName,
		materialCount = roll.materialCount or roll.iron,
		better = better,
		index = #profile.weapons,
		rating = Weapons.rating(weapon.typeId, weapon.rarityId, weapon.sharpening, weapon.id),
		equippedRating = Weapons.rating(equipped.typeId, equipped.rarityId, equipped.sharpening, equipped.id),
		armor = armorDrop,
		items = itemDrops,
		topRarity = topRarity,
		floorId = floorId,
		isBoss = isBoss == true,
	}

	-- Сундук из сумки показывает броню на своей карточке — без отдельного тоста.
	if armorDrop and not opts.quiet then
		local notify = Net.get("Notify")
		if notify then
			local text = armorDrop.echo and ("Повторка брони: +1 эхо «%s»"):format(armorDrop.name)
				or ("Броня: %s"):format(armorDrop.name)
			notify:FireClient(player, { kind = "armor", text = text, rarity = armorDrop.rarityId })
		end
	end

	player:SetAttribute("LastDrop", payload.label)
	DebugState.set("Loot", "LastDrop", payload.label)
	DebugState.set("Loot", "ChestsOpened", profile.stats.chestsOpened)
	return payload
end

-- Сундук-модель на этаже (ProximityPrompt). Этажи v3 так больше не делают —
-- их сундуки летят в сумку (ChestService); путь оставлен для старых карт и отладки.
function LootService.openChest(player, chest)
	if not chest or not chest.Parent or not chest:GetAttribute("IsChest") then
		return { ok = false, reason = "no-chest" }
	end
	if chest:GetAttribute("Opened") then
		return { ok = false, reason = "already-opened" }
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (chest:GetPivot().Position - root.Position).Magnitude > MAX_DISTANCE then
		return { ok = false, reason = "too-far" }
	end

	chest:SetAttribute("Opened", true)
	local prompt = chest.PrimaryPart and chest.PrimaryPart:FindFirstChild("ChestPrompt")
	if prompt then
		prompt.Enabled = false
	end

	local profile = DataService.get(player)
	local floorId = player:GetAttribute("FloorId") or 1
	local isBoss = chest:GetAttribute("ChestKind") == "boss"
	local payload = LootService.rollContents(player, floorId, isBoss)
	FloorBuilder.openChestVisual(chest, Rarities.color(payload.topRarity))

	local remote = Net.get("ChestOpened")
	if remote then
		remote:FireClient(player, payload)
	end
	-- Итог забега: интерфейс покажет его после закрытия карточки находки.
	-- Этаж v2: сундуки ответвлений и мини-боссов итог не показывают.
	local run = LootService.runStats and LootService.runStats(player) or { seconds = 0, kills = 0, deaths = 0 }
	local floorRemote = Net.get("FloorEvent")
	if floorRemote and chest:GetAttribute("FinalChest") ~= false then
		floorRemote:FireClient(player, {
			kind = "floorSummary",
			seconds = run.seconds,
			kills = run.kills,
			deaths = run.deaths,
			level = profile.level,
			gold = profile.gold,
		})
	end

	payload.ok = true
	return payload
end

-- Вызывается FloorService, когда сундук появился.
function LootService.bindChest(chest, prompt)
	prompt.Triggered:Connect(function(player)
		LootService.openChest(player, chest)
	end)
end

function LootService.start()
	Net.ensureAll()
	print("[LootService] запущен")
end

return LootService
