--!nonstrict
-- ClientState
-- Общее состояние клиента, которое читают разные контроллеры: заблокирован
-- ли ввод (сцена босса, смерть, инвентарь) и открыт ли интерфейс.
-- Блокировки именованные: каждый, кто заблокировал, сам и снимает.

local ClientState = {}

local locks = {}

function ClientState.lockInput(reason: string, locked: boolean)
	locks[reason] = locked or nil
end

function ClientState.isInputBlocked(): boolean
	return next(locks) ~= nil
end

function ClientState.isLocked(reason: string): boolean
	return locks[reason] == true
end

-- Блокировки, при которых нужен свободный курсор (CameraController отпускает
-- мышь): окна интерфейса, сцена сундука, итоги забега и «свободный курсор»
-- по Alt. Сцены босса и смерть курсор не показывают.
ClientState.CursorReasons = { "ui", "station", "chestReveal", "summary", "cursor" }

function ClientState.wantsCursor(): boolean
	for _, reason in ipairs(ClientState.CursorReasons) do
		if locks[reason] then
			return true
		end
	end
	return false
end

-- Способность оружия «занимает» героя (кружение, прыжок, поворот ключа):
-- удары серии в это время не начинаются. Время — серверное (GetServerTimeNow).
local castingUntil = 0

function ClientState.setCasting(untilT: number)
	castingUntil = math.max(castingUntil, untilT)
end

function ClientState.castingUntil(): number
	return castingUntil
end

return ClientState
