--!nonstrict
-- tower_state.lua — состояние коллизий башни: не осталось ли следов резки.
local W = game.Workspace
local carved, thin, big = 0, 0, 0
for _, d in ipairs(W:GetDescendants()) do
	if d:IsA("BasePart") then
		if d:GetAttribute("Carved") then
			carved += 1
		end
		if d.Transparency >= 0.9 and d.CanCollide and d.Parent and d.Parent.Name == "Collision" then
			local s = d.Size
			if s.Y >= 15 and s.X <= 2 and s.Z <= 3 then
				thin += 1
			end
			if s.Y >= 20 and (s.X >= 20 or s.Z >= 20) then
				big += 1
			end
		end
	end
end
return ("вырезанных частей: %d; тонких стен башни: %d; крупных стен: %d"):format(carved, thin, big)
