--!nonstrict
-- ArmorPreviewService (сервер) — модели комплектов брони для окон интерфейса.
--
-- Карточка сундука (ChestRevealController) показывает выпавшую броню настоящей
-- моделью рядом с оружием, а не строкой текста. Облик собирает тот же
-- AppearanceService, что одевает героя в игре: меши комплекта (HeroArmorBuilder)
-- или запасной облик из Part'ов, если меши ещё не импортированы, — поэтому
-- в окне броня выглядит ровно как на персонаже.
--
-- ArmorPreviewService.ensure(setId) — собрать (один раз на сервер) модель
--   ReplicatedStorage.KlinokArmorPreviews.<setId>: манекен R15 в комплекте,
--   все части закреплены, без Humanoid и скриптов. Клиент клонирует её во
--   ViewportFrame. Сборка асинхронная: ответ сундука не ждёт модель, клиент
--   ждёт её сам (WaitForChild), пока идёт сцена «Клинок читает память».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Armor = require(Shared.Config.Armor)

local AppearanceService = require(script.Parent.AppearanceService)

local ArmorPreviewService = {}

ArmorPreviewService.FolderName = "KlinokArmorPreviews"

local building = {} -- setId → true, пока собирается

local function folder()
	local f = ReplicatedStorage:FindFirstChild(ArmorPreviewService.FolderName)
	if not f then
		f = Instance.new("Folder")
		f.Name = ArmorPreviewService.FolderName
		f.Parent = ReplicatedStorage
	end
	return f
end

-- Готовая модель или nil.
function ArmorPreviewService.get(setId: string)
	return folder():FindFirstChild(setId)
end

local function build(setId: string)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[ArmorPreview] манекен не создан: " .. tostring(dummy))
		return nil
	end
	dummy.Name = setId
	local root = dummy:FindFirstChild("HumanoidRootPart")
	if not root then
		dummy:Destroy()
		return nil
	end
	-- Далеко над картой: суставы R15 встают на место только в Workspace.
	root.Anchored = true
	dummy:PivotTo(CFrame.new(0, 4000, 0))
	dummy.Parent = Workspace
	RunService.Heartbeat:Wait()
	AppearanceService.refresh(dummy, { helm = setId, armor = setId })
	-- Заморозить позу: всё закреплено, лишнее убрано.
	for _, d in ipairs(dummy:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end
	-- Центр модели — в начало координат, лицом к −Z (как у героя).
	dummy:PivotTo(CFrame.new(0, 2.9, 0))
	dummy.PrimaryPart = root
	local set = Armor.Sets[setId]
	dummy:SetAttribute("SetId", setId)
	dummy:SetAttribute("Rarity", set and set.rarity or "common")
	dummy.Parent = folder()
	return dummy
end

-- Собрать модель комплекта, если её ещё нет. Не ждёт сборку.
function ArmorPreviewService.ensure(setId: string?)
	if type(setId) ~= "string" or not Armor.Sets[setId] then
		return
	end
	if ArmorPreviewService.get(setId) or building[setId] then
		return
	end
	building[setId] = true
	task.spawn(function()
		local ok, err = pcall(build, setId)
		if not ok then
			warn(("[ArmorPreview] %s: %s"):format(setId, tostring(err)))
		end
		building[setId] = nil
	end)
end

function ArmorPreviewService.start()
	folder()
end

return ArmorPreviewService
