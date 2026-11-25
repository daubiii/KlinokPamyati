--!nonstrict
-- Net
-- Единая точка доступа к сетевым объектам. Сервер создаёт, клиент ждёт.
-- Имена и классы ремоутов описаны в одном месте, чтобы не искать их по коду.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.FolderName = "KlinokNet"

-- Все ремоуты проекта. Добавлять только здесь.
Net.Remotes = {
	RequestDodge = "RemoteFunction", -- клиент спрашивает разрешение на рывок
	DodgePerformed = "RemoteEvent", -- сервер сообщает об успешном рывке (эффекты)
	RequestAttack = "RemoteFunction", -- клиент просит удар / продолжение комбо
	RequestParry = "RemoteFunction", -- клиент просит парирование
	RequestHeal = "RemoteFunction", -- клиент просит лечение (заряд)
	-- RequestChest удалён: старые сундуки заменены сумкой v3 (ChestsOpen).
	ChestOpened = "RemoteEvent", -- сервер сообщает содержимое сундука
	ChestGranted = "RemoteEvent", -- сундук этажа v3 улетел в сумку (ChestService → ChestFlyController)
	RequestAbility = "RemoteFunction", -- способность оружия
	RequestCampfire = "RemoteFunction", -- костёр в комнате отдыха
	SoulReceived = "RemoteEvent", -- выпала душа босса
	AttackPerformed = "RemoteEvent", -- удар принят: комбо, урон, попадания
	ParryResult = "RemoteEvent", -- окно парирования открыто
	DamageApplied = "RemoteEvent", -- сервер сообщает о полученном уроне (интерфейс)
	CombatStateChanged = "RemoteEvent",

	-- Обратная связь для клиента (эффекты, звук, интерфейс): сервер решает,
	-- клиент только показывает.
	CombatFeedback = "RemoteEvent", -- парирование / уклонение / попадание по игроку
	EnemyEvent = "RemoteEvent", -- урон по врагу, оглушение, смерть
	FloorEvent = "RemoteEvent", -- комната, сцена босса, смерть игрока, конец этажа
	BreakableEvent = "RemoteEvent", -- этажи 4–5: удар / разрушение декорации
	Notify = "RemoteEvent", -- короткое сообщение игроку
	AbilityUsed = "RemoteEvent", -- эффект способности оружия
	AbilityFx = "RemoteEvent", -- фазы способностей оружия для всех игроков (AbilityFx)
	MageFx = "RemoteEvent", -- маг: снаряды, заклинания, барьер, покров, дебафы (MageFx, MageSpellFx)

	-- Инвентарь (раздел 20 плана): всё считает сервер.
	GetInventory = "RemoteFunction",
	RequestEquip = "RemoteFunction",
	RequestSharpen = "RemoteFunction",
	RequestNewRun = "RemoteFunction",
	BoonOffer = "RemoteEvent", -- «Дары Эха»: сервер → клиент: время стоит, 3 карточки / ждём других / идём дальше
	BoonPick = "RemoteEvent", -- клиент → сервер: выбрал карточку (номер 1..3)

	-- Отряд (PartyService): приглашения до 3 игроков, групповые этажи.
	PartyState = "RemoteEvent", -- сервер → клиент: состав отряда + приглашение (окно «Отряд»)
	PartyRequest = "RemoteFunction", -- клиент → сервер: create/invite/accept/decline/crossJoin/leave

	-- Конец забега в отряде: наблюдение за выжившими и голосование (FloorService).
	RequestLeaveFloor = "RemoteFunction", -- клиент → сервер: наблюдатель вернулся в лобби
	FloorVote = "RemoteEvent", -- клиент → сервер: голос «again» / «lobby»

	-- Онбординг: выбор класса после справки (TutorialService).
	RequestClassSelect = "RemoteFunction", -- клиент → сервер: выбрал класс (warrior/mage)

	-- Настройки игрока (PlayerSettings): громкость/чувствительность.
	RequestSettings = "RemoteFunction", -- клиент ↔ сервер: get / set {music, sfx, sens}
}

local cache = {}

local function folder()
	local existing = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = Net.FolderName
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(Net.FolderName, 15)
end

function Net.get(name: string)
	local cached = cache[name]
	if cached and cached.Parent then
		return cached
	end

	local className = Net.Remotes[name]
	if not className then
		error("Net: неизвестный ремоут '" .. tostring(name) .. "'")
	end

	local parent = folder()
	if not parent then
		return nil
	end

	local remote
	if RunService:IsServer() then
		remote = parent:FindFirstChild(name)
		if not remote then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = parent
		end
	else
		remote = parent:WaitForChild(name, 15)
	end

	cache[name] = remote
	return remote
end

-- Создать все ремоуты разом (вызывается сервером на старте).
function Net.ensureAll()
	for name in pairs(Net.Remotes) do
		Net.get(name)
	end
end

return Net
