--!nonstrict
-- EquipmentService (сервер)
-- Оружие в руке и инвентарь (раздел 20 плана): список найденного оружия,
-- экипировка, заточка. Всё считает сервер, клиент только просит.
--
-- Модель — воксельное оружие из VoxelWeaponBuilder, варится к кисти.
-- Клинок направлен по взгляду корпуса, а не по осям мира: раньше меч
-- «смотрел» в сторону только если персонаж появился лицом к -Z.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteGuard = require(game:GetService("ServerScriptService"):WaitForChild("Systems"):WaitForChild("RemoteGuard"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net.Net)
local DebugState = require(Shared.Net.DebugState)
local VoxelWeaponBuilder = require(Shared.Voxel.VoxelWeaponBuilder)

local DataService = require(script.Parent.DataService)

local EquipmentService = {}

local WEAPON_NAME = "EquippedWeapon"

-- Косы: полотно висит перпендикулярно древку и в покое торчит в бок. Доворачиваем
-- его на 90° вокруг древка (лезвие к игроку), а в замахе возвращаем боком —
-- «как траву косит». Углы уходят в атрибуты сварки, поворот плавно делает клиент
-- (Controllers/PlayerAnimator, weaponSwing).
local GRIP_ROLL = { royal_scythe = 90, slag_scythe = 90, oblivion_scythe = 90 }
local GRIP_SWING = { royal_scythe = 0, slag_scythe = 0, oblivion_scythe = 0 }

local function handOf(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

-- Рукоять в кулаке, клинок вперёд и чуть вверх относительно корпуса.
local function gripCFrame(character, hand)
	local root = character:FindFirstChild("HumanoidRootPart")
	local frame = root and root.CFrame or CFrame.new()
	local direction = frame:VectorToWorldSpace(Vector3.new(0, 0.35, -1)).Unit
	local rightAxis = frame.RightVector
	if math.abs(direction:Dot(rightAxis)) > 0.99 then
		rightAxis = frame.UpVector
	end
	return CFrame.fromMatrix(hand.Position, rightAxis, direction)
end

function EquipmentService.equip(character, weapon)
	local hand = handOf(character)
	if not hand then
		return nil
	end
	local typeId = weapon and weapon.typeId or "sword"
	if not Weapons.Types[typeId] then
		typeId = "sword"
	end

	for _, child in ipairs(character:GetDescendants()) do
		if child.Name == WEAPON_NAME and child:IsA("Model") then
			child:Destroy()
		end
	end

	local weaponId = weapon and weapon.id
	-- Косы доворачиваем: их сварка должна уметь менять C0 (см. ниже). Остальному
	-- оружию оставляем прежнюю схему — части крепятся прямо к кисти, как раньше.
	local rolls = weaponId ~= nil and GRIP_ROLL[weaponId] ~= nil
	local model = VoxelWeaponBuilder.build(typeId, {
		name = WEAPON_NAME,
		baseCFrame = gripCFrame(character, hand),
		weldTarget = rolls and nil or hand,
		weaponId = weapon and weapon.id,
		rarityId = weapon and weapon.rarityId,
	})
	local root = model.PrimaryPart
	if not root then
		return nil
	end

	root.Anchored = false
	if rolls then
		-- Сварка обычная (Weld): клиенту нужно плавно менять C0, доворачивая
		-- оружие вокруг оси древка (косы в покое и в замахе лежат по-разному).
		local baseC0 = hand.CFrame:Inverse() * root.CFrame
		local weld = Instance.new("Weld")
		weld.Name = "GripWeld"
		weld.Part0 = hand
		weld.Part1 = root
		weld.C0 = baseC0
		weld.C1 = CFrame.new()
		weaponId = weapon and weapon.id
		weld:SetAttribute("BaseC0", baseC0)
		weld:SetAttribute("IdleRoll", GRIP_ROLL[weaponId] or 0)
		weld:SetAttribute("SwingRoll", GRIP_SWING[weaponId] or GRIP_ROLL[weaponId] or 0)
		weld.Parent = root
	else
		-- Прежняя схема (мечи, молоты, посохи): жёсткая сварка к кисти.
		local weld = Instance.new("WeldConstraint")
		weld.Name = "GripWeld"
		weld.Part0 = hand
		weld.Part1 = root
		weld.Parent = root
	end

	model:SetAttribute("TypeId", typeId)
	model:SetAttribute("RarityId", weapon and weapon.rarityId or "common")
	model.Parent = hand
	return model
end

-- Старое имя оставлено: им пользовались другие модули.
function EquipmentService.equipSword(character)
	return EquipmentService.equip(character, { typeId = "sword", rarityId = "common" })
end

local function describe(weapon)
	local rarity = Rarities.get(weapon.rarityId)
	local weaponType = Weapons.Types[weapon.typeId]
	local ability, passive = Loot.abilityOf(weapon)
	local item = Weapons.stats(weapon.typeId, weapon.rarityId, weapon.id)
	return {
		id = weapon.id,
		name = weapon.name or (weaponType and weaponType.name) or weapon.typeId,
		typeId = weapon.typeId,
		typeName = weaponType and weaponType.name or weapon.typeId,
		rarityId = weapon.rarityId,
		rarityName = rarity and rarity.name or weapon.rarityId,
		sharpening = weapon.sharpening or 0,
		ability = ability and ability.name or nil,
		abilityId = ability and ability.id or nil,
		abilityText = ability and ability.description or nil,
		passive = passive and passive.name or nil,
		passiveText = passive and passive.description or nil,
		range = item.range,
		arc = item.arc,
		speed = item.speed,
		damageMultiplier = item.damage,
		rating = Weapons.rating(weapon.typeId, weapon.rarityId, weapon.sharpening, weapon.id),
	}
end

function EquipmentService.inventory(player)
	local profile = DataService.get(player)
	local list = {}
	for index, weapon in ipairs(profile.weapons) do
		local info = describe(weapon)
		info.index = index
		table.insert(list, info)
	end
	local equipped = describe(profile.equippedWeapon)
	local nextLevel = (profile.equippedWeapon.sharpening or 0) + 1
	return {
		ok = true,
		gold = profile.gold,
		iron = profile.materials[Loot.IronMaterial] or 0,
		equipped = equipped,
		weapons = list,
		sharpenCost = nextLevel <= Weapons.MaxSharpening and Weapons.sharpeningCost(nextLevel) or nil,
		maxSharpening = Weapons.MaxSharpening,
	}
end

local function refreshVisual(player)
	local character = player.Character
	if character then
		EquipmentService.equip(character, DataService.get(player).equippedWeapon)
	end
end

local function publishEquipped(player)
	local weapon = DataService.get(player).equippedWeapon
	player:SetAttribute("WeaponId", weapon.id)
	player:SetAttribute("WeaponType", weapon.typeId)
	player:SetAttribute("WeaponRarity", weapon.rarityId)
	player:SetAttribute("WeaponName", weapon.name)
	-- Способность — по шаблону предмета (старые сохранения хранят whirl/sunder).
	local ability, passive = Loot.abilityOf(weapon)
	player:SetAttribute("WeaponAbility", ability and ability.id or "")
	player:SetAttribute("WeaponAbilityIcon", ability and ability.icon or "")
	player:SetAttribute("WeaponPassive", passive and passive.id or "")
	player:SetAttribute("WeaponSharpening", weapon.sharpening or 0)
	-- ★ уровень и эхо (Кузня Эха, EchoService): после смены оружия HUD не врёт.
	player:SetAttribute("WeaponLevel", weapon.level or 1)
	player:SetAttribute("WeaponEchoes", weapon.echoes or 0)
end

function EquipmentService.requestEquip(player, index)
	if typeof(index) ~= "number" then
		return { ok = false, reason = "bad-request" }
	end
	local profile = DataService.get(player)
	local candidate = profile.weapons[index]
	if not candidate then
		return { ok = false, reason = "no-weapon" }
	end
	-- Посохи — только магу, мечи и молоты — только воину (Loot.weaponClass).
	if Loot.weaponClass(candidate) ~= (profile.className or "warrior") then
		return { ok = false, reason = "wrong-class" }
	end

	-- Обмен: выбранное в руку, прежнее — в инвентарь (на то же место).
	profile.weapons[index] = profile.equippedWeapon
	profile.equippedWeapon = candidate
	profile.newWeapons = math.max((profile.newWeapons or 0) - 1, 0)
	DataService.addGold(player, 0) -- заодно обновит атрибуты профиля

	publishEquipped(player)
	refreshVisual(player)
	-- Посох влияет на ману мага (Weapons.Items[id].mana / manaRegen).
	local okMana, ManaService = pcall(require, script.Parent.ManaService)
	if okMana and ManaService and ManaService.recalc then
		ManaService.recalc(player)
	end
	DebugState.set("Equipment", "Equipped", candidate.name)
	return EquipmentService.inventory(player)
end

-- Оружие под класс: если в руке чужое (сменили класс), надеть лучшее своё из инвентаря,
-- а если своего нет — выдать стартовое (Loot.StarterWeapons). Зовут вход в игру и DebugCommands.
function EquipmentService.ensureClassWeapon(player)
	local profile = DataService.get(player)
	if not profile or not profile.equippedWeapon then
		return false
	end
	local className = profile.className or "warrior"
	if Loot.weaponClass(profile.equippedWeapon) == className then
		return false
	end
	local bestIndex, bestRating = nil, -math.huge
	for i, w in ipairs(profile.weapons) do
		if Loot.weaponClass(w) == className then
			local ok, rating = pcall(Weapons.rating, w.typeId, w.rarityId, w.sharpening, w.id)
			rating = (ok and rating or 0) * (1 + ((w.level or 1) - 1) * 0.1)
			if rating > bestRating then
				bestIndex, bestRating = i, rating
			end
		end
	end
	if not bestIndex then
		local starter = Loot.newWeapon(Loot.StarterWeapons[className] or Loot.StarterWeapons.warrior, "class")
		if not starter then
			return false
		end
		table.insert(profile.weapons, starter)
		bestIndex = #profile.weapons
		profile.newWeapons = (profile.newWeapons or 0) + 1
	end
	local result = EquipmentService.requestEquip(player, bestIndex)
	DebugState.set("Equipment", "ClassWeapon", className)
	return type(result) == "table" and result.ok ~= false
end

-- Заточка за золото убрана (UI v2): золото — плата за вплавление эха в
-- Кузне Эха (EchoService). Ремоут оставлен, чтобы старый клиент не висел.
function EquipmentService.requestSharpen()
	return { ok = false, reason = "removed" }
end

function EquipmentService.start()
	Net.ensureAll()

	local function hook(player)
		-- Профиль грузится асинхронно: ждём, пока DataService его опубликует.
		local waited = 0
		while not player:GetAttribute("ProfileVersion") and waited < 60 and player.Parent do
			waited += task.wait(0.1)
		end
		-- Старое сохранение или смена класса без оружия: в руке должно быть оружие своего класса.
		if player.Parent and player:GetAttribute("ProfileVersion") then
			EquipmentService.ensureClassWeapon(player)
		end
		publishEquipped(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			character:WaitForChild("HumanoidRootPart")
			task.wait(0.15)
			EquipmentService.equip(character, DataService.get(player).equippedWeapon)
		end)
		if player.Character then
			EquipmentService.equip(player.Character, DataService.get(player).equippedWeapon)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		-- Профиль грузит DataService.PlayerAdded; даём ему мгновение.
		task.spawn(hook, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(hook, player)
	end

	-- Только Studio: выдать и надеть оружие из пула (проверка моделей и
	-- способностей). Command Bar в Play (контекст сервера):
	--   game.ServerStorage.KlinokDebug.GiveWeapon:Invoke(nil, "gatekeeper_key")
	if game:GetService("RunService"):IsStudio() then
		local ServerStorage = game:GetService("ServerStorage")
		local debugFolder = ServerStorage:FindFirstChild("KlinokDebug") or Instance.new("Folder")
		debugFolder.Name = "KlinokDebug"
		debugFolder.Parent = ServerStorage
		local give = debugFolder:FindFirstChild("GiveWeapon") or Instance.new("BindableFunction")
		give.Name = "GiveWeapon"
		give.Parent = debugFolder
		give.OnInvoke = function(playerName, weaponId)
			local player = playerName and Players:FindFirstChild(playerName) or Players:GetPlayers()[1]
			local template = Loot.template(weaponId)
			if not player or not template then
				return "нет игрока или оружия: " .. tostring(weaponId)
			end
			local profile = DataService.get(player)
			table.insert(profile.weapons, {
				kind = "weapon",
				id = template.id,
				name = template.name,
				typeId = template.typeId,
				rarityId = template.rarity,
				ability = template.ability,
				passive = template.passive,
				damageBonus = template.damageBonus,
				cooldownReduction = template.cooldownReduction,
				sharpening = 0,
				level = 1,
				echoes = 0,
				source = "debug",
			})
			EquipmentService.requestEquip(player, #profile.weapons)
			return "надето: " .. template.name
		end
	end

	Net.get("GetInventory").OnServerInvoke = RemoteGuard.wrap("GetInventory", EquipmentService.inventory)
	Net.get("RequestEquip").OnServerInvoke = RemoteGuard.wrap("RequestEquip", EquipmentService.requestEquip)
	Net.get("RequestSharpen").OnServerInvoke = RemoteGuard.wrap("RequestSharpen", EquipmentService.requestSharpen)

	print("[EquipmentService] запущен")
end

return EquipmentService
