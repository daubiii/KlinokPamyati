--!nonstrict
-- list_weapons345.lua — печатает оружие этажей 3-5: имя, редкость, способность,
-- пассивка. Данные читаются из исходников модулей через loadstring
-- (require заблокирован sandbox-ом Capabilities).
local cfg = game.ReplicatedStorage.Shared.Config
local out = {}

for floor = 3, 5 do
	local module = cfg:FindFirstChild("LootFloor" .. floor)
	if not module then
		table.insert(out, "этаж " .. floor .. ": модуля нет")
		continue
	end
	local ok, src = pcall(function()
		return module.Source
	end)
	if not ok then
		table.insert(out, "этаж " .. floor .. ": Source недоступен")
		continue
	end
	local chunk = loadstring(src, "LootFloor" .. floor)
	local ran, data = pcall(chunk)
	if not ran or type(data) ~= "table" then
		table.insert(out, "этаж " .. floor .. ": не выполнился")
		continue
	end

	table.insert(out, "\n=== ЭТАЖ " .. floor .. " ===")
	for _, weapon in ipairs(data.Weapons or {}) do
		local ability = weapon.ability and (data.Abilities or {})[weapon.ability]
		local passive = weapon.passive and (data.Passives or {})[weapon.passive]
		table.insert(out, ("%-16s %-32s %-10s способность: %-28s пассивка: %s"):format(
			weapon.id,
			weapon.name,
			weapon.rarity or "?",
			ability and ability.name or "—",
			passive and passive.name or "—"
		))
	end
end

return table.concat(out, "\n")
