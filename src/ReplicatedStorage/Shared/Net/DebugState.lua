--!nonstrict
-- DebugState
-- Канал отладки: любая сторона (сервер, клиент, контроллер) пишет числа в
-- Workspace.DebugState.<scope>, а проверить их можно откуда угодно.
-- Работает только в Studio, в опубликованной игре ничего не создаёт.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DebugState = {}

-- У сервера и клиента РАЗНЫЕ корни. Иначе обе стороны создают
-- Workspace.DebugState, и клиент читает свою локальную копию, не видя
-- серверных записей (а серверные атрибуты при этом реплицируются).
local ROOT_NAME = RunService:IsServer() and "DebugState" or "DebugStateClient"

local root

local function ensureRoot()
	if not RunService:IsStudio() then
		return nil
	end
	if root and root.Parent then
		return root
	end
	root = Workspace:FindFirstChild(ROOT_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = ROOT_NAME
		root.Parent = Workspace
	end
	return root
end

local function scopeNode(scope: string, create: boolean)
	local parent = ensureRoot()
	if not parent then
		return nil
	end
	local node = parent:FindFirstChild(scope)
	if not node and create then
		node = Instance.new("Folder")
		node.Name = scope
		node.Parent = parent
	end
	return node
end

function DebugState.set(scope: string, key: string, value)
	local node = scopeNode(scope, true)
	if not node then
		return
	end
	node:SetAttribute(key, value)
end

function DebugState.bump(scope: string, key: string, delta: number?)
	local node = scopeNode(scope, true)
	if not node then
		return
	end
	node:SetAttribute(key, (node:GetAttribute(key) or 0) + (delta or 1))
end

function DebugState.get(scope: string, key: string)
	local node = scopeNode(scope, false)
	if not node then
		return nil
	end
	return node:GetAttribute(key)
end

function DebugState.snapshot(scope: string)
	local node = scopeNode(scope, false)
	local result = {}
	if not node then
		return result
	end
	for _, attribute in ipairs(node:GetAttributes()) do
		result[attribute] = node:GetAttribute(attribute)
	end
	return result
end

return DebugState
