--!nonstrict
-- kill_wall.lua — проверяет рейкастом, что проём перекрыт невидимой коллизией,
-- убирает её и проверяет снова.
local W = game.Workspace
local out = {}

-- Проём: x = -120, z ≈ -125.3, идём вдоль -Z
local origin = Vector3.new(-120, 11.5, -116)
local direction = Vector3.new(0, 0, -20)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}

local function cast(label: string)
	local result = W:Raycast(origin, direction, params)
	if not result then
		table.insert(out, label .. ": луч ничего не встретил (проход свободен)")
		return nil
	end
	table.insert(out, string.format(
		"%s: попадание в %s на расстоянии %.2f (z=%.2f), размер %.1f%.1f%.1f, прозрачность %.2f",
		label, result.Instance:GetFullName(), result.Distance, result.Position.Z,
		result.Instance.Size.X, result.Instance.Size.Y, result.Instance.Size.Z,
		result.Instance.Transparency
	))
	return result.Instance
end

local blocker = cast("до")
if not blocker then
	return table.concat(out, "\n")
end

-- Убираем именно ту коллизию (проверяем, что это запечённый коллайдер карты)
if blocker.CanCollide and blocker.Transparency >= 0.9 then
	blocker.CanCollide = false
	table.insert(out, "убрана коллизия: " .. blocker:GetFullName())
else
	table.insert(out, "это не невидимая коллизия — не трогаю")
	return table.concat(out, "\n")
end

cast("после")
return table.concat(out, "\n")
